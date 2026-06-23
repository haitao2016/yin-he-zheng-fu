-- ============================================================================
-- game/BattleSkills.lua  -- 战术战斗：主动技能系统
-- 负责：技能冷却常量、技能状态、冷却倒计时、技能激活/效果、技能栏渲染、按钮点击
-- 不负责：伤害计算主循环（由 BattleScene 通过 IsActive() 查询技能状态）
-- ============================================================================

local BattleSkills = {}

-- ============================================================================
-- 技能冷却/持续时间常量
-- ============================================================================
local SKILL1_CD        = 30   -- 全体集火：冷却时间（秒）
local SKILL1_DUR       = 5    -- 全体集火：持续时间（秒）
local SKILL2_CD        = 60   -- 紧急修复：冷却时间（秒）
local SKILL3_CD        = 45   -- EMP冲击：冷却时间（秒）
local SKILL3_DUR       = 3    -- EMP冲击：持续时间（秒）
local SKILL4_CD        = 50   -- 护盾强化：冷却时间（秒）
local SKILL4_DUR       = 4    -- 护盾强化：持续时间（秒）
local SKILL5_CD        = 35   -- 相位加速：冷却时间（秒）
local SKILL5_DUR       = 5    -- 相位加速：持续时间（秒）
local SKILL6_CD        = 90   -- 量子弹幕：冷却时间（秒）
local CARRIER_DRONE_CD = 15   -- CARRIER 无人机自动召唤间隔（秒）

-- ============================================================================
-- 私有状态
-- ============================================================================
local skill1CD_       = 0
local skill1Active_   = 0    -- >0 表示激活中（全体集火：伤害翻倍）
local skill2CD_       = 0
local skill3CD_       = 0
local skill3Active_   = 0    -- >0 表示激活中（EMP：敌方移速/射速×0.25）
local skill4CD_       = 0
local skill4Active_   = 0    -- >0 表示激活中（护盾强化：我方受伤减半）
local skill5CD_       = 0
local skill5Active_   = 0    -- >0 表示激活中（相位加速：我方移速×2.5）
local skill6CD_       = 0
local carrierDroneCD_ = 0

-- 技能按钮点击区域（每帧在 Draw 时更新）
local skillBtn1_ = nil
local skillBtn2_ = nil
local skillBtn3_ = nil
local skillBtn4_ = nil
local skillBtn5_ = nil
local skillBtn6_ = nil

-- ============================================================================
-- P2-2: 技能等级系统
-- ============================================================================
-- 每个技能 Lv1(默认)~Lv3，每局战斗重置
-- skillLevels_[n]: 1=默认, 2=效果+50%, 3=效果+100%+CD-20%
local skillLevels_ = { 1, 1, 1, 1, 1, 1 }
local skillPoints_ = 0   -- 可用技能点数
local SKILL_NAMES  = { "全体集火", "紧急修复", "EMP冲击", "护盾强化", "相位加速", "量子弹幕" }
local SKILL_ICONS  = { "⚡", "🔧", "🔵", "🛡", "💨", "✨" }

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 重置技能状态（每波次开始时调用）
--- CD 跨波次保留，只重置激活效果和无人机计时器
function BattleSkills.Reset()
    skill1Active_    = 0
    skill3Active_    = 0
    skill4Active_    = 0
    skill5Active_    = 0
    carrierDroneCD_  = CARRIER_DRONE_CD
end

--- 重置所有状态（包括 CD，用于全新游戏）
function BattleSkills.FullReset()
    skill1CD_ = 0; skill1Active_ = 0
    skill2CD_ = 0
    skill3CD_ = 0; skill3Active_ = 0
    skill4CD_ = 0; skill4Active_ = 0
    skill5CD_ = 0; skill5Active_ = 0
    skill6CD_ = 0
    carrierDroneCD_ = CARRIER_DRONE_CD
    -- P2-2: 重置技能等级和技能点
    skillLevels_ = { 1, 1, 1, 1, 1, 1 }
    skillPoints_ = 0
end

-- ============================================================================
-- P2-2: 技能等级公开 API
-- ============================================================================

