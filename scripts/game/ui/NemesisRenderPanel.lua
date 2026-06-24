--- 宿敌档案面板渲染模块
--- 左侧浮动，展示所有海盗船长的进化等级、状态与战术风格

local UICommon      = require("game.ui.UICommon")
local DragManager   = require("game.ui.DragManager")
local NemesisSystem = require("game.NemesisSystem")

local NemesisRenderPanel = {}

-- ============================================================================
-- 面板私有状态
-- ============================================================================
local visible_ = false   -- 面板是否显示

-- ============================================================================
-- 公开 API
-- ============================================================================

function NemesisRenderPanel.IsVisible()  return visible_  end

function NemesisRenderPanel.Toggle()
    visible_ = not visible_
end

function NemesisRenderPanel.Show()   visible_ = true   end
function NemesisRenderPanel.Hide()   visible_ = false  end

--- 重置状态（新局开始时由 GameUI.Reset 调用）
function NemesisRenderPanel.Reset()
    visible_ = false
end

-- ============================================================================
-- 渲染
-- ============================================================================

function NemesisRenderPanel.Render()
    if not visible_ then return end
    local captains = NemesisSystem.GetAllCaptains()
    if not captains or #captains == 0 then return end

    local vg = UICommon.vg

    local PW     = 220
    local PAD    = 10
    local CARD_H = 62
    local HEADER = 28
    local ph     = HEADER + #captains * (CARD_H + 6) + PAD
    local px, py = DragManager.GetPos("nemesis", 8, 50)

    -- 面板背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, ph, 8)
    nvgFillColor(vg, nvgRGBA(12, 8, 24, 235))
    nvgFill(vg)
    DragManager.RegisterHandle("nemesis", px, py, PW, 24)
    DragManager.DrawHandle(vg, px, py, PW, 6)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, ph, 8)
    nvgStrokeColor(vg, nvgRGBA(180, 60, 60, 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 100, 80, 255))
    nvgText(vg, px + PW / 2, py + HEADER / 2, "⚔ 宿敌档案")

    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 8, py + HEADER)
    nvgLineTo(vg, px + PW - 8, py + HEADER)
    nvgStrokeColor(vg, nvgRGBA(180, 60, 60, 120))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- 关闭按钮
    UICommon.addHit(px + PW - 28, py + 2, 26, 26, function() visible_ = false end)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(200, 100, 100, 200))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, px + PW - 15, py + HEADER / 2, "✕")

    local cy = py + HEADER + 4

    -- 当前活跃宿敌
    local active = NemesisSystem.GetActiveCaptain()

    for _, cap in ipairs(captains) do
        local cx = px + PAD
        local cw = PW - PAD * 2
        local isActive = active and active.id == cap.id

        -- 卡片背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx - 2, cy, cw + 4, CARD_H, 5)
        local bgAlpha = isActive and 200 or 160
        nvgFillColor(vg, nvgRGBA(20, 12, 30, bgAlpha))
        nvgFill(vg)

        -- 活跃宿敌边框高亮
        if isActive then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - 2, cy, cw + 4, CARD_H, 5)
            local pulse = 0.6 + 0.4 * math.abs(math.sin(os.clock() * 2.5))
            nvgStrokeColor(vg, nvgRGBA(cap.color[1], cap.color[2], cap.color[3],
                                        math.floor(220 * pulse)))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        else
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - 2, cy, cw + 4, CARD_H, 5)
            nvgStrokeColor(vg, nvgRGBA(80, 60, 80, 80))
            nvgStrokeWidth(vg, 0.7)
            nvgStroke(vg)
        end

        -- 颜色指示条（左侧）
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy + 4, 3, CARD_H - 8, 2)
        local cAlpha = cap.defeated and 80 or 220
        nvgFillColor(vg, nvgRGBA(cap.color[1], cap.color[2], cap.color[3], cAlpha))
        nvgFill(vg)

        -- 船长名称
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFontSize(vg, 11)
        if cap.defeated then
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 180))
        else
            nvgFillColor(vg, nvgRGBA(cap.color[1], cap.color[2], cap.color[3], 255))
        end
        nvgText(vg, cx + 8, cy + 4, cap.name)

        -- 头衔
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(160, 140, 180, 180))
        nvgText(vg, cx + 8, cy + 18, cap.title)

        -- 进化等级条（5格）
        local barX = cx + 8
        local barY = cy + 32
        local barW = 10
        for lv = 1, 5 do
            nvgBeginPath(vg)
            nvgRoundedRect(vg, barX + (lv-1) * (barW + 2), barY, barW, 6, 2)
            if lv <= cap.level then
                nvgFillColor(vg, nvgRGBA(cap.color[1], cap.color[2], cap.color[3],
                                          cap.defeated and 60 or 200))
            else
                nvgFillColor(vg, nvgRGBA(40, 30, 50, 150))
            end
            nvgFill(vg)
        end

        -- 等级文本
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(180, 160, 200, 200))
        nvgText(vg, barX + 5 * (barW + 2) + 4, barY - 1,
                string.format("Lv.%d", cap.level))

        -- 状态标签（右上角）
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFontSize(vg, 9)
        if cap.defeated then
            nvgFillColor(vg, nvgRGBA(80, 200, 80, 200))
            nvgText(vg, cx + cw, cy + 4, "已击败")
        elseif isActive then
            nvgFillColor(vg, nvgRGBA(255, 80, 60, 240))
            nvgText(vg, cx + cw, cy + 4, "追踪中")
        else
            nvgFillColor(vg, nvgRGBA(120, 100, 140, 140))
            nvgText(vg, cx + cw, cy + 4, string.format("遭遇 ×%d", cap.encounters))
        end

        -- 战术风格描述
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFontSize(vg, 8)
        nvgFillColor(vg, nvgRGBA(140, 130, 160, 160))
        nvgText(vg, cx + 8, cy + 44, cap.desc)

        -- 最终决战标记
        if cap.level >= 5 and not cap.defeated then
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_BOTTOM)
            nvgFontSize(vg, 9)
            local fpulse = 0.5 + 0.5 * math.abs(math.sin(os.clock() * 3))
            nvgFillColor(vg, nvgRGBA(255, 200, 60, math.floor(255 * fpulse)))
            nvgText(vg, cx + cw, cy + CARD_H - 4, "★ 最终决战")
        end

        cy = cy + CARD_H + 6
    end
end

return NemesisRenderPanel
