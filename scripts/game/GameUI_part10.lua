-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function GameUI.ForceRefreshPanel(planet)
    -- 先置 nil 再赋值，确保渲染函数检测到"切换"并重新读取数据
    selectedPlanet_ = nil
    selectedPlanet_ = planet
end
