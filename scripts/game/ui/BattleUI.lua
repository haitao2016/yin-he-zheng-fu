local BattleUI = {}

local UICommon    = require("game.ui.UICommon")
local NotifyPanel = require("game.ui.NotifyPanel")

local vg_       = nil
local screenW_  = 800
local screenH_  = 600

local battleState_ = nil
local battleSpeed_ = 1.0

local hitAreas_ = {}

---@param vg userdata
---@param sw number
---@param sh number
function BattleUI.init(vg, sw, sh)
    vg_ = vg
    screenW_ = sw or 800
    screenH_ = sh or 600
end

---@param speed number
function BattleUI.setBattleSpeed(speed)
    battleSpeed_ = speed or 1.0
end

---@return table
function BattleUI.getStats()
    if not battleState_ then
        return {
            playerHp = 0, enemyHp = 0,
            playerDps = 0, enemyDps = 0,
            elapsed = 0, speed = battleSpeed_,
            victory = false, defeat = false,
        }
    end
    return {
        playerHp   = battleState_.playerHp or 0,
        enemyHp    = battleState_.enemyHp or 0,
        playerMaxHp = battleState_.playerMaxHp or 1,
        enemyMaxHp  = battleState_.enemyMaxHp or 1,
        playerDps  = battleState_.playerDps or 0,
        enemyDps   = battleState_.enemyDps or 0,
        elapsed    = battleState_.elapsed or 0,
        speed      = battleSpeed_,
        victory    = battleState_.victory == true,
        defeat     = battleState_.defeat == true,
        waveIndex  = battleState_.waveIndex or 1,
        totalWaves = battleState_.totalWaves or 1,
    }
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param label string
---@param r number
---@param g number
---@param b number
---@param onClick function|nil
local function drawButton(x, y, w, h, label, r, g, b, onClick)
    local mx = x + w / 2
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, 6)
    nvgFillColor(vg_, nvgRGBA(r, g, b, 60))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x + 0.5, y + 0.5, w - 1, h - 1, 6)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, 220))
    nvgStrokeWidth(vg_, 1.4)
    nvgStroke(vg_)
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 12)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(r + 80, g + 80, b + 80, 250))
    nvgText(vg_, mx, y + h / 2, label)
    if onClick then
        hitAreas_[#hitAreas_ + 1] = { x = x, y = y, w = w, h = h, fn = onClick }
    end
end

---@param x number
---@param y number
---@param w number
---@param h number
---@param pct number
---@param r number
---@param g number
---@param b number
local function bar(x, y, w, h, pct, r, g, b)
    pct = math.max(0, math.min(1, pct))
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x, y, w, h, h / 2)
    nvgFillColor(vg_, nvgRGBA(20, 30, 50, 200))
    nvgFill(vg_)
    if pct > 0.01 then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, x, y, w * pct, h, h / 2)
        nvgFillColor(vg_, nvgRGBA(r, g, b, 230))
        nvgFill(vg_)
    end
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, x + 0.5, y + 0.5, w - 1, h - 1, h / 2)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, 120))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)
end

