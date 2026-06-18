-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function getHeritageNodeRects(sw, sh, evolutionTree)
    local PW      = math.min(620, sw - 40)
    local px      = (sw - PW) * 0.5
    local py      = (sh - 460) * 0.5
    local nodeW   = math.floor((PW - 48) / 4) - 8  -- 约128
    local nodeH   = 78
    local gapX    = 8
    local lineH   = nodeH + 28  -- 节点 + 路线标题

    local result = {}
    for li, lineName in ipairs(LINE_ORDER) do
        local rowY = py + 70 + (li - 1) * (lineH + 12)
        for _, node in ipairs(evolutionTree) do
            if node.line == lineName then
                local col = node.tier - 1  -- 0-based
                local nx  = px + 24 + col * (nodeW + gapX)
                local ny  = rowY + 24  -- below line label
                result[#result + 1] = {
                    nodeId = node.id,
                    x = nx, y = ny, w = nodeW, h = nodeH,
                    node = node,
                }
            end
        end
    end
    return result
end
