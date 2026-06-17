---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- RenderOverlays: 覆盖层渲染 — Boss/横幅/特效/结算 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")

local RenderOverlays = {}

local function drawBossDestroyedEffect()
    if BS.bossFlashAlpha > 0 then
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)
        nvgFillColor(BS.vg, nvgRGBA(255, 240, 180, math.floor(BS.bossFlashAlpha)))
        nvgFill(BS.vg)
    end
    if BS.bossFlashTimer <= 0 then return end
    local elapsed = BS.BOSS_BANNER_DUR - BS.bossFlashTimer
    local alpha
    if elapsed < 0.25 then
        alpha = elapsed / 0.25
    elseif BS.bossFlashTimer < 0.5 then
        alpha = BS.bossFlashTimer / 0.5
    else
        alpha = 1.0
    end
    local ia = math.floor(alpha * 255)
    local cx = BS.screenW * 0.5
    local cy = BS.screenH * 0.28
    local bw, bh = 260, 44
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgFillColor(BS.vg, nvgRGBA(20, 10, 0, math.floor(ia * 0.82)))
    nvgFill(BS.vg)
    local pulse = 0.6 + 0.4 * math.abs(math.sin(BS.bossFlashTimer * 5))
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 0, math.floor(ia * pulse)))
    nvgStrokeWidth(BS.vg, 2)
    nvgStroke(BS.vg)
    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 22)
    nvgFillColor(BS.vg, nvgRGBA(60, 30, 0, math.floor(ia * 0.5)))
    nvgText(BS.vg, cx + 1, cy + 1, "★  BOSS DESTROYED  ★")
    nvgFillColor(BS.vg, nvgRGBA(255, 220, 40, ia))
    nvgText(BS.vg, cx, cy, "★  BOSS DESTROYED  ★")
end

--- 渲染烟花粒子（波次胜利特效，在 StateOverlay 之前渲染）
local function drawFireworks()
    if #BS.fwParticles == 0 then return end
    for _, p in ipairs(BS.fwParticles) do
        local frac  = p.life / p.maxLife
        local alpha = math.floor(frac * 220)
        local sz    = math.max(0.8, 3.5 * frac)
        nvgBeginPath(BS.vg)
        nvgCircle(BS.vg, p.x, p.y, sz)
        nvgFillColor(BS.vg, nvgRGBA(p.r, p.g, p.b, alpha))
        nvgFill(BS.vg)
    end
end

--- P2-3: 里程碑 Boss 通关横幅（"第N层 通关！"）
local function drawMilestoneBanner()
    if BS.milestoneFlashAlpha > 0 then
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)
        nvgFillColor(BS.vg, nvgRGBA(180, 20, 20, math.floor(BS.milestoneFlashAlpha)))
        nvgFill(BS.vg)
    end
    if BS.milestoneBannerTimer <= 0 then return end

    local elapsed = BS.MILESTONE_BANNER_DUR - BS.milestoneBannerTimer
    local alpha
    if elapsed < 0.3 then
        alpha = elapsed / 0.3
    elseif BS.milestoneBannerTimer < 0.6 then
        alpha = BS.milestoneBannerTimer / 0.6
    else
        alpha = 1.0
    end
    local ia = math.floor(alpha * 255)

    local cx = BS.screenW * 0.5
    local cy = BS.screenH * 0.38
    local bw, bh = 320, 62

    local bgPaint = nvgLinearGradient(BS.vg, cx - bw/2, cy - bh/2, cx + bw/2, cy + bh/2,
        nvgRGBA(60, 0, 0, math.floor(ia * 0.92)),
        nvgRGBA(120, 10, 10, math.floor(ia * 0.85)))
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2, cy - bh/2, bw, bh, 10)
    nvgFillPaint(BS.vg, bgPaint)
    nvgFill(BS.vg)

    local t = BS.milestoneBannerTimer
    local pulse = 0.6 + 0.4 * math.abs(math.sin(t * 4))
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2, cy - bh/2, bw, bh, 10)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 0, math.floor(ia * pulse)))
    nvgStrokeWidth(BS.vg, 2.5)
    nvgStroke(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, cx - bw/2 + 3, cy - bh/2 + 3, bw - 6, bh - 6, 8)
    nvgStrokeColor(BS.vg, nvgRGBA(255, 60, 60, math.floor(ia * pulse * 0.7)))
    nvgStrokeWidth(BS.vg, 1.5)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    local scaleAnim = 1.0 + 0.04 * math.sin(t * 6)
    local mainFontSize = math.floor(28 * scaleAnim)
    nvgFontSize(BS.vg, mainFontSize)
    nvgFillColor(BS.vg, nvgRGBA(0, 0, 0, math.floor(ia * 0.6)))
    nvgText(BS.vg, cx + 2, cy - 8, string.format("★  第 %d 层  通关！  ★", BS.milestoneRound))
    nvgFillColor(BS.vg, nvgRGBA(255, 80, 30, ia))
    nvgText(BS.vg, cx, cy - 9, string.format("★  第 %d 层  通关！  ★", BS.milestoneRound))
    nvgFillColor(BS.vg, nvgRGBA(255, 220, 50, math.floor(ia * 0.7)))
    nvgText(BS.vg, cx, cy - 10, string.format("★  第 %d 层  通关！  ★", BS.milestoneRound))

    nvgFontSize(BS.vg, 12)
    nvgFillColor(BS.vg, nvgRGBA(200, 160, 255, math.floor(ia * 0.9)))
    nvgText(BS.vg, cx, cy + 16, "里程碑击破！丰厚资源奖励已发放")
