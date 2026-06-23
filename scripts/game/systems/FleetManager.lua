---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--- FleetManager — 编队系统
--- 从 Systems.lua 机械拆分，无逻辑修改
require("game.GameConstants")

local MAX_FLEET_SLOTS  = 10   -- 理论上限
local INIT_FLEET_COUNT = 5    -- 玩家初始解锁编队数
local MAX_SHIPS_PER_FLEET = 10  -- 每编队最多舰船数

local FleetManager = {}
FleetManager.__index = FleetManager

function FleetManager.new()
    local self = setmetatable({}, FleetManager)
    self.maxFleets = INIT_FLEET_COUNT   -- 已解锁编队数（可扩展）
    self.fleets    = {}                  -- 编队列表，索引 1~maxFleets
    self.reserve   = {}                  -- 储备池 { [shipType]=count }
    -- P1-1: 改装系统
    self.salvageParts = 0                -- 残骸零件（改装货币）
    self.moduleInventory = {}            -- 已拥有模块 { [moduleKey]=count }
    -- modules per (fleetId, shipType): self.fleets[i].modules[shipType] = moduleKey
    for i = 1, INIT_FLEET_COUNT do
        self.fleets[i] = {
            id       = i,
            name     = "第 " .. i .. " 编队",
            ships    = {},   -- { shipType, count } 列表（同类型合并显示）
            modules  = {},   -- { [shipType] = moduleKey } 改装槽
            deployedCount = 0,  -- 已在战场的数量（战斗时更新）
        }
    end
    return self
end

--- 造船完成 → 进入储备池
function FleetManager:addToReserve(shipType)
    self.reserve[shipType] = (self.reserve[shipType] or 0) + 1
end

--- 从储备池取一艘 → 加入指定编队
function FleetManager:assignFromReserve(shipType, fleetId)
    local n = self.reserve[shipType] or 0
    if n <= 0 then return false, "储备中没有该舰船" end
    local ok, reason = self:addShip(fleetId, shipType)
    if not ok then return false, reason end
    self.reserve[shipType] = n - 1
    if self.reserve[shipType] <= 0 then self.reserve[shipType] = nil end
    return true
end

--- 储备池总数
function FleetManager:reserveTotal()
    local n = 0
    for _, c in pairs(self.reserve) do n = n + c end
    return n
end

-- ── P1-1: 改装模块 API ────────────────────────────────────────────────────

--- 装备模块（花费残骸零件）
--- @return boolean, string?
function FleetManager:equipModule(fleetId, shipType, moduleKey)
    local fl = self.fleets[fleetId]
    if not fl then return false, "编队不存在" end
    local modDef = SHIP_MODULES[moduleKey]
    if not modDef then return false, "模块不存在" end
    -- 检查该编队是否有该舰种
    local hasShip = false
    for _, e in ipairs(fl.ships) do
        if e.shipType == shipType then hasShip = true; break end
    end
    if not hasShip then return false, "编队中无此舰种" end
    -- 费用：替换比新装便宜
    local cost = fl.modules[shipType] and modDef.replaceCost or modDef.cost
    if self.salvageParts < cost then return false, "残骸零件不足（需要"..cost.."）" end
    -- 卸下旧模块（归还背包）
    local old = fl.modules[shipType]
    if old then
        self.moduleInventory[old] = (self.moduleInventory[old] or 0) + 1
    end
    -- 从背包扣除新模块（如果背包有则免费取，否则视为"制造"直接装上）
    if (self.moduleInventory[moduleKey] or 0) > 0 then
        self.moduleInventory[moduleKey] = self.moduleInventory[moduleKey] - 1
        if self.moduleInventory[moduleKey] <= 0 then self.moduleInventory[moduleKey] = nil end
    end
    -- 扣费 & 装备
    self.salvageParts = self.salvageParts - cost
    fl.modules[shipType] = moduleKey
    return true
end

--- 卸下模块（免费）
function FleetManager:unequipModule(fleetId, shipType)
    local fl = self.fleets[fleetId]
    if not fl then return false end
    local old = fl.modules[shipType]
    if not old then return false end
    self.moduleInventory[old] = (self.moduleInventory[old] or 0) + 1
    fl.modules[shipType] = nil
    return true
end

--- 获取编队中某舰种装备的模块 key（nil = 未装备）
function FleetManager:getModule(fleetId, shipType)
    local fl = self.fleets[fleetId]
    return fl and fl.modules[shipType] or nil
end

--- 添加残骸零件
function FleetManager:addSalvage(amount)
    self.salvageParts = self.salvageParts + (amount or 0)
end

