-- ============================================================================
-- network/ClientMenus.lua  -- 主菜单 & 难度选择屏幕：布局/命中/渲染
-- 负责：renderMainMenu, renderDifficultyScreen, 及所有辅助布局/命中函数
-- 不负责：状态变量声明、on*Select 回调（仍在 Client.lua）
-- ============================================================================
local ClientMenus = {}

-- ============================================================================
-- P3-3: 深空粒子背景（闪星 + 流星）共享函数
-- ============================================================================

--- 绘制主界面动态粒子背景
--- t = 菜单累计时间（秒），用于驱动亮度脉冲和流星移动
local function drawParticleBackground(vg, sw, sh, t)
    -- ---- 深空闪星（90颗，固定位置，亮度随时间脉冲）----
    math.randomseed(42)
    for _ = 1, 90 do
        local sx    = math.random() * sw
        local sy    = math.random() * sh
        local sr    = math.random() * 1.5 + 0.25
        local phase = math.random() * math.pi * 2
        local spd   = math.random() * 1.2 + 0.4
        local baseA = math.random(70, 180)
        local pulse = math.sin(t * spd + phase)
        local alpha = math.max(30, math.min(240, math.floor(baseA + pulse * 50)))
        local bri   = math.random(170, 255)
        -- 暖白或冷蓝色调随机分布
        local isBlue = (math.random() > 0.55)
        local r = isBlue and math.max(160, bri - 40) or bri
        local g = isBlue and math.max(160, bri - 10) or bri
        local b = isBlue and bri                       or math.max(180, bri - 20)
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, sr)
        nvgFillColor(vg, nvgRGBA(r, g, b, alpha))
        nvgFill(vg)
        -- 亮星加一圈柔光晕
        if sr > 1.2 and alpha > 140 then
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, sr + 2.0)
            nvgFillColor(vg, nvgRGBA(r, g, b, math.floor(alpha * 0.18)))
            nvgFill(vg)
        end
    end

    -- ---- 流星（12条，各自独立相位/速度/角度）----
    math.randomseed(137)
    for _ = 1, 12 do
        local period  = math.random() * 4.0 + 3.5     -- 3.5~7.5 秒一个周期
        local phase   = math.random() * period         -- 相位偏移
        local startX  = math.random() * sw * 1.3 - sw * 0.15
        local startY  = math.random() * sh * 0.55
        local ang     = math.rad(18 + math.random() * 28)  -- 18~46° 斜向下
        local spd     = sw * (0.20 + math.random() * 0.25) -- 每秒移动屏幕宽度的20~45%
        local tailLen = sw * (0.06 + math.random() * 0.08) -- 尾巴长度
        local maxDist = sw * 0.55 + tailLen             -- 最大飞行距离

        -- 周期内位置 0~1
        local cycPos = ((t + phase) % period) / period
        if cycPos < 0.72 then  -- 0.72以后隐藏（归位）
            local tVisible = cycPos / 0.72              -- 归一化可见进度 0~1
            local dist     = tVisible * maxDist
            local hx = startX + math.cos(ang) * dist   -- 头部位置
            local hy = startY + math.sin(ang) * dist
            local ex = hx - math.cos(ang) * tailLen    -- 尾部位置
            local ey = hy - math.sin(ang) * tailLen

            -- 淡入淡出：前15%淡入，最后25%淡出
            local fadeIn  = math.min(1.0, tVisible / 0.15)
            local fadeOut = math.max(0.0, 1.0 - (tVisible - 0.75) / 0.25)
            local baseA   = math.floor(math.min(fadeIn, fadeOut) * 210)
            if baseA > 8 then
                -- 主光条（头亮尾暗渐变）
                local streakGrad = nvgLinearGradient(vg, hx, hy, ex, ey,
                    nvgRGBA(255, 255, 255, baseA),
                    nvgRGBA(160, 200, 255, 0))
                nvgBeginPath(vg)
                nvgMoveTo(vg, hx, hy)
                nvgLineTo(vg, ex, ey)
                nvgStrokePaint(vg, streakGrad)
                nvgStrokeWidth(vg, 1.5)
                nvgStroke(vg)
                -- 头部亮点
                nvgBeginPath(vg)
                nvgCircle(vg, hx, hy, 2.0)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, math.min(255, baseA + 30)))
                nvgFill(vg)
                -- 头部外晕
                nvgBeginPath(vg)
                nvgCircle(vg, hx, hy, 4.0)
                nvgFillColor(vg, nvgRGBA(200, 220, 255, math.floor(baseA * 0.25)))
                nvgFill(vg)
            end
        end
    end
