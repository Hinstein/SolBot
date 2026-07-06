-- ============================================================
-- Solana Dev Alpha Bot - 数据库 Schema v1.1
-- 优化版：添加了 failure_pattern / 多标签 / 资金溯源等
-- ============================================================

-- 1. 朋友交易记录（多标签版）
CREATE TABLE IF NOT EXISTS friend_trade (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    friend_wallet TEXT NOT NULL,
    token_mint TEXT NOT NULL,
    token_name TEXT,
    token_symbol TEXT,
    buy_time TEXT,
    sell_time TEXT,
    hold_seconds INTEGER,
    buy_amount_sol REAL,
    sell_amount_sol REAL,
    pnl_sol REAL,
    roi REAL,
    buy_rank INTEGER,
    seconds_after_launch INTEGER,
    buy_mcap REAL,
    sell_mcap REAL,
    peak_mcap_after_buy REAL,
    max_roi_after_buy REAL,
    max_drawdown_after_buy REAL,
    dev_address TEXT,
    -- 优化3: 多标签分类
    action_type TEXT,       -- sniper / relay / heavy_hold / scalp
    position_size TEXT,     -- small / medium / heavy
    hold_policy TEXT,       -- fast_exit / trail_stop / to_migration / panic_exit
    entry_timing TEXT,      -- instant / wave2 / dip_buy
    exit_reason TEXT,       -- dev_sold / smart_money_exit / volume_collapse / trailing_stop / manual
    review_note TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(token_mint, buy_time)
);

