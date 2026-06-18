-- Auto-split from DiplomacySystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


--- 随机为未殖民星球分配中立势力标签（开局时调用）
---@param allPlanets table  GalaxyScene.GetAllPlanets() 结果
---@param ratio      number  0-1，随机标记比例（默认 0.35）
