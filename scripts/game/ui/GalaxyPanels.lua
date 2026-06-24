-- ============================================================================
-- GalaxyPanels.lua
-- 银河星图面板集合：情报/生涯统计/任务/信号/市场/外交/黑市/互换/造船厂
-- 从 GameUI.lua 提取的独立模块 (P3-1b-2)
-- ============================================================================
local UICommon     = require("game.ui.UICommon")
local QuestBoard   = require("game.QuestBoard")
local CareerPanel  = require("game.ui.CareerPanel")
local Commander    = require("game.CommanderSystem")

local M = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 私有状态
-- ═══════════════════════════════════════════════════════════════════════════════
local statsVisible_        = false
local questVisible_        = false
local signalOpen_          = false
local diploRelVisible_     = false
local marketCollapsed_     = false
local blackMarketCollapsed_= true
local exchangeCollapsed_   = true
local shipyardCollapsed_   = false

local signalCooldown_ = 0
local SIGNAL_CD       = 5

local QUICK_SIGNALS = {
    { icon = "🚨", label = "需要支援！",   color = {220, 60,  60},  type = "error"   },
    { icon = "⚔️", label = "发起进攻！",   color = {255, 140, 30},  type = "warn"    },
    { icon = "🛡️", label = "全力防守！",   color = {60,  140, 255}, type = "info"    },
    { icon = "💰", label = "资源短缺",     color = {255, 210, 50},  type = "warn"    },
    { icon = "🔬", label = "科技突破！",   color = {180, 100, 255}, type = "success" },
    { icon = "🚀", label = "舰队集结！",   color = {80,  220, 200}, type = "info"    },
    { icon = "👀", label = "海盗来袭！",   color = {255, 80,  80},  type = "error"   },
    { icon = "✅", label = "一切就绪！",   color = {60,  210, 100}, type = "success" },
}

local careerStats_UI_ = {
    totalGames=0, totalWins=0, bestWave=0,
    totalKills=0, totalColonies=0, bestMvpShip="", playtime=0,
}

-- 每帧注入的外部数据
local selectedPlanet_ = nil
local gameTime_       = 0
local bm_             = nil  -- BlackMarketSystem

-- 回调（由 Init 注入）
local onMarketCb_             = nil
local onBlackMarketCb_        = nil
local onExchangeCb_           = nil
local onShipQueueCb_          = nil
local onShipCancelCb_         = nil
local onShipPromoteCb_        = nil
local getDiploRelationsCb_    = nil
local onActivateIntelCb_      = nil
local onActivateAllianceCb_   = nil
local onActivateBlockadeCb_   = nil
local onActivateMediationCb_  = nil
local onSendSignalCb_         = nil
local notifyFn_               = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- 公共 API
-- ═══════════════════════════════════════════════════════════════════════════════

---@param cfg table
function M.Init(cfg)
    onMarketCb_            = cfg.onMarketCb
    onBlackMarketCb_       = cfg.onBlackMarketCb
    onExchangeCb_          = cfg.onExchangeCb
    onShipQueueCb_         = cfg.onShipQueueCb
    onShipCancelCb_        = cfg.onShipCancelCb
    onShipPromoteCb_       = cfg.onShipPromoteCb
    getDiploRelationsCb_   = cfg.getDiploRelationsCb
    onActivateIntelCb_     = cfg.onActivateIntelCb
    onActivateAllianceCb_  = cfg.onActivateAllianceCb
    onActivateBlockadeCb_  = cfg.onActivateBlockadeCb
    onActivateMediationCb_ = cfg.onActivateMediationCb
    onSendSignalCb_        = cfg.onSendSignalCb
    notifyFn_              = cfg.notifyFn
end

function M.Update(dt)
    if signalCooldown_ > 0 then
        signalCooldown_ = signalCooldown_ - dt
        if signalCooldown_ < 0 then signalCooldown_ = 0 end
    end
end

-- 每帧设值
function M.SetSelectedPlanet(p) selectedPlanet_ = p end
function M.SetGameTime(t)       gameTime_ = t end
function M.SetCareerStats(cs)   careerStats_UI_ = cs end
function M.SetBlackMarket(bm)   bm_ = bm end

-- 开关
function M.ToggleStats()    statsVisible_    = not statsVisible_ end
function M.ToggleQuest()    questVisible_    = not questVisible_ end
function M.ToggleSignal()
    if signalCooldown_ <= 0 then
        signalOpen_ = not signalOpen_
    end
end
function M.ToggleDiploRel() diploRelVisible_ = not diploRelVisible_ end

