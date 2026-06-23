-- ============================================================================
-- game/ui/Overlays.lua  -- 全屏覆盖层（模态弹窗）
-- 包含：战役剧情对话 / 星图随机事件弹窗 / 轮间选卡面板
-- ============================================================================

local UICommon  = require("game.ui.UICommon")
local Campaign  = require("game.CampaignSystem")

local M = {}

-- ============================================================================
-- 私有状态
-- ============================================================================

-- 事件弹窗状态: { ev={color,icon,label,desc,choices}, onChoice=fn } | nil
local eventPopup_ = nil

-- 选卡面板状态
local cardDraft_ = {
    visible   = false,
    cards     = {},       -- [{key, icon, label, desc, rarity}]
    onSelect  = nil,      -- function(cardKey)
    hoverIdx  = 0,        -- 鼠标悬停的卡牌索引
    animT     = 0,        -- 入场动画计时器
    runT      = 0,        -- 粒子动画累计时间
}

-- 当前无尽模式轮次
local endlessRound_ = 0

-- 回调
local onCampaignDialogueDone_ = nil
local onDiploEventChoiceCb_   = nil

-- ============================================================================
-- 初始化 & 每帧更新
-- ============================================================================

--- 注入回调
---@param cfg table
function M.Init(cfg)
    onCampaignDialogueDone_ = cfg.onCampaignDialogueDone
    onDiploEventChoiceCb_   = cfg.onDiploEventChoice
end

--- 每帧 Update（动画推进）
---@param dt number
function M.Update(dt)
    if cardDraft_.visible then
        cardDraft_.animT = math.min(1.0, cardDraft_.animT + dt * 3.0)
        cardDraft_.runT  = (cardDraft_.runT or 0) + dt
    end
end

-- ============================================================================
-- 外部 Setters
-- ============================================================================

function M.SetEndlessRound(round)
    endlessRound_ = round or 0
end

-- ============================================================================
-- 选卡面板 API
-- ============================================================================

--- 展示无尽模式选卡面板
--- cards: [{key, icon, label, desc, rarity}], onSelect: function(cardKey)
function M.ShowCardDraft(cards, onSelect)
    cardDraft_.visible  = true
    cardDraft_.cards    = cards or {}
    cardDraft_.onSelect = onSelect
    cardDraft_.hoverIdx = 0
    cardDraft_.animT    = 0
    cardDraft_.runT     = 0
end

--- 隐藏选卡面板
function M.HideCardDraft()
    cardDraft_.visible  = false
    cardDraft_.cards    = {}
    cardDraft_.onSelect = nil
end

-- ============================================================================
-- 事件弹窗 API
-- ============================================================================

--- 显示事件弹窗
---@param ev     table   事件数据 {color, icon, label, desc, choices}
---@param onChoice function(choiceIdx) 玩家选择后回调
function M.ShowEventPopup(ev, onChoice)
    eventPopup_ = { ev = ev, onChoice = onChoice }
end

--- P1-1 V2.4: 外交事件弹窗（适配 ShowEventPopup 格式）
---@param ev table  来自 DiplomacySystem._generateDiploEvent 的事件数据
function M.ShowDiploEvent(ev)
    if not ev then return end
    local color = {100, 180, 255}
    local icon  = "🤝"
    local label = "外交事件"
    local desc  = ev.desc or ""
    local choices = {}

    if ev.type == "diplo_request" then
        icon  = ev.icon or "📜"
        label = string.format("%s 的请求", ev.factionName or "?")
        color = {80, 200, 160}
        choices = {
            { text = ev.choiceA and ev.choiceA.label or "同意" },
            { text = ev.choiceB and ev.choiceB.label or "拒绝" },
        }
    elseif ev.type == "diplo_dispute" then
        icon  = "⚖️"
        label = "贸易纠纷"
        color = {220, 180, 60}
        choices = {
            { text = ev.choiceA and ev.choiceA.label or "支持发起方" },
            { text = ev.choiceB and ev.choiceB.label or "保持中立" },
        }
    elseif ev.type == "diplo_opportunity" then
        icon  = "💎"
        label = "合作机遇"
        color = {140, 100, 255}
        local costStr = ""
        if ev.cost then
            for k, v in pairs(ev.cost) do costStr = costStr .. k .. "×" .. v .. " " end
        end
        choices = {
            { text = string.format("接受（花费 %s）", costStr) },
            { text = "拒绝" },
        }
    end

    local adapted = {
        color   = color,
        icon    = icon,
        label   = label,
        desc    = desc,
        choices = choices,
    }
    M.ShowEventPopup(adapted, function(idx)
        if onDiploEventChoiceCb_ then
            onDiploEventChoiceCb_(idx)
        end
    end)
