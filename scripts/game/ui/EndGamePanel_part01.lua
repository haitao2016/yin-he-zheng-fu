-- Auto-split from EndGamePanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
