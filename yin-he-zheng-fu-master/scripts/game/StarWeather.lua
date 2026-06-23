-- ============================================================================
-- game/StarWeather.lua  -- P3-2: 动态星图天气系统
-- 星云漂移 / 流星雨 / 离子风暴预警 / 时空裂隙
-- ============================================================================

local StarWeather = {}

-- ============================================================================
-- 天气类型定义
-- ============================================================================
local WEATHER_TYPES = {
    {
        id = "nebula",
        name = "星云漂移",
        icon = "🌫",
        desc = "浓密星云经过，视野略受限制",
        color = { r = 100, g = 60, b = 180 },
        minDur = 60, maxDur = 120,  -- 秒
        weight = 35,
    },
    {
        id = "meteor_shower",
        name = "流星雨",
        icon = "☄",
        desc = "密集流星群划过星域",
        color = { r = 255, g = 180, b = 50 },
        minDur = 30, maxDur = 60,
        weight = 30,
    },
    {
        id = "ion_storm",
        name = "离子风暴",
        icon = "⚡",
        desc = "高能离子风暴！舰队移动减速",
        color = { r = 80, g = 200, b = 255 },
        minDur = 40, maxDur = 80,
        weight = 20,
    },
    {
        id = "rift",
        name = "时空裂隙",
        icon = "🌀",
        desc = "不稳定的时空裂隙在星图上涌现",
        color = { r = 200, g = 50, b = 255 },
        minDur = 25, maxDur = 50,
        weight = 15,
    },
}

-- ============================================================================
-- 内部状态
-- ============================================================================
local current_     = nil   -- 当前天气 { def, elapsed, duration }
local cooldown_    = 0     -- 切换冷却（秒）
local particles_   = {}    -- 流星/裂隙粒子列表
local nebulae_     = {}    -- 星云层 blob 列表
local MAX_PARTICLES = 40
local MAX_NEBULAE   = 6

-- 天气切换间隔（秒）
local INTERVAL_MIN = 45
local INTERVAL_MAX = 90

-- ============================================================================
-- 工具
-- ============================================================================
local function weightedRandom()
    local totalW = 0
    for _, wt in ipairs(WEATHER_TYPES) do totalW = totalW + wt.weight end
    local r = math.random() * totalW
    local acc = 0
    for _, wt in ipairs(WEATHER_TYPES) do
        acc = acc + wt.weight
        if r <= acc then return wt end
    end
    return WEATHER_TYPES[1]
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 初始化天气系统
function StarWeather.Init()
    current_ = nil
    cooldown_ = math.random(10, 25)  -- 首次天气出现前的初始等待
    particles_ = {}
    nebulae_ = {}
end

--- 每帧更新
---@param dt number
function StarWeather.Update(dt)
    if current_ then
        current_.elapsed = current_.elapsed + dt
        if current_.elapsed >= current_.duration then
            -- 天气结束
            current_ = nil
            cooldown_ = INTERVAL_MIN + math.random() * (INTERVAL_MAX - INTERVAL_MIN)
            particles_ = {}
            nebulae_ = {}
        else
            -- 更新粒子
            updateParticles(dt)
        end
    else
        cooldown_ = cooldown_ - dt
        if cooldown_ <= 0 then
            -- 触发新天气
            local def = weightedRandom()
            local dur = def.minDur + math.random() * (def.maxDur - def.minDur)
            current_ = { def = def, elapsed = 0, duration = dur }
            initWeatherVisuals(def)
        end
    end
end

--- 获取当前天气（nil 表示晴空）
---@return table|nil
function StarWeather.GetCurrent()
    if not current_ then return nil end
    local remaining = current_.duration - current_.elapsed
    return {
        id = current_.def.id,
        name = current_.def.name,
        icon = current_.def.icon,
        desc = current_.def.desc,
        color = current_.def.color,
        remaining = remaining,
        progress = current_.elapsed / current_.duration,
    }
end

--- 获取天气对舰队移动的速度修正因子
---@return number 1.0=无影响, <1.0=减速
function StarWeather.GetSpeedMod()
    if not current_ then return 1.0 end
    if current_.def.id == "ion_storm" then
        return 0.7  -- 离子风暴减速 30%
    end
    return 1.0
end

