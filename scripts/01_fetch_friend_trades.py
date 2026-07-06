"""
Day 1-2: 拉取目标朋友地址的历史交易数据。
使用 GMGN API (tls_client 绕过 Cloudflare)。
输出: data/friend_raw/ 目录下的 JSON 文件 + 汇总 CSV
"""
import os, json, time, csv, sys, random
from pathlib import Path
from dotenv import load_dotenv

# === Config ===
ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / '.env')
GMGN_API_KEY = os.getenv("GMGN_API_KEY")
FRIEND_WALLET = os.getenv("FRIEND_WALLET", "REPLACE_WITH_SAMPLE_WALLET")
DATA_DIR = ROOT / 'data'
DATA_DIR.mkdir(exist_ok=True)
RAW_DIR = DATA_DIR / 'friend_raw'
RAW_DIR.mkdir(exist_ok=True)


def create_session():
    """创建带随机 TLS 指纹的 session，绕过 Cloudflare"""
    import tls_client
    identifier = random.choice([
        b for b in tls_client.settings.ClientIdentifiers.__args__
        if b.startswith(('chrome', 'safari', 'firefox'))
    ])
    session = tls_client.Session(
        random_tls_extension_order=True,
        client_identifier=identifier
    )
    session.timeout_seconds = 30
    return session


def gmgn_get(session, path, is_post=False, payload=None):
    """GMGN API 请求，使用 gmgnai-wrapper 一致的 headers"""
    headers = {
        'Host': 'gmgn.ai',
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
        'dnt': '1',
        'referer': 'https://gmgn.ai/?chain=sol',
        'content-type': 'application/json',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Authorization': f'Bearer {GMGN_API_KEY}',
    }
    url = f"https://gmgn.ai{path}"
    try:
        if is_post:
            resp = session.post(url, json=payload, headers=headers)
        else:
            resp = session.get(url, headers=headers)
        if resp.status_code == 200:
            return resp.json()
        print(f"  [{resp.status_code}] {resp.text[:300]}")
    except Exception as e:
        print(f"  [Error] {type(e).__name__}: {e}")
    return None


def fetch_wallet_info(session, wallet, period="30d"):
    """获取钱包基础信息（PnL, 胜率, 交易统计等）"""
    return gmgn_get(session,
        f"/defi/quotation/v1/wallets/sol/{wallet}?period={period}")


def fetch_wallet_holdings(session, wallet):
    """获取当前持仓"""
    return gmgn_get(session,
        f"/defi/quotation/v1/wallets/sol/{wallet}/holdings")


def fetch_token_info(session, token_mint):
    """获取 token 详情 (creator, holders, 安全等)"""
    return gmgn_get(session,
        "/api/v1/mutil_window_token_info",
        is_post=True,
        payload={"chain": "sol", "addresses": [token_mint]})


def main():
    if not GMGN_API_KEY:
        print("ERROR: 缺少 GMGN_API_KEY，请在 .env 中配置。")
        sys.exit(1)

    if FRIEND_WALLET == "REPLACE_WITH_SAMPLE_WALLET":
        print("ERROR: 缺少 FRIEND_WALLET，请在 .env 中配置。")
        sys.exit(1)

    print(f"=== 拉取朋友地址数据: {FRIEND_WALLET} ===\n")

    # 创建 session
    print("创建 TLS session...")
    session = create_session()

    # 1. 拉钱包基础信息
    print("\n[1/3] 拉取钱包基础信息 (30d)...")
    wallet_info = fetch_wallet_info(session, FRIEND_WALLET, "30d")
    if wallet_info is None:
        print("ERROR: 无法获取钱包信息")
        print("请确认: 1) 网络能访问 gmgn.ai  2) API Key 有效")
        sys.exit(1)

    outfile = RAW_DIR / 'wallet_info_30d.json'
    with open(outfile, 'w') as f:
        json.dump(wallet_info, f, indent=2, ensure_ascii=False)
    print(f"  -> {outfile}")

    # 2. 拉钱包持仓
    print("\n[2/3] 拉取当前持仓...")
    holdings = fetch_wallet_holdings(session, FRIEND_WALLET)
    if holdings:
        outfile = RAW_DIR / 'holdings.json'
        with open(outfile, 'w') as f:
            json.dump(holdings, f, indent=2, ensure_ascii=False)
        print(f"  -> {outfile}")
    else:
        print("  (无持仓数据或接口不可用)")

    # 3. 从 wallet_info 提取交易过的 token 列表，逐个拉详情
    print("\n[3/3] 拉取 token 详情...")
    data = wallet_info.get('data', wallet_info)
    tokens = []

    # 尝试从多个可能的字段中提取 token 列表
    for key in ['positions', 'tokens', 'holdings', 'history', 'trades']:
        if key in data:
            items = data[key]
            if isinstance(items, list):
                for item in items:
                    addr = item.get('address') or item.get('token_address') or item.get('token', {}).get('address')
                    if addr:
                        tokens.append(addr)
            break

    # 如果上面没有，尝试从 wallet_info 的 key 提取
    if not tokens:
        # 直接保存整个响应，人工查看结构
        print("  未自动识别 token 列表，保存完整响应供人工分析")
        print(f"  响应 keys: {list(data.keys()) if isinstance(data, dict) else type(data)}")
        if isinstance(data, dict):
            print(f"  前 5 个 key 的样本...")
            for k, v in list(data.items())[:5]:
                print(f"    {k}: {type(v).__name__} = {json.dumps(v, ensure_ascii=False)[:200]}")

    token_details = []
    unique_tokens = list(set(tokens))[:50]  # 先去重，限 50 个
    print(f"  拉取 {len(unique_tokens)} 个 token 详情...")
    for i, tok in enumerate(unique_tokens):
        print(f"    [{i+1}/{len(unique_tokens)}] {tok}")
        detail = fetch_token_info(session, tok)
        if detail:
            token_details.append(detail)
        time.sleep(0.3)  # 限速

    if token_details:
        outfile = RAW_DIR / 'token_details.json'
        with open(outfile, 'w') as f:
            json.dump(token_details, f, indent=2, ensure_ascii=False)
        print(f"  -> {outfile} ({len(token_details)} tokens)")

    # 输出摘要
    print("\n" + "="*50)
    print("=== 拉取完成 ===")
    print(f"数据目录: {RAW_DIR}")
    for f in sorted(RAW_DIR.glob('*.json')):
        size_kb = f.stat().st_size / 1024
        print(f"  {f.name} ({size_kb:.1f} KB)")
    print("\n下一步：")
    print("  python3 scripts/02_analyze_friend_patterns.py")


if __name__ == "__main__":
    main()
