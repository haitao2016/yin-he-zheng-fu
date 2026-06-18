-- Auto-split from AchievementSystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


-- ─── 触发检查 ─────────────────────────────────────────────────────────────────
--- 外部调用：某个事件发生时，传入 eventName 和游戏状态快照 state
---@param eventName string  事件名（colonize/pirate_kill/ship_built/research_complete/resource_milestone/victory）
---@param state     table   游戏状态快照
