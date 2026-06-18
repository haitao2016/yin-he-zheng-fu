-- Auto-split from TechPanel.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


-- ============================================================================
-- 科技树节点布局（预计算，避免每帧重算）
-- ============================================================================
-- 每 Tier 的科技 id 列表（P1-3: Tier3 新增 VOID_ANCHOR，Tier4 新增 STELLAR_SYNC）
local TIER_NODES = {
    { "DEEP_MINING", "SOLAR_EFFICIENCY", "CRYSTAL_PROCESS", "HULL_ALLOY" },                        -- Tier1
    { "SHIELD_REINFORCE", "RAPID_REFINE", "COLONY_BIOTECH", "NANO_REPAIR" },                        -- Tier2
    { "WARP_DRIVE", "ADVANCED_WEAPONS", "DEFENSE_MATRIX", "VOID_ANCHOR" },                         -- Tier3 P1-3
    { "QUANTUM_CORE", "PHASE_DRIVE", "NOVA_CANNON", "FORTRESS_PROTOCOL", "STELLAR_SYNC" },         -- Tier4 P1-3
}

-- P1-1: 扩大间距，避免节点重叠导致连线不可见
local NODE_W    = 56    -- 节点宽
local NODE_H    = 28    -- 节点高
local TIER_GAP  = 76    -- 列间距（保留足够连线空间：76-56=20px gap）
local ROW_GAP   = 38    -- 行间距（节点高28 + 间距10）
local CONTENT_X = 12    -- 内容起始 X（相对面板）
local HEADER_H  = 18    -- Tier 标签行高
-- P1-3: 最大单列节点数（Tier4 有5个节点），用于居中计算和面板高
local MAX_ROW   = 5

-- P1-1: 每 Tier 的颜色主题 {r, g, b}
local TIER_COLORS = {
    { 80, 160, 255 },   -- Tier1: 蓝
    { 80, 220, 140 },   -- Tier2: 绿
    { 220, 160, 60 },   -- Tier3: 橙
    { 200, 80,  255 },  -- Tier4: 紫
}

-- P1-1: Tier 标签文字
local TIER_LABELS = { "基础", "中级", "高级", "顶级" }

-- 计算各节点的相对坐标（相对于内容区 y=0）
local NODE_POS = {}  -- id → {rx, ry, tier}
for tier, ids in ipairs(TIER_NODES) do
    local col_x = CONTENT_X + (tier - 1) * TIER_GAP
    local n     = #ids
    -- P1-3: 纵向居中排列（以 MAX_ROW 行为基准，支持 Tier4 的 5 节点）
    local totalRowH = n * NODE_H + (n - 1) * (ROW_GAP - NODE_H)
    local startY    = (MAX_ROW * ROW_GAP - totalRowH) / 2
    for i, id in ipairs(ids) do
        NODE_POS[id] = {
            rx   = col_x,
            ry   = startY + (i - 1) * ROW_GAP,
            tier = tier,
        }
    end
end

-- P1-3: 内容总高（标签行 + 节点行，基于 MAX_ROW=5）
local CONTENT_H = HEADER_H + MAX_ROW * ROW_GAP + 8

-- 面板宽（4 列 + 右边距）
local PW = CONTENT_X + 4 * TIER_GAP + 18

-- ============================================================================
-- P3-2 辅助函数
-- ============================================================================

--- 查找以 id 为前置的所有下游科技
local DOWNSTREAM_CACHE = {}  -- id → { id1, id2, ... }
