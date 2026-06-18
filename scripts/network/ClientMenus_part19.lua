-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.RenderDifficultyScreen(vg, sw, sh, ctx)
    local hover            = ctx.hover
    local customDiff       = ctx.customDiff
    local customDiffSlider = ctx.customDiffSlider
    local t                = ctx.menuT or 0   -- P3-3: 时间驱动粒子

    -- 深空背景
    local bg = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(5, 10, 30, 255), nvgRGBA(10, 20, 50, 255))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, bg)
    nvgFill(vg)

    -- P3-3: 动态粒子背景（闪星 + 流星）
    drawParticleBackground(vg, sw, sh, t)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 38)
    nvgFillColor(vg, nvgRGBA(200, 220, 255, 255))
    nvgText(vg, sw / 2, sh * 0.20, "银河征服")
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(140, 160, 200, 200))
    nvgText(vg, sw / 2, sh * 0.28, "选择难度")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, sw * 0.25, sh * 0.33)
    nvgLineTo(vg, sw * 0.75, sh * 0.33)
    nvgStrokeColor(vg, nvgRGBA(80, 100, 160, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- P1-1: 昵称输入框
    do
        local playerName    = ctx.playerName    or "指挥官"
        local isActive      = ctx.nicknameActive or false
        local cursorT       = ctx.nicknameCursorT or 0
        local isHover       = ctx.nicknameHover  or false
        local ni = ClientMenus.GetNicknameInputLayout(sw, sh)

        -- 标签
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(140, 160, 200, 200))
        nvgText(vg, sw / 2, ni.y - 13, "指挥官昵称")

        -- 输入框背景
        local borderA = isActive and 255 or (isHover and 200 or 130)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ni.x, ni.y, ni.w, ni.h, 8)
        local inputBg = nvgLinearGradient(vg, ni.x, ni.y, ni.x, ni.y + ni.h,
            nvgRGBA(20, 30, 60, isActive and 200 or 140),
            nvgRGBA(10, 18, 45, isActive and 220 or 160))
        nvgFillPaint(vg, inputBg)
        nvgFill(vg)

        -- 输入框边框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ni.x, ni.y, ni.w, ni.h, 8)
        nvgStrokeColor(vg, isActive
            and nvgRGBA(80, 160, 255, borderA)
            or  nvgRGBA(60, 90, 160, borderA))
        nvgStrokeWidth(vg, isActive and 2.0 or 1.2)
        nvgStroke(vg)

        -- 激活时外发光
        if isActive then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, ni.x - 3, ni.y - 3, ni.w + 6, ni.h + 6, 11)
            nvgStrokeColor(vg, nvgRGBA(60, 140, 255, 50))
            nvgStrokeWidth(vg, 5)
            nvgStroke(vg)
        end

        -- 文字内容（加光标）
        local displayText = playerName
        if isActive then
            local showCursor = (math.floor(cursorT * 2) % 2 == 0)
            if showCursor then displayText = displayText .. "|" end
        end
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 空内容时显示占位符
        if playerName == "" then
            nvgFillColor(vg, nvgRGBA(80, 100, 150, 150))
            nvgText(vg, ni.x + ni.w / 2, ni.y + ni.h / 2, "输入昵称…")
        else
            nvgFillColor(vg, nvgRGBA(200, 220, 255, 240))
            nvgText(vg, ni.x + ni.w / 2, ni.y + ni.h / 2, displayText)
        end

        -- 右侧铅笔图标提示
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 120, 200, isHover and 200 or 120))
        nvgText(vg, ni.x + ni.w + 8, ni.y + ni.h / 2, "✏")
    end

    -- 难度按钮
    local btns = ClientMenus.GetDifficultyBtnLayout(sw, sh, ctx)
    for _, btn in ipairs(btns) do
        local cfg     = btn.cfg
        local r, g, b = cfg.color[1], cfg.color[2], cfg.color[3]
        local isHover = (hover == btn.key)
        local alpha   = isHover and 220 or 160

        nvgBeginPath(vg)
        nvgRoundedRect(vg, btn.x, btn.y, btn.w, btn.h, 12)
        local btnBg = nvgLinearGradient(vg, btn.x, btn.y, btn.x, btn.y + btn.h,
            nvgRGBA(r, g, b, isHover and 60 or 30),
            nvgRGBA(r, g, b, isHover and 90 or 50))
        nvgFillPaint(vg, btnBg)
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, btn.x, btn.y, btn.w, btn.h, 12)
        nvgStrokeColor(vg, nvgRGBA(r, g, b, alpha))
        nvgStrokeWidth(vg, isHover and 2.5 or 1.5)
        nvgStroke(vg)

        nvgFontSize(vg, 22)
        nvgFillColor(vg, nvgRGBA(r, g, b, 255))
        nvgText(vg, btn.x + btn.w / 2, btn.y + 36, cfg.label)

        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(180, 200, 230, 200))
        nvgText(vg, btn.x + btn.w / 2, btn.y + 70, cfg.desc)

        if isHover then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btn.x - 2, btn.y - 2, btn.w + 4, btn.h + 4, 14)
            nvgStrokeColor(vg, nvgRGBA(r, g, b, 80))
            nvgStrokeWidth(vg, 4)
            nvgStroke(vg)
        end
    end

    -- 自定义难度滑块面板
    if ClientMenus.GetCustomPanelVisible(ctx) then
        local p = ClientMenus.GetCustomPanelLayout(sw, sh)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, p.x, p.y, p.w, p.h, 10)
        local panelBg = nvgLinearGradient(vg, p.x, p.y, p.x, p.y + p.h,
            nvgRGBA(30, 20, 60, 220), nvgRGBA(20, 15, 45, 220))
        nvgFillPaint(vg, panelBg)
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, p.x, p.y, p.w, p.h, 10)
        nvgStrokeColor(vg, nvgRGBA(200, 180, 255, 160))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        local sliders = ClientMenus.GetCustomSliderRects(sw, sh, ctx)
        for _, sl in ipairs(sliders) do
            local rawVal = customDiff[sl.name]
            local norm   = (rawVal - sl.vmin) / (sl.vmax - sl.vmin)
            norm = math.max(0, math.min(1, norm))
            local handleX = sl.x + norm * sl.w

            nvgFontFace(vg, "sans")
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 12)
            nvgFillColor(vg, nvgRGBA(180, 200, 240, 220))
            nvgText(vg, sl.labelX, sl.y + sl.h / 2, sl.label)

            local valStr = sl.fmtFn(rawVal)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(200, 180, 255, 255))
            nvgText(vg, sl.x + sl.w + 6, sl.y + sl.h / 2, valStr)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, sl.x, sl.y, sl.w, sl.h, sl.h / 2)
            nvgFillColor(vg, nvgRGBA(60, 50, 100, 200))
            nvgFill(vg)

            if norm > 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, sl.x, sl.y, norm * sl.w, sl.h, sl.h / 2)
                nvgFillColor(vg, nvgRGBA(180, 140, 255, 220))
                nvgFill(vg)
            end

            local isActive = (customDiffSlider == sl.name)
            nvgBeginPath(vg)
            nvgCircle(vg, handleX, sl.y + sl.h / 2, isActive and 9 or 7)
            nvgFillColor(vg, isActive and nvgRGBA(220, 200, 255, 255) or nvgRGBA(200, 180, 255, 230))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgCircle(vg, handleX, sl.y + sl.h / 2, isActive and 9 or 7)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 180))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end

        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(140, 120, 200, 160))
        nvgText(vg, p.x + p.w / 2, p.y + p.h - 8,
            "拖拽滑块调整 · 点击 [自定义] 按钮开始游戏")
    end

    -- 无尽征服模式按钮
    local eb     = ClientMenus.GetEndlessBtnLayout(sw, sh, ctx)
    local isEHov = (hover == "endless")
    nvgBeginPath(vg)
    nvgRoundedRect(vg, eb.x, eb.y, eb.w, eb.h, 10)
    local endlessBg = nvgLinearGradient(vg, eb.x, eb.y, eb.x + eb.w, eb.y,
        nvgRGBA(120, 30, 10, isEHov and 90 or 55),
        nvgRGBA(60, 10, 80, isEHov and 90 or 55))
    nvgFillPaint(vg, endlessBg)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, eb.x, eb.y, eb.w, eb.h, 10)
    nvgStrokeColor(vg, nvgRGBA(255, 140, 40, isEHov and 240 or 160))
    nvgStrokeWidth(vg, isEHov and 2.5 or 1.5)
    nvgStroke(vg)
    if isEHov then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, eb.x - 2, eb.y - 2, eb.w + 4, eb.h + 4, 12)
        nvgStrokeColor(vg, nvgRGBA(255, 140, 40, 70))
        nvgStrokeWidth(vg, 4)
        nvgStroke(vg)
    end
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(255, 160, 60, 255))
    nvgText(vg, sw / 2, eb.y + eb.h / 2 - 8, "⚔  无尽征服模式")
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(200, 160, 100, 200))
    nvgText(vg, sw / 2, eb.y + eb.h / 2 + 10,
        "无时间限制 · 歼灭全部敌人后新一轮敌人重生 · 威胁逐轮递增")

    -- 底部提示
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(100, 120, 160, 180))
    nvgText(vg, sw / 2, eb.y + eb.h + 22, "点击选择难度开始游戏")
end
