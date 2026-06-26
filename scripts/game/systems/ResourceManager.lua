---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-----------------------------------------------------------
-- ResourceManager (从 Systems.lua 机械拆分)
-----------------------------------------------------------
require("game.GameConstants")

local ResourceManager = {}
ResourceManager.__index = ResourceManager

function ResourceManager.new()
    local self = setmetatable({}, ResourceManager)
    -- 原矿资源（行星/小行星产出，经精炼厂转化后才可用）
    self.resources   = { minerals=0,     energy=0,     crystal=0,
    -- 精炼资源（可直接消耗，初始储备用于建造精炼厂）
                         metal=800,      esource=500,  nuclear=300,  -- M1: 初始核能 150→300
                         population=10, credits=0 }
    self.rates       = { minerals=10,    energy=5,     crystal=2,
                         metal=0,        esource=0,    nuclear=0,
                         population=0.1, credits=0 }
    self.caps        = { minerals=9999, energy=9999, crystal=2000,
                         metal=99999,    esource=99999, nuclear=9999,
                         population=99999, credits=9999999 }
    -- V2.6 C3: 稀有资源（独立存储，使用 RARE_RES_CAPS 常量上限）
    self.rareResources = {}
    for _, res in ipairs(RARE_RES_ORDER) do
        self.rareResources[res] = 0
    end
    self.rareRates = {}
    for _, res in ipairs(RARE_RES_ORDER) do
        self.rareRates[res] = 0
    end
    self.convertRate  = 0   -- 范围 -20 ~ +20（原矿互换用）
    self.refineryMult = 0   -- 0=无精炼厂，>0=精炼厂倍率（由 applyBaseModuleEffects 设置）
    return self
end

-- 互换比例常量
local CONVERT_RATIO = 1.5  -- 1 矿石 → 1.5 能量（或 1.5 能量 → 1 矿石）

-- 精炼配置（模块级缓存，避免每帧 GC）
local REFINE_CFG = {
    minerals = { ref="metal",   ratio=3.0, processRate=7.0 },
    energy   = { ref="esource", ratio=2.0, processRate=3.0 },
    crystal  = { ref="nuclear", ratio=3.0, processRate=1.0 },  -- M1 修复：5:1→3:1，早期核能不再过窄
}

