-- ============================================================================
-- network/ClientStats.lua  -- P2-3: 局内统计面板渲染
-- 负责：renderStatsPanel 的全部绘制逻辑
-- 不负责：statsOpen_ / statsMouse_ 状态变量（仍在 Client.lua）
-- ============================================================================
local ClientStats = {}

local GalaxyScene = require("game.GalaxyScene")
local Achievement = require("game.AchievementSystem")

-- ============================================================================
-- Render
-- 渲染全屏统计面板（Tab 键触发）
-- vg  : NanoVG 上下文（vg_）
-- sw, sh : 屏幕虚拟分辨率
-- ctx = {
--   statsOpen        bool          -- false 时立即返回
--   statsMouse       {x, y}        -- 鼠标坐标，用于关闭按钮热区
--   rs               ResearchSystem -- rs_.unlocked 统计已研究科技数
--   rm               ResourceManager -- rm_.resources / rm_.rates
--   piratesKilled    number
--   battleStatsCache table         -- { totalEnemiesKilled, shipsLost, maxCombo }
--   TL               table         -- { playTime, extraTime, BASE_LIMIT }
--   getRemainingTime function()→number
-- }
-- （TECHS 全局变量由 game.Systems 在同 Lua 状态中定义，直接使用）
-- ============================================================================
function ClientStats.Render(vg, sw, sh, ctx)
    if not ctx.statsOpen then return end

    -- ① 全屏半透明遮罩（点击关闭）
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 0, 20, 190))
    nvgFill(vg)

    -- ② 面板主体：居中 600×420
    local PW, PH = 620, 430
    local px = (sw - PW) * 0.5
    local py = (sh - PH) * 0.5

    -- 背景卡片
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 12)
    nvgFillColor(vg, nvgRGBA(15, 20, 45, 235))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 220, 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题栏
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 255))
    nvgText(vg, px + PW * 0.5, py + 22, "📊  本局统计")

    -- 关闭按钮（右上角 ×）
    local closeX = px + PW - 20
    local closeY = py + 18
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local cx, cy = ctx.statsMouse[1], ctx.statsMouse[2]
    local closeDist = math.sqrt((cx - closeX)^2 + (cy - closeY)^2)
    nvgFillColor(vg, closeDist < 14 and nvgRGBA(255,100,100,255) or nvgRGBA(180,180,180,200))
    nvgText(vg, closeX, closeY, "✕")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 36)
    nvgLineTo(vg, px + PW - 16, py + 36)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 220, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- ③ 采集统计数据
    -- 殖民
    local allPlanets  = GalaxyScene.GetAllPlanets and GalaxyScene.GetAllPlanets() or {}
    local totalPlanets = 0
    local colonized   = 0
    for _, p in ipairs(allPlanets) do
        if not p.deepSpace then
            totalPlanets = totalPlanets + 1
            if p.colonized then colonized = colonized + 1 end
        end
    end

    -- 科技
    local techResearched = 0
    local techTotal      = 0
    for _ in pairs(TECHS) do techTotal = techTotal + 1 end
    for _ in pairs(ctx.rs.unlocked) do techResearched = techResearched + 1 end

    -- 战斗
    local waves    = ctx.piratesKilled or 0
    local kills    = (ctx.battleStatsCache and ctx.battleStatsCache.totalEnemiesKilled) or 0
    local shipsLost= (ctx.battleStatsCache and ctx.battleStatsCache.shipsLost) or 0
    local maxCombo = (ctx.battleStatsCache and ctx.battleStatsCache.maxCombo) or 0

    -- 资源（显示主要3种精炼资源）
    local metal   = math.floor(ctx.rm.resources.metal   or 0)
    local esource = math.floor(ctx.rm.resources.esource or 0)
    local nuclear = math.floor(ctx.rm.resources.nuclear or 0)
    local rMetal  = math.floor(ctx.rm.rates.metal   or 0)
    local rEsrc   = math.floor(ctx.rm.rates.esource or 0)
    local rNucl   = math.floor(ctx.rm.rates.nuclear or 0)

    -- 成就
    local achUnlocked = #(Achievement.GetUnlocked())
    local achTotal    = Achievement.GetTotal()

    -- 时间
    local played  = math.floor(ctx.TL.playTime or 0)
    local remain  = math.floor(ctx.getRemainingTime())
    local function fmtTime(s)
        local h = math.floor(s/3600)
        local m = math.floor((s%3600)/60)
        local sc= s%60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, sc)
        else           return string.format("%d:%02d", m, sc) end
    end

    -- ④ 6 个数据卡片（2列 × 3行）
    local CARDS = {
        { icon="🌍", title="殖民版图",
          lines = {
            string.format("已殖民: %d / %d", colonized, totalPlanets),
          },
          progress = totalPlanets > 0 and (colonized / totalPlanets) or 0,
          pcolor   = {80, 200, 120},
        },
        { icon="⚔️", title="战斗战绩",
          lines = {
            string.format("击败海盗: %d 波", waves),
            string.format("歼灭: %d  损失: %d 艘", kills, shipsLost),
            maxCombo > 0 and string.format("最高连击: x%d", maxCombo) or "最高连击: 尚无",
          },
        },
        { icon="🔬", title="科技进度",
          lines = {
            string.format("已研究: %d / %d", techResearched, techTotal),
          },
          progress = techTotal > 0 and (techResearched / techTotal) or 0,
          pcolor   = {100, 160, 255},
        },
        { icon="💰", title="经济概览",
          lines = {
            string.format("金属: %d  (+%d/s)", metal,   rMetal),
            string.format("能源: %d  (+%d/s)", esource, rEsrc),
            string.format("核料: %d  (+%d/s)", nuclear, rNucl),
          },
        },
        { icon="🏆", title="成就进度",
          lines = {
            string.format("已解锁: %d / %d", achUnlocked, achTotal),
          },
          progress = achTotal > 0 and (achUnlocked / achTotal) or 0,
          pcolor   = {255, 200, 60},
        },
        { icon="⏱️", title="游戏时间",
          lines = {
            "已游玩: " .. fmtTime(played),
            "剩余时间: " .. fmtTime(remain),
          },
          progress = (ctx.TL.BASE_LIMIT + ctx.TL.extraTime) > 0
              and (1 - remain / math.max(1, ctx.TL.BASE_LIMIT + ctx.TL.extraTime)) or 0,
          pcolor   = remain < 600 and {255, 100, 100} or {160, 180, 255},
        },
    }

    local COLS   = 2
    local ROWS   = 3
    local CW     = (PW - 32 - (COLS-1)*10) / COLS   -- 卡片宽度
    local CH     = (PH - 56 - (ROWS-1)*8)  / ROWS   -- 卡片高度
    for ci, card in ipairs(CARDS) do
        local col = (ci-1) % COLS
        local row = math.floor((ci-1) / COLS)
        local cx2 = px + 16 + col * (CW + 10)
        local cy2 = py + 46 + row * (CH + 8)

        -- 卡片背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx2, cy2, CW, CH, 7)
        nvgFillColor(vg, nvgRGBA(25, 35, 70, 200))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(60, 90, 160, 120))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)

        -- 图标+标题
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(140, 170, 255, 220))
        nvgText(vg, cx2 + 8, cy2 + 7, card.icon .. " " .. card.title)

        -- 数据行
        nvgFontSize(vg, 12)
        nvgFillColor(vg, nvgRGBA(210, 225, 255, 240))
        local lineY = cy2 + 24
        for _, ln in ipairs(card.lines) do
            nvgText(vg, cx2 + 8, lineY, ln)
            lineY = lineY + 16
        end

        -- 进度条（可选）
        if card.progress then
            local barY  = cy2 + CH - 14
            local barX  = cx2 + 8
            local barW  = CW - 16
            local ratio = math.max(0, math.min(1, card.progress))
            local pc    = card.pcolor or {100, 160, 255}
            -- 背景轨道
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX, barY, barW, 6, 3)
            nvgFillColor(vg, nvgRGBA(40, 50, 90, 200))
            nvgFill(vg)
            -- 填充
            if ratio > 0 then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, barX, barY, barW * ratio, 6, 3)
                nvgFillColor(vg, nvgRGBA(pc[1], pc[2], pc[3], 220))
                nvgFill(vg)
            end
        end
    end

    -- ⑤ 底部提示
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(120, 140, 200, 150))
    nvgText(vg, px + PW * 0.5, py + PH - 5, "按 Tab 或点击遮罩关闭")
end

return ClientStats
