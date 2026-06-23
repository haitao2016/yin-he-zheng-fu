---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- BattleHud.lua — HUD 点击处理 & 按钮区域管理
-- 负责：技能升级卡片点击 / 战败画面按钮 / 战斗指令按钮 / 集火取消 /
--       撤退/增援按钮 / 阵型按钮 / 舰船点击 / 普通移动点击。
-- 通过 SyncIn 注入战斗所需的表引用与回调；通过 HandleClick 分发。
-- ============================================================================

local BattleSkills = require("game.BattleSkills")

local BattleHud = {}

-- ============================================================================
-- 注入的引用 & 回调（SyncIn 填充）
-- ============================================================================
local notifyFn_    = nil   ---@type function
local onBattleEnd_ = nil   ---@type function
local rm_          = nil   ---@type table
local playerFleet_ = nil   ---@type table
local enemyFleet_  = nil   ---@type table
local floatTexts_  = nil   ---@type table
local battleStats_ = nil   ---@type table

-- 可选子模块引用：用于扩展点击处理（技能/指令）
local BattleOrchestrator_ = nil  -- 撤退/增援/指令 可委托到 Orchestrator
local cmdSys_               = nil  ---@type table|nil

-- 标量与按钮区域（每次 SyncIn 刷新；点击后通过 GetOut 回写）
local S = {}

--- 注入引用与状态
---@param opts table { notifyFn, onBattleEnd, rm, playerFleet, enemyFleet,
---                    floatTexts, battleStats, BattleOrchestrator, cmdSys,
---                    vars = { state, battleEndFired, loseBtn1, loseBtn2,
---                            commandBtns, focusHudBtn, focusTarget,
---                            selectedShip, retreatBtn, reinforceBtn,
---                            formationBtn, skillUpgradeCards,
---                            skillUpgradeCardBtns, screenW, screenH,
---                            moveTarget, battleSpeed, battleSpeedId,
---                            autoBattleEnabled, SK } }
function BattleHud.SyncIn(opts)
    notifyFn_    = opts.notifyFn
    onBattleEnd_ = opts.onBattleEnd
    rm_          = opts.rm
    playerFleet_ = opts.playerFleet
    enemyFleet_  = opts.enemyFleet
    floatTexts_  = opts.floatTexts
    battleStats_ = opts.battleStats

    BattleOrchestrator_ = opts.BattleOrchestrator
    cmdSys_             = opts.cmdSys

    local v = opts.vars or {}
    S.state               = v.state               or "fighting"
    S.battleEndFired      = v.battleEndFired      or false
    S.loseBtn1            = v.loseBtn1
    S.loseBtn2            = v.loseBtn2
    S.commandBtns         = v.commandBtns         or {}
    S.focusHudBtn         = v.focusHudBtn
    S.focusTarget         = v.focusTarget
    S.selectedShip        = v.selectedShip
    S.retreatBtn          = v.retreatBtn
    S.reinforceBtn        = v.reinforceBtn
    S.formationBtn        = v.formationBtn        or {}
    S.skillUpgradeCards   = v.skillUpgradeCards
    S.skillUpgradeCardBtns = v.skillUpgradeCardBtns or {}
    S.screenW             = v.screenW             or 800
    S.screenH             = v.screenH             or 600
    S.moveTarget          = v.moveTarget
    S.battleSpeed         = v.battleSpeed         or 1.0
    S.battleSpeedId       = v.battleSpeedId       or "NORMAL"
    S.autoBattleEnabled   = v.autoBattleEnabled   or false
    S.SK                  = v.SK                  or { timer = 0, dur = 0, strength = 0, offX = 0, offY = 0 }
end

