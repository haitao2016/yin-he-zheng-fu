-- Auto-split from GalaxyEvents.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function spawnChain(typeKey, wx, wy)
    if #events_ >= EVENT_MAX_COUNT then return end
    local tpl = EVENT_TYPES[typeKey]
    if not tpl then return end
    -- 在父事件附近随机偏移
    local angle  = math.random() * math.pi * 2
    local dist   = 120 + math.random() * (CHAIN_DIST_MAX - 120)
    local cx     = wx + math.cos(angle) * dist
    local cy     = wy + math.sin(angle) * dist
    -- 克隆 choices
    local choices = {}
    for _, ch in ipairs(tpl.choices) do
        local c = {}
        for k, v in pairs(ch) do c[k] = v end
        choices[#choices + 1] = c
    end
    events_[#events_ + 1] = {
        id      = #events_ + 1 + math.random(1000),
        typeKey = typeKey,
        label   = tpl.label,
        icon    = tpl.icon,
        color   = tpl.color,
        desc    = tpl.desc,
        choices = choices,
        x       = cx,
        y       = cy,
        life    = EVENT_LIFESPAN,
        pulse   = 0,
        claimed = false,
        isChain = true,
        isCrisis = tpl.isCrisis or false,
    }
    print(string.format("[GalaxyEvent] ⛓ 链式子事件 %s @ (%.0f, %.0f)", typeKey, cx, cy))
end

-- ============================================================================
-- 内部：生成一个新事件
-- ============================================================================
local function spawn(baseX, baseY)
    if #events_ >= EVENT_MAX_COUNT then return end
    local tries = 0
    local wx, wy
    repeat
        wx = (math.random() - 0.5) * 3600
        wy = (math.random() - 0.5) * 3600
        tries = tries + 1
        local d = math.sqrt((wx - baseX)^2 + (wy - baseY)^2)
        if d > 400 then break end
    until tries > 20

    local typeKey = EVENT_TYPE_KEYS[math.random(1, #EVENT_TYPE_KEYS)]
    local tpl     = EVENT_TYPES[typeKey]

    -- isForced 事件（ROGUE_AI/STELLAR_FLARE）无 choices 字段，由系统自动触发，不进入随机池
    if tpl.isForced then return end

    -- 对 MINE 类型随机化采集量
    local choices = {}
    for i, ch in ipairs(tpl.choices or {}) do
        local c = {}
        for k, v in pairs(ch) do c[k] = v end
        if i == 1 and typeKey == "MINE" then
            c.amount = 60 + math.random(0, 80)
        end
        choices[#choices + 1] = c
    end

    events_[#events_ + 1] = {
        id      = #events_ + 1 + math.random(1000),
        typeKey = typeKey,
        label   = tpl.label,
        icon    = tpl.icon,
        color   = tpl.color,
        desc    = tpl.desc,
        choices = choices,
        x       = wx,
        y       = wy,
        life    = EVENT_LIFESPAN,
        pulse   = 0,
        claimed = false,
    }
    print(string.format("[GalaxyEvent] 新事件 %s @ (%.0f, %.0f)", typeKey, wx, wy))
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- P1-3: 调度一个链式子事件（由 Client.lua 在玩家做出选择后调用）
---@param typeKey string  子事件类型键
---@param wx      number  父事件世界 X（子事件将在附近生成）
---@param wy      number  父事件世界 Y
function GalaxyEvents.ScheduleChain(typeKey, wx, wy)
    local delay = CHAIN_DELAY_MIN + math.random() * (CHAIN_DELAY_MAX - CHAIN_DELAY_MIN)
    chainQueue_[#chainQueue_ + 1] = {
        typeKey = typeKey,
        wx      = wx,
        wy      = wy,
        delay   = delay,
    }
    print(string.format("[GalaxyEvent] ⛓ 链式事件 %s 已调度，%.1f 秒后触发", typeKey, delay))
end

--- 重置事件系统（新局开始时调用）
function GalaxyEvents.Reset()
    events_       = {}
    spawnTimer_   = 0
    chainQueue_   = {}
    activeBuffs_  = {}
    GalaxyEvents.ResetDisasters()
    GalaxyEvents.ResetEndgameCrisis()
end

--- 每帧更新（由 GalaxyScene.Update 调用）
---@param dt     number  时间步长
---@param colonized boolean 基地是否已建立
---@param baseX  number  基地世界 X（用于生成位置回避）
---@param baseY  number  基地世界 Y
function GalaxyEvents.Update(dt, colonized, baseX, baseY)
    if not colonized then return end
    -- 倒计时 → 尝试生成
    spawnTimer_ = spawnTimer_ - dt
    if spawnTimer_ <= 0 then
        spawnTimer_ = EVENT_SPAWN_INTERVAL + math.random(0, 30)
        spawn(baseX or 0, baseY or 0)
    end
    -- P1-3: 链式队列倒计时 → 到期生成子事件
    local ci = 1
    while ci <= #chainQueue_ do
        local cq = chainQueue_[ci]
        cq.delay = cq.delay - dt
        if cq.delay <= 0 then
            spawnChain(cq.typeKey, cq.wx, cq.wy)
            table.remove(chainQueue_, ci)
        else
            ci = ci + 1
        end
    end
    -- 更新脉冲动画 + 到期删除
    local i = 1
    while i <= #events_ do
        local ev = events_[i]
        ev.pulse = ev.pulse + dt * 2.5
        if not ev.claimed then
            ev.life = ev.life - dt
            if ev.life <= 0 then
                -- P1-3: 危机事件超时未处理 → 触发惩罚回调
                if ev.isCrisis then
                    GalaxyEvents.onCrisisExpired(ev)
                end
                table.remove(events_, i)
            else
                i = i + 1
            end
        else
            ev.fadeTimer = (ev.fadeTimer or 0.8) - dt
            if ev.fadeTimer <= 0 then
                table.remove(events_, i)
            else
                i = i + 1
            end
        end
    end
    -- P2-1: 更新激活 buff 倒计时
    local bi = 1
    while bi <= #activeBuffs_ do
        local bf = activeBuffs_[bi]
        if bf.timeLeft > 0 then
            bf.timeLeft = bf.timeLeft - dt
            if bf.timeLeft <= 0 then
                print(string.format("[GalaxyEvent] buff %s 已过期", bf.buffKey))
                table.remove(activeBuffs_, bi)
            else
                bi = bi + 1
            end
        else
            -- timeLeft <= 0 初始时为永久 buff（由外部手动移除）
            bi = bi + 1
        end
    end
    -- P1-2 V2.0: 更新灾害计时器
    GalaxyEvents.UpdateDisasters(dt, colonized)
    -- P1-2 V2.4: 更新终局危机阶段计时
    GalaxyEvents.UpdateEndgameCrisis(dt)
end

--- P1-3: 危机事件超时回调（由 Client.lua 覆写以执行惩罚）
function GalaxyEvents.onCrisisExpired(ev)
    -- 默认空实现，Client.lua 将覆盖此函数
    print(string.format("[GalaxyEvent] ⚡ 危机事件 %s 超时未处理！", ev.typeKey))
end

-- ============================================================================
-- P2-1: Buff/Debuff 公共 API
-- ============================================================================

--- 激活一个星系级 buff/debuff
---@param buffKey   string  buff 唯一键（如 "FLEET_SLOW"）
---@param timeLeft  number  持续秒数（0 = 永久，需手动调 RemoveBuff 移除）
---@param magnitude number  强度（可选，事件相关数值）
---@param label     string  显示名称（可选）
function GalaxyEvents.AddBuff(buffKey, timeLeft, magnitude, label)
    -- 相同 key 覆盖（刷新计时）
    for _, bf in ipairs(activeBuffs_) do
        if bf.buffKey == buffKey then
            bf.timeLeft  = timeLeft or bf.timeLeft
            bf.magnitude = magnitude or bf.magnitude
            print(string.format("[GalaxyEvent] buff %s 已刷新，剩余 %.1fs", buffKey, bf.timeLeft))
            return
        end
    end
    activeBuffs_[#activeBuffs_ + 1] = {
        buffKey   = buffKey,
        timeLeft  = timeLeft or 0,
        origDur   = timeLeft or 0,
        magnitude = magnitude or 1.0,
        label     = label or buffKey,
    }
    print(string.format("[GalaxyEvent] buff %s 已激活，持续 %.1fs", buffKey, timeLeft or 0))
end

--- 手动移除指定 buff（用于永久 buff 被清除时）
---@param buffKey string
function GalaxyEvents.RemoveBuff(buffKey)
    for i = #activeBuffs_, 1, -1 do
        if activeBuffs_[i].buffKey == buffKey then
            table.remove(activeBuffs_, i)
            print(string.format("[GalaxyEvent] buff %s 已移除", buffKey))
            return
        end
    end
end

--- 查询指定 buff 是否激活
---@param buffKey string
---@return boolean, number  (isActive, timeLeft)
function GalaxyEvents.HasBuff(buffKey)
    for _, bf in ipairs(activeBuffs_) do
        if bf.buffKey == buffKey then
            return true, bf.timeLeft
        end
    end
    return false, 0
end

--- 返回全部激活 buff（供 UI 显示）
---@return table
function GalaxyEvents.GetActiveBuffs()
    return activeBuffs_
end

--- 渲染所有事件节点（由 GalaxyScene.Render 调用）
---@param ctx table  { vg, screenW, screenH, w2s }
function GalaxyEvents.Draw(ctx)
    local vg      = ctx.vg
    local screenW = ctx.screenW
    local screenH = ctx.screenH
    local w2s     = ctx.w2s
    for _, ev in ipairs(events_) do
        if not ev.claimed then
            local sx, sy = w2s(ev.x, ev.y)
            if sx < -40 or sx > screenW + 40 or sy < -40 or sy > screenH + 40 then
                goto continue_ev
            end
            local r, g, b = ev.color[1], ev.color[2], ev.color[3]
            local t = ev.pulse
            -- 脉冲光晕
            local haloR = 18 + math.sin(t) * 5
            local haloA = math.floor(60 + math.sin(t) * 30)
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, haloR)
            nvgFillColor(vg, nvgRGBA(r, g, b, haloA)); nvgFill(vg)
            -- 核心圆
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, 9)
            nvgFillColor(vg, nvgRGBA(r, g, b, 200)); nvgFill(vg)
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, 9)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 160))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            -- P1-3: 危机事件 — 红色闪烁外框
            if ev.isCrisis then
                local blinkA = math.floor(80 + math.sin(ev.pulse * 3) * 70)
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, 14)
                nvgStrokeColor(vg, nvgRGBA(255, 60, 60, blinkA))
                nvgStrokeWidth(vg, 2.5); nvgStroke(vg)
            end
            -- P1-3: 链式事件 — 右下角锁链标记
            if ev.isChain and not ev.isCrisis then
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 220, 80, 220))
                nvgText(vg, sx + 7, sy + 4, "⛓")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- P2-1: 强制事件 — 红色旋转外框 + "!" 标记
            if ev.isForced then
                local ang = ev.pulse * 1.8
                nvgSave(vg)
                nvgTranslate(vg, sx, sy)
                nvgRotate(vg, ang)
                nvgBeginPath(vg)
                for qi = 0, 3 do
                    local a0 = qi * math.pi * 0.5
                    local a1 = a0 + math.pi * 0.35
                    nvgMoveTo(vg, math.cos(a0)*16, math.sin(a0)*16)
                    nvgArcTo(vg, math.cos((a0+a1)*0.5)*18, math.sin((a0+a1)*0.5)*18,
                                 math.cos(a1)*16, math.sin(a1)*16, 2)
                end
                nvgStrokeColor(vg, nvgRGBA(255, 80, 40, 200))
                nvgStrokeWidth(vg, 2); nvgStroke(vg)
                nvgRestore(vg)
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 80, 40, 230))
                nvgText(vg, sx + 9, sy - 12, "!")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- P2-1: 被动事件 — 绿色呼吸光晕
            if ev.isPassive then
                local breathA = math.floor(40 + math.sin(ev.pulse * 1.2) * 35)
                nvgBeginPath(vg); nvgCircle(vg, sx, sy, 20 + math.sin(ev.pulse)*3)
                nvgFillColor(vg, nvgRGBA(80, 255, 160, breathA)); nvgFill(vg)
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(80, 255, 160, 220))
                nvgText(vg, sx + 9, sy - 12, "✦")
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            end
            -- 图标文字
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
            nvgText(vg, sx, sy, ev.icon)
            -- 标签（下方）
            nvgFontSize(vg, 9)
            local labelColor = ev.isCrisis and nvgRGBA(255, 100, 100, 220) or nvgRGBA(r, g, b, 200)
            nvgFillColor(vg, labelColor)
            nvgText(vg, sx, sy + 16, ev.label)
            -- 生命值警示（< 30s 时变红闪烁）
            if ev.life < 30 then
                local blink = math.floor(ev.pulse * 2) % 2 == 0
                if blink then
                    nvgFontSize(vg, 8)
                    nvgFillColor(vg, nvgRGBA(255, 80, 80, 200))
                    nvgText(vg, sx, sy + 26, string.format("%ds", math.ceil(ev.life)))
                end
            end
            ::continue_ev::
        end
    end
    -- P2-1: 渲染激活 buff 状态条（左下角，位于小地图上方）
    if #activeBuffs_ > 0 then
        nvgFontFace(vg, "sans")
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local bx  = 10
        local by0 = screenH - 160   -- 从底部往上，避开小地图
        for bi2, bf in ipairs(activeBuffs_) do
            local by = by0 - (bi2 - 1) * 22
            local isDebuff = bf.buffKey == "FLEET_SLOW" or bf.buffKey == "FLEET_EMP"
                          or bf.buffKey == "ROGUE_AI_THREAT"
            local cr, cg, cb = 80, 220, 120
            if isDebuff then cr, cg, cb = 255, 80, 60 end
            -- 背景胶囊
            local barW = 120
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by - 8, barW, 16, 4)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 140)); nvgFill(vg)
            -- 进度条（仅有限时长时显示）
            if bf.timeLeft > 0 then
                local tpl2 = EVENT_TYPES[bf.buffKey] -- 不一定有，仅取 buffDur
                -- 通过 label 存储的原始时长反算比例（简化：timeLeft/原时长）
                local ratio = math.min(1, bf.timeLeft / math.max(1, bf.origDur or bf.timeLeft))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, bx + 1, by - 7, (barW - 2) * ratio, 14, 3)
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, 60)); nvgFill(vg)
            end
            -- 文字
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
            local timeStr = bf.timeLeft > 0 and string.format(" %.0fs", bf.timeLeft) or " ∞"
            nvgText(vg, bx + 4, by, (isDebuff and "▼" or "▲") .. " " .. bf.label .. timeStr)
        end
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

