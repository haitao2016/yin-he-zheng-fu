---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- RenderEntities: 实体层渲染 — 舰船/弹药/粒子 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")

local SHIP_LABEL = {
    SCOUT        = "侦察",
    FRIGATE      = "护卫",
    DESTROYER    = "驱逐",
    BATTLECRUISER= "战列",
    MINER        = "采矿",
    ENGINEER     = "工程",
    EXPLORER     = "探索",
}

local RenderEntities = {}

local function drawShip(ship)
    -- Boss 金色光晕 aura（渲染在血条/图片之下）
    if ship.isBoss then
        local glowBase = 30
        for i = 3, 1, -1 do
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, ship.x, ship.y, glowBase + i * 6)
            nvgFillColor(BS.vg, nvgRGBA(255, 200, 50, math.floor(25 / i)))
            nvgFill(BS.vg)
        end
        -- 外圈描边
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, ship.x, ship.y, glowBase + 5)
        nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 50, 120))
        nvgStrokeWidth(BS.vg, 1.5)
        nvgStroke(BS.vg)
    end
    -- P2-1: 增援舰红色脉冲光晕
    if ship.isReinforce then
        local pulse = 0.6 + 0.4 * math.abs(math.sin((ship.age or 0) * 3.0))
        for i = 2, 1, -1 do
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, ship.x, ship.y, 16 + i * 5)
            nvgFillColor(BS.vg, nvgRGBA(255, 60, 60, math.floor(pulse * 30 / i)))
            nvgFill(BS.vg)
        end
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, ship.x, ship.y, 18)
        nvgStrokeColor(BS.vg, nvgRGBA(255, 80, 80, math.floor(pulse * 180)))
        nvgStrokeWidth(BS.vg, 1.5)
        nvgStroke(BS.vg)
    end
    -- P1-1 EXPLORER: 图绘先行 — 标记敌舰显示红色脉冲瞄准环
    if ship == BS.explorerMarkTarget then
        local pulse = 0.5 + 0.5 * math.abs(math.sin((ship.age or 0) * 4.0))
        -- 外环（渐变透明）
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, ship.x, ship.y, 20 + pulse * 6)
        nvgStrokeColor(BS.vg, nvgRGBA(255, 50, 50, math.floor(pulse * 200)))
        nvgStrokeWidth(BS.vg, 2.0)
        nvgStroke(BS.vg)
        -- 内十字准星（4条短线）
        nvgStrokeColor(BS.vg, nvgRGBA(255, 80, 80, math.floor(180 * pulse)))
        nvgStrokeWidth(BS.vg, 1.5)
        local c = 14
        for _, dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, ship.x + dir[1]*(c-4), ship.y + dir[2]*(c-4))
            nvgLineTo(BS.vg, ship.x + dir[1]*c,     ship.y + dir[2]*c)
            nvgStroke(BS.vg)
        end
    end

    -- Boss 护盾条（在血条上方 y-22）
    if ship.isBoss and ship.maxShield > 0 then
        local shieldFrac = math.max(0, ship.shield / ship.maxShield)
        -- 护盾底轨
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, ship.x-12, ship.y-22, 24, 4)
        nvgFillColor(BS.vg, nvgRGBA(30, 0, 60, 220))
        nvgFill(BS.vg)
        -- 护盾前景（紫色）
        if shieldFrac > 0 then
            nvgBeginPath(BS.vg)
            nvgRect(BS.vg, ship.x-12, ship.y-22, math.floor(24*shieldFrac), 4)
            nvgFillColor(BS.vg, nvgRGBA(160, 60, 255, 230))
            nvgFill(BS.vg)
        end
        -- 护盾条描边
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, ship.x-12, ship.y-22, 24, 4)
        nvgStrokeColor(BS.vg, nvgRGBA(200, 100, 255, 120))
        nvgStrokeWidth(BS.vg, 0.8)
        nvgStroke(BS.vg)
    end

    -- P3-2 V2.0: 血条渲染（低血闪烁 + 护盾叠层）
    local hp = math.max(0, ship.health / ship.maxHealth)
    local isLowHp = (hp < 0.3)
    -- 低血闪烁：sin波形映射到 alpha 170~255
    local hpAlpha = 220
    if isLowHp then
        local blinkSin = math.sin(BS.hpBlinkTimer / 0.5 * math.pi * 2)
        hpAlpha = math.floor(170 + (blinkSin + 1) * 0.5 * 85)  -- 170~255
    end
    -- 血条背景
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, ship.x-12, ship.y-16, 24, 4)
    nvgFillColor(BS.vg, nvgRGBA(100,0,0, 200))
    nvgFill(BS.vg)
    -- 血条前景（低血时强制红色，正常时绿→红渐变）
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, ship.x-12, ship.y-16, math.floor(24*hp), 4)
    if isLowHp then
        nvgFillColor(BS.vg, nvgRGBA(255, 30, 30, hpAlpha))
    else
        local hpR = math.floor(255*(1-hp))
        local hpG = math.floor(255*hp)
        nvgFillColor(BS.vg, nvgRGBA(hpR, hpG, 0, hpAlpha))
    end
    nvgFill(BS.vg)

    -- P0-3: Boss 血条阶段分割线 + 小圆圈标记
    if ship.isBoss and ship.bossPhases then
        local barX = ship.x - 12
        local barY = ship.y - 16
        local barW = 24
        local barH = 4
        local phases = ship.bossPhases
        local prevX = barX + barW
        for i = #phases, 2, -1 do
            local threshold = phases[i].hpThreshold or 0
            local segX = barX + barW * (1 - threshold)
            if segX > barX and segX < prevX then
                nvgBeginPath(BS.vg)
                nvgMoveTo(BS.vg, segX, barY - 1)
                nvgLineTo(BS.vg, segX, barY + barH + 1)
                nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 50, 220))
                nvgStrokeWidth(BS.vg, 1.2)
                nvgStroke(BS.vg)
                nvgBeginPath(BS.vg)
                nvgCircle(BS.vg, segX, barY + barH / 2, 1.6)
                nvgFillColor(BS.vg, nvgRGBA(255, 220, 80, 200))
                nvgFill(BS.vg)
                prevX = segX
            end
        end
        -- 当前阶段标签（血条左侧小字）
        if ship.bossPhaseIndex then
            local phaseName = phases[ship.bossPhaseIndex] and phases[ship.bossPhaseIndex].name or ""
            if phaseName ~= "" then
                nvgFontSize(BS.vg, 7)
                nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(BS.vg, nvgRGBA(255, 180, 60, 230))
                nvgText(BS.vg, barX - 2, barY + barH / 2, "[" .. phaseName .. "]")
            end
        end
    end

    -- 护盾叠层：技能4"护盾强化"激活时，血条右侧追加 2px 蓝色细条
    if BS.BattleSkills.IsActive(4) then
        local shieldW = math.max(2, math.floor(24 * hp))
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, ship.x-12, ship.y-16, shieldW, 2)
        nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, 180))
        nvgFill(BS.vg)
    end

    -- 舰船图片渲染
    nvgSave(BS.vg)
    nvgTranslate(BS.vg, ship.x, ship.y)
    local angle = 0
    if math.abs(ship.vx) > 0.01 or math.abs(ship.vy) > 0.01 then
        angle = math.atan(ship.vy, ship.vx)
    elseif ship.team == "enemy" then
        angle = math.pi
    end
    nvgRotate(BS.vg, angle)

    local scale = 1.0
    if ship.stype == "SCOUT"         then scale = 0.85 end
    if ship.stype == "DESTROYER"     then scale = 1.4  end
    if ship.stype == "BATTLECRUISER" then scale = 1.8  end
    if ship.stype == "MINER"         then scale = 1.1  end
    if ship.stype == "ENGINEER"      then scale = 1.0  end
    if ship.stype == "EXPLORER"      then scale = 1.0  end
    if ship.stype == "CARRIER"       then scale = 2.5  end
    if ship.stype == "INTERCEPTOR"   then scale = 0.75 end

    local imgHandle = BS.shipImages[ship.stype]
    if imgHandle and imgHandle >= 0 then
        -- 用 nvgImagePattern 渲染纹理
        local half = 18 * scale
        -- 敌方舰船叠加红色调
        if ship.team == "enemy" then
            nvgGlobalAlpha(BS.vg, 0.85)
        end
        local paint = nvgImagePattern(BS.vg, -half, -half, half*2, half*2, 0, imgHandle, 1.0)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, -half, -half, half*2, half*2)
        nvgFillPaint(BS.vg, paint)
        nvgFill(BS.vg)
        -- 敌方叠加半透明红色蒙版
        if ship.team == "enemy" then
            nvgBeginPath(BS.vg)
            nvgRect(BS.vg, -half, -half, half*2, half*2)
            nvgFillColor(BS.vg, nvgRGBA(200, 30, 30, 80))
            nvgFill(BS.vg)
            nvgGlobalAlpha(BS.vg, 1.0)
        end
        -- P2-3: 我方舰队涂装色调叠加
        if ship.team == "player" then
            local lc = BS.LiverySystem.GetBattleColors()
            if lc and lc.primary then
                nvgBeginPath(BS.vg)
                nvgRect(BS.vg, -half, -half, half*2, half*2)
                nvgFillColor(BS.vg, nvgRGBA(lc.primary[1], lc.primary[2], lc.primary[3], 50))
                nvgFill(BS.vg)
            end
        end
    else
        -- 纹理未加载时回退到三角形
        local c = ship.color
        if ship.team == "enemy" then c = {255,60,60} end
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg,  12*scale,  0)
        nvgLineTo(BS.vg, -8*scale,  -8*scale)
        nvgLineTo(BS.vg, -5*scale,   0)
        nvgLineTo(BS.vg, -8*scale,   8*scale)
        nvgClosePath(BS.vg)
        nvgFillColor(BS.vg, nvgRGBA(c[1],c[2],c[3], 230))
        nvgFill(BS.vg)
    end

    -- 受击闪白叠加（transform 空间内，与舰船同步）
    if ship.hitFlash and ship.hitFlash > 0 then
        local flashAlpha = math.floor(ship.hitFlash * 200)
        local half = 18 * scale + 2
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, -half, -half, half*2, half*2)
        nvgFillColor(BS.vg, nvgRGBA(255, 255, 255, flashAlpha))
        nvgFill(BS.vg)
    end

    nvgRestore(BS.vg)

    -- 舰船类型标签（血条上方）
    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    if ship.team == "player" then
        nvgFillColor(BS.vg, nvgRGBA(120, 200, 255, 180))
    else
        nvgFillColor(BS.vg, nvgRGBA(255, 120, 120, 180))
    end
    -- Boss 时类型标签上移一格，腾出空间给 BOSS 标题
    local labelOffY = ship.isBoss and -28 or -17
    nvgText(BS.vg, ship.x, ship.y + labelOffY, SHIP_LABEL[ship.stype] or ship.stype)

    -- Boss 专属标题标签
    if ship.isBoss then
        nvgFontSize(BS.vg, 11)
        nvgFillColor(BS.vg, nvgRGBA(255, 200, 50, 230))
        nvgText(BS.vg, ship.x, ship.y - 37, "★BOSS★")
    end
