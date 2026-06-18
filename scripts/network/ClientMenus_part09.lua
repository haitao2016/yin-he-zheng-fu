-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetCustomPanelVisible(ctx)
    return ctx.hover == "custom" or ctx.customDiffSlider ~= nil
end
