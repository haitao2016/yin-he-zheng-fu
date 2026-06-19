---@diagnostic disable: assign-type-mismatch, return-type-mismatch
--- BaseBuildingSystem — 星航基地独立建造系统
--- 从 Systems.lua 机械拆分，无逻辑修改
require("game.GameConstants")

local BaseBuildingSystem = {}
BaseBuildingSystem.__index = BaseBuildingSystem

---@param rm table  ResourceManager 实例
---@return BaseBuildingSystem
function BaseBuildingSystem.new(rm)
    return setmetatable({ rm = rm }, BaseBuildingSystem)
end

---@param key string  模块 key
---@return table|nil
function BaseBuildingSystem:getModule(key)
    -- 先查基础模块，再查 Lv8-10 专属模块
    return BASE_MODULES[key] or BASE_MODULES_LV8_10[key]
end

---@param key string
---@param level number
---@return table
function BaseBuildingSystem:getUpgradeCost(key, level)
    local mod = self:getModule(key)
    if not mod then return {} end
    local k = mod.upgradeK or 1.5
    local cost = {}
    for res, base in pairs(mod.cost) do
        cost[res] = math.floor(base * (k ^ level))
    end
    return cost
end

---@param key string
---@param base table
---@return boolean, string
function BaseBuildingSystem:canBuild(key, base)
    if base.constructing            then return false, "队列忙碌" end
    local maxSlots = BaseModuleSlots(base.coreLevel)
    if #base.buildings >= maxSlots  then return false, "槽位已满" end
    -- 同类模块只能建一个
    for _, b in ipairs(base.buildings) do
        if b.key == key then return false, "已安装" end
    end
    -- 核心等级校验
    local reqLv = BASE_MODULE_UNLOCK_LEVEL[key] or 1
    local curLv = base.coreLevel or 1
    if curLv < reqLv then
        return false, "需核心 Lv." .. reqLv
    end
    local mod = self:getModule(key)
    if not mod then return false, "未知模块" end
    if not self.rm:canAfford(mod.cost) then return false, "资源不足" end
    return true, ""
end

--- 检查是否可升级核心等级
---@param base table
---@return boolean, string, table?
function BaseBuildingSystem:canUpgradeCore(base)
    local lv = base.coreLevel or 1
    if lv >= BASE_CORE_MAX_LEVEL then return false, "已达最高等级" end
    if base.constructing          then return false, "队列忙碌" end
    local cost = BASE_CORE_UPGRADE_COSTS[lv]
    if not cost                   then return false, "无升级配置" end
    -- S1 QUANTUM_CORE: 核心升级费用折扣
    local costMult = (self.rm.baseBonus and self.rm.baseBonus.coreUpgradeCostMult) or 1.0
    -- 提取资源部分（排除 buildTime），并应用折扣
    local resCost = {}
    for k, v in pairs(cost) do
        if k ~= "buildTime" then resCost[k] = math.max(1, math.floor(v * costMult)) end
    end
    if not self.rm:canAfford(resCost) then return false, "资源不足" end
    return true, "", resCost
end

--- 执行核心等级升级（进入建造队列）
---@param base table
---@return boolean, string
function BaseBuildingSystem:upgradeCore(base)
    local ok, reason, resCost = self:canUpgradeCore(base)
    if not ok then return false, reason end
    local lv   = base.coreLevel or 1
    local cost = BASE_CORE_UPGRADE_COSTS[lv]
    self.rm:spend(resCost)
    base.constructing = {
        key       = "__CORE_UPGRADE__",
        progress  = 0,
        totalTime = cost.buildTime,
        remaining = cost.buildTime,
        level     = lv + 1,
        isUpgrade = false,
        isCoreUpgrade = true,
    }
    return true, ""
end

---@param bldIdx number
---@param base table
---@return boolean, string
function BaseBuildingSystem:canUpgrade(bldIdx, base)
    local b = base.buildings[bldIdx]
    if not b then return false, "无效模块" end
    if base.constructing then return false, "队列忙碌" end
    local cost = self:getUpgradeCost(b.key, b.level)
    if not self.rm:canAfford(cost) then return false, "资源不足" end
    return true, ""
