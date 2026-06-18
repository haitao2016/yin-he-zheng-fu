-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function GameUI.RefreshPlanetPanel(planet)
    -- M1: 切换星球时重置面板状态，清除 planetBuildPending_ 残留
    -- L3: 同时重置 TechPanel 滚动位置，避免跨星球残留
    if planet ~= selectedPlanet_ then
        PlanetPanel.ResetScroll()
        TechPanel.ResetScroll()
    end
    selectedPlanet_ = planet
end
