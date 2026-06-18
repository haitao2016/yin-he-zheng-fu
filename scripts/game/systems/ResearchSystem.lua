---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-----------------------------------------------------------
-- ResearchSystem (从 Systems.lua 机械拆分)
-----------------------------------------------------------
require("game.GameConstants")

local ResearchSystem = {}
ResearchSystem.__index = ResearchSystem

function ResearchSystem.new(rm, bs)
    local self = setmetatable({ rm=rm, bs=bs, planetGetter=nil }, ResearchSystem)
    self.unlocked = {}
    self.active   = nil
    return self
end

--- 设置动态行星列表获取函数（每次科技完成时调用，确保包含新殖民的行星）
function ResearchSystem:setPlanetGetter(fn)
    self.planetGetter = fn
end

function ResearchSystem:canResearch(id)
    local t = TECHS[id]
    if not t then return false, "未知科技" end
    if self.unlocked[id] then return false, "已完成" end
    if self.active        then return false, "研究中" end
    for _, pre in ipairs(t.prereqs) do
        if not self.unlocked[pre] then return false, "需先完成: " .. TECHS[pre].name end
    end
    -- P1-1: 互斥分组检查（同组内已解锁其他科技则封锁）
    if t.exclusiveGroup then
        for otherId, otherT in pairs(TECHS) do
            if otherId ~= id and otherT.exclusiveGroup == t.exclusiveGroup
               and self.unlocked[otherId] then
                return false, "与 " .. otherT.name .. " 互斥（只能选一）"
            end
        end
    end
    if not self.rm:canAfford(t.cost) then return false, "资源不足" end
    return true, ""
end

--- P1-1: 检查科技是否被互斥锁定（已有同组其他科技解锁）
---@param id string
---@return boolean  true = 被互斥封锁
function ResearchSystem:isExcluded(id)
    local t = TECHS[id]
    if not t or not t.exclusiveGroup then return false end
    if self.unlocked[id] then return false end
    for otherId, otherT in pairs(TECHS) do
        if otherId ~= id and otherT.exclusiveGroup == t.exclusiveGroup
           and self.unlocked[otherId] then
            return true
        end
    end
    return false
end

-- 前置科技是否全部完成（不检查资源）
function ResearchSystem:prereqsMet(id)
    local t = TECHS[id]
    if not t then return false end
    if self.unlocked[id] then return false end
    if self.active        then return false end
    for _, pre in ipairs(t.prereqs) do
        if not self.unlocked[pre] then return false end
    end
    return true
end

function ResearchSystem:start(id)
    local ok, reason = self:canResearch(id)
    if not ok then return false, reason end
    self.rm:spend(TECHS[id].cost)
    self.active = {
        id=id,
        remaining=TECHS[id].time,
        totalTime=TECHS[id].time,
        progress=0
    }
    return true, ""
end

function ResearchSystem:update(dt)
    if not self.active then return nil end
    -- S1 QUANTUM_CORE: researchSpeedMult 与科研中心的 researchMult 叠乘
    local speedMult = ((self.rm.baseBonus and self.rm.baseBonus.researchMult) or 1.0)
                    * ((self.rm.baseBonus and self.rm.baseBonus.researchSpeedMult) or 1.0)
    self.active.remaining = self.active.remaining - dt * speedMult
    self.active.progress  = 1.0 - math.max(0, self.active.remaining) / self.active.totalTime
    if self.active.remaining <= 0 then
        local id = self.active.id
        self.unlocked[id] = true
        self.active = nil
        -- 通过 getter 动态获取所有行星（包含最新殖民的）并应用科技加成
        if self.planetGetter then
            local planets = self.planetGetter()
            for _, p in ipairs(planets) do
                if p.colonized then
                    self.bs:applyTechBonus(p, id)
                end
            end
        end
        -- 应用特殊科技效果到 baseBonus
        local bonus = TECHS[id] and TECHS[id].bonus
        if bonus then
            self.rm.baseBonus = self.rm.baseBonus or {}
            local bb = self.rm.baseBonus

            local function applyMult(key, label)
                if bonus[key] then
                    bb[key] = (bb[key] or 1.0) * bonus[key]
                    print("[Research] " .. label .. "：×" .. tostring(bb[key]))
                end
            end

            local function applyAdd(key, label)
                if bonus[key] then
                    bb[key] = (bb[key] or 0) + bonus[key]
                    print("[Research] " .. label .. "：+" .. tostring(bonus[key]))
                end
            end

            applyMult("fleetSpeedMult",      "曲速引擎激活：舰队速度")
            applyMult("aoeRadiusMult",       "新星炮激活：AOE半径")
            applyMult("shieldMaxMult",       "要塞协议激活：护盾上限")
            applyMult("enemySpeedDebuff",    "虚空锚定激活：敌方舰队速度")
            applyMult("globalProdMult",      "星际同步激活：全局产出")
            applyMult("researchSpeedMult",   "科研速度加成")

            applyAdd("battleStartSkillCharge", "新星炮激活：每波战斗开始额外技能充能")
            applyAdd("shieldRegenPct",         "要塞协议激活：战斗中护盾每10s回复" .. (bonus.shieldRegenPct and tostring(bonus.shieldRegenPct * 100) .. "%" or ""))

            if bonus.shieldBonus then
                bb.shieldBonus  = (bb.shieldBonus  or 0) + bonus.shieldBonus
                bb.defenseBonus = (bb.defenseBonus or 0) + (bonus.defenseBonus or 0)
                print("[Research] 护盾强化激活：护盾+" .. tostring(bonus.shieldBonus))
            end
        end
        print("[Research] 完成: " .. TECHS[id].name)
        return id
    end
    return nil
end

-- 序列化 / 反序列化
function ResearchSystem:serialize()
    local unlockedList = {}
    for id, _ in pairs(self.unlocked) do unlockedList[#unlockedList+1] = id end
    local active = nil
    if self.active then active = { id=self.active.id, remaining=self.active.remaining, totalTime=self.active.totalTime } end
    return { unlocked = unlockedList, active = active }
end

function ResearchSystem:deserialize(data)
    if not data then return end
    self.unlocked = {}
    if data.unlocked then for _, id in ipairs(data.unlocked) do self.unlocked[id] = true end end
    self.active = nil
    if data.active then self.active = { id=data.active.id, remaining=data.active.remaining, totalTime=data.active.totalTime, progress=1.0-(data.active.remaining/math.max(1,data.active.totalTime)) } end
end

return ResearchSystem
