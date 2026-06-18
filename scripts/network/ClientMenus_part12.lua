-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetCustomSliderRects(sw, sh, ctx)
    local customDiff = ctx.customDiff
    local p     = ClientMenus.GetCustomPanelLayout(sw, sh)
    local trackW = 200
    local labelX = p.x + 12
    local trackX = p.x + p.w - trackW - 12
    local trackH = 6
    return {
        {
            name  = "attackFactor",
            label = "进攻频率",
            x = trackX, y = p.y + 22, w = trackW, h = trackH,
            vmin = 0.5, vmax = 2.5,
            value = customDiff.attackFactor,
            fmtFn = function(v)
                if v < 0.8 then return "极快" elseif v < 1.2 then return "普通"
                elseif v < 1.8 then return "较慢" else return "很慢" end
            end,
            labelX = labelX,
        },
        {
            name  = "initResBonus",
            label = "初始资源",
            x = trackX, y = p.y + 53, w = trackW, h = trackH,
            vmin = -500, vmax = 1000,
            value = customDiff.initResBonus,
            fmtFn = function(v)
                if v > 0 then return string.format("+%d", v)
                elseif v < 0 then return string.format("%d", v)
                else return "标准" end
            end,
            labelX = labelX,
        },
        {
            name  = "maxThreat",
            label = "最大威胁",
            x = trackX, y = p.y + 84, w = trackW, h = trackH,
            vmin = 1, vmax = 8,
            value = customDiff.maxThreat,
            fmtFn = function(v) return string.format("Lv%d", math.floor(v)) end,
            labelX = labelX,
        },
    }
end