--- 向编队添加一艘舰船（建造完成时调用）
--- 返回 true/false
function FleetManager:addShip(fleetId, shipType)
    local fl = self.fleets[fleetId]
    if not fl then return false, "编队不存在" end
    -- 检查编队上限
    if self:totalShips(fleetId) >= MAX_SHIPS_PER_FLEET then
        return false, "编队已满（上限 " .. MAX_SHIPS_PER_FLEET .. " 艘）"
    end
    -- 查找同类型条目
    for _, entry in ipairs(fl.ships) do
        if entry.shipType == shipType then
            entry.count = entry.count + 1
            return true
        end
    end
    fl.ships[#fl.ships+1] = { shipType=shipType, count=1 }
    return true
end

--- 从编队移除一艘舰船（通常在舰船阵亡时调用）
function FleetManager:removeShip(fleetId, shipType)
    local fl = self.fleets[fleetId]
    if not fl then return end
    for i, entry in ipairs(fl.ships) do
        if entry.shipType == shipType then
            entry.count = entry.count - 1
            if entry.count <= 0 then table.remove(fl.ships, i) end
            return
        end
    end
end

--- 移动舰船：将 shipType 从 srcFleet 移到 dstFleet（1 艘）
function FleetManager:moveShip(srcId, dstId, shipType)
    if srcId == dstId then return false, "同一编队" end
    local src = self.fleets[srcId]
    local dst = self.fleets[dstId]
    if not src or not dst then return false, "编队不存在" end
    -- 检查来源是否有该舰
    local found = false
    for _, e in ipairs(src.ships) do
        if e.shipType == shipType and e.count > 0 then found = true; break end
    end
    if not found then return false, "编队中没有该舰船" end
    self:removeShip(srcId, shipType)
    self:addShip(dstId, shipType)
    return true
end

--- 获取编队的舰船总数
function FleetManager:totalShips(fleetId)
    local fl = self.fleets[fleetId]
    if not fl then return 0 end
    local n = 0
    for _, e in ipairs(fl.ships) do n = n + e.count end
    return n
end

--- 解锁更多编队槽位（逐步 +1，内部兼容接口）
function FleetManager:unlock()
    if self.maxFleets >= MAX_FLEET_SLOTS then return false, "已达上限" end
    self.maxFleets = self.maxFleets + 1
    local i = self.maxFleets
    self.fleets[i] = {
        id=i, name="第 " .. i .. " 编队", ships={}, deployedCount=0
    }
    return true
end

--- 根据基地模块效果重新设定编队上限（applyBaseModuleEffects 调用）
--- target：期望的 maxFleets 值，自动 clamp 到 [INIT_FLEET_COUNT, MAX_FLEET_SLOTS]
function FleetManager:setMaxFleets(target)
    local clamped = math.max(INIT_FLEET_COUNT, math.min(MAX_FLEET_SLOTS, target))
    if clamped == self.maxFleets then return end
    self.maxFleets = clamped
    -- 补全缺少的编队槽位（仅增加，不删除已有编队的舰船）
    for i = #self.fleets + 1, self.maxFleets do
        self.fleets[i] = {
            id=i, name="第 " .. i .. " 编队", ships={}, deployedCount=0
        }
    end
end

--- 序列化
function FleetManager:serialize()
    local fleets = {}
    for i, fl in ipairs(self.fleets) do
        local ships = {}
        for _, e in ipairs(fl.ships) do
            ships[#ships + 1] = { shipType = e.shipType, count = e.count }
        end
        fleets[i] = { id = fl.id, name = fl.name, ships = ships, modules = fl.modules }
    end
    -- 序列化储备池
    local reserve = {}
    for st, cnt in pairs(self.reserve) do
        reserve[#reserve + 1] = { shipType = st, count = cnt }
    end
    return {
        maxFleets = self.maxFleets, fleets = fleets, reserve = reserve,
        salvageParts = self.salvageParts,
        moduleInventory = self.moduleInventory,
    }
end

--- 从存档恢复
function FleetManager:deserialize(data)
    if not data then return end
    self.maxFleets = data.maxFleets or INIT_FLEET_COUNT
    self.fleets    = {}
    for i, fd in ipairs(data.fleets or {}) do
        local ships = {}
        for _, e in ipairs(fd.ships or {}) do
            ships[#ships + 1] = { shipType = e.shipType, count = e.count }
        end
        self.fleets[i] = {
            id = fd.id or i, name = fd.name or ("第 " .. i .. " 编队"),
            ships = ships, modules = fd.modules or {}, deployedCount = 0,
        }
    end
    -- 补全不足的编队槽位
    for i = #self.fleets + 1, self.maxFleets do
        self.fleets[i] = { id = i, name = "第 " .. i .. " 编队", ships = {}, modules = {}, deployedCount = 0 }
    end
    -- 恢复储备池
    self.reserve = {}
    for _, e in ipairs(data.reserve or {}) do
        if e.shipType and e.count then
            self.reserve[e.shipType] = e.count
        end
    end
    -- P1-1: 恢复改装数据
    self.salvageParts = data.salvageParts or 0
    self.moduleInventory = data.moduleInventory or {}
end

return FleetManager
