---@diagnostic disable: undefined-global, assign-type-mismatch
-- ============================================================================
-- ExpeditionSystem.lua — 探险队远征系统
-- 支持多槽位远征、离线推进、事件链、奖励结算
-- ============================================================================
require("game.GameConstants")

local ExpeditionSystem = {}
ExpeditionSystem.__index = ExpeditionSystem

-- ============================================================================
-- 常量配置
-- ============================================================================
local MAX_SLOTS = 3  -- 最大远征槽位

-- 远征路线定义
local ROUTES = {
    { id = "unknown",    name = "未知区域",     icon = "🌑", duration = 1800,  danger = 1, rewardMult = 1.0 },
    { id = "ruins",      name = "古代遗迹",     icon = "🏛️", duration = 3600,  danger = 2, rewardMult = 1.5 },
    { id = "nebula",     name = "星云深处",     icon = "🌫️", duration = 7200,  danger = 2, rewardMult = 2.0 },
    { id = "blackhole",  name = "黑洞边缘",     icon = "🕳️", duration = 14400, danger = 3, rewardMult = 3.0 },
    { id = "station",    name = "废弃空间站",   icon = "🛰️", duration = 5400,  danger = 2, rewardMult = 1.8 },
    { id = "anomaly",    name = "时空异常点",   icon = "⚡",  duration = 10800, danger = 3, rewardMult = 2.5 },
}

-- 事件池（按类型分组）
local EVENTS = {
    battle = {
        { text = "遭遇流浪海盗小队！", outcome = "战斗胜利，缴获资源", rewardType = "metal", rewardAmt = 30 },
        { text = "发现海盗补给站！突袭成功", outcome = "获得大量能源", rewardType = "energy", rewardAmt = 50 },
        { text = "遭遇未知生物体攻击", outcome = "击退生物，获得样本", rewardType = "credits", rewardAmt = 80 },
        { text = "海盗伏击！激烈交战", outcome = "险胜，损失轻微", rewardType = "crystal", rewardAmt = 20 },
        { text = "遭遇敌方侦察舰", outcome = "将其俘获，获得情报", rewardType = "credits", rewardAmt = 60 },
    },
    discover = {
        { text = "发现富矿小行星带！", outcome = "标记位置，获得矿石", rewardType = "minerals", rewardAmt = 80 },
        { text = "探测到能量信号源", outcome = "回收能量晶体", rewardType = "energy", rewardAmt = 60 },
        { text = "发现古代文明遗物", outcome = "带回研究样本", rewardType = "credits", rewardAmt = 120 },
        { text = "定位到稀有水晶矿脉", outcome = "采集水晶样本", rewardType = "crystal", rewardAmt = 40 },
        { text = "发现漂流的货舱残骸", outcome = "回收物资", rewardType = "metal", rewardAmt = 50 },
    },
    choice = {
        { text = "遇到求救信号，是否前往？", outcome = "救援成功，获得感谢", rewardType = "credits", rewardAmt = 100 },
        { text = "发现可疑信号，是否调查？", outcome = "是陷阱！但成功脱离", rewardType = "minerals", rewardAmt = 20 },
        { text = "商人请求护航，是否接受？", outcome = "护航完成，获得报酬", rewardType = "credits", rewardAmt = 150 },
        { text = "发现休眠舱，是否唤醒？", outcome = "是友方幸存者", rewardType = "energy", rewardAmt = 40 },
    },
    crisis = {
        { text = "引擎故障！紧急维修中", outcome = "修复成功，延迟返回", rewardType = "none", rewardAmt = 0 },
        { text = "遭遇太阳风暴！", outcome = "护盾抵挡，无损失", rewardType = "energy", rewardAmt = 10 },
        { text = "导航系统异常，偏离航线", outcome = "意外发现新区域", rewardType = "credits", rewardAmt = 50 },
    },
}

-- 事件类型权重（百分比）
local EVENT_WEIGHTS = { battle = 40, discover = 25, choice = 20, crisis = 15 }

-- ============================================================================
-- 构造函数
-- ============================================================================
function ExpeditionSystem.new()
    local self = setmetatable({}, ExpeditionSystem)
    self.slots = {}        -- 当前远征 { [1..3] = expedition or nil }
    self.history = {}      -- 已完成远征历史（最多保留10条）
    self.totalCompleted = 0
    return self
end

-- ============================================================================
-- 核心接口
-- ============================================================================

--- 获取所有路线配置
function ExpeditionSystem:GetRoutes()
    return ROUTES
end

--- 获取当前远征列表
function ExpeditionSystem:GetActiveExpeditions()
    return self.slots
end

--- 获取可用槽位数
function ExpeditionSystem:GetFreeSlots()
    local used = 0
    for i = 1, MAX_SLOTS do
        if self.slots[i] then used = used + 1 end
    end
    return MAX_SLOTS - used
