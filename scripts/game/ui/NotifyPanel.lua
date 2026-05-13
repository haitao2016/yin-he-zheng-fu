--- 通知面板模块
--- 负责：浮动 toast 通知、通知中心日志面板
--- 依赖：UICommon（vg, screenW, screenH, addHit, addScroll）

local UICommon = require("game.ui.UICommon")

local NotifyPanel = {}

-- ============================================================================
-- 私有常量
-- ============================================================================
local NOTIFY_LIFE    = 3.5
local NOTIFY_LOG_MAX = 80

local NOTIFY_COLORS = {
    success = {50,  220, 100, 255},
    error   = {255, 70,  70,  255},
    info    = {68,  136, 255, 255},
    warn    = {255, 200, 50,  255},
}

-- ============================================================================
-- 私有状态
-- ============================================================================
local notifications_      = {}      -- 浮动 toast 队列（最多5条）
local notifyLog_          = {}      -- 持久日志（最多 NOTIFY_LOG_MAX 条）
local notifyCenterOpen_   = false   -- 通知中心面板开关
local notifyCenterScroll_ = 0       -- 通知中心滚动偏移
local notifyUnread_       = 0       -- 未读计数
local gameTime_           = 0       -- 累计游戏时间（秒），用于打时间戳

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 推送一条通知（同时写入 toast 队列和日志）
---@param msg string
---@param ntype string  "success"|"error"|"info"|"warn"
function NotifyPanel.Push(msg, ntype)
    ntype = ntype or "info"
    local c = NOTIFY_COLORS[ntype] or NOTIFY_COLORS["info"]

    -- 飘字队列
    notifications_[#notifications_+1] = {
        text    = msg,
        color   = c,
        timer   = NOTIFY_LIFE,
        maxTime = NOTIFY_LIFE,
    }
    while #notifications_ > 5 do table.remove(notifications_, 1) end

    -- 写入通知中心日志
    local mins = math.floor(gameTime_ / 60)
    local secs = math.floor(gameTime_) % 60
    notifyLog_[#notifyLog_+1] = {
        text      = msg,
        ntype     = ntype,
        color     = c,
        timeLabel = string.format("%02d:%02d", mins, secs),
    }
    while #notifyLog_ > NOTIFY_LOG_MAX do table.remove(notifyLog_, 1) end

    -- 面板关闭时累计未读
    if not notifyCenterOpen_ then
        notifyUnread_ = notifyUnread_ + 1
    end
    print("[Notify]", ntype, msg)
end

--- 每帧更新（推进 toast 计时、累计游戏时间）
---@param dt number
function NotifyPanel.Update(dt)
    gameTime_ = gameTime_ + dt
    for i = #notifications_, 1, -1 do
        notifications_[i].timer = notifications_[i].timer - dt
        if notifications_[i].timer <= 0 then
            table.remove(notifications_, i)
        end
    end
end

--- 打开/关闭通知中心面板
function NotifyPanel.Toggle()
    notifyCenterOpen_ = not notifyCenterOpen_
    if notifyCenterOpen_ then
        notifyUnread_ = 0
    end
end

--- 关闭通知中心面板
function NotifyPanel.Close()
    notifyCenterOpen_ = false
end

--- 查询面板是否打开
---@return boolean
function NotifyPanel.IsOpen()
    return notifyCenterOpen_
end

--- 查询未读计数
---@return number
function NotifyPanel.GetUnread()
    return notifyUnread_
end

--- 同步外部游戏时间（由 GameUI 在 UpdateNotifications 中调用）
---@param t number
function NotifyPanel.SetGameTime(t)
    gameTime_ = t
end