--- 获取指定技能当前等级 (1-3)
function BattleSkills.GetLevel(n)
    return skillLevels_[n] or 1
end

--- 获取技能效果倍率（Lv1=1.0, Lv2=1.5, Lv3=2.0）
function BattleSkills.GetEffectMult(n)
    local lv = skillLevels_[n] or 1
    if lv == 2 then return 1.5
    elseif lv == 3 then return 2.0
    end
    return 1.0
end

--- 获取CD倍率（Lv1=1.0, Lv2=1.0, Lv3=0.8）
function BattleSkills.GetCDMult(n)
    if (skillLevels_[n] or 1) >= 3 then return 0.8 end
    return 1.0
end

--- 获取当前可用技能点数
function BattleSkills.GetPoints()
    return skillPoints_
end

--- 给予技能点（每 3 波 +1）
function BattleSkills.AddPoint()
    skillPoints_ = skillPoints_ + 1
end

--- 升级指定技能（消耗1点）返回 true=成功
function BattleSkills.UpgradeSkill(n)
    if skillPoints_ <= 0 then return false end
    local lv = skillLevels_[n] or 1
    if lv >= 3 then return false end  -- 已满级
    skillLevels_[n] = lv + 1
    skillPoints_ = skillPoints_ - 1
    return true
end

--- P2-3: 直接设置技能等级（成就奖励 skill_level 类型使用）
function BattleSkills.SetLevel(n, lv)
    if n >= 1 and n <= 6 then
        skillLevels_[n] = math.max(1, math.min(3, lv))
    end
end

--- P2-3: 直接增加技能点（成就奖励 skill_point 类型使用）
function BattleSkills.AddPoints(count)
    skillPoints_ = skillPoints_ + (count or 1)
end

--- 获取技能名称
function BattleSkills.GetName(n)
    return SKILL_NAMES[n] or ("技能" .. n)
end

--- 获取技能图标
function BattleSkills.GetIcon(n)
    return SKILL_ICONS[n] or "?"
end

--- P1-1 NOVA_CANNON: 波次开始时预充能主动技能（技能1全体集火立刻可用）
--- @param charges number  额外充能次数（NOVA_CANNON = 1）
function BattleSkills.PreChargeOnWaveStart(charges)
    if not charges or charges <= 0 then return end
    -- 将技能1（全体集火）冷却清零，使其在波次开始即可使用
    skill1CD_ = 0
    skill2CD_ = 0  -- 同时重置紧急修复（让玩家多一个开局选择）
end

--- 查询技能是否处于激活状态（供 BattleScene 战斗循环调用）
--- @param n number  技能编号（1=集火, 3=EMP, 4=护盾, 5=加速）
--- @return boolean
function BattleSkills.IsActive(n)
    if n == 1 then return skill1Active_ > 0
    elseif n == 3 then return skill3Active_ > 0
    elseif n == 4 then return skill4Active_ > 0
    elseif n == 5 then return skill5Active_ > 0
    end
    return false
end

