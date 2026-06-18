-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function BattleScene.Init(opts)
    vg_          = opts.vg
    notifyFn_    = opts.notifyFn
    onBattleEnd_ = opts.onBattleEnd
    player_      = opts.player
    rm_          = opts.rm
    rs_          = opts.rs
    spq_         = opts.spq
    moduleMap_   = opts.moduleMap or {}  -- P1-1: 改装模块映射
    mutantMap_   = opts.mutantMap or {}  -- P1-2 V2.5: 变异舰船映射
    leagueAttackMult_ = opts.leagueAttackMult or 1.0  -- P1-3: 联赛敌人攻击力修正
    pendingShips_= {}
    -- 海盗进攻时从指定波次开始（pirateLevel 1~5 对应 wave 1~5）
    waveNum_     = math.max(1, opts.startWave or 1)
    -- P2-3: 无尽模式层数（用于判断里程碑 Boss）
    endlessRound_ = opts.endlessRound or 0