end

-- ============================================================================
-- 主菜单屏幕
-- ============================================================================

--- 返回主菜单按钮布局 { key, x, y, w, h, label, enabled }
function ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    local btnW, btnH = math.min(240, sw - 40), 56
    local cx = sw / 2 - btnW / 2
    local baseY = sh * 0.52
    -- 底部4按钮：响应式宽度，确保不溢出屏幕
    local gap      = 6
    local smW      = math.min(198, math.floor((sw - 16 - gap * 3) / 4))
    local smH      = 40
    local totalSmW = smW * 4 + gap * 3
    local smStartX = sw / 2 - totalSmW / 2
    local smY      = sh - smH - 8  -- 固定在屏幕底部
    return {
        { key="new",      x=cx,             y=baseY,       w=btnW, h=btnH, label="新  游  戏", enabled=true },
        { key="continue", x=cx,             y=baseY + 72,  w=btnW, h=btnH, label="继 续 游 戏", enabled=hasSave },
        { key="campaign", x=smStartX,                      y=smY, w=smW, h=smH, label="⚔ 银河战役", enabled=true },
        { key="daily",    x=smStartX+smW+gap,              y=smY, w=smW, h=smH, label="📅 每日挑战", enabled=true },
        { key="heritage", x=smStartX+(smW+gap)*2,          y=smY, w=smW, h=smH, label="★ 星际传承", enabled=true },
        { key="league",   x=smStartX+(smW+gap)*3,          y=smY, w=smW, h=smH, label="🏆 星际联赛", enabled=true },
    }
end

--- 命中检测：返回命中按钮 key 或 nil
function ClientMenus.GetMainMenuHit(mx, my, sw, sh, hasSave)
    local btns = ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    for _, btn in ipairs(btns) do
        if btn.enabled and mx >= btn.x and mx <= btn.x + btn.w
            and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    return nil
end

--- 绘制主菜单全屏 UI
--- ctx = { hover, hasSave, menuT, evolutionPoints, unlockedCount }
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
            -- 普通按钮文字（底部小按钮根据宽度缩放字号）
            local fontSize
            if btn.key == "new" or btn.key == "continue" then
                fontSize = 20
            else
                fontSize = btn.w < 110 and 10 or 13
            end
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

    -- P1-1: 传承按钮的积分徽章（传承按钮下方居中）
    do
        local hBtns = ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
        local heriBtn = nil
        for _, b in ipairs(hBtns) do if b.key == "heritage" then heriBtn = b; break end end
        if heriBtn then
            local badgeX = heriBtn.x + heriBtn.w / 2
            local badgeY = heriBtn.y + heriBtn.h + 10
            local badge  = string.format("✦%d", evPoints)
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 215, 80, 220))
            nvgText(vg, badgeX, badgeY, badge)
            if evUnlocked > 0 then
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(150, 190, 255, 180))
                nvgText(vg, badgeX, badgeY + 13, string.format("%d/12", evUnlocked))
            end
        end
    end

    -- 底部版权
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(70, 90, 130, 150))
    nvgText(vg, sw / 2, sh * 0.94, "银河征服 · 点击开始你的星际征途")
end

-- ============================================================================
-- 难度选择屏幕
-- ============================================================================