-- 2. Dev 资料库（含资金溯源）
CREATE TABLE IF NOT EXISTS dev_profile (
    dev_address TEXT PRIMARY KEY,
    dev_cluster_id TEXT,
    -- 优化5: 资金溯源
    funding_source_type TEXT,      -- CEX_fresh / DEX_fresh / old_wallet / mixer / from_another_dev
    funding_source_address TEXT,   -- 资金来源地址
    wallet_age_at_launch INTEGER,  -- 发币时钱包年龄（天）
    pre_launch_tx_count INTEGER,   -- 发币前交易数
    previous_rug_count INTEGER,    -- 历史 rug 次数（跨号追溯）
    -- 原字段
    first_seen_at TEXT,
    last_seen_at TEXT,
    launch_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    rug_count INTEGER DEFAULT 0,
    success_rate REAL,
    rug_rate REAL,
    avg_peak_mcap REAL,
    median_peak_mcap REAL,
    max_peak_mcap REAL,
    migration_count INTEGER DEFAULT 0,
    migration_rate REAL,
    avg_lifetime_seconds REAL,
    avg_dev_sell_delay REAL,
    recent_7d_score REAL,
    recent_30d_score REAL,
    dev_score REAL,
    dev_tag TEXT,
    risk_level TEXT,
    is_blacklisted INTEGER DEFAULT 0,
    notes TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 3. Dev 集群
CREATE TABLE IF NOT EXISTS dev_cluster (
    cluster_id TEXT PRIMARY KEY,
    main_funding_wallet TEXT,
    related_dev_wallets TEXT,        -- JSON array
    related_first_buyers TEXT,       -- JSON array
    related_profit_wallets TEXT,     -- JSON array
    cluster_launch_count INTEGER DEFAULT 0,
    cluster_success_count INTEGER DEFAULT 0,
    cluster_success_rate REAL,
    cluster_rug_rate REAL,
    cluster_avg_peak_mcap REAL,
    cluster_recent_score REAL,
    cluster_tag TEXT,
    cluster_status TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 4. 钱包资料库
CREATE TABLE IF NOT EXISTS wallet_profile (
    wallet_address TEXT PRIMARY KEY,
    wallet_type TEXT,                -- smart_money / sniper / insider / bundle / dev_follower / exit_leader / fake_smart_money
    first_seen_at TEXT,
    early_entry_count INTEGER DEFAULT 0,
    win_count INTEGER DEFAULT 0,
    loss_count INTEGER DEFAULT 0,
    win_rate REAL,
    avg_roi REAL,
    median_roi REAL,
    max_roi REAL,
    avg_hold_time REAL,
    fast_exit_rate REAL,
    early_entry_rate REAL,
    rug_survival_rate REAL,
    smart_money_score REAL,
    sniper_score REAL,
    insider_score REAL,
    bundle_score REAL,
    is_blacklisted INTEGER DEFAULT 0,
    notes TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 5. Token 发行记录
CREATE TABLE IF NOT EXISTS token_launch (
    token_mint TEXT PRIMARY KEY,
    token_name TEXT,
    token_symbol TEXT,
    creator_address TEXT,
    dev_cluster_id TEXT,
    created_at_ts TEXT,
    launch_source TEXT,              -- pump_fun / pump_swap / raydium
    initial_liquidity REAL,
    creator_holdings REAL,
    bonding_curve_progress REAL,
    migration_status TEXT,
    peak_mcap REAL,
    peak_roi REAL,
    lifetime_seconds INTEGER,
    rug_status TEXT,
    final_status TEXT,
    created_at_db TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 6. 开盘结构快照（新增超短窗口）
CREATE TABLE IF NOT EXISTS launch_snapshot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_mint TEXT NOT NULL,
    timestamp TEXT,
    -- 优化4: 超短窗口
    snapshot_at_3s REAL,             -- 3秒快照
    snapshot_at_5s REAL,             -- 5秒快照
    snapshot_at_10s REAL,
    snapshot_at_30s REAL,
    snapshot_at_60s REAL,
    snapshot_at_3m REAL,
    snapshot_at_5m REAL,
    snapshot_at_10m REAL,
    -- 各窗口数据
    buys_3s INTEGER,
    buy_volume_3s REAL,
    buys_5s INTEGER,
    buy_volume_5s REAL,
    buys_10s INTEGER,
    buy_volume_10s REAL,
    buys_30s INTEGER,
    buy_volume_30s REAL,
    buys_60s INTEGER,
    buy_volume_60s REAL,
    unique_buyers_3s INTEGER,
    unique_buyers_10s INTEGER,
    unique_buyers_60s INTEGER,
    volume_decay_3s_to_10s REAL,     -- 衰减率
    dev_sell_3s INTEGER DEFAULT 0,
    dev_sell_10s INTEGER DEFAULT 0,
    dev_sell_30s INTEGER DEFAULT 0,
    buy_sell_ratio REAL,
    smart_money_count INTEGER,
    sniper_count INTEGER,
    insider_ratio REAL,
    bundle_ratio REAL,
    fresh_wallet_ratio REAL,
    top_holder_concentration REAL,
    dev_hold_ratio REAL,
    bonding_curve_progress REAL,
    entry_score REAL,
    risk_score REAL,
    friend_similarity_score REAL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 7. 模拟交易（新增反事实基准）
CREATE TABLE IF NOT EXISTS simulated_trade (
    trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_mint TEXT NOT NULL,
    signal_time TEXT,
    entry_price REAL,
    entry_mcap REAL,
    entry_score REAL,
    risk_score REAL,
    friend_similarity_score REAL,
    simulated_position_size REAL,
    exit_strategy TEXT,              -- A / B / C
    max_profit_pct REAL,
    max_drawdown_pct REAL,
    exit_price REAL,
    exit_time TEXT,
    realized_pnl REAL,
    best_exit_time TEXT,
    best_exit_profit REAL,
    -- 优化6: 反事实基准
    benchmark_roi REAL,              -- 同期同类 token 平均 ROI
    excess_roi REAL,                 -- 超额收益
    market_heat_at_entry REAL,
    benchmark_token_count INTEGER,
    failure_reason TEXT,
    review_status TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 8. 每日复盘
CREATE TABLE IF NOT EXISTS daily_review (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT UNIQUE,
    total_tokens_scanned INTEGER,
    total_signals INTEGER,
    simulated_trades INTEGER,
    win_rate REAL,
    avg_roi REAL,
    max_roi REAL,
    max_drawdown REAL,
    best_dev_clusters TEXT,          -- JSON
    worst_dev_clusters TEXT,         -- JSON
    best_wallets TEXT,               -- JSON
    fake_smart_money TEXT,           -- JSON
    best_entry_pattern TEXT,
    worst_entry_pattern TEXT,
    recommended_rule_changes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 9. 优化2: 反向案例库
CREATE TABLE IF NOT EXISTS failure_pattern (
    pattern_id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_name TEXT NOT NULL,          -- 例如"新号秒砸"、"前排全是老鼠仓"
    dev_is_new INTEGER,                  -- dev 是否新号
    first_5_all_fresh INTEGER,           -- 前5买家是否全是新钱包
    buy_volume_collapse_3s REAL,         -- 3s后买盘衰减率
    dev_sell_in_30s INTEGER,             -- dev是否30s内卖出
    top_holder_concentration REAL,       -- 大户集中度
    bundle_ratio_high INTEGER,           -- 捆绑比例是否过高
    avg_buy_volume_small INTEGER,        -- 平均买入金额是否过小
    insider_ratio_high INTEGER,          -- 内盘比例是否过高
    occurrence_count INTEGER DEFAULT 0,  -- 该模式出现次数
    failure_rate REAL,                   -- 导致亏损的比例
    is_blacklisted INTEGER DEFAULT 0,    -- 是否加入硬过滤
    notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);
