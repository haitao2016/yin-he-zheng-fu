---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-----------------------------------------------------------
-- BattleCommandSystem 战斗中途指令系统
-----------------------------------------------------------
require("game.GameConstants")

BATTLE_COMMANDS = {
    {
        id = "FOCUS_FIRE",
        name = "集火目标",
        desc = "全舰队集火指定目标：+50% 伤害，+100% 射速，持续 8 秒",
        icon = "icon_focus",
        cooldown = 45,
        duration = 8,
        effect = { attackMult = 0.50, fireRateMult = 1.00, stance = "focus" }
    },
    {
        id = "DEFENSE_STANCE",
        name = "优先防御",
        desc = "舰队转入防御姿态：-30% 伤害，+50% 防御，持续 10 秒",
        icon = "icon_defense_stance",
        cooldown = 40,
        duration = 10,
        effect = { attackMult = -0.30, defenseMult = 0.50, stance = "defense" }
    },
    {
        id = "TACTICAL_RETREAT",
        name = "后撤重整",
        desc = "舰队后撤：+30% 移动速度，护盾 +40%，5 秒内无法攻击",
        icon = "icon_retreat",
        cooldown = 60,
        duration = 5,
        effect = { speedMult = 0.30, shieldMult = 0.40, disableAttack = true }
    },
    {
        id = "FULL_SALVO",
        name = "全弹发射",
        desc = "一次性发射所有武器：+200% 伤害，消耗所有技能充能",
        icon = "icon_salvo",
        cooldown = 90,
        duration = 1,
        effect = { attackMult = 2.00, consumeAllCharge = true, stance = "salvo" }
    },
    {
        id = "EMERGENCY_REPAIR",
        name = "紧急修理",
        desc = "紧急修复 30% 最大生命值，冷却 60 秒",
        icon = "icon_repair",
        cooldown = 60,
        duration = 0,
        effect = { healPct = 0.30 }
    }
}

local BATTLE_COMMANDS_BY_ID = {}
for _, c in ipairs(BATTLE_COMMANDS) do BATTLE_COMMANDS_BY_ID[c.id] = c end

local BattleCommandSystem = {}
BattleCommandSystem.__index = BattleCommandSystem

---@return BattleCommandSystem
function BattleCommandSystem.new()
    local self = setmetatable({}, BattleCommandSystem)
    self.cooldowns = {}
    self.active    = {}
    for _, c in ipairs(BATTLE_COMMANDS) do
        self.cooldowns[c.id] = 0
        self.active[c.id]    = 0
    end
    return self
end

--- 检查指令是否可用
---@param commandId string
---@param battleState table
---@return boolean, string
function BattleCommandSystem:canUse(commandId, battleState)
    local cmd = BATTLE_COMMANDS_BY_ID[commandId]
    if not cmd then return false, "未知指令" end
    local cd = self.cooldowns[commandId] or 0
    if cd > 0 then return false, "冷却中 " .. string.format("%.1fs", cd) end
    if battleState and cmd.effect.consumeAllCharge then
        local charge = battleState.skillCharge or 0
        if charge <= 0 then return false, "无技能充能" end
    end
    return true, ""
end

--- 执行指令并应用效果（P0-4: 支持效果过期后自动回滚）
---@param commandId string
---@param battleState table
---@return boolean, string
function BattleCommandSystem:execute(commandId, battleState)
    local ok, reason = self:canUse(commandId, battleState)
    if not ok then return false, reason end
    local cmd = BATTLE_COMMANDS_BY_ID[commandId]
    self.cooldowns[commandId] = cmd.cooldown
    self.active[commandId]    = cmd.duration
    if battleState then
        battleState.battleCommands = battleState.battleCommands or {}
        battleState.battleCommands[commandId] = { remaining = cmd.duration, startedAt = os.time() }
        battleState.baseBonus = battleState.baseBonus or {}
        local e = cmd.effect
        -- 记录用于过期回滚的加成值
        local applied = {}
        if e.attackMult then
            battleState.baseBonus.attackMult = (battleState.baseBonus.attackMult or 0) + e.attackMult
            applied.attackMult = e.attackMult
        end
        if e.defenseMult then
            battleState.baseBonus.defenseMult = (battleState.baseBonus.defenseMult or 0) + e.defenseMult
            applied.defenseMult = e.defenseMult
        end
        if e.fireRateMult then
            battleState.baseBonus.fireRateMult = (battleState.baseBonus.fireRateMult or 0) + e.fireRateMult
            applied.fireRateMult = e.fireRateMult
        end
        if e.speedMult then
            battleState.baseBonus.speedMult = (battleState.baseBonus.speedMult or 0) + e.speedMult
            applied.speedMult = e.speedMult
        end
        if e.shieldMult then
            battleState.baseBonus.shieldMult = (battleState.baseBonus.shieldMult or 0) + e.shieldMult
            applied.shieldMult = e.shieldMult
        end
        if e.healPct and battleState.fleet then
            battleState.fleet.hp = math.min(battleState.fleet.maxHp or battleState.fleet.hp,
                battleState.fleet.hp + (battleState.fleet.maxHp or battleState.fleet.hp) * e.healPct)
        end
        if e.consumeAllCharge then
            battleState.skillCharge = 0
        end
        if e.disableAttack then
            battleState.attackDisabledTimer = cmd.duration
        end
        if e.stance then battleState.currentStance = e.stance end
        -- 存储本次加成以用于过期回滚
        self.appliedBonus = self.appliedBonus or {}
        self.appliedBonus[commandId] = applied
        print("[BattleCommand] 执行指令: " .. cmd.name)
    end
    return true, ""
