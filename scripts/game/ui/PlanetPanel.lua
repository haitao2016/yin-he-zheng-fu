--- 行星面板模块
--- 负责渲染行星建造、已安装模块、殖民状态、建造队列

local UICommon = require("game.ui.UICommon")

local PlanetPanel = {}

-- 面板私有状态
local scrollY_           = 0
local planetBuildPending_   = nil   -- H4: 行星建造待确认（key string）
local planetUpgradePending_ = nil   -- H4: 行星升级待确认 {idx, key}
local specModalBld_         = nil   -- P2-3: 当前打开专精选择框的建筑 bldIdx

-- P3-2: 微动画状态表
-- animStates_[key] = { type, timer, maxTime, ... }
-- type: "press"(按钮按压), "highlight"(建造完成高亮), "shake"(资源不足抖动), "glow"(光晕扩散)
local animStates_  = {}
local lastDt_      = 0  -- 最近一帧 dt（由 Update 写入）

--- P3-2: 更新所有微动画计时器（每帧调用）
function PlanetPanel.Update(dt)
    lastDt_ = dt
    local toRemove = {}
    for k, anim in pairs(animStates_) do
        anim.timer = anim.timer - dt
        if anim.timer <= 0 then toRemove[#toRemove+1] = k end
    end
    for _, k in ipairs(toRemove) do animStates_[k] = nil end
end

--- P3-2: 触发按钮按压动画
local function triggerPress(key)
    animStates_[key] = { type="press", timer=0.18, maxTime=0.18 }
end

--- P3-2: 触发资源不足抖动动画
local function triggerShake(key)
    animStates_[key] = { type="shake", timer=0.30, maxTime=0.30 }
end

--- P3-2: 触发建造完成高亮动画（从 GameUI 调用）
function PlanetPanel.TriggerHighlight(planetId, bldKey)
    local key = tostring(planetId) .. "_hl_" .. tostring(bldKey)
    animStates_[key] = { type="highlight", timer=0.6, maxTime=0.6 }
end

--- P3-2: 触发专精激活光晕动画（从 GameUI 调用）
function PlanetPanel.TriggerGlow(planetId, bldIdx)
    local key = tostring(planetId) .. "_glow_" .. tostring(bldIdx)
    animStates_[key] = { type="glow", timer=0.45, maxTime=0.45 }
end

--- P3-2: 获取按钮按压缩放系数 (0.92–1.0)
local function getPressScale(key)
    local anim = animStates_[key]
    if not anim or anim.type ~= "press" then return 1.0 end
    local t = anim.timer / anim.maxTime   -- 1→0
    -- spring: 先缩小到 0.92，再弹回 1.0
    if t > 0.5 then
        return 1.0 - (1.0 - t) * 2 * 0.08   -- 缩小阶段：1.0→0.92
    else
        return 0.92 + t * 2 * 0.08           -- 弹回阶段：0.92→1.0
    end
end

--- P3-2: 获取资源不足抖动偏移 X
local function getShakeOffset(key)
    local anim = animStates_[key]
    if not anim or anim.type ~= "shake" then return 0 end
    local t = anim.timer / anim.maxTime   -- 1→0
    -- 3次往返抖动，衰减幅度
    return math.sin(t * math.pi * 6) * 4 * t
end

--- P3-2: 获取高亮 alpha（0–120）
local function getHighlightAlpha(planetId, bldKey)
    local key = tostring(planetId) .. "_hl_" .. tostring(bldKey)
    local anim = animStates_[key]
    if not anim or anim.type ~= "highlight" then return 0 end
    local t = anim.timer / anim.maxTime
    -- 先亮后暗，峰值在 t=0.7
    if t > 0.7 then
        return math.floor((1.0 - t) / 0.3 * 120)
    else
        return math.floor(t / 0.7 * 120)
    end
end

--- P3-2: 获取光晕扩散半径和 alpha
local function getGlowParams(planetId, bldIdx)
    local key = tostring(planetId) .. "_glow_" .. tostring(bldIdx)
    local anim = animStates_[key]
    if not anim or anim.type ~= "glow" then return 0, 0 end
    local t = anim.timer / anim.maxTime  -- 1→0
    local radius = (1.0 - t) * 22        -- 0→22px 扩散
    local alpha  = math.floor(t * 180)   -- 淡出
    return radius, alpha
end

function PlanetPanel.ResetScroll()
    scrollY_ = 0
    planetBuildPending_   = nil
    planetUpgradePending_ = nil
    specModalBld_         = nil
    animStates_  = {}
end

--- 渲染行星面板
---@param planet table  行星数据对象
---@param ctx    table  {bs, rm, screenH, onBuild, progressBar}
function PlanetPanel.Render(planet, ctx)
    if not planet then return end

    local vg       = UICommon.vg
    local screenW  = UICommon.screenW
    local screenH  = UICommon.screenH
    local bs       = UICommon.bs
    local rm       = UICommon.rm
    local addHit   = UICommon.addHit
    local addScroll= UICommon.addScroll
    local panel    = UICommon.panel
    local text     = UICommon.text
    local clr      = UICommon.clr
    local onBuild           = ctx.onBuild
    local onBatchUpgrade    = ctx.onBatchUpgrade  -- P3-3.3
    local onSpeedUpBuild    = ctx.onSpeedUpBuild
    local onSpeedUpBuildAd  = ctx.onSpeedUpBuildAd  -- 广告免费完成（星币不足时）
    local progressBar       = ctx.progressBar
    local onTogglePriority  = ctx.onTogglePriority  -- P2-1: 优先标记回调
    local isPriority        = ctx.isPriority        -- P2-1: 当前是否已标记
    local onCancelQueued    = ctx.onCancelQueued    -- P1-3: 取消排队任务回调 function(qIdx)
    local prodHistory       = ctx.prodHistory       -- P3-2: 产量历史 {minerals={}, energy={}, crystal={}}
    local onSendGift           = ctx.onSendGift           -- P1-1: 外交送礼回调 function(planetId)
    local diplomacyState       = ctx.diplomacyState       -- P1-1: {factionKey, favor, atWar, military, tradeTimer} or nil
    local onActivateLongTrade  = ctx.onActivateLongTrade  -- P2-2: 激活长期贸易协议 function(planetId)
    local onSetSpec            = ctx.onSetSpec            -- P2-3: 设置建筑专精 function(planetId, bldIdx, specKey)
    local onUpgradePlanetCb = ctx.onUpgradePlanetCb -- P1-2: 升级星球等级 function(planet)

    local pw = 275
    local px = screenW - pw - 12
    local py = UICommon.PANEL_TOP or 48

    -- 计算产量速率行高度（有已殖民星球+有建筑+有产量时额外占17px）
    local prodRowH = 0
    if (planet.colonized or planet.isBase) and #planet.buildings > 0 then
        for _, b in ipairs(planet.buildings) do
            if b.currentProd then
                for _, v in pairs(b.currentProd) do
                    if v > 0 then prodRowH = 17; break end
                end
            end
            if prodRowH > 0 then break end
        end
    end
    -- 特产标签行高度（已殖民非基地且有对应特产时额外14px）
    local bonusRowH = 0
    local ptBonus = nil
    if planet.colonized and not planet.isBase and planet.ptype then
        ptBonus = PLANET_TYPE_BONUS and PLANET_TYPE_BONUS[planet.ptype]
        if ptBonus then bonusRowH = 14 end
    end

    -- P3-3: 殖民建议指数（未殖民行星才计算）
    local colonyScore = 0        -- 0~100
    local colonyStars = 0        -- 1~5
    local colonyLabel = ""
    local colonyTips  = {}       -- 加成/减分条目
    local colonyAdvRowH = 0      -- 额外占用高度
    if not planet.colonized and not planet.isBase then
        -- === 评分算法 ===
        -- 1. 行星类型加成（最高35分）
        local typeScore = 0
        local typeLabel = ""
        local tb = PLANET_TYPE_BONUS and PLANET_TYPE_BONUS[planet.ptype]
        if tb then
            -- 各加成类型的吸引力权重
            if tb.esourceMult then
                typeScore = math.floor((tb.esourceMult - 1) * 70)  -- Gas Giant 1.6→42 → cap35
                typeLabel = "⚡ " .. tb.label
            elseif tb.nuclearMult then
                typeScore = math.floor((tb.nuclearMult - 1) * 80)  -- Volcanic 1.4→32
                typeLabel = "☢ " .. tb.label
            elseif tb.crystalMult then
                typeScore = math.floor((tb.crystalMult - 1) * 60)  -- Oceanic 1.5→30
                typeLabel = "💎 " .. tb.label
            elseif tb.mineralMult then
                typeScore = math.floor((tb.mineralMult - 1) * 60)  -- Terran/Desert 1.3→18
                typeLabel = "⛏ " .. tb.label
            elseif tb.buildCostMult then
                typeScore = math.floor((1 - tb.buildCostMult) * 80)  -- Barren 0.85→12
                typeLabel = "🔧 " .. tb.label
            end
        else
            typeLabel = "无特产加成"
        end
        typeScore = math.min(35, typeScore)
        colonyTips[#colonyTips+1] = {
            label = "星球类型",
            val   = typeScore,
            maxV  = 35,
            desc  = typeLabel ~= "" and typeLabel or "—",
            r=100, g=180, b=255,
        }

        -- 2. 行星大小（建筑槽位，最高30分）
        -- size范围 5~18，标准化到 0~30
        local sizeScore = math.floor(math.max(0, planet.size - 5) / 13 * 30)
        sizeScore = math.min(30, sizeScore)
        local slotEst = math.floor(sizeScore / 3) + 1  -- 粗略槽位预估
        colonyTips[#colonyTips+1] = {
            label = "星球大小",
            val   = sizeScore,
            maxV  = 30,
            desc  = string.format("%.1f  预估≈%d槽", planet.size, slotEst),
            r=80, g=220, b=120,
        }

        -- 3. 位置（深空行星资源加倍但防御难度高，+15；普通位置+20）
        local locScore = planet.deepSpace and 15 or 20
        local locDesc  = planet.deepSpace and "深空区域（高风险高回报）" or "常规星系"
        colonyTips[#colonyTips+1] = {
            label = "位置",
            val   = locScore,
            maxV  = 20,
            desc  = locDesc,
            r=255, g=200, b=80,
        }

        -- 4. 资源倍增（深空resMultiplier加成，最高15分）
        local multScore = 0
        local multDesc  = "无倍增"
        if planet.resMultiplier and planet.resMultiplier > 1.0 then
            multScore = math.floor((planet.resMultiplier - 1.0) * 30)
            multScore = math.min(15, multScore)
            multDesc  = string.format("资源×%.1f", planet.resMultiplier)
        end
        colonyTips[#colonyTips+1] = {
            label = "资源倍率",
            val   = multScore,
            maxV  = 15,
            desc  = multDesc,
            r=200, g=130, b=255,
        }

        colonyScore = math.min(100, typeScore + sizeScore + locScore + multScore)

        -- 转换为星级
        if     colonyScore >= 85 then colonyStars = 5
        elseif colonyScore >= 68 then colonyStars = 4
        elseif colonyScore >= 50 then colonyStars = 3
        elseif colonyScore >= 32 then colonyStars = 2
        else                          colonyStars = 1
        end

        -- 文字标签
        local COLONY_LABELS = {"不推荐","一般","较好","推荐","强烈推荐"}
        colonyLabel = COLONY_LABELS[colonyStars]

        -- 占用额外头部高度：1行标题+1行进度条+4行 tips = 约 60px
        colonyAdvRowH = 64
    end

    -- P1-3: 计算队列额外高度（每项 18px）
    local queueLen = (planet.buildQueue and #planet.buildQueue) or 0
    local queueH   = planet.constructing and (queueLen * 18) or 0

    -- P3-2: 产量趋势图高度（已殖民/基地且有 >=2 个历史点才显示）
    local chartRowH = 0
    if (planet.colonized or planet.isBase) and prodHistory then
        for _, res in ipairs({"minerals","energy","crystal"}) do
            if prodHistory[res] and #prodHistory[res] >= 2 then
                chartRowH = 58  -- 标题14 + 图表38 + 间距6
                break
            end
        end
    end

    -- P1-1: 外交区块高度（中立势力行星才显示）
    local diplomacyRowH = 0
    if planet.neutralFaction and not planet.colonized and not planet.isBase then
        -- 基础: 势力行14 + 好感度条14 + 状态标签/礼物按钮行18 + 间距
        diplomacyRowH = 60
        -- P2-2: 长期贸易协议按钮/状态行（好感 ≥ 60 且未宣战时显示）
        local ds_pre = ctx.diplomacyState
        if ds_pre and not ds_pre.atWar and (ds_pre.favor or 0) >= 60 then
            diplomacyRowH = diplomacyRowH + 18  -- 额外一行
        end
    end

    -- P1-2: 星球升级区块高度（已殖民非基地，且等级 < 5）
    local upgradeRowH = 0
    if planet.colonized and not planet.isBase then
        upgradeRowH = 32  -- 等级栏14 + 升级按钮/费用行18
    end

    local headerH = 36 + 18 + (planet.constructing and 22 or 16) + queueH + 16 + prodRowH + bonusRowH + colonyAdvRowH + chartRowH + diplomacyRowH + upgradeRowH

    local scrollContentH = 18
        + #BUILD_ORDER * 21
        + 12 + 17
        + math.max(1, #planet.buildings) * 20

    local totalH    = headerH + scrollContentH
    local maxPanelH = screenH - py - 16
    local ph        = math.min(totalH + 16, maxPanelH)

    local scrollStartY = py + headerH
    local scrollAreaH  = ph - headerH
    local maxScroll    = math.max(0, scrollContentH - scrollAreaH)
    scrollY_ = math.max(0, math.min(maxScroll, scrollY_))

    panel(px, py, pw, ph, 7, {8,14,30,240}, {68,136,255,220})

    -- === 固定头部 ===
    local sy = py + 16

    text(px+pw/2, sy, planet.name, 15, 100,180,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = sy + 20
    if planet.isBase then
        text(px+pw/2, sy,
            "已建立  模块槽位:"..#planet.buildings.."/10",
            9, 100,200,255,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    else
        -- P1-2: 槽位上限基于星球等级
        local pLvForSlot = planet.level or 1
        local maxSlotDisp = math.min(8, 4 + (pLvForSlot - 1))
        text(px+pw/2, sy,
            planet.ptype.."行星  大小:"..string.format("%.1f",planet.size).."  槽位:"..#planet.buildings.."/"..maxSlotDisp,
            9, 130,160,220,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    end
    sy = sy + 16

    if planet.isBase then
        text(px+14, sy, "★ 星航基地", 11, 80, 200, 255, 255)
        sy = sy + 18
    elseif planet.colonized then
        text(px+14, sy, "● 已探索", 11, 50,220,100,255)
        sy = sy + 18
        -- 特产标签（黄色高亮，仅已殖民非基地行星）
        if ptBonus and ptBonus.label then
            text(px+14, sy, "★ 特产: " .. ptBonus.label, 10, 255,210,80,255)
            sy = sy + 14
        end
        -- P1-2: 星球升级区块（已殖民非基地）
        do
            local pLv    = planet.level or 1
            local maxLv  = 5
            -- 等级进度条（五格）
            local barX = px + 14
            local barY = sy + 5
            local cellW, cellH, cellGap = 28, 8, 3
            for i = 1, maxLv do
                local filled = (i <= pLv)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, barX + (i-1)*(cellW+cellGap), barY, cellW, cellH, 2)
                if filled then
                    nvgFillColor(vg, nvgRGBA(60, 200, 120, 220))
                else
                    nvgFillColor(vg, nvgRGBA(40, 60, 80, 160))
                end
                nvgFill(vg)
            end
            -- 等级文字
            text(barX + maxLv*(cellW+cellGap) + 4, barY + 4,
                "Lv."..pLv, 9, 100,220,160,255)
            sy = sy + 16

            -- 升级按钮 / 满级提示
            if pLv < maxLv then
                local COSTS = {
                    [2]={metal=200},
                    [3]={metal=500,crystal=200},
                    [4]={metal=500,crystal=500,esource=500},
                    [5]={metal=1000,crystal=1000,esource=1000},
                }
                local cost   = COSTS[pLv + 1] or {}
                local costParts = {}
                local RES_LABEL = {metal="金属",crystal="晶体",esource="能源",nuclear="核能"}
                for _, res in ipairs({"metal","crystal","esource","nuclear"}) do
                    if cost[res] then
                        costParts[#costParts+1] = (RES_LABEL[res] or res).."×"..cost[res]
                    end
                end
                local costStr = table.concat(costParts, " ")

                local btnW, btnH = 72, 14
                local bx = px + pw - btnW - 8
                local by = sy - 2
                panel(bx, by, btnW, btnH, 3, {20,60,30,120}, {50,180,90,200})
                text(bx + btnW/2, by + btnH/2, "升级 →Lv."..(pLv+1),
                    8, 120,255,160,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                -- 费用文字
                text(px+14, by + btnH/2, costStr, 8, 200,200,180,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)

                local capPlanet = planet
                addHit(bx, by, btnW, btnH, function()
                    if onUpgradePlanetCb then onUpgradePlanetCb(capPlanet) end
                end)
                sy = sy + 16
            else
                text(px+14, sy, "★ 星球已达最高等级", 9, 255,200,60,220)
                sy = sy + 16
            end
        end
    else
        text(px+14, sy, "○ 未探索  (派遣探索舰探索)", 11, 200,160,60,220)
        -- P2-1: 优先标记切换按钮（右侧小按钮）
        if onTogglePriority then
            local marked  = isPriority == true
            local btnW, btnH = 50, 14
            local bx = px + pw - btnW - 8
            local by = sy - 7
            panel(bx, by, btnW, btnH, 3,
                marked and {180, 100, 10, 80} or {60, 60, 80, 60},
                marked and {255, 160, 30, 200} or {120, 120, 150, 160})
            text(bx + btnW/2, by + btnH/2,
                marked and "◆取消" or "◆标记",
                8,
                marked and 255 or 180,
                marked and 200 or 180,
                marked and 60  or 200,
                240,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local capturedPlanet = planet
            addHit(bx, by, btnW, btnH, function()
                if onTogglePriority then onTogglePriority(capturedPlanet) end
            end)
        end
        sy = sy + 18

        -- P3-3: 殖民建议指数卡片
        if colonyAdvRowH > 0 then
            -- 卡片背景
            local cardX, cardW, cardH = px + 8, pw - 16, colonyAdvRowH - 4
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cardX, sy, cardW, cardH, 5)
            -- 星级颜色渐变背景
            local starColors = {
                [1]={60,40,40},   [2]={50,50,40},  [3]={30,55,45},
                [4]={30,50,70},   [5]={50,40,90},
            }
            local sc = starColors[colonyStars] or starColors[3]
            nvgFillColor(vg, nvgRGBA(sc[1], sc[2], sc[3], 180))
            nvgFill(vg)
            -- 卡片边框（星级着色）
            local borderColors = {
                [1]={160,60,60},   [2]={200,180,60},  [3]={60,200,120},
                [4]={60,160,255},  [5]={200,100,255},
            }
            local bc2 = borderColors[colonyStars] or {100,140,200}
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cardX+0.5, sy+0.5, cardW-1, cardH-1, 5)
            nvgStrokeColor(vg, nvgRGBA(bc2[1], bc2[2], bc2[3], 160))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            -- 标题行：「殖民建议」 + 星级 + 标签
            local starStr = string.rep("★", colonyStars) .. string.rep("☆", 5 - colonyStars)
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(160, 200, 255, 220))
            nvgText(vg, cardX + 7, sy + 8, "殖民建议")
            -- 星级（金黄色）
            nvgFillColor(vg, nvgRGBA(bc2[1], bc2[2], bc2[3], 240))
            nvgText(vg, cardX + 52, sy + 8, starStr)
            -- 标签（右对齐）
            nvgFontSize(vg, 8.5)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(bc2[1], bc2[2], bc2[3], 210))
            nvgText(vg, cardX + cardW - 7, sy + 8, colonyLabel)

            -- 总分进度条
            local barY   = sy + 18
            local barX   = cardX + 7
            local barW2  = cardW - 14
            local barH2  = 7
            local fillW  = math.floor(barW2 * colonyScore / 100)
            -- 底槽
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW2, barH2, 3)
            nvgFillColor(vg, nvgRGBA(20, 20, 40, 160))
            nvgFill(vg)
            -- 填充（渐变：低分红→中分黄→高分蓝紫）
            if fillW > 0 then
                local grad = nvgLinearGradient(vg, barX, barY, barX + barW2, barY,
                    nvgRGBA(200, 60, 60, 220), nvgRGBA(bc2[1], bc2[2], bc2[3], 240))
                nvgBeginPath(vg)
                nvgRoundedRect(vg, barX, barY, fillW, barH2, 3)
                nvgFillPaint(vg, grad)
                nvgFill(vg)
            end
            -- 分数文字
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, 200))
            nvgText(vg, cardX + cardW - 7, barY + barH2/2, colonyScore .. "/100")

            -- 4个评分维度（两列布局）
            local tipY = barY + barH2 + 5
            local colW = (cardW - 14) / 2
            for i, tip in ipairs(colonyTips) do
                local col  = (i - 1) % 2
                local row  = math.floor((i - 1) / 2)
                local tx   = cardX + 7 + col * colW
                local ty   = tipY + row * 14
                -- 小标签背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, tx, ty, colW - 4, 11, 2)
                nvgFillColor(vg, nvgRGBA(tip.r, tip.g, tip.b, 18))
                nvgFill(vg)
                -- 标签名
                nvgFontSize(vg, 7.5)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(tip.r, tip.g, tip.b, 180))
                nvgText(vg, tx + 3, ty + 5.5, tip.label .. ":")
                -- 分值（右）
                nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(tip.r, tip.g, tip.b, 220))
                nvgText(vg, tx + colW - 7, ty + 5.5, "+" .. tip.val)
            end

            sy = sy + colonyAdvRowH
        end
    end

    if planet.constructing then
        local job = planet.constructing
        local pct = job.progress or 0
        local tag = job.isUpgrade and "升级" or "建造"
        local barW = onSpeedUpBuild and (pw - 58) or (pw - 20)
        progressBar(px+10, sy, barW, 12, pct,
            tag..": "..BUILDINGS[job.key].name.." "..math.floor(pct*100).."%", 68,180,255)
        -- 加速按钮（星币足够→金色购买；不足且有广告→绿色免费）
        if onSpeedUpBuild or onSpeedUpBuildAd then
            local remaining = job.remaining or 0
            -- M6 修复：1★/10秒，上限50★，避免后期费用失控
            local speedCost = math.max(5, math.min(50, math.ceil(remaining / 10)))
            local rmRef     = UICommon.rm
            local canAfford = rmRef and (rmRef.resources.credits or 0) >= speedCost
            local sbx = px + pw - 46
            if onSpeedUpBuild and canAfford then
                panel(sbx, sy, 40, 12, 4, {160,130,20,80}, {220,190,40,210})
                text(sbx+20, sy+6, "★"..speedCost, 8, 255,230,80,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                local capturedPlanet = planet
                addHit(sbx, sy, 40, 12, function()
                    if onSpeedUpBuild then onSpeedUpBuild(capturedPlanet) end
                end)
            elseif onSpeedUpBuildAd and not canAfford then
                -- 星币不足时显示"看广告免费完成"
                panel(sbx, sy, 40, 12, 3, {0,80,45,100}, {0,190,100,220})
                text(sbx+20, sy+6, "🎬", 9, 80,255,160,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                local capturedPlanet = planet
                addHit(sbx, sy, 40, 12, function()
                    if onSpeedUpBuildAd then onSpeedUpBuildAd(capturedPlanet) end
                end)
            end
        end
        sy = sy + 22

        -- P1-3: 渲染排队任务列表
        if planet.buildQueue and #planet.buildQueue > 0 then
            for qi, qjob in ipairs(planet.buildQueue) do
                -- 排队条背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+10, sy, pw-20, 15, 3)
                nvgFillColor(vg, nvgRGBA(30, 60, 100, 160))
                nvgFill(vg)
                nvgStrokeColor(vg, nvgRGBA(80,130,220,100))
                nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                -- 序号 + 任务名（通过 bs:getBuildingName 获取）
                local bname = bs and bs:getBuildingName(qjob.key) or qjob.key
                local tag2 = qjob.isUpgrade and "升 " or "建 "
                text(px+16, sy+7.5, qi..". "..tag2..bname, 9, 160,200,255,220,
                    NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
                -- 取消按钮（右侧 ×）
                if onCancelQueued then
                    local cbx = px + pw - 22
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, cbx, sy+1, 14, 13, 3)
                    nvgFillColor(vg, nvgRGBA(180,60,60,160)); nvgFill(vg)
                    text(cbx+7, sy+7.5, "×", 9, 255,160,160,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local capturedQi = qi
                    local capturedPlanet = planet
                    addHit(cbx, sy+1, 14, 13, function()
                        if onCancelQueued then onCancelQueued(capturedQi, capturedPlanet) end
                    end)
                end
                sy = sy + 18
            end
        end
    else
        text(px+14, sy, "建设队列: 空闲", 10, 150,170,200,180)
        sy = sy + 16
    end

    -- ── 产量速率小条（已殖民/基地才显示）──
    if (planet.colonized or planet.isBase) and #planet.buildings > 0 then
        -- 汇总该行星所有建筑的产量
        local prodSum = {}
        for _, b in ipairs(planet.buildings) do
            if b.currentProd then
                for res, val in pairs(b.currentProd) do
                    prodSum[res] = (prodSum[res] or 0) + val
                end
            end
        end
        -- 只显示有产量的资源（minerals/energy/crystal）
        local RES_DISP = {
            { key="minerals", label="矿", r=180,g=140,b=90  },
            { key="energy",   label="能", r=80, g=220,b=255 },
            { key="crystal",  label="晶", r=200,g=120,b=255 },
        }
        local hasAny = false
        for _, rd in ipairs(RES_DISP) do
            if (prodSum[rd.key] or 0) > 0 then hasAny = true; break end
        end
        if hasAny then
            local segW = math.floor((pw - 20) / #RES_DISP)
            for k, rd in ipairs(RES_DISP) do
                local val = prodSum[rd.key] or 0
                local sx2 = px + 10 + (k-1) * segW
                -- 小胶囊背景
                nvgBeginPath(vg); nvgRoundedRect(vg, sx2, sy, segW - 4, 13, 3)
                nvgFillColor(vg, nvgRGBA(rd.r, rd.g, rd.b, val > 0 and 25 or 10)); nvgFill(vg)
                nvgBeginPath(vg); nvgRoundedRect(vg, sx2+0.5, sy+0.5, segW-5, 12, 3)
                nvgStrokeColor(vg, nvgRGBA(rd.r, rd.g, rd.b, val > 0 and 80 or 30))
                nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
                local valStr = val > 0 and string.format("%s+%d/s", rd.label, val) or rd.label.."--"
                local ta = val > 0 and 230 or 80
                nvgFontFace(vg, "sans"); nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(rd.r, rd.g, rd.b, ta))
                nvgText(vg, sx2 + (segW-4)/2, sy + 6.5, valStr)
            end
            sy = sy + 17
        end
    end

    -- P3-2: 产量趋势折线图
    if chartRowH > 0 and prodHistory then
        -- 标题
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 180, 255, 160))
        nvgText(vg, px + 12, sy + 7, "产量趋势")
        -- 图例（右侧）
        local legendItems = {
            { label="矿", r=180,g=140,b=90 },
            { label="能", r=80, g=220,b=255 },
            { label="晶", r=200,g=120,b=255 },
        }
        local lx0 = px + pw - 12
        for i = #legendItems, 1, -1 do
            local li = legendItems[i]
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(li.r, li.g, li.b, 200))
            nvgText(vg, lx0, sy + 7, li.label)
            lx0 = lx0 - 18
        end
        sy = sy + 14

        -- 图表背景
        local cw = pw - 24
        local ch = 38
        local cx = px + 12
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, sy, cw, ch, 3)
        nvgFillColor(vg, nvgRGBA(5, 10, 25, 160)); nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx+0.5, sy+0.5, cw-1, ch-1, 3)
        nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 60))
        nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        -- 水平参考线（中线 + 顶线）
        for _, frac in ipairs({0.25, 0.5, 0.75}) do
            local ry = sy + ch - frac * ch
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx+3, ry); nvgLineTo(vg, cx+cw-3, ry)
            nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 30))
            nvgStrokeWidth(vg, 0.5); nvgStroke(vg)
        end

        -- 求全局最大值（三条线共用 Y 轴比例，便于直观对比）
        local yMax = 1
        local RES_LINES = {
            { key="minerals", r=180,g=140,b=90 },
            { key="energy",   r=80, g=220,b=255 },
            { key="crystal",  r=200,g=120,b=255 },
        }
        for _, rl in ipairs(RES_LINES) do
            local hist = prodHistory[rl.key] or {}
            for _, v in ipairs(hist) do
                if v > yMax then yMax = v end
            end
        end

        local pad = 4
        for _, rl in ipairs(RES_LINES) do
            local hist = prodHistory[rl.key] or {}
            local n = #hist
            if n >= 2 then
                nvgBeginPath(vg)
                for i = 1, n do
                    local xi = cx + pad + (i-1)/(n-1) * (cw - pad*2)
                    local norm = math.min(1.0, hist[i] / yMax)
                    local yi = sy + ch - pad - norm * (ch - pad*2)
                    yi = math.max(sy + pad, math.min(sy + ch - pad, yi))
                    if i == 1 then nvgMoveTo(vg, xi, yi)
                    else nvgLineTo(vg, xi, yi) end
                end
                nvgStrokeColor(vg, nvgRGBA(rl.r, rl.g, rl.b, 200))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                -- 最新数据点圆点标记
                local lxi = cx + pad + (n-1)/(n-1) * (cw - pad*2)
                local normL = math.min(1.0, hist[n] / yMax)
                local lyi = sy + ch - pad - normL * (ch - pad*2)
                lyi = math.max(sy + pad, math.min(sy + ch - pad, lyi))
                nvgBeginPath(vg)
                nvgCircle(vg, lxi, lyi, 2.5)
                nvgFillColor(vg, nvgRGBA(rl.r, rl.g, rl.b, 255)); nvgFill(vg)
            end
        end
        sy = sy + ch + 6
    end

    -- P1-1: 外交区块（仅中立势力未殖民行星）
    if diplomacyRowH > 0 and diplomacyState then
        local ds   = diplomacyState
        local fdef = ds.factionDef or {}
        local favor= math.max(0, math.min(100, ds.favor or 40))
        local fc   = fdef.color or {200, 180, 100}

        -- 区块背景卡片
        local cardX, cardW, cardH = px + 8, pw - 16, diplomacyRowH - 6
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cardX, sy, cardW, cardH, 5)
        nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 18))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cardX + 0.5, sy + 0.5, cardW - 1, cardH - 1, 5)
        nvgStrokeColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 100))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        local dy = sy + 7
        -- 势力图标+名称
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(fc[1], fc[2], fc[3], 230))
        nvgText(vg, cardX + 7, dy, (fdef.icon or "?") .. " " .. (fdef.name or "未知势力"))

        -- 好感度标签（右侧）
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local favorColor
        if ds.atWar then
            favorColor = {255, 80, 80}
        elseif favor >= 90 then
            favorColor = {100, 255, 160}
        elseif favor >= 60 then
            favorColor = {80, 200, 255}
        else
            favorColor = {200, 200, 200}
        end
        nvgFillColor(vg, nvgRGBA(favorColor[1], favorColor[2], favorColor[3], 220))
        nvgText(vg, cardX + cardW - 7, dy,
            ds.atWar and "宣战!" or string.format("好感: %d", favor))

        dy = dy + 14
        -- 好感度进度条
        local barX, barW2, barH2 = cardX + 7, cardW - 14, 7
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, dy, barW2, barH2, 3)
        nvgFillColor(vg, nvgRGBA(20, 20, 40, 160)); nvgFill(vg)
        if favor > 0 then
            local fillW = math.max(2, math.floor(barW2 * favor / 100))
            local r1, g1, b1 = 200, 80, 80
            local r2, g2, b2 = favorColor[1], favorColor[2], favorColor[3]
            local grad = nvgLinearGradient(vg, barX, dy, barX + barW2, dy,
                nvgRGBA(r1, g1, b1, 200), nvgRGBA(r2, g2, b2, 240))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, dy, fillW, barH2, 3)
            nvgFillPaint(vg, grad); nvgFill(vg)
        end
        -- 门槛刻度线
        for _, thresh in ipairs({60, 90}) do
            local tx = barX + math.floor(barW2 * thresh / 100)
            nvgBeginPath(vg)
            nvgMoveTo(vg, tx, dy - 1); nvgLineTo(vg, tx, dy + barH2 + 1)
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 60))
            nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        end

        dy = dy + barH2 + 5
        -- 状态标签
        local statusLabel, sr, sg, sb
        if ds.atWar then
            statusLabel, sr, sg, sb = "⚔ 宣战状态", 255, 80, 80
        elseif ds.military then
            statusLabel, sr, sg, sb = "🛡 军事合作", 100, 255, 160
        elseif favor >= 60 then
            statusLabel, sr, sg, sb = "📦 商贸协议", 80, 200, 255
        else
            statusLabel, sr, sg, sb = "○ 中立", 160, 160, 180
        end
        nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(sr, sg, sb, 220))
        nvgText(vg, cardX + 7, dy, statusLabel)

        -- 礼物按钮（右侧，宣战时禁用）
        if not ds.atWar and onSendGift then
            local costMetal  = (fdef.giftCost and fdef.giftCost.metal)   or 80
            local costEsrc   = (fdef.giftCost and fdef.giftCost.esource) or 50
            local btnW, btnH = 90, 14
            local bx = cardX + cardW - btnW - 2
            local by = dy - 7
            local canAfford = (rm and (rm.resources.metal or 0) >= costMetal
                                   and (rm.resources.esource or 0) >= costEsrc)
            panel(bx, by, btnW, btnH, 4,
                canAfford and {120, 90, 20, 80} or {60, 60, 80, 50},
                canAfford and {220, 170, 40, 200} or {100, 100, 120, 120})
            nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(
                canAfford and 255 or 140,
                canAfford and 220 or 140,
                canAfford and 80 or 100, 240))
            nvgText(vg, bx + btnW / 2, by + btnH / 2,
                string.format("礼物 %dM+%dE", costMetal, costEsrc))
            if canAfford then
                local capturedId = planet.id
                addHit(bx, by, btnW, btnH, function()
                    if onSendGift then onSendGift(capturedId) end
                end)
            end
        end

        -- P2-2: 长期贸易协议行（好感 ≥ 60 且未宣战）
        if not ds.atWar and (favor >= 60) then
            dy = dy + 4  -- 间距
            local ltBtnW, ltBtnH = cardW - 14, 14
            local ltBx = cardX + 7
            local ltBy = dy

            if ds.longTrade then
                -- 协议激活中：显示状态 + 自动购入进度条
                panel(ltBx, ltBy, ltBtnW, ltBtnH, 3, {10, 60, 30, 100}, {30, 160, 80, 160})
                nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(100, 255, 160, 230))
                nvgText(vg, ltBx + 6, ltBy + ltBtnH / 2, "📋 长期协议激活中")
                -- 小进度条（tradeTimer / LONG_TRADE_INTERVAL）
                local S = require("game.Systems")
                local interval = S.LONG_TRADE_INTERVAL or 60
                local pct = math.min(1.0, (ds.tradeTimer or 0) / interval)
                local pbW = ltBtnW - 10
                nvgBeginPath(vg); nvgRoundedRect(vg, ltBx + ltBtnW - pbW - 2, ltBy + 4, pbW, 6, 2)
                nvgFillColor(vg, nvgRGBA(10, 30, 20, 150)); nvgFill(vg)
                if pct > 0 then
                    nvgBeginPath(vg); nvgRoundedRect(vg, ltBx + ltBtnW - pbW - 2, ltBy + 4, math.max(2, pbW * pct), 6, 2)
                    nvgFillColor(vg, nvgRGBA(60, 220, 120, 200)); nvgFill(vg)
                end
            else
                -- 协议未激活：显示激活按钮
                local S = require("game.Systems")
                local cost = S.LONG_TRADE_COST or { crystal = 100 }
                local maxTrades = S.MAX_LONG_TRADES or 3
                local crystalCost = cost.crystal or 100
                local canAffordLT = rm and (rm.resources.crystal or 0) >= crystalCost
                panel(ltBx, ltBy, ltBtnW, ltBtnH, 3,
                    canAffordLT and {40, 20, 80, 90} or {50, 50, 70, 50},
                    canAffordLT and {140, 80, 255, 200} or {80, 80, 100, 120})
                nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(
                    canAffordLT and 200 or 120,
                    canAffordLT and 140 or 120,
                    canAffordLT and 255 or 160, 240))
                nvgText(vg, ltBx + ltBtnW / 2, ltBy + ltBtnH / 2,
                    string.format("📋 长期协议 (晶体×%d)", crystalCost))
                if canAffordLT and onActivateLongTrade then
                    local capturedId = planet.id
                    addHit(ltBx, ltBy, ltBtnW, ltBtnH, function()
                        onActivateLongTrade(capturedId)
                    end)
                end
            end
        end

        sy = sy + diplomacyRowH
    end

    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(60,110,255,80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- === 可滚动区域 ===
    local clipY1 = scrollStartY
    local clipY2 = py + ph

    addScroll(px, clipY1, pw, scrollAreaH, function(delta)
        scrollY_ = scrollY_ - delta * 30
    end)

    nvgSave(vg)
    nvgScissor(vg, px+1, clipY1, pw-2, scrollAreaH)

    local function vy2sy(vy) return vy - scrollY_ end
    local function isVis(vy, h)
        local s = vy - scrollY_
        return s + h > clipY1 and s < clipY2
    end

    local vy = clipY1 + 6

    if isVis(vy, 14) then
        text(px+14, vy2sy(vy)+7, "模块建造:", 10, 160,200,255,200)
    end
    vy = vy + 18

    for _, key in ipairs(BUILD_ORDER) do
        local sy2 = vy2sy(vy)
        if sy2 + 18 > clipY1 and sy2 < clipY2 then
            local bd      = BUILDINGS[key]
            local canB, _ = bs:canBuild(key, planet)
            local costStr = rm:fmtCost(bd.cost)
            local bx, bw, bh = px+8, pw-16, 18

            -- H4：二次确认逻辑
            if planetBuildPending_ == key then
                -- 确认行：✓ 确认 / ✗ 取消（按压缩放）
                local hbW = (bw - 3) / 2
                -- P3-2: 确认按钮按压动画
                local confKey = "bconf_" .. key
                local csc = getPressScale(confKey)
                local confCx, confCy = bx + hbW/2, sy2 + bh/2
                if csc ~= 1.0 then nvgSave(vg); nvgTranslate(vg, confCx, confCy); nvgScale(vg, csc, csc); nvgTranslate(vg, -confCx, -confCy) end
                panel(bx, sy2, hbW, bh, 4, {30,150,70,100},{50,200,90,220})
                text(bx+hbW/2, sy2+bh/2, "✓ 确认", 10, 150,255,170,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                if csc ~= 1.0 then nvgRestore(vg) end
                local ck = key
                addHit(bx, sy2, hbW, bh, function()
                    triggerPress(confKey)
                    planetBuildPending_ = nil
                    if onBuild then onBuild(ck, false, nil) end
                end)
                local bx2 = bx + hbW + 3
                panel(bx2, sy2, hbW, bh, 4, {150,40,40,100},{200,70,70,220})
                text(bx2+hbW/2, sy2+bh/2, "✗ 取消", 10, 255,140,140,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(bx2, sy2, hbW, bh, function() planetBuildPending_ = nil end)
            else
                -- P3-2: 按压缩放 + 资源不足抖动
                local sc  = getPressScale(key)
                local shX = getShakeOffset(key)
                local rbx = bx + shX
                local btnCx, btnCy = rbx + bw/2, sy2 + bh/2
                if sc ~= 1.0 then nvgSave(vg); nvgTranslate(vg, btnCx, btnCy); nvgScale(vg, sc, sc); nvgTranslate(vg, -btnCx, -btnCy) end
                -- 资源不足红色闪烁叠加（shake 进行中）
                local shakeAnim = animStates_[key]
                if shakeAnim and shakeAnim.type == "shake" then
                    local t = shakeAnim.timer / shakeAnim.maxTime
                    local flashA = math.floor(t * 60)
                    nvgBeginPath(vg); nvgRoundedRect(vg, rbx, sy2, bw, bh, 4)
                    nvgFillColor(vg, nvgRGBA(220, 60, 60, flashA)); nvgFill(vg)
                end
                panel(rbx, sy2, bw, bh, 4,
                    {canB and 50 or 50, canB and 120 or 80, canB and 255 or 140, 60},
                    {canB and 50 or 50, canB and 120 or 80, canB and 255 or 140, 180})
                text(rbx+bw/2, sy2+bh/2, bd.name.."  ["..costStr.."]", 10,
                    canB and 110 or 110, canB and 180 or 140, canB and 255 or 200, 240,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                if sc ~= 1.0 then nvgRestore(vg) end
                -- 始终注册点击区（可建→进入确认；不可建→抖动提示）
                local ck = key
                addHit(rbx, sy2, bw, bh, function()
                    if canB then
                        triggerPress(ck)
                        planetBuildPending_   = ck
                        planetUpgradePending_ = nil
                    else
                        triggerShake(ck)
                    end
                end)
            end
        end
        vy = vy + 21
    end

    local sepSy = vy2sy(vy)
    if sepSy > clipY1 and sepSy < clipY2 then
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sepSy+2); nvgLineTo(vg, px+pw-8, sepSy+2)
        nvgStrokeColor(vg, clr(60,110,255,40)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    vy = vy + 12

    if isVis(vy, 14) then
        text(px+14, vy2sy(vy)+7, "已安装:", 10, 160,200,255,200)
    end
    vy = vy + 17

    if #planet.buildings == 0 then
        if isVis(vy, 14) then
            text(px+14, vy2sy(vy)+7, "尚未安装任何模块", 10, 120,130,160,180)
        end
    else
        for bldIdx, b in ipairs(planet.buildings) do
            local sy2 = vy2sy(vy)
            if sy2 + 20 > clipY1 and sy2 < clipY2 then
                -- P3-2: 建造完成高亮背景叠加
                local hlA = getHighlightAlpha(planet.id, b.key)
                if hlA > 0 then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, px+8, sy2-1, pw-16, 20, 3)
                    nvgFillColor(vg, nvgRGBA(80, 220, 130, hlA))
                    nvgFill(vg)
                end

                text(px+14, sy2+8, "▸ " .. b.name .. " Lv." .. b.level, 10, 140,175,230,220)
                -- P2-3: 专精槽图标（Lv.3+ 才显示，在升级按钮左侧）
                local bx, bw, bh = px+pw-88, 84, 16
                if b.level >= 3 then
                    local sx, sr = bx - 22, 8
                    local hasSp = b.spec ~= nil
                    -- P3-2: 专精激活光晕扩散（在圆圈之前绘制，靠后层）
                    local glowR, glowA = getGlowParams(planet.id, bldIdx)
                    if glowA > 0 then
                        nvgBeginPath(vg)
                        nvgCircle(vg, sx, sy2+bh/2, sr + glowR)
                        nvgFillColor(vg, nvgRGBA(80, 255, 180, glowA))
                        nvgFill(vg)
                    end
                    nvgBeginPath(vg)
                    nvgCircle(vg, sx, sy2+bh/2, sr)
                    if hasSp then
                        nvgFillColor(vg, nvgRGBA(80,220,160,220))
                    else
                        nvgFillColor(vg, nvgRGBA(60,80,110,180))
                    end
                    nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(100,180,255,160))
                    nvgStrokeWidth(vg, 1.0)
                    nvgStroke(vg)
                    nvgFontSize(vg, 9)
                    nvgFontFace(vg, "sans")
                    nvgFillColor(vg, nvgRGBA(220,240,255,240))
                    nvgTextAlign(vg, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    nvgText(vg, sx, sy2+bh/2, hasSp and "✦" or "+")
                    local ci = bldIdx
                    addHit(sx-sr, sy2, sr*2, bh, function()
                        if specModalBld_ == ci then
                            specModalBld_ = nil
                        else
                            specModalBld_ = ci
                            planetBuildPending_   = nil
                            planetUpgradePending_ = nil
                        end
                    end)
                end
                local canUp   = bs:canUpgrade(bldIdx, planet)
                local cost    = bs:getUpgradeCost(b.key, b.level)
                local costStr = rm:fmtCost(cost)
                -- H4：升级二次确认
                local isPending = planetUpgradePending_ and
                    planetUpgradePending_.idx == bldIdx and
                    planetUpgradePending_.key == b.key
                if isPending then
                    local gap = 2
                    local hbW = math.floor((bw - gap * 2) / 3)
                    -- P3-2: 确认按钮按压动画
                    local uconfKey = "uconf_" .. bldIdx
                    local ucsc = getPressScale(uconfKey)
                    local ucCx, ucCy = bx + hbW/2, sy2 + bh/2
                    if ucsc ~= 1.0 then nvgSave(vg); nvgTranslate(vg, ucCx, ucCy); nvgScale(vg, ucsc, ucsc); nvgTranslate(vg, -ucCx, -ucCy) end
                    panel(bx, sy2, hbW, bh, 4, {30,150,70,100},{50,200,90,220})
                    text(bx+hbW/2, sy2+bh/2, "✓", 10, 150,255,170,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    if ucsc ~= 1.0 then nvgRestore(vg) end
                    local ci, ck = bldIdx, b.key
                    addHit(bx, sy2, hbW, bh, function()
                        triggerPress(uconfKey)
                        planetUpgradePending_ = nil
                        if onBuild then onBuild(ck, true, ci) end
                    end)
                    -- P3-3.3: 批量升级按钮
                    local bx2 = bx + hbW + gap
                    panel(bx2, sy2, hbW, bh, 4, {30,100,160,100},{50,140,220,220})
                    text(bx2+hbW/2, sy2+bh/2, "⏫全", 9, 120,200,255,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx2, sy2, hbW, bh, function()
                        planetUpgradePending_ = nil
                        if onBatchUpgrade then onBatchUpgrade(ci) end
                    end)
                    -- 取消按钮
                    local bx3 = bx2 + hbW + gap
                    panel(bx3, sy2, hbW, bh, 4, {150,40,40,100},{200,70,70,220})
                    text(bx3+hbW/2, sy2+bh/2, "✗", 10, 255,140,140,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx3, sy2, hbW, bh, function() planetUpgradePending_ = nil end)
                else
                    -- P3-2: 升级按钮按压缩放 + 资源不足抖动
                    local upKey = "up_" .. tostring(bldIdx)
                    local usc  = getPressScale(upKey)
                    local ushX = getShakeOffset(upKey)
                    local ubx  = bx + ushX
                    local ubtnCx, ubtnCy = ubx + bw/2, sy2 + bh/2
                    if usc ~= 1.0 then nvgSave(vg); nvgTranslate(vg, ubtnCx, ubtnCy); nvgScale(vg, usc, usc); nvgTranslate(vg, -ubtnCx, -ubtnCy) end
                    -- 资源不足红色闪烁
                    local ushakeAnim = animStates_[upKey]
                    if ushakeAnim and ushakeAnim.type == "shake" then
                        local t = ushakeAnim.timer / ushakeAnim.maxTime
                        nvgBeginPath(vg); nvgRoundedRect(vg, ubx, sy2, bw, bh, 4)
                        nvgFillColor(vg, nvgRGBA(220, 60, 60, math.floor(t * 60))); nvgFill(vg)
                    end
                    panel(ubx, sy2, bw, bh, 4,
                        {canUp and 220 or 100, canUp and 160 or 100, canUp and 50 or 60, 60},
                        {canUp and 220 or 100, canUp and 160 or 100, canUp and 50 or 60, 180})
                    text(ubx+bw/2, sy2+bh/2, "升级["..costStr.."]", 10,
                        canUp and 255 or 160, canUp and 220 or 160, canUp and 110 or 120, 240,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    if usc ~= 1.0 then nvgRestore(vg) end
                    -- 始终注册点击区
                    local ci, ck = bldIdx, b.key
                    addHit(ubx, sy2, bw, bh, function()
                        if canUp then
                            triggerPress(upKey)
                            planetUpgradePending_ = { idx=ci, key=ck }
                            planetBuildPending_   = nil
                        else
                            triggerShake(upKey)
                        end
                    end)
                end
            end
            vy = vy + 20
        end
    end

    nvgRestore(vg)

    -- P2-3: 专精选择模态框（不受 scissor 裁剪，渲染在 scroll 区域之上）
    if specModalBld_ then
        local b = planet.buildings[specModalBld_]
        if b and b.level >= 3 then
            local specs    = bs:getSpecsForBuilding(b.key)
            local mw, mh   = 240, 16 + #specs * 40 + 14
            local mx       = px + pw/2 - mw/2
            -- 定位在面板中部
            local my       = math.max(clipY1 + 4, clipY1 + (clipY2 - clipY1)/2 - mh/2)
            -- 背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, mx, my, mw, mh, 8)
            nvgFillColor(vg, nvgRGBA(12,20,38,240))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(80,160,255,180))
            nvgStrokeWidth(vg, 1.2)
            nvgStroke(vg)
            -- 标题
            nvgFontSize(vg, 11)
            nvgFontFace(vg, "sans")
            nvgFillColor(vg, nvgRGBA(180,210,255,240))
            nvgTextAlign(vg, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            nvgText(vg, mx+mw/2, my+10, b.name .. " — 选择专精  (消耗晶石×" .. tostring(SPEC_COST) .. ")")
            -- 专精选项
            for i, sp in ipairs(specs) do
                local iy  = my + 16 + (i-1)*40
                local iw, ih = mw - 16, 36
                local ix  = mx + 8
                local isSel = b.spec == sp.key
                local canAff = rm:canAfford({crystal = SPEC_COST})
                -- 选项背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, ix, iy, iw, ih, 5)
                if isSel then
                    nvgFillColor(vg, nvgRGBA(30,100,60,200))
                elseif canAff then
                    nvgFillColor(vg, nvgRGBA(25,45,80,180))
                else
                    nvgFillColor(vg, nvgRGBA(40,35,35,160))
                end
                nvgFill(vg)
                nvgStrokeColor(vg, isSel and nvgRGBA(80,230,140,200) or nvgRGBA(60,100,160,120))
                nvgStrokeWidth(vg, 1.0)
                nvgStroke(vg)
                -- 名称
                nvgFontSize(vg, 11)
                nvgFillColor(vg, isSel and nvgRGBA(120,255,180,255) or nvgRGBA(200,220,255,220))
                nvgTextAlign(vg, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
                nvgText(vg, ix+8, iy+12, (isSel and "✦ " or "○ ") .. sp.name)
                -- 描述
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(140,180,200,180))
                nvgText(vg, ix+8, iy+26, sp.desc)
                -- 点击
                if not isSel then
                    local ci2 = specModalBld_
                    local sk  = sp.key
                    addHit(ix, iy, iw, ih, function()
                        if onSetSpec then onSetSpec(planet.id, ci2, sk) end
                        specModalBld_ = nil
                    end)
                end
            end
            -- 关闭按钮
            local cx, cy = mx+mw-14, my+8
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(180,120,120,220))
            nvgTextAlign(vg, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            nvgText(vg, cx, cy, "✕")
            addHit(cx-8, cy-8, 16, 16, function() specModalBld_ = nil end)
        else
            specModalBld_ = nil
        end
    end

    -- 滚动条
    if maxScroll > 0 then
        local sbH = math.max(16, scrollAreaH * scrollAreaH / (scrollContentH + 1))
        local sbY = clipY1 + (scrollAreaH - sbH) * (scrollY_ / maxScroll)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px+pw-4, sbY, 3, sbH, 1.5)
        nvgFillColor(vg, nvgRGBA(68,136,255,140))
        nvgFill(vg)
    end
end

return PlanetPanel


-- NOTE: 此文件已被 code_health_check.py 自动拆分，详见同目录 *_part*.lua 文件。
