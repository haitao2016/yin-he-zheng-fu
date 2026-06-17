---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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
    self.caps        = { minerals=9999,  energy=9999,  crystal=2000,
                         metal=99999,    esource=99999, nuclear=9999,
                         population=99999, credits=9999999 }
    -- V2.6 C3: 稀有资源（独立上限500，超出自动转化）
    self.rareResources = {
        titanium       = 0,   -- 钛合金
        darkMatter     = 0,   -- 暗物质
        starCore       = 0,   -- 星核碎片
        blueCrystal    = 0,   -- 蓝晶石
        purpleCrystal  = 0,   -- 紫晶石
        rainbowCrystal = 0,   -- 彩虹晶
    }
    self.rareRates = {
        titanium       = 0,
        darkMatter     = 0,
        starCore       = 0,
        blueCrystal    = 0,
        purpleCrystal  = 0,
        rainbowCrystal = 0,
    }
    self.rareCaps = {
        titanium       = 500,
        darkMatter     = 500,
        starCore       = 500,
        blueCrystal    = 500,
        purpleCrystal  = 500,
        rainbowCrystal = 500,
    }
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
    -- Step 1：所有资源按速率正常积累（原矿也进入库存）
    local resMult = self.leagueResMult or 1.0  -- P1-3: 联赛资源倍率
    for res, rate in pairs(self.rates) do
        if rate ~= 0 then
            local cap = self.caps[res] or 99999
            self.resources[res] = math.min(cap, (self.resources[res] or 0) + rate * resMult * dt)
        end
    end

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
        local globalMult = (self.baseBonus and self.baseBonus.globalRefineMult) or 1.0
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

    -- V2.6 C3: 稀有资源更新（按速率积累，超上限自动转化）
    for res, rate in pairs(self.rareRates) do
        if rate ~= 0 then
            local cap = self.rareCaps[res] or 500
            self.rareResources[res] = math.min(cap, (self.rareResources[res] or 0) + rate * dt)
        end
    end
    -- 稀有资源超出上限时自动转化为普通资源
    local conversionRatios = {
        titanium       = { to="metal",    ratio=50 },
        darkMatter     = { to="nuclear", ratio=50 },
        starCore       = { to="nuclear", ratio=50 },
        blueCrystal    = { to="crystal", ratio=50 },
        purpleCrystal  = { to="crystal", ratio=50 },
        rainbowCrystal = { to="crystal", ratio=50 },
    }
    for res, conv in pairs(conversionRatios) do
        local cap = self.rareCaps[res] or 500
        if (self.rareResources[res] or 0) > cap then
            local overflow = self.rareResources[res] - cap
            self.rareResources[res] = cap
            -- 转化到对应普通资源
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
    return {
        resources = {
            minerals=math.floor(self.resources.minerals or 0), energy=math.floor(self.resources.energy or 0),
            crystal=math.floor(self.resources.crystal or 0), metal=math.floor(self.resources.metal or 0),
            esource=math.floor(self.resources.esource or 0), nuclear=math.floor(self.resources.nuclear or 0),
            population=math.floor(self.resources.population or 0), credits=math.floor(self.resources.credits or 0),
        }
    }
end

function ResourceManager:deserialize(data)
    if not data or not data.resources then return end
    for k, v in pairs(data.resources) do if self.resources[k] ~= nil then self.resources[k] = v end end
end

return ResourceManager
