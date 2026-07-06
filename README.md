# Solana Copytrade Safe Export

这个目录是给代码审阅和结构分析用的最小安全导出版本，不包含原始 `.env`、虚拟环境或完整交易数据。

## Included

- `requirements.txt`
- `scripts/01_fetch_friend_trades.py`
- `sql/schema.sql`
- `data/transactions_sample.json`
- `data/token_trades_sample.json`
- `data/full_pnl_sample.json`
- `data/token_pnl_sample.json`
- `data/dev_summary_sample.json`

## Excluded

- `venv/`
- `.env`
- `data/friend_raw/`
- 完整 `data/*.json` 和 `data/*.csv`
- 任何真实 API key、私钥、助记词或身份可关联信息

## Notes

- `scripts/01_fetch_friend_trades.py` 已改为通过环境变量读取 `FRIEND_WALLET`，避免硬编码真实地址。
- `data/*sample*.json` 仅保留最小结构化样例，便于查看字段、调用关系和 PnL 结果格式。
- 如果要在本目录复现脚本运行，请先复制 `.env.example` 为 `.env` 并填入自己的配置。

## Questions This Export Supports

1. 它怎么抓 Solana 交易
2. 它怎么解析 buy / sell
3. 它怎么计算 PnL
4. 它怎么识别 dev / friend / token
5. 它的数据表设计是否能迁移到多链系统
6. 有没有实时监听、priority fee、滑点、失败重试、卖出逻辑