end

--- Boss波次警告横幅（BS.bossWarningTimer > 0 时显示）
local function drawBossWarning()
    if BS.bossWarningTimer <= 0 or BS.state ~= "fighting" then return end

    local alpha
    local elapsed = BS.BOSS_WARNING_DUR - BS.bossWarningTimer
    if elapsed < 0.3 then
        alpha = elapsed / 0.3
    elseif BS.bossWarningTimer < 0.5 then
        alpha = BS.bossWarningTimer / 0.5
    else
        alpha = 1.0
    end

    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)
    nvgFillColor(BS.vg, nvgRGBA(180, 10, 10, math.floor(alpha * 55)))
    nvgFill(BS.vg)

    local bannerH = 74
    local by = BS.screenH / 2 - bannerH / 2
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, by, BS.screenW, bannerH)
    nvgFillColor(BS.vg, nvgRGBA(60, 0, 0, math.floor(alpha * 220)))
    nvgFill(BS.vg)

    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, by, BS.screenW, 2)
    nvgFillColor(BS.vg, nvgRGBA(255, 50, 50, math.floor(alpha * 255)))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, by + bannerH - 2, BS.screenW, 2)
    nvgFillColor(BS.vg, nvgRGBA(255, 50, 50, math.floor(alpha * 255)))
    nvgFill(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 28)
    nvgFillColor(BS.vg, nvgRGBA(255, 200, 50, math.floor(alpha * 255)))
    nvgText(BS.vg, BS.screenW/2, by + bannerH/2 - 12, "⚠  旗舰 BOSS 来袭  ⚠")

    nvgFontSize(BS.vg, 13)
    nvgFillColor(BS.vg, nvgRGBA(255, 130, 130, math.floor(alpha * 220)))
    nvgText(BS.vg, BS.screenW/2, by + bannerH/2 + 14,
        string.format("第 %d 波 · 强化旗舰 · 护盾 + 血量 + 伤害全面增强", BS.waveNum))
end

--- P2-2: 夹击波次双入口指示箭头 + 公告横幅
local function drawPincerBanner()
    if not BS.isPincerWave or BS.state ~= "fighting" then return end

    local battleH = BS.screenH - 88

    if BS.pincerAnnounceTimer > 0 then
        local elapsed = BS.PINCER_ANNOUNCE_DUR - BS.pincerAnnounceTimer
        local alpha
        if elapsed < 0.25 then
            alpha = elapsed / 0.25
        elseif BS.pincerAnnounceTimer < 0.4 then
            alpha = BS.pincerAnnounceTimer / 0.4
        else
            alpha = 1.0
        end
        local a = math.floor(alpha * 255)

        local bannerH = 60
        local by = BS.screenH / 2 - bannerH / 2
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, bannerH)
        nvgFillColor(BS.vg, nvgRGBA(10, 40, 80, math.floor(alpha * 200)))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, a))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by + bannerH - 2, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, a))
        nvgFill(BS.vg)
        nvgFontFace(BS.vg, "sans")
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(BS.vg, 24)
        nvgFillColor(BS.vg, nvgRGBA(100, 210, 255, a))
        nvgText(BS.vg, BS.screenW / 2, by + bannerH / 2 - 10, "↕  上下夹击波次  ↕")
        nvgFontSize(BS.vg, 12)
        nvgFillColor(BS.vg, nvgRGBA(180, 230, 255, math.floor(alpha * 200)))
        nvgText(BS.vg, BS.screenW / 2, by + bannerH / 2 + 13, "敌军同时从右侧上下两处突入 — 分兵拦截！")
    end

    local arrowAlpha = 0.7
    if BS.pincerAnnounceTimer > 0 then arrowAlpha = 0.4 end

    local topY    = 88 + battleH * 0.15
    local bottomY = 88 + battleH * 0.85
    local ax = BS.screenW - 22
    local aw, ah = 16, 20

    local a2 = math.floor(arrowAlpha * 255)

    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, ax,      topY)
    nvgLineTo(BS.vg, ax + aw, topY - ah / 2)
    nvgLineTo(BS.vg, ax + aw, topY + ah / 2)
    nvgClosePath(BS.vg)
    nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, a2))
    nvgFill(BS.vg)

    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, ax,      bottomY)
    nvgLineTo(BS.vg, ax + aw, bottomY - ah / 2)
    nvgLineTo(BS.vg, ax + aw, bottomY + ah / 2)
    nvgClosePath(BS.vg)
    nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, a2))
    nvgFill(BS.vg)

    local zoneW = 40
    local topZoneH    = battleH * 0.30
    local bottomZoneH = battleH * 0.30
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, BS.screenW - zoneW, 88, zoneW, topZoneH)
    nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, math.floor(arrowAlpha * 30)))
    nvgFill(BS.vg)
    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, BS.screenW - zoneW, 88 + battleH - bottomZoneH, zoneW, bottomZoneH)
    nvgFillColor(BS.vg, nvgRGBA(80, 180, 255, math.floor(arrowAlpha * 30)))
    nvgFill(BS.vg)
end

