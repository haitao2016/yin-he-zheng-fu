---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--- PlayerProfile — 玩家等级与档案系统
--- 从 Systems.lua 机械拆分，无逻辑修改
require("game.GameConstants")

local PlayerProfile = {}
PlayerProfile.__index = PlayerProfile

---@return PlayerProfile
function PlayerProfile.new()
    local self = setmetatable({}, PlayerProfile)
    local n = tostring(GetLoginName() or "")
    self.name      = (n ~= "" and n ~= "(?)") and n or "玩家"
    self.level     = 1
    self.exp       = 0
    self.rankIdx   = 1
    self.rank      = RANKS[1]
    self.alliance  = "无联盟"
    self.colonized = 0
    self.battles   = 0
    self.wins      = 0
    return self
end

-- 等级奖励表：每级给予的资源奖励
local LEVEL_REWARDS = {
    -- 每隔5级有大奖励，其余给小奖励
    default  = { metal=500,  esource=300,  nuclear=50  },
    milestone= { metal=2000, esource=1000, nuclear=200 },  -- 5/10/15/20级
}

---@param amount number
---@return boolean, number|nil, string|nil, table|nil
function PlayerProfile:addExp(amount)
    self.exp = self.exp + amount
    local rewards = nil
    while self.exp >= self.level * EXP_PER_LEVEL do
        self.exp   = self.exp - self.level * EXP_PER_LEVEL
        self.level = self.level + 1
        -- 5的倍数为里程碑大奖励，否则普通奖励
        local r = (self.level % 5 == 0) and LEVEL_REWARDS.milestone or LEVEL_REWARDS.default
        -- 累计奖励（可能连续升多级）
        if not rewards then
            rewards = { metal=0, esource=0, nuclear=0 }
        end
        rewards.metal   = rewards.metal   + r.metal
        rewards.esource = rewards.esource + r.esource
        rewards.nuclear = rewards.nuclear + r.nuclear
    end
    if rewards then
        local idx    = math.min(math.floor(self.level / 5) + 1, #RANKS)  -- L1: (level-1)/5 偏差1级，改为 level/5，Lv5晋升第2阶
        self.rankIdx = idx
        self.rank    = RANKS[idx]
        print("[Profile] 晋升! Lv." .. self.level .. "  " .. self.rank)
        return true, self.level, self.rank, rewards
    end
    return false
end

--- 序列化
---@return table
function PlayerProfile:serialize()
    return {
        level     = self.level,
        exp       = self.exp,
        rankIdx   = self.rankIdx,
        colonized = self.colonized,
        battles   = self.battles,
        wins      = self.wins,
    }
end

--- 从存档恢复
---@param data table
function PlayerProfile:deserialize(data)
    if not data then return end
    self.level     = data.level     or 1
    self.exp       = data.exp       or 0
    self.rankIdx   = data.rankIdx   or 1
    self.rank      = RANKS[math.min(self.rankIdx, #RANKS)]
    self.colonized = data.colonized or 0
    self.battles   = data.battles   or 0
    self.wins      = data.wins      or 0
end

return PlayerProfile
