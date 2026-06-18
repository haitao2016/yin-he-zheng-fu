-- Auto-split from BattleScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function BattleScene.AddProductionShip(shipType)
    pendingShips_[#pendingShips_+1] = shipType
end
