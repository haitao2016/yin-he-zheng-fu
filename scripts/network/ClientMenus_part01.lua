-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