---@param state table|nil
function BattleUI.render(state)
    battleState_ = state or battleState_
    screenW_, screenH_ = UICommon.getVirtualSize()
    hitAreas_ = {}

    local stats = BattleUI.getStats()

    local hudH = 78
    local hudY = screenH_ - hudH - 8
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, 8, hudY, screenW_ - 16, hudH, 8)
    nvgFillColor(vg_, nvgRGBA(8, 16, 36, 210))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, 8.5, hudY + 0.5, screenW_ - 17, hudH - 1, 8)
    nvgStrokeColor(vg_, nvgRGBA(80, 160, 255, 160))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    local marginX = 20
    local lineY = hudY + 18
    local barW = (screenW_ - 16) / 2 - marginX - 8
    local barH = 14

    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(180, 220, 255, 230))
    nvgText(vg_, marginX + 8, lineY - 10, "我方舰队")
    bar(marginX, lineY, barW, barH, stats.playerHp / stats.playerMaxHp, 60, 200, 120)
    local pctTxt = string.format("%d / %d", math.floor(stats.playerHp), stats.playerMaxHp)
    nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(240, 255, 240, 240))
    nvgText(vg_, marginX + barW / 2, lineY + barH / 2, pctTxt)

    local rightX = screenW_ - marginX - barW
    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 200, 200, 230))
    nvgText(vg_, rightX + barW - 8, lineY - 10, "敌方舰队")
    bar(rightX, lineY, barW, barH, stats.enemyHp / stats.enemyMaxHp, 230, 90, 90)
    nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 240, 240, 240))
    nvgText(vg_, rightX + barW / 2, lineY + barH / 2,
        string.format("%d / %d", math.floor(stats.enemyHp), stats.enemyMaxHp))

    local midY = lineY + barH + 14
    nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(180, 220, 255, 220))
    nvgText(vg_, screenW_ / 2, midY,
        string.format("波次 %d / %d   已用时 %.1fs   DPS 我 %d / 敌 %d",
            stats.waveIndex, stats.totalWaves, stats.elapsed,
            math.floor(stats.playerDps), math.floor(stats.enemyDps)))

    local cmdY = midY + 16
    local btnW = 84
    local btnH = 26
    local btnGap = 12
    local totalW = btnW * 4 + btnGap * 3
    local startX = math.floor(screenW_ / 2 - totalW / 2)

    drawButton(startX, cmdY, btnW, btnH, "⏸ 暂停", 100, 150, 220, function()
        BattleUI.setBattleSpeed(0)
        NotifyPanel.Push("战斗已暂停", "info")
    end)
    drawButton(startX + btnW + btnGap, cmdY, btnW, btnH, "▶ 1x", 60, 180, 120, function()
        BattleUI.setBattleSpeed(1)
    end)
    drawButton(startX + (btnW + btnGap) * 2, cmdY, btnW, btnH, "⏩ 2x", 230, 180, 60, function()
        BattleUI.setBattleSpeed(2)
    end)
    drawButton(startX + (btnW + btnGap) * 3, cmdY, btnW, btnH, "⚡ 4x", 230, 120, 200, function()
        BattleUI.setBattleSpeed(4)
    end)

    if stats.victory then
        BattleUI.renderEndCard("胜利！", 60, 200, 120)
    elseif stats.defeat then
        BattleUI.renderEndCard("战败", 230, 90, 90)
    end
end

---@param title string
---@param r number
---@param g number
---@param b number
function BattleUI.renderEndCard(title, r, g, b)
    local cw, ch = 360, 140
    local cx = math.floor(screenW_ / 2 - cw / 2)
    local cy = math.floor(screenH_ / 2 - ch / 2 - 40)

    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx, cy, cw, ch, 12)
    nvgFillColor(vg_, nvgRGBA(10, 18, 40, 240))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx + 0.5, cy + 0.5, cw - 1, ch - 1, 12)
    nvgStrokeColor(vg_, nvgRGBA(r, g, b, 220))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 30)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(r, g, b, 255))
    nvgText(vg_, cx + cw / 2, cy + 44, title)

    local stats = BattleUI.getStats()
    nvgFontSize(vg_, 12)
    nvgFillColor(vg_, nvgRGBA(220, 230, 255, 230))
    nvgText(vg_, cx + cw / 2, cy + 76,
        string.format("用时 %.1fs | 波次 %d/%d", stats.elapsed, stats.waveIndex, stats.totalWaves))

    drawButton(cx + cw / 2 - 60, cy + ch - 48, 120, 32, "返回", 120, 180, 240, function()
        NotifyPanel.Push("返回星图", "info")
    end)
end

---@param mx number
---@param my number
---@return boolean
function BattleUI.onClick(mx, my)
    for i = #hitAreas_, 1, -1 do
        local h = hitAreas_[i]
        if mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h then
            if h.fn then h.fn() end
            return true
        end
    end
    return false
end

---@param vg userdata
---@param w number
---@param h number
function BattleUI.setVg(vg, w, h)
    vg_ = vg
    screenW_ = w or screenW_
    screenH_ = h or screenH_
end

return BattleUI
