---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-----------------------------------------------------------
-- BuildingSystem (从 Systems.lua 机械拆分)
-----------------------------------------------------------
require("game.GameConstants")

local BuildingSystem = {}
BuildingSystem.__index = BuildingSystem

---@param rm table  ResourceManager 实例
---@return BuildingSystem
function BuildingSystem.new(rm)
    return setmetatable({ rm=rm }, BuildingSystem)
end

---@param key string  建筑类型 key
---@param level number 当前等级
---@return table  升级所需资源表
function BuildingSystem:getUpgradeCost(key, level)
    local bd   = BUILDINGS[key]
    local cost = {}
    local m    = bd.upgradeK ^ level
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    for res, base in pairs(bd.cost) do
        cost[res] = math.max(1, math.floor(base * m * bcm))
    end
    return cost
end

--- P1-3: 获取建筑显示名称（供 UI 渲染队列条目时使用）
---@param key string
---@return string
function BuildingSystem:getBuildingName(key)
    return BUILDINGS[key] and BUILDINGS[key].name or key
end

--- P2-3: 获取建筑类型可用专精列表
---@param key string
---@return table
function BuildingSystem:getSpecsForBuilding(key)
    return BUILDING_SPECS[key] or {}
end

--- 获取指定建筑在星球上的累计等级（某类建筑可能有多个，但目前每类一个）
---@param key string
---@param planet table
---@return number
function BuildingSystem:getBuildingLevelOn(key, planet)
    if not planet or not planet.buildings then return 0 end
    for _, b in ipairs(planet.buildings) do
        if b.key == key then return b.level or 1 end
    end
    return 0
end

--- 汇总所有已殖民行星上指定类型建筑的累计等级（用于全局效果）
---@param key string
---@param planets table
---@return number
function BuildingSystem:getTotalLevelAcrossPlanets(key, planets)
    if not planets then return 0 end
    local total = 0
    for _, p in ipairs(planets) do
        total = total + self:getBuildingLevelOn(key, p)
    end
    return total
end

--- 获取新建筑的文本描述（供 UI 按钮提示）
---@param key string
---@return string
function BuildingSystem:getBuildingDescription(key)
    local bd = BUILDINGS[key]
    if not bd then return "" end
    if key == "DEFENSE_TURRET" then
        return string.format("炮塔×2+1/级 Dmg%d R%d %.1fs", bd.turretDmg, bd.turretRange, bd.turretRate)
    elseif key == "ADVANCED_REFINERY" then
        return string.format("精炼×%.1f 稀有%.0f%%", bd.refineBonus, (bd.rareChance or 0)*100)
    elseif key == "RESEARCH_STATION" then
        return string.format("科研+%.0f%% 点×%.2f", (bd.researchBonus or 0)*100, bd.researchMult or 1.0)
    elseif key == "STARGATE_NODE" then
        return string.format("瞬移 %ds CD", bd.teleportCooldown or 60)
    elseif key == "SHIELD_GEN" then
        return string.format("护盾+%d", bd.shieldBonus or 200)
    elseif key == "TRADE_HUB" then
        return string.format("星币+%d/s", (bd.prod and bd.prod.credits) or 0)
    end
    return ""
end

