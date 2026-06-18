-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetDifficultyHit(mx, my, sw, sh, ctx)
    -- P1-1: 昵称输入框悬停检测
    local ni = ClientMenus.GetNicknameInputLayout(sw, sh)
    if mx >= ni.x and mx <= ni.x + ni.w and my >= ni.y and my <= ni.y + ni.h then
        return "nickname_input"
    end
    for _, btn in ipairs(ClientMenus.GetDifficultyBtnLayout(sw, sh, ctx)) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    if ClientMenus.GetCustomPanelVisible(ctx) then
        local p = ClientMenus.GetCustomPanelLayout(sw, sh)
        if mx >= p.x and mx <= p.x + p.w
        and my >= p.y and my <= p.y + p.h then
            return "custom"
        end
    end
    local eb = ClientMenus.GetEndlessBtnLayout(sw, sh, ctx)
    if mx >= eb.x and mx <= eb.x + eb.w
    and my >= eb.y and my <= eb.y + eb.h then
        return "endless"
    end
    return nil
end