function M.IsSignalOpen()   return signalOpen_ end
function M.IsStatsVisible() return statsVisible_ end
function M.IsQuestVisible() return questVisible_ end
function M.IsDiploVisible() return diploRelVisible_ end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. 海盗情报面板（右侧浮窗）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderIntel()
    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local addHit  = UICommon.addHit

    if not UICommon.pirateAI then return end
    local intel = UICommon.pirateAI:GetActiveIntel()
    if #intel == 0 then return end

    local PW      = 190
    local LINE_H  = 18
    local PAD     = 8
    local ENTRY_H = LINE_H * 4 + PAD
    local HEADER  = 22
    local ph      = HEADER + #intel * (ENTRY_H + 4) + PAD
    local px      = screenW - PW - 8
    local py      = 50

    local function ic(r, g, b, a) return nvgRGBA(r, g, b, a or 255) end

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, ph, 6)
    nvgFillColor(vg, ic(10, 30, 40, 210))
    nvgFill(vg)
    nvgStrokeColor(vg, ic(60, 220, 200, 200))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, ic(60, 240, 220, 255))
    nvgText(vg, px + PW / 2, py + HEADER / 2, "[ 海盗情报 ]")

    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 6, py + HEADER)
    nvgLineTo(vg, px + PW - 6, py + HEADER)
    nvgStrokeColor(vg, ic(60, 200, 180, 120))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    local ey = py + HEADER + 2

    -- 玩家基地位置
    local baseX, baseY = 0, 0
    if UICommon.bs then
        baseX = UICommon.bs.x or 0
        baseY = UICommon.bs.y or 0
    end

    for i, entry in ipairs(intel) do
        local ex = px + PAD
        local ew = PW - PAD * 2

        -- 条目背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, ex - 2, ey, ew + 4, ENTRY_H, 4)
        nvgFillColor(vg, ic(20, 50, 60, 180))
        nvgFill(vg)
        nvgStrokeColor(vg, ic(60, 180, 160, 80))
        nvgStrokeWidth(vg, 0.7)
        nvgStroke(vg)

        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)

        -- 行1: 方位
        local dx = entry.x - baseX
        local dy = entry.y - baseY
        local angle = math.deg(math.atan(dy, dx))
        local dirs = { "东", "东北", "北", "西北", "西", "西南", "南", "东南" }
        local dirIdx = math.floor((angle + 202.5) / 45) % 8 + 1
        local dirStr = dirs[dirIdx]

        nvgFontSize(vg, 10)
        nvgFillColor(vg, ic(60, 240, 220, 240))
        nvgText(vg, ex, ey + 2, string.format("Lv%d 海盗基地  [%s]", entry.level, dirStr))

        -- 行2: 进攻预估
        local urgency = entry.estimatedAttack <= 30
        local tr = urgency and 255 or 220
        local tg = urgency and 100 or 190
        nvgFontSize(vg, 10)
        nvgFillColor(vg, ic(tr, tg, 60, 240))
        nvgText(vg, ex, ey + LINE_H + 2,
            string.format("进攻: 约 %ds", entry.estimatedAttack))

        -- 行3: 舰队编成
        nvgFontSize(vg, 9)
        nvgFillColor(vg, ic(180, 210, 230, 220))
        nvgText(vg, ex, ey + LINE_H * 2 + 2, "兵力: " .. entry.composition)

        -- 行4: 情报计时
        local itLeft = math.ceil(entry.intelTimer)
        local itR = itLeft <= 20 and 255 or 140
        local itG = itLeft <= 20 and 160 or 200
        nvgFontSize(vg, 9)
        nvgFillColor(vg, ic(itR, itG, 140, 200))
        nvgText(vg, ex, ey + LINE_H * 3 + 2, string.format("情报剩余: %ds", itLeft))

        ey = ey + ENTRY_H + 4
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. 生涯战绩面板（右侧浮窗 3×2 卡片）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderCareerStats()
    if not statsVisible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local addHit  = UICommon.addHit

    local cs   = careerStats_UI_
    local PW   = math.min(260, screenW - 16)
    local PAD  = 10
    local PH   = 258
    local px   = math.max(4, screenW - PW - 6)
    local py   = 40

    -- 背景板
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgFillColor(vg, nvgRGBA(6, 10, 26, 235)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgStrokeColor(vg, nvgRGBA(80, 140, 255, 180)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 标题栏
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 200, 255, 255))
    nvgText(vg, px + PAD, py + 14, "📊 生涯战绩")
    -- 关闭按钮
    nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 200))
    nvgText(vg, px + PW - PAD, py + 14, "✕")
    addHit(px + PW - 26, py, 26, 28, function() statsVisible_ = false end)

    -- 分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, px + PAD, py + 28); nvgLineTo(vg, px + PW - PAD, py + 28)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 6 格卡片数据（3列×2行）
    local cards = {
        { icon="🎮", label="总局数",   value=tostring(cs.totalGames) },
        { icon="🏆", label="胜利",     value=string.format("%d局 (%.0f%%)",
            cs.totalWins,
            cs.totalGames > 0 and (cs.totalWins / cs.totalGames * 100) or 0) },
        { icon="⚡", label="最高波次", value=tostring(cs.bestWave) .. "波" },
        { icon="💥", label="总击杀",   value=tostring(cs.totalKills) },
        { icon="🌍", label="总殖民",   value=tostring(cs.totalColonies) .. "颗" },
        { icon="⏱",  label="游戏时长", value=(function()
            local t = cs.playtime
            if t < 60 then return t .. "秒"
            elseif t < 3600 then return string.format("%d分%d秒", math.floor(t/60), t%60)
            else return string.format("%dh%dm", math.floor(t/3600), math.floor((t%3600)/60)) end
        end)() },
    }
    local COLS      = 3
    local CARD_W    = math.floor((PW - PAD*2 - (COLS-1)*6) / COLS)
    local CARD_H    = 58
    local ROWS      = 2
    local gridTop   = py + 34
    for i, card in ipairs(cards) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local cx  = px + PAD + col * (CARD_W + 6)
        local cy  = gridTop + row * (CARD_H + 6)
        nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, CARD_W, CARD_H, 5)
        nvgFillColor(vg, nvgRGBA(15, 25, 55, 200)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, cx, cy, CARD_W, CARD_H, 5)
        nvgStrokeColor(vg, nvgRGBA(50, 90, 160, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
        -- 图标
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
        nvgText(vg, cx + CARD_W/2, cy + 5, card.icon)
        -- 数值
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(180, 220, 255, 255))
        nvgText(vg, cx + CARD_W/2, cy + 24, card.value)
        -- 标签
        nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(100, 140, 200, 160))
        nvgText(vg, cx + CARD_W/2, cy + CARD_H - 13, card.label)
    end

    -- MVP 舰种
    local mvpY = gridTop + ROWS * (CARD_H + 6) + 2
    nvgBeginPath(vg); nvgRoundedRect(vg, px + PAD, mvpY, PW - PAD*2, 22, 4)
    nvgFillColor(vg, nvgRGBA(40, 30, 10, 180)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px + PAD, mvpY, PW - PAD*2, 22, 4)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 40, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 160, 60, 220))
    local mvpLabel = (cs.bestMvpShip and cs.bestMvpShip ~= "") and ("🥇 历史MVP：" .. cs.bestMvpShip) or "🥇 历史MVP：尚无记录"
    nvgText(vg, px + PAD + 6, mvpY + 11, mvpLabel)

    -- "查看完整战绩"按钮
    local btnY  = mvpY + 28
    local btnX  = px + PAD
    local btnW  = PW - PAD * 2
    local btnH  = 22
    local bhov  = cursorX >= btnX and cursorX <= btnX+btnW
               and cursorY >= btnY and cursorY <= btnY+btnH
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
    nvgFillColor(vg, bhov and nvgRGBA(40, 80, 160, 230) or nvgRGBA(20, 40, 90, 180))
    nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
    nvgStrokeColor(vg, bhov and nvgRGBA(100, 180, 255, 220) or nvgRGBA(60, 100, 200, 120))
    nvgStrokeWidth(vg, 1); nvgStroke(vg)
    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 200, 255, 230))
    nvgText(vg, btnX + btnW/2, btnY + btnH/2, "🏛 查看完整战绩 →")
    addHit(btnX, btnY, btnW, btnH, function()
        CareerPanel.Show()
        statsVisible_ = false
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. 任务板面板（右侧浮层）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderQuest()
    if not questVisible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local addHit  = UICommon.addHit

    local quests = QuestBoard.GetQuests()
    local spawnT = QuestBoard.GetSpawnTimer()
    local PW     = math.min(280, screenW - 16)
    local PAD    = 10
    local ENTRY_H = 58
    local n      = #quests
    local headerH = 42
    local footerH = 22
    local PH     = headerH + n * ENTRY_H + footerH + 6
    if n == 0 then PH = headerH + 40 + footerH end
    local px     = math.max(4, screenW - PW - 6)
    local py     = 40

    -- 背景板
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgFillColor(vg, nvgRGBA(6, 14, 28, 238)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, PW, PH, 8)
    nvgStrokeColor(vg, nvgRGBA(60, 200, 140, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)

    -- 标题栏
    nvgFontSize(vg, 13); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 220, 160, 255))
    nvgText(vg, px + PAD, py + 14, "📌 任务板")

    -- 已完成计数
    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 180, 200, 180))
    nvgText(vg, px + PW - 30, py + 14,
        string.format("已完成 %d", QuestBoard.GetCompletedCount()))

    -- 关闭按钮
    nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 180, 220, 200))
    nvgText(vg, px + PW - PAD, py + 14, "✕")
    addHit(px + PW - 28, py + 2, 26, 26, function() questVisible_ = false end)

    -- 分隔线
    nvgBeginPath(vg); nvgMoveTo(vg, px + PAD, py + 28)
    nvgLineTo(vg, px + PW - PAD, py + 28)
    nvgStrokeColor(vg, nvgRGBA(60, 160, 120, 120)); nvgStrokeWidth(vg, 1); nvgStroke(vg)

    -- 任务列表
    if n == 0 then
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 160, 180, 180))
        nvgText(vg, px + PW/2, py + headerH + 16, "暂无活跃任务，等待生成…")
    else
        local TYPE_ICONS = { combat="⚔", economy="💰", diplomacy="🤝", exploration="🔭" }
        local TYPE_COLORS = {
            combat      = {255, 100, 100},
            economy     = {255, 210, 80},
            diplomacy   = {140, 180, 255},
            exploration = {100, 230, 180},
        }
        for i, q in ipairs(quests) do
            local ey = py + headerH + (i - 1) * ENTRY_H
            local tc = TYPE_COLORS[q.type] or {180,180,180}

            -- 条目背景
            nvgBeginPath(vg); nvgRoundedRect(vg, px + 6, ey + 2, PW - 12, ENTRY_H - 4, 5)
            if q.elite then
                nvgFillColor(vg, nvgRGBA(30, 25, 10, 200))
            else
                nvgFillColor(vg, nvgRGBA(12, 22, 45, 180))
            end
            nvgFill(vg)
            if q.elite then
                nvgBeginPath(vg); nvgRoundedRect(vg, px + 6, ey + 2, PW - 12, ENTRY_H - 4, 5)
                nvgStrokeColor(vg, nvgRGBA(255, 200, 60, 160)); nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            end

            -- 类型图标
            local icon = TYPE_ICONS[q.type] or "?"
            if q.elite then icon = "⭐" .. icon end
            nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 240))
            nvgText(vg, px + 14, ey + 6, icon)

            -- 描述
            nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(220, 230, 240, 240))
            nvgText(vg, px + 38, ey + 7, q.desc)

            -- 进度条
            local pct = q.target > 0 and math.min(1.0, q.progress / q.target) or 0
            local barX, barY, barW, barH = px + 38, ey + 22, PW - 80, 6
            nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 3)
            nvgFillColor(vg, nvgRGBA(30, 50, 70, 200)); nvgFill(vg)
            if pct > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW * pct, barH, 3)
                nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 200)); nvgFill(vg)
            end
            -- 进度文字
            nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(180, 200, 220, 200))
            nvgText(vg, px + PW - 14, barY + barH/2,
                string.format("%d/%d", math.min(q.progress, q.target), q.target))

            -- 倒计时
            local tMin = math.floor(q.timer / 60)
            local tSec = math.floor(q.timer % 60)
            local timerStr = string.format("⏱%d:%02d", tMin, tSec)
            local isUrgent = q.timer < 60
            nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, isUrgent and nvgRGBA(255, 80, 80, 220) or nvgRGBA(140, 170, 200, 180))
            nvgText(vg, px + 38, ey + 34, timerStr)

            -- 奖励预览
            local rwStr = ""
            if q.reward.metal > 0 then rwStr = rwStr .. string.format("⛏%d ", q.reward.metal) end
            if q.reward.energy > 0 then rwStr = rwStr .. string.format("⚡%d ", q.reward.energy) end
            if q.reward.salvage > 0 then rwStr = rwStr .. string.format("🔧%d", q.reward.salvage) end
            nvgFontSize(vg, 8); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(200, 220, 160, 180))
            nvgText(vg, px + PW - 14, ey + 36, rwStr)
        end
    end

    -- 底部刷新倒计时
    local footY = py + PH - footerH
    nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 160, 140, 160))
    local spawnMin = math.floor(spawnT / 60)
    local spawnSec = math.floor(spawnT % 60)
    nvgText(vg, px + PW/2, footY + footerH/2,
        n >= 3 and "任务已满（3/3）"
              or string.format("下一任务: %d:%02d", spawnMin, spawnSec))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. 快捷信号面板（TopBar 下方居中，4×2 格）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderSignal()
    if not signalOpen_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local addHit  = UICommon.addHit

    local COLS = screenW < 500 and 3 or 4
    local ROWS = screenW < 500 and 3 or 2
    local BTN_W = math.min(120, math.floor((screenW - 40) / COLS - 6))
    local BTN_H = 44
    local GAP  = 6
    local PAD  = 10
    local pw   = math.min(COLS * BTN_W + (COLS - 1) * GAP + PAD * 2, screenW - 16)
    local ph   = ROWS * BTN_H + (ROWS - 1) * GAP + PAD * 2
    local px   = math.max(8, screenW / 2 - pw / 2)
    local py   = 48

    -- 面板背景
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(8, 16, 36, 230)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 80, 180)); nvgStrokeWidth(vg, 1.5); nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 10)
    nvgFillColor(vg, nvgRGBA(140, 200, 140, 180))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local cdStr = signalCooldown_ > 0
        and string.format("  [冷却 %.0fs]", signalCooldown_) or ""
    nvgText(vg, px + PAD, py + 2, "📡 快捷信号" .. cdStr)

    -- 8 个信号按钮
    local onCD = signalCooldown_ > 0
    for i, sig in ipairs(QUICK_SIGNALS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local bx  = px + PAD + col * (BTN_W + GAP)
        local by  = py + PAD + 10 + row * (BTN_H + GAP)
        local cr, cg, cb = sig.color[1], sig.color[2], sig.color[3]
        local hover = cursorX >= bx and cursorX <= bx + BTN_W and cursorY >= by and cursorY <= by + BTN_H

        -- 按钮背景
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, BTN_W, BTN_H, 6)
        if onCD then
            nvgFillColor(vg, nvgRGBA(20, 20, 30, 140))
        elseif hover then
            nvgFillColor(vg, nvgRGBA(cr, cg, cb, 50))
        else
            nvgFillColor(vg, nvgRGBA(12, 20, 40, 200))
        end
        nvgFill(vg)
        -- 边框
        nvgBeginPath(vg); nvgRoundedRect(vg, bx, by, BTN_W, BTN_H, 6)
        nvgStrokeColor(vg, onCD and nvgRGBA(60, 60, 60, 100)
            or nvgRGBA(cr, cg, cb, hover and 220 or 100))
        nvgStrokeWidth(vg, hover and 1.5 or 1); nvgStroke(vg)
        -- 图标
        nvgFontSize(vg, 16); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(80, 80, 80, 150) or nvgRGBA(255, 255, 255, 230))
        nvgText(vg, bx + 8, by + BTN_H / 2, sig.icon)
        -- 文字
        nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, onCD and nvgRGBA(80, 80, 80, 150)
            or nvgRGBA(cr, cg, cb, hover and 255 or 200))
        nvgText(vg, bx + 30, by + BTN_H / 2, sig.label)
    end

    -- 点击热区
    for i, sig in ipairs(QUICK_SIGNALS) do
        local col = (i - 1) % COLS
        local row = math.floor((i - 1) / COLS)
        local bx  = px + PAD + col * (BTN_W + GAP)
        local by2 = py + PAD + 10 + row * (BTN_H + GAP)
        if not onCD then
            addHit(bx, by2, BTN_W, BTN_H, function()
                signalOpen_    = false
                signalCooldown_ = SIGNAL_CD
                local msg = sig.icon .. " " .. sig.label
                if notifyFn_ then notifyFn_("📡 [信号] " .. msg, sig.type) end
                if onSendSignalCb_ then onSendSignalCb_(sig) end
            end)
        end
    end
    -- 点击面板外关闭
    addHit(0, 0, px, screenH, function() signalOpen_ = false end)
    addHit(px + pw, 0, screenW - px - pw, screenH, function() signalOpen_ = false end)
    addHit(px, py + ph, pw, screenH - py - ph, function() signalOpen_ = false end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. 市场面板（左下）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderMarket()
    local vg         = UICommon.vg
    local screenH    = UICommon.screenH
    local ms         = UICommon.ms
    local addHit     = UICommon.addHit
    local panel      = UICommon.panel
    local text       = UICommon.text
    local clr        = UICommon.clr
    local drawButton = UICommon.drawButton
    local PANEL_TOP  = UICommon.PANEL_TOP

    if not ms then return end
    if not selectedPlanet_ or not selectedPlanet_.colonized then return end
    local hasHub = false
    for _, b in ipairs(selectedPlanet_.buildings) do
        if b.key == "TRADE_HUB" then hasHub = true; break end
    end
    if not hasHub then return end

    local pw = 230
    local lineH = 20
    local rows = 2 + 3 * 2
    if marketCollapsed_ then rows = 2 end
    local ph = rows * lineH + 12

    local px = 12
    local techBottom = PANEL_TOP + (UICommon.techPanelH or 0) + (UICommon.techPanelH > 0 and 8 or 0)
    local py = math.max(techBottom, screenH - ph - 8)
    if py + ph > screenH - 4 then return end

    panel(px, py, pw, ph, 7, {8,22,12,235}, {40,180,80,200})

    local titleY = py + 14
    text(px+10, titleY, "[ 银河交易所 ]", 13, 60,200,100,255)
    local btnX = px+pw-22
    text(btnX, titleY, marketCollapsed_ and "▼" or "▲", 11, 80,200,120,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    addHit(px, py, pw, 22, function() marketCollapsed_ = not marketCollapsed_ end)

    if marketCollapsed_ then return end

    local sy = titleY + 22
    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(40,180,80,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    -- sparkline 辅助函数
    local function drawSparkline(cx, cy, w, h, history, upR,upG,upB, downR,downG,downB)
        if not history or #history < 2 then return end
        local minV, maxV = history[1], history[1]
        for _, v in ipairs(history) do
            if v < minV then minV = v end
            if v > maxV then maxV = v end
        end
        local range = maxV - minV
        if range < 0.01 then range = 0.01 end
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, w, h, 2)
        nvgFillColor(vg, clr(15,15,15,120))
        nvgFill(vg)
        local nn = #history
        local lastDir = history[nn] >= history[nn-1]
        local lr = lastDir and upR  or downR
        local lg = lastDir and upG  or downG
        local lb = lastDir and upB  or downB
        nvgBeginPath(vg)
        for i, v in ipairs(history) do
            local t = (i - 1) / (nn - 1)
            local nx2 = cx + t * w
            local ny2 = cy + h - ((v - minV) / range) * h
            ny2 = math.max(cy + 1, math.min(cy + h - 1, ny2))
            if i == 1 then nvgMoveTo(vg, nx2, ny2)
            else            nvgLineTo(vg, nx2, ny2) end
        end
        nvgStrokeColor(vg, clr(lr, lg, lb, 200))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        local lx = cx + w
        local ly = cy + h - ((history[nn] - minV) / range) * h
        ly = math.max(cy + 1, math.min(cy + h - 1, ly))
        nvgBeginPath(vg)
        nvgCircle(vg, lx, ly, 2)
        nvgFillColor(vg, clr(lr, lg, lb, 255))
        nvgFill(vg)
    end

    for _, res in ipairs({"metal","esource","nuclear"}) do
        local r     = ms.rates[res]
        local c     = RES_COLORS[res]
        local trend = ms:getTrend(res)
        local tr,tg,tb = 150,150,150
        if trend == "↑" then tr,tg,tb = 50,230,100
        elseif trend == "↓" then tr,tg,tb = 255,80,80 end

        local flash = ms.priceFlash and (ms.priceFlash[res] or 0) or 0
        local flashAlpha = flash > 0 and math.floor(math.abs(math.sin(flash * 4)) * 180 + 60) or 0

        text(px+10, sy+9, RES_LABELS[res], 10, c[1]+40,c[2]+40,c[3]+40,230)
        text(px+60, sy+9, trend, 12, tr,tg,tb,255)
        if flashAlpha > 0 then
            text(px+74, sy+9, "!", 11, 255,220,60,flashAlpha)
        end
        text(px+82, sy+9,
            "卖" .. string.format("%.1f", r.sell) .. " 买" .. string.format("%.1f", r.buy),
            10, c[1]+20,c[2]+20,c[3]+20,210)
        local sparkX = px + pw - 52
        local sparkY = sy + 1
        drawSparkline(sparkX, sparkY, 44, 13, ms.history[res],
            50,230,100, 255,100,80)
        sy = sy + 18

        local capturedRes = res
        local y1 = sy
        drawButton(px+10, y1, 100, 16, "卖出×100", 200,120,50, function()
            if onMarketCb_ then onMarketCb_("sell", capturedRes, 100) end
        end)
        drawButton(px+120, y1, 100, 16, "买入×100", 50,150,200, function()
            if onMarketCb_ then onMarketCb_("buy", capturedRes, 100) end
        end)
        sy = y1 + 20
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. 外交关系网面板（右侧浮窗）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderDiploRel()
    if not diploRelVisible_ then return end
    if not getDiploRelationsCb_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local addHit  = UICommon.addHit

    local relations, agreements = getDiploRelationsCb_()
    if not relations then return end
    agreements = agreements or {}

    local pw, ph = math.min(320, screenW - 16), 360
    local px = math.max(4, screenW - pw - 10)
    local py = 42

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(10, 15, 35, 230))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(100, 80, 200, 180))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(200, 160, 255, 255))
    nvgText(vg, px + pw/2, py + 16, "🤝 派系关系网")

    -- 三角布局
    local factionDefs = {
        { key = "trade_union",  name = "商业联盟",   icon = "💰", color = {255,200,80} },
        { key = "star_guild",   name = "星际工会",   icon = "⚙️",  color = {100,200,255} },
        { key = "relic_keeper", name = "遗迹守护者", icon = "🏛️", color = {180,120,255} },
    }
    local triPos = {
        { x = px + pw/2,     y = py + 75 },
        { x = px + 60,       y = py + 200 },
        { x = px + pw - 60,  y = py + 200 },
    }

    -- 关系连线
    local relMap = {}
    for _, r in ipairs(relations) do
        relMap[r.fk1 .. ":" .. r.fk2] = r.rel
        relMap[r.fk2 .. ":" .. r.fk1] = r.rel
    end
    local function getRelBetween(i, j)
        local k = factionDefs[i].key .. ":" .. factionDefs[j].key
        return relMap[k] or "neutral"
    end
    local relColors = {
        compete   = { 255, 80, 80, 200 },
        neutral   = { 150, 150, 150, 140 },
        cooperate = { 80, 220, 120, 200 },
    }
    local relLabels = {
        compete   = "⚔ 竞争",
        neutral   = "— 中立",
        cooperate = "🤝 合作",
    }
    local pairsList = { {1,2}, {1,3}, {2,3} }
    for _, p in ipairs(pairsList) do
        local i, j = p[1], p[2]
        local rel = getRelBetween(i, j)
        local rc = relColors[rel] or relColors.neutral
        nvgBeginPath(vg)
        nvgMoveTo(vg, triPos[i].x, triPos[i].y)
        nvgLineTo(vg, triPos[j].x, triPos[j].y)
        nvgStrokeColor(vg, nvgRGBA(rc[1], rc[2], rc[3], rc[4]))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
        local mx = (triPos[i].x + triPos[j].x) / 2
        local my = (triPos[i].y + triPos[j].y) / 2
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 255))
        nvgText(vg, mx, my, relLabels[rel] or "—")
    end

    -- 派系节点
    for i, fd in ipairs(factionDefs) do
        local cx, cy = triPos[i].x, triPos[i].y
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 22)
        nvgFillColor(vg, nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 40))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 22)
        nvgStrokeColor(vg, nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 180))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)
        nvgFontSize(vg, 16)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, cx, cy, fd.icon)
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(fd.color[1], fd.color[2], fd.color[3], 220))
        nvgText(vg, cx, cy + 30, fd.name)
    end

    -- 协议状态
    local ay = py + 240
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(180, 200, 255, 200))
    nvgText(vg, px + 12, ay, "当前协议：")
    ay = ay + 18

    local hasAny = false
    if agreements.intelShares then
        for fk, _ in pairs(agreements.intelShares) do
            nvgFillColor(vg, nvgRGBA(100, 220, 180, 220))
            nvgText(vg, px + 16, ay, string.format("🔍 情报共享 → %s", fk))
            ay = ay + 14; hasAny = true
        end
    end
    if agreements.alliances then
        for fk, _ in pairs(agreements.alliances) do
            nvgFillColor(vg, nvgRGBA(255, 120, 80, 220))
            nvgText(vg, px + 16, ay, string.format("⚔ 军事同盟 → %s", fk))
            ay = ay + 14; hasAny = true
        end
    end
    if agreements.blockades then
        for _, b in pairs(agreements.blockades) do
            if type(b) == "table" then
                local remain = math.max(0, math.floor((b.endTime or 0) - (os.clock())))
                nvgFillColor(vg, nvgRGBA(255, 200, 60, 220))
                nvgText(vg, px + 16, ay, string.format("🚫 封锁 %s→%s (%ds)", b.from or "?", b.target or "?", remain))
                ay = ay + 14; hasAny = true
            end
        end
    end
    if not hasAny then
        nvgFillColor(vg, nvgRGBA(120, 130, 150, 180))
        nvgText(vg, px + 16, ay, "暂无活跃协议")
    end

    -- 操作按钮
    ay = py + ph - 50
    local btnW = 70
    local btnH = 22
    local btnGap = 6
    local startX = px + 10
    local btns = {
        { label = "情报", cb = onActivateIntelCb_,     color = {60, 180, 140} },
        { label = "同盟", cb = onActivateAllianceCb_,  color = {220, 100, 80} },
        { label = "封锁", cb = onActivateBlockadeCb_,  color = {200, 180, 60} },
        { label = "调停", cb = onActivateMediationCb_, color = {140, 100, 220} },
    }
    for i, btn in ipairs(btns) do
        local bx = startX + (i-1) * (btnW + btnGap)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, ay, btnW, btnH, 4)
        nvgFillColor(vg, nvgRGBA(btn.color[1], btn.color[2], btn.color[3], 60))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, ay, btnW, btnH, 4)
        nvgStrokeColor(vg, nvgRGBA(btn.color[1], btn.color[2], btn.color[3], 180))
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(btn.color[1], btn.color[2], btn.color[3], 240))
        nvgText(vg, bx + btnW/2, ay + btnH/2, btn.label)

        if btn.cb then
            addHit(bx, ay, btnW, btnH, function()
                if i <= 2 then
                    local bestFk = factionDefs[1].key
                    btn.cb(bestFk)
                elseif i == 3 then
                    local from = factionDefs[1].key
                    local target = factionDefs[2].key
                    btn.cb(from, target)
                elseif i == 4 then
                    for _, r in ipairs(relations) do
                        if r.rel == "compete" then
                            btn.cb(r.fk1, r.fk2)
                            return
                        end
                    end
                    btn.cb(factionDefs[1].key, factionDefs[2].key)
                end
            end)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. 黑市走私面板（右下）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderBlackMarket()
    local vg         = UICommon.vg
    local screenW    = UICommon.screenW
    local screenH    = UICommon.screenH
    local addHit     = UICommon.addHit
    local panel      = UICommon.panel
    local text       = UICommon.text
    local clr        = UICommon.clr
    local drawButton = UICommon.drawButton

    if not bm_ then return end
    if not selectedPlanet_ or not selectedPlanet_.colonized then return end
    local hasHub = false
    for _, b in ipairs(selectedPlanet_.buildings) do
        if b.key == "TRADE_HUB" then hasHub = true; break end
    end
    if not hasHub then return end

    local pw = 240
    local lineH = 18
    local rows = 2
    if not blackMarketCollapsed_ then
        local shopItems = bm_:getShopItems()
        local cargo     = bm_:getCargo()
        local routes    = bm_:getRoutes()
        local activeRt  = bm_:getActiveRoute()
        rows = rows + 2 + #shopItems
        rows = rows + 2 + math.max(1, #cargo)
        if activeRt then rows = rows + 3 end
        if #cargo > 0 and not activeRt then
            rows = rows + 2 + #routes
        end
        rows = rows + 2
        if Commander.CanRecruit() then rows = rows + 2 end
    end
    local ph = rows * lineH + 16

    local px = screenW - pw - 12
    local py = screenH - ph - 8
    if py < 60 then py = 60 end

    panel(px, py, pw, ph, 7, {12,8,22,235}, {180,80,40,200})

    local titleY = py + 14
    text(px+10, titleY, "[ 🕵️ 黑市走私 ]", 13, 200,100,60,255)
    local refreshT = bm_:getRefreshTimer()
    text(px+pw-60, titleY, string.format("⏱%ds", math.floor(refreshT)), 10, 150,150,150,180)
    local btnX2 = px+pw-22
    text(btnX2, titleY, blackMarketCollapsed_ and "▼" or "▲", 11, 180,120,80,200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    addHit(px, py, pw, 22, function() blackMarketCollapsed_ = not blackMarketCollapsed_ end)

    if blackMarketCollapsed_ then return end

    local sy = titleY + 20
    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(180,80,40,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 6

    -- 商店
    local shopItems = bm_:getShopItems()
    text(px+10, sy+8, "商店 (" .. #shopItems .. "/" .. 4 .. ")", 10, 200,160,100,220)
    drawButton(px+pw-70, sy, 60, 16, "刷新★50", 180,140,60, function()
        if onBlackMarketCb_ then onBlackMarketCb_("refresh") end
    end)
    sy = sy + lineH

    for idx, slot in ipairs(shopItems) do
        local item = slot.item
        local cost = math.floor(item.buyCost * slot.priceMod)
        local rc = bm_:getRarityColor(item.rarity)
        text(px+10, sy+8, item.icon, 11, 255,255,255,230)
        text(px+26, sy+8, item.name, 10, rc[1],rc[2],rc[3],240)
        text(px+110, sy+8, "★" .. cost, 10, 255,220,100,220)
        drawButton(px+pw-50, sy, 42, 15, "购入", 60,180,100, function()
            if onBlackMarketCb_ then onBlackMarketCb_("buy", idx) end
        end)
        sy = sy + lineH
    end
    if #shopItems == 0 then
        text(px+10, sy+8, "已售罄，等待刷新...", 10, 120,120,120,180)
        sy = sy + lineH
    end

    -- 分隔
    sy = sy + 4
    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(180,80,40,40)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
    sy = sy + 6

    -- 货舱
    local cargo = bm_:getCargo()
    text(px+10, sy+8, "货舱 (" .. #cargo .. "/" .. bm_:getMaxCargo() .. ")", 10, 200,160,100,220)
    sy = sy + lineH

    if #cargo == 0 then
        text(px+10, sy+8, "空空如也", 10, 120,120,120,160)
        sy = sy + lineH
    else
        for idx, c in ipairs(cargo) do
            local item = c.item
            local rc = bm_:getRarityColor(item.rarity)
            text(px+10, sy+8, item.icon, 11, 255,255,255,230)
            text(px+26, sy+8, item.name, 10, rc[1],rc[2],rc[3],230)
            text(px+108, sy+8, "₊" .. c.boughtAt, 9, 150,150,150,180)
            if not bm_:getActiveRoute() then
                drawButton(px+pw-50, sy, 42, 15, "直售", 200,150,50, function()
                    if onBlackMarketCb_ then onBlackMarketCb_("sell", idx) end
                end)
            end
            sy = sy + lineH
        end
    end

    -- 活跃路线
    local activeRt = bm_:getActiveRoute()
    if activeRt then
        sy = sy + 4
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, clr(180,80,40,40)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        sy = sy + 6

        text(px+10, sy+8, "🚀 运送中: " .. activeRt.item.name, 10, 255,200,100,240)
        sy = sy + lineH
        local prog = activeRt.timer / activeRt.duration
        local barX2, barW2 = px+10, pw-70
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX2, sy+4, barW2, 8, 3)
        nvgFillColor(vg, clr(40,40,40,180))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX2, sy+4, barW2 * prog, 8, 3)
        nvgFillColor(vg, clr(200,120,40,220))
        nvgFill(vg)
        text(barX2+barW2+6, sy+8, string.format("%ds", math.floor(activeRt.duration - activeRt.timer)), 9, 180,180,180,200)
        drawButton(px+pw-50, sy, 42, 15, "取消", 200,80,60, function()
            if onBlackMarketCb_ then onBlackMarketCb_("cancelRoute") end
        end)
        sy = sy + lineH + 2
    elseif #cargo > 0 then
        -- 路线选择
        sy = sy + 4
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, clr(180,80,40,40)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        sy = sy + 6

        text(px+10, sy+8, "选择路线 (货物#1发货)", 10, 200,160,100,220)
        sy = sy + lineH

        local routes = bm_:getRoutes()
        for rIdx, route in ipairs(routes) do
            local risk = bm_:previewRisk(1, rIdx)
            local riskPct = math.floor(risk * 100)
            local rr,rg,rb = 100,200,100
            if riskPct > 25 then rr,rg,rb = 255,200,60 end
            if riskPct > 35 then rr,rg,rb = 255,100,60 end
            text(px+10, sy+8, route.icon .. " " .. route.name, 10, 180,180,180,230)
            text(px+110, sy+8, riskPct .. "%⚠", 9, rr,rg,rb,220)
            text(px+145, sy+8, route.duration .. "s", 9, 150,150,150,180)
            drawButton(px+pw-50, sy, 42, 15, "发货", 100,160,200, function()
                if onBlackMarketCb_ then onBlackMarketCb_("startRoute", rIdx, 1) end
            end)
            sy = sy + lineH
        end
    end

    -- 雇佣指挥官
    if Commander.CanRecruit() then
        sy = sy + 4
        nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
        nvgStrokeColor(vg, clr(120,60,200,60)); nvgStrokeWidth(vg, 0.8); nvgStroke(vg)
        sy = sy + 4
        text(px+10, sy+8, "🎖️ 雇佣指挥官 (★2000)", 10, 180,120,255,230)
        drawButton(px+pw-50, sy, 42, 15, "雇佣", 140,80,220, function()
            if onBlackMarketCb_ then onBlackMarketCb_("hireCommander") end
        end)
        sy = sy + lineH
    end

    -- 统计摘要
    sy = sy + 4
    local stats = bm_:getStats()
    text(px+10, sy+8, string.format("利润★%d | 截获%d | 连胜%d",
        stats.totalProfit, stats.intercepted, stats.maxConsecutive), 9, 140,140,140,180)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. 资源互换中心面板（基地面板下方）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderExchange(base, basePanelH)
    local vg         = UICommon.vg
    local screenW    = UICommon.screenW
    local screenH    = UICommon.screenH
    local addHit     = UICommon.addHit
    local panel      = UICommon.panel
    local text       = UICommon.text
    local clr        = UICommon.clr
    local rm         = UICommon.rm
    local PANEL_TOP  = UICommon.PANEL_TOP

    if not base or not base.isBase then return end
    local hasExchange = false
    for _, b in ipairs(base.buildings) do
        if b.key == "EXCHANGE_CENTER" then hasExchange = true; break end
    end
    if not hasExchange then return end

    local pw = 275
    local px = screenW - pw - 12
    local py = PANEL_TOP + (basePanelH or 300) + 8
    local titleH = 26

    -- 折叠态
    if exchangeCollapsed_ then
        if py + titleH > screenH - 4 then return end
        panel(px, py, pw, titleH, 5, {10,22,20,220}, {60,200,120,160})
        text(px + 14, py + titleH/2, "▶", 10, 60,200,120,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
        text(px + pw/2, py + titleH/2, "资源互换中心", 12, 60,220,140,220,
            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        addHit(px, py, pw, titleH, function() exchangeCollapsed_ = false end)
        return
    end

    -- 展开态
    local EXCHANGE_RES = {"metal","esource","nuclear"}
    local btnH2  = 20
    local stockH = 14
    local groupCount = #EXCHANGE_RES
    local btnsPerGroup = #EXCHANGE_RES - 1
    local ph = titleH + 4 + stockH + 4 + groupCount * (12 + btnsPerGroup * (btnH2 + 3) + 6) + 4
    if py + ph > screenH - 4 then return end

    panel(px, py, pw, ph, 7, {10,22,20,240}, {60,200,120,200})

    local sy = py + titleH/2
    text(px + 10, sy, "◀", 9, 60,200,120,180, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    addHit(px, py, 28, titleH, function() exchangeCollapsed_ = true end)
    text(px+pw/2, sy, "[ 资源互换中心 ]", 13, 60,220,140,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = py + titleH + 2

    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(60,200,120,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 3

    -- 库存行
    if rm then
        local resOrder = {"metal","esource","nuclear"}
        local colW = (pw - 16) / 3
        for i, res in ipairs(resOrder) do
            local amt   = math.floor(rm.resources[res] or 0)
            local rclr  = RES_COLORS[res]
            local cx    = px + 8 + (i - 1) * colW + colW / 2
            local enough = amt >= EXCHANGE_AMOUNT
            text(cx, sy + stockH/2,
                RES_LABELS[res] .. ": " .. amt,
                9,
                enough and (rclr[1]+30) or 180,
                enough and (rclr[2]+30) or 100,
                enough and (rclr[3]+30) or 80,
                enough and 220 or 150,
                NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
    end
    sy = sy + stockH + 3

    nvgBeginPath(vg); nvgMoveTo(vg, px+8, sy); nvgLineTo(vg, px+pw-8, sy)
    nvgStrokeColor(vg, clr(60,200,120,40)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 4

    -- 互换按钮
    for _, fromRes in ipairs(EXCHANGE_RES) do
        local fromLabel = RES_LABELS[fromRes]
        local fromClr   = RES_COLORS[fromRes]
        local have      = rm and (rm.resources[fromRes] or 0) or 0
        local canFrom   = have >= EXCHANGE_AMOUNT

        text(px + 12, sy + 6,
            "消耗 " .. fromLabel .. "（" .. math.floor(have) .. "）",
            9,
            fromClr[1]+20, fromClr[2]+20, fromClr[3]+20,
            canFrom and 200 or 120,
            NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        sy = sy + 12

        for _, toRes in ipairs(EXCHANGE_RES) do
            if toRes ~= fromRes then
                local ratio = EXCHANGE_RATES[fromRes] and EXCHANGE_RATES[fromRes][toRes]
                if ratio then
                    local toLabel = RES_LABELS[toRes]
                    local gain    = math.floor(EXCHANGE_AMOUNT * ratio)
                    local toClr   = RES_COLORS[toRes]

                    local bx2 = px + 8
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, bx2, sy, pw-16, btnH2, 3)
                    nvgFillColor(vg, nvgRGBA(
                        canFrom and 20 or 14,
                        canFrom and 80 or 45,
                        canFrom and 50 or 32,
                        canFrom and 210 or 110))
                    nvgFill(vg)
                    nvgStrokeColor(vg, nvgRGBA(
                        fromClr[1], fromClr[2], fromClr[3],
                        canFrom and 160 or 60))
                    nvgStrokeWidth(vg, 0.8)
                    nvgStroke(vg)

                    local midX = px + pw / 2
                    text(midX - 6, sy + btnH2/2,
                        "-" .. EXCHANGE_AMOUNT .. " " .. fromLabel,
                        10,
                        fromClr[1]+50, fromClr[2]+50, fromClr[3]+50,
                        canFrom and 230 or 110,
                        NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    text(midX, sy + btnH2/2, "⇒", 10,
                        160, 220, 160, canFrom and 200 or 90,
                        NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    text(midX + 6, sy + btnH2/2,
                        "+" .. gain .. " " .. toLabel,
                        10,
                        toClr[1]+50, toClr[2]+50, toClr[3]+50,
                        canFrom and 230 or 110,
                        NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

                    if canFrom then
                        local capturedFrom = fromRes
                        local capturedTo   = toRes
                        addHit(bx2, sy, pw-16, btnH2, function()
                            if onExchangeCb_ then onExchangeCb_(capturedFrom, capturedTo) end
                        end)
                    end
                    sy = sy + btnH2 + 3
                end
            end
        end
        sy = sy + 6
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. 造船厂面板（左侧，TechPanel 下方）
-- ═══════════════════════════════════════════════════════════════════════════════
function M.RenderShipyard(planet)
    local vg          = UICommon.vg
    local addHit      = UICommon.addHit
    local panel       = UICommon.panel
    local text        = UICommon.text
    local clr         = UICommon.clr
    local drawButton  = UICommon.drawButton
    local progressBar = UICommon.progressBar
    local rm          = UICommon.rm
    local spq         = UICommon.spq
    local PANEL_TOP   = UICommon.PANEL_TOP

    if not planet or not planet.colonized then return end
    local hasShipyard = false
    if planet.buildings then
        for _, b in ipairs(planet.buildings) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    if not hasShipyard and planet.isBase and planet.modules then
        for _, b in ipairs(planet.modules) do
            if b.key == "SHIPYARD" then hasShipyard = true; break end
        end
    end
    if not hasShipyard then return end

    local pw = 210
    local px = 12
    local techH = UICommon.techPanelH or 0
    local py = PANEL_TOP + (techH > 0 and (techH + 8) or 0)
    local titleH = 26

    -- 折叠态
    if shipyardCollapsed_ then
        local queueSize = spq and #spq.items or 0
        local colH = titleH + (queueSize > 0 and 16 or 0)
        panel(px, py, pw, colH, 5, {6,12,24,220}, {60,120,200,160})
        text(px + 14, py + titleH/2, "▶", 10, 100,160,255,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
        text(px + pw/2, py + titleH/2, "造船厂", 12, 100,170,255,220,
            NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        if queueSize > 0 then
            local job = spq.items[1]
            local pct = job.progress or 0
            progressBar(px+8, py+titleH, pw-16, 10, pct,
                SHIP_TYPES[job.shipType].name.." "..math.floor(pct*100).."%",
                80, 130, 220)
        end
        addHit(px, py, pw, colH, function() shipyardCollapsed_ = false end)
        return
    end

    -- 展开态
    local numShips  = #SHIP_QUEUE_ORDER
    local queueSize = spq and #spq.items or 0
    local ph = titleH + 4 + (queueSize > 0 and 16 or 18)
             + (queueSize > 1 and (10 + (queueSize - 1) * 16) or 0)
             + 8 + numShips * 22

    panel(px, py, pw, ph, 7, {6,12,24,240}, {60,120,200,200})

    local sy = py + titleH/2
    text(px + 10, sy, "◀", 9, 100,160,255,180, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    addHit(px, py, 28, titleH, function() shipyardCollapsed_ = true end)
    text(px+pw/2, sy, "[ 造船厂 ]", 13, 100,170,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    sy = py + titleH + 4

    -- 队列状态
    if spq and #spq.items > 0 then
        local displayMax = math.min(3, #spq.items)
        for i = 1, displayMax do
            local capturedIdx = i
            local q   = spq.items[i]
            local st  = SHIP_TYPES[q.shipType]
            local rowH = 18
            local rowY = sy

            if i == 1 then
                local pct   = q.progress or 0
                local pulse = math.abs(math.sin(gameTime_ * 3)) * 80 + 120
                local barW  = pw - 52
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+8, rowY, barW, 14, 3)
                nvgFillColor(vg, nvgRGBA(20,50,100,180))
                nvgFill(vg)
                if pct > 0 then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, px+8, rowY, barW * pct, 14, 3)
                    nvgFillColor(vg, nvgRGBA(60, 140, 255, math.floor(pulse)))
                    nvgFill(vg)
                end
                local lbl = st.name .. " " .. math.floor(pct*100) .. "%"
                text(px+8+barW/2, rowY+7, lbl, 9, 180,210,255,220, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+pw-40, rowY+1, 14, 12, 2)
                nvgFillColor(vg, nvgRGBA(180,60,60,160))
                nvgFill(vg)
                text(px+pw-33, rowY+7, "×", 10, 255,180,180,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-40, rowY, 14, 14, function()
                    if onShipCancelCb_ then onShipCancelCb_(capturedIdx) end
                end)
                sy = sy + 18
            else
                local rowMid = rowY + rowH/2
                nvgBeginPath(vg)
                nvgCircle(vg, px+14, rowMid, 4)
                nvgFillColor(vg, nvgRGBA(st.color[1], st.color[2], st.color[3], 200))
                nvgFill(vg)
                text(px+24, rowMid, (i-1)..". "..st.name, 10, 160,185,225,200, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
                -- ↑ 上移
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+pw-56, rowY+3, 14, 12, 2)
                nvgFillColor(vg, nvgRGBA(60,120,200,140))
                nvgFill(vg)
                text(px+pw-49, rowMid, "↑", 9, 160,210,255,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-56, rowY+2, 14, 14, function()
                    if onShipPromoteCb_ then onShipPromoteCb_(capturedIdx) end
                end)
                -- × 取消
                nvgBeginPath(vg)
                nvgRoundedRect(vg, px+pw-40, rowY+3, 14, 12, 2)
                nvgFillColor(vg, nvgRGBA(180,60,60,140))
                nvgFill(vg)
                text(px+pw-33, rowMid, "×", 10, 255,180,180,255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(px+pw-40, rowY+2, 14, 14, function()
                    if onShipCancelCb_ then onShipCancelCb_(capturedIdx) end
                end)
                sy = sy + rowH
            end
        end
        if #spq.items > 3 then
            text(px+pw/2, sy+6, "...还有 " .. (#spq.items-3) .. " 艘", 9, 120,140,170,160, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            sy = sy + 14
        end
    else
        text(px+10, sy+7, "队列: 空闲", 10, 130,150,180,180)
        sy = sy + 18
    end

    nvgBeginPath(vg); nvgMoveTo(vg, px+6, sy); nvgLineTo(vg, px+pw-6, sy)
    nvgStrokeColor(vg, clr(60,120,200,60)); nvgStrokeWidth(vg, 1); nvgStroke(vg)
    sy = sy + 8

    for si_, stype in ipairs(SHIP_QUEUE_ORDER) do
        local capturedType = stype
        local cost = SHIP_COSTS[stype]
        local costStr = rm:fmtCost(cost)
        local st = SHIP_TYPES[stype]
        local timeStr = st.buildTime and (" ⏱"..st.buildTime.."s") or ""
        local hkPrefix = si_ <= 5 and (si_..".") or "  "
        sy = drawButton(px+8, sy, pw-16, 18,
            hkPrefix..st.name.." ["..costStr.."]"..timeStr,
            60, 100, 220,
            function()
                if onShipQueueCb_ then onShipQueueCb_(capturedType) end
            end)
    end
end

return M