--- 每帧更新技能冷却 + 激活计时 + CARRIER 无人机召唤
--- @param dt number  帧时间
--- @param ctx table  上下文：{ state, rs, notifyFn, playerFleet, floatTexts, screenW, screenH, makeShip }
function BattleSkills.Update(dt, ctx)
    if ctx.state ~= "fighting" then return end

    -- 技能冷却倒计时
    skill1CD_ = math.max(0, skill1CD_ - dt)
    skill2CD_ = math.max(0, skill2CD_ - dt)
    skill3CD_ = math.max(0, skill3CD_ - dt)
    skill4CD_ = math.max(0, skill4CD_ - dt)
    skill5CD_ = math.max(0, skill5CD_ - dt)
    skill6CD_ = math.max(0, skill6CD_ - dt)

    -- 全体集火激活倒计时
    if skill1Active_ > 0 then
        skill1Active_ = skill1Active_ - dt
        if skill1Active_ <= 0 then
            skill1Active_ = 0
            if ctx.notifyFn then ctx.notifyFn("集火结束", "info") end
        end
    end
    -- EMP冲击激活倒计时
    if skill3Active_ > 0 then
        skill3Active_ = skill3Active_ - dt
        if skill3Active_ <= 0 then
            skill3Active_ = 0
            if ctx.notifyFn then ctx.notifyFn("EMP消散，敌方恢复正常", "info") end
        end
    end
    -- 护盾强化激活倒计时
    if skill4Active_ > 0 then
        skill4Active_ = skill4Active_ - dt
        if skill4Active_ <= 0 then
            skill4Active_ = 0
            if ctx.notifyFn then ctx.notifyFn("护盾强化结束", "info") end
        end
    end
    -- 相位加速激活倒计时
    if skill5Active_ > 0 then
        skill5Active_ = skill5Active_ - dt
        if skill5Active_ <= 0 then
            skill5Active_ = 0
            if ctx.notifyFn then ctx.notifyFn("相位加速结束", "info") end
        end
    end

    -- CARRIER 无人机自动召唤
    local hasCarrier = false
    for _, s in ipairs(ctx.playerFleet) do
        if s.stype == "CARRIER" then hasCarrier = true; break end
    end
    if hasCarrier then
        carrierDroneCD_ = carrierDroneCD_ - dt
        if carrierDroneCD_ <= 0 then
            carrierDroneCD_ = CARRIER_DRONE_CD
            for k = 1, 2 do
                local mx = 60 + math.random() * 80
                local my = ctx.screenH * 0.2 + math.random() * ctx.screenH * 0.6
                ctx.playerFleet[#ctx.playerFleet + 1] = ctx.makeShip("SCOUT", mx, my, "player")
            end
            ctx.floatTexts[#ctx.floatTexts + 1] = {
                x = ctx.screenW / 2, y = ctx.screenH * 0.4,
                text = "CARRIER 召唤 2 架无人机", life = 1.8, maxLife = 1.8,
                vy = -22, team = "enemy"
            }
            if ctx.notifyFn then ctx.notifyFn("CARRIER 召唤无人机！", "info") end
        end
    end
end

--- 渲染技能按钮栏（同时记录各按钮点击区域）
--- @param ctx table  上下文：{ vg, state, rs, screenW, screenH }
function BattleSkills.Draw(ctx)
    if ctx.state ~= "fighting" then return end

    local vg      = ctx.vg
    local screenW = ctx.screenW
    local screenH = ctx.screenH

    local btnW, btnH = 74, 36
    local gapX, gapY = 6, 5
    local cols        = 3
    local totalW      = btnW * cols + gapX * (cols - 1)
    local startX      = screenW / 2 - totalW / 2
    local row2Y       = screenH - btnH - 6
    local row1Y       = row2Y - btnH - gapY

    -- 科技解锁检查
    local rs = ctx.rs
    local hasNanoRepair      = rs and rs.unlocked and rs.unlocked["NANO_REPAIR"]
    local hasShieldReinforce = rs and rs.unlocked and rs.unlocked["SHIELD_REINFORCE"]
    local hasWarpDrive       = rs and rs.unlocked and rs.unlocked["WARP_DRIVE"]
    local hasQuantumCore     = rs and rs.unlocked and rs.unlocked["QUANTUM_CORE"]

    -- 辅助函数：绘制单个技能按钮
    local function drawBtn(bx, rowY, label, subLabel, cd, maxCd, activeTimer, locked, lockHint)
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, rowY, btnW, btnH, 6)
        if locked then
            nvgFillColor(vg, nvgRGBA(25, 25, 38, 160))
        elseif activeTimer > 0 then
            nvgFillColor(vg, nvgRGBA(255, 200, 50, 200))
        elseif cd > 0 then
            nvgFillColor(vg, nvgRGBA(18, 22, 44, 180))
        else
            nvgFillColor(vg, nvgRGBA(28, 55, 110, 215))
        end
        nvgFill(vg)
        -- 边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx + 0.5, rowY + 0.5, btnW - 1, btnH - 1, 6)
        if activeTimer > 0 then
            nvgStrokeColor(vg, nvgRGBA(255, 230, 80, 255))
        elseif locked then
            nvgStrokeColor(vg, nvgRGBA(70, 70, 90, 100))
        else
            nvgStrokeColor(vg, nvgRGBA(55, 110, 210, 170))
        end
        nvgStrokeWidth(vg, 1.2)
        nvgStroke(vg)
        -- 冷却遮罩（从上到下）
        if cd > 0 and not locked then
            local ratio = cd / maxCd
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, rowY, btnW, btnH * ratio, 6)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 130))
            nvgFill(vg)
        end
        -- 技能名称
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if locked then
            nvgFillColor(vg, nvgRGBA(90, 90, 120, 150))
        elseif activeTimer > 0 then
            nvgFillColor(vg, nvgRGBA(30, 20, 0, 255))
        else
            nvgFillColor(vg, nvgRGBA(195, 225, 255, 225))
        end
        nvgFontSize(vg, 12)
        nvgText(vg, bx + btnW / 2, rowY + btnH / 2 - 7, label)
        -- 副标签
        nvgFontSize(vg, 9)
        if locked then
            nvgFillColor(vg, nvgRGBA(110, 110, 150, 140))
            nvgText(vg, bx + btnW / 2, rowY + btnH / 2 + 7, lockHint or "需科技解锁")
        elseif activeTimer > 0 then
            nvgFillColor(vg, nvgRGBA(50, 30, 0, 220))
            nvgText(vg, bx + btnW / 2, rowY + btnH / 2 + 7, string.format("%.1fs", activeTimer))
        elseif cd > 0 then
            nvgFillColor(vg, nvgRGBA(140, 170, 215, 170))
            nvgText(vg, bx + btnW / 2, rowY + btnH / 2 + 7, string.format("CD %.0fs", cd))
        else
            nvgFillColor(vg, nvgRGBA(95, 215, 135, 200))
            nvgText(vg, bx + btnW / 2, rowY + btnH / 2 + 7, subLabel)
        end
    end

    -- 第一行：全体集火 | EMP冲击 | 相位加速
    local bx1 = startX
    local bx3 = startX + btnW + gapX
    local bx5 = startX + (btnW + gapX) * 2
    drawBtn(bx1, row1Y, "⚡全体集火", "30s CD", skill1CD_, SKILL1_CD, skill1Active_, false, nil)
    drawBtn(bx3, row1Y, "🔵EMP冲击",  "45s CD", skill3CD_, SKILL3_CD, skill3Active_, false, nil)
    drawBtn(bx5, row1Y, "💨相位加速", "35s CD", skill5CD_, SKILL5_CD, skill5Active_,
        not hasWarpDrive, "需 曲速引擎")

    -- 第二行：紧急修复 | 护盾强化 | 量子弹幕
    local bx2 = startX
    local bx4 = startX + btnW + gapX
    local bx6 = startX + (btnW + gapX) * 2
    drawBtn(bx2, row2Y, "🔧紧急修复", "60s CD", skill2CD_, SKILL2_CD, 0,
        not hasNanoRepair, "需 纳米修复")
    drawBtn(bx4, row2Y, "🛡护盾强化", "50s CD", skill4CD_, SKILL4_CD, skill4Active_,
        not hasShieldReinforce, "需 护盾强化")
    drawBtn(bx6, row2Y, "✨量子弹幕", "90s CD", skill6CD_, SKILL6_CD, 0,
        not hasQuantumCore, "需 量子核心")

    -- P2-2: 在每个按钮右上角绘制等级小标（Lv2/Lv3 时显示）
    local function drawLvBadge(bx, rowY, skillIdx)
        local lv = skillLevels_[skillIdx] or 1
        if lv <= 1 then return end
        local badgeX = bx + btnW - 2
        local badgeY = rowY + 2
        -- 背景圆点
        nvgBeginPath(vg)
        nvgCircle(vg, badgeX, badgeY, 7)
        if lv >= 3 then
            nvgFillColor(vg, nvgRGBA(255, 190, 30, 230))
        else
            nvgFillColor(vg, nvgRGBA(80, 200, 120, 210))
        end
        nvgFill(vg)
        -- 等级文字
        nvgFontSize(vg, 8)
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(10, 10, 10, 240))
        nvgText(vg, badgeX, badgeY, "L" .. lv)
    end
    drawLvBadge(bx1, row1Y, 1)
    drawLvBadge(bx3, row1Y, 3)
    drawLvBadge(bx5, row1Y, 5)
    drawLvBadge(bx2, row2Y, 2)
    drawLvBadge(bx4, row2Y, 4)
    drawLvBadge(bx6, row2Y, 6)

    -- 记录6个技能按钮点击区域（供 OnClick 使用）
    skillBtn1_ = { x = bx1, y = row1Y, w = btnW, h = btnH }
    skillBtn3_ = { x = bx3, y = row1Y, w = btnW, h = btnH }
    skillBtn5_ = { x = bx5, y = row1Y, w = btnW, h = btnH }
    skillBtn2_ = { x = bx2, y = row2Y, w = btnW, h = btnH }
    skillBtn4_ = { x = bx4, y = row2Y, w = btnW, h = btnH }
    skillBtn6_ = { x = bx6, y = row2Y, w = btnW, h = btnH }
