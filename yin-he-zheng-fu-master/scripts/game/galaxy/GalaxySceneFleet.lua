-- ============================================================================
-- game/galaxy/GalaxySceneFleet.lua  -- 编队管理模块
-- ============================================================================

local M = {}

local FLEET_ARRIVE_RADIUS = 25
local FLEET_ICON_RADIUS   = 14
local FLEET_MINE_RANGE    = 30
local FLEET_MINE_INTERVAL = 2.0

function M.countEngineersInFleet(fm, fleetId)
    if not fm then return 0 end
    local fl = fm.fleets[fleetId]
    if not fl then return 0 end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "ENGINEER" then return e.count end
    end
    return 0
end

function M.fleetHasExplorer(fm, fleetId)
    if not fm then return false end
    local fl = fm.fleets[fleetId]
    if not fl then return false end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "EXPLORER" and e.count > 0 then return true end
    end
    return false
end

function M.getFleetSpeed(fm, rm, SHIP_TYPES, StarWeather, fleetId)
    if not fm then return 80 end
    local fl = fm.fleets[fleetId]
    if not fl or #fl.ships == 0 then return 80 end
    local minSpeed = 9999
    for _, entry in ipairs(fl.ships) do
        local st = SHIP_TYPES[entry.shipType]
        if st and st.speed and st.speed < minSpeed then
            minSpeed = st.speed
        end
    end
    local base = minSpeed < 9999 and minSpeed or 80
    local mult = (rm and rm.baseBonus and rm.baseBonus.fleetSpeedMult) or 1.0
    local weatherMod = StarWeather.GetSpeedMod()
    return base * mult * weatherMod
end

function M.getOrCreateFleetObj(fleetObjs, fm, seedShip, fleetId)
    if fleetObjs[fleetId] then return fleetObjs[fleetId] end
    local maxF   = fm and fm.maxFleets or 4
    local angle  = (fleetId - 1) / maxF * math.pi * 2
    local radius = 220 + math.random() * 60
    local bx = seedShip.x + math.cos(angle) * radius
    local by = seedShip.y + math.sin(angle) * radius
    fleetObjs[fleetId] = {
        x       = bx,
        y       = by,
        targetX = nil,
        targetY = nil,
        angle   = angle + math.pi,
        pulse   = math.random() * math.pi * 2,
    }
    return fleetObjs[fleetId]
end

function M.updateFleets(dt, fm, rm, getFleetSpeed, onFleetContactPirateBase_, 
                          onFleetContactPlanet_, getOrCreateFleetObj, fleetObjs)
    if not fm then return end
    for i = 1, fm.maxFleets do
        local fl = fm.fleets[i]
        if fl and #fl.ships > 0 then
            local obj = getOrCreateFleetObj(fleetObjs, fm, {x=0,y=0}, i)
            obj.pulse = obj.pulse + dt

            if obj.targetX then
                local dx  = obj.targetX - obj.x
                local dy  = obj.targetY - obj.y
                local d   = math.sqrt(dx*dx + dy*dy)
                if d <= FLEET_ARRIVE_RADIUS then
                    obj.x       = obj.targetX
                    obj.y       = obj.targetY
                    obj.targetX = nil
                    obj.targetY = nil

                    if obj.pirateBaseTarget and onFleetContactPirateBase_ then
                        local bid = obj.pirateBaseTarget
                        obj.pirateBaseTarget = nil
                        onFleetContactPirateBase_(i, bid)
                    end
                else
                    local speed = getFleetSpeed(fm, rm, nil, {GetSpeedMod=function() return 1 end}, i)
                    local move = speed * dt
                    if move > d then move = d end
                    local nx = obj.x + dx / d * move
                    local ny = obj.y + dy / d * move
                    obj.angle = math.atan2(dy, dx)
                    obj.x = nx
                    obj.y = ny
                end
            end

            if obj.miningTarget then
                local mx, my = obj.miningTarget.x, obj.miningTarget.y
                local dx = mx - obj.x
                local dy = my - obj.y
                local d = math.sqrt(dx*dx + dy*dy)
                if d > FLEET_MINE_RANGE then
                    local speed = getFleetSpeed(fm, rm, nil, {GetSpeedMod=function() return 1 end}, i)
                    local move = speed * dt
                    if move > d then move = d end
                    obj.x = obj.x + dx / d * move
                    obj.y = obj.y + dy / d * move
                else
                    obj.mineTimer = (obj.mineTimer or 0) + dt
                    if obj.mineTimer >= FLEET_MINE_INTERVAL then
                        obj.mineTimer = 0
                    end
                end
            end
        end
    end
end

function M.findNearbyUncolonizedPlanet(starSystems, dist2, PLANET_CONTACT_DIST, wx, wy)
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            if not p.colonized and not p.isBase then
                local px = sys.x + math.cos(p.angle) * p.orbitRadius
                local py = sys.y + math.sin(p.angle) * p.orbitRadius
                if dist2(wx, wy, px, py) < PLANET_CONTACT_DIST then
                    return p
                end
            end
        end
    end
    return nil
end

return M