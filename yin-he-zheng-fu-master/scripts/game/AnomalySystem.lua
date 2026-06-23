-- ============================================================================
-- game/AnomalySystem.lua  -- P2-1: 星域异象系统
-- 负责: 异象类型定义、异象生成/轮转、战斗修正计算、星图视觉数据
-- 设计: 每局游戏中星域会周期性出现异象,持续数个波次,给予战斗加成或惩罚
-- ============================================================================

local AnomalySystem = {}

-- ============================================================================
-- 异象类型定义 (6种)
-- ============================================================================
local ANOMALY_TYPES = {
    -- 1. 离子风暴: 护盾增强但移速降低
    ION_STORM = {
        id       = "ION_STORM",
        name     = "离子风暴",
        icon     = "⚡",
        desc     = "高能离子粒子充斥星域,护盾效率+30%,舰船移速-20%",
        color    = {80, 180, 255},     -- 蓝色
        effects  = {
            shieldMult  = 1.3,   -- 护盾倍率
            speedMult   = 0.8,   -- 移速倍率
        },
        visual   = "storm",            -- 视觉类型(星图渲染用)
        duration = {3, 5},             -- 持续波次 [min, max]
    },
    -- 2. 暗物质涌流: 攻击力增强但护盾削弱
    DARK_MATTER = {
        id       = "DARK_MATTER",
        name     = "暗物质涌流",
        icon     = "🌀",
        desc     = "暗物质涌入战场,武器伤害+25%,护盾效率-25%",
        color    = {160, 60, 200},     -- 紫色
        effects  = {
            damageMult  = 1.25,
            shieldMult  = 0.75,
        },
        visual   = "vortex",
        duration = {2, 4},
    },
    -- 3. 引力异常: 敌人减速,我方加速
    GRAVITY_WELL = {
        id       = "GRAVITY_WELL",
        name     = "引力异常",
        icon     = "🕳️",
        desc     = "局部引力扭曲,我方加速+15%,敌方减速-20%",
        color    = {200, 100, 40},     -- 橙色
        effects  = {
            speedMult      = 1.15,
            enemySpeedMult = 0.8,
        },
        visual   = "gravity",
        duration = {3, 5},
    },
    -- 4. 太阳耀斑: 双方受伤加倍(攻守皆增)
    SOLAR_FLARE = {
        id       = "SOLAR_FLARE",
        name     = "太阳耀斑",
        icon     = "☀",
        desc     = "恒星耀斑爆发,所有武器伤害×1.5,所有舰船HP-10%",
        color    = {255, 200, 40},     -- 金黄
        effects  = {
            damageMult      = 1.5,
            enemyDamageMult = 1.5,
            hpMult          = 0.9,
        },
        visual   = "flare",
        duration = {2, 3},
    },
    -- 5. 星云屏蔽: 隐蔽性增强,首次伤害大幅降低
    NEBULA_SHROUD = {
        id       = "NEBULA_SHROUD",
        name     = "星云屏蔽",
        icon     = "🌫️",
        desc     = "浓密星云笼罩,首轮攻击伤害-50%,后续恢复正常",
        color    = {100, 200, 150},    -- 绿色
        effects  = {
            firstStrikeMult = 0.5,     -- 首轮伤害倍率
        },
        visual   = "nebula",
        duration = {3, 4},
    },
    -- 6. 时空裂隙: 随机强化一项属性
    RIFT = {
        id       = "RIFT",
        name     = "时空裂隙",
        icon     = "💠",
        desc     = "时空裂隙释放不稳定能量,随机强化一项属性×2.0",
        color    = {255, 80, 120},     -- 粉红
        effects  = {
            -- 运行时随机选择: damageMult / shieldMult / speedMult 其一 ×2.0
            randomBoost = 2.0,
        },
        visual   = "rift",
        duration = {2, 3},
    },
}

