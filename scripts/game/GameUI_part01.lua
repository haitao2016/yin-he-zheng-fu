-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function GameUI.Notify(msg, ntype)
    Audio.PlayNotify(ntype)
    NotifyPanel.Push(msg, ntype)
end
