-- ============================================================================
-- game/galaxy/GalaxySceneSaveLoad.lua  -- 存档管理模块
-- ============================================================================

local M = {}

function M.GetSaveData(starSystems, deepSpaceSystems, seedShip, fleetObjs, priorityPlanetIds_, 
                       currentSeed_, currentShape_)
    local planets = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            if p.colonized then
                local buildings = {}
                for _, b in ipairs(p.buildings) do
                    local prod = {}
                    for res, v in pairs(b.currentProd or {}) do
                        prod[res] = v
                    end
                    buildings[#buildings + 1] = {
                        key         = b.key,
                        name        = b.name,
                        level       = b.level,
                        currentProd = prod,
                        spec        = b.spec,
                    }
                end
                local appliedTechs = {}
                for techId, _ in pairs(p.appliedTechs or {}) do
                    appliedTechs[#appliedTechs + 1] = techId
                end
                planets[#planets + 1] = {
                    id           = p.id,
                    colonized    = true,
                    level        = p.level or 1,
                    buildings    = buildings,
                    appliedTechs = appliedTechs,
                    constructing = p.constructing and {
                        key       = p.constructing.key,
                        remaining = p.constructing.remaining,
                        totalTime = p.constructing.totalTime,
                        level     = p.constructing.level,
                        isUpgrade = p.constructing.isUpgrade,
                        targetIdx = p.constructing.targetIdx,
                    } or nil,
                }
            end
        end
    end
    
    local base = nil
    if seedShip.colonized then
        local baseBuildings = {}
        for _, b in ipairs(seedShip.buildings) do
            baseBuildings[#baseBuildings + 1] = { key = b.key, name = b.name, level = b.level }
        end
        base = {
            colonized    = true,
            x            = seedShip.x,
            y            = seedShip.y,
            coreLevel    = seedShip.coreLevel or 1,
            buildings    = baseBuildings,
            constructing = seedShip.constructing and {
                key           = seedShip.constructing.key,
                remaining     = seedShip.constructing.remaining,
                totalTime     = seedShip.constructing.totalTime,
                level         = seedShip.constructing.level,
                isUpgrade     = seedShip.constructing.isUpgrade,
                targetIdx     = seedShip.constructing.targetIdx,
                isCoreUpgrade = seedShip.constructing.isCoreUpgrade,
            } or nil,
        }
    end
    
    local deepPlanets = {}
    for _, sys in ipairs(deepSpaceSystems) do
        for _, p in ipairs(sys.planets) do
            if p.colonized then
                local buildings = {}
                for _, b in ipairs(p.buildings) do
                    local prod = {}
                    for res, v in pairs(b.currentProd or {}) do prod[res] = v end
                    buildings[#buildings + 1] = {
                        key = b.key, name = b.name, level = b.level, currentProd = prod,
                        spec = b.spec,
                    }
                end
                deepPlanets[#deepPlanets + 1] = {
                    id        = p.id,
                    colonized = true,
                    buildings = buildings,
                }
            end
        end
    end
    
    local fleets = {}
    for fleetId, obj in pairs(fleetObjs) do
        fleets[#fleets + 1] = {
            id      = fleetId,
            x       = math.floor(obj.x + 0.5),
            y       = math.floor(obj.y + 0.5),
            targetX = obj.targetX and math.floor(obj.targetX + 0.5) or nil,
            targetY = obj.targetY and math.floor(obj.targetY + 0.5) or nil,
            angle   = obj.angle or 0,
        }
    end
    
    local priorityIds = {}
    for id, _ in pairs(priorityPlanetIds_) do
        priorityIds[#priorityIds + 1] = id
    end
    
    return { 
        planets = planets, 
        base = base, 
        deepPlanets = deepPlanets, 
        fleets = fleets,
        priorityIds = priorityIds,
        seed = currentSeed_, 
        shape = currentShape_ 
    }
end

function M.LoadSaveData(data, starSystems, deepSpaceSystems, seedShip, allPlanets_, 
                       colonizedPlanets_, fleetObjs, priorityPlanetIds_, getOrCreateFleetObj, rm)
    if not data then return end

    local planetMap = {}
    for _, sys in ipairs(starSystems) do
        for _, p in ipairs(sys.planets) do
            planetMap[p.id] = p
        end
    end

    if data.planets then
        if rm then
            rm.rates = { minerals=2, energy=5, crystal=0.5,
                         metal=0, esource=0, nuclear=0,
                         population=0.1, credits=0 }
        end
        for _, pd in ipairs(data.planets) do
            local p = planetMap[pd.id]
            if p then
                p.colonized    = true
                p.owner        = "player"
                p.level        = pd.level or 1
                p.buildings    = {}
                p.appliedTechs = {}
                
                for _, bd in ipairs(pd.buildings or {}) do
                    local bld = {
                        key         = bd.key,
                        name        = bd.name,
                        level       = bd.level,
                        currentProd = {},
                        spec        = bd.spec,
                    }
                    for res, v in pairs(bd.currentProd or {}) do
                        bld.currentProd[res] = v
                        if rm then
                            rm.rates[res] = (rm.rates[res] or 0) + v
                        end
                    end
                    p.buildings[#p.buildings + 1] = bld
                end
                
                for _, techId in ipairs(pd.appliedTechs or {}) do
                    p.appliedTechs[techId] = true
                end
                
                if pd.constructing then
                    p.constructing = {
                        key       = pd.constructing.key,
                        remaining = pd.constructing.remaining,
                        totalTime = pd.constructing.totalTime,
                        progress  = 1.0 - (pd.constructing.remaining / math.max(1, pd.constructing.totalTime)),
                        level     = pd.constructing.level,
                        isUpgrade = pd.constructing.isUpgrade,
                        targetIdx = pd.constructing.targetIdx,
                    }
                end
            end
        end
    end

    if data.base and data.base.colonized then
        seedShip.colonized  = true
        seedShip.state      = "deployed"
        seedShip.x          = data.base.x or seedShip.x
        seedShip.y          = data.base.y or seedShip.y
        seedShip.coreLevel  = data.base.coreLevel or 1
        seedShip.buildings  = {}
        for _, bd in ipairs(data.base.buildings or {}) do
            seedShip.buildings[#seedShip.buildings + 1] = {
                key = bd.key, name = bd.name, level = bd.level
            }
        end
        if data.base.constructing then
            local c = data.base.constructing
            seedShip.constructing = {
                key           = c.key,
                remaining     = c.remaining,
                totalTime     = c.totalTime,
                progress      = 1.0 - (c.remaining / math.max(1, c.totalTime)),
                level         = c.level,
                isUpgrade     = c.isUpgrade,
                targetIdx     = c.targetIdx,
                isCoreUpgrade = c.isCoreUpgrade,
            }
        end
    end

    if data.deepPlanets and #data.deepPlanets > 0 then
        local dsMap = {}
        for _, sys in ipairs(deepSpaceSystems) do
            for _, p in ipairs(sys.planets) do
                dsMap[p.id] = p
            end
        end
        for _, pd in ipairs(data.deepPlanets) do
            local p = dsMap[pd.id]
            if p then
                p.colonized = true
                p.owner     = "player"
                p.buildings = {}
                for _, bd in ipairs(pd.buildings or {}) do
                    local bld = { key = bd.key, name = bd.name, level = bd.level, currentProd = {}, spec = bd.spec }
                    for res, v in pairs(bd.currentProd or {}) do
                        bld.currentProd[res] = v
                        if rm then rm.rates[res] = (rm.rates[res] or 0) + v end
                    end
                    p.buildings[#p.buildings + 1] = bld
                end
            end
        end
    end

    colonizedPlanets_ = {}
    for _, p in ipairs(allPlanets_) do
        if p.colonized then
            colonizedPlanets_[#colonizedPlanets_+1] = p
        end
    end

    if data.fleets then
        for _, fd in ipairs(data.fleets) do
            local obj = getOrCreateFleetObj(fleetObjs, nil, seedShip, fd.id)
            obj.x       = fd.x or obj.x
            obj.y       = fd.y or obj.y
            obj.targetX = fd.targetX
            obj.targetY = fd.targetY
            obj.angle   = fd.angle or obj.angle
        end
    end

    priorityPlanetIds_ = {}
    if data.priorityIds then
        for _, id in ipairs(data.priorityIds) do
            priorityPlanetIds_[id] = true
        end
    end
    
    return {
        colonizedPlanets = colonizedPlanets_,
        priorityPlanetIds = priorityPlanetIds_
    }
end

return M