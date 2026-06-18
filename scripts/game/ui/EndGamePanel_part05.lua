-- Auto-split from EndGamePanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


-- ── P3-2: 6维度雷达图 ────────────────────────────────────────────────────────
--- 绘制6轴六边形雷达图
---@param vg      userdata  NanoVG context
---@param cx      number    中心 x
---@param cy      number    中心 y
---@param radius  number    最大半径（像素）
---@param dims    table     { {label, value (0-1)} … } 顺时针6个维度
---@param ease    number    动画进度 0-1
