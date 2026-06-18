-- Auto-split from EndGamePanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function renderProfilePopup()
    if not profileEntry_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    local e = profileEntry_

    -- 弹入动画（从下方滑入 + 淡入）
    local prog = math.min(1.0, profileAnimT_ / PROFILE_ANIM_DUR)
    local ease = 1 - (1 - prog) ^ 3
    if ease <= 0.01 then return end

    -- P3-1: 统一卡片高度（P2-3: 增加到 340 以容纳蓝图摘要区）
    local pw = math.min(300, screenW - 60)
    local ph = 340
    local px = (screenW - pw) / 2
    local slideOff = (1 - ease) * 30
    local py = (screenH - ph) / 2 + slideOff
    local ga = ease

    -- P3-1: 难度/舰型显示名映射
    local DIFF_NAMES = { easy="简单", normal="普通", hard="困难", custom="自定义" }
    local SHIP_NAMES = {
        SCOUT="侦察舰", FRIGATE="护卫舰", DESTROYER="驱逐舰",
        BATTLECRUISER="巡洋舰", ENGINEER="工程舰", EXPLORER="探索舰",
        CARRIER="母舰", INTERCEPTOR="拦截舰",
    }

    -- 全屏半透明遮罩（点击遮罩关闭弹窗）
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(100 * ga)))
    nvgFill(vg)
    addHit(0, 0, screenW, screenH, function()
        profileEntry_ = nil
    end)

    nvgSave(vg)
    nvgGlobalAlpha(vg, ga)

    -- 卡片背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px - 2, py - 2, pw + 4, ph + 4, 14)
    nvgFillColor(vg, nvgRGBA(80, 50, 180, 50))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(8, 5, 28, 252))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 80, 220, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题行
    local rankColors = { {255,215,0}, {192,192,192}, {205,127,50} }
    local rc = rankColors[e.rank] or {140, 120, 220}
    local medal = e.rank == 1 and "🥇 " or e.rank == 2 and "🥈 " or e.rank == 3 and "🥉 " or string.format("#%d  ", e.rank)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
    nvgText(vg, px + pw / 2, py + 22, medal .. (e.nickname or e.name or ("玩家" .. tostring(e.userId or "?"))))

    -- 分割线
    local function divider(dy)
        nvgBeginPath(vg)
        nvgMoveTo(vg, px + 20, py + dy); nvgLineTo(vg, px + pw - 20, py + dy)
        nvgStrokeColor(vg, nvgRGBA(80, 60, 160, 80)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    end
    divider(36)

    -- 数据行（3列：得分 / 殖民 / 击杀）
    local col = pw / 3
    local labels3 = { "🏆 得分", "🌍 殖民", "⚔️ 击杀" }
    local values3 = {
        tostring(e.score     or 0),
        tostring(e.colonized or 0),
        tostring(e.kills     or 0),
    }
    for ci = 1, 3 do
        local cx = px + (ci - 1) * col + col / 2
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(130, 110, 180, 200))
        nvgText(vg, cx, py + 52, labels3[ci])
        nvgFontSize(vg, 15)
        nvgFillColor(vg, nvgRGBA(220, 210, 255, 255))
        nvgText(vg, cx, py + 70, values3[ci])
    end

    divider(86)

    -- ── P3-1: 战绩详情区（最佳难度 / 最高连胜 / 最爱舰型）──────────────────
    -- 节标题
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 80, 180, 160))
    nvgText(vg, px + 16, py + 96, "战绩详情")

    local extra = e.extraReady and e.extra or nil
    local lineH = 22
    local lineY = py + 112

    local function statRow(label, val)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 120, 190, 200))
        nvgText(vg, px + 16, lineY, label)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(210, 195, 255, 240))
        nvgText(vg, px + pw - 16, lineY, tostring(val))
        lineY = lineY + lineH
    end

    if extra then
        local diffName  = DIFF_NAMES[extra.bd] or (extra.bd ~= "" and extra.bd or "—")
        local streak    = (extra.ms or 0) > 0 and (extra.ms .. " 连胜") or "—"
        local shipName  = SHIP_NAMES[extra.fs] or (extra.fs ~= "" and extra.fs or "—")
        statRow("最佳难度", diffName)
        statRow("最高连胜", streak)
        statRow("最爱舰型", shipName)
        -- P3-2: 展示战报摘要
        if extra.br and extra.br ~= "" then
            statRow("最近战报", extra.br)
        end
    else
        -- 占位：脉冲淡入文字
        local pulseA = math.floor(120 + 80 * math.abs(math.sin(profileAnimT_ * 2.5)))
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 100, 180, pulseA))
        nvgText(vg, px + pw / 2, py + 126, "暂无详细战绩")
        lineY = py + 112 + lineH * 3
    end

    -- P3-2: 动态分割线位置（适应可变行数）
    local secDivY = math.max(lineY + 2, py + 158)
    divider(secDivY - py)

    -- ── P3-1: 近期胜利简报（最多3场）──────────────────────────────────────────
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 80, 180, 160))
    nvgText(vg, px + 16, secDivY + 10, "近期胜利")

    local recentY = secDivY + 24
    local recentH = 18
    local recentWins = (extra and type(extra.rw) == "table") and extra.rw or {}

    if #recentWins > 0 then
        for ri = 1, math.min(3, #recentWins) do
            local w = recentWins[ri]
            local diffStr = DIFF_NAMES[w.diff] or (w.diff or "?")
            local durStr  = (w.duration or 0) > 0 and (w.duration .. "min") or "<1min"
            local rowStr  = string.format("波次%d  ·  %s  ·  %s", w.waves or 0, durStr, diffStr)
            -- 交替底色
            if ri % 2 == 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + 12, recentY - recentH / 2, pw - 24, recentH, 3)
                nvgFillColor(vg, nvgRGBA(50, 35, 100, 60)); nvgFill(vg)
            end
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 165, 230, 200))
            nvgText(vg, px + pw / 2, recentY, rowStr)
            recentY = recentY + recentH
        end
    else
        local pulseA2 = math.floor(100 + 60 * math.abs(math.sin(profileAnimT_ * 2.5)))
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 85, 160, pulseA2))
        nvgText(vg, px + pw / 2, secDivY + 28, extra and "暂无胜利记录" or "—")
    end

    -- ── P2-3: 蓝图摘要区 ───────────────────────────────────────────────────────
    local bpData = extra and extra.bp or nil
    local bpSecY = math.max(recentY + 4, secDivY + 64)
    divider(bpSecY - py)

    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 80, 180, 160))
    nvgText(vg, px + 16, bpSecY + 10, "战术蓝图")

    if bpData and bpData.nm then
        -- 蓝图名称
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 180, 255, 230))
        nvgText(vg, px + 16, bpSecY + 26, "📋 " .. (bpData.nm or "未命名"))

        -- 舰队组成摘要
        local fleetY = bpSecY + 40
        if type(bpData.fl) == "table" then
            for fi = 1, math.min(2, #bpData.fl) do
                local f = bpData.fl[fi]
                local fleetStr = (f.n or ("舰队" .. fi)) .. ": " .. (f.s or "—")
                nvgFontSize(vg, 8)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(150, 135, 200, 180))
                nvgText(vg, px + 24, fleetY, fleetStr)
                fleetY = fleetY + 13
            end
        end

        -- "收藏蓝图" 按钮（用分享码导入到本地收藏）
        if bpData.sc then
            local bmBtnW, bmBtnH = 72, 18
            local bmBtnX = px + pw - bmBtnW - 14
            local bmBtnY = bpSecY + 20
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bmBtnX, bmBtnY, bmBtnW, bmBtnH, 4)
            nvgFillColor(vg, nvgRGBA(60, 40, 120, 200)); nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(180, 140, 255, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 200, 255, 240))
            nvgText(vg, bmBtnX + bmBtnW / 2, bmBtnY + bmBtnH / 2, "⭐ 收藏")
            addHit(bmBtnX, bmBtnY, bmBtnW, bmBtnH, function()
                -- 构造收藏数据
                local bmData = {
                    name      = bpData.nm or "未命名蓝图",
                    shareCode = bpData.sc,
                    fleets    = {},  -- 精简版无完整 fleets，标记来源
                    _source   = "leaderboard",
                }
                local ok, msg = BlueprintSystem.Bookmark(bmData)
                if notifyFn_ then notifyFn_(msg, ok and "success" or "warning") end
            end)
        end
    else
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 85, 160, 120))
        nvgText(vg, px + pw / 2, bpSecY + 28, "暂无蓝图")
    end

    -- 关闭按钮
    local cbw2, cbh2 = 80, 24
    local cbx2 = (screenW - cbw2) / 2
    local cby2 = py + ph - cbh2 - 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx2, cby2, cbw2, cbh2, 6)
    nvgFillColor(vg, nvgRGBA(30, 20, 60, 220)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 60, 140, 160)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 130, 210, 240))
    nvgText(vg, screenW / 2, cby2 + cbh2 / 2, "关闭")
    addHit(cbx2, cby2, cbw2, cbh2, function()
        profileEntry_ = nil
    end)

    nvgRestore(vg)
end