function ResourceManager:update(dt)
    -- P2-4: 聚合行星建筑加成（高级精炼厂倍率 / 稀有几率）
    local planetRefineMult = 1.0
    local rareChance        = 0.0
    if self.bs and self.planetGetter and self.bs.aggregatePlanetEffects then
        local pe = self.bs:aggregatePlanetEffects(self.planetGetter())
        planetRefineMult = pe.refineMult or 1.0
        rareChance        = pe.rareChance or 0.0
    end

    -- Step 1：所有资源按速率正常积累（原矿也进入库存）
    local resMult = self.leagueResMult or 1.0  -- P1-3: 联赛资源倍率
    for res, rate in pairs(self.rates) do
        if rate ~= 0 then
            local cap = self.caps[res] or 99999
            self.resources[res] = math.min(cap, (self.resources[res] or 0) + rate * resMult * dt)
            -- P2-4: 高级精炼厂稀有资源几率（每次 tick 有机会额外产出稀有资源）
            if rareChance > 0 and math.random() < rareChance * dt then
                local rareKey = RARE_RES_ORDER[(math.floor(self.totalTime_ or 0) % #RARE_RES_ORDER) + 1]
                if rareKey then
                    self:addRare(rareKey, 1)
                end
            end
        end
    end
    self.totalTime_ = (self.totalTime_ or 0) + dt

    -- Step 2：原矿 ⇄ 原矿 自动互换（convertRate 只作用于原矿层）
    if self.convertRate ~= 0 then
        local rate = self.convertRate
        if rate > 0 then
            local drain = math.min(rate * dt, math.max(0, self.resources.minerals))
            self.resources.minerals = self.resources.minerals - drain
            self.resources.energy   = math.min(self.caps.energy,
                self.resources.energy + drain * CONVERT_RATIO)
        else
            local drain = math.min((-rate) * CONVERT_RATIO * dt, math.max(0, self.resources.energy))
            self.resources.energy   = self.resources.energy - drain
            self.resources.minerals = math.min(self.caps.minerals,
                self.resources.minerals + drain / CONVERT_RATIO)
        end
    end

    -- Step 3：精炼厂以固定速率从原矿库存消耗并转化为精炼资源
    if self.refineryMult and self.refineryMult > 0 then
        -- S1 RAPID_REFINE: 全局精炼速率加成（累乘到 refineryMult 上）
        -- P2-4: 行星高级精炼厂（planetRefineMult）进一步叠乘
        local globalMult = ((self.baseBonus and self.baseBonus.globalRefineMult) or 1.0) * planetRefineMult
        for raw, cfg in pairs(REFINE_CFG) do
            local rawAmt = self.resources[raw] or 0
            if rawAmt > 0 then
                -- S1 CRYSTAL_PROCESS: 水晶精炼效率独立加成
                -- P1-2 Volcanic nuclearMult: 核能精炼速率加成
                local extraMult = globalMult
                if raw == "crystal" then
                    extraMult = extraMult * ((self.baseBonus and self.baseBonus.crystalRefineMult) or 1.0)
                    extraMult = extraMult * ((self.baseBonus and self.baseBonus.nuclearMult) or 1.0)
                end
                local toConsume = math.min(rawAmt, cfg.processRate * self.refineryMult * extraMult * dt)
                if toConsume > 0 then
                    self.resources[raw] = rawAmt - toConsume
                    local cap = self.caps[cfg.ref] or 99999
                    self.resources[cfg.ref] = math.min(cap,
                        (self.resources[cfg.ref] or 0) + toConsume / cfg.ratio)
                end
            end
        end
    end

    -- V2.6 C3: 稀有资源更新（按速率积累，超上限自动转化为普通资源）
    for res, rate in pairs(self.rareRates) do
        if rate ~= 0 then
            local cap = RARE_RES_CAPS[res] or 500
            self.rareResources[res] = math.min(cap, (self.rareResources[res] or 0) + rate * dt)
        end
    end
    -- 稀有资源超出上限自动转化（通过 addRare 正常添加也会触发，但这里确保按速率积累的也会转化）
    for res, conv in pairs(RES_OVERFLOW_CONVERSION) do
        local cap = RARE_RES_CAPS[res] or 500
        if (self.rareResources[res] or 0) > cap then
            local overflow = self.rareResources[res] - cap
            self.rareResources[res] = cap
            local refCap = self.caps[conv.to] or 99999
            self.resources[conv.to] = math.min(refCap,
                (self.resources[conv.to] or 0) + math.floor(overflow * conv.ratio / 100))
        end
    end
end

--- 设置互换速率（正=矿→能量，负=能→矿，0=关闭）
function ResourceManager:setConvertRate(rate)
    self.convertRate = math.max(-20, math.min(20, rate))
end

--- 获取互换对显示速率（用于 UI 展示净变化）
--- 返回 { mineralsPerSec, energyPerSec }（已含互换影响）
function ResourceManager:getConvertDisplay()
    local r = self.convertRate
    if r > 0 then
        return -r, r * CONVERT_RATIO   -- 矿石减少，能量增加
    elseif r < 0 then
        return (-r) / CONVERT_RATIO, r * CONVERT_RATIO  -- 矿石增加，能量减少
    end
    return 0, 0
end

function ResourceManager:canAfford(cost)
    for res, amt in pairs(cost) do
        if (self.resources[res] or 0) < amt then return false end
    end
    return true
end

function ResourceManager:spend(cost)
    if not self:canAfford(cost) then return false end
    for res, amt in pairs(cost) do
        self.resources[res] = (self.resources[res] or 0) - amt
    end
    return true
end

function ResourceManager:add(resType, amount)
    if self.resources[resType] ~= nil then
        local cap = self.caps[resType] or 99999
        self.resources[resType] = math.min(cap, self.resources[resType] + amount)
    end
end

-- V2.6 C3: 稀有资源操作方法
--- 检查稀有资源是否足够
function ResourceManager:canAffordRare(cost)
    for res, amt in pairs(cost) do
        if (self.rareResources[res] or 0) < amt then return false end
    end
    return true
end

--- 消耗稀有资源
function ResourceManager:spendRare(cost)
    if not self:canAffordRare(cost) then return false end
    for res, amt in pairs(cost) do
        self.rareResources[res] = (self.rareResources[res] or 0) - amt
    end
    return true
end

--- 添加稀有资源，超出上限自动转化为普通资源
function ResourceManager:addRare(resType, amount)
    local cap = RARE_RES_CAPS[resType] or 500
    local current = self.rareResources[resType] or 0
    local newVal = current + amount
    if newVal <= cap then
        self.rareResources[resType] = newVal
    else
        self.rareResources[resType] = cap
        local overflow = newVal - cap
        -- 超出部分自动转化为对应普通资源
        local conv = RES_OVERFLOW_CONVERSION[resType]
        if conv then
            local refCap = self.caps[conv.to] or 99999
            self.resources[conv.to] = math.min(refCap,
                (self.resources[conv.to] or 0) + math.floor(overflow * conv.ratio / 100))
        end
    end
end

-- 资源互换：从 fromRes 消耗 EXCHANGE_AMOUNT，换取 toRes
-- 返回 ok, gain（实际获得数量）或 false, reason
function ResourceManager:exchange(fromRes, toRes)
    local rates = EXCHANGE_RATES[fromRes]
    if not rates or not rates[toRes] then
        return false, "不支持该互换方向"
    end
    local have = self.resources[fromRes] or 0
    if have < EXCHANGE_AMOUNT then
        return false, RES_LABELS[fromRes] .. "不足（需要 " .. EXCHANGE_AMOUNT .. "）"
    end
    local gain = math.floor(EXCHANGE_AMOUNT * rates[toRes])
    self.resources[fromRes] = have - EXCHANGE_AMOUNT
    local cap = self.caps[toRes] or 99999
    self.resources[toRes] = math.min(cap, (self.resources[toRes] or 0) + gain)
    return true, gain
end

function ResourceManager:fmtCost(cost)
    local parts = {}
    for _, res in ipairs(RES_ORDER) do
        local amt = cost[res]
        if amt and amt > 0 then
            parts[#parts+1] = RES_LABELS[res] .. "×" .. amt
        end
    end
    return table.concat(parts, " ")
end

-- 序列化 / 反序列化
function ResourceManager:serialize()
    local function safeNum(v) return tonumber(v) or 0 end
    local data = {
        resources = {
            minerals=math.floor(safeNum(self.resources.minerals)), energy=math.floor(safeNum(self.resources.energy)),
            crystal=math.floor(safeNum(self.resources.crystal)), metal=math.floor(safeNum(self.resources.metal)),
            esource=math.floor(safeNum(self.resources.esource)), nuclear=math.floor(safeNum(self.resources.nuclear)),
            population=math.floor(safeNum(self.resources.population)), credits=math.floor(safeNum(self.resources.credits)),
        }
    }
    -- P0-2: V2.6 稀有资源（防御性保存，即便未来新增 key 也可正确序列化）
    if self.rareResources then
        data.rareResources = {}
        if RARE_RES_ORDER then
            for _, k in ipairs(RARE_RES_ORDER) do
                data.rareResources[k] = math.floor(safeNum(self.rareResources[k]))
            end
        else
            for k, v in pairs(self.rareResources) do
                data.rareResources[k] = math.floor(safeNum(v))
            end
        end
    end
    -- 防御性保存速率（防止未来新增资源时丢失）
    if self.rates then
        data.rates = {}
        for k, v in pairs(self.rates) do
            data.rates[k] = tonumber(v) or 0
        end
    end
    if self.rareRates then
        data.rareRates = {}
        for k, v in pairs(self.rareRates) do
            data.rareRates[k] = tonumber(v) or 0
        end
    end
    return data
end

function ResourceManager:deserialize(data)
    if not data then return end
    if data.resources then
        for k, v in pairs(data.resources) do
            if self.resources[k] ~= nil then
                self.resources[k] = tonumber(v) or 0
            end
        end
    end
    -- P0-2: V2.6 稀有资源恢复（防御性：老存档可能无此字段）
    if data.rareResources and self.rareResources then
        for k, v in pairs(data.rareResources) do
            self.rareResources[k] = tonumber(v) or 0
        end
    elseif RARE_RES_ORDER and self.rareResources then
        -- 老存档兜底：初始化为 0（防止 nil 索引）
        for _, k in ipairs(RARE_RES_ORDER) do
            if self.rareResources[k] == nil then
                self.rareResources[k] = 0
            end
        end
    end
    -- 速率恢复（防御性）
    if data.rates and self.rates then
        for k, v in pairs(data.rates) do
            self.rates[k] = tonumber(v) or 0
        end
    end
    if data.rareRates and self.rareRates then
        for k, v in pairs(data.rareRates) do
            self.rareRates[k] = tonumber(v) or 0
        end
    end
end

---@param self table
function ResourceManager:initSupplyDemand()
    self.supplyLevels = self.supplyLevels or {}
    self.demandLevels = self.demandLevels or {}
    for res, _ in pairs(self.resources) do
        if self.supplyLevels[res] == nil then self.supplyLevels[res] = 0 end
        if self.demandLevels[res] == nil then self.demandLevels[res] = 0 end
    end
    if RARE_RES_ORDER then
        for _, res in ipairs(RARE_RES_ORDER) do
            if self.supplyLevels[res] == nil then self.supplyLevels[res] = 0 end
            if self.demandLevels[res] == nil then self.demandLevels[res] = 0 end
        end
    end
    self.colonyProduction = self.colonyProduction or {}
    self.productionHistory = self.productionHistory or {}
    self.consumptionHistory = self.consumptionHistory or {}
    self.totalProduction = self.totalProduction or {}
    self.totalConsumption = self.totalConsumption or {}
end

---@param self table
---@param colony string
---@param resource string
---@param amount number
function ResourceManager:recordColonyProduction(colony, resource, amount)
    if not colony or not resource then return end
    self:initSupplyDemand()
    self.colonyProduction[colony] = self.colonyProduction[colony] or {}
    self.colonyProduction[colony][resource] = (self.colonyProduction[colony][resource] or 0) + amount
    self.supplyLevels[resource] = (self.supplyLevels[resource] or 0) + amount
    self.totalProduction[resource] = (self.totalProduction[resource] or 0) + amount
end

---@param self table
---@param resource string
---@param amount number
function ResourceManager:trackProduction(resource, amount)
    if not resource then return end
    self:initSupplyDemand()
    self.supplyLevels[resource] = (self.supplyLevels[resource] or 0) + amount
    self.totalProduction[resource] = (self.totalProduction[resource] or 0) + amount
    self.productionHistory[resource] = self.productionHistory[resource] or {}
    table.insert(self.productionHistory[resource], { value = amount, time = os.time() })
    if #self.productionHistory[resource] > 50 then table.remove(self.productionHistory[resource], 1) end
end

---@param self table
---@param resource string
---@param amount number
function ResourceManager:trackConsumption(resource, amount)
    if not resource then return end
    self:initSupplyDemand()
    self.demandLevels[resource] = (self.demandLevels[resource] or 0) + amount
    self.totalConsumption[resource] = (self.totalConsumption[resource] or 0) + amount
    self.consumptionHistory[resource] = self.consumptionHistory[resource] or {}
    table.insert(self.consumptionHistory[resource], { value = amount, time = os.time() })
    if #self.consumptionHistory[resource] > 50 then table.remove(self.consumptionHistory[resource], 1) end
end

---@param self table
---@return table
function ResourceManager:getSupplyDemandStats()
    self:initSupplyDemand()
    local stats = {}
    local function addStats(res)
        local supply = self.supplyLevels[res] or 0
        local demand = self.demandLevels[res] or 0
        local ratio = 1.0
        if demand > 0 then ratio = supply / demand
        elseif supply > 0 then ratio = math.huge end
        stats[res] = {
            resource = res,
            supply = supply,
            demand = demand,
            ratio = ratio,
            net = supply - demand,
            totalProduction = self.totalProduction[res] or 0,
            totalConsumption = self.totalConsumption[res] or 0,
        }
    end
    for res, _ in pairs(self.resources) do addStats(res) end
    if RARE_RES_ORDER then
        for _, res in ipairs(RARE_RES_ORDER) do addStats(res) end
    end
    return stats
end

---@param self table
---@param resource string
---@return number
function ResourceManager:computeSupplyDemandRatio(resource)
    self:initSupplyDemand()
    local supply = self.supplyLevels[resource] or 0
    local demand = self.demandLevels[resource] or 0
    if demand <= 0 and supply <= 0 then return 1.0 end
    if demand <= 0 then return 2.0 end
    return supply / demand
end

---@param self table
---@return table
function ResourceManager:getColonyProductionBreakdown()
    self:initSupplyDemand()
    local breakdown = {}
    for colony, resources in pairs(self.colonyProduction) do
        local total = 0
        for _, amt in pairs(resources) do total = total + amt end
        breakdown[colony] = { resources = resources, total = total }
    end
    return breakdown
end

---@param self table
---@param resource string
---@param horizon number
---@return number,string,table
function ResourceManager:predictPriceTrend(resource, horizon)
    self:initSupplyDemand()
    horizon = tonumber(horizon) or 5
    local prodHist = self.productionHistory[resource] or {}
    local consHist = self.consumptionHistory[resource] or {}
    local function average(hist, window)
        if not hist or #hist == 0 then return 0 end
        local n = math.min(window, #hist)
        if n <= 0 then return 0 end
        local sum = 0
        for i = #hist - n + 1, #hist do sum = sum + (hist[i] and hist[i].value or 0) end
        return sum / n
    end
    local recentSupply = average(prodHist, horizon)
    local recentDemand = average(consHist, horizon)
    local longSupply = average(prodHist, 20)
    local longDemand = average(consHist, 20)
    local ratio = 1.0
    if recentDemand > 0 then ratio = recentSupply / recentDemand
    elseif recentSupply > 0 then ratio = 2.0 end
    local longRatio = 1.0
    if longDemand > 0 then longRatio = longSupply / longDemand
    elseif longSupply > 0 then longRatio = 2.0 end
    local delta = ratio - longRatio
    local basePriceMult = 1.0 / math.max(0.1, ratio)
    local trendScore = 0
    if delta > 0.1 then trendScore = -0.05
    elseif delta < -0.1 then trendScore = 0.05 end
    if ratio < 0.7 then trendScore = trendScore + 0.08 end
    if ratio > 1.5 then trendScore = trendScore - 0.05 end
    local trend = "stable"
    if trendScore > 0.03 then trend = "up"
    elseif trendScore < -0.03 then trend = "down" end
    return trendScore, trend, {
        currentRatio = ratio,
        longRatio = longRatio,
        delta = delta,
        recentSupply = recentSupply,
        recentDemand = recentDemand,
        horizon = horizon,
        predictedPriceMult = basePriceMult,
    }
end

return ResourceManager
