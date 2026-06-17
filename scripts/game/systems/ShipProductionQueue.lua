---@diagnostic disable: assign-type-mismatch, return-type-mismatch
--- ShipProductionQueue — 造船厂队列系统
--- 从 Systems.lua 机械拆分，无逻辑修改
require("game.GameConstants")

local ShipProductionQueue = {}
ShipProductionQueue.__index = ShipProductionQueue

function ShipProductionQueue.new(rm)
    return setmetatable({ rm=rm, items={}, timer=0 }, ShipProductionQueue)
end

function ShipProductionQueue:canQueue(shipType, planet)
    if not planet.colonized then return false, "未殖民" end
    local hasShipyard = false
    -- 检查行星建筑
    if planet.buildings then
        for _, b in ipairs(planet.buildings) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    -- 检查基地模块（isBase 标记）
    if not hasShipyard and planet.isBase and planet.modules then
        for _, b in ipairs(planet.modules) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    if not hasShipyard then return false, "需建造造船厂" end
    if not self.rm:canAfford(SHIP_COSTS[shipType]) then return false, "资源不足" end
    return true, ""
end

function ShipProductionQueue:queue(shipType, planet)
    local ok, reason = self:canQueue(shipType, planet)
    if not ok then return false, reason end
    self.rm:spend(SHIP_COSTS[shipType])
    local buildTime = SHIP_TYPES[shipType].buildTime
    self.items[#self.items+1] = {
        shipType  = shipType,
        planet    = planet,
        remaining = buildTime,
        totalTime = buildTime,
        progress  = 0,
    }
    return true, ""
end

-- P2-3: 取消队列中第 index 项（退还已花费资源）
function ShipProductionQueue:cancel(index)
    if index < 1 or index > #self.items then return false end
    local job  = self.items[index]
    local cost = SHIP_COSTS[job.shipType]
    if cost and self.rm then
        for res, amt in pairs(cost) do
            self.rm:add(res, amt)
        end
    end
    table.remove(self.items, index)
    return true
end

-- P2-3: 将队列中第 index 项上移一位（index 必须 >= 2）
function ShipProductionQueue:promote(index)
    if index <= 1 or index > #self.items then return false end
    self.items[index-1], self.items[index] = self.items[index], self.items[index-1]
    return true
end

function ShipProductionQueue:update(dt)
    if #self.items == 0 then return nil end
    local job = self.items[1]
    local shipMult = (self.rm.baseBonus and self.rm.baseBonus.shipyardMult) or 1.0
    job.remaining = job.remaining - dt * shipMult
    job.progress  = 1.0 - math.max(0, job.remaining) / job.totalTime
    if job.remaining <= 0 then
        local completed = job
        table.remove(self.items, 1)
        print("[Shipyard] 完成生产: " .. completed.shipType)
        return completed
    end
    return nil
end

--- 序列化（仅保存队列项，不含 planet 对象引用）
function ShipProductionQueue:serialize()
    local items = {}
    for _, job in ipairs(self.items) do
        items[#items + 1] = {
            shipType  = job.shipType,
            remaining = job.remaining,
            totalTime = job.totalTime,
            planetId  = job.planet and job.planet.id or nil,
        }
    end
    return { items = items }
end

--- 从存档恢复（planetResolver 是一个函数，接受 id 返回行星对象）
function ShipProductionQueue:deserialize(data, planetResolver)
    if not data or not data.items then return end
    self.items = {}
    for _, d in ipairs(data.items) do
        local planet = planetResolver and planetResolver(d.planetId) or nil
        self.items[#self.items + 1] = {
            shipType  = d.shipType,
            remaining = d.remaining,
            totalTime = d.totalTime,
            progress  = 1.0 - (d.remaining / math.max(1, d.totalTime)),
            planet    = planet,
        }
    end
end

return ShipProductionQueue
