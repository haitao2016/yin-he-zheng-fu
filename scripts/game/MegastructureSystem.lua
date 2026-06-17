-- ============================================================================
-- game/MegastructureSystem.lua  -- P2-2: 巨构工程系统
-- 三种银河级巨型建筑：戴森球 / 星门 / 量子堡垒
-- 分阶段建造，每阶段消耗资源+时间，完成后提供强力全局加成
-- ============================================================================

local MegastructureSystem = {}

-- ============================================================================
-- 巨构定义
-- ============================================================================

---@class MegaPhase
---@field name string
---@field desc string
---@field cost table<string,number>
---@field buildTime number  -- 秒

---@class MegaDef
---@field name string
---@field icon string
---@field desc string
---@field unlockCoreLevel number
---@field phases MegaPhase[]
---@field bonusPerPhase table  -- 每阶段完成时叠加的加成
---@field finalBonus table     -- 全部阶段完成时的额外加成

MEGASTRUCTURES = {
    DYSON_SPHERE = {
        name = "戴森球",
        icon = "☀",
        desc = "包裹恒星的能量收集阵列，持续产出海量能源",
        unlockCoreLevel = 7,
        phases = {
            { name="轨道框架",   desc="部署环绕恒星的基础骨架",     cost={metal=3000, esource=1500, nuclear=800},   buildTime=60 },
            { name="能量采集板", desc="安装光伏转化阵列",           cost={metal=5000, esource=3000, nuclear=1500},  buildTime=90 },
            { name="传输网络",   desc="建设能量传输通道",           cost={metal=6000, esource=4000, nuclear=2000},  buildTime=120 },
            { name="恒星封装",   desc="完成恒星全覆盖，产能最大化", cost={metal=10000, esource=8000, nuclear=5000}, buildTime=180 },
        },
        bonusPerPhase = { esourceRate = 15 },   -- 每阶段 +15 能源/s
        finalBonus    = { esourceRate = 30, researchMult = 1.5 },  -- 完工额外+30能源/s 且科研×1.5
    },
    STARGATE = {
        name = "星门",
        icon = "🌀",
        desc = "连接星系的空间折叠门径，舰队可瞬间跨越星域",
        unlockCoreLevel = 8,
        phases = {
            { name="量子锚点",   desc="在目标星域固定空间坐标",      cost={metal=4000, esource=2000, nuclear=1500},  buildTime=75 },
            { name="空间稳定器", desc="维持虫洞结构不坍缩",          cost={metal=6000, esource=4000, nuclear=2500},  buildTime=100 },
            { name="传送阵列",   desc="安装质能转换与重组设备",      cost={metal=8000, esource=6000, nuclear=4000},  buildTime=140 },
            { name="门径激活",   desc="打开稳定的双向空间通道",      cost={metal=12000, esource=10000, nuclear=6000}, buildTime=200 },
        },
        bonusPerPhase = { fleetSpeedMult = 1.25 },  -- 每阶段舰队速度×1.25
        finalBonus    = { instantWarp = true, fleetSpeedMult = 1.5 },  -- 完工：瞬移+额外速度
    },
    QUANTUM_FORTRESS = {
        name = "量子堡垒",
        icon = "🛡",
        desc = "利用量子纠缠的绝对防御要塞，敌方舰队近乎无法攻破",
        unlockCoreLevel = 9,
        phases = {
            { name="量子核心",   desc="建造纠缠态防御核心",          cost={metal=5000, esource=3000, nuclear=2000},  buildTime=80 },
            { name="相位护盾",   desc="部署多层相位偏转屏障",        cost={metal=7000, esource=5000, nuclear=3000},  buildTime=110 },
            { name="时空壁垒",   desc="扭曲局部时空减缓来袭",        cost={metal=10000, esource=7000, nuclear=5000}, buildTime=150 },
            { name="量子锁定",   desc="激活绝对防御态",              cost={metal=15000, esource=12000, nuclear=8000}, buildTime=240 },
        },
        bonusPerPhase = { defense = 200, shield = 500 },   -- 每阶段 +200防御 +500护盾
        finalBonus    = { defenseMult = 2.0, shield = 2000, enemyLossMult = 1.3 },  -- 完工：防御翻倍+敌方额外损失30%
    },
}