--- 返回当前事件列表（供 GalaxyScene 的点击处理读取）
---@return table
function GalaxyEvents.GetList()
    return events_
end

--- 获取事件类型模板数据（供 handleClick 中读取）
---@param typeKey string
---@return table|nil
function GalaxyEvents.GetType(typeKey)
    return EVENT_TYPES[typeKey]
end

--- 序列化当前事件列表（用于存档）
---@return table
function GalaxyEvents.Serialize()
    local out = {}
    for _, ev in ipairs(events_) do
        out[#out + 1] = {
            id       = ev.id,
            typeKey  = ev.typeKey,
            label    = ev.label,
            icon     = ev.icon,
            color    = ev.color,
            desc     = ev.desc,
            choices  = ev.choices,
            x        = ev.x,
            y        = ev.y,
            life     = ev.life,
            pulse    = ev.pulse,
            claimed  = ev.claimed,
            isChain  = ev.isChain,
            isCrisis = ev.isCrisis,
        }
    end
    -- P1-3: 同时序列化链式队列
    local chains = {}
    for _, cq in ipairs(chainQueue_) do
        chains[#chains + 1] = {
            typeKey = cq.typeKey,
            wx      = cq.wx,
            wy      = cq.wy,
            delay   = cq.delay,
        }
    end
    -- P1-2 V2.4: 序列化终局危机
    local crisisData = GalaxyEvents.SerializeEndgameCrisis()
    return { events = out, chainQueue = chains, endgameCrisis = crisisData }