--- P1-2: 宿敌遭遇公告 + 战斗结算横幅
local function drawNemesisOverlay()
    -- 1) 遭遇公告横幅
    if BS.nemesisAnnounceTimer > 0 then
        local elapsed = BS.NEMESIS_ANNOUNCE_DUR - BS.nemesisAnnounceTimer
        local alpha
        if elapsed < 0.3 then
            alpha = elapsed / 0.3
        elseif BS.nemesisAnnounceTimer < 0.5 then
            alpha = BS.nemesisAnnounceTimer / 0.5
        else
            alpha = 1.0
        end
        local a = math.floor(alpha * 255)

        local bannerH = 72
        local by = BS.screenH / 2 - bannerH / 2 - 20
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, bannerH)
        nvgFillColor(BS.vg, nvgRGBA(60, 5, 5, math.floor(alpha * 220)))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(255, 40, 40, a))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by + bannerH - 2, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(255, 40, 40, a))
        nvgFill(BS.vg)

        local captain = BS.NemesisSystem.GetActiveCaptain()
        local captainName = captain and captain.name or "未知"
        local evoLevel = captain and captain.evolutionLevel or 1
        local isFinal = evoLevel >= 5

        nvgFontFace(BS.vg, "sans")
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(BS.vg, 26)
        if isFinal then
            nvgFillColor(BS.vg, nvgRGBA(255, 220, 50, a))
            nvgText(BS.vg, BS.screenW/2, by + bannerH/2 - 12, "☠  最终决战  ☠")
        else
            nvgFillColor(BS.vg, nvgRGBA(255, 80, 80, a))
            nvgText(BS.vg, BS.screenW/2, by + bannerH/2 - 12, "⚔  宿敌来袭  ⚔")
        end
        nvgFontSize(BS.vg, 13)
        nvgFillColor(BS.vg, nvgRGBA(255, 180, 180, math.floor(alpha * 210)))
        local subtitle = string.format("%s · 进化 Lv.%d · 已适应你的战术", captainName, evoLevel)
        nvgText(BS.vg, BS.screenW/2, by + bannerH/2 + 14, subtitle)
    end

    -- 2) 战斗结算横幅
    if BS.nemesisResultTimer > 0 and BS.nemesisResult then
        local elapsed = BS.NEMESIS_RESULT_DUR - BS.nemesisResultTimer
        local alpha
        if elapsed < 0.3 then
            alpha = elapsed / 0.3
        elseif BS.nemesisResultTimer < 0.6 then
            alpha = BS.nemesisResultTimer / 0.6
        else
            alpha = 1.0
        end
        local a = math.floor(alpha * 255)

        local bannerH = 64
        local by = BS.screenH / 2 - bannerH / 2
        local isWin = (BS.state == "win" or BS.state == "idle")

        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, bannerH)
        if isWin then
            nvgFillColor(BS.vg, nvgRGBA(40, 35, 5, math.floor(alpha * 220)))
        else
            nvgFillColor(BS.vg, nvgRGBA(50, 5, 10, math.floor(alpha * 220)))
        end
        nvgFill(BS.vg)
        local borderR, borderG, borderB = 255, 200, 50
        if not isWin then borderR, borderG, borderB = 180, 40, 40 end
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(borderR, borderG, borderB, a))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by + bannerH - 2, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(borderR, borderG, borderB, a))
        nvgFill(BS.vg)

        nvgFontFace(BS.vg, "sans")
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(BS.vg, 24)
        if isWin then
            nvgFillColor(BS.vg, nvgRGBA(255, 220, 80, a))
            nvgText(BS.vg, BS.screenW/2, by + bannerH/2 - 10, "✦  宿敌击破  ✦")
        else
            nvgFillColor(BS.vg, nvgRGBA(255, 100, 100, a))
            nvgText(BS.vg, BS.screenW/2, by + bannerH/2 - 10, "✗  宿敌得逞  ✗")
        end
        nvgFontSize(BS.vg, 12)
        local desc = BS.nemesisResult.taunt or (isWin and "宿敌将进化再来" or "宿敌战力增强")
        nvgFillColor(BS.vg, nvgRGBA(200, 200, 200, math.floor(alpha * 200)))
        nvgText(BS.vg, BS.screenW/2, by + bannerH/2 + 12, desc)
    end
end

--- P2-1: 星域异象通知横幅（新异象触发时中央短暂显示）
local function drawAnomalyBanner()
    if BS.anomalyNotifyTimer <= 0 or not BS.anomalyNotify then return end
    local elapsed = BS.ANOMALY_NOTIFY_DUR - BS.anomalyNotifyTimer
    local alpha
    if elapsed < 0.35 then
        alpha = elapsed / 0.35
    elseif BS.anomalyNotifyTimer < 0.5 then
        alpha = BS.anomalyNotifyTimer / 0.5
    else
        alpha = 1.0
    end
    local a = math.floor(alpha * 255)

    local bannerW, bannerH = 320, 68
    local bx = BS.screenW / 2 - bannerW / 2
    local by = BS.screenH * 0.22 - bannerH / 2
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx, by, bannerW, bannerH, 10)
    nvgFillColor(BS.vg, nvgRGBA(10, 5, 30, math.floor(alpha * 210)))
    nvgFill(BS.vg)

    local clr = BS.anomalyNotify.color or {r=180, g=100, b=255}
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, bx + 0.5, by + 0.5, bannerW - 1, bannerH - 1, 10)
    nvgStrokeColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, a))
    nvgStrokeWidth(BS.vg, 1.5)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(BS.vg, 20)
    nvgFillColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, a))
    nvgText(BS.vg, BS.screenW / 2, by + bannerH / 2 - 12,
        (BS.anomalyNotify.icon or "⚠") .. "  " .. (BS.anomalyNotify.name or "异象"))

    nvgFontSize(BS.vg, 11)
    nvgFillColor(BS.vg, nvgRGBA(200, 210, 240, math.floor(alpha * 200)))
    nvgText(BS.vg, BS.screenW / 2, by + bannerH / 2 + 12, BS.anomalyNotify.desc or "")

    nvgFontSize(BS.vg, 9)
    nvgFillColor(BS.vg, nvgRGBA(160, 170, 200, math.floor(alpha * 160)))
    nvgText(BS.vg, BS.screenW / 2, by + bannerH / 2 + 26,
        string.format("持续 %d 波", BS.anomalyNotify.duration or 1))