MEGA_ORDER = { "DYSON_SPHERE", "STARGATE", "QUANTUM_FORTRESS" }

-- ============================================================================
-- 运行时状态
-- ============================================================================

-- 每个巨构的建造状态
-- megaStates_[key] = { currentPhase=1, building=false, timer=0, completed=false }
local megaStates_ = {}

-- 初始化
local function initStates()
    for _, key in ipairs(MEGA_ORDER) do
        if not megaStates_[key] then
            megaStates_[key] = {
                currentPhase = 0,  -- 0=未开始, 1~N=正在/已完成该阶段
                building = false,  -- 是否正在建造中
                timer = 0,         -- 当前阶段已建造时间
                completed = false, -- 全阶段完成
            }
        end
    end
end
initStates()

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 获取巨构状态（只读副本概要）
---@param key string
---@return table|nil
function MegastructureSystem.GetState(key)
    return megaStates_[key]
end

--- 获取所有巨构状态
function MegastructureSystem.GetAllStates()
    return megaStates_
end

--- 判断巨构是否已解锁（基地核心等级足够）
---@param key string
---@param coreLevel number
function MegastructureSystem.IsUnlocked(key, coreLevel)
    local def = MEGASTRUCTURES[key]
    if not def then return false end
    return (coreLevel or 0) >= def.unlockCoreLevel
end

--- 获取当前阶段的花费信息（nil=已全部完成或未解锁）
function MegastructureSystem.GetCurrentPhaseCost(key)
    local state = megaStates_[key]
    local def = MEGASTRUCTURES[key]
    if not state or not def or state.completed then return nil end
    local phaseIdx = state.currentPhase + 1  -- 下一个要建的阶段
    if phaseIdx > #def.phases then return nil end
    return def.phases[phaseIdx]
end

--- 检查是否可以开始建造下一阶段
---@param key string
---@param resources table  当前资源
---@param coreLevel number
---@return boolean, string|nil  -- canBuild, reason
function MegastructureSystem.CanStartPhase(key, resources, coreLevel)
    local def = MEGASTRUCTURES[key]
    local state = megaStates_[key]
    if not def or not state then return false, "无效巨构" end
    if state.completed then return false, "已完工" end
    if state.building then return false, "正在建造中" end
    if (coreLevel or 0) < def.unlockCoreLevel then
        return false, "需要基地核心 Lv." .. def.unlockCoreLevel
    end
    -- 检查是否有其他巨构正在建造（同一时间只能建一个）
    for _, k in ipairs(MEGA_ORDER) do
        if k ~= key and megaStates_[k] and megaStates_[k].building then
            return false, MEGASTRUCTURES[k].name .. " 正在建造中"
        end
    end
    -- 检查资源
    local phaseIdx = state.currentPhase + 1
    if phaseIdx > #def.phases then return false, "已完工" end
    local phase = def.phases[phaseIdx]
    for res, need in pairs(phase.cost) do
        if (resources[res] or 0) < need then
            return false, res .. " 不足"
        end
    end
    return true, nil
end

--- 开始建造下一阶段（调用前需确认 CanStartPhase=true 并扣除资源）
---@param key string
---@return boolean
function MegastructureSystem.StartPhase(key)
    local state = megaStates_[key]
    if not state then return false end
    state.currentPhase = state.currentPhase + 1
    state.building = true
    state.timer = 0
    return true
end