--- 返回标量回写表
function BattleHud.GetOut()
    return {
        state               = S.state,
        battleEndFired      = S.battleEndFired,
        loseBtn1            = S.loseBtn1,
        loseBtn2            = S.loseBtn2,
        commandBtns         = S.commandBtns,
        focusHudBtn         = S.focusHudBtn,
        focusTarget         = S.focusTarget,
        selectedShip        = S.selectedShip,
        retreatBtn          = S.retreatBtn,
        reinforceBtn        = S.reinforceBtn,
        formationBtn        = S.formationBtn,
        skillUpgradeCards   = S.skillUpgradeCards,
        skillUpgradeCardBtns = S.skillUpgradeCardBtns,
        moveTarget          = S.moveTarget,
        battleSpeed         = S.battleSpeed,
        battleSpeedId       = S.battleSpeedId,
        autoBattleEnabled   = S.autoBattleEnabled,
    }
end

-- ============================================================================
-- 内部辅助：点命中
-- ============================================================================
local function hitRect(btn, x, y)
    if not btn then return false end
    return x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h
end

local function hitCircle(cx, cy, r, x, y)
    local dx = x - cx
    local dy = y - cy
    return dx * dx + dy * dy <= r * r
end

-- ============================================================================
-- 主分发
-- ============================================================================

