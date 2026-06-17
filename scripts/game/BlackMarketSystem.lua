-- ============================================================================
-- game/BlackMarketSystem.lua  -- P2-2: 黑市走私网络
-- 走私货物刷新 + 高风险交易 + 截获机制 + 走私路线 + 成就挂钩
-- ============================================================================
local BlackMarketSystem = {}
BlackMarketSystem.__index = BlackMarketSystem

-- ═══════════════════════════════════════════════════════════════════════════════
-- 走私品目录
-- ═══════════════════════════════════════════════════════════════════════════════
local CONTRABAND = {
    -- common (出现概率高，利润低，截获率低)
    { id="synth_spice",    name="合成香料",   rarity="common", buyCost=120,  sellMult=1.8,  interceptChance=0.12, icon="🧂" },
    { id="nano_chips",     name="纳米芯片",   rarity="common", buyCost=200,  sellMult=1.6,  interceptChance=0.10, icon="💾" },
    { id="pirate_data",    name="海盗情报",   rarity="common", buyCost=150,  sellMult=2.0,  interceptChance=0.15, icon="📡" },
    -- rare (出现概率中，利润中，截获率中)
    { id="void_crystal",   name="虚空晶体",   rarity="rare",   buyCost=500,  sellMult=2.5,  interceptChance=0.22, icon="💎" },
    { id="alien_artifact", name="异星遗物",   rarity="rare",   buyCost=800,  sellMult=2.2,  interceptChance=0.25, icon="🏺" },
    { id="plasma_core",    name="等离子核心", rarity="rare",   buyCost=650,  sellMult=2.8,  interceptChance=0.28, icon="⚡" },
    -- epic (出现概率低，利润高，截获率高)
    { id="dark_matter",    name="暗物质样本", rarity="epic",   buyCost=1500, sellMult=3.5,  interceptChance=0.35, icon="🌑" },
    { id="warp_fuel",      name="曲速燃料",   rarity="epic",   buyCost=2000, sellMult=3.0,  interceptChance=0.32, icon="🔥" },
    { id="xeno_egg",       name="异种虫卵",   rarity="epic",   buyCost=2500, sellMult=4.0,  interceptChance=0.40, icon="🥚" },
}