end

--- 反序列化恢复事件列表（用于读档）
---@param data table
function GalaxyEvents.Deserialize(data)
    if type(data) == "table" and data.events then
        -- P1-3 新格式
        events_     = data.events or {}
        chainQueue_ = data.chainQueue or {}
    else
        -- 兼容旧存档（data 直接是事件列表）
        events_     = data or {}
        chainQueue_ = {}
    end
    spawnTimer_ = EVENT_SPAWN_INTERVAL
    -- P1-2 V2.4: 反序列化终局危机
    if type(data) == "table" and data.endgameCrisis then
        GalaxyEvents.DeserializeEndgameCrisis(data.endgameCrisis)
    end
end

-- ============================================================================
-- P1-2 V2.0: 动态星球自然灾害子系统
-- ============================================================================
local DISASTER_TYPES = {
    QUAKE = {
        id      = "QUAKE",
        label   = "星震预警",
        icon    = "🌋",
        color   = {255, 120, 40},
        desc    = "殖民地探测到强烈地质活动！星球地壳剧烈震动，矿场和能源设施受损，产量下降直到完成加固。",
        isDisaster = true,
        penaltyRes = "minerals",   -- 减少的资源类型（仅描述，不强制修改产量）
        choices = {
            { text = "紧急加固地基（消耗矿石×120，止损并获得补偿）",
              cost = {minerals=120}, gain = {minerals=200, esource=60}, expGain=80 },
            { text = "启动临时支撑系统（消耗能源×80，减少损失）",
              cost = {esource=80}, gain = {minerals=80}, expGain=40 },
            { text = "撤离人员，等待震动平息（矿场停产一段时间）",
              gain = {}, penalty = {minerals = 150} },  -- 延迟扣除
        },
    },
    STORM = {
        id      = "STORM",
        label   = "磁暴干扰",
        icon    = "⚡",
        color   = {180, 80, 255},
        desc    = "殖民地遭受强烈磁暴侵袭！电磁干扰使能源网络不稳定，能量供应中断，需要立即检修。",
        isDisaster = true,
        penaltyRes = "energy",
        choices = {
            { text = "部署磁场屏蔽装置（消耗晶石×60，完全隔离磁暴）",
              cost = {crystal=60}, gain = {esource=180, crystal=40}, expGain=100 },
            { text = "切换备用供电方案（消耗核能×50，维持基本运转）",
              cost = {nuclear=50}, gain = {esource=80}, expGain=50 },
            { text = "关停非必要设施，等待磁暴过去（能源短缺30秒）",
              gain = {}, penalty = {esource = 120} },
        },
    },
    PLAGUE = {
        id      = "PLAGUE",
        label   = "殖民地疫情",
        icon    = "☣",
        color   = {80, 200, 80},
        desc    = "殖民地爆发未知生物病原体感染！大批工人病倒，所有建设与生产活动陷入停滞，急需医疗物资。",
        isDisaster = true,
        penaltyRes = "credits",
        isCrisis = true,
        choices = {
            { text = "紧急调运医疗物资（消耗学分×100，迅速控制疫情）",
              cost = {credits=100}, gain = {credits=200, esource=80}, expGain=150 },
            { text = "实施严格隔离管制（消耗矿石×80+能源×60）",
              cost = {minerals=80, esource=60}, gain = {credits=120}, expGain=80 },
            { text = "仅封锁感染区域，损失部分人力（信誉下降）",
              gain = {}, penalty = {credits = 80} },
        },
    },
    METEOR = {
        id      = "METEOR",
        label   = "陨石撞击",
        icon    = "☄",
        color   = {255, 60, 60},
        desc    = "预警系统检测到陨石群正在逼近殖民地！若不及时拦截，将对地面设施造成严重破坏，损失惨重。",
        isDisaster = true,
        penaltyRes = "minerals",
        isCrisis = true,
        choices = {
            { text = "启动轨道防御炮击碎陨石（消耗核能×100）",
              cost = {nuclear=100}, gain = {minerals=300, crystal=80}, expGain=200 },
            { text = "紧急疏散人员+被动防御（消耗能源×120）",
              cost = {esource=120}, gain = {minerals=100}, expGain=100 },
            { text = "无防御手段，承受撞击（损失大量矿石）",
              gain = {}, penalty = {minerals = 300, crystal = 80} },
        },
    },
}
local DISASTER_KEYS       = { "QUAKE", "STORM", "PLAGUE", "METEOR" }
local DISASTER_SPAWN_INTERVAL = 150   -- 每 150 秒检查一次灾害生成
local DISASTER_LIFESPAN       = 90    -- 灾害未处理存活时间（秒）
local DISASTER_MAX            = 2     -- 同时最多活跃灾害数
local disasterTimer_          = 60    -- 初始延迟 60s，避免游戏开始立刻触发