--- 聚合新建筑提供的全局修正（由资源/科研/战斗系统在每帧或事件时调用）
---@param planets table
---@return table
function BuildingSystem:aggregatePlanetEffects(planets)
    local eff = {
        refineMult         = 1.0,
        researchSpeedBonus = 0.0,
        researchPointMult  = 1.0,
        turretCount        = 0,
        shieldBonus        = 0,
        teleportEnabled    = false,
        teleportCooldown   = 60,
        rareChance         = 0.0,
    }
    if not planets then return eff end
    for _, p in ipairs(planets) do
        if not p.buildings then goto nextPlanet end
        for _, b in ipairs(p.buildings) do
            local bd = BUILDINGS[b.key]
            if not bd then goto nextBuilding end
            local lv = b.level or 1
            if b.key == "DEFENSE_TURRET" then
                eff.turretCount = eff.turretCount + (1 + lv)   -- Lv1 = 2, Lv2 = 3, ...
            elseif b.key == "ADVANCED_REFINERY" then
                eff.refineMult = eff.refineMult * (1 + (bd.refineBonus - 1) * lv)
                eff.rareChance = eff.rareChance + (bd.rareChance or 0) * lv
            elseif b.key == "RESEARCH_STATION" then
                eff.researchSpeedBonus = eff.researchSpeedBonus + (bd.researchBonus or 0) * lv
                eff.researchPointMult  = eff.researchPointMult * (1 + ((bd.researchMult or 1) - 1) * lv)
            elseif b.key == "STARGATE_NODE" then
                eff.teleportEnabled = true
                eff.teleportCooldown = math.min(eff.teleportCooldown, bd.teleportCooldown or 60)
            elseif b.key == "SHIELD_GEN" then
                eff.shieldBonus = eff.shieldBonus + (bd.shieldBonus or 200) * lv
            end
            ::nextBuilding::
        end
        ::nextPlanet::
    end
    return eff
end

--- 获取防御炮塔配置（战斗中生成友方炮塔用）
---@return table
function BuildingSystem:getTurretStats()
    local bd = BUILDINGS.DEFENSE_TURRET
    if not bd then return { dmg = 25, range = 300, rate = 1.5, hp = 100 } end
    return { dmg = bd.turretDmg, range = bd.turretRange, rate = bd.turretRate, hp = 100 }
end

--- P2-3: 查找专精定义（按建筑类型 key + 专精 key）
---@param bKey string
---@param specKey string
---@return table|nil
function BuildingSystem:findSpec(bKey, specKey)
    for _, sp in ipairs(BUILDING_SPECS[bKey] or {}) do
        if sp.key == specKey then return sp end
    end
    return nil
end

--- P2-3: 重算单个建筑产量（科技倍率 + 专精效果）
--- 会先撤销旧贡献再写入新值到 rm.rates
---@param b table
---@param planet table
function BuildingSystem:_recalcBuildingProd(b, planet)
    local bd = BUILDINGS[b.key]
    if not bd then return end
    -- 撤销旧产量贡献
    for res, old in pairs(b.currentProd or {}) do
        self.rm.rates[res] = math.max(0, (self.rm.rates[res] or 0) - old)
    end
    b.currentProd = {}
    -- 科技倍率
    local techMult = 1.0
    if planet.appliedTechs then
        for techId in pairs(planet.appliedTechs) do
            local bonus = TECHS[techId] and TECHS[techId].bonus
            if bonus and bonus.building == b.key then
                techMult = bonus.prodMult; break
            end
        end
    end
    -- 专精效果
    local specEffect = nil
    if b.spec then
        local sp = self:findSpec(b.key, b.spec)
        if sp then specEffect = sp.effect end
    end
    -- P1-2: 星球等级产量加成（每级 +5%，乘算）
    local planetLevelMult = 1.0 + ((planet.level or 1) - 1) * 0.05
    for res, rate in pairs(bd.prod) do
        local val = math.floor(rate * b.level * techMult * planetLevelMult)
        if specEffect then
            local mKey = res .. "Mult"
            local fKey = res .. "Flat"
            if specEffect[mKey] then val = math.floor(val * specEffect[mKey]) end
            if specEffect[fKey] then val = val + specEffect[fKey] end
        end
        b.currentProd[res] = math.max(0, val)
        self.rm.rates[res] = (self.rm.rates[res] or 0) + b.currentProd[res]
    end
end

