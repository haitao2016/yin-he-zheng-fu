-- ============================================================================
-- galaxy/SpecialGalaxyTypes.lua  -- 特殊星系类型系统
-- 包含星云、黑洞、虫洞等特殊天体类型
-- ============================================================================

local M = {}

local SPECIAL_GALAXY_TYPES = {
    NEBULA = {
        id = "nebula",
        name = "星云",
        icon = "🌫️",
        description = "神秘的星云区域，可提供资源采集加成但降低舰队移动速度",
        color = {138, 43, 226},
        minSize = 80,
        maxSize = 150,
        effects = {
            resourceBonus = 0.3,
            speedPenalty = 0.5,
            explorationBonus = 1.5,
        },
        rarity = 0.15,
        canColonize = false,
        canExplore = true,
        explorationRewards = {
            { type = "resource", resource = "metal", amount = {50, 150} },
            { type = "resource", resource = "energy", amount = {30, 100} },
            { type = "artifact", chance = 0.2 },
            { type = "commander", chance = 0.1 },
        },
    },
    BLACK_HOLE = {
        id = "blackhole",
        name = "黑洞",
        icon = "🕳️",
        description = "引力极强的黑洞，靠近的舰队会被吸引并受到伤害",
        color = {20, 20, 20},
        glowColor = {100, 50, 150},
        minSize = 30,
        maxSize = 60,
        effects = {
            damagePerSecond = 5,
            pullStrength = 0.5,
            shieldDrain = 0.1,
        },
        rarity = 0.05,
        canColonize = false,
        canExplore = false,
        dangerLevel = "high",
    },
    WORMHOLE = {
        id = "wormhole",
        name = "虫洞",
        icon = "🌀",
        description = "连接遥远星系的神秘通道，可瞬间传送到另一处虫洞",
        color = {0, 200, 255},
        glowColor = {50, 150, 255},
        minSize = 40,
        maxSize = 70,
        effects = {
            teleportRange = 500,
            cooldown = 60,
            energyCost = 100,
        },
        rarity = 0.08,
        canColonize = false,
        canExplore = true,
        isPair = true,
        explorationRewards = {
            { type = "teleport", target = "random" },
            { type = "resource", resource = "nuclear", amount = {20, 50} },
        },
    },
    ASTEROID_FIELD = {
        id = "asteroid_field",
        name = "小行星带",
        icon = "☄️",
        description = "密集的小行星群，可开采稀有矿石但存在碰撞风险",
        color = {169, 169, 169},
        minSize = 60,
        maxSize = 120,
        effects = {
            miningBonus = 0.4,
            collisionDamage = 10,
            detectionReduction = 0.3,
        },
        rarity = 0.2,
        canColonize = false,
        canExplore = true,
        explorationRewards = {
            { type = "resource", resource = "metal", amount = {80, 200} },
            { type = "resource", resource = "nuclear", amount = {10, 30} },
            { type = "module", chance = 0.15 },
        },
    },
    STAR_CLUSTER = {
        id = "star_cluster",
        name = "星团",
        icon = "✨",
        description = "密集的恒星群，提供额外能源产出",
        color = {255, 215, 0},
        minSize = 100,
        maxSize = 180,
        effects = {
            energyBonus = 0.5,
            researchBonus = 0.2,
            shieldRegen = 1,
        },
        rarity = 0.12,
        canColonize = false,
        canExplore = true,
        explorationRewards = {
            { type = "resource", resource = "energy", amount = {100, 250} },
            { type = "tech", chance = 0.1 },
            { type = "commander", chance = 0.08 },
        },
    },
    MAGNETIC_STORM = {
        id = "magnetic_storm",
        name = "磁暴区",
        icon = "⚡",
        description = "强烈的电磁风暴，干扰电子设备但蕴含丰富能源",
        color = {255, 255, 0},
        glowColor = {255, 150, 0},
        minSize = 70,
        maxSize = 130,
        effects = {
            energyBonus = 0.6,
            sensorDisruption = 0.5,
            shieldDamage = 2,
        },
        rarity = 0.1,
        canColonize = false,
        canExplore = true,
        explorationRewards = {
            { type = "resource", resource = "energy", amount = {120, 300} },
            { type = "artifact", chance = 0.25 },
        },
    },
    DUST_CLOUD = {
        id = "dust_cloud",
        name = "尘埃云",
        icon = "💨",
        description = "宇宙尘埃形成的云雾，可隐藏舰队行踪",
        color = {100, 100, 120},
        minSize = 90,
        maxSize = 160,
        effects = {
            stealthBonus = 0.6,
            speedPenalty = 0.3,
            detectionReduction = 0.5,
        },
        rarity = 0.18,
        canColonize = false,
        canExplore = true,
        explorationRewards = {
            { type = "resource", resource = "metal", amount = {30, 80} },
            { type = "stealth_module", chance = 0.1 },
        },
    },
    QUASAR = {
        id = "quasar",
        name = "类星体",
        icon = "💎",
        description = "宇宙中最亮的天体，提供强大的能源和研究加成",
        color = {200, 100, 255},
        glowColor = {255, 150, 255},
        minSize = 25,
        maxSize = 45,
        effects = {
            energyBonus = 1.0,
            researchBonus = 0.5,
            visionBonus = 2,
        },
        rarity = 0.03,
        canColonize = false,
        canExplore = true,
        dangerLevel = "medium",
        explorationRewards = {
            { type = "resource", resource = "energy", amount = {200, 500} },
            { type = "tech", chance = 0.3 },
            { type = "artifact", chance = 0.3 },
        },
    },
}

