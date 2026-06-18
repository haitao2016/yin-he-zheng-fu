-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetNicknameInputLayout(sw, sh)
    local iw, ih = 240, 40
    return { x = (sw - iw) / 2, y = sh * 0.368, w = iw, h = ih }
end