--- P2-3: 为建筑设置专精（消耗晶石 SPEC_COST）
---@param bldIdx number
---@param planet table
---@param specKey string
---@return boolean, string
function BuildingSystem:setSpec(bldIdx, planet, specKey)
    local b = planet.buildings[bldIdx]
    if not b then return false, "无效建筑" end
    if b.level < 3 then return false, "需要 Lv.3+" end
    local sp = self:findSpec(b.key, specKey)
    if not sp then return false, "未知专精" end
    if b.spec == specKey then return false, "已选择此专精" end
    if not self.rm:canAfford({crystal = SPEC_COST}) then
        return false, string.format("晶石不足（需 %d）", SPEC_COST)
    end
    self.rm:spend({crystal = SPEC_COST})
    b.spec = specKey
    self:_recalcBuildingProd(b, planet)
    return true, sp.name .. " 已激活"
end

-- P1-3: 建造队列最大容量
local BUILD_QUEUE_MAX = 3

--- 检查是否可以新建（支持队列：constructing 满但 queue 未满也可以）
---@param key string
---@param planet table
---@return boolean, string
function BuildingSystem:canBuild(key, planet)
    if not planet.colonized  then return false, "尚未殖民" end
    -- P1-3: 允许队列排队，队列满时才拒绝
    local qLen = planet.buildQueue and #planet.buildQueue or 0
    if planet.constructing and qLen >= BUILD_QUEUE_MAX then return false, "队列已满" end
    -- P1-2: 建筑槽上限 = 4 + (planet.level-1)，最多8（Lv5时=8）
    local maxSlots = math.min(8, 4 + ((planet.level or 1) - 1))
    -- P2-1: 每日挑战建筑槽-1
    if self.rm.baseBonus and self.rm.baseBonus.challengeSlotMinus1 then
        maxSlots = math.max(1, maxSlots - 1)
    end
    if #planet.buildings + (planet.constructing and 1 or 0) + qLen >= maxSlots then return false, "槽位已满" end
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local cost = {}
    for res, base in pairs(BUILDINGS[key].cost) do
        cost[res] = math.max(1, math.floor(base * bcm))
    end
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

