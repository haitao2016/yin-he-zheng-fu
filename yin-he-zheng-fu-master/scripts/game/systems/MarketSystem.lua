---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-----------------------------------------------------------
-- MarketSystem (从 Systems.lua 机械拆分)
-----------------------------------------------------------
require("game.GameConstants")

local BASE_RATES = {
    metal   = { buy=2.0,  sell=0.5 },
    esource = { buy=3.0,  sell=1.0 },
    nuclear = { buy=10.0, sell=4.0 },
}

local MarketSystem = {}
MarketSystem.__index = MarketSystem

function MarketSystem.new(rm)
    local self = setmetatable({ rm=rm, timer=0 }, MarketSystem)
    self.rates      = {}
    self.history    = {}  -- 记录近期买价快照（最多6条）
    self.priceFlash = {}  -- P2-3: 价格大幅波动提示计时器（秒）
    for res, r in pairs(BASE_RATES) do
        self.rates[res]      = { buy=r.buy, sell=r.sell }
        self.history[res]    = { r.buy }  -- 初始时放一条基准价
        self.priceFlash[res] = 0
    end
    return self
end

function MarketSystem:update(dt)
    -- P2-3: 衰减所有 priceFlash 计时器
    for res, _ in pairs(self.priceFlash) do
        if self.priceFlash[res] > 0 then
            self.priceFlash[res] = math.max(0, self.priceFlash[res] - dt)
        end
    end

    -- P2-1: 每日挑战 — 市场汇率固定为最优（买价最低、卖价最高）
    if self.rm.baseBonus and self.rm.baseBonus.challengeBestMarket then
        for res, r in pairs(self.rates) do
            local base = BASE_RATES[res]
            r.buy  = base.buy  * 0.4   -- 最低买入价（玩家花最少）
            r.sell = base.buy  * 0.4 * 0.6  -- 对应卖出价（保持60%差价）
            -- 让卖价也尽量高（用基准卖价×1.5 但不超过买价60%）
            r.sell = math.min(base.sell * 1.5, r.buy * 0.6)
        end
        return  -- 跳过正常波动
    end

    self.timer = self.timer + dt
    if self.timer >= 12 then   -- 每12秒波动一次，让玩家有感知
        self.timer = 0
        for res, r in pairs(self.rates) do
            local prevBuy = r.buy   -- P2-3: 记录变动前价格
            -- 记录历史（买价快照）
            local h = self.history[res]
            h[#h+1] = r.buy
            if #h > 6 then table.remove(h, 1) end
            -- 滑动波动：当前价 × 随机因子，带均值回归避免无限漂移
            local change   = 1.0 + (math.random() * 0.5 - 0.25)   -- ±25%
            local base     = BASE_RATES[res]
            local revert   = 0.25   -- 25% 拉力归向基准价
            r.buy  = math.max(base.buy  * 0.4, r.buy  * change * (1 - revert) + base.buy  * revert)
            r.sell = math.max(base.sell * 0.4, r.sell * change * (1 - revert) + base.sell * revert)
            -- 卖价始终 ≤ 买价的 60%（交易所差价）
            r.sell = math.min(r.sell, r.buy * 0.6)
            -- P2-3: 变动 > 15% 触发价格闪烁提示（8秒）
            local changePct = math.abs(r.buy - prevBuy) / prevBuy
            if changePct >= 0.15 then
                self.priceFlash[res] = 8.0
            end
        end
    end
end

--- 获取某资源的价格趋势符号（"↑" / "↓" / "→"）
function MarketSystem:getTrend(resType)
    local h = self.history[resType]
    if not h or #h < 2 then return "→" end
    local last = h[#h]
    local prev = h[#h - 1]
    if last > prev * 1.05 then return "↑"
    elseif last < prev * 0.95 then return "↓"
    else return "→" end
end

function MarketSystem:sell(resType, amount)
    local r = self.rates[resType]
    if not r then return false, "不可交易" end
    if (self.rm.resources[resType] or 0) < amount then return false, "资源不足" end
    self.rm.resources[resType] = self.rm.resources[resType] - amount
    self.rm:add("credits", amount * r.sell)
    return true, math.floor(amount * r.sell)
end

function MarketSystem:buy(resType, amount)
    local r = self.rates[resType]
    if not r then return false, "不可交易" end
    local cost = amount * r.buy
    if not self.rm:canAfford({credits=cost}) then return false, "星币不足" end
    self.rm:spend({credits=cost})
    self.rm:add(resType, amount)
    return true, math.floor(cost)
end

return MarketSystem