-- ============================================================================
-- 渲染：通知中心面板（完整日志）
-- ============================================================================
function NotifyPanel.RenderCenter()
    if not notifyCenterOpen_ then return end

    local vg       = UICommon.vg
    local screenW  = UICommon.screenW
    local screenH  = UICommon.screenH
    local addHit   = UICommon.addHit
    local addScroll= UICommon.addScroll
    local C        = UICommon.C

    local pw  = 340
    local ph  = math.min(screenH - 80, 420)
    local px  = screenW - pw - 12
    local py  = 46

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgFillColor(vg, nvgRGBA(C.panelBgDark[1], C.panelBgDark[2], C.panelBgDark[3], C.panelBgDark[4] or 255))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(68, 136, 255, 160))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 24, 8)
    nvgFillColor(vg, nvgRGBA(20, 50, 100, 200))
    nvgFill(vg)
    nvgFontFace(vg, "sans"); nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 200, 255, 255))
    nvgText(vg, px + pw/2, py + 12, "◎ 系统通知中心")

    -- 关闭按钮
    local cbx, cby, cbsz = px + pw - 24, py + 4, 16
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cbx, cby, cbsz, cbsz, 4)
    nvgFillColor(vg, nvgRGBA(180, 60, 60, 140))
    nvgFill(vg)
    nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 180, 180, 255))
    nvgText(vg, cbx + cbsz/2, cby + cbsz/2, "✕")
    addHit(cbx, cby, cbsz, cbsz, function()
        notifyCenterOpen_ = false
    end)

    -- 清空按钮
    local clbx = px + 8
    nvgBeginPath(vg)
    nvgRoundedRect(vg, clbx, cby, 36, cbsz, 4)
    nvgFillColor(vg, nvgRGBA(60, 60, 80, 120))
    nvgFill(vg)
    nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(150, 160, 180, 200))
    nvgText(vg, clbx + 18, cby + cbsz/2, "清空")
    addHit(clbx, cby, 36, cbsz, function()
        notifyLog_    = {}
        notifyUnread_ = 0
    end)

    -- 日志列表区（可滚动）
    local listY   = py + 26
    local listH   = ph - 26
    local itemH   = 28
    local total   = #notifyLog_
    local contentH = total * itemH
    local maxScroll = math.max(0, contentH - listH)
    notifyCenterScroll_ = math.max(0, math.min(maxScroll, notifyCenterScroll_))

    addScroll(px, listY, pw, listH, function(delta)
        notifyCenterScroll_ = notifyCenterScroll_ - delta * 30
    end)

    nvgSave(vg)
    nvgScissor(vg, px + 1, listY, pw - 2, listH)

    if total == 0 then
        nvgFontSize(vg, 11); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 120, 160, 150))
        nvgText(vg, px + pw/2, listY + listH/2, "暂无通知")
    else
        -- 从最新一条倒序显示
        for idx = total, 1, -1 do
            local entry = notifyLog_[idx]
            local row   = total - idx          -- 0=最新
            local iy    = listY + row * itemH - notifyCenterScroll_
            if iy + itemH > listY and iy < listY + listH then
                -- 交替底色
                if row % 2 == 0 then
                    nvgBeginPath(vg)
                    nvgRect(vg, px + 1, iy, pw - 2, itemH)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 8))
                    nvgFill(vg)
                end
                -- 类型色条
                local c = entry.color
                nvgBeginPath(vg)
                nvgRect(vg, px + 1, iy + 4, 3, itemH - 8)
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 220))
                nvgFill(vg)
                -- 时间戳
                nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(100, 130, 180, 180))
                nvgText(vg, px + 10, iy + itemH/2 - 6, entry.timeLabel)
                -- 类型标签
                local typeLabel = ({
                    success = "成功",
                    error   = "错误",
                    info    = "信息",
                    warn    = "警告",
                })[entry.ntype] or "信息"
                nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], 200))
                nvgText(vg, px + 44, iy + itemH/2 - 6, "[" .. typeLabel .. "]")
                -- 正文
                nvgFontSize(vg, 10); nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(200, 220, 255, 230))
                nvgText(vg, px + 10, iy + itemH/2 + 7, entry.text)
            end
        end
    end

    nvgRestore(vg)
end

-- ============================================================================
-- 渲染：浮动 toast 通知（屏幕顶部飘字）
-- ============================================================================
function NotifyPanel.RenderToasts()
    if #notifications_ == 0 then return end
    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local startY  = 76
    nvgFontFace(vg, "sans")
    for i, n in ipairs(notifications_) do
        local alpha = math.min(1, n.timer / 0.6)
        local a     = math.floor(alpha * 230)
        local y     = startY + (i-1) * 28
        -- 胶囊背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, screenW/2 - 160, y, 320, 22, 11)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(a * 0.6)))
        nvgFill(vg)
        -- 颜色侧条
        nvgBeginPath(vg)
        nvgRoundedRect(vg, screenW/2 - 160, y, 4, 22, 2)
        nvgFillColor(vg, nvgRGBA(n.color[1], n.color[2], n.color[3], a))
        nvgFill(vg)
        -- 文字
        nvgFontFace(vg, "sans"); nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(n.color[1], n.color[2], n.color[3], a))
        nvgText(vg, screenW/2, y + 11, n.text)
    end
end

return NotifyPanel