end

--- P2-1: 星域异象 HUD 指示器（左上角环境HUD下方，活跃异象时常驻）
local function drawAnomalyHUD()
    local active = BS.AnomalySystem.GetActive()
    if not active then return end

    local ex = 8
    local ey = 55
    local ew = 110
    local eh = 22

    local clr = active.color or {r=180, g=100, b=255}

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, ex, ey, ew, eh, 5)
    nvgFillColor(BS.vg, nvgRGBA(10, 5, 25, 175))
    nvgFill(BS.vg)

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, ex + 0.5, ey + 0.5, ew - 1, eh - 1, 5)
    nvgStrokeColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, 130))
    nvgStrokeWidth(BS.vg, 0.8)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 10)
    nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, 220))
    local remaining = active.remainWaves or 0
    nvgText(BS.vg, ex + 5, ey + eh / 2,
        (active.icon or "⚠") .. " " .. (active.name or "异象") .. " (" .. remaining .. "波)")
end

--- P2-1: 增援预警横幅（3秒倒计时期间显示）
local function drawReinforcementWarning()
    if BS.state ~= "fighting" then return end
    if BS.RF.warning > 0 and not BS.RF.spawned then
        local frac   = BS.RF.warning / BS.RF.WARN_DUR
        local alpha
        local elapsed = BS.RF.WARN_DUR - BS.RF.warning
        if elapsed < 0.3 then
            alpha = elapsed / 0.3
        elseif BS.RF.warning < 0.3 then
            alpha = BS.RF.warning / 0.3
        else
            alpha = 1.0
        end
        local pulse = 0.75 + 0.25 * math.abs(math.sin(BS.RF.warning * 5))
        local a = math.floor(alpha * pulse * 255)

        local bannerH = 52
        local by = BS.screenH * 0.5 - bannerH * 0.5

        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, bannerH)
        nvgFillColor(BS.vg, nvgRGBA(60, 0, 0, math.floor(alpha * pulse * 200)))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(255, 60, 60, a))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, by + bannerH - 2, BS.screenW, 2)
        nvgFillColor(BS.vg, nvgRGBA(255, 60, 60, a))
        nvgFill(BS.vg)

        nvgFontFace(BS.vg, "sans")
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

        nvgFontSize(BS.vg, 22)
        nvgFillColor(BS.vg, nvgRGBA(255, 80, 80, a))
        nvgText(BS.vg, BS.screenW * 0.5, by + bannerH * 0.5 - 9, "⚠  海盗援军来袭  ⚠")

        nvgFontSize(BS.vg, 11)
        nvgFillColor(BS.vg, nvgRGBA(255, 160, 160, math.floor(alpha * 200)))
        nvgText(BS.vg, BS.screenW * 0.5, by + bannerH * 0.5 + 12,
            string.format("%.1f 秒后援舰抵达 — 全歼可获逆境奖励！", BS.RF.warning))
    end

    if BS.RF.spawned and not BS.RF.defeated and BS.RF.remain > 0 then
        local bx = BS.screenW - 90
        local by2 = BS.screenH * 0.5 - 16
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx, by2, 82, 32, 5)
        nvgFillColor(BS.vg, nvgRGBA(40, 0, 0, 200))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx + 0.5, by2 + 0.5, 81, 31, 5)
        nvgStrokeColor(BS.vg, nvgRGBA(255, 80, 80, 160))
        nvgStrokeWidth(BS.vg, 1)
        nvgStroke(BS.vg)

        nvgFontFace(BS.vg, "sans")
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(BS.vg, 11)
        nvgFillColor(BS.vg, nvgRGBA(255, 100, 100, 230))
        nvgText(BS.vg, bx + 41, by2 + 11, "⚠ 援军")
        nvgFontSize(BS.vg, 14)
        nvgFillColor(BS.vg, nvgRGBA(255, 200, 200, 230))
        nvgText(BS.vg, bx + 41, by2 + 24, string.format("剩余 %d 艘", BS.RF.remain))
    end
end

