-- ============================================================================
-- game/ui/EndGamePanel.lua  -- 游戏结算面板 + 排行榜子面板
-- ============================================================================
local UICommon = require "game.ui.UICommon"
local LiverySystem = require "game.LiverySystem"  -- P2-3: 排行榜徽章图标
local BlueprintSystem = require "game.BlueprintSystem"  -- P2-3: 蓝图收藏

local EndGamePanel = {}

-- ── 结算面板私有状态 ──────────────────────────────────────────────────────────
local active_        = false
local gameType_      = nil     -- "win" | "lose"
local stats_         = {}      -- { playTime, colonized, piratesKilled, rank, level, stars, ... }
local onRetry_       = nil     -- 点击"再来一局"回调
local animT_         = 0       -- 进场动画计时器
local adCb_          = nil     -- 广告回调：fn(onResult)
local adWatched_     = false   -- 本局是否已看过广告
local adLoading_     = false   -- 广告播放中

-- ── 排行榜子面板私有状态 ──────────────────────────────────────────────────────
local lbVisible_     = false
local lbData_        = nil
local lbLoading_     = false
local lbMyRank_      = nil
local lbMyScore_     = nil
local lbOnRequest_   = nil     -- fn(callback) 由 Client.lua 注入
local lbAnimT_       = 0
local LB_ANIM_DUR    = 0.45
local LB_ROW_STAGGER = 0.06

-- ── P3-1: 排行榜个人主页弹窗私有状态 ──────────────────────────────────────────
local profileEntry_    = nil    -- 当前展示的 entry（nil = 未打开）
local profileAnimT_    = 0      -- 弹入动画计时器
local PROFILE_ANIM_DUR = 0.3    -- 弹入动画时长（秒）
local profileCareer_   = nil    -- 本玩家生涯数据（由外部 SetCareerStats 注入）

-- ── P3-1: 战斗回放与精彩时刻私有状态 ─────────────────────────────────────────
local replayData_      = nil    -- {highlights, mvp, duration, frameCount, eventCount}
local replayBtnCb_     = nil    -- 点击"查看回放"回调（由外部注入）

-- 通知函数（由 GameUI 通过 SetNotifyFn 注入）
local notifyFn_ = nil

-- P3-2: 战报导出状态
local reportCopiedT_ = 0   -- 复制成功反馈计时器（>0 时显示"已复制"）

-- P2-2c: 战斗日志标签页状态
local logTabActive_ = false   -- true=显示日志, false=显示统计
local logScrollY_   = 0       -- 日志滚动偏移

