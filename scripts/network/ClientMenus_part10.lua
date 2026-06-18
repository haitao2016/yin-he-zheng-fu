-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetCustomPanelLayout(sw, sh)
    local pw, ph = 380, 106
    return {
        x = (sw - pw) / 2,
        y = sh * 0.46 + 110 + 8,
        w = pw,
        h = ph,
    }
end
