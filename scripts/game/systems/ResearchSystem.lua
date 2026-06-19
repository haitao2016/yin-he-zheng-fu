---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-----------------------------------------------------------
-- ResearchSystem (从 Systems.lua 机械拆分)
-----------------------------------------------------------
require("game.GameConstants")

local ResearchSystem = {}
ResearchSystem.__index = ResearchSystem

---@param rm table  ResourceManager 实例
---@param bs table  BuildingSystem 实例
---@return ResearchSystem
function ResearchSystem.new(rm, bs)
    local self = setmetatable({ rm=rm, bs=bs, planetGetter=nil }, ResearchSystem)
    self.unlocked = {}
    self.active   = nil
    self.onCompleteCallback = nil  -- P2-P1-1: 研究完成动画回调
    return self
end

--- P2-P1-1: 设置研究完成动画回调
---@param fn function
function ResearchSystem:setOnCompleteCallback(fn)
    self.onCompleteCallback = fn
end

--- P2-6: 记录当前基地核心等级（用于 Tier5 科技解锁校验）
---@param lv number
function ResearchSystem:setCoreLevel(lv)
    if self.rm then self.rm.coreLevel = lv end
end

--- 设置动态行星列表获取函数（每次科技完成时调用，确保包含新殖民的行星）
---@param fn function
function ResearchSystem:setPlanetGetter(fn)
    self.planetGetter = fn
end

---@param id string  科技 ID
---@return boolean, string  可研究? 以及原因
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
    -- P2-6: Tier5 科技基地核心等级前置检查
    if t.coreLevelReq then
        local lv = (self.rm and self.rm.coreLevel) or 1
        if lv < t.coreLevelReq then
            return false, "需要基地核心Lv." .. t.coreLevelReq
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
---@param id string
---@return boolean
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

---@param id string  科技 ID
---@return boolean, string
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