--- 渲染天气视觉效果（在 drawBackground 之后调用）
---@param vg userdata NanoVG context
---@param screenW number
---@param screenH number
---@param totalTime number 累计时间
---@param camera table {x, y}
---@param zoom number
function StarWeather.Render(vg, screenW, screenH, totalTime, camera, zoom)
    if not current_ then return end
    local def = current_.def
    local progress = current_.elapsed / current_.duration
    -- 淡入淡出因子
    local alpha = 1.0
    if current_.elapsed < 3.0 then
        alpha = current_.elapsed / 3.0
    elseif current_.duration - current_.elapsed < 3.0 then
        alpha = (current_.duration - current_.elapsed) / 3.0
    end

    if def.id == "nebula" then
        renderNebula(vg, screenW, screenH, totalTime, alpha, camera, zoom)
    elseif def.id == "meteor_shower" then
        renderMeteors(vg, screenW, screenH, totalTime, alpha)
    elseif def.id == "ion_storm" then
        renderIonStorm(vg, screenW, screenH, totalTime, alpha)
    elseif def.id == "rift" then
        renderRift(vg, screenW, screenH, totalTime, alpha)
    end
end

--- 序列化
function StarWeather.Serialize()
    return {
        current = current_,
        cooldown = cooldown_,
    }
end

--- 反序列化
function StarWeather.Deserialize(data)
    if not data then
        StarWeather.Init()
        return
    end
    current_ = data.current
    cooldown_ = data.cooldown or 0
    -- 粒子视觉在下一帧 render 时重新生成
    particles_ = {}
    nebulae_ = {}
    if current_ and current_.def then
        initWeatherVisuals(current_.def)
    end
end

-- ============================================================================
-- 内部：粒子与渲染
-- ============================================================================

--- 初始化天气视觉元素
function initWeatherVisuals(def)
    particles_ = {}
    nebulae_ = {}
    if def.id == "nebula" then
        for i = 1, MAX_NEBULAE do
            nebulae_[i] = {
                x = math.random() * 1.4 - 0.2,  -- [−0.2, 1.2] normalized
                y = math.random() * 1.4 - 0.2,
                r = 0.15 + math.random() * 0.25,
                speed = 0.002 + math.random() * 0.004,
                hueShift = math.random() * 60 - 30,
            }
        end
    elseif def.id == "meteor_shower" then
        for i = 1, MAX_PARTICLES do
            particles_[i] = newMeteor()
        end
    elseif def.id == "rift" then
        for i = 1, 8 do
            particles_[i] = newRiftPoint()
        end
    end
end

function updateParticles(dt)
    if not current_ then return end
    local def = current_.def
    if def.id == "nebula" then
        for _, nb in ipairs(nebulae_) do
            nb.x = nb.x + nb.speed * dt
            if nb.x > 1.3 then nb.x = -0.3 end
        end
    elseif def.id == "meteor_shower" then
        for i, p in ipairs(particles_) do
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.life = p.life - dt
            if p.life <= 0 then
                particles_[i] = newMeteor()
            end
        end
    elseif def.id == "rift" then
        for _, p in ipairs(particles_) do
            p.angle = p.angle + p.rotSpeed * dt
        end
    end
end

function newMeteor()
    local angle = -0.6 + math.random() * 0.3  -- 大致从右上向左下
    local speed = 200 + math.random() * 300
    return {
        x = math.random() * 1.2 + 0.1,   -- normalized screen coords
        y = -0.05 - math.random() * 0.2,
        vx = math.cos(angle) * speed / 1000,  -- normalized speed/s
        vy = math.sin(angle) * speed / 1000,
        life = 1.0 + math.random() * 2.0,
        len = 12 + math.random() * 20,
        brightness = 150 + math.random(105),
    }
end

function newRiftPoint()
    return {
        x = 0.2 + math.random() * 0.6,
        y = 0.2 + math.random() * 0.6,
        size = 20 + math.random() * 40,
        angle = math.random() * math.pi * 2,
        rotSpeed = (math.random() - 0.5) * 2.0,
    }
end