end

--- 清除事件弹窗
function M.ClearEventPopup()
    eventPopup_ = nil
end

-- ============================================================================
-- 渲染：战役剧情对话框（底部半透明条，点击推进）
-- ============================================================================
function M.RenderCampaignDialogue()
    if not Campaign.IsShowingDialogue() then return end
    local vg = UICommon.vg
    local sw = UICommon.screenW
    local sh = UICommon.screenH
    local addHit = UICommon.addHit
    local line = Campaign.GetCurrentDialogueLine()
    if not line then return end

    -- 底部对话条：高度 110px
    local barH = 110
    local barY = sh - barH

    -- 半透明暗色背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, barY, sw, barH)
    nvgFillColor(vg, nvgRGBA(10, 15, 30, 220))
    nvgFill(vg)

    -- 顶部分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, barY)
    nvgLineTo(vg, sw, barY)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, 150))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 说话者名字（蓝色高亮）
    local padX = 24
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, padX, barY + 14, line.speaker or "???")

    -- 对话文字
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(230, 235, 245, 255))
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    local textW = sw - padX * 2
    nvgTextBox(vg, padX, barY + 38, textW, line.text or "")

    -- "点击继续" 提示（右下角）
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, math.floor(140 + 80 * math.abs(math.sin(os.clock() * 3)))))
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
    nvgText(vg, sw - padX, sh - 10, "▶ 点击继续")

    -- 全屏点击区域推进对话
    addHit(0, barY, sw, barH, function()
        local finished = Campaign.AdvanceDialogue()
        if finished and onCampaignDialogueDone_ then
            onCampaignDialogueDone_()
        end
    end)
end

-- ============================================================================
-- 渲染：星图随机事件弹窗
-- ============================================================================
function M.RenderEventPopup()
    if not eventPopup_ then return end
    local vg = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local addHit  = UICommon.addHit

    local ev       = eventPopup_.ev
    local onChoice = eventPopup_.onChoice
    local r, g, b  = ev.color[1], ev.color[2], ev.color[3]

    -- 半透明全屏遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 160))
    nvgFill(vg)

    -- 弹窗主体
    local panW  = math.min(screenW - 40, 340)
    local btnH  = 34
    local padV  = 14
    local titleH = 32
    local descH  = 36
    local choiceH = #ev.choices * (btnH + 8)
    local panH  = titleH + padV + descH + padV + choiceH + padV
    local panX  = screenW / 2 - panW / 2
    local panY  = screenH / 2 - panH / 2

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, panH, 10)
    nvgFillColor(vg, nvgRGBA(6, 12, 28, 248))
    nvgFill(vg)
    -- 边框（事件主色）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX + 0.5, panY + 0.5, panW - 1, panH - 1, 10)
    nvgStrokeColor(vg, nvgRGBA(r, g, b, 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
    -- 顶部彩色条
    nvgBeginPath(vg)
    nvgRoundedRect(vg, panX, panY, panW, 4, 10)
    nvgFillColor(vg, nvgRGBA(r, g, b, 200))
    nvgFill(vg)

    -- 标题行（图标 + 名称）
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(r, g, b, 255))
    nvgText(vg, screenW / 2, panY + 4 + titleH / 2 + 2,
        ev.icon .. "  " .. ev.label)

    -- 描述文字
    local descY = panY + titleH + padV
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 200))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgTextBox(vg, panX + 16, descY, panW - 32, ev.desc)

    -- 选项按钮
    local btnY = descY + descH + padV
    for idx, ch in ipairs(ev.choices) do
        local isCancel = (ch.cost == nil and ch.gain == nil and ch.res == nil)
        local bgR = isCancel and nvgRGBA(40, 40, 60, 180) or nvgRGBA(r // 4, g // 4, b // 4, 200)
        local bdR = isCancel and nvgRGBA(80, 80, 120, 120) or nvgRGBA(r, g, b, 160)
        local txR = isCancel and nvgRGBA(140, 150, 180, 200) or nvgRGBA(r, g, b, 240)

        local bx = panX + 12
        local bw = panW - 24
        -- 按钮背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx, btnY, bw, btnH, 6)
        nvgFillColor(vg, bgR)
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, bx + 0.5, btnY + 0.5, bw - 1, btnH - 1, 6)
        nvgStrokeColor(vg, bdR)
        nvgStrokeWidth(vg, 1)
        nvgStroke(vg)
        -- 悬停高亮
        if cursorX >= bx and cursorX <= bx + bw
            and cursorY >= btnY and cursorY <= btnY + btnH then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, btnY, bw, btnH, 6)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 18))
            nvgFill(vg)
        end
        -- 按钮文字
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, txR)
        nvgText(vg, bx + bw / 2, btnY + btnH / 2, ch.text)

        -- 注册点击区域
        local captureIdx = idx
        addHit(bx, btnY, bw, btnH, function()
            eventPopup_ = nil
            if onChoice then onChoice(captureIdx) end
        end)
        btnY = btnY + btnH + 8
    end