--- 返回四个按钮的布局参数 { key, x, y, w, h, cfg }
function ClientMenus.GetDifficultyBtnLayout(sw, sh, ctx)
    local DIFF_ORDER          = ctx.DIFF_ORDER
    local DIFFICULTY_CONFIGS  = ctx.DIFFICULTY_CONFIGS
    local btnW, btnH = 165, 110
    local gap        = 16
    local totalW     = btnW * 4 + gap * 3
    local startX     = (sw - totalW) / 2
    local btnY       = sh * 0.46
    local result     = {}
    for i, key in ipairs(DIFF_ORDER) do
        result[i] = {
            key = key,
            x   = startX + (i - 1) * (btnW + gap),
            y   = btnY,
            w   = btnW,
            h   = btnH,
            cfg = DIFFICULTY_CONFIGS[key],
        }
    end
    return result
end

--- 自定义难度滑块面板是否可见
function ClientMenus.GetCustomPanelVisible(ctx)
    return ctx.hover == "custom" or ctx.customDiffSlider ~= nil
end

--- 返回自定义难度滑块面板布局 {x, y, w, h}
function ClientMenus.GetCustomPanelLayout(sw, sh)
    local pw, ph = 380, 106
    return {
        x = (sw - pw) / 2,
        y = sh * 0.46 + 110 + 8,
        w = pw,
        h = ph,
    }
end

--- 返回三条滑块的轨道信息列表
--- ctx = { customDiff }
function ClientMenus.GetCustomSliderRects(sw, sh, ctx)
    local customDiff = ctx.customDiff
    local p     = ClientMenus.GetCustomPanelLayout(sw, sh)
    local trackW = 200
    local labelX = p.x + 12
    local trackX = p.x + p.w - trackW - 12
    local trackH = 6
    return {
        {
            name  = "attackFactor",
            label = "进攻频率",
            x = trackX, y = p.y + 22, w = trackW, h = trackH,
            vmin = 0.5, vmax = 2.5,
            value = customDiff.attackFactor,
            fmtFn = function(v)
                if v < 0.8 then return "极快" elseif v < 1.2 then return "普通"
                elseif v < 1.8 then return "较慢" else return "很慢" end
            end,
            labelX = labelX,
        },
        {
            name  = "initResBonus",
            label = "初始资源",
            x = trackX, y = p.y + 53, w = trackW, h = trackH,
            vmin = -500, vmax = 1000,
            value = customDiff.initResBonus,
            fmtFn = function(v)
                if v > 0 then return string.format("+%d", v)
                elseif v < 0 then return string.format("%d", v)
                else return "标准" end
            end,
            labelX = labelX,
        },
        {
            name  = "maxThreat",
            label = "最大威胁",
            x = trackX, y = p.y + 84, w = trackW, h = trackH,
            vmin = 1, vmax = 8,
            value = customDiff.maxThreat,
            fmtFn = function(v) return string.format("Lv%d", math.floor(v)) end,
            labelX = labelX,
        },
    }
end

--- 无尽模式按钮布局
--- ctx = { hover, customDiffSlider }
function ClientMenus.GetEndlessBtnLayout(sw, sh, ctx)
    local btnW = 165 * 4 + 16 * 3
    local btnH = 48
    local btnX = (sw - btnW) / 2
    local extraY = ClientMenus.GetCustomPanelVisible(ctx) and 118 or 0
    local btnY = sh * 0.46 + 110 + 18 + extraY
    return { x=btnX, y=btnY, w=btnW, h=btnH }
end

--- 昵称输入框布局 {x, y, w, h}
function ClientMenus.GetNicknameInputLayout(sw, sh)
    local iw, ih = 240, 40
    return { x = (sw - iw) / 2, y = sh * 0.368, w = iw, h = ih }
end