---@param dt number  距上次更新的时间（秒）
---@return string|nil  完成的科技 ID 或 nil
function ResearchSystem:update(dt)
    if not self.active then return nil end
    -- S1 QUANTUM_CORE: researchSpeedMult 与科研中心的 researchMult 叠乘
    local speedMult = ((self.rm.baseBonus and self.rm.baseBonus.researchMult) or 1.0)
                    * ((self.rm.baseBonus and self.rm.baseBonus.researchSpeedMult) or 1.0)
    -- P2-4: 行星科研站加成（由 BuildingSystem 聚合）
    if self.planetGetter and self.bs and self.bs.aggregatePlanetEffects then
        local pe = self.bs:aggregatePlanetEffects(self.planetGetter())
        speedMult = speedMult * (1 + (pe.researchSpeedBonus or 0))
    end
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
            if bonus.fleetSpeedMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.fleetSpeedMult = (self.rm.baseBonus.fleetSpeedMult or 1.0) * bonus.fleetSpeedMult
                print("[Research] 曲速引擎激活：舰队速度×" .. tostring(self.rm.baseBonus.fleetSpeedMult))
            end
            if bonus.shieldBonus then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldBonus  = (self.rm.baseBonus.shieldBonus  or 0) + bonus.shieldBonus
                self.rm.baseBonus.defenseBonus = (self.rm.baseBonus.defenseBonus or 0) + bonus.defenseBonus
                print("[Research] 护盾强化激活：护盾+" .. tostring(bonus.shieldBonus))
            end
            -- P1-1: NOVA_CANNON
            if bonus.aoeRadiusMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.aoeRadiusMult = (self.rm.baseBonus.aoeRadiusMult or 1.0) * bonus.aoeRadiusMult
                print("[Research] 新星炮激活：AOE半径×" .. tostring(self.rm.baseBonus.aoeRadiusMult))
            end
            if bonus.battleStartSkillCharge then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.battleStartSkillCharge = (self.rm.baseBonus.battleStartSkillCharge or 0) + bonus.battleStartSkillCharge
                print("[Research] 新星炮激活：每波战斗开始额外技能充能+" .. tostring(bonus.battleStartSkillCharge))
            end
            -- P1-1: FORTRESS_PROTOCOL
            if bonus.shieldMaxMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldMaxMult = (self.rm.baseBonus.shieldMaxMult or 1.0) * bonus.shieldMaxMult
                print("[Research] 要塞协议激活：护盾上限×" .. tostring(self.rm.baseBonus.shieldMaxMult))
            end
            if bonus.shieldRegenPct then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldRegenPct = (self.rm.baseBonus.shieldRegenPct or 0) + bonus.shieldRegenPct
                print("[Research] 要塞协议激活：战斗中护盾每10s回复" .. tostring(bonus.shieldRegenPct * 100) .. "%")
            end
            -- P1-3: VOID_ANCHOR
            if bonus.enemySpeedDebuff then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.enemySpeedDebuff = (self.rm.baseBonus.enemySpeedDebuff or 1.0) * bonus.enemySpeedDebuff
                print("[Research] 虚空锚定激活：敌方舰队速度×" .. tostring(self.rm.baseBonus.enemySpeedDebuff))
            end
            -- P1-3: STELLAR_SYNC
            if bonus.globalProdMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.globalProdMult = (self.rm.baseBonus.globalProdMult or 1.0) * bonus.globalProdMult
                print("[Research] 星际同步激活：全局产出×" .. tostring(self.rm.baseBonus.globalProdMult))
            end
            -- P2-6: QUANTUM_FACTORY 舰船建造速度 ×
            if bonus.shipyardSpeedMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shipyardMult = (self.rm.baseBonus.shipyardMult or 1.0) * bonus.shipyardSpeedMult
                print("[Research] 量子工厂激活：舰船建造速度×" .. tostring(self.rm.baseBonus.shipyardMult))
            end
            -- P2-6: QUANTUM_FACTORY 升级费用 -25%
            if bonus.upgradeCostMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.upgradeCostMult = (self.rm.baseBonus.upgradeCostMult or 1.0) * bonus.upgradeCostMult
                print("[Research] 量子工厂激活：升级费用×" .. tostring(self.rm.baseBonus.upgradeCostMult))
            end
            -- P2-6: GALACTIC_ASCEND 全局伤害倍率
            if bonus.globalDmgMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.globalDmgMult = (self.rm.baseBonus.globalDmgMult or 1.0) * bonus.globalDmgMult
                print("[Research] 文明飞跃激活：全局伤害×" .. tostring(self.rm.baseBonus.globalDmgMult))
            end
            -- P2-6: GALACTIC_ASCEND 舰队上限 +3
            if bonus.fleetCapBonus then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.fleetCapBonus = (self.rm.baseBonus.fleetCapBonus or 0) + bonus.fleetCapBonus
                print("[Research] 文明飞跃激活：舰队上限+" .. tostring(self.rm.baseBonus.fleetCapBonus))
            end
            -- P2-6: GALACTIC_ASCEND 每波技能点 +1
            if bonus.skillPointBonus then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.skillPointBonus = (self.rm.baseBonus.skillPointBonus or 0) + bonus.skillPointBonus
                print("[Research] 文明飞跃激活：每波技能点+" .. tostring(bonus.skillPointBonus))
            end
            -- P0-1: PHASE_DRIVE 隐形能力
            if bonus.stealthEnabled then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.stealthEnabled = true
                print("[Research] 相位驱动激活：舰队获得隐形能力")
            end
            -- P0-1: STELLAR_ENGINE 战斗开局加速
            if bonus.battleStartSpeedBoost then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.battleStartSpeedBoost = (self.rm.baseBonus.battleStartSpeedBoost or 0) + bonus.battleStartSpeedBoost
                print("[Research] 恒星引擎激活：战斗开局速度+" .. tostring(bonus.battleStartSpeedBoost))
            end
            -- P0-1: VOID_FLEET 敌舰生成减少
            if bonus.enemySpawnMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.enemySpawnMult = (self.rm.baseBonus.enemySpawnMult or 1.0) * bonus.enemySpawnMult
                print("[Research] 虚空舰队激活：敌舰生成×" .. tostring(bonus.enemySpawnMult))
            end
            -- P0-1: CHRONO_RESEARCH 事件频率
            if bonus.eventFrequencyMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.eventFrequencyMult = (self.rm.baseBonus.eventFrequencyMult or 1.0) * bonus.eventFrequencyMult
                print("[Research] 时序研究激活：事件频率×" .. tostring(bonus.eventFrequencyMult))
            end
            -- P0-1: GALACTIC_ASCEND 奖励翻倍
            if bonus.rewardMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.rewardMult = (self.rm.baseBonus.rewardMult or 1.0) * bonus.rewardMult
                print("[Research] 银河飞升激活：奖励×" .. tostring(bonus.rewardMult))
            end
            -- P0-1: FORTRESS_PROTOCOL_II 反击护盾
            if bonus.counterShield then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.counterShield = true
                print("[Research] 要塞协议II激活：反击护盾已解锁")
            end
            -- P0-1: 基地护盾恢复
            if bonus.shieldFlat then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.shieldFlat = (self.rm.baseBonus.shieldFlat or 0) + bonus.shieldFlat
            end
            -- P0-1: 殖民速度 + 资源上限 (COLONY_BIOTECH)
            if bonus.colonySpeedMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.colonySpeedMult = (self.rm.baseBonus.colonySpeedMult or 1.0) * bonus.colonySpeedMult
            end
            if bonus.resourceCapMult then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.resourceCapMult = (self.rm.baseBonus.resourceCapMult or 1.0) * bonus.resourceCapMult
            end
            -- P0-1: 战斗中生命恢复 (NANO_REPAIR)
            if bonus.battleRegenPct then
                self.rm.baseBonus = self.rm.baseBonus or {}
                self.rm.baseBonus.battleRegenPct = (self.rm.baseBonus.battleRegenPct or 0) + bonus.battleRegenPct
            end
        end
        -- P2-P1-1: 研究完成动画回调
        if self.onCompleteCallback then
            self:onCompleteCallback(id, TECHS[id])
        end
        print("[Research] 完成: " .. TECHS[id].name)
        return id
    end
    return nil
end

-- 序列化 / 反序列化
---@return table
function ResearchSystem:serialize()
    local unlockedList = {}
    for id, _ in pairs(self.unlocked) do unlockedList[#unlockedList+1] = id end
    local active = nil
    if self.active then active = { id=self.active.id, remaining=self.active.remaining, totalTime=self.active.totalTime } end
    return { unlocked = unlockedList, active = active }
end

---@param data table
function ResearchSystem:deserialize(data)
    if not data then return end
    self.unlocked = {}
    if data.unlocked then for _, id in ipairs(data.unlocked) do self.unlocked[id] = true end end
    self.active = nil
    if data.active then self.active = { id=data.active.id, remaining=data.active.remaining, totalTime=data.active.totalTime, progress=1.0-(data.active.remaining/math.max(1,data.active.totalTime)) } end
end

return ResearchSystem
