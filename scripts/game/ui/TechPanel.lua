-- ============================================================================
-- game/ui/TechPanel.lua  -- 科研面板（左侧，可滚动）
-- ============================================================================
local UICommon  = require("game.ui.UICommon")
local TechPanel = {}

-- 面板私有状态
local scrollY_   = 0
local collapsed_ = false

--- 外部重置滚动（换星球时调用）
function TechPanel.ResetScroll()
    scrollY_ = 0
end

--- 渲染科研面板
--- @param ctx table
---   .selectedPlanet  table    当前选中星球（nil = 无选中）
---   .onResearch      function 点击研究按钮的回调 function(id)
function TechPanel.Render(ctx)
    -- 每帧重置导出高度（不渲染时为 0，供 Shipyard 面板定位使用）
    UICommon.techPanelH = 0

    local vg       = UICommon.vg
    local screenH  = UICommon.screenH
    local rm       = UICommon.rm
    local rs       = UICommon.rs
    local clr      = UICommon.clr
    local panel    = UICommon.panel
    local text     = UICommon.text
    local addHit   = UICommon.addHit
    local addScroll = UICommon.addScroll

    if not rs then return end
    local selectedPlanet = ctx.selectedPlanet
    if not selectedPlanet or not selectedPlanet.colonized then return end

    -- 仅当星球有科研中心时显示
    local hasLab = false
    if selectedPlanet.buildings then
        for _, b in ipairs(selectedPlanet.buildings) do
            if b.key == "RESEARCH_LAB" or b.key == "RESEARCH_CENTER" then
                hasLab = true; break
            end
        end
    end
    if not hasLab then return end

    local px, py = 12, (UICommon.PANEL_TOP or 48)
    local pw = 230

    -- 估算内容总高度
    local statusH  = rs.active and 36 or 20
    local techRowH = {}
    for _, id in ipairs(TECH_ORDER) do
        local showResRow = not rs.unlocked[id]
                           and not (rs.active and rs.active.id == id)
        techRowH[id] = showResRow and 42 or 26
    end
    local totalH = statusH + 8
    for _, id in ipairs(TECH_ORDER) do totalH = totalH + techRowH[id] end

    local maxPanelH    = screenH - py - 16
    local ph           = math.min(totalH + 30, maxPanelH)
    if collapsed_ then ph = 30 end

    -- 导出实际渲染高度（供 Shipyard 面板在下方定位）
    UICommon.techPanelH = ph

    local contentAreaH = ph - 22
    local maxScroll    = math.max(0, totalH - contentAreaH)
    scrollY_ = math.max(0, math.min(maxScroll, scrollY_))

    panel(px, py, pw, ph, 7, {10,18,38,235}, {60,120,255,200})

    -- 标题栏
    local titleY = py + 14
    text(px+10, titleY, "[ 科研中心 ]", 13, 80,160,255,255)
    local btnLbl = collapsed_ and "▼" or "▲"
    text(px+pw-22, titleY, btnLbl, 11, 100,150,255,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    addHit(px, py, pw, 22, function()
        collapsed_ = not collapsed_
        scrollY_ = 0
    end)
    if collapsed_ then return end

    -- 滚动区域
    addScroll(px, py+22, pw, contentAreaH, function(delta)
        scrollY_ = scrollY_ - delta * 30
    end)

    nvgSave(vg)
    nvgScissor(vg, px+1, py+22, pw-2, contentAreaH)

    local clipY1 = py + 22
    local clipY2 = py + ph
    local function sy2screen(vy) return vy - scrollY_ end
    local function isVis(vy, h)
        local sy = vy - scrollY_
        return sy + h > clipY1 and sy < clipY2
    end

    local vy = clipY1 + 8

    -- 当前研发状态
    if rs.active then
        local a    = rs.active
        local pct  = a.progress or 0
        local tech = TECHS[a.id]
        if isVis(vy, 20) then
            text(px+10, sy2screen(vy), "研发: " .. tech.name, 10, 80,220,150,255)
        end
        if isVis(vy+10, 8) then
            -- 进度条
            local bx2, by2, bw2, bh2 = px+10, sy2screen(vy)+10, pw-20, 8
            nvgBeginPath(vg); nvgRoundedRect(vg, bx2, by2, bw2, bh2, 3)
            nvgFillColor(vg, clr(20,40,20,180)); nvgFill(vg)
            if pct > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, bx2, by2, bw2*pct, bh2, 3)
                nvgFillColor(vg, clr(60,200,120,220)); nvgFill(vg)
            end
        end
        vy = vy + 28
    else
        if isVis(vy, 16) then
            text(px+10, sy2screen(vy), "空闲中 — 选择科技", 10, 120,140,160,200)
        end
        vy = vy + 20
    end

    -- 分隔线
    local sepSy = sy2screen(vy)
    if sepSy > clipY1 and sepSy < clipY2 then
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sepSy); nvgLineTo(vg, px+pw-8, sepSy)
        nvgStrokeColor(vg, clr(60,120,255,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    vy = vy + 8

    -- 科技列表
    for _, id in ipairs(TECH_ORDER) do
        local t        = TECHS[id]
        local ok       = rs:canResearch(id)
        local unlocked = rs.unlocked[id]
        local active   = rs.active and rs.active.id == id
        local rowH     = techRowH[id]
        local showResRow = rowH > 26

        local stateStr, sr,sg,sb
        if unlocked then
            stateStr="✓"; sr,sg,sb=50,220,100
        elseif active then
            stateStr="▶"; sr,sg,sb=50,200,255
        elseif ok then
            stateStr="→"; sr,sg,sb=200,220,100
        elseif showResRow then
            stateStr="!"; sr,sg,sb=255,180,50
        else
            stateStr="●"; sr,sg,sb=100,100,120
        end

        if isVis(vy, rowH) then
            local sy = sy2screen(vy)
            text(px+8,  sy+9,  stateStr, 12, sr,sg,sb,240, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
            text(px+22, sy+5,  t.name,   11, 180,210,255,unlocked and 180 or 230)
            text(px+22, sy+17, t.desc,   9,  120,145,190,170)
            if showResRow then
                local rx = px + 22
                local ry = sy + 28
                for _, res in ipairs(RES_ORDER) do
                    local need = t.cost[res] or 0
                    if need > 0 then
                        local have   = rm.resources[res] or 0
                        local enough = have >= need
                        local cr, cg, cb = enough and 80 or 255, enough and 220 or 80, enough and 100 or 60
                        local label  = RES_LABELS[res] .. ":" .. math.floor(have) .. "/" .. need
                        text(rx, ry, label, 9, cr, cg, cb, 230)
                        rx = rx + #label * 6 + 8
                    end
                end
            end
            if ok and not unlocked and not active then
                local capturedId = id
                local costStr    = rm:fmtCost(t.cost)
                local bx3, by3   = px+pw-85, sy+2
                local bw3, bh3   = 82, 18
                if by3 >= clipY1 and by3 + bh3 <= clipY2 then
                    panel(bx3, by3, bw3, bh3, 4, {50,150,255,60}, {50,150,255,180})
                    text(bx3+bw3/2, by3+bh3/2, "研究["..costStr.."]", 10, 110,210,255,240,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx3, by3, bw3, bh3, function()
                        if ctx.onResearch then ctx.onResearch(capturedId) end
                    end)
                elseif by3 + bh3 > clipY1 and by3 < clipY2 then
                    -- L2: 部分可见时也注册点击区域，否则边缘按钮无法响应
                    panel(bx3, by3, bw3, bh3, 4, {50,150,255,60}, {50,150,255,180})
                    text(bx3+bw3/2, by3+bh3/2, "研究["..costStr.."]", 10, 110,210,255,240,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx3, by3, bw3, bh3, function()
                        if ctx.onResearch then ctx.onResearch(capturedId) end
                    end)
                end
            end
        end
        vy = vy + rowH
    end

    nvgRestore(vg)

    -- 滚动条
    if maxScroll > 0 then
        local sbH = math.max(16, contentAreaH * contentAreaH / (totalH + 1))
        local sbY = clipY1 + (contentAreaH - sbH) * (scrollY_ / maxScroll)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px+pw-4, sbY, 3, sbH, 1.5)
        nvgFillColor(vg, nvgRGBA(100,150,255,140))
        nvgFill(vg)
    end
end

return TechPanel
