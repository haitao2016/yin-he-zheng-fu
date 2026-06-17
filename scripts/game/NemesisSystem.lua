---@diagnostic disable: return-type-mismatch
-- ============================================================================
-- game/NemesisSystem.lua  -- P1-2: 宿敌系统（3位船长+进化+策略记忆+最终决战）
-- ============================================================================

local NemesisSystem = {}

-- ============================================================================
-- 宿敌船长定义
-- ============================================================================
-- 3 位宿敌船长：各有独特战术风格和进化路线
local CAPTAINS = {
    {
        id       = "VIKTOR",
        name     = "「铁爪」维克托",
        title    = "暴力征服者",
        desc     = "崇尚火力压制，偏好重型舰船正面碾压。",
        color    = {255, 80, 40},      -- 暗红
        shipPref = "BATTLECRUISER",    -- 偏好旗舰舰型
        fleetStyle = "heavy",          -- heavy = 重火力流
        taunt    = {
            encounter = "你的小舰队不堪一击！",
            flee      = "哼...下次我会碾碎你！",
            final     = "这是最后的决战，维克托不会再逃！",
            defeated  = "不...不可能...铁爪怎会败！",
        },
    },
    {
        id       = "SELINA",
        name     = "「幽影」塞琳娜",
        title    = "幽灵掠夺者",
        desc     = "擅长高速突击和侧翼迂回，让目标防不胜防。",
        color    = {100, 200, 255},    -- 冰蓝
        shipPref = "INTERCEPTOR",      -- 偏好拦截舰
        fleetStyle = "swarm",          -- swarm = 蜂群快攻
        taunt    = {
            encounter = "你看得见我的影子吗？",
            flee      = "追不上我的...我们还会再见。",
            final     = "幽影之名不容亵渎，来吧！",
            defeated  = "这速度...居然能追上我...",
        },
    },
    {
        id       = "AXOS",
        name     = "「核焰」阿克索斯",
        title    = "毁灭统帅",
        desc     = "老练的战术家，依靠母舰编队和远程火力支配战场。",
        color    = {200, 50, 255},     -- 紫焰
        shipPref = "CARRIER",          -- 偏好母舰
        fleetStyle = "carrier",        -- carrier = 母舰流
        taunt    = {
            encounter = "星海将在核焰中净化。",
            flee      = "且让你多活几日...下次不会这么简单。",
            final     = "核焰的终焉之战...来吧，毁灭者。",
            defeated  = "不...我的舰队...我的信念...",
        },
    },
}

-- ============================================================================
-- 进化等级配置
-- ============================================================================
-- 每次遭遇后进化，等级 1-5；等级 5 触发最终决战
local EVOLUTION_CONFIG = {
    -- 每级加成：HP倍率、攻击力倍率、舰队规模加成、额外能力
    [1] = { hpMult=1.0,  dmgMult=1.0,  fleetBonus=0,  desc="初次遭遇" },
    [2] = { hpMult=1.3,  dmgMult=1.2,  fleetBonus=2,  desc="记仇归来" },
    [3] = { hpMult=1.6,  dmgMult=1.4,  fleetBonus=4,  desc="强化改造" },
    [4] = { hpMult=2.0,  dmgMult=1.7,  fleetBonus=6,  desc="复仇执念" },
    [5] = { hpMult=2.5,  dmgMult=2.0,  fleetBonus=8,  desc="最终决战" },
}

-- 遭遇触发条件：波次间隔 & 最低波次
local ENCOUNTER_MIN_WAVE    = 4    -- 至少第 4 波后才可能遇到宿敌
local ENCOUNTER_INTERVAL    = 7    -- 每隔至少 7 波才会遇到下一次宿敌
local ENCOUNTER_CHANCE      = 0.6  -- 满足间隔条件后的触发概率

-- ============================================================================
-- 系统状态（运行时）
-- ============================================================================
local state_ = {
    captains = {},   -- { [captainId] = { level, encounters, lastWave, defeated, strategyMemory } }
    activeCaptain   = nil,   -- 当前战斗中的宿敌 captainId（nil=非宿敌波）
    lastEncounterWave = 0,   -- 上次遭遇的波次
    totalEncounters   = 0,   -- 总遭遇次数
    defeatedCaptains  = {},  -- 已被最终击败的船长 id 集合
}