-- P1-1: 波次战斗摘要弹窗（显示在 win 阶段右侧）
local function drawWaveSummary()
    if not BS.waveSummary then return end
    if BS.state ~= "win" then return end

    local s   = BS.waveSummary
    local t   = BS.stateTimer
    local fadeIn  = math.min(1, t / 0.4)
    local fadeOut = math.max(0, 1 - math.max(0, t - (BS.WAVE_GAP - 0.5)) / 0.4)
    local ease    = fadeIn * fadeOut
    if ease <= 0 then return end

    local a = math.floor(ease * 255)
    local panW = 190
    local hasMvp = (s.mvp ~= nil and s.mvp.dmg > 0)
    local panH = hasMvp and 176 or 152
    local margin = 18
    local px = BS.screenW - panW - margin
    local py = BS.screenH / 2 - panH / 2

    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, px, py, panW, panH, 10)
    nvgFillColor(BS.vg, nvgRGBA(4, 12, 28, math.floor(a * 0.88)))
    nvgFill(BS.vg)
    local bc = ({
        [1] = {180, 100, 60},
        [2] = {60, 160, 255},
        [3] = {255, 210, 40},
    })[s.stars] or {80, 120, 200}
    nvgBeginPath(BS.vg)
    nvgRoundedRect(BS.vg, px + 0.5, py + 0.5, panW - 1, panH - 1, 10)
    nvgStrokeColor(BS.vg, nvgRGBA(bc[1], bc[2], bc[3], math.floor(a * 0.7)))
    nvgStrokeWidth(BS.vg, 1.5)
    nvgStroke(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    nvgFontSize(BS.vg, 11)
    nvgFillColor(BS.vg, nvgRGBA(bc[1], bc[2], bc[3], a))
    nvgText(BS.vg, px + panW/2, py + 14, string.format("— 第 %d 波 战报 —", s.wave))

    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, px + 12, py + 24)
    nvgLineTo(BS.vg, px + panW - 12, py + 24)
    nvgStrokeColor(BS.vg, nvgRGBA(bc[1], bc[2], bc[3], math.floor(a * 0.4)))
    nvgStrokeWidth(BS.vg, 0.5)
    nvgStroke(BS.vg)

    local rows = {
        { icon = "🎯", label = "击落敌舰",  val = string.format("%d 艘",  s.kills)    },
        { icon = "⚔️",  label = "最高连击",  val = s.maxCombo > 0 and string.format("x%d", s.maxCombo) or "—" },
        { icon = "💥", label = "造成伤害",  val = s.dmg >= 1000 and string.format("%.1fK", s.dmg/1000) or tostring(s.dmg) },
        { icon = "🚀", label = "损失舰船",  val = s.lost == 0 and "无损！" or string.format("%d 艘", s.lost) },
    }

    local rowH   = 22
    local startY = py + 34
    for i, row in ipairs(rows) do
        local ry = startY + (i - 1) * rowH
        nvgFontSize(BS.vg, 10)
        nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(130, 160, 200, a))
        nvgText(BS.vg, px + 14, ry + rowH/2, row.icon .. " " .. row.label)
        nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local vc = (row.label == "损失舰船" and s.lost == 0) and {80, 255, 120}
                or (row.label == "损失舰船" and s.lost > 0)  and {255, 160, 60}
                or {220, 230, 255}
        nvgFillColor(BS.vg, nvgRGBA(vc[1], vc[2], vc[3], a))
        nvgText(BS.vg, px + panW - 14, ry + rowH/2, row.val)
    end

    local afterRowsY = startY + #rows * rowH + 2
    if hasMvp then
        nvgBeginPath(BS.vg)
        nvgMoveTo(BS.vg, px + 12, afterRowsY)
        nvgLineTo(BS.vg, px + panW - 12, afterRowsY)
        nvgStrokeColor(BS.vg, nvgRGBA(200, 160, 40, math.floor(a * 0.35)))
        nvgStrokeWidth(BS.vg, 0.5)
        nvgStroke(BS.vg)

        local mvpY  = afterRowsY + 11
        local m     = s.mvp
        local SHIP_NAMES = {
            FIGHTER="战斗机", DESTROYER="驱逐舰", BATTLECRUISER="战列舰",
            CARRIER="航母", INTERCEPTOR="拦截机",
        }
        local stypeName = SHIP_NAMES[m.stype] or m.stype
        local dmgStr    = m.dmg >= 1000
            and string.format("%.1fK", m.dmg / 1000)
            or  tostring(m.dmg)
        nvgFontSize(BS.vg, 9.5)
        nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(255, 210, 50, a))
        nvgText(BS.vg, px + 14, mvpY, "👑 MVP  " .. stypeName)
        nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(255, 230, 120, a))
        nvgText(BS.vg, px + panW - 14, mvpY,
            string.format("%s  ×%d", dmgStr, m.kills))
    end

    local sepY = afterRowsY + (hasMvp and 24 or 0) + 2
    nvgBeginPath(BS.vg)
    nvgMoveTo(BS.vg, px + 12, sepY)
    nvgLineTo(BS.vg, px + panW - 12, sepY)
    nvgStrokeColor(BS.vg, nvgRGBA(60, 100, 180, math.floor(a * 0.4)))
    nvgStrokeWidth(BS.vg, 0.5)
    nvgStroke(BS.vg)

    nvgFontSize(BS.vg, 9)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(BS.vg, nvgRGBA(100, 200, 120, math.floor(a * 0.85)))
    nvgText(BS.vg, px + panW/2, sepY + 11,
        string.format("奖励  金属+%d  能源+%d  核能+%d", s.mReward, s.eReward, s.cReward))
end