end

--- 每帧更新冷却与持续时间（P0-4: 新增效果过期回滚）
---@param dt number
---@param battleState table
function BattleCommandSystem:update(dt, battleState)
    for id, _ in pairs(self.cooldowns) do
        if self.cooldowns[id] > 0 then
            self.cooldowns[id] = math.max(0, self.cooldowns[id] - dt)
        end
    end
    for id, _ in pairs(self.active) do
        if self.active[id] > 0 then
            self.active[id] = math.max(0, self.active[id] - dt)
            -- 效果过期 → 回滚加成
            if self.active[id] <= 0 and battleState and self.appliedBonus and self.appliedBonus[id] then
                battleState.baseBonus = battleState.baseBonus or {}
                for key, val in pairs(self.appliedBonus[id]) do
                    battleState.baseBonus[key] = (battleState.baseBonus[key] or 0) - val
                end
                self.appliedBonus[id] = nil
                if battleState.currentStance and id ~= "FOCUS_FIRE" and id ~= "DEFENSE_STANCE" and id ~= "FULL_SALVO" then
                    -- 仅该指令设置的 stance 才需要清理
                end
                -- 清理当前姿态（如果是该指令设置的）
                local cmd = BATTLE_COMMANDS_BY_ID[id]
                if cmd and cmd.effect and cmd.effect.stance and battleState.currentStance == cmd.effect.stance then
                    battleState.currentStance = nil
                end
            end
        end
    end
    if battleState and battleState.attackDisabledTimer and battleState.attackDisabledTimer > 0 then
        battleState.attackDisabledTimer = math.max(0, battleState.attackDisabledTimer - dt)
    end
end

--- 返回所有指令冷却状态
---@return table
function BattleCommandSystem:getCooldowns()
    local result = {}
    for _, cmd in ipairs(BATTLE_COMMANDS) do
        result[cmd.id] = {
            name = cmd.name,
            cooldown = self.cooldowns[cmd.id] or 0,
            active = self.active[cmd.id] or 0,
            ready = (self.cooldowns[cmd.id] or 0) <= 0
        }
    end
    return result
end

---@return table
function BattleCommandSystem:serialize()
    return { cooldowns = self.cooldowns, active = self.active }
end

---@param data table
function BattleCommandSystem:deserialize(data)
    self.cooldowns = {}
    self.active    = {}
    for _, c in ipairs(BATTLE_COMMANDS) do
        self.cooldowns[c.id] = 0
        self.active[c.id]    = 0
    end
    if data then
        if data.cooldowns then
            for id, v in pairs(data.cooldowns) do self.cooldowns[id] = v end
        end
        if data.active then
            for id, v in pairs(data.active) do self.active[id] = v end
        end
    end
end

---@param difficultyName string
---@return table
function BattleCommandSystem:applyCooldownCurve(difficultyName)
    local DIFFICULTY_MULT = { EASY = 1.4, NORMAL = 1.0, HARD = 0.7, LEGENDARY = 0.5 }
    local baseMult = DIFFICULTY_MULT[difficultyName] or 1.0

    local fleetCount = 0
    if self.fleet then
        if type(self.fleet) == "table" then
            fleetCount = #self.fleet
        end
    end
    if self.difficulty and type(self.difficulty) == "table" and self.difficulty.fleetCount then
        fleetCount = self.difficulty.fleetCount
    end
    local fleetMult = 1.0
    if fleetCount > 15 then fleetMult = 0.85 end

    local totalMult = baseMult * fleetMult

    self.cmdCooldowns = self.cmdCooldowns or {}
    self.cmdUses = self.cmdUses or {}

    local applied = {}
    for _, cmd in ipairs(BATTLE_COMMANDS) do
        local baseCooldown = cmd.cooldown or 0
        local tuned = baseCooldown * totalMult
        if self.cooldowns and self.cooldowns[cmd.id] then
            self.cooldowns[cmd.id] = tuned
        end
        self.cmdCooldowns[cmd.id] = tuned
        if self.cmdUses[cmd.id] == nil then self.cmdUses[cmd.id] = 0 end
        applied[cmd.id] = tuned
    end

    self.difficulty = self.difficulty or {}
    if type(self.difficulty) == "table" then
        self.difficulty.name = difficultyName
        self.difficulty.mult = totalMult
        self.difficulty.fleetCount = fleetCount
    end

    return applied
end

---@return table
function BattleCommandSystem:getCooldownReport()
    local report = {}
    for _, cmd in ipairs(BATTLE_COMMANDS) do
        report[cmd.id] = {
            name = cmd.name,
            cooldown = (self.cmdCooldowns and self.cmdCooldowns[cmd.id]) or cmd.cooldown or 0,
            remaining = (self.cooldowns and self.cooldowns[cmd.id]) or 0,
            uses = (self.cmdUses and self.cmdUses[cmd.id]) or 0,
        }
    end
    return report
end

return BattleCommandSystem