M.SPECIAL_GALAXY_TYPES = SPECIAL_GALAXY_TYPES

function M.GetType(typeId)
    return SPECIAL_GALAXY_TYPES[typeId:upper()]
end

function M.GetAllTypes()
    local types = {}
    for _, data in pairs(SPECIAL_GALAXY_TYPES) do
        types[#types + 1] = data
    end
    table.sort(types, function(a, b) return a.rarity > b.rarity end)
    return types
end

function M.GenerateSpecialGalaxy(rng, x, y)
    local rand = rng()
    local cumulative = 0
    
    for _, data in pairs(SPECIAL_GALAXY_TYPES) do
        cumulative = cumulative + data.rarity
        if rand <= cumulative then
            local size = data.minSize + rng() * (data.maxSize - data.minSize)
            return {
                type = data.id,
                name = data.name,
                icon = data.icon,
                x = x,
                y = y,
                size = size,
                effects = data.effects,
                color = data.color,
                glowColor = data.glowColor,
                canColonize = data.canColonize,
                canExplore = data.canExplore,
                dangerLevel = data.dangerLevel,
                isPair = data.isPair,
                pairId = nil,
                explored = false,
                explorationProgress = 0,
            }
        end
    end
    
    return nil
end

function M.GenerateWormholePair(rng, areaWidth, areaHeight)
    local pos1 = {
        x = 100 + rng() * (areaWidth - 200),
        y = 100 + rng() * (areaHeight - 200),
    }
    
    local pos2 = {
        x = 100 + rng() * (areaWidth - 200),
        y = 100 + rng() * (areaHeight - 200),
    }
    
    local dist = math.sqrt((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2)
    while dist < 300 do
        pos2.x = 100 + rng() * (areaWidth - 200)
        pos2.y = 100 + rng() * (areaHeight - 200)
        dist = math.sqrt((pos2.x - pos1.x)^2 + (pos2.y - pos1.y)^2)
    end
    
    local wormholeType = SPECIAL_GALAXY_TYPES.WORMHOLE
    local size = wormholeType.minSize + rng() * (wormholeType.maxSize - wormholeType.minSize)
    
    local wh1 = {
        type = wormholeType.id,
        name = wormholeType.name,
        icon = wormholeType.icon,
        x = pos1.x,
        y = pos1.y,
        size = size,
        effects = wormholeType.effects,
        color = wormholeType.color,
        glowColor = wormholeType.glowColor,
        canColonize = wormholeType.canColonize,
        canExplore = wormholeType.canExplore,
        isPair = true,
        pairId = 2,
        explored = false,
        explorationProgress = 0,
    }
    
    local wh2 = {
        type = wormholeType.id,
        name = wormholeType.name,
        icon = wormholeType.icon,
        x = pos2.x,
        y = pos2.y,
        size = size,
        effects = wormholeType.effects,
        color = wormholeType.color,
        glowColor = wormholeType.glowColor,
        canColonize = wormholeType.canColonize,
        canExplore = wormholeType.canExplore,
        isPair = true,
        pairId = 1,
        explored = false,
        explorationProgress = 0,
    }
    
    return wh1, wh2
end

function M.GetExplorationReward(specialGalaxy, rng)
    local typeData = SPECIAL_GALAXY_TYPES[specialGalaxy.type:upper()]
    if not typeData or not typeData.explorationRewards then return nil end
    
    local rewards = {}
    for _, rewardDef in ipairs(typeData.explorationRewards) do
        if rewardDef.chance then
            if rng() <= rewardDef.chance then
                rewards[#rewards + 1] = {
                    type = rewardDef.type,
                    resource = rewardDef.resource,
                    amount = rewardDef.amount and {
                        rewardDef.amount[1] + rng() * (rewardDef.amount[2] - rewardDef.amount[1])
                    } or nil,
                }
            end
        else
            rewards[#rewards + 1] = {
                type = rewardDef.type,
                resource = rewardDef.resource,
                amount = rewardDef.amount and {
                    rewardDef.amount[1] + rng() * (rewardDef.amount[2] - rewardDef.amount[1])
                } or nil,
            }
        end
    end
    
    return #rewards > 0 and rewards or nil
end

function M.ApplyGalaxyEffects(fleet, specialGalaxy, dt)
    if not specialGalaxy or not specialGalaxy.effects then return end
    
    local effects = specialGalaxy.effects
    
    if effects.speedPenalty then
        fleet.speed = fleet.speed * (1 - effects.speedPenalty)
    end
    
    if effects.damagePerSecond then
        fleet.damage = (fleet.damage or 0) + effects.damagePerSecond * dt
    end
    
    if effects.pullStrength then
        local dx = specialGalaxy.x - fleet.x
        local dy = specialGalaxy.y - fleet.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            fleet.x = fleet.x + (dx / dist) * effects.pullStrength * dt * 100
            fleet.y = fleet.y + (dy / dist) * effects.pullStrength * dt * 100
        end
    end
    
    if effects.shieldDrain and fleet.shield then
        fleet.shield = math.max(0, fleet.shield - effects.shieldDrain * dt)
    end
end

function M.IsDangerous(specialGalaxy)
    if not specialGalaxy then return false end
    return specialGalaxy.dangerLevel and specialGalaxy.dangerLevel ~= "low"
end

function M.CanInteract(specialGalaxy)
    if not specialGalaxy then return false end
    return specialGalaxy.canExplore or specialGalaxy.canColonize
end

return M