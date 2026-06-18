-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    local btnW, btnH = 240, 56
    local cx = sw / 2 - btnW / 2
    local baseY = sh * 0.52
    -- P1-1: 传承按钮 / P2-1: 每日挑战按钮 / P2-2: 战役按钮（均较小，位于两个主按钮之下）
    local smW, smH = 198, 40
    local gap      = 6
    local totalSmW = smW * 4 + gap * 3  -- P1-3: 4 buttons row (campaign/daily/heritage/league)
    local smStartX = sw / 2 - totalSmW / 2
    return {
        { key="new",      x=cx,             y=baseY,       w=btnW, h=btnH, label="新  游  戏", enabled=true },
        { key="continue", x=cx,             y=baseY + 72,  w=btnW, h=btnH, label="继 续 游 戏", enabled=hasSave },
        { key="campaign", x=smStartX,                      y=baseY + 152, w=smW, h=smH, label="⚔  银河战役", enabled=true },
        { key="daily",    x=smStartX+smW+gap,              y=baseY + 152, w=smW, h=smH, label="📅 每日挑战", enabled=true },
        { key="heritage", x=smStartX+(smW+gap)*2,          y=baseY + 152, w=smW, h=smH, label="★  星际传承", enabled=true },
        { key="league",   x=smStartX+(smW+gap)*3,          y=baseY + 152, w=smW, h=smH, label="🏆 星际联赛", enabled=true },
    }
end