-- ============================================================================
-- 初始化
-- ============================================================================
function NemesisSystem.Init()
    state_.captains = {}
    for _, cap in ipairs(CAPTAINS) do
        state_.captains[cap.id] = {
            level           = 1,
            encounters      = 0,
            lastWave        = 0,
            defeated        = false,   -- 最终决战已击败
            strategyMemory  = {},      -- { [shipType] = count } 记录玩家使用的舰型
            lastPlayerTactic = nil,    -- 上次玩家的主力舰型
            escapedTimes    = 0,       -- 逃跑次数（决战前）
        }
    end
    state_.activeCaptain     = nil
    state_.lastEncounterWave = 0
    state_.totalEncounters   = 0
    state_.defeatedCaptains  = {}
end

-- ============================================================================
-- 策略记忆：记录玩家战术偏好
-- ============================================================================
--- 战斗结束后记录玩家使用的舰型分布
---@param playerFleet table[] 玩家舰船列表 { stype=... }
function NemesisSystem.RecordPlayerTactics(playerFleet)
    if not state_.activeCaptain then return end
    local capState = state_.captains[state_.activeCaptain]
    if not capState then return end

    -- 统计本次玩家舰型
    local counts = {}
    for _, ship in ipairs(playerFleet) do
        local t = ship.stype or "UNKNOWN"
        counts[t] = (counts[t] or 0) + 1
    end

    -- 累加到策略记忆
    for stype, cnt in pairs(counts) do
        capState.strategyMemory[stype] = (capState.strategyMemory[stype] or 0) + cnt
    end

    -- 找出玩家主力舰型
    local maxType, maxCount = nil, 0
    for stype, cnt in pairs(capState.strategyMemory) do
        if cnt > maxCount then maxType = stype; maxCount = cnt end
    end
    capState.lastPlayerTactic = maxType
end

