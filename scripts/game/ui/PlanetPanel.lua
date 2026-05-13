--- 行星面板模块
--- 负责渲染行星建造、已安装模块、殖民状态、建造队列

local UICommon = require("game.ui.UICommon")

local PlanetPanel = {}

-- 面板私有状态
local scrollY_           = 0
local planetBuildPending_   = nil   -- H4: 行星建造待确认（key string）
local planetUpgradePending_ = nil   -- H4: 行星升级待确认 {idx, key}

function PlanetPanel.ResetScroll()
    scrollY_ = 0
    planetBuildPending_   = nil
    planetUpgradePending_ = nil
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
    local onBuild        = ctx.onBuild
    local onSpeedUpBuild = ctx.onSpeedUpBuild
    local progressBar    = ctx.progressBar

    local pw = 275
    local px = screenW - pw - 12
    local py = UICommon.PANEL_TOP or 48

    local headerH = 36 + 18 + (planet.constructing and 22 or 16) + 16

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
        text(px+pw/2, sy,
            planet.ptype.."行星  大小:"..string.format("%.1f",planet.size).."  槽位:"..#planet.buildings.."/10",
            9, 130,160,220,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    end
    sy = sy + 16

    if planet.isBase then
        text(px+14, sy, "★ 星航基地", 11, 80, 200, 255, 255)
        sy = sy + 18
    elseif planet.colonized then
        text(px+14, sy, "● 已探索", 11, 50,220,100,255)
        sy = sy + 18
    else
        text(px+14, sy, "○ 未探索  (派遣探索舰探索)", 11, 200,160,60,220)
        sy = sy + 18
    end

    if planet.constructing then
        local job = planet.constructing
        local pct = job.progress or 0
        local tag = job.isUpgrade and "升级" or "建造"
        local barW = onSpeedUpBuild and (pw - 58) or (pw - 20)
        progressBar(px+10, sy, barW, 12, pct,
            tag..": "..BUILDINGS[job.key].name.." "..math.floor(pct*100).."%", 68,180,255)
        -- 加速按钮
        if onSpeedUpBuild then
            local remaining = job.remaining or 0
            -- M6 修复：1★/10秒，上限50★，避免后期费用失控
            local speedCost = math.max(5, math.min(50, math.ceil(remaining / 10)))
            local sbx = px + pw - 46
            panel(sbx, sy, 40, 12, 4, {160,130,20,80}, {220,190,40,210})
            text(sbx+20, sy+6, "★"..speedCost, 8, 255,230,80,255,
                NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            local capturedPlanet = planet
            addHit(sbx, sy, 40, 12, function()
                if onSpeedUpBuild then onSpeedUpBuild(capturedPlanet) end
            end)
        end
        sy = sy + 22
    else
        text(px+14, sy, "建设队列: 空闲", 10, 150,170,200,180)
        sy = sy + 16
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
                -- 确认行：✓ 确认 / ✗ 取消
                local hbW = (bw - 3) / 2
                panel(bx, sy2, hbW, bh, 4, {30,150,70,100},{50,200,90,220})
                text(bx+hbW/2, sy2+bh/2, "✓ 确认", 10, 150,255,170,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                local ck = key
                addHit(bx, sy2, hbW, bh, function()
                    planetBuildPending_ = nil
                    if onBuild then onBuild(ck, false, nil) end
                end)
                local bx2 = bx + hbW + 3
                panel(bx2, sy2, hbW, bh, 4, {150,40,40,100},{200,70,70,220})
                text(bx2+hbW/2, sy2+bh/2, "✗ 取消", 10, 255,140,140,255,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(bx2, sy2, hbW, bh, function() planetBuildPending_ = nil end)
            else
                panel(bx, sy2, bw, bh, 4,
                    {canB and 50 or 50, canB and 120 or 80, canB and 255 or 140, 60},
                    {canB and 50 or 50, canB and 120 or 80, canB and 255 or 140, 180})
                text(bx+bw/2, sy2+bh/2, bd.name.."  ["..costStr.."]", 10,
                    canB and 110 or 110, canB and 180 or 140, canB and 255 or 200, 240,
                    NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                if canB then
                    local ck = key
                    addHit(bx, sy2, bw, bh, function()
                        planetBuildPending_   = ck
                        planetUpgradePending_ = nil
                    end)
                end
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
                text(px+14, sy2+8, "▸ " .. b.name .. " Lv." .. b.level, 10, 140,175,230,220)
                local canUp   = bs:canUpgrade(bldIdx, planet)
                local cost    = bs:getUpgradeCost(b.key, b.level)
                local costStr = rm:fmtCost(cost)
                local bx, bw, bh = px+pw-88, 84, 16
                -- H4：升级二次确认
                local isPending = planetUpgradePending_ and
                    planetUpgradePending_.idx == bldIdx and
                    planetUpgradePending_.key == b.key
                if isPending then
                    local hbW = (bw - 3) / 2
                    panel(bx, sy2, hbW, bh, 4, {30,150,70,100},{50,200,90,220})
                    text(bx+hbW/2, sy2+bh/2, "✓", 10, 150,255,170,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    local ci, ck = bldIdx, b.key
                    addHit(bx, sy2, hbW, bh, function()
                        planetUpgradePending_ = nil
                        if onBuild then onBuild(ck, true, ci) end
                    end)
                    local bx2 = bx + hbW + 3
                    panel(bx2, sy2, hbW, bh, 4, {150,40,40,100},{200,70,70,220})
                    text(bx2+hbW/2, sy2+bh/2, "✗", 10, 255,140,140,255,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx2, sy2, hbW, bh, function() planetUpgradePending_ = nil end)
                else
                    panel(bx, sy2, bw, bh, 4,
                        {canUp and 220 or 100, canUp and 160 or 100, canUp and 50 or 60, 60},
                        {canUp and 220 or 100, canUp and 160 or 100, canUp and 50 or 60, 180})
                    text(bx+bw/2, sy2+bh/2, "升级["..costStr.."]", 10,
                        canUp and 255 or 160, canUp and 220 or 160, canUp and 110 or 120, 240,
                        NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    if canUp then
                        local ci, ck = bldIdx, b.key
                        addHit(bx, sy2, bw, bh, function()
                            planetUpgradePending_ = { idx=ci, key=ck }
                            planetBuildPending_   = nil
                        end)
                    end
                end
            end
            vy = vy + 20
        end
    end

    nvgRestore(vg)

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