---@param key string
---@param planet table
---@return boolean, string
function BuildingSystem:build(key, planet)
    local ok, reason = self:canBuild(key, planet)
    if not ok then return false, reason end
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local cost = {}
    for res, base in pairs(BUILDINGS[key].cost) do
        cost[res] = math.max(1, math.floor(base * bcm))
    end
    self.rm:spend(cost)
    local bd = BUILDINGS[key]
    local bm = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt = math.max(1, math.floor(bd.buildTime * bm))
    local job = {
        key=key, progress=0,
        totalTime=bt, remaining=bt,
        level=1, isUpgrade=false, targetIdx=nil
    }
    -- P1-3: 若当前没有建造任务，直接开始；否则入队
    if not planet.constructing then
        planet.constructing = job
    else
        planet.buildQueue = planet.buildQueue or {}
        planet.buildQueue[#planet.buildQueue + 1] = job
    end
    return true, ""
end

--- 检查升级（canUpgrade 保持单槽校验，允许排队时调整）
---@param bldIdx number
---@param planet table
---@return boolean, string
function BuildingSystem:canUpgrade(bldIdx, planet)
    local b    = planet.buildings[bldIdx]
    if not b then return false, "无效建筑" end
    -- P1-3: 同 canBuild，允许队列排队
    local qLen = planet.buildQueue and #planet.buildQueue or 0
    if planet.constructing and qLen >= BUILD_QUEUE_MAX then return false, "队列已满" end
    local cost = self:getUpgradeCost(b.key, b.level)
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

---@param bldIdx number
---@param planet table
---@return boolean, string
function BuildingSystem:upgrade(bldIdx, planet)
    local ok, reason = self:canUpgrade(bldIdx, planet)
    if not ok then return false, reason end
    local b    = planet.buildings[bldIdx]
    local cost = self:getUpgradeCost(b.key, b.level)
    self.rm:spend(cost)
    local bd = BUILDINGS[b.key]
    local bm = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt = math.max(1, math.floor(bd.buildTime * b.level * bm))
    local job = {
        key=b.key, progress=0,
        totalTime=bt, remaining=bt,
        level=b.level+1, isUpgrade=true, targetIdx=bldIdx
    }
    -- P1-3: 若当前没有建造任务，直接开始；否则入队
    if not planet.constructing then
        planet.constructing = job
    else
        planet.buildQueue = planet.buildQueue or {}
        planet.buildQueue[#planet.buildQueue + 1] = job
    end
    return true, ""
end

---@param planet table
---@param techId string
function BuildingSystem:applyTechBonus(planet, techId)
    local bonus = TECHS[techId] and TECHS[techId].bonus
    if not bonus then return end
    -- 去重：每个行星每个科技只应用一次
    planet.appliedTechs = planet.appliedTechs or {}
    if planet.appliedTechs[techId] then return end
    planet.appliedTechs[techId] = true

    for _, b in ipairs(planet.buildings) do
        if b.key == bonus.building then
            local bd = BUILDINGS[b.key]
            for res, baseProd in pairs(bd.prod) do
                -- 正确公式：产量 = 基础 × 等级 × 科技倍率（平乘，非指数）
                self.rm.rates[res] = math.max(0, (self.rm.rates[res] or 0) - (b.currentProd[res] or 0))
                b.currentProd[res] = math.floor(baseProd * b.level * bonus.prodMult)
                self.rm.rates[res] = (self.rm.rates[res] or 0) + b.currentProd[res]
            end
        end
    end
end

---@param dt number
---@param planet table
---@return string|nil
function BuildingSystem:update(dt, planet)
    if not planet.constructing then return nil end
    local job = planet.constructing
    job.remaining = job.remaining - dt
    job.progress  = 1.0 - math.max(0, job.remaining) / job.totalTime
    if job.remaining <= 0 then
        local completed = job.key
        if not job.isUpgrade then
            -- 新建
            local bd  = BUILDINGS[job.key]
            local bld = { key=job.key, name=bd.name, level=1, currentProd={} }
            for res, rate in pairs(bd.prod) do
                bld.currentProd[res] = rate
                self.rm.rates[res] = (self.rm.rates[res] or 0) + rate
            end
            planet.buildings[#planet.buildings+1] = bld
        else
            -- 升级
            local b   = planet.buildings[job.targetIdx]
            if b then
                b.level = job.level
                self:_recalcBuildingProd(b, planet)  -- P2-3: 含科技+专精效果
            end
        end
        planet.constructing = nil
        -- P1-3: 自动出队下一个任务
        if planet.buildQueue and #planet.buildQueue > 0 then
            planet.constructing = table.remove(planet.buildQueue, 1)
        end
        return completed
    end
    return nil
end

-- P1-3: 取消队列中某个建造任务（退还资源，index 为 buildQueue 中的 1-based 位置）
---@param qIdx number
---@param planet table
---@return boolean, string
function BuildingSystem:cancelQueued(qIdx, planet)
    if not planet.buildQueue then return false end
    local job = planet.buildQueue[qIdx]
    if not job then return false end
    -- 退还资源
    local bcm  = (self.rm.baseBonus and self.rm.baseBonus.buildCostMult) or 1.0
    local bd   = BUILDINGS[job.key]
    if bd then
        local refund = {}
        if not job.isUpgrade then
            for res, base in pairs(bd.cost) do
                refund[res] = math.max(1, math.floor(base * bcm))
            end
        else
            -- 升级退还：getUpgradeCost 需要当前等级，job.level-1 是原始等级
            local origLevel = job.level - 1
            for res, base in pairs(bd.cost) do
                refund[res] = math.max(1, math.floor(base * origLevel * bcm))
            end
        end
        for res, amt in pairs(refund) do self.rm:add(res, amt) end
    end
    table.remove(planet.buildQueue, qIdx)
    return true
end

return BuildingSystem
