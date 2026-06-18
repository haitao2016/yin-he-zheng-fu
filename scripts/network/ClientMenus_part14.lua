-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetEndlessBtnLayout(sw, sh, ctx)
    local btnW = 165 * 4 + 16 * 3
    local btnH = 48
    local btnX = (sw - btnW) / 2
    local extraY = ClientMenus.GetCustomPanelVisible(ctx) and 118 or 0
    local btnY = sh * 0.46 + 110 + 18 + extraY
    return { x=btnX, y=btnY, w=btnW, h=btnH }
end