-- 异象ID列表(方便随机选取)
local ANOMALY_IDS = {}
for id, _ in pairs(ANOMALY_TYPES) do
    ANOMALY_IDS[#ANOMALY_IDS + 1] = id
end

-- ============================================================================
-- 配置常量
-- ============================================================================
local ANOMALY_START_WAVE   = 3     -- 第几波开始可能出现异象
local ANOMALY_CHANCE       = 0.45  -- 每波结束时出现新异象的概率
local ANOMALY_COOLDOWN     = 2     -- 异象结束后至少间隔几波才出新的
local ANOMALY_MAX_ACTIVE   = 1     -- 同时最多活跃异象数

-- ============================================================================
-- 运行时状态
-- ============================================================================
local state_ = {
    active       = nil,    -- 当前活跃异象 {type, remainWaves, resolvedEffects}
    history      = {},     -- 本局出现过的异象记录 [{id, startWave, endWave}]
    cooldown     = 0,      -- 冷却剩余波次
    totalWaves   = 0,      -- 累计波次
    riftBoostKey = nil,    -- 时空裂隙随机选中的属性键
}

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化/重置(新游戏或新战斗)
function AnomalySystem.Init()
    state_ = {
        active     = nil,
        history    = {},
        cooldown   = 0,
        totalWaves = 0,
        riftBoostKey = nil,
    }
end

--- 每波结束时调用,判定是否触发新异象或推进当前异象
---@param waveNum number 当前结束的波次号
---@return table|nil newAnomaly 如果本波触发了新异象则返回异象信息
function AnomalySystem.OnWaveEnd(waveNum)
    state_.totalWaves = waveNum

    -- 推进当前活跃异象
    if state_.active then
        state_.active.remainWaves = state_.active.remainWaves - 1
        if state_.active.remainWaves <= 0 then
            -- 异象结束
            local h = state_.history[#state_.history]
            if h then h.endWave = waveNum end
            state_.active = nil
            state_.cooldown = ANOMALY_COOLDOWN
            return nil
        end
        return nil  -- 异象仍在持续
    end

    -- 冷却中
    if state_.cooldown > 0 then
        state_.cooldown = state_.cooldown - 1
        return nil
    end

    -- 波次不够
    if waveNum < ANOMALY_START_WAVE then return nil end

    -- 概率判定
    if math.random() > ANOMALY_CHANCE then return nil end

    -- 生成新异象(避免连续重复)
    local lastId = #state_.history > 0 and state_.history[#state_.history].id or nil
    local candidates = {}
    for _, id in ipairs(ANOMALY_IDS) do
        if id ~= lastId then candidates[#candidates + 1] = id end
    end
    if #candidates == 0 then candidates = ANOMALY_IDS end

    local chosenId = candidates[math.random(#candidates)]
    local anomalyDef = ANOMALY_TYPES[chosenId]

    -- 确定持续波次
    local dur = math.random(anomalyDef.duration[1], anomalyDef.duration[2])

    -- 处理时空裂隙的随机属性
    local riftKey = nil
    if chosenId == "RIFT" then
        local keys = {"damageMult", "shieldMult", "speedMult"}
        riftKey = keys[math.random(#keys)]
    end

    state_.active = {
        type        = anomalyDef,
        remainWaves = dur,
        startWave   = waveNum + 1,
        riftBoostKey = riftKey,
    }
    state_.riftBoostKey = riftKey

    state_.history[#state_.history + 1] = {
        id        = chosenId,
        startWave = waveNum + 1,
        endWave   = nil,  -- 尚未结束
    }

    return {
        id        = chosenId,
        name      = anomalyDef.name,
        icon      = anomalyDef.icon,
        desc      = anomalyDef.desc,
        color     = anomalyDef.color,
        duration  = dur,
        riftBoostKey = riftKey,
    }
end

--- 获取当前活跃异象信息(用于UI显示)
---@return table|nil {id, name, icon, desc, color, remainWaves, effects, visual, riftBoostKey}
function AnomalySystem.GetActive()
    if not state_.active then return nil end
    local a = state_.active
    return {
        id          = a.type.id,
        name        = a.type.name,
        icon        = a.type.icon,
        desc        = a.type.desc,
        color       = a.type.color,
        visual      = a.type.visual,
        remainWaves = a.remainWaves,
        effects     = a.type.effects,
        riftBoostKey = a.riftBoostKey,
    }
end

--- 获取当前战斗修正值(供 BattleScene 使用)
---@return table modifiers {damageMult, shieldMult, speedMult, hpMult, enemySpeedMult, enemyDamageMult, firstStrikeMult}
function AnomalySystem.GetBattleModifiers()
    local mods = {
        damageMult      = 1.0,
        shieldMult      = 1.0,
        speedMult       = 1.0,
        hpMult          = 1.0,
        enemySpeedMult  = 1.0,
        enemyDamageMult = 1.0,
        firstStrikeMult = 1.0,
    }

    if not state_.active then return mods end

    local fx = state_.active.type.effects
    if not fx then return mods end

    -- 直接属性覆盖
    if fx.damageMult      then mods.damageMult      = fx.damageMult end
    if fx.shieldMult      then mods.shieldMult      = fx.shieldMult end
    if fx.speedMult       then mods.speedMult       = fx.speedMult end
    if fx.hpMult          then mods.hpMult          = fx.hpMult end
    if fx.enemySpeedMult  then mods.enemySpeedMult  = fx.enemySpeedMult end
    if fx.enemyDamageMult then mods.enemyDamageMult = fx.enemyDamageMult end
    if fx.firstStrikeMult then mods.firstStrikeMult = fx.firstStrikeMult end

    -- 时空裂隙: 随机属性×2
    if fx.randomBoost and state_.active.riftBoostKey then
        local key = state_.active.riftBoostKey
        if mods[key] then
            mods[key] = mods[key] * fx.randomBoost
        end
    end

    return mods
end

--- 获取所有异象类型定义(用于UI图鉴)
---@return table[] list of anomaly definitions
function AnomalySystem.GetAllTypes()
    local list = {}
    for _, id in ipairs(ANOMALY_IDS) do
        list[#list + 1] = ANOMALY_TYPES[id]
    end
    return list
end

--- 获取本局历史记录
---@return table[] history
function AnomalySystem.GetHistory()
    return state_.history
end

-- ============================================================================
-- 存档接口
-- ============================================================================

function AnomalySystem.Serialize()
    return {
        active     = state_.active and {
            typeId       = state_.active.type.id,
            remainWaves  = state_.active.remainWaves,
            startWave    = state_.active.startWave,
            riftBoostKey = state_.active.riftBoostKey,
        } or nil,
        history    = state_.history,
        cooldown   = state_.cooldown,
        totalWaves = state_.totalWaves,
    }
end

function AnomalySystem.Deserialize(data)
    if not data then
        AnomalySystem.Init()
        return
    end
    state_.history    = data.history or {}
    state_.cooldown   = data.cooldown or 0
    state_.totalWaves = data.totalWaves or 0
    state_.active     = nil

    if data.active then
        local def = ANOMALY_TYPES[data.active.typeId]
        if def then
            state_.active = {
                type         = def,
                remainWaves  = data.active.remainWaves or 1,
                startWave    = data.active.startWave or 0,
                riftBoostKey = data.active.riftBoostKey,
            }
            state_.riftBoostKey = data.active.riftBoostKey
        end
    end
end

return AnomalySystem