end

-- ============================================================================
-- 渲染：轮间选卡覆盖层
-- ============================================================================
function M.RenderCardDraft()
    if not cardDraft_.visible or #cardDraft_.cards == 0 then return end

    local vg      = UICommon.vg
    local sw      = UICommon.screenW
    local sh      = UICommon.screenH
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local addHit  = UICommon.addHit
    local t       = cardDraft_.animT  -- 0→1 入场插值

    -- 暗化背景
    nvgBeginPath(vg); nvgRect(vg, 0, 0, sw, sh)
    nvgFillColor(vg, nvgRGBA(0, 0, 10, math.floor(200 * t)))
    nvgFill(vg)

    -- 标题
    local titleY = sh * 0.12 + (1 - t) * 40
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 22)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(255 * t)))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, sw / 2, titleY, string.format("⚡ 第 %d 轮奖励 — 选择强化卡牌", endlessRound_))
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(180, 180, 200, math.floor(200 * t)))
    nvgText(vg, sw / 2, titleY + 26, "选择一张卡牌增强你的舰队")

    -- 卡牌布局
    local CARD_W, CARD_H = 170, 240
    local GAP    = 24
    local n      = #cardDraft_.cards
    local totalW = n * CARD_W + (n - 1) * GAP
    local startX = sw / 2 - totalW / 2
    local cardY  = sh * 0.5 - CARD_H / 2 + (1 - t) * 60

    -- 稀有度颜色
    local rarityColors = {
        common   = {120, 200, 255},
        rare     = {160, 120, 255},
        epic     = {255, 180, 60},
    }

    -- hover 命中检测
    local newHoverIdx = 0
    for i = 1, n do
        local cx2 = startX + (i - 1) * (CARD_W + GAP)
        if cursorX >= cx2 and cursorX <= cx2 + CARD_W
           and cursorY >= cardY - 10 and cursorY <= cardY + CARD_H then
            newHoverIdx = i
        end
    end
    cardDraft_.hoverIdx = newHoverIdx

    for i, card in ipairs(cardDraft_.cards) do
        local cx = startX + (i - 1) * (CARD_W + GAP)
        local isHover = (cardDraft_.hoverIdx == i)
        local ry = isHover and (cardY - 10) or cardY
        local rc = rarityColors[card.rarity or "common"]

        -- 卡牌背景
        nvgBeginPath(vg); nvgRoundedRect(vg, cx, ry, CARD_W, CARD_H, 12)
        nvgFillColor(vg, nvgRGBA(12, 20, 40, 240))
        nvgFill(vg)
        -- 边框（稀有度色）
        nvgStrokeWidth(vg, isHover and 3 or 2)
        nvgStrokeColor(vg, nvgRGBA(rc[1], rc[2], rc[3], isHover and 255 or 180))
        nvgStroke(vg)

        -- 史诗卡金色粒子特效
        if card.rarity == "epic" then
            local gt = cardDraft_.runT or 0
            local SPARKS = 12
            for si = 1, SPARKS do
                local phase = (si / SPARKS) * math.pi * 2 + gt * 1.8
                local perim = 2 * (CARD_W + CARD_H)
                local pos   = ((phase % (math.pi * 2)) / (math.pi * 2)) * perim
                local px, py
                if pos < CARD_W then
                    px, py = cx + pos, ry
                elseif pos < CARD_W + CARD_H then
                    px, py = cx + CARD_W, ry + (pos - CARD_W)
                elseif pos < 2 * CARD_W + CARD_H then
                    px, py = cx + CARD_W - (pos - CARD_W - CARD_H), ry + CARD_H
                else
                    px, py = cx, ry + CARD_H - (pos - 2 * CARD_W - CARD_H)
                end
                local sparkAlpha = math.floor(180 * t * (0.5 + 0.5 * math.sin(phase * 3 + si)))
                local sparkR     = 2.0 + 1.5 * math.abs(math.sin(phase * 2 + si * 0.7))
                nvgBeginPath(vg)
                nvgCircle(vg, px, py, sparkR)
                nvgFillColor(vg, nvgRGBA(255, 210, 60, sparkAlpha))
                nvgFill(vg)
            end
            -- 史诗卡顶部金色光晕
            local glowPaint = nvgRadialGradient(vg,
                cx + CARD_W / 2, ry - 4, 0, 60,
                nvgRGBA(255, 200, 50, math.floor(80 * t)),
                nvgRGBA(255, 180, 0, 0))
            nvgBeginPath(vg); nvgRect(vg, cx - 10, ry - 30, CARD_W + 20, 60)
            nvgFillPaint(vg, glowPaint); nvgFill(vg)
        end

        -- 图标
        nvgFontSize(vg, 44); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(255 * t)))
        nvgText(vg, cx + CARD_W / 2, ry + 62, card.icon or "★")
        -- 稀有度标签
        local rl = card.rarity == "epic" and "史诗" or card.rarity == "rare" and "稀有" or "普通"
        nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], 220))
        nvgText(vg, cx + CARD_W / 2, ry + 112, rl)
        -- 卡名
        nvgFontSize(vg, 14); nvgFillColor(vg, nvgRGBA(220, 230, 255, 240))
        nvgText(vg, cx + CARD_W / 2, ry + 132, card.label or "")
        -- 描述（最多2行）
        nvgFontSize(vg, 11); nvgFillColor(vg, nvgRGBA(160, 170, 200, 200))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        local desc = card.desc or ""
        local line1, line2 = desc:sub(1, 14), desc:sub(15)
        nvgText(vg, cx + CARD_W / 2, ry + 154, line1)
        if line2 ~= "" then nvgText(vg, cx + CARD_W / 2, ry + 168, line2) end
        -- 选择按钮
        local btnX, btnY2, btnW2, btnH2 = cx + 16, ry + CARD_H - 38, CARD_W - 32, 26
        nvgBeginPath(vg); nvgRoundedRect(vg, btnX, btnY2, btnW2, btnH2, 6)
        nvgFillColor(vg, nvgRGBA(rc[1], rc[2], rc[3], isHover and 200 or 120))
        nvgFill(vg)
        nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 230))
        nvgText(vg, cx + CARD_W / 2, btnY2 + btnH2 / 2, "选择")
        -- 注册点击热区（t 足够大才响应）
        if t > 0.5 then
            addHit(cx, ry, CARD_W, CARD_H, function()
                if cardDraft_.onSelect then cardDraft_.onSelect(card.key) end
                cardDraft_.visible = false
            end)
        end
    end
end

-- ============================================================================
-- 状态查询
-- ============================================================================

function M.IsCardDraftVisible()
    return cardDraft_.visible
end

function M.IsEventPopupVisible()
    return eventPopup_ ~= nil
end

return M