--- 处理一次屏幕点击（坐标为原始屏幕坐标；未做震动偏移矫正）
---@param mx number
---@param my number
---@return boolean handled 若为 true 表示点击已被 HUD 消费
function BattleHud.HandleClick(mx, my)
    -- 1) 技能升级弹窗：仅在 win 阶段显示，优先级最高
    if S.skillUpgradeCards and #S.skillUpgradeCards > 0 and S.state == "win" then
        for _, btn in ipairs(S.skillUpgradeCardBtns) do
            if hitRect(btn, mx, my) then
                BattleSkills.UpgradeSkill(btn.skillIdx)
                if notifyFn_ then
                    notifyFn_(BattleSkills.GetIcon(btn.skillIdx) .. " " ..
                              BattleSkills.GetName(btn.skillIdx) .. " 升至 Lv" ..
                              BattleSkills.GetLevel(btn.skillIdx), "success")
                end
                S.skillUpgradeCards   = nil
                S.skillUpgradeCardBtns = {}
                return true
            end
        end
        return true  -- 点击弹窗外区域也吃掉，避免穿透到舰船选择
    end

    -- 2) 战败画面触屏按钮
    if S.state == "lose" then
        if hitRect(S.loseBtn1, mx, my) then
            -- 重新战斗由 BattleScene 负责：此处仅消费点击并让 BattleScene 做 Reset
            return true
        elseif hitRect(S.loseBtn2, mx, my) then
            if onBattleEnd_ and not S.battleEndFired then
                S.battleEndFired = true
                onBattleEnd_("lose")
            end
            return true
        end
        return true  -- 战败时屏蔽其他区域点击
    end
    if S.state ~= "fighting" then return false end

    -- 3) 战斗指令按钮
    if S.commandBtns and #S.commandBtns > 0 then
        for _, btn in ipairs(S.commandBtns) do
            if hitRect(btn, mx, my) then
                if BattleOrchestrator_ and BattleOrchestrator_.ExecuteCommand then
                    local ok, reason = BattleOrchestrator_.ExecuteCommand(btn.id)
                    if not ok and notifyFn_ then notifyFn_(reason, "warn") end
                elseif cmdSys_ and cmdSys_.execute then
                    local ok, reason = cmdSys_:execute(btn.id, {})
                    if not ok and notifyFn_ then notifyFn_(reason, "warn") end
                end
                return true
            end
        end
    end

    -- 4) 集火取消按钮（顶部状态条右侧 ✕）
    if hitRect(S.focusHudBtn, mx, my) then
        S.focusTarget = nil
        return true
    end

    -- 5) 舰船点击：我方（显示信息）→ 敌方（集火）
    local SHIP_HIT_RADIUS = 14
    local clickedShip = nil
    for _, s in ipairs(playerFleet_) do
        if hitCircle(s.x, s.y, SHIP_HIT_RADIUS, mx, my) then clickedShip = s; break end
    end
    if not clickedShip then
        for _, s in ipairs(enemyFleet_) do
            if hitCircle(s.x, s.y, SHIP_HIT_RADIUS, mx, my) then clickedShip = s; break end
        end
    end
    if clickedShip then
        if clickedShip.team == "enemy" then
            S.focusTarget = (S.focusTarget == clickedShip) and nil or clickedShip
        end
        S.selectedShip = (S.selectedShip == clickedShip) and nil or clickedShip
        return true
    end

    -- 6) 撤退按钮
    if hitRect(S.retreatBtn, mx, my) then
        if BattleOrchestrator_ and BattleOrchestrator_.TryRetreat then
            local ok, reason = BattleOrchestrator_.TryRetreat()
            if not ok and notifyFn_ then notifyFn_(reason, "warn") end
        end
        return true
    end

    -- 7) 增援按钮
    if hitRect(S.reinforceBtn, mx, my) then
        if BattleOrchestrator_ and BattleOrchestrator_.TryReinforce then
            local ok, reason = BattleOrchestrator_.TryReinforce()
            if not ok and notifyFn_ then notifyFn_(reason, "warn") end
        end
        return true
    end

    -- 8) 阵型按钮
    for _, btn in ipairs(S.formationBtn) do
        if hitRect(btn, mx, my) then
            if btn.locked then return true end
            if BattleOrchestrator_ and BattleOrchestrator_.SetFormation then
                BattleOrchestrator_.SetFormation(btn.key)
            else
                S.currentFormation = btn.key
            end
            return true
        end
    end

    -- 9) 技能按钮（BattleSkills.OnClick 处理）
    local handled = BattleSkills.OnClick(mx, my, {
        rs          = rm_,
        notifyFn    = notifyFn_,
        playerFleet = playerFleet_,
        enemyFleet  = enemyFleet_,
        floatTexts  = floatTexts_,
        battleStats = battleStats_,
        screenW     = S.screenW,
        screenH     = S.screenH,
        onShake     = function(dur, str)
            S.SK.timer    = dur
            S.SK.dur      = dur
            S.SK.strength = str
        end,
    })
    if handled then return true end

    -- 10) 普通点击：移动指令（同时取消单舰选中）
    S.selectedShip = nil
    if playerFleet_ then
        for i, s in ipairs(playerFleet_) do
            local spread = (#playerFleet_ > 1) and (i - (#playerFleet_ + 1) / 2) * 28 or 0
            s.target = { x = mx, y = my + spread }
        end
    end
    S.moveTarget = { x = mx, y = my }
    return true
end

-- ============================================================================
-- 按钮区域管理（供 BattleScene.Render 设置后再回写）
-- ============================================================================

--- 设置战败画面按钮区域
function BattleHud.SetLoseButtons(btn1, btn2)
    S.loseBtn1 = btn1
    S.loseBtn2 = btn2
end

--- 设置战斗指令按钮区域
function BattleHud.SetCommandButtons(btns)
    S.commandBtns = btns or {}
end

--- 设置集火取消按钮区域
function BattleHud.SetFocusHudBtn(btn)
    S.focusHudBtn = btn
end

--- 设置撤退/增援按钮区域
function BattleHud.SetRetreatReinforce(retreatBtn, reinforceBtn)
    S.retreatBtn   = retreatBtn
    S.reinforceBtn = reinforceBtn
end

--- 设置阵型按钮区域
function BattleHud.SetFormationButtons(btns)
    S.formationBtn = btns or {}
end

--- 设置技能升级卡片区域
function BattleHud.SetSkillUpgradeCards(cards, btns)
    S.skillUpgradeCards   = cards
    S.skillUpgradeCardBtns = btns or {}
end

--- 获取当前选中舰船
function BattleHud.GetSelectedShip() return S.selectedShip end
--- 获取当前集火目标
function BattleHud.GetFocusTarget() return S.focusTarget end

--- 设置屏幕尺寸（用于默认坐标计算）
function BattleHud.SetScreenSize(w, h)
    S.screenW = w or S.screenW
    S.screenH = h or S.screenH
end

return BattleHud