end

--- 派遣远征队
---@param routeId string 路线ID
---@param shipCount number 派遣舰船数（1-5）
---@return boolean success
---@return string reason
function ExpeditionSystem:Dispatch(routeId, shipCount)
    if self:GetFreeSlots() <= 0 then
        return false, "远征槽位已满"
    end
    shipCount = math.max(1, math.min(5, shipCount or 1))

    local route = nil
    for _, r in ipairs(ROUTES) do
        if r.id == routeId then route = r; break end
    end
    if not route then return false, "无效路线" end

    -- 找到空槽位
    local slotIdx = nil
    for i = 1, MAX_SLOTS do
        if not self.slots[i] then slotIdx = i; break end
    end

    -- 生成事件序列（每30分钟一个事件，最少2个最多8个）
    local eventCount = math.max(2, math.min(8, math.floor(route.duration / 1800)))
    local events = {}
    for e = 1, eventCount do
        local evType = self:_rollEventType()
        local pool = EVENTS[evType]
        local ev = pool[math.random(1, #pool)]
        events[e] = {
            type = evType,
            text = ev.text,
            outcome = ev.outcome,
            rewardType = ev.rewardType,
            rewardAmt = math.floor(ev.rewardAmt * route.rewardMult * (0.8 + math.random() * 0.4)),
            triggerAt = (e / eventCount) * route.duration,  -- 均匀分布
            triggered = false,
        }
    end

    self.slots[slotIdx] = {
        routeId    = routeId,
        routeName  = route.name,
        routeIcon  = route.icon,
        shipCount  = shipCount,
        startTime  = os.clock(),
        duration   = route.duration,
        elapsed    = 0,
        events     = events,
        log        = { { time = 0, text = "🚀 远征队出发！目标: " .. route.name } },
        rewards    = {},
        completed  = false,
    }

    return true, ""
end

--- 更新所有远征进度（每帧调用）
---@param dt number 帧时间
function ExpeditionSystem:Update(dt)
    for i = 1, MAX_SLOTS do
        local exp = self.slots[i]
        if exp and not exp.completed then
            exp.elapsed = exp.elapsed + dt

            -- 检查事件触发
            for _, ev in ipairs(exp.events) do
                if not ev.triggered and exp.elapsed >= ev.triggerAt then
                    ev.triggered = true
                    -- 记录日志
                    exp.log[#exp.log + 1] = { time = exp.elapsed, text = "📍 " .. ev.text }
                    exp.log[#exp.log + 1] = { time = exp.elapsed, text = "   → " .. ev.outcome }
                    -- 累计奖励
                    if ev.rewardType ~= "none" then
                        exp.rewards[ev.rewardType] = (exp.rewards[ev.rewardType] or 0) + ev.rewardAmt
                    end
                end
            end

            -- 检查完成
            if exp.elapsed >= exp.duration then
                exp.completed = true
                exp.log[#exp.log + 1] = { time = exp.elapsed, text = "✅ 远征完成！舰队返航" }
            end
        end
    end
end

--- 领取远征奖励并清除槽位
---@param slotIdx number
---@return table|nil rewards 奖励表 {metal=N, energy=N, ...}
function ExpeditionSystem:Claim(slotIdx)
    local exp = self.slots[slotIdx]
    if not exp or not exp.completed then return nil end

    local rewards = exp.rewards
    -- 保存到历史
    self.history[#self.history + 1] = {
        routeName = exp.routeName,
        duration  = exp.duration,
        rewards   = rewards,
        logCount  = #exp.log,
    }
    if #self.history > 10 then table.remove(self.history, 1) end
    self.totalCompleted = self.totalCompleted + 1

    self.slots[slotIdx] = nil
    return rewards
end

--- 获取远征日志
---@param slotIdx number
---@return table log entries
function ExpeditionSystem:GetLog(slotIdx)
    local exp = self.slots[slotIdx]
    if not exp then return {} end
    return exp.log
end

-- ============================================================================
-- 序列化/反序列化
-- ============================================================================
function ExpeditionSystem:Serialize()
    return {
        slots          = self.slots,
        history        = self.history,
        totalCompleted = self.totalCompleted,
    }
end

function ExpeditionSystem:Deserialize(data)
    if not data then return end
    self.slots          = data.slots or {}
    self.history        = data.history or {}
    self.totalCompleted = data.totalCompleted or 0
end

-- ============================================================================
-- 内部辅助
-- ============================================================================
function ExpeditionSystem:_rollEventType()
    local roll = math.random(1, 100)
    local acc = 0
    for evType, weight in pairs(EVENT_WEIGHTS) do
        acc = acc + weight
        if roll <= acc then return evType end
    end
    return "discover"
end

return ExpeditionSystem
