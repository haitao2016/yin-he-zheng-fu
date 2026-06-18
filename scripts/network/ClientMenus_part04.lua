-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetMainMenuHit(mx, my, sw, sh, hasSave)
    local btns = ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    for _, btn in ipairs(btns) do
        if btn.enabled and mx >= btn.x and mx <= btn.x + btn.w
            and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    return nil
end