--- 判断鼠标命中哪个按钮，返回 key 或 nil（"endless" 表示无尽模式）
--- ctx = { hover, customDiffSlider, customDiff, DIFF_ORDER, DIFFICULTY_CONFIGS }
function ClientMenus.GetDifficultyHit(mx, my, sw, sh, ctx)
    -- P1-1: 昵称输入框悬停检测
    local ni = ClientMenus.GetNicknameInputLayout(sw, sh)
    if mx >= ni.x and mx <= ni.x + ni.w and my >= ni.y and my <= ni.y + ni.h then
        return "nickname_input"
    end
    for _, btn in ipairs(ClientMenus.GetDifficultyBtnLayout(sw, sh, ctx)) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    if ClientMenus.GetCustomPanelVisible(ctx) then
        local p = ClientMenus.GetCustomPanelLayout(sw, sh)
        if mx >= p.x and mx <= p.x + p.w
        and my >= p.y and my <= p.y + p.h then
            return "custom"
        end
    end
    local eb = ClientMenus.GetEndlessBtnLayout(sw, sh, ctx)
    if mx >= eb.x and mx <= eb.x + eb.w
    and my >= eb.y and my <= eb.y + eb.h then
        return "endless"
    end
    return nil
end

--- 绘制难度选择全屏 UI
--- ctx = { hover, customDiffSlider, customDiff, DIFF_ORDER, DIFFICULTY_CONFIGS, menuT }
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

-- ============================================================================
-- P1-1: 传承树面板（主菜单层）
-- ============================================================================

-- 路线元数据
local LINE_META = {
    military = { label="⚔ 军事路线", color={255, 120, 80} },
    economy  = { label="⛏ 经济路线", color={80, 200, 120} },
    science  = { label="🔬 科研路线", color={100, 160, 255} },
}
local LINE_ORDER = { "military", "economy", "science" }

--- 计算节点格子布局（每条路线4个节点，水平排列）
--- 返回 { { nodeId, x, y, w, h }, ... }
local function getHeritageNodeRects(sw, sh, evolutionTree)
    local PW      = math.min(620, sw - 40)
    local px      = (sw - PW) * 0.5
    local py      = (sh - 460) * 0.5
    local nodeW   = math.floor((PW - 48) / 4) - 8  -- 约128
    local nodeH   = 78
    local gapX    = 8
    local lineH   = nodeH + 28  -- 节点 + 路线标题

    local result = {}
    for li, lineName in ipairs(LINE_ORDER) do
        local rowY = py + 70 + (li - 1) * (lineH + 12)
        for _, node in ipairs(evolutionTree) do
            if node.line == lineName then
                local col = node.tier - 1  -- 0-based
                local nx  = px + 24 + col * (nodeW + gapX)
                local ny  = rowY + 24  -- below line label
                result[#result + 1] = {
                    nodeId = node.id,
                    x = nx, y = ny, w = nodeW, h = nodeH,
                    node = node,
                }
            end
        end
    end
    return result
end

--- 关闭按钮中心位置
local function getHeritageClosePos(sw, sh)
    local PW = math.min(620, sw - 40)
    local px = (sw - PW) * 0.5
    local py = (sh - 460) * 0.5
    return px + PW - 20, py + 20
end

--- 返回鼠标命中的对象：节点id / "close" / nil
--- ctx = { evolutionTree, evolutionPoints, evolutionUnlocked }
function ClientMenus.GetHeritagePanelHit(mx, my, sw, sh, ctx)
    local closeX, closeY = getHeritageClosePos(sw, sh)
    if math.sqrt((mx - closeX)^2 + (my - closeY)^2) < 16 then
        return "close"
    end
    local rects = getHeritageNodeRects(sw, sh, ctx.evolutionTree)
    for _, r in ipairs(rects) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            return r.nodeId
        end
    end
    return nil
end

