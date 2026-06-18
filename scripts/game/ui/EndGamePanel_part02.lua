-- Auto-split from EndGamePanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function renderLeaderboard()
    if not lbVisible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    local panelProg = math.min(1.0, lbAnimT_ / LB_ANIM_DUR)
    local panelEase = 1 - (1 - panelProg) ^ 3
    local panelAlpha = panelEase

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(180 * panelAlpha)))
    nvgFill(vg)

    local pw = math.min(420, screenW - 40)
    local ph = math.min(520, screenH - 40)
    local px = (screenW - pw) / 2
    local slideOffset = (1 - panelEase) * (ph * 0.35)
    local py = (screenH - ph) / 2 - slideOffset

    nvgSave(vg)
    nvgGlobalAlpha(vg, panelAlpha)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px - 2, py - 2, pw + 4, ph + 4, 14)
    nvgFillColor(vg, nvgRGBA(80, 50, 180, 60))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(8, 5, 22, 248))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 200, 200))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 150, 255, 255))
    nvgText(vg, px + pw / 2, py + 22, "🏅  银河征服 · 排行榜")

    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, py + 36); nvgLineTo(vg, px + pw - 20, py + 36)
    nvgStrokeColor(vg, nvgRGBA(80, 60, 160, 120))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    local listY = py + 44
    if lbMyRank_ or lbMyScore_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + 10, listY, pw - 20, 20, 4)
        nvgFillColor(vg, nvgRGBA(60, 40, 120, 160)); nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(180, 150, 255, 220))
        local rankStr = lbMyRank_ and string.format("我的排名: #%d", lbMyRank_) or "我的排名: 未上榜"
        nvgText(vg, px + 16, listY + 10, rankStr)
        if lbMyScore_ then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 220))
            nvgText(vg, px + pw - 16, listY + 10, string.format("得分: %d", lbMyScore_))
        end
        listY = listY + 28
    end

    local rowH = 28
    local rankColors = { {255,215,0}, {192,192,192}, {205,127,50} }

    if lbLoading_ then
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 120, 200, 200))
        nvgText(vg, px + pw / 2, listY + 60, "加载中...")
    elseif not lbData_ or #lbData_ == 0 then
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 100, 160, 180))
        nvgText(vg, px + pw / 2, listY + 60, "暂无排行榜数据")
    else
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(100, 90, 150, 180))
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + 16, listY + 6, "排名  指挥官")
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + pw - 16, listY + 6, "得分")
        listY = listY + 16

        local maxRows = math.floor((py + ph - 50 - listY) / rowH)
        for i, entry in ipairs(lbData_) do
            if i > maxRows then break end

            local rowDelay = LB_ANIM_DUR + (i - 1) * LB_ROW_STAGGER
            local rowProg  = math.max(0, math.min(1, (lbAnimT_ - rowDelay) / 0.18))
            local rowEase  = 1 - (1 - rowProg) ^ 2
            local rowSlide = (1 - rowEase) * 10
            local ry = listY + (i - 1) * rowH + rowSlide

            if rowEase <= 0 then goto continueRow end

            nvgSave(vg)
            nvgGlobalAlpha(vg, rowEase * panelAlpha)

            if entry.isMe then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg, nvgRGBA(60, 40, 130, 140)); nvgFill(vg)
            elseif i % 2 == 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px + 8, ry + 1, pw - 16, rowH - 2, 4)
                nvgFillColor(vg, nvgRGBA(20, 15, 45, 80)); nvgFill(vg)
            end

            local rc = rankColors[entry.rank] or {160, 150, 200}
            nvgFontSize(vg, entry.rank <= 3 and 13 or 11)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
            local medal = entry.rank == 1 and "🥇"
                       or entry.rank == 2 and "🥈"
                       or entry.rank == 3 and "🥉"
                       or string.format("#%d", entry.rank)
            nvgText(vg, px + 16, ry + rowH / 2, medal)

            nvgFontSize(vg, 11)
            nvgFillColor(vg, entry.isMe
                and nvgRGBA(220, 200, 255, 255)
                or  nvgRGBA(180, 170, 210, 220))
            local nameX = entry.rank <= 9 and (px + 46) or (px + 52)
            -- P2-3: 自己的排行榜条目显示徽章图标
            if entry.isMe then
                local emb = LiverySystem.GetEmblem()
                if emb and emb.icon then
                    nvgText(vg, nameX, ry + rowH / 2, emb.icon)
                    nameX = nameX + 16
                end
            end
            local name = entry.nickname or ("玩家" .. tostring(entry.userId or "?"))
            nvgText(vg, nameX, ry + rowH / 2, name .. (entry.isMe and " ★" or ""))

            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, 230))
            nvgText(vg, px + pw - 16, ry + rowH / 2, tostring(entry.score or 0))

            nvgRestore(vg)

            -- P3-1: 点击行 → 打开个人主页弹窗
            do
                local capturedEntry = entry
                addHit(px + 8, ry + 1, pw - 16, rowH - 2, function()
                    profileEntry_ = capturedEntry
                    profileAnimT_ = 0
                end)
            end

            ::continueRow::
        end
    end

    local cbw, cbh = 120, 32
    local cbx = (screenW - cbw) / 2
    local cby = py + ph - cbh - 12
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx, cby, cbw, cbh, 7)
    nvgFillColor(vg, nvgRGBA(40, 30, 80, 200)); nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 180, 160))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 140, 220, 240))
    nvgText(vg, screenW / 2, cby + cbh / 2, "关闭")
    addHit(cbx, cby, cbw, cbh, function()
        lbVisible_    = false
        profileEntry_ = nil   -- P3-1: 关闭排行榜时同时关闭个人主页弹窗
    end)

    nvgRestore(vg)
end
