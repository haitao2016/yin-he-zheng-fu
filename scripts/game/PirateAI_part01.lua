-- Auto-split from PirateAI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function PirateAI.new(opts)
    local self = setmetatable({}, PirateAI)
    self.notifyFn      = opts.notifyFn      -- function(msg, level)
    self.onAttack      = opts.onAttack      -- function(pirateLevel, baseId) 海盗舰队到达玩家目标时触发
    self.getTargets    = opts.getTargets    -- function() → [{x,y,name}] 玩家可被攻击的位置列表
    self.getProgress   = opts.getProgress   -- function() → {colonized, gameTime, piratesKilled}
    self.bases         = {}                 -- 海盗基地列表
    self.fleets        = {}                 -- 活跃海盗舰队列表
    self.recoverTimer  = 0
    -- 难度参数
    self.attackIntervalFactor = opts.attackIntervalFactor or 1.0  -- 进攻间隔倍率（简单>1, 困难<1）
    self.maxThreatLevel       = opts.maxThreatLevel       or 5    -- 威胁等级上限
    -- 动态难度状态
    self.threatTimer   = 0                  -- 距下次威胁检查计时
    self.streakKills   = 0                  -- 自上次 escalation 后连续击败次数
    self.skipCount     = 0                  -- 因连击缓冲跳过的 escalation 次数
    return self
end
