--- 星航基地面板模块
--- 负责渲染基地核心等级、模块建造、安装队列、已安装模块

local UICommon    = require("game.ui.UICommon")
local DragManager = require("game.ui.DragManager")

local BasePanel = {}

-- 面板私有状态
local scrollY_            = 0
local corePending_        = false   -- 核心升级待确认
local baseBuildPending_   = nil     -- 模块建造待确认（key string）
local baseUpgradePending_ = nil     -- 模块升级待确认 {idx, key}

function BasePanel.ResetScroll()
    scrollY_ = 0
end

--- 渲染基地面板
---@param base  table  基地数据对象（isBase=true）
---@param ctx   table  {bbs, rm, screenH, onBuild, onCoreUpgrade, slotFlashTimer, progressBar}
function BasePanel.Render(base, ctx)
    if not base or not base.isBase then return end

    local vg        = UICommon.vg
    local screenW   = UICommon.screenW
    local screenH   = UICommon.screenH
    local bbs       = UICommon.bbs
    local rm        = UICommon.rm
    local addHit    = UICommon.addHit
    local addScroll = UICommon.addScroll
    local panel     = UICommon.panel
    local text      = UICommon.text
    local clr       = UICommon.clr

    local onBuild        = ctx.onBuild
    local onCoreUpgrade  = ctx.onCoreUpgrade
    local onSpeedUpBuild    = ctx.onSpeedUpBuild
    local onSpeedUpBuildAd  = ctx.onSpeedUpBuildAd  -- 广告免费完成（星币不足时）
    local slotFlashTimer = ctx.slotFlashTimer or 0
    local progressBar    = ctx.progressBar
    local shipyardMult   = ctx.shipyardMult or 1.0
    local SLOT_FLASH_DURATION = ctx.slotFlashDuration or 0.6
    -- P1-2 WARP_GATE_PRIME
    local hasWarpGate    = ctx.hasWarpGate or false
    local warpCooldown   = ctx.warpCooldown or 0
    local onWarpFleet    = ctx.onWarpFleet

    local pw = 275
    local defPx = screenW - pw - 12
    local defPy = UICommon.PANEL_TOP or 48
    local px, py = DragManager.GetPos("base", defPx, defPy)

    local coreLevel  = base.coreLevel or 1
    local isMaxCore  = coreLevel >= BASE_CORE_MAX_LEVEL

    -- +16 = 下一级解锁预览行（未满级时显示）
    local headerH = 36 + 18 + 16 + 16 + (not isMaxCore and 16 or 0)
                  + (base.constructing and 26 or 16) + 16
                  + (shipyardMult > 1.01 and 14 or 0)
                  + (hasWarpGate and 26 or 0)  -- P1-2 WARP_GATE_PRIME 瞬移按钮行

    -- P2-2: 槽位可视化格子行数（5列）
    local maxSlots      = BaseModuleSlots(coreLevel)
    local SLOT_COLS     = 5
    local slotRows      = math.ceil(maxSlots / SLOT_COLS)
    local SLOT_GRID_H   = slotRows * 24 + 8 + 14  -- 格子 + 标题

    local scrollContentH = SLOT_GRID_H
        + 18
        + #BASE_MODULE_ORDER * 28
        + 12 + 17
        + math.max(1, #base.buildings) * 20

    local totalH    = headerH + scrollContentH
    local maxPanelH = screenH - py - 16
    local ph        = math.min(totalH + 16, maxPanelH)

    local scrollStartY = py + headerH
    local scrollAreaH  = ph - headerH
    local maxScroll    = math.max(0, scrollContentH - scrollAreaH)
    scrollY_ = math.max(0, math.min(maxScroll, scrollY_))

    panel(px, py, pw, ph, 7, {8, 18, 35, 245}, {80, 200, 255, 220})
    DragManager.RegisterHandle("base", px, py, pw, 28)
    DragManager.DrawHandle(UICommon.vg, px, py, pw, 8)

    -- === 固定头部 ===
    local sy = py + 16

    text(px+pw/2, sy, "★ " .. base.name, 15, 80, 200, 255, 255,
        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    sy = sy + 20

    -- 槽位行（升级后短暂高亮闪烁）
    local slotAlpha = 200
    if slotFlashTimer > 0 then
        local frac = slotFlashTimer / SLOT_FLASH_DURATION
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px+8, sy-6, pw-16, 14, 3)
        nvgFillColor(vg, nvgRGBA(80, 220, 120, math.floor(frac * 120)))
        nvgFill(vg)
        slotAlpha = 255
    end
    text(px+pw/2, sy,
        "模块槽位: " .. #base.buildings .. " / " .. BaseModuleSlots(coreLevel),
        9, slotFlashTimer > 0 and 150 or 100,
           slotFlashTimer > 0 and 255 or 180,
           slotFlashTimer > 0 and 180 or 255,
        slotAlpha, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    sy = sy + 16

    -- ── 核心等级行 + 升级按钮 ──
    do
        local canUp, reason = bbs and bbs:canUpgradeCore(base) or false, "—"
        local upCost = (not isMaxCore) and BASE_CORE_UPGRADE_COSTS[coreLevel] or nil
        local costStr = ""
        if upCost then
            local parts = {}
            for _, r in ipairs({"metal","esource","nuclear"}) do
                if upCost[r] then parts[#parts+1] = RES_LABELS[r] .. " " .. upCost[r] end
            end
            costStr = table.concat(parts, " / ")
        end

        local btnW, btnH = 76, 16
        local bx  = px + pw - btnW - 8

        text(px+14, sy+8, "核心等级: Lv." .. coreLevel .. " / " .. BASE_CORE_MAX_LEVEL,
            10, 180, 220, 255, 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local barX = px + 14 + 110
        local barW = bx - barX - 6
        if barW > 10 then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, sy+4, barW, 7, 2)
            nvgFillColor(vg, nvgRGBA(30,60,100,180))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, sy+4, barW * (coreLevel / BASE_CORE_MAX_LEVEL), 7, 2)
            nvgFillColor(vg, nvgRGBA(80,180,255,200))
            nvgFill(vg)
        end

        if isMaxCore then
            panel(bx, sy, btnW, btnH, 4, {40,120,80,60}, {60,200,120,160})
            text(bx+btnW/2, sy+btnH/2, "已满级 ★", 9, 120, 255, 180, 230,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        elseif corePending_ then
            local hbW = (btnW - 3) / 2
            panel(bx, sy, hbW, btnH, 4, {40,160,80,100},{60,200,100,220})
            text(bx+hbW/2, sy+btnH/2, "✓", 10, 150,255,170,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            addHit(bx, sy, hbW, btnH, function()
                corePending_ = false
                if onCoreUpgrade then onCoreUpgrade() end
            end)
            local bx2 = bx + hbW + 3
            panel(bx2, sy, hbW, btnH, 4, {160,50,50,100},{200,80,80,220})
            text(bx2+hbW/2, sy+btnH/2, "✗", 10, 255,150,150,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            addHit(bx2, sy, hbW, btnH, function() corePending_ = false end)
        elseif canUp then
            panel(bx, sy, btnW, btnH, 4, {60,100,200,80},{100,160,255,200})
            text(bx+btnW/2, sy+btnH/2, "升级核心 ▲", 9, 160,210,255,255,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            addHit(bx, sy, btnW, btnH, function() corePending_ = true end)
        else
            panel(bx, sy, btnW, btnH, 4, {40,50,70,60},{60,80,120,100})
            text(bx+btnW/2, sy+btnH/2, reason or "升级核心", 9, 100,120,160,160,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
        sy = sy + 18

        if not isMaxCore and costStr ~= "" then
            text(px+14, sy+6, "下级费用: " .. costStr, 8, 120, 160, 200, 160)
        end
        sy = sy + 16

        -- 下一级解锁模块预览
        if not isMaxCore then
            local nextLv = coreLevel + 1
            local unlockList = BASE_CORE_UNLOCK_PREVIEW and BASE_CORE_UNLOCK_PREVIEW[nextLv] or {}
            if #unlockList > 0 then
                local names = {}
                for _, k in ipairs(unlockList) do
                    names[#names+1] = (BASE_MODULES[k] and BASE_MODULES[k].name) or k
                end
                text(px+14, sy+6, "Lv."..nextLv.." 解锁: " .. table.concat(names, " · "),
                    8, 100, 220, 160, 180)
            else
                text(px+14, sy+6, "Lv."..nextLv.." 无新模块（槽位+1）",
                    8, 100, 140, 160, 130)
            end
            sy = sy + 16
        end
    end

    -- 队列进度
    if base.constructing then
        local job = base.constructing
        local pct = job.progress or 0
        -- 进度条（留右侧空间给加速按钮）
        local barW = onSpeedUpBuild and (pw - 60) or (pw - 20)
        if job.isCoreUpgrade then
            progressBar(px+10, sy, barW, 14, pct,
                "核心升级 Lv." .. job.level .. "  " .. math.floor(pct*100) .. "%",
                180, 120, 255)
        else
            local tag     = job.isUpgrade and "升级" or "安装"
            local modName = BASE_MODULES[job.key] and BASE_MODULES[job.key].name or job.key
            progressBar(px+10, sy, barW, 14, pct,
                tag .. ": " .. modName .. " " .. math.floor(pct*100) .. "%", 80, 200, 255)
        end
        -- 加速按钮（星币足够→金色购买；不足且有广告→绿色免费）
        if onSpeedUpBuild or onSpeedUpBuildAd then
            local remaining = job.remaining or 0
            local speedCost = math.max(5, math.min(50, math.ceil(remaining / 10)))
            local rmRef     = UICommon.rm
            local canAfford = rmRef and (rmRef.resources.credits or 0) >= speedCost
            local sbx = px + pw - 46
            if onSpeedUpBuild and canAfford then
                panel(sbx, sy, 40, 14, 4, {160, 130, 20, 80}, {220, 190, 40, 210})
                text(sbx+20, sy+7, "★" .. speedCost, 9, 255, 230, 80, 255,
                    NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                local capturedBase = base
                addHit(sbx, sy, 40, 14, function()
                    if onSpeedUpBuild then onSpeedUpBuild(capturedBase) end
                end)
            elseif onSpeedUpBuildAd and not canAfford then
                -- 星币不足时显示"看广告免费完成"
                panel(sbx, sy, 40, 14, 3, {0, 80, 45, 100}, {0, 190, 100, 220})
                text(sbx+20, sy+7, "🎬", 10, 80, 255, 160, 255,
                    NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                local capturedBase = base
                addHit(sbx, sy, 40, 14, function()
                    if onSpeedUpBuildAd then onSpeedUpBuildAd(capturedBase) end
                end)
            end
        end
        sy = sy + 26
    else
        text(px+14, sy, "安装队列: 空闲", 10, 150, 170, 200, 180)
        sy = sy + 16
    end

    -- 造船加速倍率提示行
    if shipyardMult > 1.01 then
        text(px+pw/2, sy, "造船速度: x" .. string.format("%.2f", shipyardMult), 9, 100, 230, 160, 220,
            NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        sy = sy + 14
    end

    -- P1-2 WARP_GATE_PRIME 瞬移按钮行
    if hasWarpGate then
        local btnW, btnH = pw - 24, 20
        local btnX, btnY = px + 12, sy + 3
        local onCD       = warpCooldown > 0
        local btnLabel   = onCD
            and string.format("主曲速门冷却中 (%.0fs)", warpCooldown)
            or  "⚡ 舰队瞬移至此星球"
        local br, bg, bb = onCD and 80 or 60, onCD and 80 or 180, onCD and 100 or 255
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
        nvgFillColor(vg, nvgRGBA(br, bg, bb, onCD and 60 or 120))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(br, bg, bb, 200))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        text(px + pw/2, btnY + btnH/2, btnLabel, 9,
            onCD and 140 or 120, onCD and 140 or 220, onCD and 160 or 255,
            onCD and 160 or 240, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if not onCD and onWarpFleet then
            addHit(btnX, btnY, btnW, btnH, function()
                onWarpFleet(base)
            end)
        end
        sy = sy + 26
    end

    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(80, 180, 255, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- === 可滚动区域 ===
    addScroll(px, scrollStartY, pw, scrollAreaH, function(delta)
        scrollY_ = scrollY_ - delta * 30
    end)

    nvgSave(vg)
    nvgScissor(vg, px+1, scrollStartY, pw-2, scrollAreaH)

    local clipY1 = scrollStartY
    local clipY2 = py + ph
    local function vy2sy(vy) return vy - scrollY_ end
    local function isVis(vy, h)
        local s = vy - scrollY_
        return s + h > clipY1 and s < clipY2
    end

    -- P2-2: 模块简称表（槽位格子显示用）
    local MODULE_ABBR = {
        COMMAND_CENTER  = "指挥", ENERGY_CORE    = "能核", MINERAL_SILO   = "仓储",
        MATERIAL_DEPOT  = "材库", REFINERY       = "精炼", DEFENSE_CANNON = "炮台",
        HANGAR          = "机库", WARP_GATE      = "曲速", SOLAR_ARRAY    = "太阳",
        RESEARCH_CENTER = "科研", SHIPYARD       = "造船", BASE_SHIELD    = "护盾",
        BUILD_CENTER    = "探索", EXCHANGE_CENTER= "互换",
    }

    local vy = clipY1 + 6

    -- P2-2: 槽位可视化（所有已建+空槽格子一览）
    do
        local CELL_GAP  = 4
        local CELL_W    = math.floor((pw - 16 - (SLOT_COLS - 1) * CELL_GAP) / SLOT_COLS)
        local CELL_H    = 22

        -- 标题行
        if isVis(vy, 12) then
            text(px+14, vy2sy(vy)+6, "模块槽位总览  " .. #base.buildings .. "/" .. maxSlots,
                9, 100, 200, 255, 180)
        end
        vy = vy + 14

        for slotIdx = 1, maxSlots do
            local col = (slotIdx - 1) % SLOT_COLS
            local row = math.floor((slotIdx - 1) / SLOT_COLS)
            local cx  = px + 8 + col * (CELL_W + CELL_GAP)
            local cy  = vy2sy(vy + row * (CELL_H + CELL_GAP))

            if cy + CELL_H > clipY1 - 4 and cy < clipY1 + scrollAreaH + 4 then
                local bldg = base.buildings[slotIdx]  -- 已安装（按安装顺序）
                if bldg then
                    -- 已安装槽：蓝色实心
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, CELL_W, CELL_H, 4)
                    nvgFillColor(vg, clr(20, 60, 140, 200)); nvgFill(vg)
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, CELL_W, CELL_H, 4)
                    nvgStrokeColor(vg, clr(60, 140, 255, 180)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
                    -- 简称 + 等级
                    local abbr = MODULE_ABBR[bldg.key] or bldg.name:sub(1, 2)
                    text(cx + CELL_W/2, cy + 8,  abbr,           8, 160, 220, 255, 255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    text(cx + CELL_W/2, cy + 17, "Lv"..bldg.level, 7, 100, 180, 255, 180, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                else
                    -- 空槽：灰色虚线边框 + "+" 号
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx+0.5, cy+0.5, CELL_W-1, CELL_H-1, 4)
                    -- 虚线效果：短边框段
                    nvgStrokeColor(vg, clr(80, 100, 140, 120))
                    nvgStrokeWidth(vg, 1)
                    nvgStroke(vg)
                    text(cx + CELL_W/2, cy + CELL_H/2, "+", 13, 100, 140, 200, 160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)

                    -- 点击空槽：高亮第一个可建造的模块（设为 pending）
                    if cy >= clipY1 and cy + CELL_H <= clipY1 + scrollAreaH then
                        addHit(cx, cy, CELL_W, CELL_H, function()
                            for _, k in ipairs(BASE_MODULE_ORDER) do
                                local alreadyBuilt = false
                                for _, b in ipairs(base.buildings) do
                                    if b.key == k then alreadyBuilt = true; break end
                                end
                                local reqLv = BASE_MODULE_UNLOCK_LEVEL[k] or 1
                                if not alreadyBuilt and coreLevel >= reqLv then
                                    local ok2 = bbs and bbs:canBuild(k, base) or false
                                    if ok2 then
                                        baseBuildPending_ = k
                                        return
                                    end
                                end
                            end
                            -- 资源不足时也选第一个未建且已解锁的
                            for _, k in ipairs(BASE_MODULE_ORDER) do
                                local alreadyBuilt = false
                                for _, b in ipairs(base.buildings) do
                                    if b.key == k then alreadyBuilt = true; break end
                                end
                                local reqLv = BASE_MODULE_UNLOCK_LEVEL[k] or 1
                                if not alreadyBuilt and coreLevel >= reqLv then
                                    baseBuildPending_ = k; return
                                end
                            end
                        end)
                    end
                end
            end
        end
        vy = vy + slotRows * (CELL_H + CELL_GAP) + 4
    end

    -- 分隔线
    if isVis(vy, 2) then
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, vy2sy(vy)); nvgLineTo(vg, px+pw-8, vy2sy(vy))
        nvgStrokeColor(vg, clr(60, 100, 180, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    vy = vy + 6

    if isVis(vy, 14) then
        text(px+14, vy2sy(vy)+7, "模块建造:", 10, 100, 200, 255, 200)
    end
    vy = vy + 18

    for _, key in ipairs(BASE_MODULE_ORDER) do
        local sy2    = vy2sy(vy)
        local mod    = BASE_MODULES[key]
        local reqLv  = BASE_MODULE_UNLOCK_LEVEL[key] or 1
        local locked = coreLevel < reqLv

        local installed = false
        for _, b in ipairs(base.buildings) do
            if b.key == key then installed = true; break end
        end
        if installed and baseBuildPending_ == key then
            baseBuildPending_ = nil
        end
        local ok, failReason = bbs and bbs:canBuild(key, base) or false, ""
        local costStr = rm and rm:fmtCost(mod.cost) or ""

        local deficits = {}
        if not installed and not locked and not ok and rm then
            for _, res in ipairs(RES_ORDER) do
                local need = mod.cost[res] or 0
                if need > 0 then
                    local have = math.floor(rm.resources[res] or 0)
                    if have < need then
                        deficits[#deficits+1] = "需+" .. (need-have) .. " " .. RES_LABELS[res]
                    end
                end
            end
        end

        if sy2 >= clipY1 - 28 and sy2 < clipY2 then
            local bx, bw, bh = px+8, pw-16, 24
            local r, g, b_col
            if installed then
                r, g, b_col = 40, 160, 110
            elseif locked then
                r, g, b_col = 80, 50, 40
            elseif ok then
                r, g, b_col = 50, 150, 255
            else
                r, g, b_col = 50, 80, 160
            end
            panel(bx, sy2, bw, bh, 4,
                {r, g, b_col, locked and 25 or 40},
                {r, g, b_col, locked and 80 or (installed and 120 or 180)})

            if locked then
                text(bx+12, sy2+8, "🔒 " .. mod.name, 10, 140, 100, 80, 180)
                text(bx+bw/2, sy2+18,
                    "核心升级至 Lv." .. reqLv .. " 解锁  |  " .. mod.desc,
                    8, 160, 120, 80, 140, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            else
                if installed then
                    text(bx+10, sy2+bh/2, "✓ 已安装",
                        9, 100, 255, 160, 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    text(bx+bw/2+18, sy2+8, mod.name,
                        10, 160, 230, 190, 220, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- L5: 已安装模块显示效果描述
                    text(bx+bw/2+18, sy2+18, mod.desc,
                        7, 120, 200, 160, 160, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                elseif #deficits > 0 then
                    text(bx+bw/2, sy2+8, mod.name,
                        10, r+80, g+80, b_col+40, 240, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    -- L5: 最多显示2项缺口，防溢出
                    local showDef = {}
                    for i = 1, math.min(2, #deficits) do showDef[i] = deficits[i] end
                    if #deficits > 2 then showDef[#showDef+1] = "…" end
                    local defStr = table.concat(showDef, "  ")
                    text(bx+bw/2, sy2+18, defStr,
                        8, 255, 100, 80, 220, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                else
                    text(bx+bw/2, sy2+8,
                        mod.name .. "  [" .. costStr .. "]",
                        10, r+80, g+80, b_col+40, 240, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    text(bx+bw/2, sy2+18, mod.desc,
                        8, r+40, g+80, b_col+20, 160, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                end

                if not installed and ok and sy2 >= clipY1 and sy2 + bh <= clipY2 then
                    local capturedKey = key
                    if baseBuildPending_ == capturedKey then
                        local btnW2, btnH2 = 50, 16
                        local gap   = 4
                        local cbx   = bx + bw/2 - (btnW2*2+gap)/2
                        local csy   = sy2 + (bh - btnH2) / 2

                        panel(cbx, csy, btnW2, btnH2, 4, {40,160,80,100},{60,200,100,220})
                        text(cbx+btnW2/2, csy+btnH2/2, "✓ 确认", 9, 150,255,170,255,
                            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                        addHit(cbx, csy, btnW2, btnH2, function()
                            baseBuildPending_ = nil
                            if onBuild then onBuild(capturedKey, false, nil) end
                        end)

                        local cbx1 = cbx + btnW2 + gap
                        panel(cbx1, csy, btnW2, btnH2, 4, {160,50,50,100},{200,80,80,220})
                        text(cbx1+btnW2/2, csy+btnH2/2, "✗ 取消", 9, 255,150,150,255,
                            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                        addHit(cbx1, csy, btnW2, btnH2, function() baseBuildPending_ = nil end)
                    else
                        addHit(bx, sy2, bw, bh, function()
                            baseBuildPending_ = capturedKey
                        end)
                    end
                end
            end
        end
        vy = vy + 28
    end

    -- 分隔
    local sepSy = vy2sy(vy)
    if sepSy > clipY1 and sepSy < clipY2 then
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sepSy+2); nvgLineTo(vg, px+pw-8, sepSy+2)
        nvgStrokeColor(vg, clr(80, 180, 255, 40)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    vy = vy + 12

    if isVis(vy, 14) then
        text(px+14, vy2sy(vy)+7, "已安装:", 10, 100, 200, 255, 200)
    end
    vy = vy + 17

    if #base.buildings == 0 then
        if isVis(vy, 14) then
            text(px+14, vy2sy(vy)+7, "尚未安装任何模块", 10, 120, 130, 160, 180)
        end
    else
        for bldIdx, b in ipairs(base.buildings) do
            local sy2 = vy2sy(vy)
            if sy2 >= clipY1 and sy2 + 28 <= clipY2 then
                text(px+14, sy2+8, "▸ " .. b.name .. " Lv." .. b.level, 10, 100, 180, 255, 220)
                -- L5: 已安装列表显示模块效果描述
                local modDef = BASE_MODULES[b.key]
                if modDef and modDef.desc then
                    text(px+24, sy2+19, modDef.desc, 7, 100, 160, 140, 150)
                end
                local canUp    = bbs and bbs:canUpgrade(bldIdx, base)
                -- P1-3: 升级收益预览（desc 行右侧，仅可升级时显示）
                if canUp and modDef then
                    local nextLv = b.level + 1
                    local lvLabel = "Lv." .. b.level .. "→" .. nextLv
                    -- 从 desc 中提取首个带 /级 的收益片段，如 "+50/级"→"+50"、"×2/级"→"×2"
                    local benefitNum = modDef.desc and (
                        modDef.desc:match("([×%+%-%d%.x]+)/级") or
                        modDef.desc:match("([×%+%-%d%.x]+)/每级")
                    )
                    local hint = benefitNum and (lvLabel .. " " .. benefitNum) or lvLabel
                    text(px+pw-92, sy2+19, "↑ " .. hint, 7,
                        80, 220, 140, 180,
                        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                end
                local cost     = bbs and bbs:getUpgradeCost(b.key, b.level) or {}
                local costStr2 = rm and rm:fmtCost(cost) or ""
                local capturedIdx = bldIdx
                local capturedKey = b.key
                local isPending = baseUpgradePending_ and baseUpgradePending_.idx == bldIdx

                if isPending then
                    local btnW2, bh2 = 40, 16
                    local gap = 4
                    local totalW = btnW2 * 2 + gap
                    local bx0 = px + pw - totalW - 6

                    panel(bx0, sy2, btnW2, bh2, 4, {40, 160, 80, 70}, {60, 200, 100, 200})
                    text(bx0+btnW2/2, sy2+bh2/2, "✓确认", 9, 150, 255, 170, 255,
                        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    addHit(bx0, sy2, btnW2, bh2, function()
                        baseUpgradePending_ = nil
                        if onBuild then onBuild(capturedKey, true, capturedIdx) end
                    end)

                    local bx1 = bx0 + btnW2 + gap
                    panel(bx1, sy2, btnW2, bh2, 4, {160, 50, 50, 70}, {200, 80, 80, 200})
                    text(bx1+btnW2/2, sy2+bh2/2, "✗取消", 9, 255, 150, 150, 255,
                        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    addHit(bx1, sy2, btnW2, bh2, function()
                        baseUpgradePending_ = nil
                    end)
                else
                    local bx, bw, bh = px+pw-88, 84, 16
                    panel(bx, sy2, bw, bh, 4,
                        {canUp and 80 or 60, canUp and 180 or 120, canUp and 255 or 160, 60},
                        {canUp and 80 or 60, canUp and 180 or 120, canUp and 255 or 160, 180})
                    text(bx+bw/2, sy2+bh/2, "升级[" .. costStr2 .. "]", 9,
                        canUp and 150 or 120, canUp and 220 or 160, canUp and 255 or 200, 240,
                        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    if canUp then
                        addHit(bx, sy2, bw, bh, function()
                            baseUpgradePending_ = { idx = capturedIdx, key = capturedKey }
                        end)
                    end
                end
            end
            vy = vy + 28   -- L5: 行高 20→28，容纳两行文字
        end
    end

    nvgRestore(vg)
    -- 返回面板实际渲染高度，供下方子面板（互换中心等）定位使用
    return ph
end

return BasePanel