-- 稀有度权重（用于刷新抽取）
local RARITY_WEIGHTS = { common = 60, rare = 30, epic = 10 }
local RARITY_COLORS  = {
    common = {180,180,180},
    rare   = {100,180,255},
    epic   = {255,180,50},
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 走私路线定义
-- ═══════════════════════════════════════════════════════════════════════════════
local ROUTES = {
    { id="short",  name="近距走私",   riskMult=0.8,  rewardMult=0.9,  duration=15, icon="🚀" },
    { id="medium", name="星际航线",   riskMult=1.0,  rewardMult=1.0,  duration=25, icon="🛸" },
    { id="long",   name="深空密道",   riskMult=1.3,  rewardMult=1.4,  duration=40, icon="🌌" },
    { id="danger", name="虫巢禁区",   riskMult=1.8,  rewardMult=2.0,  duration=60, icon="☠️" },
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 常量
-- ═══════════════════════════════════════════════════════════════════════════════
local MAX_CARGO_SLOTS   = 5     -- 玩家最多同时持有走私品数量
local REFRESH_INTERVAL  = 45    -- 黑市货物刷新间隔（秒）
local SHOP_SLOTS        = 4     -- 每次刷新展示的商品数量
local FINE_MULTIPLIER   = 0.5   -- 被截获时额外罚款比例（相对买入价）
local HUB_RISK_REDUCE   = 0.03  -- 每级交易所降低截获率

-- ═══════════════════════════════════════════════════════════════════════════════
-- 构造
-- ═══════════════════════════════════════════════════════════════════════════════
function BlackMarketSystem.new(rm)
    local self = setmetatable({}, BlackMarketSystem)
    self.rm           = rm           -- ResourceManager 引用
    self.cargo        = {}           -- 玩家持有的走私品列表 [{item, boughtAt}]
    self.shopItems    = {}           -- 当前商店展示品 [{item, priceModifier}]
    self.refreshTimer = 0            -- 刷新计时器
    self.activeRoute  = nil          -- 当前进行中的走私任务 {route, cargoIdx, timer, duration}
    -- 统计（用于成就触发）
    self.stats = {
        totalTrades     = 0,   -- 成功交易次数
        totalProfit     = 0,   -- 累计利润
        intercepted     = 0,   -- 被截获次数
        epicSold        = 0,   -- 出售过的 epic 品数量
        dangerCompleted = 0,   -- 完成虫巢禁区次数
        consecutiveOk   = 0,   -- 连续未截获次数
        maxConsecutive  = 0,   -- 最高连续未截获
    }
    self.onRouteComplete = nil   -- 回调: function(result) result={success,item,profit/fine}
    -- 初始刷新商店
    self:_refreshShop()
    return self
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 内部方法
-- ═══════════════════════════════════════════════════════════════════════════════

--- 按稀有度权重抽取一个走私品
function BlackMarketSystem:_pickItem()
    -- 加权随机
    local total = 0
    for _, w in pairs(RARITY_WEIGHTS) do total = total + w end
    local roll = math.random() * total
    local chosen_rarity = "common"
    local acc = 0
    for rarity, w in pairs(RARITY_WEIGHTS) do
        acc = acc + w
        if roll <= acc then chosen_rarity = rarity; break end
    end
    -- 从对应稀有度中随机选一个
    local pool = {}
    for _, item in ipairs(CONTRABAND) do
        if item.rarity == chosen_rarity then pool[#pool + 1] = item end
    end
    return pool[math.random(#pool)]
end

--- 刷新商店货架
function BlackMarketSystem:_refreshShop()
    self.shopItems = {}
    local seen = {}
    for i = 1, SHOP_SLOTS do
        local item
        for _ = 1, 20 do  -- 防死循环
            item = self:_pickItem()
            if not seen[item.id] then break end
        end
        seen[item.id] = true
        -- 价格浮动 ±15%
        local priceMod = 0.85 + math.random() * 0.30
        self.shopItems[i] = { item = item, priceMod = priceMod }
    end
    print("[BlackMarket] 商店刷新: " .. #self.shopItems .. " 件走私品")
end

--- 计算实际截获概率（考虑交易所等级降低）
function BlackMarketSystem:_calcInterceptChance(item, route)
    local base = item.interceptChance * (route and route.riskMult or 1.0)
    -- 如果有交易所加成（通过 rm.baseBonus 传入）
    local hubLevel = (self.rm.baseBonus and self.rm.baseBonus.tradeHubLevel) or 0
    local reduction = hubLevel * HUB_RISK_REDUCE
    return math.max(0.05, base - reduction)  -- 最低 5%
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 公开 API
-- ═══════════════════════════════════════════════════════════════════════════════

--- 每帧更新
function BlackMarketSystem:update(dt)
    -- 商店刷新计时
    self.refreshTimer = self.refreshTimer + dt
    if self.refreshTimer >= REFRESH_INTERVAL then
        self.refreshTimer = 0
        self:_refreshShop()
    end
    -- 走私任务进行中
    if self.activeRoute then
        self.activeRoute.timer = self.activeRoute.timer + dt
        if self.activeRoute.timer >= self.activeRoute.duration then
            self:_completeRoute()
        end
    end
end

--- 购买走私品（从商店货架）
---@return boolean success
---@return string message
function BlackMarketSystem:buyItem(shopIdx)
    if #self.cargo >= MAX_CARGO_SLOTS then
        return false, "货舱已满（" .. MAX_CARGO_SLOTS .. "/" .. MAX_CARGO_SLOTS .. "）"
    end
    local slot = self.shopItems[shopIdx]
    if not slot then return false, "商品不存在" end
    local actualCost = math.floor(slot.item.buyCost * slot.priceMod)
    if not self.rm:canAfford({ credits = actualCost }) then
        return false, "星币不足（需要 " .. actualCost .. "）"
    end
    self.rm:spend({ credits = actualCost })
    self.cargo[#self.cargo + 1] = { item = slot.item, boughtAt = actualCost }
    -- 移除商店中该商品
    table.remove(self.shopItems, shopIdx)
    print("[BlackMarket] 购入: " .. slot.item.name .. " 花费 " .. actualCost)
    return true, slot.item.name .. " 已装载"
end

--- 直接出售走私品（无路线，低收益，无截获风险）
---@return boolean success
---@return string message
---@return number|nil profit
function BlackMarketSystem:sellDirect(cargoIdx)
    local c = self.cargo[cargoIdx]
    if not c then return false, "无此货物", nil end
    -- 直接出售只给 1.2x 基础倍率（远低于走私路线）
    local sellPrice = math.floor(c.boughtAt * 1.2)
    self.rm:add("credits", sellPrice)
    local profit = sellPrice - c.boughtAt
    self.stats.totalTrades = self.stats.totalTrades + 1
    self.stats.totalProfit = self.stats.totalProfit + profit
    if c.item.rarity == "epic" then
        self.stats.epicSold = self.stats.epicSold + 1
    end
    self.stats.consecutiveOk = self.stats.consecutiveOk + 1
    self.stats.maxConsecutive = math.max(self.stats.maxConsecutive, self.stats.consecutiveOk)
    table.remove(self.cargo, cargoIdx)
    print("[BlackMarket] 直售: " .. c.item.name .. " 利润 " .. profit)
    return true, c.item.name .. " 已出售", profit
end

--- 发起走私（选择路线+货物）
---@return boolean success
---@return string message
function BlackMarketSystem:startRoute(routeIdx, cargoIdx)
    if self.activeRoute then return false, "已有走私任务进行中" end
    local route = ROUTES[routeIdx]
    if not route then return false, "无效路线" end
    local c = self.cargo[cargoIdx]
    if not c then return false, "无此货物" end
    self.activeRoute = {
        route    = route,
        cargoIdx = cargoIdx,
        item     = c.item,
        boughtAt = c.boughtAt,
        timer    = 0,
        duration = route.duration,
    }
    print(string.format("[BlackMarket] 走私启动: %s via %s (%ds)",
        c.item.name, route.name, route.duration))
    return true, "走私启动: " .. route.name
end

--- 走私完成（内部调用）
function BlackMarketSystem:_completeRoute()
    local ar = self.activeRoute
    if not ar then return end
    local route = ar.route
    local item  = ar.item
    local interceptChance = self:_calcInterceptChance(item, route)
    local intercepted = math.random() < interceptChance

    if intercepted then
        -- 截获：货物没收 + 罚款
        local fine = math.floor(ar.boughtAt * FINE_MULTIPLIER)
        -- 尝试扣罚款（不足则扣到0）
        local current = self.rm.resources.credits or 0
        local actualFine = math.min(fine, current)
        self.rm.resources.credits = current - actualFine
        -- 移除货物
        for i, c in ipairs(self.cargo) do
            if c.item.id == item.id and c.boughtAt == ar.boughtAt then
                table.remove(self.cargo, i)
                break
            end
        end
        self.stats.intercepted = self.stats.intercepted + 1
        self.stats.consecutiveOk = 0
        self.activeRoute = nil
        print(string.format("[BlackMarket] 截获! %s 被没收，罚款 %d", item.name, actualFine))
        if self.onRouteComplete then
            self.onRouteComplete({ success = false, item = item, fine = actualFine })
        end
        return "intercepted", item, actualFine
    else
        -- 成功：获得高额报酬
        local sellPrice = math.floor(ar.boughtAt * item.sellMult * route.rewardMult)
        self.rm:add("credits", sellPrice)
        local profit = sellPrice - ar.boughtAt
        -- 移除货物
        for i, c in ipairs(self.cargo) do
            if c.item.id == item.id and c.boughtAt == ar.boughtAt then
                table.remove(self.cargo, i)
                break
            end
        end
        self.stats.totalTrades = self.stats.totalTrades + 1
        self.stats.totalProfit = self.stats.totalProfit + profit
        self.stats.consecutiveOk = self.stats.consecutiveOk + 1
        self.stats.maxConsecutive = math.max(self.stats.maxConsecutive, self.stats.consecutiveOk)
        if item.rarity == "epic" then
            self.stats.epicSold = self.stats.epicSold + 1
        end
        if route.id == "danger" then
            self.stats.dangerCompleted = self.stats.dangerCompleted + 1
        end
        self.activeRoute = nil
        print(string.format("[BlackMarket] 走私成功! %s 获利 %d（风险 %d%%）",
            item.name, profit, math.floor(interceptChance * 100)))
        if self.onRouteComplete then
            self.onRouteComplete({ success = true, item = item, profit = profit })
        end
        return "success", item, profit
    end
end

--- 取消进行中的走私（货物退回，无惩罚）
function BlackMarketSystem:cancelRoute()
    if not self.activeRoute then return false, "无进行中任务" end
    self.activeRoute = nil
    return true, "走私任务已取消"
end

--- 手动刷新商店（消耗少量星币）
function BlackMarketSystem:manualRefresh()
    local cost = 50
    if not self.rm:canAfford({ credits = cost }) then
        return false, "星币不足"
    end
    self.rm:spend({ credits = cost })
    self:_refreshShop()
    self.refreshTimer = 0
    return true, "商店已刷新"
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 查询接口（供 UI 渲染用）
-- ═══════════════════════════════════════════════════════════════════════════════

function BlackMarketSystem:getShopItems()     return self.shopItems end
function BlackMarketSystem:getCargo()         return self.cargo end
function BlackMarketSystem:getCargoCount()    return #self.cargo end
function BlackMarketSystem:getMaxCargo()      return MAX_CARGO_SLOTS end
function BlackMarketSystem:getActiveRoute()   return self.activeRoute end
function BlackMarketSystem:getRefreshTimer()  return REFRESH_INTERVAL - self.refreshTimer end
function BlackMarketSystem:getStats()         return self.stats end
function BlackMarketSystem:getRoutes()        return ROUTES end
function BlackMarketSystem:getRarityColor(r)  return RARITY_COLORS[r] or {180,180,180} end

--- 获取指定货物的截获概率预览（选中路线时显示）
function BlackMarketSystem:previewRisk(cargoIdx, routeIdx)
    local c = self.cargo[cargoIdx]
    local route = ROUTES[routeIdx]
    if not c or not route then return 0 end
    return self:_calcInterceptChance(c.item, route)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 序列化 / 反序列化
-- ═══════════════════════════════════════════════════════════════════════════════

function BlackMarketSystem:serialize()
    local cargoSave = {}
    for _, c in ipairs(self.cargo) do
        cargoSave[#cargoSave + 1] = { id = c.item.id, boughtAt = c.boughtAt }
    end
    return {
        cargo        = cargoSave,
        stats        = self.stats,
        refreshTimer = self.refreshTimer,
    }
end

function BlackMarketSystem:deserialize(data)
    if not data then return end
    -- 恢复货物
    self.cargo = {}
    if type(data.cargo) == "table" then
        for _, cs in ipairs(data.cargo) do
            -- 通过 id 找到对应物品定义
            for _, item in ipairs(CONTRABAND) do
                if item.id == cs.id then
                    self.cargo[#self.cargo + 1] = { item = item, boughtAt = cs.boughtAt or item.buyCost }
                    break
                end
            end
        end
    end
    -- 恢复统计
    if type(data.stats) == "table" then
        for k, v in pairs(data.stats) do
            self.stats[k] = v
        end
    end
    self.refreshTimer = data.refreshTimer or 0
    print(string.format("[BlackMarket] 恢复: %d件货物, %d次交易, %d次截获",
        #self.cargo, self.stats.totalTrades, self.stats.intercepted))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 模块导出（含常量供 UI 使用）
-- ═══════════════════════════════════════════════════════════════════════════════
BlackMarketSystem.CONTRABAND    = CONTRABAND
BlackMarketSystem.ROUTES        = ROUTES
BlackMarketSystem.RARITY_COLORS = RARITY_COLORS
BlackMarketSystem.MAX_CARGO     = MAX_CARGO_SLOTS

return BlackMarketSystem