-- P3-2: 生成结构化战报文本
local function generateBattleReport()
    local shipNames = {
        SCOUT="侦察舰", FRIGATE="护卫舰", DESTROYER="驱逐舰",
        BATTLECRUISER="战列舰", CARRIER="航母", INTERCEPTOR="拦截机",
        MINER="采矿舰", ENGINEER="工程舰", EXPLORER="探索舰",
    }
    local isWin = (gameType_ == "win")
    local lines = {}
    -- 标题
    lines[#lines+1] = isWin and "🏆 银河征服 · 战报" or "💀 银河征服 · 战报"
    lines[#lines+1] = string.rep("─", 20)
    -- 核心数据
    local m = math.floor((stats_.playTime or 0) / 60)
    local s = math.floor((stats_.playTime or 0) % 60)
    lines[#lines+1] = string.format("⏱ 用时 %d分%02d秒 | 🌍 殖民 %d颗", m, s, stats_.colonized or 0)
    lines[#lines+1] = string.format("⚔ 击败 %d波 / %d艘 | 💥 伤害 %s",
        stats_.wavesCleared or 0,
        stats_.enemiesKilled or 0,
        (stats_.dmgDealt or 0) >= 10000
            and string.format("%.1fw", (stats_.dmgDealt or 0) / 10000)
            or tostring(math.floor(stats_.dmgDealt or 0)))
    -- MVP
    if stats_.mvpShip then
        local mvpName = shipNames[stats_.mvpShip] or stats_.mvpShip
        lines[#lines+1] = string.format("⭐ MVP: %s", mvpName)
    end
    -- 存活旗舰
    if stats_.bestSurvivor then
        local surv = shipNames[stats_.bestSurvivor] or stats_.bestSurvivor
        lines[#lines+1] = string.format("🛡 存活旗舰: %s", surv)
    end
    -- 连锁反应
    if (stats_.chainCount or 0) > 0 then
        lines[#lines+1] = string.format("🔗 连锁反应: %d次", stats_.chainCount)
    end
    -- 指挥官
    lines[#lines+1] = string.format("👤 Lv.%d %s", stats_.level or 1, stats_.rank or "指挥官")
    -- 精彩时刻
    if replayData_ and replayData_.highlights and #replayData_.highlights > 0 then
        lines[#lines+1] = "── 精彩时刻 ──"
        local maxHL = math.min(3, #replayData_.highlights)
        for i = 1, maxHL do
            local hl = replayData_.highlights[i]
            local tStr = string.format("%d:%02d", math.floor(hl.time / 60), math.floor(hl.time % 60))
            lines[#lines+1] = string.format("  [%s] %s", tStr, hl.desc or "精彩操作")
        end
    end
    -- 联赛标签
    if stats_.leagueScore then
        local rankName = (stats_.leagueRank and stats_.leagueRank.name) or "未定级"
        lines[#lines+1] = string.format("🏅 联赛 %s · %d分%s",
            rankName, stats_.leagueScore,
            stats_.leagueNewBest and " (NEW!)" or "")
    end
    -- 星级
    local starStr = string.rep("⭐", stats_.stars or 1)
    lines[#lines+1] = "评价: " .. starStr
    lines[#lines+1] = string.rep("─", 20)
    lines[#lines+1] = "#银河征服 #TapTap"
    return table.concat(lines, "\n")
end

-- ── 排行榜渲染 ────────────────────────────────────────────────────────────────
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

-- ── P3-1: 个人主页弹窗渲染 ───────────────────────────────────────────────────
--- 点击排行榜任意行后弹出玩家战绩详情卡片（300×260px）
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

-- ── P3-2: 6维度雷达图 ────────────────────────────────────────────────────────
--- 绘制6轴六边形雷达图
---@param vg      userdata  NanoVG context
---@param cx      number    中心 x
---@param cy      number    中心 y
---@param radius  number    最大半径（像素）
---@param dims    table     { {label, value (0-1)} … } 顺时针6个维度
---@param ease    number    动画进度 0-1
local function renderRadarChart(vg, cx, cy, radius, dims, ease)
    local N = #dims  -- 6
    -- 各顶点方向，从顶部(-π/2)顺时针
    local angles = {}
    for i = 1, N do
        angles[i] = -math.pi / 2 + (i - 1) * (2 * math.pi / N)
    end

    -- 1. 背景网格（三层：0.33 / 0.66 / 1.0）
    for layer = 1, 3 do
        local r = radius * (layer / 3)
        nvgBeginPath(vg)
        for i = 1, N do
            local px = cx + r * math.cos(angles[i])
            local py = cy + r * math.sin(angles[i])
            if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
        end
        nvgClosePath(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 100, 160, math.floor(60 * ease)))
        nvgStrokeWidth(vg, 0.8)
        nvgStroke(vg)
    end

    -- 2. 辐射轴线
    for i = 1, N do
        local px = cx + radius * math.cos(angles[i])
        local py = cy + radius * math.sin(angles[i])
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy)
        nvgLineTo(vg, px, py)
        nvgStrokeColor(vg, nvgRGBA(80, 100, 160, math.floor(50 * ease)))
        nvgStrokeWidth(vg, 0.7)
        nvgStroke(vg)
    end

    -- 3. 数据多边形（填充 + 描边）
    nvgBeginPath(vg)
    for i = 1, N do
        local v  = math.max(0.05, (dims[i].value or 0) * ease)  -- ease 动画缩放
        local r  = radius * v
        local px = cx + r * math.cos(angles[i])
        local py = cy + r * math.sin(angles[i])
        if i == 1 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(80, 180, 255, math.floor(55 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 220, 255, math.floor(230 * ease)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 4. 顶点圆点
    for i = 1, N do
        local v  = math.max(0.05, (dims[i].value or 0) * ease)
        local r  = radius * v
        local px = cx + r * math.cos(angles[i])
        local py = cy + r * math.sin(angles[i])
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, 3)
        nvgFillColor(vg, nvgRGBA(180, 240, 255, math.floor(220 * ease)))
        nvgFill(vg)
    end

    -- 5. 标签（轴末端外侧）
    local LABEL_GAP = 14
    nvgFontFace(vg, "sans")
    for i = 1, N do
        local lr = radius + LABEL_GAP
        local px = cx + lr * math.cos(angles[i])
        local py = cy + lr * math.sin(angles[i])
        -- 对齐：左右轴居中，顶/底轴居中
        local alignH
        local cosA = math.cos(angles[i])
        if cosA > 0.3 then
            alignH = NVG_ALIGN_LEFT
        elseif cosA < -0.3 then
            alignH = NVG_ALIGN_RIGHT
        else
            alignH = NVG_ALIGN_CENTER
        end
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, alignH + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(160, 190, 240, math.floor(210 * ease)))
        nvgText(vg, px, py, dims[i].label)

        -- 百分比数值（轴内稍偏，仅在 ease > 0.6 时显示）
        if ease > 0.6 then
            local pct = math.floor((dims[i].value or 0) * 100)
            local vr  = radius * math.max(0.05, dims[i].value or 0) * ease
            local vx  = cx + vr * math.cos(angles[i])
            local vy  = cy + vr * math.sin(angles[i])
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(200 * (ease - 0.6) / 0.4)))
            nvgText(vg, vx, vy - 6, pct .. "%")
        end
    end
end

-- ── 结算面板渲染 ──────────────────────────────────────────────────────────────
local function renderEndGame()
    if not active_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    local isWin = (gameType_ == "win")
    local AT    = animT_          -- 原始计时器（0→3.0 @ 1.5/s）

    -- P1-3: 缓动辅助函数
    local function easeOutBack(x)
        local c1 = 1.70158; local c3 = c1 + 1
        return 1 + c3 * (x - 1)^3 + c1 * (x - 1)^2
    end
    local function easeOutElastic(x)
        if x <= 0 then return 0 end
        if x >= 1 then return 1 end
        local c4 = (2 * math.pi) / 3
        return 2^(-10*x) * math.sin((x*10 - 0.75) * c4) + 1
    end
    -- 通用滑段：将 AT 映射到 [start, start+dur] → 0→1
    local function seg(start, dur)
        return math.max(0, math.min(1, (AT - start) / dur))
    end

    -- 面板主 ease：0→0.65s 用 easeOutBack（过冲回弹），纯位置用
    local tPos  = seg(0, 0.65)
    local easePos = easeOutBack(tPos)
    -- Alpha ease：0→0.4s smoothstep（避免 easeOutBack 导致 alpha>1 闪屏）
    local tAlpha = seg(0, 0.4)
    local ease   = tAlpha * tAlpha * (3 - 2 * tAlpha)

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(180 * ease)))
    nvgFill(vg)

    local dw, dh = 480, 748  -- P1-3: 扩高以容纳联赛横幅（+48px）
    local dx = (screenW - dw) / 2
    -- P1-3: 用 easePos 做位置（过冲），用 ease 做 alpha（不过冲）
    local dy = (screenH - dh) / 2 + (1 - easePos) * screenH * 0.3

    local glowR, glowG, glowB = isWin and 80 or 220, isWin and 220 or 50, isWin and 60 or 50
    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx-3, dy-3, dw+6, dh+6, 16)
    nvgFillColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(70 * ease)))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, dx, dy, dw, dh, 14)
    nvgFillColor(vg, nvgRGBA(8, 10, 22, 252))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(220 * ease)))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 44)
    nvgFillColor(vg, nvgRGBA(glowR+40, glowG+40, glowB+40, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, dy + 56, isWin and "🏆" or "💀")

    nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(glowR+60, glowG+60, glowB+60, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, dy + 102, isWin and "银河征服完成！" or "帝国覆灭")

    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(160, 180, 220, math.floor(200 * ease)))
    nvgText(vg, screenW / 2, dy + 124,
        isWin and "你已消灭所有海盗势力，统一银河！" or "星航基地已被摧毁，帝国就此终结。")

    -- P1-3: 星级评分 — 逐颗弹出动画
    local starCount = stats_.stars or 1
    local starCx    = screenW / 2
    local starY     = dy + 152
    nvgFontSize(vg, 8)
    nvgFillColor(vg, nvgRGBA(120, 140, 180, math.floor(160 * ease)))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, starCx, starY - 10, "本局评级")
    for i = 1, 3 do
        local sx_i  = starCx + (i - 2) * 48
        local filled = (i <= starCount)
        -- P1-3: 每颗星在 AT=0.2+(i-1)*0.18s 处弹出（easeOutElastic）
        local starT  = seg(0.2 + (i - 1) * 0.18, 0.45)
        local starSc = easeOutElastic(starT)
        nvgSave(vg)
        nvgTranslate(vg, sx_i, starY)
        nvgScale(vg, starSc, starSc)
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 26)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if filled then
            nvgFillColor(vg, nvgRGBA(255, 180, 0, math.floor(60 * ease)))
            nvgText(vg, 1, 1, "★")
            nvgFillColor(vg, nvgRGBA(255, 210, 30, math.floor(255 * ease)))
        else
            nvgFillColor(vg, nvgRGBA(60, 70, 100, math.floor(180 * ease)))
        end
        nvgText(vg, 0, 0, filled and "★" or "☆")
        nvgRestore(vg)
    end

    -- P1-3: 胜利时金色闪光粒子（AT=0.6s 后激活，持续至 AT=2.5s）
    if isWin and AT > 0.6 and AT < 2.5 then
        local pt    = AT - 0.6          -- 粒子时间 0→1.9s
        local NPART = 16
        for pi = 1, NPART do
            -- 每颗粒子有独立的相位偏移（伪随机）
            local phase  = (pi - 1) / NPART * 2.0
            local localT = (pt - phase) % 1.8   -- 0→1.8 循环
            if localT < 1.5 then
                local lt01   = localT / 1.5
                local angle  = (pi - 1) * (math.pi * 2 / NPART) + lt01 * 0.4
                local radius = 30 + (pi % 4) * 12
                local px2    = dx + dw / 2 + math.cos(angle) * radius
                local py2    = starY - 20 - lt01 * 40  -- 向上漂移
                local alpha  = math.floor((1 - lt01) * 200)
                local r2     = (pi % 2 == 0) and 2.0 or 1.4
                nvgBeginPath(vg)
                nvgCircle(vg, px2, py2, r2)
                nvgFillColor(vg, nvgRGBA(255, 210 + (pi % 3) * 15, 30, alpha))
                nvgFill(vg)
            end
        end
    end

    -- 分割线
    local lx1, lx2, ly = dx + 30, dx + dw - 30, dy + 180
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, ly); nvgLineTo(vg, lx2, ly)
    nvgStrokeColor(vg, nvgRGBA(glowR, glowG, glowB, math.floor(80 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- P2-2c: 统计/日志 标签切换
    local tabY = ly + 6
    local tabW = 70
    local tabH = 22
    local tab1X = dx + dw / 2 - tabW - 4
    local tab2X = dx + dw / 2 + 4
    for ti, tabInfo in ipairs({
        { x = tab1X, label = "📊 统计", active = not logTabActive_ },
        { x = tab2X, label = "📜 日志", active = logTabActive_ },
    }) do
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tabInfo.x, tabY, tabW, tabH, 4)
        if tabInfo.active then
            nvgFillColor(vg, nvgRGBA(30, 50, 100, math.floor(220 * ease)))
        else
            nvgFillColor(vg, nvgRGBA(15, 20, 40, math.floor(160 * ease)))
        end
        nvgFill(vg)
        if tabInfo.active then
            nvgStrokeColor(vg, nvgRGBA(80, 160, 255, math.floor(200 * ease)))
            nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        end
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(
            tabInfo.active and 180 or 100,
            tabInfo.active and 210 or 130,
            255,
            math.floor((tabInfo.active and 255 or 160) * ease)))
        nvgText(vg, tabInfo.x + tabW / 2, tabY + tabH / 2, tabInfo.label)
    end
    if ease > 0.8 then
        addHit(tab1X, tabY, tabW, tabH, function() logTabActive_ = false end)
        addHit(tab2X, tabY, tabW, tabH, function() logTabActive_ = true; logScrollY_ = 0 end)
    end

    if not logTabActive_ then
    local function fmtTime(s)
        local m   = math.floor((s or 0) / 60)
        local sec = math.floor((s or 0) % 60)
        return string.format("%d分%02d秒", m, sec)
    end
    local baseRows = {
        { label="游戏时长", value=fmtTime(stats_.playTime) },
        { label="殖民星球", value=tostring(stats_.colonized or 0) .. " 颗" },
        { label="击败海盗", value=tostring(stats_.piratesKilled or 0) .. " 次" },
        { label="最终等级", value="Lv." .. tostring(stats_.level or 1) .. "  [" .. (stats_.rank or "见习指挥官") .. "]" },
    }
    local sy = dy + 194
    -- P1-3: 基础统计行逐行错开淡入+从左滑入（0.35s + 行号*0.1s 时启动）
    for ri, row in ipairs(baseRows) do
        local rowT   = seg(0.35 + (ri - 1) * 0.10, 0.25)
        local rowEase = rowT * rowT * (3 - 2 * rowT)
        local slideX  = (1 - rowEase) * 18   -- 从右偏移18px滑入
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 150, 200, math.floor(180 * rowEase)))
        nvgText(vg, dx + 60 - slideX, sy + 7, row.label)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 220, 255, math.floor(230 * rowEase)))
        nvgText(vg, dx + dw - 60 + slideX, sy + 7, row.value)
        sy = sy + 22
    end

    -- 分割线2
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, sy + 4); nvgLineTo(vg, lx2, sy + 4)
    nvgStrokeColor(vg, nvgRGBA(60, 80, 140, math.floor(80 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 14

    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 130, 200, math.floor(160 * ease)))
    nvgText(vg, screenW / 2, sy + 7, "— 战斗详情 —")
    sy = sy + 18

    local shipNames = {
        SCOUT="侦察舰", FRIGATE="护卫舰", DESTROYER="驱逐舰",
        BATTLECRUISER="战列舰", CARRIER="航母", INTERCEPTOR="拦截机",
        MINER="采矿舰", ENGINEER="工程舰", EXPLORER="探索舰",
    }
    local function fmtNum(n)
        if n >= 10000 then return string.format("%.1fw", n/10000) end
        return tostring(math.floor(n or 0))
    end
    local survivor = stats_.bestSurvivor and (shipNames[stats_.bestSurvivor] or stats_.bestSurvivor) or "—"
    local battleRows = {
        { label="伤害输出", value=fmtNum(stats_.dmgDealt or 0),      color={80,220,120} },
        { label="受到伤害", value=fmtNum(stats_.dmgTaken or 0),      color={220,100,80} },
        { label="击落敌舰", value=(stats_.enemiesKilled or 0).." 艘", color={200,180,80} },
        { label="通关波次", value=(stats_.wavesCleared  or 0).." 波", color={120,180,255} },
        { label="存活旗舰", value=survivor,                           color={180,140,255} },
        { label="连锁反应", value=(stats_.chainCount    or 0).." 次", color={255,160,40}  },  -- P1-3
    }
    -- P1-3: 战斗详情行从 0.75s 开始逐行错开（间隔0.08s）
    for bi, row in ipairs(battleRows) do
        local bRowT   = seg(0.75 + (bi - 1) * 0.08, 0.22)
        local bRowE   = bRowT * bRowT * (3 - 2 * bRowT)
        local bSlideX = (1 - bRowE) * 14
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 180, math.floor(160 * bRowE)))
        nvgText(vg, dx + 60 - bSlideX, sy + 7, row.label)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(row.color[1], row.color[2], row.color[3], math.floor(230 * bRowE)))
        nvgText(vg, dx + dw - 60 + bSlideX, sy + 7, row.value)
        sy = sy + 20
    end

    if stats_.mvpShip then
        local mvpName   = shipNames[stats_.mvpShip] or stats_.mvpShip
        local mvpReason = stats_.mvpReason or "综合表现最佳"
        local mvpT    = seg(1.20, 0.30)
        local mvpE    = mvpT * mvpT * (3 - 2 * mvpT)

        -- MVP 卡片背景（金色渐变）
        local mvpCardX = dx + 40
        local mvpCardW = dw - 80
        local mvpCardH = 36
        local mvpCardY = dy + sy - 2

        nvgBeginPath(vg)
        nvgRoundedRect(vg, mvpCardX, mvpCardY, mvpCardW, mvpCardH, 5)
        local mvpGrad = nvgLinearGradient(vg, mvpCardX, mvpCardY, mvpCardX + mvpCardW, mvpCardY,
            nvgRGBA(50, 40, 10, math.floor(180 * mvpE)),
            nvgRGBA(30, 25, 8, math.floor(160 * mvpE)))
        nvgFillPaint(vg, mvpGrad)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(220, 180, 40, math.floor(160 * mvpE)))
        nvgStrokeWidth(vg, 1.0)
        nvgStroke(vg)

        -- 左侧: MVP标签+舰种
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(240 * mvpE)))
        nvgText(vg, mvpCardX + 10, mvpCardY + mvpCardH / 2 - 6, "⭐ MVP  " .. mvpName)

        -- 下方: 原因
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(200, 170, 80, math.floor(180 * mvpE)))
        nvgText(vg, mvpCardX + 28, mvpCardY + mvpCardH / 2 + 8, mvpReason)

        -- 右侧: 评分
        if stats_.mvpScore and stats_.mvpScore > 0 then
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 220, 100, math.floor(200 * mvpE)))
            nvgText(vg, mvpCardX + mvpCardW - 10, mvpCardY + mvpCardH / 2,
                string.format("%.0f pts", stats_.mvpScore))
        end

        sy = sy + mvpCardH + 6
    end

    -- P3-1: 战斗精彩时刻（最多显示3条高光）──────────────────────────────────
    if replayData_ and replayData_.highlights and #replayData_.highlights > 0 then
        local hlT = seg(1.40, 0.25)
        local hlE = hlT * hlT * (3 - 2 * hlT)
        local maxShow = math.min(3, #replayData_.highlights)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(130, 160, 220, math.floor(140 * hlE)))
        nvgText(vg, dx + 50, dy + sy + 4, "精彩时刻")
        sy = sy + 14

        for hi = 1, maxShow do
            local hl = replayData_.highlights[hi]
            local rowT = seg(1.40 + hi * 0.06, 0.20)
            local rowE = rowT * rowT * (3 - 2 * rowT)

            -- 时间标签
            local tStr = string.format("%d:%02d", math.floor(hl.time / 60), math.floor(hl.time % 60))
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(80, 120, 180, math.floor(160 * rowE)))
            nvgText(vg, dx + 55, dy + sy + 5, tStr)

            -- 描述
            local desc = hl.desc or "精彩操作"
            nvgFillColor(vg, nvgRGBA(180, 200, 240, math.floor(200 * rowE)))
            nvgText(vg, dx + 90, dy + sy + 5, desc)

            -- 评分条
            local barX = dx + dw - 90
            local barW = 40
            local barH = 4
            local barY = dy + sy + 3
            local fillW = barW * math.min(1, (hl.score or 0) / 100)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, barH, 2)
            nvgFillColor(vg, nvgRGBA(40, 50, 80, math.floor(120 * rowE)))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, fillW, barH, 2)
            nvgFillColor(vg, nvgRGBA(255, 180, 40, math.floor(200 * rowE)))
            nvgFill(vg)

            sy = sy + 14
        end
        sy = sy + 4
    end

    -- 分割线3
    nvgBeginPath(vg)
    nvgMoveTo(vg, lx1, sy + 4); nvgLineTo(vg, lx2, sy + 4)
    nvgStrokeColor(vg, nvgRGBA(60, 80, 140, math.floor(60 * ease)))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 14

    -- P3-2: 六维度雷达图 ───────────────────────────────────────────────────────
    do
        local dmgDealt  = stats_.dmgDealt  or 0
        local dmgTaken  = stats_.dmgTaken  or 0
        local colonized = stats_.colonized or 0
        local totalRes  = stats_.totalResearch or 0
        local pirates   = stats_.piratesKilled or 0
        local waves     = stats_.wavesCleared  or 0

        -- 防御能力：伤害比越低越好，0 = 全部扣血，1 = 零伤
        local defRaw = dmgDealt > 0 and (1 - math.min(1, dmgTaken / dmgDealt)) or (dmgTaken == 0 and 1 or 0)

        local dims = {
            { label = "战斗强度", value = math.min(1, dmgDealt  / 50000) },
            { label = "防御能力", value = math.max(0, defRaw)            },
            { label = "扩张速度", value = math.min(1, colonized / 8)     },
            { label = "科研进度", value = math.min(1, totalRes  / 12)    },
            { label = "战术效率", value = math.min(1, pirates   / 20)    },
            { label = "生存时间", value = math.min(1, waves     / 10)    },
        }

        -- 雷达图区域：宽 dw，高 136，居中
        local RADAR_H  = 136
        local rcx      = dx + dw / 2
        local rcy      = dy + sy + RADAR_H / 2  -- 面板内绝对坐标
        local radius   = 46

        -- 标题
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 130, 200, math.floor(160 * ease)))
        nvgText(vg, screenW / 2, dy + sy + 8, "— 综合评估 —")

        renderRadarChart(vg, rcx, rcy + 12, radius, dims, ease)

        sy = sy + RADAR_H + 8
    end
    -- ─────────────────────────────────────────────────────────────────────────

    -- P1-3: 联赛得分横幅 ──────────────────────────────────────────────────────
    if stats_.leagueScore then
        local lsT  = seg(1.45, 0.30)
        local lsE  = lsT * lsT * (3 - 2 * lsT)
        local lsBW = dw - 60
        local lsBH = 38
        local lsBX = dx + (dw - lsBW) / 2
        local lsBY = dy + sy

        -- 金色渐变背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, lsBX, lsBY, lsBW, lsBH, 6)
        local lsGrad = nvgLinearGradient(vg, lsBX, lsBY, lsBX + lsBW, lsBY,
            nvgRGBA(40, 30, 10, math.floor(200 * lsE)),
            nvgRGBA(20, 15, 5, math.floor(200 * lsE)))
        nvgFillPaint(vg, lsGrad)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(200, 170, 50, math.floor(180 * lsE)))
        nvgStrokeWidth(vg, 1.2)
        nvgStroke(vg)

        -- 左侧: 段位图标+名称
        local rankIcon = "🏆"
        local rankName = "未定级"
        if stats_.leagueRank then
            rankIcon = stats_.leagueRank.icon or "🏆"
            rankName = stats_.leagueRank.name or "未定级"
        end
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 210, 60, math.floor(230 * lsE)))
        nvgText(vg, lsBX + 10, lsBY + lsBH / 2, string.format("%s %s", rankIcon, rankName))

        -- 右侧: 联赛得分
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(255, 230, 100, math.floor(255 * lsE)))
        nvgText(vg, lsBX + lsBW - 10, lsBY + lsBH / 2,
            string.format("联赛得分  %d", stats_.leagueScore))

        -- 新纪录标记
        if stats_.leagueNewBest then
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(255, 80, 80, math.floor(220 * lsE)))
            nvgText(vg, lsBX + lsBW - 10, lsBY + lsBH / 2 + 14, "★ NEW BEST!")
        end

        sy = sy + lsBH + 8
    end
    -- ─────────────────────────────────────────────────────────────────────────
    else
        -- P2-2c: 战斗日志渲染
        local logEntries = stats_.battleLog or {}
        local logStartY = dy + 210
        local logEndY   = dy + dh - 120  -- 按钮区域上方留空
        local logH      = logEndY - logStartY
        local ROW_H     = 18
        local maxScroll = math.max(0, #logEntries * ROW_H - logH)
        logScrollY_ = math.max(0, math.min(logScrollY_, maxScroll))

        -- 裁剪区域
        nvgSave(vg)
        nvgScissor(vg, dx + 20, logStartY, dw - 40, logH)

        if #logEntries == 0 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 120, 160, math.floor(160 * ease)))
            nvgText(vg, screenW / 2, logStartY + logH / 2, "暂无战斗日志")
        else
            for li, entry in ipairs(logEntries) do
                local ey = logStartY + (li - 1) * ROW_H - logScrollY_
                if ey > logStartY - ROW_H and ey < logEndY then
                    local logRowT = seg(0.35 + (li - 1) * 0.03, 0.20)
                    local logRowE = logRowT * logRowT * (3 - 2 * logRowT)

                    -- 波次标签
                    nvgFontFace(vg, "sans")
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(60, 120, 200, math.floor(180 * logRowE)))
                    nvgText(vg, dx + 30, ey + ROW_H / 2, string.format("[W%d]", entry.wave or 0))

                    -- 日志文本
                    nvgFontSize(vg, 10)
                    nvgFillColor(vg, nvgRGBA(170, 190, 230, math.floor(220 * logRowE)))
                    nvgText(vg, dx + 70, ey + ROW_H / 2, entry.text or "")
                end
            end
        end

        nvgRestore(vg)

        -- 滚动条（超过可见区域时显示）
        if maxScroll > 0 then
            local scrollBarH = math.max(20, logH * (logH / (#logEntries * ROW_H)))
            local scrollBarY = logStartY + (logScrollY_ / maxScroll) * (logH - scrollBarH)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, dx + dw - 28, scrollBarY, 4, scrollBarH, 2)
            nvgFillColor(vg, nvgRGBA(80, 120, 180, math.floor(120 * ease)))
            nvgFill(vg)
        end

        -- 滚动交互区域（允许鼠标滚轮/拖拽滚动在 Update 中处理）
        if ease > 0.8 and maxScroll > 0 then
            addHit(dx + 20, logStartY, dw - 40, logH, function()
                -- 点击不做什么，滚动在 Update 中处理
            end)
        end
    end

    -- 再来一局按钮
    local bw, bh = 200, 44
    local bx = (screenW - bw) / 2
    local by = dy + dh - 60

    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 8)
    nvgFillColor(vg, nvgRGBA(
        isWin and 30 or 160,
        isWin and 120 or 40,
        isWin and 200 or 40,
        math.floor(220 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(
        isWin and 80 or 220,
        isWin and 180 or 80,
        isWin and 255 or 80,
        math.floor(200 * ease)))
    nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 235, 255, math.floor(255 * ease)))
    nvgText(vg, screenW / 2, by + bh / 2, "🔄  再来一局")

    if ease > 0.8 then
        addHit(bx, by, bw, bh, function()
            if onRetry_ then onRetry_() end
        end)
    end

    -- 广告按钮
    local adw, adh = 240, 38
    local adx = (screenW - adw) / 2
    local ady = by - adh - 8

    if adWatched_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        nvgFillColor(vg, nvgRGBA(20, 60, 20, math.floor(180 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 180, 60, math.floor(140 * ease)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(80, 220, 100, math.floor(230 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "✅  下局资源加成已激活！")
    elseif adLoading_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        nvgFillColor(vg, nvgRGBA(40, 40, 40, math.floor(160 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 80, 80, math.floor(120 * ease)))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(140, 140, 140, math.floor(200 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "广告加载中…")
    elseif adCb_ then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, adx, ady, adw, adh, 7)
        local grad = nvgLinearGradient(vg, adx, ady, adx, ady + adh,
            nvgRGBA(120, 80, 0, math.floor(230 * ease)),
            nvgRGBA(80, 50, 0, math.floor(210 * ease)))
        nvgFillPaint(vg, grad)
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 60, math.floor(220 * ease)))
        nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(255 * ease)))
        nvgText(vg, screenW / 2, ady + adh / 2, "🎬  看广告 · 下局获得资源加成")
        if ease > 0.8 then
            addHit(adx, ady, adw, adh, function()
                if adLoading_ or adWatched_ then return end
                adLoading_ = true
                adCb_(function(success, msg)
                    adLoading_ = false
                    if success then
                        adWatched_ = true
                        if notifyFn_ then notifyFn_("🎬 广告观看完成！下局资源加成已激活", "info") end
                    else
                        if notifyFn_ then notifyFn_("广告未完整播放，请重试", "warn") end
                    end
                end)
            end)
        end
    end

    -- P3-1: 战斗回放按钮（排行榜上方）
    local rpw, rph = 160, 34
    local rpx = (screenW - rpw) / 2
    local rpy = ady - rph - 8

    if replayData_ and replayData_.frameCount and replayData_.frameCount > 0 then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, rpx, rpy, rpw, rph, 7)
        nvgFillColor(vg, nvgRGBA(20, 40, 60, math.floor(200 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 160, 200, math.floor(180 * ease)))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 200, 240, math.floor(240 * ease)))
        local durStr = ""
        if replayData_.duration then
            durStr = string.format(" (%d:%02d)",
                math.floor(replayData_.duration / 60),
                math.floor(replayData_.duration % 60))
        end
        nvgText(vg, screenW / 2, rpy + rph / 2, "🎬  战斗回放" .. durStr)

        if ease > 0.8 then
            addHit(rpx, rpy, rpw, rph, function()
                if replayBtnCb_ then
                    replayBtnCb_(replayData_)
                elseif notifyFn_ then
                    notifyFn_("回放功能开发中…", "info")
                end
            end)
        end
        rpy = rpy - rph - 6
    end

    -- 排行榜按钮
    local lbw, lbh = 160, 34
    local lbx = (screenW - lbw) / 2
    local lby = rpy - lbh + (rpy == (ady - rph - 8) and 0 or 2)
    -- 如果没有回放按钮，lby回退到原来的位置
    if not (replayData_ and replayData_.frameCount and replayData_.frameCount > 0) then
        lby = ady - lbh - 8
    end

    nvgBeginPath(vg)
    nvgRoundedRect(vg, lbx, lby, lbw, lbh, 7)
    nvgFillColor(vg, nvgRGBA(40, 30, 80, math.floor(200 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(120, 80, 220, math.floor(180 * ease)))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 150, 255, math.floor(240 * ease)))
    nvgText(vg, screenW / 2, lby + lbh / 2, "🏅  银河排行榜")

    if ease > 0.8 then
        addHit(lbx, lby, lbw, lbh, function()
            lbVisible_  = true
            lbLoading_  = true
            lbData_     = nil
            lbMyRank_   = nil
            lbMyScore_  = nil
            lbAnimT_    = 0
            if lbOnRequest_ then
                lbOnRequest_(function(data, myRank, myScore)
                    lbData_    = data
                    lbMyRank_  = myRank
                    lbMyScore_ = myScore
                    lbLoading_ = false
                end)
            else
                lbLoading_ = false
            end
        end)
    end

    -- P3-2: 生成战报按钮（排行榜上方）
    local rprtW, rprtH = 160, 34
    local rprtX = (screenW - rprtW) / 2
    local rprtY = lby - rprtH - 6

    nvgBeginPath(vg)
    nvgRoundedRect(vg, rprtX, rprtY, rprtW, rprtH, 7)
    if reportCopiedT_ > 0 then
        -- 已复制状态：绿色
        nvgFillColor(vg, nvgRGBA(20, 60, 30, math.floor(220 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 200, 80, math.floor(200 * ease)))
    else
        nvgFillColor(vg, nvgRGBA(20, 40, 50, math.floor(200 * ease)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(80, 180, 160, math.floor(180 * ease)))
    end
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if reportCopiedT_ > 0 then
        nvgFillColor(vg, nvgRGBA(100, 240, 120, math.floor(255 * ease)))
        nvgText(vg, screenW / 2, rprtY + rprtH / 2, "✅  已复制到剪贴板")
    else
        nvgFillColor(vg, nvgRGBA(140, 220, 200, math.floor(240 * ease)))
        nvgText(vg, screenW / 2, rprtY + rprtH / 2, "📋  生成战报")
    end

    if ease > 0.8 and reportCopiedT_ <= 0 then
        addHit(rprtX, rprtY, rprtW, rprtH, function()
            local report = generateBattleReport()
            ui:SetClipboardText(report)
            reportCopiedT_ = 2.0  -- 2秒反馈
            if notifyFn_ then notifyFn_("📋 战报已复制到剪贴板", "success") end
        end)
    end
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 每帧更新动画计时器（由 GameUI.UpdateNotifications 调用）
---@param dt number 帧间隔（秒）
function EndGamePanel.Update(dt)
    if active_ and animT_ < 3.0 then
        animT_ = animT_ + dt * 1.5   -- P1-3: 延长到3.0，支持逐行错开动画
    end
    if lbVisible_ and lbAnimT_ < LB_ANIM_DUR + LB_ROW_STAGGER * 15 then
        lbAnimT_ = lbAnimT_ + dt
    end
    -- P3-1: 个人主页弹窗弹入动画计时（弹入后继续递增供脉冲动画使用）
    if profileEntry_ then
        profileAnimT_ = profileAnimT_ + dt
    end
    -- P3-2: 战报复制反馈计时器倒计时
    if reportCopiedT_ > 0 then
        reportCopiedT_ = reportCopiedT_ - dt
        if reportCopiedT_ < 0 then reportCopiedT_ = 0 end
    end
    -- P2-2c: 日志标签页滚轮滚动
    if active_ and logTabActive_ then
        local wheel = input:GetMouseMoveWheel()
        if wheel ~= 0 then
            logScrollY_ = logScrollY_ - wheel * 36
            local logEntries = stats_.battleLog or {}
            local logH = (748 - 120 - 210)  -- approx visible height
            local maxScroll = math.max(0, #logEntries * 18 - logH)
            logScrollY_ = math.max(0, math.min(logScrollY_, maxScroll))
        end
    end
end

--- 渲染结算界面（每帧调用）
function EndGamePanel.Render()
    renderEndGame()
end

--- 渲染排行榜（每帧调用，在结算面板之后调用）
function EndGamePanel.RenderLeaderboard()
    renderLeaderboard()
    renderProfilePopup()   -- P3-1: 弹出个人主页卡片
end

--- 显示结算界面
---@param gameType string  "win" | "lose"
---@param stats    table   统计数据
---@param onRetry  function 再来一局回调
function EndGamePanel.Show(gameType, stats, onRetry)
    active_     = true
    gameType_   = gameType
    stats_      = stats or {}
    onRetry_    = onRetry
    animT_      = 0
    reportCopiedT_ = 0  -- P3-2: 重置战报复制反馈
    logTabActive_ = false   -- P2-2c: 重置标签页到统计
    logScrollY_   = 0       -- P2-2c: 重置日志滚动位置
end

--- 隐藏结算界面并重置状态
function EndGamePanel.Hide()
    active_        = false
    gameType_      = nil
    stats_         = {}
    animT_         = 0
    adWatched_     = false
    adLoading_     = false
    lbVisible_     = false
    lbData_        = nil
    lbAnimT_       = 0
    profileEntry_  = nil   -- P3-1: 关闭时清除弹窗
    profileAnimT_  = 0
    replayData_    = nil   -- P3-1: 清除回放数据
    reportCopiedT_ = 0    -- P3-2: 重置战报复制反馈
end

--- 是否当前结算界面可见
function EndGamePanel.IsActive()
    return active_
end

--- 注入结算广告回调
---@param fn function  fn(onResult) — onResult(success, msg)
function EndGamePanel.SetAdCallback(fn)
    adCb_ = fn
end

--- 注入排行榜请求回调
---@param fn function  fn(callback) — callback(data, myRank, myScore)
function EndGamePanel.SetLeaderboardCallback(fn)
    lbOnRequest_ = fn
end

--- 注入通知函数（用于广告结果通知）
---@param fn function  fn(msg, ntype)
function EndGamePanel.SetNotifyFn(fn)
    notifyFn_ = fn
end

--- P3-1: 注入本玩家生涯数据，用于个人主页弹窗展示
---@param career table  { totalGames, totalWins, bestWave, totalKills, totalColonies, playtime, bestMvpShip }
function EndGamePanel.SetCareerStats(career)
    profileCareer_ = career
end

--- P3-1: 注入战斗回放数据（由 GameUI 在结算时从 BattleScene.GetReplayData() 获取后注入）
---@param data table  {highlights, mvp, duration, frameCount, eventCount}
function EndGamePanel.SetReplayData(data)
    replayData_ = data
end

--- P3-1: 注入"查看回放"按钮的点击回调
---@param fn function  fn(replayData)
function EndGamePanel.SetReplayCallback(fn)
    replayBtnCb_ = fn
end

return EndGamePanel
