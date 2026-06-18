-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetHeritagePanelHit(mx, my, sw, sh, ctx)
    local closeX, closeY = getHeritageClosePos(sw, sh)
    if math.sqrt((mx - closeX)^2 + (my - closeY)^2) < 16 then
        return "close"
    end
    local rects = getHeritageNodeRects(sw, sh, ctx.evolutionTree)
    for _, r in ipairs(rects) do
        if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then
            return r.nodeId
        end
    end
    return nil
end