end

--- 处理技能按钮点击。返回 true 表示点击已被消费。
--- @param mx number  点击 X（逻辑像素）
--- @param my number  点击 Y（逻辑像素）
--- @param ctx table  上下文：{ rs, notifyFn, playerFleet, enemyFleet, floatTexts,
---                             battleStats, screenW, screenH, onShake }
--- @return boolean
function BattleSkills.OnClick(mx, my, ctx)
    local function inBtn(b)
        return b and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h
    end

    local notifyFn   = ctx.notifyFn
    local floatTexts = ctx.floatTexts
    local screenW    = ctx.screenW
    local screenH    = ctx.screenH
    local rs         = ctx.rs

    -- 技能1：全体集火
    if inBtn(skillBtn1_) then
        if skill1Active_ > 0 then
            -- 已激活中，忽略
        elseif skill1CD_ > 0 then
            if notifyFn then notifyFn(string.format("集火冷却中 %.0fs", skill1CD_), "warn") end
        else
            skill1Active_ = SKILL1_DUR
            skill1CD_     = math.floor(SKILL1_CD * BattleSkills.GetCDMult(1))
            if notifyFn then notifyFn("全体集火！伤害翻倍 " .. SKILL1_DUR .. "s", "success") end
        end
        return true
    end

    -- 技能2：紧急修复
    if inBtn(skillBtn2_) then
        local hasNanoRepair = rs and rs.unlocked and rs.unlocked["NANO_REPAIR"]
        if not hasNanoRepair then
            if notifyFn then notifyFn("需研究 纳米修复 科技", "warn") end
        elseif skill2CD_ > 0 then
            if notifyFn then notifyFn(string.format("修复冷却中 %.0fs", skill2CD_), "warn") end
        else
            skill2CD_ = math.floor(SKILL2_CD * BattleSkills.GetCDMult(2))
            local healed = 0
            for _, s in ipairs(ctx.playerFleet) do
                local gain = math.floor(s.maxHealth * 0.20)
                s.health   = math.min(s.maxHealth, s.health + gain)
                healed     = healed + gain
            end
            if notifyFn then notifyFn(string.format("紧急修复！+%.0f HP", healed), "success") end
            floatTexts[#floatTexts + 1] = {
                x = screenW / 2, y = screenH * 0.5,
                text = string.format("+%d HP 修复", healed), life = 1.5, maxLife = 1.5,
                vy = -28, team = "player"
            }
        end
        return true
    end

    -- 技能3：EMP冲击
    if inBtn(skillBtn3_) then
        if skill3Active_ > 0 then
            -- 已激活，无需重复
        elseif skill3CD_ > 0 then
            if notifyFn then notifyFn(string.format("EMP冷却中 %.0fs", skill3CD_), "warn") end
        else
            skill3Active_ = SKILL3_DUR
            skill3CD_     = math.floor(SKILL3_CD * BattleSkills.GetCDMult(3))
            if notifyFn then notifyFn("EMP冲击！敌方速度降低 " .. SKILL3_DUR .. "s", "success") end
            floatTexts[#floatTexts + 1] = {
                x = screenW / 2, y = screenH * 0.45,
                text = "⚡ EMP！敌方瘫痪 " .. SKILL3_DUR .. "s",
                life = 1.5, maxLife = 1.5, vy = -24, team = "enemy"
            }
        end
        return true
    end

    -- 技能4：护盾强化
    if inBtn(skillBtn4_) then
        local hasShieldReinforce = rs and rs.unlocked and rs.unlocked["SHIELD_REINFORCE"]
        if not hasShieldReinforce then
            if notifyFn then notifyFn("需研究 护盾强化 科技", "warn") end
        elseif skill4Active_ > 0 then
            -- 已激活
        elseif skill4CD_ > 0 then
            if notifyFn then notifyFn(string.format("护盾冷却中 %.0fs", skill4CD_), "warn") end
        else
            skill4Active_ = SKILL4_DUR
            skill4CD_     = math.floor(SKILL4_CD * BattleSkills.GetCDMult(4))
            if notifyFn then notifyFn("护盾强化！受伤减半 " .. SKILL4_DUR .. "s", "success") end
            floatTexts[#floatTexts + 1] = {
                x = screenW / 2, y = screenH * 0.5,
                text = "🛡 护盾强化 " .. SKILL4_DUR .. "s",
                life = 1.5, maxLife = 1.5, vy = -24, team = "player"
            }
        end
        return true
    end

    -- 技能5：相位加速
    if inBtn(skillBtn5_) then
        local hasWarpDrive = rs and rs.unlocked and rs.unlocked["WARP_DRIVE"]
        if not hasWarpDrive then
            if notifyFn then notifyFn("需研究 曲速引擎 科技", "warn") end
        elseif skill5Active_ > 0 then
            -- 已激活
        elseif skill5CD_ > 0 then
            if notifyFn then notifyFn(string.format("加速冷却中 %.0fs", skill5CD_), "warn") end
        else
            skill5Active_ = SKILL5_DUR
            skill5CD_     = math.floor(SKILL5_CD * BattleSkills.GetCDMult(5))
            if notifyFn then notifyFn("相位加速！舰队提速×2.5 " .. SKILL5_DUR .. "s", "success") end
            floatTexts[#floatTexts + 1] = {
                x = screenW / 2, y = screenH * 0.55,
                text = "💨 相位加速！",
                life = 1.3, maxLife = 1.3, vy = -26, team = "player"
            }
        end
        return true
    end

    -- 技能6：量子弹幕
    if inBtn(skillBtn6_) then
        local hasQuantumCore = rs and rs.unlocked and rs.unlocked["QUANTUM_CORE"]
        if not hasQuantumCore then
            if notifyFn then notifyFn("需研究 量子核心 科技", "warn") end
        elseif skill6CD_ > 0 then
            if notifyFn then notifyFn(string.format("弹幕冷却中 %.0fs", skill6CD_), "warn") end
        else
            skill6CD_ = math.floor(SKILL6_CD * BattleSkills.GetCDMult(6))
            local totalDmg   = 0
            local dmgPerShip = 50
            for _, es in ipairs(ctx.enemyFleet) do
                local d = dmgPerShip
                if es.isBoss and es.shield > 0 then
                    local abs = math.min(es.shield, d)
                    es.shield = es.shield - abs
                    d = d - abs
                end
                es.health   = es.health - d
                es.hitFlash = 1.0
                totalDmg    = totalDmg + d
                floatTexts[#floatTexts + 1] = {
                    x = es.x + math.random(-8, 8), y = es.y - 18,
                    text = "-" .. d .. "✨",
                    life = 1.0, maxLife = 1.0, vy = -40, team = "enemy"
                }
            end
            if ctx.battleStats then
                ctx.battleStats.dmgDealt = ctx.battleStats.dmgDealt + totalDmg
            end
            if notifyFn then
                notifyFn(string.format("量子弹幕！总伤害 %d", totalDmg), "success")
            end
            if ctx.onShake then ctx.onShake(0.4, 6) end
        end
        return true
    end

    return false
end

return BattleSkills
