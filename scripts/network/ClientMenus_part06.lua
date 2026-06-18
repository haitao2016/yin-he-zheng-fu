-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.RenderMainMenu(vg, sw, sh, ctx)
    local hover          = ctx.hover
    local hasSave        = ctx.hasSave
    local t              = ctx.menuT or 0   -- P3-3: 时间驱动粒子
    local evPoints       = ctx.evolutionPoints  or 0
    local evUnlocked     = ctx.unlockedCount    or 0

    -- 深空渐变背景
    local bg = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(4, 8, 24, 255), nvgRGBA(8, 18, 48, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, bg)
    nvgFill(vg)

    -- P3-3: 动态粒子背景（闪星 + 流星）
    drawParticleBackground(vg, sw, sh, t)

    -- 游戏 Logo 大标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 阴影层
    nvgFontSize(vg, 52)
    nvgFillColor(vg, nvgRGBA(30, 60, 160, 120))
    nvgText(vg, sw / 2 + 3, sh * 0.24 + 3, "银河征服")

    -- 主标题
    nvgFontSize(vg, 52)
    local titleGrad = nvgLinearGradient(vg, sw/2 - 120, sh*0.19, sw/2 + 120, sh*0.29,
        nvgRGBA(160, 200, 255, 255), nvgRGBA(80, 140, 255, 255))
    nvgBeginPath(vg)
    nvgRect(vg, sw/2 - 130, sh*0.18, 260, 80)
    nvgFillPaint(vg, titleGrad)
    nvgFill(vg)
    nvgFontSize(vg, 52)
    nvgFillColor(vg, nvgRGBA(200, 220, 255, 255))
    nvgText(vg, sw / 2, sh * 0.24, "银河征服")

    -- 副标题
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(120, 150, 210, 200))
    nvgText(vg, sw / 2, sh * 0.34, "GALACTIC CONQUEST")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, sw * 0.30, sh * 0.40)
    nvgLineTo(vg, sw * 0.70, sh * 0.40)
    nvgStrokeColor(vg, nvgRGBA(60, 90, 180, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 按钮
    local btns = ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    for _, btn in ipairs(btns) do
        local isHover   = (hover == btn.key)
        local isEnabled = btn.enabled
        local baseAlpha = isEnabled and 255 or 80
        -- P2-1: 每日挑战按钮用不同颜色主题
        local isDailyBtn  = (btn.key == "daily")
        local dailyDone   = isDailyBtn and (ctx.dailyCompleted == true)
        -- 颜色主题：every日挑战=青绿，传承=蓝，其他=蓝
        local cr1, cg1, cb1, cr2, cg2, cb2, bR, bG, bB
        if isDailyBtn then
            if dailyDone then
                cr1,cg1,cb1 = 20, 80, 40;  cr2,cg2,cb2 = 10, 50, 30
                bR,bG,bB    = 60, 180, 100
            else
                cr1,cg1,cb1 = 20, 80, 100; cr2,cg2,cb2 = 10, 55, 80
                bR,bG,bB    = 60, 200, 180
            end
        else
            cr1,cg1,cb1 = 40, 80, 180;  cr2,cg2,cb2 = 20, 50, 140
            bR,bG,bB    = 80, 130, 255
        end

        -- 按钮背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btn.x, btn.y, btn.w, btn.h, 10)
        if isEnabled then
            local btnBg = nvgLinearGradient(vg, btn.x, btn.y, btn.x, btn.y + btn.h,
                nvgRGBA(cr1, cg1, cb1, isHover and 160 or 90),
                nvgRGBA(cr2, cg2, cb2, isHover and 200 or 120))
            nvgFillPaint(vg, btnBg)
        else
            nvgFillColor(vg, nvgRGBA(30, 40, 60, 60))
        end
        nvgFill(vg)

        -- 按钮边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btn.x, btn.y, btn.w, btn.h, 10)
        nvgStrokeColor(vg, nvgRGBA(bR, bG, bB, isHover and 240 or (isEnabled and 160 or 50)))
        nvgStrokeWidth(vg, isHover and 2.0 or 1.2)
        nvgStroke(vg)

        -- 悬停光晕
        if isHover and isEnabled then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btn.x - 3, btn.y - 3, btn.w + 6, btn.h + 6, 13)
            nvgStrokeColor(vg, nvgRGBA(bR, bG, bB, 60))
            nvgStrokeWidth(vg, 5)
            nvgStroke(vg)
        end

        -- P2-1: 每日挑战按钮特殊内容
        if isDailyBtn then
            local cx_ = btn.x + btn.w / 2
            local cy_ = btn.y + btn.h / 2
            if dailyDone then
                -- 已完成：显示✔标记 + 按钮主文字
                nvgFontSize(vg, 13)
                nvgFillColor(vg, nvgRGBA(100, 230, 150, baseAlpha))
                nvgText(vg, cx_, cy_ - 7, btn.label)
                nvgFontSize(vg, 10)
                nvgFillColor(vg, nvgRGBA(80, 200, 120, 200))
                nvgText(vg, cx_, cy_ + 9, "✔ 今日已完成")
            else
                -- 未完成：显示按钮文字 + 倒计时小字
                nvgFontSize(vg, 13)
                nvgFillColor(vg, nvgRGBA(160, 240, 230, baseAlpha))
                nvgText(vg, cx_, cy_ - 7, btn.label)
                local countdown = ctx.dailyCountdown or 0
                local hrs  = math.floor(countdown / 3600)
                local mins = math.floor((countdown % 3600) / 60)
                local cdStr = string.format("%02d:%02d 后刷新", hrs, mins)
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(100, 180, 180, 180))
                nvgText(vg, cx_, cy_ + 9, cdStr)
            end
        else
            -- 普通按钮文字
            local fontSize = (btn.key == "new" or btn.key == "continue") and 20 or 13
            nvgFontSize(vg, fontSize)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, baseAlpha))
            nvgText(vg, btn.x + btn.w / 2, btn.y + btn.h / 2, btn.label)
        end
    end

    -- 无存档时的提示
    if not hasSave then
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(100, 110, 150, 150))
        nvgText(vg, sw / 2, sh * 0.52 + 72 + 72, "（暂无存档）")
    end

    -- P1-1: 传承按钮的积分徽章（右侧小字）
    do
        local smW    = 198
        local gap    = 6
        local totalSmW = smW * 2 + gap
        local smStartX = sw / 2 - totalSmW / 2
        local baseY  = sh * 0.52
        local btnRightEdge = smStartX + totalSmW  -- 传承按钮右边缘
        local badgeY = baseY + 152 + 20           -- 传承按钮垂直中心
        local badgeX = btnRightEdge + 6
        local badge  = string.format("✦%d", evPoints)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 215, 80, 220))
        nvgText(vg, badgeX, badgeY, badge)
        if evUnlocked > 0 then
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(150, 190, 255, 180))
            nvgText(vg, badgeX, badgeY + 13, string.format("%d/12", evUnlocked))
        end
    end
