--- 帝国运营总览面板模块
--- 负责渲染全屏星球网格、批量建造、帝国总产量汇总

local UICommon = require("game.ui.UICommon")

local EmpirePanel = {}

-- ============================================================================
-- 面板私有状态
-- ============================================================================
local visible_  = false   -- 面板是否显示
local scroll_   = 0       -- 网格滚动偏移
local checked_  = {}      -- { [planetName]=true } 批量选中

-- ============================================================================
-- 公开 API（由 GameUI 调用）
-- ============================================================================

function EmpirePanel.IsVisible()  return visible_  end

function EmpirePanel.Toggle()
    visible_ = not visible_
    scroll_  = 0
    if not visible_ then checked_ = {} end
end

function EmpirePanel.Show()
    visible_ = true
    scroll_  = 0
end

function EmpirePanel.Hide()
    visible_  = false
    scroll_   = 0
    checked_  = {}
end

--- 重置所有状态（新局开始时由 GameUI.Reset 调用）
function EmpirePanel.Reset()
    visible_  = false
    scroll_   = 0
    checked_  = {}
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 渲染帝国运营总览面板
---@param getColonizedPlanetsCb  function()→planets[]
---@param onPlanetJumpCb         function(planet)
---@param onBatchBuildCb         function(checkedNames[])
function EmpirePanel.Render(getColonizedPlanetsCb, onPlanetJumpCb, onBatchBuildCb)
    if not visible_ then return end
    if not getColonizedPlanetsCb then return end

    local planets = getColonizedPlanetsCb()
    if not planets or #planets == 0 then
        visible_ = false
        return
    end

    local vg  = UICommon.vg
    local W   = UICommon.screenW
    local H   = UICommon.screenH

    -- 全屏遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
    nvgFill(vg)

    -- 面板区域
    local PAD    = 12
    local HEADER = 34
    local pw     = math.min(W - 24, 520)
    local ph     = H - 60
    local px     = (W - pw) / 2
    local py     = 30

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgFillColor(vg, nvgRGBA(8, 16, 36, 245))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 10)
    nvgStrokeColor(vg, nvgRGBA(60, 140, 255, 160))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 210, 255, 255))
    nvgText(vg, px + PAD, py + HEADER / 2, "🏛️ 帝国运营总览")

    -- 关闭按钮
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 200))
    nvgText(vg, px + pw - 18, py + HEADER / 2, "✕")
    UICommon.addHit(px + pw - 28, py + 2, 26, 26, function() visible_ = false end)

    -- 分割线
    local sepY = py + HEADER
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 6, sepY)
    nvgLineTo(vg, px + pw - 6, sepY)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 60))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 卡片网格参数
    local CARD_W   = math.min(230, (pw - PAD * 3) / 2)
    local CARD_H   = 100
    local GAP      = 8
    local cols     = math.max(1, math.floor((pw - PAD * 2 + GAP) / (CARD_W + GAP)))
    local contentY = sepY + 6
    local contentH = ph - HEADER - 56  -- 留出底部汇总行
    local totalRows = math.ceil(#planets / cols)
    local totalContentH = totalRows * (CARD_H + GAP) - GAP
    -- 限制滚动
    local maxScroll = math.max(0, totalContentH - contentH)
    scroll_ = math.max(0, math.min(scroll_, maxScroll))

    -- 裁剪区
    nvgSave(vg)
    nvgScissor(vg, px + PAD - 2, contentY, pw - PAD * 2 + 4, contentH)

    -- 渲染每颗星球卡片
    local RES_COLORS = {
        minerals = {120, 200, 255},
        energy   = {255, 220, 60},
        crystal  = {200, 120, 255},
        credits  = {255, 200, 60},
    }
    for idx, planet in ipairs(planets) do
        if planet.isBase then goto continue_empire end
        local row = math.floor((idx - 1) / cols)
        local col = (idx - 1) % cols
        local cx  = px + PAD + col * (CARD_W + GAP)
        local cy  = contentY + row * (CARD_H + GAP) - scroll_

        -- 卡片可见性检查
        if cy + CARD_H < contentY or cy > contentY + contentH then
            goto continue_empire
        end

        -- 卡片背景
        local isChecked = checked_[planet.name] == true
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, CARD_W, CARD_H, 6)
        nvgFillColor(vg, isChecked and nvgRGBA(20, 60, 120, 200) or nvgRGBA(12, 24, 50, 200))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, CARD_W, CARD_H, 6)
        nvgStrokeColor(vg, isChecked and nvgRGBA(80, 180, 255, 200) or nvgRGBA(40, 80, 140, 120))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 勾选框
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx + 4, cy + 4, 14, 14, 3)
        nvgFillColor(vg, isChecked and nvgRGBA(40, 140, 255, 220) or nvgRGBA(20, 40, 70, 160))
        nvgFill(vg)
        if isChecked then
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, cx + 11, cy + 11, "✓")
        end
        -- 勾选点击区
        local capturedName = planet.name
        UICommon.addHit(cx + 2, cy + 2, 18, 18, function()
            checked_[capturedName] = not checked_[capturedName]
        end)

        -- 星球名 + 等级
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 230, 255, 255))
        local nameStr = (planet.name or "?") .. "  Lv." .. (planet.level or 1)
        nvgText(vg, cx + 22, cy + 12, nameStr)

        -- 建筑数 / 槽位
        local bldCount = planet.buildings and #planet.buildings or 0
        local maxSlots = math.min(8, 4 + ((planet.level or 1) - 1))
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 180, 220, 200))
        nvgText(vg, cx + CARD_W - 6, cy + 12, bldCount .. "/" .. maxSlots .. " 建筑")

        -- 资源产量汇总
        local prodSums = {}
        if planet.buildings then
            for _, b in ipairs(planet.buildings) do
                if b.currentProd then
                    for res, val in pairs(b.currentProd) do
                        prodSums[res] = (prodSums[res] or 0) + val
                    end
                end
            end
        end
        local resY = cy + 28
        local resX = cx + 6
        local resOrder = {"minerals", "energy", "crystal", "credits"}
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        for _, res in ipairs(resOrder) do
            local val = prodSums[res] or 0
            if val > 0 then
                local c = RES_COLORS[res] or {200, 200, 200}
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 230))
                local icon = UICommon.resIcons[res]
                if icon and icon >= 0 then
                    local paint = nvgImagePattern(vg, resX, resY - 5, 10, 10, 0, icon, 1.0)
                    nvgBeginPath(vg); nvgRect(vg, resX, resY - 5, 10, 10)
                    nvgFillPaint(vg, paint); nvgFill(vg)
                    nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 230))
                end
                nvgText(vg, resX + 12, resY, "+" .. val .. "/s")
                resX = resX + 52
            end
        end

        -- 建造队列
        local queueY = cy + 46
        nvgFontSize(vg, 8)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        if planet.constructing then
            local job = planet.constructing
            local bDef = BUILDINGS[job.key]
            local jName = bDef and bDef.name or job.key
            local pct = math.floor((job.progress or 0) * 100)
            nvgFillColor(vg, nvgRGBA(80, 220, 140, 220))
            nvgText(vg, cx + 6, queueY, "🔨 " .. jName .. " " .. pct .. "%")
            -- 进度条
            local barW = CARD_W - 12
            local barH = 4
            local barY = queueY + 8
            nvgBeginPath(vg); nvgRoundedRect(vg, cx + 6, barY, barW, barH, 2)
            nvgFillColor(vg, nvgRGBA(20, 40, 60, 160)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, cx + 6, barY, barW * (job.progress or 0), barH, 2)
            nvgFillColor(vg, nvgRGBA(60, 200, 120, 220)); nvgFill(vg)
            -- 剩余时间
            local rem = math.ceil(job.remaining or 0)
            nvgFillColor(vg, nvgRGBA(160, 200, 230, 180))
            nvgText(vg, cx + 6, barY + 10, rem .. "s 剩余")
            -- 队列中等待项
            if planet.buildQueue and #planet.buildQueue > 0 then
                local qStr = "队列: "
                for qi = 1, math.min(2, #planet.buildQueue) do
                    local qj = planet.buildQueue[qi]
                    local qDef = BUILDINGS[qj.key]
                    qStr = qStr .. (qDef and qDef.name or qj.key)
                    if qi < math.min(2, #planet.buildQueue) then qStr = qStr .. ", " end
                end
                nvgFillColor(vg, nvgRGBA(120, 160, 200, 160))
                nvgText(vg, cx + 6, barY + 22, qStr)
            end
        else
            nvgFillColor(vg, nvgRGBA(100, 130, 160, 140))
            nvgText(vg, cx + 6, queueY, "无建造任务")
        end

        -- 点击卡片跳转（排除勾选区域）
        local capturedPlanet = planet
        UICommon.addHit(cx + 20, cy, CARD_W - 20, CARD_H, function()
            visible_ = false
            if onPlanetJumpCb then onPlanetJumpCb(capturedPlanet) end
        end)

        ::continue_empire::
    end

    nvgRestore(vg)

    -- 滚动区域注册
    UICommon.addScroll(px, contentY, pw, contentH,
        function(dy) scroll_ = math.max(0, math.min(maxScroll, scroll_ - dy * 20)) end)

    -- ========== 底部汇总行 ==========
    local sumY  = py + ph - 48
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 6, sumY)
    nvgLineTo(vg, px + pw - 6, sumY)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 200, 60))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 帝国总产量
    local totalProd = { minerals = 0, energy = 0, crystal = 0, credits = 0 }
    for _, p in ipairs(planets) do
        if not p.isBase and p.buildings then
            for _, b in ipairs(p.buildings) do
                if b.currentProd then
                    for res, val in pairs(b.currentProd) do
                        if totalProd[res] then totalProd[res] = totalProd[res] + val end
                    end
                end
            end
        end
    end
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 210, 255, 200))
    nvgText(vg, px + PAD, sumY + 14, "帝国总产量:")
    local sumX = px + PAD + 72
    local resOrder2 = {"minerals", "energy", "crystal", "credits"}
    for _, res in ipairs(resOrder2) do
        local val = totalProd[res]
        if val > 0 then
            local c = RES_COLORS[res] or {200,200,200}
            local icon = UICommon.resIcons[res]
            if icon and icon >= 0 then
                local paint = nvgImagePattern(vg, sumX, sumY + 8, 12, 12, 0, icon, 1.0)
                nvgBeginPath(vg); nvgRect(vg, sumX, sumY + 8, 12, 12)
                nvgFillPaint(vg, paint); nvgFill(vg)
            end
            nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 240))
            nvgText(vg, sumX + 14, sumY + 14, "+" .. val .. "/s")
            sumX = sumX + 62
        end
    end

    -- 批量建造按钮
    local hasChecked = false
    for _, v in pairs(checked_) do if v then hasChecked = true; break end end
    local btnW = 80
    local btnH = 22
    local btnX = px + pw - btnW - PAD
    local btnY = sumY + 6
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
    nvgFillColor(vg, hasChecked and nvgRGBA(30, 100, 200, 220) or nvgRGBA(30, 40, 60, 140))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
    nvgStrokeColor(vg, hasChecked and nvgRGBA(80, 180, 255, 200) or nvgRGBA(50, 70, 100, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, hasChecked and nvgRGBA(200, 240, 255, 255) or nvgRGBA(100, 130, 160, 140))
    nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "同步建造")
    if hasChecked and onBatchBuildCb then
        UICommon.addHit(btnX, btnY, btnW, btnH, function()
            local names = {}
            for name, v in pairs(checked_) do
                if v then names[#names + 1] = name end
            end
            onBatchBuildCb(names)
        end)
    end

    -- 全屏遮罩点击关闭（低优先级，在面板外围）
    UICommon.addHit(0, 0, px, H, function() visible_ = false end)
    UICommon.addHit(px + pw, 0, W - px - pw, H, function() visible_ = false end)
end

return EmpirePanel
