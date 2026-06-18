-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetDifficultyBtnLayout(sw, sh, ctx)
    local DIFF_ORDER          = ctx.DIFF_ORDER
    local DIFFICULTY_CONFIGS  = ctx.DIFFICULTY_CONFIGS
    local btnW, btnH = 165, 110
    local gap        = 16
    local totalW     = btnW * 4 + gap * 3
    local startX     = (sw - totalW) / 2
    local btnY       = sh * 0.46
    local result     = {}
    for i, key in ipairs(DIFF_ORDER) do
        result[i] = {
            key = key,
            x   = startX + (i - 1) * (btnW + gap),
            y   = btnY,
            w   = btnW,
            h   = btnH,
            cfg = DIFFICULTY_CONFIGS[key],
        }
    end
    return result
end