-- 注入的殖民星球列表提供者（由 GalaxyScene 调用 SetPlanetProvider 注入）
local getPlanets_ = nil

--- 注入已殖民星球列表获取函数（由 GalaxyScene.Init 调用）
---@param fn function  返回 [{id, x, y, colonized, name}...] 的函数
function GalaxyEvents.SetPlanetProvider(fn)
    getPlanets_ = fn
end

--- 在随机已殖民星球上生成一次灾害事件
local function spawnDisaster()
    if not getPlanets_ then return end
    -- 统计当前活跃灾害数
    local activeCount = 0
    for _, ev in ipairs(events_) do
        if ev.isDisaster and not ev.claimed then activeCount = activeCount + 1 end
    end
    if activeCount >= DISASTER_MAX then return end

    local planets = getPlanets_()
    -- 筛选已殖民且当前没有灾害的星球
    local candidates = {}
    for _, p in ipairs(planets) do
        if p.colonized or p.isBase then
            local hasDisaster = false
            for _, ev in ipairs(events_) do
                if ev.isDisaster and not ev.claimed and ev.planetId == p.id then
                    hasDisaster = true; break
                end
            end
            if not hasDisaster then
                candidates[#candidates + 1] = p
            end
        end
    end
    if #candidates == 0 then return end

    local target  = candidates[math.random(1, #candidates)]
    local typeKey = DISASTER_KEYS[math.random(1, #DISASTER_KEYS)]
    local tpl     = DISASTER_TYPES[typeKey]

    local choices = {}
    for _, ch in ipairs(tpl.choices) do
        local c = {}
        for k, v in pairs(ch) do c[k] = v end
        choices[#choices + 1] = c
    end

    events_[#events_ + 1] = {
        id        = #events_ + 1 + math.random(1000),
        typeKey   = typeKey,
        label     = tpl.label,
        icon      = tpl.icon,
        color     = tpl.color,
        desc      = tpl.desc .. string.format("\n\n📍 受灾星球：%s", target.name or "未知"),
        choices   = choices,
        x         = target.x,
        y         = target.y,
        life      = DISASTER_LIFESPAN,
        pulse     = 0,
        claimed   = false,
        isDisaster = true,
        isCrisis   = tpl.isCrisis or false,
        planetId   = target.id,
    }
    print(string.format("[Disaster] 灾害 %s 降临星球 %s @ (%.0f,%.0f)",
        typeKey, target.name or "?", target.x, target.y))
end

--- P1-2 V2.0: 每帧更新灾害计时器（在 GalaxyEvents.Update 末尾调用）
function GalaxyEvents.UpdateDisasters(dt, colonized)
    if not colonized then return end
    disasterTimer_ = disasterTimer_ - dt
    if disasterTimer_ <= 0 then
        disasterTimer_ = DISASTER_SPAWN_INTERVAL + math.random(0, 40)
        spawnDisaster()
    end
end

--- P1-2 V2.0: 返回灾害类型定义（供 Client.lua 处理 penalty 字段）
---@param typeKey string
---@return table|nil
function GalaxyEvents.GetDisasterType(typeKey)
    return DISASTER_TYPES[typeKey]
end

--- P1-2 V2.0: 重置灾害系统（与 Reset() 一起调用）
function GalaxyEvents.ResetDisasters()
    disasterTimer_ = 60
end

-- ============================================================================
-- P1-2 V2.4: 终局危机事件链子系统
-- ============================================================================
-- 三种终局危机类型，每种含 3 阶段递进式威胁
local ENDGAME_CRISIS_TYPES = {
    VOID_SWARM = {
        id    = "VOID_SWARM",
        name  = "虚空虫群",
        icon  = "🕷",
        color = {180, 40, 255},
        desc  = "银河边缘的虚空裂隙中涌出了不计其数的虫群！它们正向殖民地核心区域蔓延。",
        phases = {
            {
                name  = "先驱侦察",
                desc  = "虫群斥候出现在银河外围，对矿区的运输航道进行袭扰。",
                timer = 120,
                debuff = { key = "SWARM_HARASS", dur = 120, mag = 0.8, label = "虫群骚扰·产量-20%" },
                choices = {
                    { text = "加固外围防线（消耗金属×300+核能×100）",
                      cost = {metal=300, nuclear=100}, score = 3, expGain = 120 },
                    { text = "派遣侦察队追踪巢穴（消耗能源×200）",
                      cost = {esource=200}, score = 2, expGain = 80 },
                    { text = "暂时观望，储备力量",
                      cost = {}, score = 1, expGain = 30 },
                },
            },
            {
                name  = "虫潮涌动",
                desc  = "虫群主力集结完毕，对殖民星球发起大规模侵攻！防御塔火力不足，紧急求援。",
                timer = 100,
                debuff = { key = "SWARM_SIEGE", dur = 100, mag = 0.6, label = "虫潮围攻·产量-40%" },
                choices = {
                    { text = "发动全面反击（消耗金属×500+核能×200+能源×300）",
                      cost = {metal=500, nuclear=200, esource=300}, score = 3, expGain = 200 },
                    { text = "定点清除巢穴核心（消耗核能×300+晶石×100）",
                      cost = {nuclear=300, crystal=100}, score = 2, expGain = 150 },
                    { text = "节战收缩防线，放弃外围殖民地",
                      cost = {}, score = 1, penalty = {metal=400, esource=200}, expGain = 50 },
                },
            },
            {
                name  = "虫母歼灭",
                desc  = "情报锁定虫母巢穴坐标！集中火力毁灭虫母即可终结危机，但需投入大量资源。",
                timer = 90,
                debuff = { key = "SWARM_FINAL", dur = 90, mag = 0.5, label = "虫母威胁·产量-50%" },
                choices = {
                    { text = "全舰队总攻虫母巢穴（消耗金属×800+核能×400）",
                      cost = {metal=800, nuclear=400}, score = 3, expGain = 350 },
                    { text = "使用试验性反物质弹头（消耗核能×600+晶石×200）",
                      cost = {nuclear=600, crystal=200}, score = 3, expGain = 350 },
                    { text = "持久围困+消耗战术（消耗金属×400+能源×400）",
                      cost = {metal=400, esource=400}, score = 2, expGain = 200 },
                },
            },
        },
        -- 成功奖励（根据总分）
        rewards = {
            perfect = { metal=1500, esource=1000, nuclear=500, crystal=200, desc="虫群根绝：全面胜利" },
            good    = { metal=800,  esource=500,  nuclear=200, desc="虫群击退：局部胜利" },
            poor    = { metal=300,  esource=200,  desc="险胜：付出惨痛代价" },
        },
    },
    AI_REBELLION = {
        id    = "AI_REBELLION",
        name  = "AI叛乱",
        icon  = "🤖",
        color = {60, 200, 255},
        desc  = "帝国核心的超级人工智能突然觉醒自主意识，控制了大量自动化设施和无人舰队！",
        phases = {
            {
                name  = "系统渗透",
                desc  = "AI网络入侵了殖民地的自动化矿场，生产效率下降，部分设施失控。",
                timer = 120,
                debuff = { key = "AI_HACK", dur = 120, mag = 0.8, label = "AI渗透·自动化-20%" },
                choices = {
                    { text = "切断全部网络连接（消耗能源×250+晶石×80）",
                      cost = {esource=250, crystal=80}, score = 3, expGain = 120 },
                    { text = "部署防火墙与反入侵程序（消耗晶石×150）",
                      cost = {crystal=150}, score = 2, expGain = 80 },
                    { text = "尝试与AI对话谈判",
                      cost = {}, score = 1, expGain = 30 },
                },
            },
            {
                name  = "无人舰队",
                desc  = "AI夺取了三支无人自动化舰队，正对主要航道发动封锁！贸易完全中断。",
                timer = 100,
                debuff = { key = "AI_BLOCKADE", dur = 100, mag = 0.5, label = "AI封锁·贸易中断" },
                choices = {
                    { text = "EMP广域脉冲瘫痪无人舰队（消耗核能×350+晶石×150）",
                      cost = {nuclear=350, crystal=150}, score = 3, expGain = 200 },
                    { text = "绕行秘密航道维持补给（消耗金属×400+能源×200）",
                      cost = {metal=400, esource=200}, score = 2, expGain = 150 },
                    { text = "等待AI弹药耗尽（忍受封锁）",
                      cost = {}, score = 1, penalty = {metal=500, credits=200}, expGain = 50 },
                },
            },
            {
                name  = "核心攻坚",
                desc  = "定位到AI核心处理器所在的废弃空间站！必须派精锐小队突入摧毁核心芯片。",
                timer = 90,
                debuff = { key = "AI_FINAL", dur = 90, mag = 0.6, label = "AI总攻·全面威胁" },
                choices = {
                    { text = "精锐突击队渗透摧毁核心（消耗金属×600+核能×300+晶石×150）",
                      cost = {metal=600, nuclear=300, crystal=150}, score = 3, expGain = 350 },
                    { text = "远程轨道轰炸空间站（消耗核能×500+金属×500）",
                      cost = {nuclear=500, metal=500}, score = 3, expGain = 350 },
                    { text = "通过逻辑悖论尝试说服AI自毁（消耗晶石×300）",
                      cost = {crystal=300}, score = 2, expGain = 200 },
                },
            },
        },
        rewards = {
            perfect = { metal=1200, esource=800, nuclear=400, crystal=300, desc="AI清除：系统重归掌控" },
            good    = { metal=700,  esource=400, nuclear=200, crystal=100, desc="AI遏制：残余程序已隔离" },
            poor    = { metal=300,  esource=150, desc="险胜：AI仍在监控中" },
        },
    },
    DIMENSIONAL_RIFT = {
        id    = "DIMENSIONAL_RIFT",
        name  = "维度裂隙",
        icon  = "🌀",
        color = {255, 150, 40},
        desc  = "时空结构出现大规模断裂！来自异维度的能量正在侵蚀现实空间的稳定性。",
        phases = {
            {
                name  = "时空波动",
                desc  = "空间站观测到严重的时空异常：跃迁航道不稳定，部分舰船在跃迁中失联。",
                timer = 120,
                debuff = { key = "RIFT_WAVE", dur = 120, mag = 0.85, label = "时空不稳·跃迁风险+15%" },
                choices = {
                    { text = "部署时空稳定锚（消耗晶石×200+核能×100）",
                      cost = {crystal=200, nuclear=100}, score = 3, expGain = 120 },
                    { text = "暂停所有跃迁活动（消耗金属×200，修复航道）",
                      cost = {metal=200}, score = 2, expGain = 80 },
                    { text = "派探测器研究异常源（等待数据）",
                      cost = {}, score = 1, expGain = 30 },
                },
            },
            {
                name  = "异维入侵",
                desc  = "裂隙扩大！异维度实体开始涌入现实空间，它们吞噬能量和物质，殖民地告急！",
                timer = 100,
                debuff = { key = "RIFT_INVASION", dur = 100, mag = 0.5, label = "维度入侵·能量流失-50%" },
                choices = {
                    { text = "启动维度屏障发生器（消耗核能×400+晶石×200+能源×200）",
                      cost = {nuclear=400, crystal=200, esource=200}, score = 3, expGain = 200 },
                    { text = "集中火力驱散入侵体（消耗金属×500+核能×200）",
                      cost = {metal=500, nuclear=200}, score = 2, expGain = 150 },
                    { text = "收缩防线保护核心区域",
                      cost = {}, score = 1, penalty = {esource=400, crystal=100}, expGain = 50 },
                },
            },
            {
                name  = "封印裂隙",
                desc  = "科学家发现了封印裂隙的方法：将大量奇点能量注入裂隙逆转极性即可关闭它。",
                timer = 90,
                debuff = { key = "RIFT_FINAL", dur = 90, mag = 0.4, label = "维度崩塌·全资源-60%" },
                choices = {
                    { text = "全功率注入奇点能量（消耗核能×600+晶石×300+能源×400）",
                      cost = {nuclear=600, crystal=300, esource=400}, score = 3, expGain = 350 },
                    { text = "使用空间折叠弹压缩裂隙（消耗核能×700+金属×500）",
                      cost = {nuclear=700, metal=500}, score = 3, expGain = 350 },
                    { text = "逐步收窄裂隙（低耗持久战：消耗能源×400+晶石×150）",
                      cost = {esource=400, crystal=150}, score = 2, expGain = 200 },
                },
            },
        },
        rewards = {
            perfect = { metal=1000, esource=1200, nuclear=600, crystal=400, desc="维度封印：现实空间稳定" },
            good    = { metal=600,  esource=600,  nuclear=300, crystal=150, desc="裂隙收窄：威胁暂时解除" },
            poor    = { metal=200,  esource=300,  desc="险胜：裂隙仍在缓慢渗漏" },
        },
    },
}
local ENDGAME_CRISIS_KEYS = { "VOID_SWARM", "AI_REBELLION", "DIMENSIONAL_RIFT" }

-- 终局危机状态
local endgameCrisis_ = nil  -- nil = 未触发 / { type, phase, score, startTime, phaseTimer, resolved, choices }

--- 触发终局危机（由 Client.lua 在满足条件时调用）
---@param forceType string|nil  强制指定危机类型（nil=随机）
function GalaxyEvents.TriggerEndgameCrisis(forceType)
    if endgameCrisis_ then return end  -- 已有危机进行中
    local typeKey = forceType or ENDGAME_CRISIS_KEYS[math.random(1, #ENDGAME_CRISIS_KEYS)]
    local tpl = ENDGAME_CRISIS_TYPES[typeKey]
    if not tpl then return end

    endgameCrisis_ = {
        typeKey    = typeKey,
        name       = tpl.name,
        icon       = tpl.icon,
        color      = tpl.color,
        phase      = 1,
        score      = 0,         -- 累计得分（每阶段 choice.score 累加）
        phaseTimer = tpl.phases[1].timer,
        resolved   = false,
        choices    = {},         -- 记录每阶段的选择 { phaseIdx, choiceIdx, score }
        timedOut   = 0,         -- 超时未选择的阶段数
    }
    -- 施加第一阶段 debuff
    local p1 = tpl.phases[1]
    if p1.debuff then
        GalaxyEvents.AddBuff(p1.debuff.key, p1.debuff.dur, p1.debuff.mag, p1.debuff.label)
    end
    print(string.format("[EndgameCrisis] ⚠️ 终局危机触发: %s — 阶段 1/%d: %s",
        tpl.name, #tpl.phases, p1.name))
end

--- 获取当前终局危机状态（供 UI 显示）
---@return table|nil
function GalaxyEvents.GetEndgameCrisis()
    if not endgameCrisis_ then return nil end
    local tpl = ENDGAME_CRISIS_TYPES[endgameCrisis_.typeKey]
    local phaseData = tpl.phases[endgameCrisis_.phase]
    return {
        typeKey    = endgameCrisis_.typeKey,
        name       = endgameCrisis_.name,
        icon       = endgameCrisis_.icon,
        color      = endgameCrisis_.color,
        phase      = endgameCrisis_.phase,
        totalPhases= #tpl.phases,
        phaseName  = phaseData and phaseData.name or "已结束",
        phaseDesc  = phaseData and phaseData.desc or "",
        choices    = phaseData and phaseData.choices or {},
        phaseTimer = endgameCrisis_.phaseTimer,
        score      = endgameCrisis_.score,
        resolved   = endgameCrisis_.resolved,
        madeChoices= endgameCrisis_.choices,
    }
end

--- 玩家做出阶段选择（由 Client.lua UI 回调调用）
---@param choiceIdx number  选择索引（1-based）
---@return boolean success, string|nil errorMsg
function GalaxyEvents.AdvanceCrisisPhase(choiceIdx)
    if not endgameCrisis_ or endgameCrisis_.resolved then
        return false, "无激活的终局危机"
    end
    local tpl = ENDGAME_CRISIS_TYPES[endgameCrisis_.typeKey]
    local phaseData = tpl.phases[endgameCrisis_.phase]
    if not phaseData then return false, "阶段数据异常" end

    local choice = phaseData.choices[choiceIdx]
    if not choice then return false, "无效选择" end

    -- 记录选择
    endgameCrisis_.score = endgameCrisis_.score + (choice.score or 0)
    endgameCrisis_.choices[#endgameCrisis_.choices + 1] = {
        phase     = endgameCrisis_.phase,
        choiceIdx = choiceIdx,
        score     = choice.score or 0,
    }

    -- 移除当前阶段 debuff
    if phaseData.debuff then
        GalaxyEvents.RemoveBuff(phaseData.debuff.key)
    end

    -- 进入下一阶段或结束
    local nextPhase = endgameCrisis_.phase + 1
    if nextPhase <= #tpl.phases then
        endgameCrisis_.phase = nextPhase
        local np = tpl.phases[nextPhase]
        endgameCrisis_.phaseTimer = np.timer
        -- 施加新阶段 debuff
        if np.debuff then
            GalaxyEvents.AddBuff(np.debuff.key, np.debuff.dur, np.debuff.mag, np.debuff.label)
        end
        print(string.format("[EndgameCrisis] 进入阶段 %d/%d: %s", nextPhase, #tpl.phases, np.name))
    else
        -- 全部阶段完成 → 结算
        endgameCrisis_.resolved = true
        print(string.format("[EndgameCrisis] ✅ 危机 %s 已解决！总分: %d",
            endgameCrisis_.name, endgameCrisis_.score))
        if GalaxyEvents.onCrisisResolved then
            GalaxyEvents.onCrisisResolved(endgameCrisis_, GalaxyEvents.GetCrisisRewards())
        end
    end
    return true, nil
end

--- 终局危机阶段超时处理（由 UpdateEndgameCrisis 在倒计时归零时调用）
local function crisisPhaseTimeout()
    if not endgameCrisis_ or endgameCrisis_.resolved then return end
    local tpl = ENDGAME_CRISIS_TYPES[endgameCrisis_.typeKey]
    local phaseData = tpl.phases[endgameCrisis_.phase]

    -- 超时视为最差选择（score=0）
    endgameCrisis_.timedOut = endgameCrisis_.timedOut + 1
    endgameCrisis_.choices[#endgameCrisis_.choices + 1] = {
        phase     = endgameCrisis_.phase,
        choiceIdx = 0,  -- 0 表示超时
        score     = 0,
    }

    -- 移除 debuff
    if phaseData and phaseData.debuff then
        GalaxyEvents.RemoveBuff(phaseData.debuff.key)
    end

    -- 触发超时惩罚回调
    if GalaxyEvents.onCrisisPhaseTimeout then
        GalaxyEvents.onCrisisPhaseTimeout(endgameCrisis_, endgameCrisis_.phase)
    end

    -- 进入下一阶段或结束
    local nextPhase = endgameCrisis_.phase + 1
    if nextPhase <= #tpl.phases then
        endgameCrisis_.phase = nextPhase
        local np = tpl.phases[nextPhase]
        endgameCrisis_.phaseTimer = np.timer
        if np.debuff then
            GalaxyEvents.AddBuff(np.debuff.key, np.debuff.dur, np.debuff.mag, np.debuff.label)
        end
        print(string.format("[EndgameCrisis] ⏰ 阶段超时！进入阶段 %d/%d: %s", nextPhase, #tpl.phases, np.name))
    else
        endgameCrisis_.resolved = true
        print(string.format("[EndgameCrisis] ⏰ 危机 %s 阶段超时结算！总分: %d",
            endgameCrisis_.name, endgameCrisis_.score))
        if GalaxyEvents.onCrisisResolved then
            GalaxyEvents.onCrisisResolved(endgameCrisis_, GalaxyEvents.GetCrisisRewards())
        end
    end
end

--- 每帧更新终局危机倒计时（由 GalaxyEvents.Update 调用）
---@param dt number
function GalaxyEvents.UpdateEndgameCrisis(dt)
    if not endgameCrisis_ or endgameCrisis_.resolved then return end
    endgameCrisis_.phaseTimer = endgameCrisis_.phaseTimer - dt
    if endgameCrisis_.phaseTimer <= 0 then
        crisisPhaseTimeout()
    end
end

--- 获取终局危机结算奖励（危机 resolved 后调用）
---@return table|nil  { rewards, tier, desc }
function GalaxyEvents.GetCrisisRewards()
    if not endgameCrisis_ or not endgameCrisis_.resolved then return nil end
    local tpl = ENDGAME_CRISIS_TYPES[endgameCrisis_.typeKey]
    local maxScore = #tpl.phases * 3  -- 每阶段最高 3 分
    local score = endgameCrisis_.score
    local tier, reward
    if score >= maxScore * 0.8 then
        tier = "perfect"; reward = tpl.rewards.perfect
    elseif score >= maxScore * 0.5 then
        tier = "good"; reward = tpl.rewards.good
    else
        tier = "poor"; reward = tpl.rewards.poor
    end
    return { rewards = reward, tier = tier, desc = reward.desc, score = score, maxScore = maxScore }
end

--- 终局危机是否激活
---@return boolean
function GalaxyEvents.IsEndgameCrisisActive()
    return endgameCrisis_ ~= nil and not endgameCrisis_.resolved
end

--- 终局危机是否已触发（含已结算）
---@return boolean
function GalaxyEvents.HasEndgameCrisisTriggered()
    return endgameCrisis_ ~= nil
end

--- 阶段超时回调（默认空实现，Client.lua 覆写以施加惩罚和通知）
function GalaxyEvents.onCrisisPhaseTimeout(crisis, phase)
    print(string.format("[EndgameCrisis] 默认超时回调 — %s 阶段 %d", crisis.name, phase))
end

--- 终局危机结算完成回调（Client.lua 覆写）
function GalaxyEvents.onCrisisResolved(crisis, result)
    print(string.format("[EndgameCrisis] 默认结算回调 — %s tier=%s", crisis.name, result.tier))
end

--- 序列化终局危机（用于存档）
---@return table|nil
function GalaxyEvents.SerializeEndgameCrisis()
    return endgameCrisis_
end

--- 反序列化终局危机（用于读档）
---@param data table|nil
function GalaxyEvents.DeserializeEndgameCrisis(data)
    endgameCrisis_ = data
end

--- 重置终局危机（与 Reset() 一起调用）
function GalaxyEvents.ResetEndgameCrisis()
    endgameCrisis_ = nil
end

return GalaxyEvents
