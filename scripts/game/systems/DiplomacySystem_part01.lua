-- Auto-split from DiplomacySystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function DiplomacySystem.new()
    local self = setmetatable({}, DiplomacySystem)
    -- planetId → { factionKey, favor(0-100), tradeTimer, atWar, military }
    self.planets = {}
    -- P1-1: 三角关系（两两之间：compete/neutral/cooperate）
    self.triangleRels = {}  -- { "trade_union:star_guild" = "compete", ... }
    -- P1-1: 新协议状态
    self.alliances   = {}   -- { factionKey = true } 军事同盟
    self.blockades   = {}   -- { factionKey = remainTime } 封锁中
    self.intelShares = {}   -- { factionKey = true } 情报共享
    -- P1-1: 外交事件计时器
    self.diploEventTimer = 0
    return self
end