local function drawStateOverlay()
    if BS.state == "fighting" then return end

    nvgBeginPath(BS.vg)
    nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)
    nvgFillColor(BS.vg, nvgRGBA(0,0,0,140))
    nvgFill(BS.vg)

    nvgFontFace(BS.vg, "sans")
    nvgFontSize(BS.vg, 48)
    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if BS.state == "win" then
        nvgFillColor(BS.vg, nvgRGBA(50,255,100,255))
        nvgText(BS.vg, BS.screenW/2, BS.screenH/2 - 20, "胜 利")

        -- P3-3: 星级评分（3颗星依次亮起）
        if BS.currentWaveStar > 0 then
            local starCount  = 3
            local starR      = 18
            local starGap    = 52
            local totalW     = (starCount - 1) * starGap
            local cx         = BS.screenW / 2
            local sy         = BS.screenH / 2 + 8

            local STAR_DELAY = 0.22

            for si = 1, starCount do
                local earned  = si <= BS.currentWaveStar
                local appear  = BS.starAnim - (si - 1) * STAR_DELAY
                local prog    = math.max(0, math.min(1, appear / 0.25))
                local scale   = prog < 1 and (1.2 - 0.2 * prog) or 1.0
                local sx      = cx - totalW / 2 + (si - 1) * starGap

                if prog <= 0 then
                    nvgBeginPath(BS.vg)
                    local pts = 5
                    for pi = 0, pts * 2 - 1 do
                        local a  = pi * math.pi / pts - math.pi / 2
                        local r  = (pi % 2 == 0) and starR or starR * 0.42
                        local px = sx + math.cos(a) * r
                        local py = sy + math.sin(a) * r
                        if pi == 0 then nvgMoveTo(BS.vg, px, py)
                        else           nvgLineTo(BS.vg, px, py) end
                    end
                    nvgClosePath(BS.vg)
                    nvgStrokeColor(BS.vg, nvgRGBA(80, 80, 80, 120))
                    nvgStrokeWidth(BS.vg, 1.5); nvgStroke(BS.vg)
                else
                    local sr = starR * scale
                    nvgBeginPath(BS.vg)
                    local pts = 5
                    for pi = 0, pts * 2 - 1 do
                        local a  = pi * math.pi / pts - math.pi / 2
                        local r  = (pi % 2 == 0) and sr or sr * 0.42
                        local px = sx + math.cos(a) * r
                        local py = sy + math.sin(a) * r
                        if pi == 0 then nvgMoveTo(BS.vg, px, py)
                        else           nvgLineTo(BS.vg, px, py) end
                    end
                    nvgClosePath(BS.vg)

                    if earned then
                        local pulse = 0.85 + 0.15 * math.abs(math.sin(BS.starAnim * 2.4 + si * 1.1))
                        local glowR = sr * 1.6 * pulse
                        nvgFillColor(BS.vg, nvgRGBA(255, 220, 60, math.floor(40 * pulse)))
                        nvgFill(BS.vg)
                        -- 重绘实心
                        nvgBeginPath(BS.vg)
                        for pi = 0, pts * 2 - 1 do
                            local a  = pi * math.pi / pts - math.pi / 2
                            local r  = (pi % 2 == 0) and sr or sr * 0.42
                            local px = sx + math.cos(a) * r
                            local py = sy + math.sin(a) * r
                            if pi == 0 then nvgMoveTo(BS.vg, px, py)
                            else           nvgLineTo(BS.vg, px, py) end
                        end
                        nvgClosePath(BS.vg)
                        nvgFillColor(BS.vg, nvgRGBA(255, 210, 40, 255))
                        nvgFill(BS.vg)
                        nvgStrokeColor(BS.vg, nvgRGBA(255, 255, 180, math.floor(180 * pulse)))
                        nvgStrokeWidth(BS.vg, 1.5); nvgStroke(BS.vg)
                        nvgBeginPath(BS.vg)
                        nvgCircle(BS.vg, sx, sy - sr * 0.15, sr * 0.18)
                        nvgFillColor(BS.vg, nvgRGBA(255, 255, 220, math.floor(200 * pulse)))
                        nvgFill(BS.vg)
                        if glowR > 10 then
                            for ri = 0, 3 do
                                local ra = ri * math.pi / 2 + BS.starAnim * 0.4
                                nvgBeginPath(BS.vg)
                                nvgMoveTo(BS.vg, sx + math.cos(ra) * sr * 0.6, sy + math.sin(ra) * sr * 0.6)
                                nvgLineTo(BS.vg, sx + math.cos(ra) * glowR * 0.5, sy + math.sin(ra) * glowR * 0.5)
                                nvgStrokeColor(BS.vg, nvgRGBA(255, 240, 120, math.floor(80 * pulse)))
                                nvgStrokeWidth(BS.vg, 1.0); nvgStroke(BS.vg)
                            end
                        end
                    else
                        nvgFillColor(BS.vg, nvgRGBA(60, 60, 60, 160))
                        nvgFill(BS.vg)
                        nvgStrokeColor(BS.vg, nvgRGBA(120, 120, 120, 140))
                        nvgStrokeWidth(BS.vg, 1.5); nvgStroke(BS.vg)
                    end
                end
            end

            local labelT = { [1]="惨 胜", [2]="良 好", [3]="完 美" }
            local labelC = {
                [1] = {200, 120, 80},
                [2] = {140, 210, 255},
                [3] = {255, 220, 60},
            }
            local allShown = BS.starAnim >= (BS.currentWaveStar - 1) * STAR_DELAY + 0.4
            if allShown then
                local lc = labelC[BS.currentWaveStar] or {200,200,200}
                local labelAlpha = math.min(255, math.floor((BS.starAnim - 0.6) / 0.3 * 255))
                if labelAlpha > 0 then
                    nvgFontSize(BS.vg, 12)
                    nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(BS.vg, nvgRGBA(lc[1], lc[2], lc[3], math.min(255, labelAlpha)))
                    nvgText(BS.vg, BS.screenW/2, BS.screenH/2 + 8 + starR + 14, labelT[BS.currentWaveStar] or "")
                end
            end
        end

        -- ── P2-3: 顶部备战倒计时条 ──
        local gap = BS.WAVE_GAP
        local remaining = math.max(0, gap - BS.waveGapTimer)
        local pct = math.min(1, BS.waveGapTimer / gap)
        local barW = math.min(BS.screenW - 40, 340)
        local barH = 18
        local bx = BS.screenW / 2 - barW / 2
        local by = 96

        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx, by, barW, barH, 9)
        nvgFillColor(BS.vg, nvgRGBA(10, 20, 40, 200))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx, by, barW, barH, 9)
        nvgStrokeColor(BS.vg, nvgRGBA(80, 180, 255, 100))
        nvgStrokeWidth(BS.vg, 1)
        nvgStroke(BS.vg)

        local fillW = barW * (1.0 - pct)
        if fillW > 2 then
            nvgBeginPath(BS.vg)
            nvgRoundedRect(BS.vg, bx, by, fillW, barH, 9)
            nvgFillColor(BS.vg, nvgRGBA(60, 200, 255, 160))
            nvgFill(BS.vg)
        end

        nvgFontSize(BS.vg, 12)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(220, 240, 255, 240))
        local prepLabel = string.format("🔧 备战中 %ds…", math.ceil(remaining))
        nvgText(BS.vg, BS.screenW / 2, by + barH / 2, prepLabel)

        nvgFontSize(BS.vg, 9)
        nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(180, 200, 220, 160))
        nvgText(BS.vg, bx + barW - 8, by + barH / 2, "[SPACE 跳过]")

        nvgFontSize(BS.vg, 11)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(160, 220, 200, 180))
        nvgText(BS.vg, BS.screenW / 2, by + barH + 12,
            string.format("即将进入第 %d 波", BS.waveNum + 1))

        -- ── P2-3: 左下角舰队HP状态网格 ──
        do
            local gridX = 16
            local gridY = BS.screenH - 80
            local cellW, cellH = 14, 14
            local gap2 = 2
            local cols = math.min(12, math.max(6, math.floor((BS.screenW * 0.35) / (cellW + gap2))))
            local count = #BS.playerFleet
            if count > 0 then
                nvgFontSize(BS.vg, 9)
                nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
                nvgFillColor(BS.vg, nvgRGBA(120, 200, 160, 180))
                nvgText(BS.vg, gridX, gridY - 4,
                    string.format("我方舰队  %d/%d", count, BS.initialPlayerCount or count))
                for i, ship in ipairs(BS.playerFleet) do
                    local col = (i - 1) % cols
                    local row = math.floor((i - 1) / cols)
                    local cx = gridX + col * (cellW + gap2)
                    local cy = gridY + row * (cellH + gap2)
                    local hpPct = math.max(0, ship.health / ship.maxHealth)
                    nvgBeginPath(BS.vg)
                    nvgRoundedRect(BS.vg, cx, cy, cellW, cellH, 2)
                    nvgFillColor(BS.vg, nvgRGBA(20, 30, 50, 180))
                    nvgFill(BS.vg)
                    local fillH = math.max(1, math.floor(cellH * hpPct))
                    local r, g, b = ship.color[1] or 100, ship.color[2] or 200, ship.color[3] or 150
                    if hpPct < 0.3 then r, g, b = 255, 60, 60 end
                    nvgBeginPath(BS.vg)
                    nvgRoundedRect(BS.vg, cx, cy + (cellH - fillH), cellW, fillH, 2)
                    nvgFillColor(BS.vg, nvgRGBA(r, g, b, 180))
                    nvgFill(BS.vg)
                    nvgBeginPath(BS.vg)
                    nvgRoundedRect(BS.vg, cx + 0.5, cy + 0.5, cellW - 1, cellH - 1, 2)
                    nvgStrokeColor(BS.vg, nvgRGBA(60, 120, 180, 80))
                    nvgStrokeWidth(BS.vg, 0.5)
                    nvgStroke(BS.vg)
                end
            end
        end

        -- ── 波次预报面板（右下角）──
        local forecast = BS.getNextWavePreview(BS.waveNum + 1)
        if forecast and #forecast.groups > 0 then
            local panW  = math.min(BS.screenW * 0.42, 280)
            local itemH = 22
            local padV  = 10
            local titleH = 18
            local panH  = titleH + padV + #forecast.groups * itemH + padV
            local panX  = BS.screenW - panW - 16
            local panY  = BS.screenH - panH - 16

            nvgBeginPath(BS.vg)
            nvgRoundedRect(BS.vg, panX, panY, panW, panH, 8)
            nvgFillColor(BS.vg, nvgRGBA(5, 15, 30, 210))
            nvgFill(BS.vg)
            nvgBeginPath(BS.vg)
            nvgRoundedRect(BS.vg, panX + 0.5, panY + 0.5, panW - 1, panH - 1, 8)
            nvgStrokeColor(BS.vg, nvgRGBA(60, 140, 255, 100))
            nvgStrokeWidth(BS.vg, 1)
            nvgStroke(BS.vg)

            nvgFontSize(BS.vg, 11)
            nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(BS.vg, nvgRGBA(120, 180, 255, 200))
            nvgText(BS.vg, panX + panW / 2, panY + titleH / 2 + 2,
                string.format("— 第 %d 波 预报（共约 %d 艘）—", BS.waveNum + 1, forecast.total))

            local sepY = panY + titleH + 2
            nvgBeginPath(BS.vg)
            nvgMoveTo(BS.vg, panX + 12, sepY)
            nvgLineTo(BS.vg, panX + panW - 12, sepY)
            nvgStrokeColor(BS.vg, nvgRGBA(60, 100, 180, 80))
            nvgStrokeWidth(BS.vg, 0.5)
            nvgStroke(BS.vg)

            local rowY = sepY + padV
            local SHIP_COLOR = {
                SCOUT         = {r=100, g=180, b=255},
                FRIGATE       = {r=80,  g=220, b=140},
                DESTROYER     = {r=255, g=180, b=80 },
                BATTLECRUISER = {r=255, g=100, b=80 },
                INTERCEPTOR   = {r=200, g=100, b=255},
                CARRIER       = {r=255, g=60,  b=60 },
            }

            for _, grp in ipairs(forecast.groups) do
                local clr = SHIP_COLOR[grp.stype] or {r=200,g=200,b=200}
                local isBoss = grp.isBoss == true

                local dotX = panX + 18
                nvgBeginPath(BS.vg)
                nvgCircle(BS.vg, dotX, rowY + itemH / 2, 4)
                nvgFillColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 255 or 200))
                nvgFill(BS.vg)
                if isBoss then
                    nvgBeginPath(BS.vg)
                    nvgCircle(BS.vg, dotX, rowY + itemH / 2, 5)
                    nvgStrokeColor(BS.vg, nvgRGBA(255, 200, 60, 220))
                    nvgStrokeWidth(BS.vg, 1)
                    nvgStroke(BS.vg)
                end

                nvgFontSize(BS.vg, 11)
                nvgTextAlign(BS.vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if isBoss then
                    nvgFillColor(BS.vg, nvgRGBA(255, 200, 60, 240))
                else
                    nvgFillColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, 220))
                end
                local label = isBoss and ("★ " .. grp.name) or grp.name
                nvgText(BS.vg, dotX + 12, rowY + itemH / 2, label)

                local barMaxW = panW * 0.35
                local barFrac = math.min(1, grp.count / math.max(1, forecast.total))
                local barFillW = math.max(4, math.floor(barMaxW * barFrac))
                local barX = panX + panW - 14 - barMaxW
                local barY = rowY + itemH / 2 - 4
                nvgBeginPath(BS.vg)
                nvgRoundedRect(BS.vg, barX, barY, barMaxW, 8, 3)
                nvgFillColor(BS.vg, nvgRGBA(20, 30, 50, 180))
                nvgFill(BS.vg)
                nvgBeginPath(BS.vg)
                nvgRoundedRect(BS.vg, barX, barY, barFillW, 8, 3)
                nvgFillColor(BS.vg, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 220 or 160))
                nvgFill(BS.vg)
                nvgFontSize(BS.vg, 10)
                nvgTextAlign(BS.vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(BS.vg, nvgRGBA(200, 220, 255, 200))
                nvgText(BS.vg, panX + panW - 8, rowY + itemH / 2,
                    string.format("×%d", grp.count))

                rowY = rowY + itemH
            end
        end
    else
        nvgFillColor(BS.vg, nvgRGBA(255,50,50,255))
        nvgText(BS.vg, BS.screenW/2, BS.screenH/2 - 10, "战 败")

        local btnW, btnH = 130, 36
        local gap        = 20
        local totalW     = btnW * 2 + gap
        local bx1        = BS.screenW/2 - totalW/2
        local bx2        = bx1 + btnW + gap
        local by         = BS.screenH/2 + 28

        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx1, by, btnW, btnH, 6)
        nvgFillColor(BS.vg, nvgRGBA(60,140,255,220))
        nvgFill(BS.vg)
        nvgBeginPath(BS.vg)
        nvgRoundedRect(BS.vg, bx2, by, btnW, btnH, 6)
        nvgFillColor(BS.vg, nvgRGBA(80,80,80,200))
        nvgFill(BS.vg)

        nvgFontSize(BS.vg, 15)
        nvgTextAlign(BS.vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(BS.vg, nvgRGBA(255,255,255,240))
        nvgText(BS.vg, bx1 + btnW/2, by + btnH/2, "[2] 重新战斗")
        nvgText(BS.vg, bx2 + btnW/2, by + btnH/2, "[1] 返回星图")

        BS.loseBtn1 = { x=bx1, y=by, w=btnW, h=btnH }
        BS.loseBtn2 = { x=bx2, y=by, w=btnW, h=btnH }
    end
end

-- ============================================================================
-- 公开渲染入口
-- ============================================================================

--- BattleRender.Render() — 在 NanoVGRender 事件中由外部调用

RenderOverlays.drawBossDestroyedEffect   = drawBossDestroyedEffect
RenderOverlays.drawFireworks             = drawFireworks
RenderOverlays.drawMilestoneBanner       = drawMilestoneBanner
RenderOverlays.drawBossWarning           = drawBossWarning
RenderOverlays.drawPincerBanner          = drawPincerBanner
RenderOverlays.drawNemesisOverlay        = drawNemesisOverlay
RenderOverlays.drawAnomalyBanner         = drawAnomalyBanner
RenderOverlays.drawAnomalyHUD            = drawAnomalyHUD
RenderOverlays.drawReinforcementWarning  = drawReinforcementWarning
RenderOverlays.drawWaveSummary           = drawWaveSummary
RenderOverlays.drawStateOverlay          = drawStateOverlay

return RenderOverlays
