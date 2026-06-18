---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/StarMapVariantSystem.lua -- 星图变体与种子系统
-- V2.8 Map-1
-- ============================================================================

local StarMapVariantSystem = {}

-- ============================================================================
-- 星图变体定义（全局）
-- ============================================================================

MAP_VARIANTS = {
    STANDARD = {
        id = "STANDARD",
        name = "标准星域",
        nameEn = "Standard",
        desc = "标准银河星图：资源与挑战分布均衡。",
        resourceMult = 1.0,
        enemyStrength = 1.0,
        eventFrequency = 1.0,
        mapSize = 1.0,
        seedPrefix = "ST",
    },
    RESOURCE_RICH = {
        id = "RESOURCE_RICH",
        name = "资源富矿",
        nameEn = "Resource-Rich",
        desc = "矿产与能源极其丰富的星域，但敌人活动也更频繁。",
        resourceMult = 1.6,
        enemyStrength = 1.1,
        eventFrequency = 1.2,
        mapSize = 1.0,
        seedPrefix = "RR",
    },
    BARREN = {
        id = "BARREN",
        name = "贫瘠之地",
        nameEn = "Barren",
        desc = "资源稀少的荒芜星域，敌人活动相对较低。",
        resourceMult = 0.6,
        enemyStrength = 0.8,
        eventFrequency = 0.7,
        mapSize = 1.2,
        seedPrefix = "BR",
    },
    HIGH_THREAT = {
        id = "HIGH_THREAT",
        name = "高危战区",
        nameEn = "High Threat",
        desc = "敌人密布的危险战区，挑战极高，战利品也更丰厚。",
        resourceMult = 1.2,
        enemyStrength = 1.6,
        eventFrequency = 1.5,
        mapSize = 0.9,
        seedPrefix = "HT",
    },
}

local VARIANT_ORDER = { "STANDARD", "RESOURCE_RICH", "BARREN", "HIGH_THREAT" }

-- ============================================================================
-- 运行时状态
-- ============================================================================

local RuntimeMapState = {
    currentVariant = "STANDARD",
    seed = 0,
    seedStr = "",
}

-- ============================================================================
-- 种子生成（字符串 -> 数字种子）
-- ============================================================================

-- FNV-1a 风格简单 32 位哈希，保证同字符串 -> 同数字种子
local function hashStringToSeed(str)
    if str == nil or str == "" then
        return math.random(1, 2147483647)
    end
    local h = 2166136261
    for i = 1, #str do
        local b = string.byte(str, i)
        h = (h ~ b) * 16777619
        h = h % 4294967296
    end
    return h
end

function StarMapVariantSystem.generateSeed(seedStr)
    if seedStr == nil or seedStr == "" then
        -- 随机种子：基于时间与随机数
        local base = os.time()
        local rand = math.random(1, 999999)
        RuntimeMapState.seed = (base + rand) % 2147483647
        if RuntimeMapState.seed <= 0 then
            RuntimeMapState.seed = RuntimeMapState.seed + 2147483647
        end
        local variant = MAP_VARIANTS[RuntimeMapState.currentVariant] or MAP_VARIANTS.STANDARD
        RuntimeMapState.seedStr = variant.seedPrefix .. "-" .. tostring(RuntimeMapState.seed)
        return RuntimeMapState.seed, RuntimeMapState.seedStr
    end

    -- 给定字符串：取前缀以识别变体
    local prefix, rest = seedStr:match("^([A-Z]+)%-(.+)$")
    local seedNum = 0
    if prefix and rest then
        seedNum = hashStringToSeed(rest)
        for _, key in ipairs(VARIANT_ORDER) do
            if MAP_VARIANTS[key].seedPrefix == prefix then
                RuntimeMapState.currentVariant = key
                break
            end
        end
    else
        seedNum = hashStringToSeed(seedStr)
    end
    RuntimeMapState.seed = seedNum
    local variant = MAP_VARIANTS[RuntimeMapState.currentVariant] or MAP_VARIANTS.STANDARD
    RuntimeMapState.seedStr = variant.seedPrefix .. "-" .. tostring(seedNum)
    return seedNum, RuntimeMapState.seedStr
end

-- ============================================================================
-- 变体选择与修饰
-- ============================================================================

function StarMapVariantSystem.setVariant(variantId, gameState)
    if variantId == nil then return false, "变体标识不能为空" end
    local variant = MAP_VARIANTS[variantId]
    if variant == nil then
        return false, "未知星图变体: " .. tostring(variantId)
    end
    RuntimeMapState.currentVariant = variantId
    -- 重新生成带新前缀的种子字符串
    if RuntimeMapState.seedStr and RuntimeMapState.seedStr ~= "" then
        RuntimeMapState.seedStr = variant.seedPrefix .. "-" .. tostring(RuntimeMapState.seed)
    end
    return true, "星图变体已设置: " .. variant.name
end

function StarMapVariantSystem.getCurrentVariant()
    return RuntimeMapState.currentVariant
end

function StarMapVariantSystem.getVariantMods(gameState)
    local variant = MAP_VARIANTS[RuntimeMapState.currentVariant] or MAP_VARIANTS.STANDARD
    return {
        variant = variant.id,
        name = variant.name,
        resourceMult = variant.resourceMult,
        enemyStrength = variant.enemyStrength,
        eventFrequency = variant.eventFrequency,
        mapSize = variant.mapSize,
        seed = RuntimeMapState.seed,
        seedStr = RuntimeMapState.seedStr,
    }
end

function StarMapVariantSystem.getAvailableVariants()
    local list = {}
    for _, key in ipairs(VARIANT_ORDER) do
        local v = MAP_VARIANTS[key]
        table.insert(list, {
            id = v.id,
            name = v.name,
            nameEn = v.nameEn,
            desc = v.desc,
            resourceMult = v.resourceMult,
            enemyStrength = v.enemyStrength,
            isCurrent = (RuntimeMapState.currentVariant == v.id),
        })
    end
    return list
end

function StarMapVariantSystem.getMapDescription(gameState)
    local variant = MAP_VARIANTS[RuntimeMapState.currentVariant] or MAP_VARIANTS.STANDARD
    local seedStr = RuntimeMapState.seedStr
    if seedStr == nil or seedStr == "" then
        seedStr = variant.seedPrefix .. "-" .. tostring(RuntimeMapState.seed)
    end
    return string.format("[%s] %s - 种子: %s", variant.seedPrefix, variant.name, seedStr)
end

function StarMapVariantSystem.getSeed()
    return RuntimeMapState.seed, RuntimeMapState.seedStr
end

-- 应用种子到 math.randomseed（供星图生成器使用）
function StarMapVariantSystem.applySeed()
    local seed = RuntimeMapState.seed
    if seed == nil or seed == 0 then
        seed = os.time()
        RuntimeMapState.seed = seed
    end
    math.randomseed(seed)
    return seed
end

-- ============================================================================
-- 存档
-- ============================================================================

function StarMapVariantSystem.serialize()
    return {
        currentVariant = RuntimeMapState.currentVariant,
        seed = RuntimeMapState.seed,
        seedStr = RuntimeMapState.seedStr,
    }
end

function StarMapVariantSystem.deserialize(data)
    if data == nil then return false end
    if data.currentVariant and MAP_VARIANTS[data.currentVariant] then
        RuntimeMapState.currentVariant = data.currentVariant
    end
    if data.seed then
        RuntimeMapState.seed = data.seed
    end
    if data.seedStr then
        RuntimeMapState.seedStr = data.seedStr
    end
    return true
end

-- ============================================================================
-- 导出
-- ============================================================================

return StarMapVariantSystem