--- 每帧更新（dt 秒）—— 推进建造进度
---@param dt number
---@param buildMult number  建造速度倍率（来自 baseBonus.buildMult 的倒数）
---@return table|nil  -- 完成事件 {key, phaseIdx, isComplete}
function MegastructureSystem.Update(dt, buildMult)
    buildMult = buildMult or 1.0
    for _, key in ipairs(MEGA_ORDER) do
        local state = megaStates_[key]
        if state and state.building then
            local def = MEGASTRUCTURES[key]
            local phase = def.phases[state.currentPhase]
            if phase then
                state.timer = state.timer + dt * buildMult
                if state.timer >= phase.buildTime then
                    -- 阶段完成
                    state.building = false
                    state.timer = phase.buildTime
                    local isComplete = (state.currentPhase >= #def.phases)
                    if isComplete then
                        state.completed = true
                    end
                    return { key = key, phaseIdx = state.currentPhase, isComplete = isComplete }
                end
            end
            break  -- 同时只有一个在建造
        end
    end
    return nil
end

--- 获取建造进度百分比 0~1（当前阶段）
function MegastructureSystem.GetProgress(key)
    local state = megaStates_[key]
    local def = MEGASTRUCTURES[key]
    if not state or not def or not state.building then return 0 end
    local phase = def.phases[state.currentPhase]
    if not phase then return 1 end
    return math.min(1.0, state.timer / phase.buildTime)
end

--- 计算巨构提供的全局加成（累加所有已完成阶段 + 最终加成）
---@return table  bonuses
function MegastructureSystem.CalcBonuses()
    local bonuses = {
        esourceRate = 0,
        researchMult = 1.0,
        fleetSpeedMult = 1.0,
        instantWarp = false,
        defense = 0,
        shield = 0,
        defenseMult = 1.0,
        enemyLossMult = 1.0,
    }
    for _, key in ipairs(MEGA_ORDER) do
        local state = megaStates_[key]
        local def = MEGASTRUCTURES[key]
        if state and def then
            -- 每个已完成阶段的 bonusPerPhase
            local completedPhases = state.building and (state.currentPhase - 1) or state.currentPhase
            if completedPhases > 0 then
                local bp = def.bonusPerPhase
                if bp.esourceRate then
                    bonuses.esourceRate = bonuses.esourceRate + bp.esourceRate * completedPhases
                end
                if bp.fleetSpeedMult then
                    for _ = 1, completedPhases do
                        bonuses.fleetSpeedMult = bonuses.fleetSpeedMult * bp.fleetSpeedMult
                    end
                end
                if bp.defense then
                    bonuses.defense = bonuses.defense + bp.defense * completedPhases
                end
                if bp.shield then
                    bonuses.shield = bonuses.shield + bp.shield * completedPhases
                end
            end
            -- 最终加成（全阶段完成时）
            if state.completed then
                local fb = def.finalBonus
                if fb.esourceRate then
                    bonuses.esourceRate = bonuses.esourceRate + fb.esourceRate
                end
                if fb.researchMult then
                    bonuses.researchMult = bonuses.researchMult * fb.researchMult
                end
                if fb.fleetSpeedMult then
                    bonuses.fleetSpeedMult = bonuses.fleetSpeedMult * fb.fleetSpeedMult
                end
                if fb.instantWarp then
                    bonuses.instantWarp = true
                end
                if fb.defense then
                    bonuses.defense = bonuses.defense + fb.defense
                end
                if fb.shield then
                    bonuses.shield = bonuses.shield + fb.shield
                end
                if fb.defenseMult then
                    bonuses.defenseMult = bonuses.defenseMult * fb.defenseMult
                end
                if fb.enemyLossMult then
                    bonuses.enemyLossMult = bonuses.enemyLossMult * fb.enemyLossMult
                end
            end
        end
    end
    return bonuses
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function MegastructureSystem.Serialize()
    local data = {}
    for _, key in ipairs(MEGA_ORDER) do
        local s = megaStates_[key]
        if s then
            data[key] = {
                currentPhase = s.currentPhase,
                building = s.building,
                timer = s.timer,
                completed = s.completed,
            }
        end
    end
    return data
end

function MegastructureSystem.Deserialize(data)
    if not data then return end
    initStates()
    for _, key in ipairs(MEGA_ORDER) do
        if data[key] then
            local d = data[key]
            megaStates_[key] = {
                currentPhase = d.currentPhase or 0,
                building = d.building or false,
                timer = d.timer or 0,
                completed = d.completed or false,
            }
        end
    end
end

--- 重置所有巨构状态（新游戏时调用）
function MegastructureSystem.Reset()
    megaStates_ = {}
    initStates()
end

return MegastructureSystem