-- ============================================================================
-- 渲染：星云
-- ============================================================================
function renderNebula(vg, sw, sh, t, alpha, camera, zoom)
    for _, nb in ipairs(nebulae_) do
        local cx = nb.x * sw
        local cy = nb.y * sh
        local radius = nb.r * math.min(sw, sh)
        -- 用径向渐变模拟星云气体
        local baseR = 100 + math.floor(nb.hueShift * 0.5)
        local baseG = 40
        local baseB = 180 + math.floor(nb.hueShift)
        local a = math.floor(alpha * 35)
        local paint = nvgRadialGradient(vg, cx, cy, radius * 0.2, radius,
            nvgRGBA(baseR, baseG, baseB, a),
            nvgRGBA(baseR, baseG, baseB, 0))
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, radius)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end
end

-- ============================================================================
-- 渲染：流星雨
-- ============================================================================
function renderMeteors(vg, sw, sh, t, alpha)
    for _, p in ipairs(particles_) do
        if p.life > 0 then
            local sx = p.x * sw
            local sy = p.y * sh
            local a = math.floor(alpha * p.brightness * math.min(1.0, p.life))
            -- 尾迹线
            local tailX = sx - (p.vx * p.len * 10)
            local tailY = sy - (p.vy * p.len * 10)
            nvgBeginPath(vg)
            nvgMoveTo(vg, sx, sy)
            nvgLineTo(vg, tailX, tailY)
            nvgStrokeColor(vg, nvgRGBA(255, 220, 100, a))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
            -- 头部亮点
            nvgBeginPath(vg)
            nvgCircle(vg, sx, sy, 2.0)
            nvgFillColor(vg, nvgRGBA(255, 255, 200, a))
            nvgFill(vg)
        end
    end
end

-- ============================================================================
-- 渲染：离子风暴
-- ============================================================================
function renderIonStorm(vg, sw, sh, t, alpha)
    -- 全屏闪烁 + 电弧线条
    local flicker = 0.7 + 0.3 * math.sin(t * 8.0) * math.sin(t * 12.3)
    local a = math.floor(alpha * 18 * flicker)
    -- 全屏薄覆盖
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(60, 180, 255, a))
    nvgFill(vg)

    -- 4 条电弧（锯齿线）
    local arcCount = 4
    for i = 1, arcCount do
        local seed = t * 3.0 + i * 100
        local startX = (math.sin(seed * 0.7 + i) * 0.4 + 0.5) * sw
        local startY = 0
        local endX = (math.sin(seed * 0.5 + i * 2.3) * 0.4 + 0.5) * sw
        local endY = sh
        local segments = 8
        local arcAlpha = math.floor(alpha * 80 * flicker)
        nvgBeginPath(vg)
        nvgMoveTo(vg, startX, startY)
        for s = 1, segments do
            local frac = s / segments
            local lx = startX + (endX - startX) * frac + (math.sin(seed + s * 5.7) * 30)
            local ly = startY + (endY - startY) * frac + (math.cos(seed + s * 3.2) * 15)
            nvgLineTo(vg, lx, ly)
        end
        nvgStrokeColor(vg, nvgRGBA(100, 200, 255, arcAlpha))
        nvgStrokeWidth(vg, 1.0 + math.sin(seed) * 0.5)
        nvgStroke(vg)
    end
end

-- ============================================================================
-- 渲染：时空裂隙
-- ============================================================================
function renderRift(vg, sw, sh, t, alpha)
    for _, p in ipairs(particles_) do
        local cx = p.x * sw
        local cy = p.y * sh
        local sz = p.size
        local ang = p.angle
        -- 旋转的椭圆裂隙
        local a = math.floor(alpha * 120)
        nvgSave(vg)
        nvgTranslate(vg, cx, cy)
        nvgRotate(vg, ang)
        -- 外圈光晕
        local paint = nvgRadialGradient(vg, 0, 0, sz * 0.1, sz,
            nvgRGBA(200, 50, 255, a),
            nvgRGBA(100, 0, 200, 0))
        nvgBeginPath(vg)
        nvgEllipse(vg, 0, 0, sz, sz * 0.4)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
        -- 内核高亮
        nvgBeginPath(vg)
        nvgEllipse(vg, 0, 0, sz * 0.3, sz * 0.12)
        nvgFillColor(vg, nvgRGBA(255, 200, 255, math.floor(alpha * 200)))
        nvgFill(vg)
        nvgRestore(vg)
    end
end

return StarWeather