end

---@param key string
---@param base table
---@return boolean, string
function BaseBuildingSystem:build(key, base)
    local ok, reason = self:canBuild(key, base)
    if not ok then return false, reason end
    local mod = self:getModule(key)
    self.rm:spend(mod.cost)
    local installed = {
        key   = key,
        level = 1,
        btype = mod.name or key,
        pdef  = mod.prod,
        active = true,
    }
    table.insert(base.buildings, installed)
    local bm  = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt  = math.max(1, math.floor(mod.buildTime * bm))
    base.constructing = {
        key = key, progress = 0,
        totalTime = bt, remaining = bt,
        level = 1, isUpgrade = false
    }
    return true, ""
end

---@param bldIdx number
---@param base table
---@return boolean, string
function BaseBuildingSystem:upgrade(bldIdx, base)
    local ok, reason = self:canUpgrade(bldIdx, base)
    if not ok then return false, reason end
    local b    = base.buildings[bldIdx]
    local cost = self:getUpgradeCost(b.key, b.level)
    self.rm:spend(cost)
    local mod  = self:getModule(b.key)
    local bm   = (self.rm.baseBonus and self.rm.baseBonus.buildMult) or 1.0
    local bt   = math.max(1, math.floor(mod.buildTime * (mod.upgradeK ^ b.level) * bm))
    base.constructing = {
        key = b.key, progress = 0,
        totalTime = bt, remaining = bt,
        level = b.level + 1, isUpgrade = true, targetIdx = bldIdx
    }
    return true, ""
end

--- 应用模块的 effect 加成到 rm.baseBonus（Lv8-10 专属模块用）
---@param mod table
---@param isRemove boolean
function BaseBuildingSystem:applyModuleEffect(mod, isRemove)
    if not mod or not mod.effect or not self.rm then return end
    self.rm.baseBonus = self.rm.baseBonus or {}
    for effectKey, value in pairs(mod.effect) do
        if type(value) == "number" then
            if isRemove then
                self.rm.baseBonus[effectKey] = (self.rm.baseBonus[effectKey] or 0) - value
            else
                self.rm.baseBonus[effectKey] = (self.rm.baseBonus[effectKey] or 0) + value
            end
        else
            self.rm.baseBonus[effectKey] = isRemove and nil or value
        end
    end
end

--- 收集并应用基地所有模块的 effect 加成（游戏启动或加载存档后调用）
---@param base table
function BaseBuildingSystem:recalcModuleEffects(base)
    if not self.rm or not base or not base.buildings then return end
    for _, b in ipairs(base.buildings) do
        local mod = self:getModule(b.key)
        if mod and mod.effect then
            self:applyModuleEffect(mod, false)
        end
    end
end

--- 返回完成的模块 key（完成时），否则返回 nil
---@param dt number
---@param base table
---@return string|nil
function BaseBuildingSystem:update(dt, base)
    if not base.constructing then return nil end
    local job = base.constructing
    job.remaining = job.remaining - dt
    job.progress  = 1 - math.max(0, job.remaining / job.totalTime)
    if job.remaining <= 0 then
        local doneKey = job.key
        if job.isCoreUpgrade then
            base.coreLevel = job.level
        elseif job.isUpgrade then
            base.buildings[job.targetIdx].level = job.level
            local mod = self:getModule(job.key)
            if mod and mod.effect and self.rm then
                for effectKey, value in pairs(mod.effect) do
                    if type(value) == "number" then
                        self.rm.baseBonus = self.rm.baseBonus or {}
                        self.rm.baseBonus[effectKey] = (self.rm.baseBonus[effectKey] or 0) + value * 0.5
                    end
                end
            end
        else
            local mod = self:getModule(job.key)
            base.buildings[#base.buildings + 1] = {
                key = job.key, name = (mod and mod.name) or job.key, level = 1
            }
            if mod and mod.effect then self:applyModuleEffect(mod, false) end
        end
        base.constructing = nil
        return doneKey
    end
    return nil
end

return BaseBuildingSystem