end

local function drawProjectile(p)
    if p.isBig then
        -- 战列舰主炮：粗线 + 圆形弹头
        local alpha = math.floor(p.life * 1200)
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg, p.x, p.y)
        nvgLineTo(BS.vg, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(BS.vg, nvgRGBA(200,120,255, alpha))
        else
            nvgStrokeColor(BS.vg, nvgRGBA(255,140,40, alpha))
        end
        nvgStrokeWidth(BS.vg, 5)
        nvgStroke(BS.vg)
        -- 弹头圆点
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, p.tx, p.ty, 5)
        if p.team == "player" then
            nvgFillColor(BS.vg, nvgRGBA(240,180,255, alpha))
        else
            nvgFillColor(BS.vg, nvgRGBA(255,200,80, alpha))
        end
        nvgFill(BS.vg)
    else
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg, p.x, p.y)
        nvgLineTo(BS.vg, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(BS.vg, nvgRGBA(100,200,255, math.floor(p.life*1200)))
        else
            nvgStrokeColor(BS.vg, nvgRGBA(255,80,80, math.floor(p.life*1200)))
        end
        nvgStrokeWidth(BS.vg, 2)
        nvgStroke(BS.vg)
    end
end

local function drawFloatTexts()
    if #BS.floatTexts == 0 then return end
    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(BS.floatTexts) do
        local lifeFrac = ft.life / ft.maxLife
        local alpha    = math.floor(lifeFrac * 255)

        if ft.team == "combo" then
            -- 连击飘字：金黄色，放大动画
            local scale = 1.0 + (1 - lifeFrac) * 0.5
            local fs = math.floor((13 + (BS.comboCount >= 10 and 3 or 0)) * scale)
            nvgFontSize(BS.vg, fs)
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(140, 70, 0, math.floor(alpha * 0.55)))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(255, 220, 40, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "combo_reward" then
            -- P2-2: 连击 credits 奖励飘字：青绿大字，居中
            local scale = 1.0 + (1 - lifeFrac) * 0.3
            nvgFontSize(BS.vg, math.floor(16 * scale))
            -- 阴影
            nvgFillColor(BS.vg, nvgRGBA(0, 80, 60, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            -- 主色：青绿
            nvgFillColor(BS.vg, nvgRGBA(60, 255, 200, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "chain" then
            -- P3-1: CHAIN 飘字：橙色超大字 + 强缩放动画
            local scale = 1.0 + (1 - lifeFrac) * 0.7
            nvgFontSize(BS.vg, math.floor(28 * scale))
            -- 深色描边
            nvgFillColor(BS.vg, nvgRGBA(120, 50, 0, math.floor(alpha * 0.6)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            -- 橙色主体
            nvgFillColor(BS.vg, nvgRGBA(255, 160, 40, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "chain_dmg" then
            -- P1-3: 连锁 AOE 伤害数字：浅橙色小字
            nvgFontSize(BS.vg, 11)
            nvgFillColor(BS.vg, nvgRGBA(255, 200, 80, math.floor(alpha * 0.85)))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "reinforce_bonus" then
            -- P2-1: 逆境奋战奖励：绿色大字带描边
            local scale = 1.0 + (1 - lifeFrac) * 0.5
            nvgFontSize(BS.vg, math.floor(15 * scale))
            nvgFillColor(BS.vg, nvgRGBA(20, 80, 20, math.floor(alpha * 0.6)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(80, 255, 120, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        -- P1-1 被动飘字组 ===================================================
        elseif ft.team == "passive_scout" then
            -- SCOUT先敌洞察：蓝绿色中字，带描边
            local scale = 1.0 + (1 - lifeFrac) * 0.3
            nvgFontSize(BS.vg, math.floor(13 * scale))
            nvgFillColor(BS.vg, nvgRGBA(0, 60, 80, math.floor(alpha * 0.55)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(60, 220, 255, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "passive_explorer" then
            -- EXPLORER图绘先行：红色中字，带箭头感
            local scale = 1.0 + (1 - lifeFrac) * 0.4
            nvgFontSize(BS.vg, math.floor(13 * scale))
            nvgFillColor(BS.vg, nvgRGBA(100, 0, 0, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(255, 80, 80, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "passive_carrier" then
            -- CARRIER舰载机出击：青色大字，放大出现
            local scale = 1.2 + (1 - lifeFrac) * 0.5
            nvgFontSize(BS.vg, math.floor(14 * scale))
            nvgFillColor(BS.vg, nvgRGBA(0, 60, 80, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(80, 240, 255, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "pierce" then
            -- DESTROYER穿甲弹：橙黄色小字
            nvgFontSize(BS.vg, 12)
            nvgFillColor(BS.vg, nvgRGBA(80, 40, 0, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(255, 180, 40, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "block" then
            -- BATTLECRUISER格挡：灰色"格挡"文字
            local scale = 1.0 + (1 - lifeFrac) * 0.35
            nvgFontSize(BS.vg, math.floor(14 * scale))
            nvgFillColor(BS.vg, nvgRGBA(60, 60, 70, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(160, 170, 180, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "shield" then
            -- P3-1: 护盾吸收：蓝色飘字（🛡-N）
            local scale = 1.0 + (1 - lifeFrac) * 0.3
            nvgFontSize(BS.vg, math.floor(15 * scale))
            nvgFillColor(BS.vg, nvgRGBA(20, 40, 100, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(80, 160, 255, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "intercept" then
            -- INTERCEPTOR超音速：亮紫色小字，快速飘出
            nvgFontSize(BS.vg, 11)
            nvgFillColor(BS.vg, nvgRGBA(180, 100, 255, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        elseif ft.team == "heal" then
            -- ENGINEER治疗：绿色数字，向上飘
            local scale = 1.0 + (1 - lifeFrac) * 0.3
            nvgFontSize(BS.vg, math.floor(13 * scale))
            nvgFillColor(BS.vg, nvgRGBA(20, 100, 20, math.floor(alpha * 0.5)))
            nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(BS.vg, nvgRGBA(80, 255, 100, alpha))
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        else
            -- P3-1: 伤害数字精细化 — 按量级分字号/颜色
            local numVal = tonumber(ft.text:match("%-?(%d+)")) or 0
            local isBig  = numVal >= 100
            local isMed  = numVal >= 20 and not isBig
            -- 字号：小14 / 中18 / 大24，随生命周期缩放
            local baseSize = isBig and 24 or (isMed and 18 or 14)
            local scaleAnim = 1.0 + (1 - lifeFrac) * (isBig and 0.45 or (isMed and 0.25 or 0.1))
            nvgFontSize(BS.vg, math.floor(baseSize * scaleAnim))

            if ft.team == "enemy" then
                -- 暴击：金色大字放大1.5倍
                if ft.isCrit then
                    nvgFontSize(BS.vg, math.floor(baseSize * scaleAnim * 1.5))
                    nvgFillColor(BS.vg, nvgRGBA(120, 80, 0, math.floor(alpha * 0.6)))
                    nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(BS.vg, nvgRGBA(255, 210, 0, alpha))
                -- 连击期间颜色渐变（橙→黄→白循环）
                elseif BS.comboCount >= 3 then
                    local t = (BS.comboTimer / BS.COMBO_RESET_TIME) * math.pi * 4
                    local gr = math.floor(200 + 55 * math.abs(math.sin(t)))
                    local gg = math.floor(150 + 105 * math.abs(math.cos(t * 0.7)))
                    nvgFillColor(BS.vg, nvgRGBA(gr, gg, 80, alpha))
                -- 大伤害(100+)：亮白描边 + 鲜绿
                elseif isBig then
                    nvgFillColor(BS.vg, nvgRGBA(200, 255, 220, math.floor(alpha * 0.6)))
                    nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(BS.vg, nvgRGBA(0, 255, 100, alpha))
                -- 中伤害(20-99)：黄绿色
                elseif isMed then
                    nvgFillColor(BS.vg, nvgRGBA(140, 255, 80, alpha))
                -- 小伤害(<20)：浅白绿
                else
                    nvgFillColor(BS.vg, nvgRGBA(180, 240, 200, alpha))
                end
            else
                -- 命中我舰：大伤害深红描边，中橙色，小浅橙
                if isBig then
                    nvgFillColor(BS.vg, nvgRGBA(140, 20, 0, math.floor(alpha * 0.6)))
                    nvgText(BS.vg, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(BS.vg, nvgRGBA(255, 60, 30, alpha))
                elseif isMed then
                    nvgFillColor(BS.vg, nvgRGBA(255, 130, 50, alpha))
                else
                    nvgFillColor(BS.vg, nvgRGBA(230, 180, 120, alpha))
                end
            end
            nvgText(BS.vg, ft.x, ft.y, ft.text)
        end
    end
end

local function drawMoveTarget()
    if not BS.moveTarget then return end
    nvgBeginPath(BS.vg)
    nvgCircle(BS.vg, BS.moveTarget.x, BS.moveTarget.y, 10)
    nvgStrokeColor(BS.vg, nvgRGBA(50,220,120,200))
    nvgStrokeWidth(BS.vg, 2)
    nvgStroke(BS.vg)
    nvgBeginPath(BS.vg)
    nvgCircle(BS.vg, BS.moveTarget.x, BS.moveTarget.y, 5)
    nvgFillColor(BS.vg, nvgRGBA(50,220,120,150))
    nvgFill(BS.vg)
end

--- 渲染燃烧粒子（低血量舰船火焰特效）
local function drawFireParticles()
    if #BS.fireParticles == 0 then return end
    for _, p in ipairs(BS.fireParticles) do
        local alpha = math.floor(255 * (p.life / p.maxLife))
        local size  = p.size * (p.life / p.maxLife)  -- 随生命周期缩小
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, p.x, p.y, math.max(0.5, size))
        nvgFillColor(BS.vg, nvgRGBA(p.r, p.g, 0, alpha))
        nvgFill(BS.vg)
    end
end

--- 渲染爆炸粒子（舰船被摧毁时的闪光+碎片）
local function drawExplParticles()
    if #BS.explParticles == 0 then return end
    for _, ep in ipairs(BS.explParticles) do
        local frac  = ep.life / ep.maxLife
        local alpha = math.floor(frac * 255)
        if ep.ptype == "flash" then
            -- 扩张白光圆，淡出
            local r = ep.size * (2 - frac)
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, ep.x, ep.y, math.max(0.5, r))
            nvgFillColor(BS.vg, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(BS.vg)
        else
            -- 碎片：小点，收缩+淡出
            local sz = ep.size * frac
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, ep.x, ep.y, math.max(0.5, sz))
            nvgFillColor(BS.vg, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(BS.vg)
        end
    end
end

--- 渲染击中火花（细小射线状粒子）
local function drawHitSparks()
    if #BS.hitSparks == 0 then return end
    for _, sp in ipairs(BS.hitSparks) do
        local frac  = sp.life / sp.maxLife
        local alpha = math.floor(frac * 220)
        local len   = math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy) * 0.04 + 1.5
        local nx = sp.vx == 0 and 0 or sp.vx / math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy)
        local ny = sp.vy == 0 and 0 or sp.vy / math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy)
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg, sp.x - nx * len, sp.y - ny * len)
        nvgLineTo(BS.vg, sp.x + nx * len, sp.y + ny * len)
        nvgStrokeColor(BS.vg, nvgRGBA(sp.r, sp.g, sp.b, alpha))
        nvgStrokeWidth(BS.vg, math.max(0.5, frac * 1.5))
        nvgStroke(BS.vg)
    end
end

--- 渲染冲击波环（扩张光圈）
local function drawShockRings()
    if #BS.shockRings == 0 then return end
    for _, ring in ipairs(BS.shockRings) do
        if ring.radius > 0 then
            local frac  = ring.life / ring.maxLife  -- 1→0
            local alpha = math.floor(frac * 180)
            nvgBeginPath(BS.vg)
            nvgCircle(BS.vg, ring.x, ring.y, ring.radius)
            nvgStrokeColor(BS.vg, nvgRGBA(ring.r, ring.g, ring.b, alpha))
            nvgStrokeWidth(BS.vg, ring.width * frac)
            nvgStroke(BS.vg)
            -- 内层更亮的细环（增强层次感）
            if ring.radius > 6 then
                nvgBeginPath(BS.vg)
                nvgCircle(BS.vg, ring.x, ring.y, ring.radius * 0.6)
                nvgStrokeColor(BS.vg, nvgRGBA(
                    math.min(255, ring.r + 80),
                    math.min(255, ring.g + 40),
                    ring.b,
                    math.floor(frac * 100)))
                nvgStrokeWidth(BS.vg, ring.width * frac * 0.4)
                nvgStroke(BS.vg)
            end
        end
    end
end

--- 战斗中顶部波次信息 HUD

RenderEntities.drawShip          = drawShip
RenderEntities.drawProjectile    = drawProjectile
RenderEntities.drawFloatTexts    = drawFloatTexts
RenderEntities.drawMoveTarget    = drawMoveTarget
RenderEntities.drawFireParticles = drawFireParticles
RenderEntities.drawExplParticles = drawExplParticles
RenderEntities.drawHitSparks     = drawHitSparks
RenderEntities.drawShockRings    = drawShockRings

return RenderEntities
