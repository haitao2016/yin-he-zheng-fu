-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


-- ============================================================================
-- P1-1: 传承树面板（主菜单层）
-- ============================================================================

-- 路线元数据
local LINE_META = {
    military = { label="⚔ 军事路线", color={255, 120, 80} },
    economy  = { label="⛏ 经济路线", color={80, 200, 120} },
    science  = { label="🔬 科研路线", color={100, 160, 255} },
}
local LINE_ORDER = { "military", "economy", "science" }

--- 计算节点格子布局（每条路线4个节点，水平排列）
--- 返回 { { nodeId, x, y, w, h }, ... }
