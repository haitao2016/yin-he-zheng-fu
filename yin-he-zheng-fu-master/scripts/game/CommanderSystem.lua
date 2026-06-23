---@diagnostic disable: return-type-mismatch
--- ============================================================================
--- game/CommanderSystem.lua  -- P1-3 V2.4: 指挥官系统
--- 管理指挥官的招募/升级/专精/退役/技能/战斗加成
--- ============================================================================

local Systems = require("game.Systems")
local COMMANDER_MAX_LEVEL     = Systems.COMMANDER_MAX_LEVEL
local COMMANDER_MAX_SLOTS     = Systems.COMMANDER_MAX_SLOTS
local COMMANDER_RETIRE_REWARD = Systems.COMMANDER_RETIRE_REWARD
local COMMANDER_EXP_TABLE     = Systems.COMMANDER_EXP_TABLE
local COMMANDER_SPECS         = Systems.COMMANDER_SPECS
local COMMANDER_NAMES         = Systems.COMMANDER_NAMES
local COMMANDER_SOURCE        = Systems.COMMANDER_SOURCE
local COMMANDER_MARKET_COST   = Systems.COMMANDER_MARKET_COST

local CommanderSystem = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
---@type table[]  -- { id, name, level, exp, spec, source, fleetId, skillCooldown }
local commanders_ = {}
local nextId_ = 1

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 生成随机指挥官名
---@return string
local function randomName()
    return COMMANDER_NAMES[math.random(1, #COMMANDER_NAMES)]
end

--- 获取升级所需经验
---@param level number
---@return number
local function expToNext(level)
    return COMMANDER_EXP_TABLE[level] or math.huge
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 获取所有指挥官列表
---@return table[]
function CommanderSystem.GetAll()
    return commanders_
end

--- 获取指定编队的指挥官（如有）
---@param fleetId number
---@return table|nil
function CommanderSystem.GetByFleet(fleetId)
    for _, cmd in ipairs(commanders_) do
        if cmd.fleetId == fleetId then return cmd end
    end
    return nil
end

--- 获取指定 id 的指挥官
---@param id number
---@return table|nil
function CommanderSystem.GetById(id)
    for _, cmd in ipairs(commanders_) do
        if cmd.id == id then return cmd end
    end
    return nil
end

--- 获取指定编队指挥官的技能剩余冷却时间
---@param fleetId number
---@return number|nil  冷却秒数，无指挥官返回 nil
function CommanderSystem.GetSkillCooldown(fleetId)
    local cmd = CommanderSystem.GetByFleet(fleetId)
    if not cmd then return nil end
    return cmd.skillCooldown or 0
end

--- 当前拥有指挥官数量
---@return number
function CommanderSystem.Count()
    return #commanders_
end

--- 是否还能招募
---@return boolean
function CommanderSystem.CanRecruit()
    return #commanders_ < COMMANDER_MAX_SLOTS
end

--- 招募新指挥官
---@param source string  COMMANDER_SOURCE 枚举值
---@param customName? string  自定义名称（可选）
---@return table|nil commander, string msg
function CommanderSystem.Recruit(source, customName)
    if #commanders_ >= COMMANDER_MAX_SLOTS then
        return nil, string.format("指挥官已满（上限%d人）", COMMANDER_MAX_SLOTS)
    end
    local cmd = {
        id       = nextId_,
        name     = customName or randomName(),
        level    = 1,
        exp      = 0,
        spec     = nil,       -- Lv3 选择专精后设定
        source   = source,
        fleetId  = nil,       -- 未分配编队
        skillCooldown = 0,    -- 技能冷却剩余时间
    }
    nextId_ = nextId_ + 1
    commanders_[#commanders_ + 1] = cmd
    print(string.format("[Commander] 招募: %s (来源=%s)", cmd.name, source))
    return cmd, string.format("🎖 新指挥官 %s 加入！", cmd.name)
end

--- 给指挥官增加经验
---@param cmdId number
---@param amount number
---@return boolean leveledUp
function CommanderSystem.AddExp(cmdId, amount)
    local cmd = CommanderSystem.GetById(cmdId)
    if not cmd or cmd.level >= COMMANDER_MAX_LEVEL then return false end
    cmd.exp = cmd.exp + amount
    local leveledUp = false
    while cmd.level < COMMANDER_MAX_LEVEL and cmd.exp >= expToNext(cmd.level) do
        cmd.exp = cmd.exp - expToNext(cmd.level)
        cmd.level = cmd.level + 1
        leveledUp = true
        print(string.format("[Commander] %s 升级! Lv%d", cmd.name, cmd.level))
    end
    if cmd.level >= COMMANDER_MAX_LEVEL then
        cmd.exp = 0  -- 满级清零
    end
    return leveledUp
end

--- 选择专精（Lv3+ 时可用，只能选一次）
---@param cmdId number
---@param specKey string  "tactical"|"defense"|"logistics"
---@return boolean success, string msg
function CommanderSystem.ChooseSpec(cmdId, specKey)
    local cmd = CommanderSystem.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    if cmd.level < 3 then return false, "需要达到3级才能选择专精" end
    if cmd.spec then return false, "已选择专精，无法更改" end
    if not COMMANDER_SPECS[specKey] then return false, "无效的专精类型" end
    cmd.spec = specKey
    local specDef = COMMANDER_SPECS[specKey]
    print(string.format("[Commander] %s 选择专精: %s %s", cmd.name, specDef.icon, specDef.name))
    return true, string.format("%s 选择了 %s %s！", cmd.name, specDef.icon, specDef.name)
end

--- 分配指挥官到编队
---@param cmdId number
---@param fleetId number|nil  nil=取消分配
---@return boolean success, string msg
function CommanderSystem.AssignToFleet(cmdId, fleetId)
    local cmd = CommanderSystem.GetById(cmdId)
    if not cmd then return false, "指挥官不存在" end
    -- 如果目标编队已有其他指挥官，先解除
    if fleetId then
        for _, other in ipairs(commanders_) do
            if other.id ~= cmdId and other.fleetId == fleetId then
                other.fleetId = nil
            end
        end
    end
    cmd.fleetId = fleetId
    return true, fleetId and string.format("%s 已分配到编队%d", cmd.name, fleetId) or
                            string.format("%s 已解除编队分配", cmd.name)
end

--- 退役指挥官（返回文明积分）
---@param cmdId number
---@return number points, string msg
function CommanderSystem.Retire(cmdId)
    local cmd = CommanderSystem.GetById(cmdId)
    if not cmd then return 0, "指挥官不存在" end
    local points = COMMANDER_RETIRE_REWARD
    -- 从列表中移除
    for i, c in ipairs(commanders_) do
        if c.id == cmdId then
            table.remove(commanders_, i)
            break
        end
    end
    print(string.format("[Commander] %s 退役，获得%d文明积分", cmd.name, points))
    return points, string.format("🏅 %s 光荣退役！获得 %d 文明积分", cmd.name, points)
end

--- 获取指挥官对编队的被动加成（乘数）
---@param cmdId number
---@return table  { dmgMult=1.x, healthMult=1.x, resourceMult=1.x }
function CommanderSystem.GetPassiveBonus(cmdId)
    local bonus = { dmgMult = 1.0, healthMult = 1.0, resourceMult = 1.0 }
    local cmd = CommanderSystem.GetById(cmdId)
    if not cmd then return bonus end
    if not cmd.spec then return bonus end
    local specDef = COMMANDER_SPECS[cmd.spec]
    if not specDef then return bonus end
    -- 从 Lv3 开始计算专精加成（3级选择后每级都有效，含3级本身）
    local effLevels = cmd.level  -- 全等级都算加成
    for key, perLv in pairs(specDef.perLevel) do
        if key == "dmgMult" then
            bonus.dmgMult = bonus.dmgMult + perLv * effLevels
        elseif key == "healthMult" then
            bonus.healthMult = bonus.healthMult + perLv * effLevels
        elseif key == "resourceMult" then
            bonus.resourceMult = bonus.resourceMult + perLv * effLevels
        end
    end
    return bonus
end

--- 获取指定编队的被动加成
---@param fleetId number
---@return table
function CommanderSystem.GetFleetBonus(fleetId)
    local cmd = CommanderSystem.GetByFleet(fleetId)
    if not cmd then
        return { dmgMult = 1.0, healthMult = 1.0, resourceMult = 1.0 }
    end
    return CommanderSystem.GetPassiveBonus(cmd.id)
end

--- 尝试激活技能（战斗中调用）
---@param fleetId number
---@return boolean activated, table|nil skillDef
function CommanderSystem.ActivateSkill(fleetId)
    local cmd = CommanderSystem.GetByFleet(fleetId)
    if not cmd or not cmd.spec then return false, nil end
    local specDef = COMMANDER_SPECS[cmd.spec]
    if not specDef or not specDef.skill then return false, nil end
    if cmd.level < 5 then return false, nil end  -- Lv5 解锁主动技能
    local skill = specDef.skill
    if skill.cooldown <= 0 then return false, nil end  -- 被动技能不需要激活
    if cmd.skillCooldown > 0 then return false, nil end  -- 冷却中
    cmd.skillCooldown = skill.cooldown
    print(string.format("[Commander] %s 激活技能: %s", cmd.name, skill.name))
    return true, skill
end

--- 更新技能冷却（每帧调用）
---@param dt number
function CommanderSystem.Update(dt)
    for _, cmd in ipairs(commanders_) do
        if cmd.skillCooldown > 0 then
            cmd.skillCooldown = math.max(0, cmd.skillCooldown - dt)
        end
    end
end

--- 战斗结束时给参战编队指挥官加经验
---@param fleetId number
---@param kills number  击杀数
---@param waves number  存活波次
---@return boolean leveledUp
function CommanderSystem.OnBattleEnd(fleetId, kills, waves)
    local cmd = CommanderSystem.GetByFleet(fleetId)
    if not cmd then return false end
    local expGain = kills * 2 + waves * 5
    if expGain < 1 then expGain = 1 end
    print(string.format("[Commander] %s 战斗经验 +%d (击杀%d×2 + 波次%d×5)",
        cmd.name, expGain, kills, waves))
    return CommanderSystem.AddExp(cmd.id, expGain)
end

--- 判断后勤专精被动回收是否生效
---@param fleetId number
---@return number salvageMult  1.0=无加成, 1.3=有回收加成
function CommanderSystem.GetSalvageMult(fleetId)
    local cmd = CommanderSystem.GetByFleet(fleetId)
    if not cmd or not cmd.spec then return 1.0 end
    if cmd.spec ~= "logistics" then return 1.0 end
    if cmd.level < 5 then return 1.0 end
    return COMMANDER_SPECS.logistics.skill.effectMult
end

-- ============================================================================
-- 序列化/反序列化（跨局持久化，存入 galaxy_career.json）
-- ============================================================================

--- 序列化
---@return table
function CommanderSystem.Serialize()
    local data = { nextId = nextId_, commanders = {} }
    for _, cmd in ipairs(commanders_) do
        data.commanders[#data.commanders + 1] = {
            id       = cmd.id,
            name     = cmd.name,
            level    = cmd.level,
            exp      = cmd.exp,
            spec     = cmd.spec,
            source   = cmd.source,
            fleetId  = cmd.fleetId,
        }
    end
    return data
end

--- 反序列化
---@param data table
function CommanderSystem.Deserialize(data)
    if type(data) ~= "table" then return end
    nextId_ = data.nextId or 1
    commanders_ = {}
    if type(data.commanders) == "table" then
        for _, d in ipairs(data.commanders) do
            commanders_[#commanders_ + 1] = {
                id            = d.id or nextId_,
                name          = d.name or "未知",
                level         = d.level or 1,
                exp           = d.exp or 0,
                spec          = d.spec,
                source        = d.source or "initial",
                fleetId       = d.fleetId,
                skillCooldown = 0,
            }
            if (d.id or 0) >= nextId_ then
                nextId_ = d.id + 1
            end
        end
    end
    print(string.format("[Commander] 加载 %d 位指挥官", #commanders_))
end

--- 重置（新游戏开始时，但保留指挥官——因为跨局持久）
--- 仅重置编队分配和技能冷却
function CommanderSystem.ResetBattleState()
    for _, cmd in ipairs(commanders_) do
        cmd.skillCooldown = 0
    end
end

--- 完全重置（仅调试或新存档时）
function CommanderSystem.FullReset()
    commanders_ = {}
    nextId_ = 1
end

return CommanderSystem