-- ============================================================================
-- 宿敌舰队生成（根据船长风格+进化等级+策略反制）
-- ============================================================================
--- 生成宿敌舰队组成（返回 shipType 列表）
---@param captainId string
---@return table[] fleet { {stype=..., isBoss=bool, isNemesis=bool} ... }
function NemesisSystem.BuildNemesisFleet(captainId, screenW, screenH)
    local capDef = nil
    for _, c in ipairs(CAPTAINS) do
        if c.id == captainId then capDef = c; break end
    end
    if not capDef then return {} end

    local capState = state_.captains[captainId]
    local level    = capState.level
    local evo      = EVOLUTION_CONFIG[level]

    -- 基础舰队规模
    local baseCount = 5 + evo.fleetBonus
    local fleet = {}

    -- 根据风格生成舰队
    if capDef.fleetStyle == "heavy" then
        -- 重火力流：大量驱逐+战列
        for i = 1, baseCount do
            local roll = math.random()
            if roll < 0.35 then
                fleet[#fleet+1] = "BATTLECRUISER"
            elseif roll < 0.65 then
                fleet[#fleet+1] = "DESTROYER"
            else
                fleet[#fleet+1] = "FRIGATE"
            end
        end
    elseif capDef.fleetStyle == "swarm" then
        -- 蜂群流：大量拦截舰+侦察
        for i = 1, baseCount + 3 do  -- 蜂群多 3 艘
            local roll = math.random()
            if roll < 0.45 then
                fleet[#fleet+1] = "INTERCEPTOR"
            elseif roll < 0.75 then
                fleet[#fleet+1] = "SCOUT"
            else
                fleet[#fleet+1] = "FRIGATE"
            end
        end
    elseif capDef.fleetStyle == "carrier" then
        -- 母舰流：2 母舰 + 护卫
        fleet[#fleet+1] = "CARRIER"
        if level >= 3 then fleet[#fleet+1] = "CARRIER" end
        for i = 1, baseCount - 1 do
            local roll = math.random()
            if roll < 0.4 then
                fleet[#fleet+1] = "DESTROYER"
            elseif roll < 0.7 then
                fleet[#fleet+1] = "FRIGATE"
            else
                fleet[#fleet+1] = "INTERCEPTOR"
            end
        end
    end

    -- 策略反制：根据玩家主力舰型添加克制单位
    local playerMain = capState.lastPlayerTactic
    if playerMain and level >= 2 then
        local counterMap = {
            SCOUT        = "INTERCEPTOR",    -- 拦截舰克侦察
            FRIGATE      = "DESTROYER",      -- 驱逐舰克护卫
            DESTROYER    = "BATTLECRUISER",  -- 战列克驱逐
            BATTLECRUISER= "INTERCEPTOR",    -- 蜂群克战列（数量优势）
            INTERCEPTOR  = "FRIGATE",        -- 护卫对空克拦截
            CARRIER      = "DESTROYER",      -- 驱逐突进克母舰
        }
        local counterType = counterMap[playerMain]
        if counterType then
            -- 添加 1-3 艘反制单位（等级越高越多）
            local counterCount = math.min(3, math.floor(level / 2) + 1)
            for i = 1, counterCount do
                fleet[#fleet+1] = counterType
            end
        end
    end

    return fleet
end

-- ============================================================================
-- 遭遇判定：当前波次是否触发宿敌
-- ============================================================================
--- 检查是否应该触发宿敌遭遇
---@param currentWave number 当前战斗波次
---@return string|nil captainId 触发的宿敌船长ID，nil=不触发
function NemesisSystem.CheckEncounter(currentWave)
    -- 最低波次限制
    if currentWave < ENCOUNTER_MIN_WAVE then return nil end
    -- 间隔限制
    if currentWave - state_.lastEncounterWave < ENCOUNTER_INTERVAL then return nil end
    -- Boss 波不触发宿敌（让位给常规Boss）
    if currentWave % 5 == 0 then return nil end
    -- 概率判定
    if math.random() > ENCOUNTER_CHANCE then return nil end

    -- 选择宿敌：优先选进化等级最高且未被最终击败的
    local candidates = {}
    for _, cap in ipairs(CAPTAINS) do
        local cs = state_.captains[cap.id]
        if cs and not cs.defeated then
            candidates[#candidates+1] = { id = cap.id, level = cs.level, encounters = cs.encounters }
        end
    end
    if #candidates == 0 then return nil end

    -- 排序：等级高优先，相同等级则遭遇次数少的优先（让所有船长均匀出现）
    table.sort(candidates, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.encounters < b.encounters
    end)

    -- 等级 5 的船长优先触发最终决战
    for _, c in ipairs(candidates) do
        if c.level >= 5 then return c.id end
    end

    return candidates[1].id
end

-- ============================================================================
-- 遭遇开始/结束
-- ============================================================================
--- 标记宿敌遭遇开始
function NemesisSystem.StartEncounter(captainId, currentWave)
    state_.activeCaptain     = captainId
    state_.lastEncounterWave = currentWave
    state_.totalEncounters   = state_.totalEncounters + 1

    local cs = state_.captains[captainId]
    if cs then
        cs.encounters = cs.encounters + 1
        cs.lastWave   = currentWave
    end
    print(string.format("[Nemesis] 宿敌遭遇！船长=%s 等级=%d 波次=%d",
        captainId, cs and cs.level or 0, currentWave))
end

--- 宿敌战斗结束：玩家获胜
---@return table result { captainId, level, isFinale, taunt }
function NemesisSystem.OnPlayerWin()
    local captainId = state_.activeCaptain
    if not captainId then return nil end

    local capDef = nil
    for _, c in ipairs(CAPTAINS) do
        if c.id == captainId then capDef = c; break end
    end
    local cs = state_.captains[captainId]
    if not cs or not capDef then
        state_.activeCaptain = nil
        return nil
    end

    local isFinale = cs.level >= 5
    local result = {
        captainId = captainId,
        name      = capDef.name,
        level     = cs.level,
        isFinale  = isFinale,
        color     = capDef.color,
    }

    if isFinale then
        -- 最终决战：宿敌被击败
        cs.defeated = true
        state_.defeatedCaptains[captainId] = true
        result.taunt = capDef.taunt.defeated
        print(string.format("[Nemesis] 最终决战胜利！%s 已被击败！", capDef.name))
    else
        -- 普通遭遇：宿敌逃跑并进化
        cs.level = math.min(5, cs.level + 1)
        cs.escapedTimes = cs.escapedTimes + 1
        result.taunt = capDef.taunt.flee
        print(string.format("[Nemesis] %s 逃走！进化至 Lv.%d", capDef.name, cs.level))
    end

    state_.activeCaptain = nil
    return result
end

--- 宿敌战斗结束：玩家失败
---@return table result { captainId, level, taunt }
function NemesisSystem.OnPlayerLose()
    local captainId = state_.activeCaptain
    if not captainId then return nil end

    local capDef = nil
    for _, c in ipairs(CAPTAINS) do
        if c.id == captainId then capDef = c; break end
    end
    local cs = state_.captains[captainId]
    if not cs or not capDef then
        state_.activeCaptain = nil
        return nil
    end

    -- 玩家输了，宿敌也会进化（更嚣张）
    cs.level = math.min(5, cs.level + 1)
    local result = {
        captainId = captainId,
        name      = capDef.name,
        level     = cs.level,
        isFinale  = false,
        taunt     = "哈哈！就这？",
        color     = capDef.color,
    }
    state_.activeCaptain = nil
    print(string.format("[Nemesis] 玩家战败！%s 进化至 Lv.%d", capDef.name, cs.level))
    return result
end

-- ============================================================================
-- 查询接口
-- ============================================================================
--- 获取当前活跃宿敌信息（用于 UI 展示）
function NemesisSystem.GetActiveCaptain()
    if not state_.activeCaptain then return nil end
    local capDef = nil
    for _, c in ipairs(CAPTAINS) do
        if c.id == state_.activeCaptain then capDef = c; break end
    end
    if not capDef then return nil end
    local cs = state_.captains[state_.activeCaptain]
    return {
        id    = capDef.id,
        name  = capDef.name,
        title = capDef.title,
        color = capDef.color,
        level = cs.level,
        isFinale = cs.level >= 5,
        taunt = cs.level >= 5 and capDef.taunt.final or capDef.taunt.encounter,
    }
end

--- 获取所有船长状态概览（用于 UI 档案展示）
function NemesisSystem.GetAllCaptains()
    local result = {}
    for _, capDef in ipairs(CAPTAINS) do
        local cs = state_.captains[capDef.id]
        result[#result+1] = {
            id         = capDef.id,
            name       = capDef.name,
            title      = capDef.title,
            desc       = capDef.desc,
            color      = capDef.color,
            level      = cs and cs.level or 1,
            encounters = cs and cs.encounters or 0,
            defeated   = cs and cs.defeated or false,
            fleetStyle = capDef.fleetStyle,
        }
    end
    return result
end

--- 获取进化等级描述
function NemesisSystem.GetEvolutionDesc(level)
    local evo = EVOLUTION_CONFIG[level]
    return evo and evo.desc or ""
end

--- 获取进化配置（用于战斗中应用加成）
function NemesisSystem.GetEvolutionConfig(level)
    return EVOLUTION_CONFIG[level or 1]
end

--- 是否为最终决战波
function NemesisSystem.IsFinaleWave()
    if not state_.activeCaptain then return false end
    local cs = state_.captains[state_.activeCaptain]
    return cs and cs.level >= 5
end

--- 所有宿敌是否都已被最终击败
--- 返回已击败的宿敌船长数量
function NemesisSystem.GetDefeatedCount()
    local n = 0
    for _ in pairs(state_.defeatedCaptains) do n = n + 1 end
    return n
end

function NemesisSystem.AllDefeated()
    for _, capDef in ipairs(CAPTAINS) do
        local cs = state_.captains[capDef.id]
        if not cs or not cs.defeated then return false end
    end
    return true
end

-- ============================================================================
-- 序列化/反序列化（存档）
-- ============================================================================
function NemesisSystem.Serialize()
    local data = {
        captains          = {},
        lastEncounterWave = state_.lastEncounterWave,
        totalEncounters   = state_.totalEncounters,
        defeatedCaptains  = {},
    }
    for id, cs in pairs(state_.captains) do
        data.captains[id] = {
            level           = cs.level,
            encounters      = cs.encounters,
            lastWave        = cs.lastWave,
            defeated        = cs.defeated,
            strategyMemory  = cs.strategyMemory,
            lastPlayerTactic= cs.lastPlayerTactic,
            escapedTimes    = cs.escapedTimes,
        }
    end
    for id in pairs(state_.defeatedCaptains) do
        data.defeatedCaptains[#data.defeatedCaptains+1] = id
    end
    return data
end

function NemesisSystem.Deserialize(data)
    if not data then
        NemesisSystem.Init()
        return
    end
    state_.lastEncounterWave = data.lastEncounterWave or 0
    state_.totalEncounters   = data.totalEncounters or 0
    state_.defeatedCaptains  = {}
    if data.defeatedCaptains then
        for _, id in ipairs(data.defeatedCaptains) do
            state_.defeatedCaptains[id] = true
        end
    end
    -- 恢复各船长状态
    if data.captains then
        for id, cs in pairs(data.captains) do
            if state_.captains[id] then
                state_.captains[id].level           = cs.level or 1
                state_.captains[id].encounters      = cs.encounters or 0
                state_.captains[id].lastWave        = cs.lastWave or 0
                state_.captains[id].defeated        = cs.defeated or false
                state_.captains[id].strategyMemory  = cs.strategyMemory or {}
                state_.captains[id].lastPlayerTactic= cs.lastPlayerTactic
                state_.captains[id].escapedTimes    = cs.escapedTimes or 0
            end
        end
    end
    -- 同步 defeated 状态
    for id in pairs(state_.defeatedCaptains) do
        if state_.captains[id] then
            state_.captains[id].defeated = true
        end
    end
end

-- 初始化默认状态
NemesisSystem.Init()

return NemesisSystem