--- 绘制传承树全屏面板
--- ctx = { evolutionTree, evolutionPoints, evolutionUnlocked, hover, menuT }
function ClientMenus.RenderHeritagePanel(vg, sw, sh, ctx)
    local tree     = ctx.evolutionTree
    local pts      = ctx.evolutionPoints   or 0
    local unlocked = ctx.evolutionUnlocked or {}
    local hover    = ctx.hover
    local t        = ctx.menuT or 0

    -- 全屏遮罩
    local bg = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(2, 5, 18, 245), nvgRGBA(5, 12, 38, 245))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, bg)
    nvgFill(vg)

    -- 稀疏星点背景
    math.randomseed(77)
    for _ = 1, 40 do
        local sx = math.random() * sw
        local sy = math.random() * sh
        local sr = math.random() * 1.0 + 0.3
        local a  = math.random(40, 140)
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, sr)
        nvgFillColor(vg, nvgRGBA(180, 200, 255, a))
        nvgFill(vg)
    end

    -- 面板主体
    local PW = math.min(620, sw - 40)
    local PH = 460
    local px = (sw - PW) * 0.5
    local py = (sh - PH) * 0.5

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgFillColor(vg, nvgRGBA(10, 15, 40, 230))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgStrokeColor(vg, nvgRGBA(80, 130, 220, 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(180, 210, 255, 255))
    nvgText(vg, sw / 2, py + 22, "⚙  星际传承进化树")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, py + 38)
    nvgLineTo(vg, px + PW - 20, py + 38)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 积分显示（右上角）
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 215, 80, 240))
    nvgText(vg, px + PW - 36, py + 22, string.format("文明积分：%d", pts))

    -- 关闭按钮（X）
    local closeX, closeY = getHeritageClosePos(sw, sh)
    local closeDist = hover == "close" and 0 or 999
    local isCloseHov = (hover == "close")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, isCloseHov and nvgRGBA(255, 100, 100, 255) or nvgRGBA(160, 170, 200, 200))
    nvgText(vg, closeX, closeY, "✕")

    -- 路线 + 节点
    local nodeW  = math.floor((PW - 48) / 4) - 8
    local nodeH  = 78
    local gapX   = 8
    local lineH  = nodeH + 28

    -- 预先计算每条路线前一层是否已解锁（用于节点连线颜色）
    -- 按路线分组
    local byLine = {}
    for _, node in ipairs(tree) do
        byLine[node.line] = byLine[node.line] or {}
        byLine[node.line][node.tier] = node
    end

    for li, lineName in ipairs(LINE_ORDER) do
        local meta  = LINE_META[lineName]
        local cr, cg, cb = meta.color[1], meta.color[2], meta.color[3]
        local rowY  = py + 70 + (li - 1) * (lineH + 12)

        -- 路线标签
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
        nvgText(vg, px + 24, rowY + 10, meta.label)

        -- 节点连线（4个节点之间画3段连线）
        for tier = 1, 3 do
            local n1  = byLine[lineName][tier]
            local n2  = byLine[lineName][tier + 1]
            if n1 and n2 then
                local col1 = tier - 1
                local col2 = tier
                local x1   = px + 24 + col1 * (nodeW + gapX) + nodeW
                local x2   = px + 24 + col2 * (nodeW + gapX)
                local cy2  = rowY + 24 + nodeH / 2
                local bothUnlocked = unlocked[n1.id] and unlocked[n2.id]
                nvgBeginPath(vg)
                nvgMoveTo(vg, x1, cy2)
                nvgLineTo(vg, x2, cy2)
                if bothUnlocked then
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 200))
                    nvgStrokeWidth(vg, 2.5)
                elseif unlocked[n1.id] then
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 100))
                    nvgStrokeWidth(vg, 1.5)
                else
                    nvgStrokeColor(vg, nvgRGBA(60, 70, 100, 120))
                    nvgStrokeWidth(vg, 1)
                end
                nvgStroke(vg)
            end
        end

        -- 各节点格子
        for _, node in ipairs(tree) do
            if node.line == lineName then
                local col    = node.tier - 1
                local nx     = px + 24 + col * (nodeW + gapX)
                local ny     = rowY + 24
                local isUnlocked = unlocked[node.id]
                local isHov  = (hover == node.id)

                -- 检查是否可解锁（前置节点已解锁 且 积分足够）
                local prereqOk = true
                if node.tier > 1 then
                    local prev = byLine[lineName][node.tier - 1]
                    if prev then prereqOk = unlocked[prev.id] == true end
                end
                local canUnlock = prereqOk and not isUnlocked and pts >= node.unlockCost

                -- 节点背景色
                local bgR, bgG, bgB, bgA
                if isUnlocked then
                    bgR, bgG, bgB = cr, cg, cb
                    bgA = isHov and 90 or 55
                elseif canUnlock then
                    bgR, bgG, bgB = cr, cg, cb
                    bgA = isHov and 50 or 28
                else
                    bgR, bgG, bgB, bgA = 30, 35, 55, isHov and 60 or 35
                end

                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, nodeW, nodeH, 8)
                local nodeBg = nvgLinearGradient(vg, nx, ny, nx, ny + nodeH,
                    nvgRGBA(bgR, bgG, bgB, bgA + 10),
                    nvgRGBA(bgR, bgG, bgB, bgA))
                nvgFillPaint(vg, nodeBg)
                nvgFill(vg)

                -- 边框
                local borderA, borderW
                if isUnlocked then
                    borderA = isHov and 240 or 180
                    borderW = isHov and 2.0 or 1.5
                elseif canUnlock then
                    borderA = isHov and 200 or 140
                    borderW = isHov and 2.0 or 1.2
                else
                    borderA = 60
                    borderW = 0.8
                end
                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, nodeW, nodeH, 8)
                nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, borderA))
                nvgStrokeWidth(vg, borderW)
                nvgStroke(vg)

                -- hover 外发光
                if isHov and (canUnlock or isUnlocked) then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, nx - 3, ny - 3, nodeW + 6, nodeH + 6, 11)
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 70))
                    nvgStrokeWidth(vg, 5)
                    nvgStroke(vg)
                end

                -- 节点内容
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 图标
                nvgFontSize(vg, 18)
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, isUnlocked and 255 or 160))
                nvgText(vg, nx + nodeW / 2, ny + 16, node.icon)
                -- 名称
                nvgFontSize(vg, 11)
                nvgFillColor(vg, nvgRGBA(200, 220, 255, isUnlocked and 230 or 150))
                nvgText(vg, nx + nodeW / 2, ny + 33, node.name)
                -- 描述
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(160, 180, 220, isUnlocked and 200 or 110))
                nvgText(vg, nx + nodeW / 2, ny + 47, node.desc)
                -- 费用 / 状态
                if isUnlocked then
                    nvgFontSize(vg, 10)
                    nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
                    nvgText(vg, nx + nodeW / 2, ny + 62, "✓ 已解锁")
                elseif canUnlock then
                    nvgFontSize(vg, 10)
                    nvgFillColor(vg, nvgRGBA(255, 215, 80, 230))
                    nvgText(vg, nx + nodeW / 2, ny + 62,
                        string.format("点击解锁 ✦%d", node.unlockCost))
                else
                    nvgFontSize(vg, 10)
                    local costColor = pts >= node.unlockCost
                        and nvgRGBA(200, 200, 100, 160)
                        or  nvgRGBA(160, 80, 80, 180)
                    nvgFillColor(vg, costColor)
                    if not prereqOk then
                        nvgText(vg, nx + nodeW / 2, ny + 62, "🔒 前置未解")
                    else
                        nvgText(vg, nx + nodeW / 2, ny + 62,
                            string.format("需 ✦%d", node.unlockCost))
                    end
                end
            end
        end
    end

    -- 底部提示
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 120, 170, 180))
    nvgText(vg, sw / 2, py + PH - 18,
        "赢得游戏获得文明积分 · 积分永久保留 · 传承加成在下局自动生效")
end

return ClientMenus
