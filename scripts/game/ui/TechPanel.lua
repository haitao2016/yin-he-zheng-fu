-- ============================================================================
-- game/ui/TechPanel.lua  -- 科技树可视化面板（节点图，按 Tier 分层展示）
-- P1-1 重构：节点间距扩大、贝塞尔连线、Tier 颜色分组、状态色规范
-- P3-2 可视化2.0：互斥组虚线框+二选一、有向箭头连线、Hover浮窗、推荐路线
-- ============================================================================
local UICommon  = require("game.ui.UICommon")
local TechPanel = {}

-- 面板私有状态
local scrollY_    = 0
local collapsed_  = false
local selectedId_ = nil   -- 当前选中的科技节点 id
local hoveredId_  = nil   -- P3-2: 鼠标悬浮的科技节点 id

--- 外部重置滚动（换星球时调用）
function TechPanel.ResetScroll()
    scrollY_    = 0
    selectedId_ = nil
end

-- ============================================================================
-- 科技树节点布局（预计算，避免每帧重算）
-- ============================================================================
-- 每 Tier 的科技 id 列表（P1-3: Tier3 新增 VOID_ANCHOR，Tier4 新增 STELLAR_SYNC，P2-6: Tier5 新增 6 个高阶科技）
local TIER_NODES = {
    { "DEEP_MINING", "SOLAR_EFFICIENCY", "CRYSTAL_PROCESS", "HULL_ALLOY" },                        -- Tier1 基础
    { "SHIELD_REINFORCE", "RAPID_REFINE", "COLONY_BIOTECH", "NANO_REPAIR" },                        -- Tier2 中级
    { "WARP_DRIVE", "ADVANCED_WEAPONS", "DEFENSE_MATRIX", "VOID_ANCHOR" },                         -- Tier3 高级
    { "QUANTUM_CORE", "NOVA_CANNON", "FORTRESS_PROTOCOL", "STELLAR_SYNC", "PHASE_DRIVE" },         -- Tier4 顶级（双路线）
    { "STELLAR_ENGINE", "QUANTUM_FACTORY", "VOID_FLEET", "FORTRESS_PROTOCOL_II", "CHRONO_RESEARCH", "GALACTIC_ASCEND" }, -- Tier5 终极
}

-- P1-1: 扩大间距，避免节点重叠导致连线不可见
local NODE_W    = 56    -- 节点宽
local NODE_H    = 28    -- 节点高
local TIER_GAP  = 76    -- 列间距（保留足够连线空间：76-56=20px gap）
local ROW_GAP   = 38    -- 行间距（节点高28 + 间距10）
local CONTENT_X = 12    -- 内容起始 X（相对面板）
local HEADER_H  = 18    -- Tier 标签行高
-- P1-3: 最大单列节点数（Tier5 有6个节点），用于居中计算和面板高
local MAX_ROW   = 6

-- P1-1: 每 Tier 的颜色主题 {r, g, b}
local TIER_COLORS = {
    { 80, 160, 255 },   -- Tier1: 蓝
    { 80, 220, 140 },   -- Tier2: 绿
    { 220, 160, 60 },   -- Tier3: 橙
    { 200, 80,  255 },  -- Tier4: 紫
    { 255, 200, 80  },  -- Tier5: 金（P2-6）
}

-- P1-1: Tier 标签文字
local TIER_LABELS = { "基础", "中级", "高级", "顶级", "终极" }

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
local function getDownstream(id)
    if DOWNSTREAM_CACHE[id] then return DOWNSTREAM_CACHE[id] end
    local result = {}
    for _, otherId in ipairs(TECH_ORDER) do
        local t = TECHS[otherId]
        if t then
            for _, pre in ipairs(t.prereqs) do
                if pre == id then result[#result + 1] = otherId; break end
            end
        end
    end
    DOWNSTREAM_CACHE[id] = result
    return result
end

--- 查找同 exclusiveGroup 的互斥伙伴
local function getExclusivePeers(id)
    local t = TECHS[id]
    if not t or not t.exclusiveGroup then return {} end
    local peers = {}
    for _, otherId in ipairs(TECH_ORDER) do
        if otherId ~= id and TECHS[otherId] and TECHS[otherId].exclusiveGroup == t.exclusiveGroup then
            peers[#peers + 1] = otherId
        end
    end
    return peers
end

--- P3-2: 推荐研究路线（基于当前状态选最优下一步路径）
--- 返回 { id1, id2, ... } 有序推荐列表（从当前可研究节点沿最有价值路径）
local function computeRecommendedPath(rs)
    local path = {}
    -- 找所有当前可研究的节点
    local candidates = {}
    for _, id in ipairs(TECH_ORDER) do
        if not rs.unlocked[id] and rs:canResearch(id) then
            candidates[#candidates + 1] = id
        end
    end
    if #candidates == 0 then return path end
    -- 简单启发：选 Tier 最高优先、解锁下游最多优先
    local best = candidates[1]
    local bestScore = -1
    for _, id in ipairs(candidates) do
        local pos = NODE_POS[id]
        local tier = pos and pos.tier or 1
        local ds = #getDownstream(id)
        local score = tier * 10 + ds * 3
        if score > bestScore then bestScore = score; best = id end
    end
    path[#path + 1] = best
    -- 沿下游扩展（最多3层）
    local cur = best
    for _ = 1, 3 do
        local ds = getDownstream(cur)
        if #ds == 0 then break end
        -- 选未解锁的第一个下游
        local next_ = nil
        for _, did in ipairs(ds) do
            if not rs.unlocked[did] then next_ = did; break end
        end
        if not next_ then break end
        path[#path + 1] = next_
        cur = next_
    end
    return path
end

--- 收集互斥组 → 节点列表映射
local EXCLUSIVE_GROUPS = {}  -- group → { id1, id2, ... }
for _, id in ipairs(TECH_ORDER) do
    local t = TECHS[id]
    if t and t.exclusiveGroup then
        local g = t.exclusiveGroup
        if not EXCLUSIVE_GROUPS[g] then EXCLUSIVE_GROUPS[g] = {} end
        EXCLUSIVE_GROUPS[g][#EXCLUSIVE_GROUPS[g] + 1] = id
    end
end

-- ============================================================================
-- 辅助：绘制一条贝塞尔前置连线（P3-2: +箭头）
-- ============================================================================
local function drawConnection(vg, clrFn, x1, y1, x2, y2, r, g, b, a, showArrow)
    -- 贝塞尔曲线：控制点在两端中间偏 X 方向
    local cx = (x1 + x2) / 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, x1, y1)
    nvgBezierTo(vg, cx, y1, cx, y2, x2, y2)
    nvgStrokeColor(vg, clrFn(r, g, b, a))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
    -- P3-2: 箭头（在终点 x2,y2 处画三角）
    if showArrow ~= false then
        -- 近似切线方向：从控制点2 (cx,y2) 到终点 (x2,y2)
        local dx = x2 - cx
        local dy = y2 - y2  -- = 0 (最后一段几乎水平)
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.01 then dx, dy = 1, 0 else dx, dy = dx / len, dy / len end
        local arrLen = 5
        local arrW   = 3
        -- 箭头尖端 = x2, y2；两翼向后展开
        local bx = x2 - dx * arrLen
        local by = y2 - dy * arrLen
        local perpX, perpY = -dy, dx
        nvgBeginPath(vg)
        nvgMoveTo(vg, x2, y2)
        nvgLineTo(vg, bx + perpX * arrW, by + perpY * arrW)
        nvgLineTo(vg, bx - perpX * arrW, by - perpY * arrW)
        nvgClosePath(vg)
        nvgFillColor(vg, clrFn(r, g, b, a))
        nvgFill(vg)
    end
end

--- 渲染科研面板
--- @param ctx table
---   .selectedPlanet      table    当前选中星球（nil = 无选中）
---   .onResearch          function 点击研究按钮的回调 function(id)
---   .onResearchSpeedAd   function 看广告加速5分钟回调 fn(onResult)，nil=无广告
function TechPanel.Render(ctx)
    -- 每帧重置导出高度
    UICommon.techPanelH = 0

    local vg        = UICommon.vg
    local screenH   = UICommon.screenH
    local rm        = UICommon.rm
    local rs        = UICommon.rs
    local clr       = UICommon.clr
    local panel     = UICommon.panel
    local text      = UICommon.text
    local addHit    = UICommon.addHit
    local addScroll = UICommon.addScroll

    if not rs then return end
    local selectedPlanet    = ctx.selectedPlanet
    local onResearchSpeedAd = ctx.onResearchSpeedAd  -- 广告加速5分钟
    if not selectedPlanet or not selectedPlanet.colonized then return end

    -- P2-6: 从基地行星取 coreLevel（用于 Tier5 科技解锁检查）
    local coreLevel = (selectedPlanet and selectedPlanet.coreLevel)
                     or (selectedPlanet and selectedPlanet.isBase and selectedPlanet.coreLevel)
                     or (UICommon.rm and UICommon.rm.coreLevel)
                     or 1
    -- 同步到 rm，供 ResearchSystem:canResearch 使用
    if UICommon.rm then UICommon.rm.coreLevel = coreLevel end

    -- 仅当星球有科研中心时显示
    local hasLab = false
    if selectedPlanet.buildings then
        for _, b in ipairs(selectedPlanet.buildings) do
            if b.key == "RESEARCH_LAB" or b.key == "RESEARCH_CENTER" then
                hasLab = true; break
            end
        end
    end
    if not hasLab then return end

    local px, py = 12, (UICommon.PANEL_TOP or 48)
    local pw     = PW

    -- 折叠时只显示标题
    if collapsed_ then
        local ph = 24
        UICommon.techPanelH = ph
        panel(px, py, pw, ph, 6, {10,18,38,230}, {60,120,255,200})
        text(px + 10, py + 12, "[ 科技树 ]", 12, 80, 160, 255, 255, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
        text(px + pw - 16, py + 12, "▼", 11, 100, 150, 255, 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        addHit(px, py, pw, ph, function() collapsed_ = false; scrollY_ = 0 end)
        return
    end

    -- 详情卡片高（选中时额外显示）
    local detailH = 0
    if selectedId_ and TECHS[selectedId_] then
        detailH = 60
    end

    -- 当前研究进度条高
    local progressH = rs.active and 24 or 0

    local headerH   = 24
    local totalH    = headerH + progressH + CONTENT_H + detailH + 10
    local maxPanelH = screenH - py - 16
    local ph        = math.min(totalH, maxPanelH)
    UICommon.techPanelH = ph

    local contentAreaH = ph - headerH
    local maxScroll    = math.max(0, totalH - headerH - contentAreaH)
    scrollY_ = math.max(0, math.min(maxScroll, scrollY_))

    panel(px, py, pw, ph, 6, {8, 14, 32, 238}, {60, 120, 255, 200})

    -- ── 标题栏 ──────────────────────────────────────────────────
    local titleY = py + 12
    text(px + 10, titleY, "[ 科技树 ]", 12, 80, 160, 255, 255, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
    text(px + pw - 16, titleY, "▲", 11, 100, 150, 255, 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
    addHit(px, py, pw, headerH, function() collapsed_ = true; scrollY_ = 0 end)

    -- ── 滚动区域 ─────────────────────────────────────────────────
    addScroll(px, py + headerH, pw, contentAreaH, function(delta)
        scrollY_ = scrollY_ - delta * 24
    end)

    local clipY1 = py + headerH
    local clipY2 = py + ph
    nvgSave(vg)
    nvgScissor(vg, px + 1, clipY1, pw - 2, contentAreaH)

    -- 虚拟 Y 起点（滚动后的坐标）
    local baseY = clipY1 - scrollY_

    -- ── 当前研究进度 ─────────────────────────────────────────────
    local vy = baseY + 4
    if rs.active then
        local a    = rs.active
        local pct  = a.progress or 0
        local tech = TECHS[a.id]
        if vy + 22 > clipY1 and vy < clipY2 then
            text(px + 8, vy + 8, "研发中: " .. (tech and tech.name or a.id), 9, 60, 200, 140, 255, NVG_ALIGN_LEFT+NVG_ALIGN_MIDDLE)
            -- 广告按钮存在时压缩进度条宽度，为按钮留出 42px
            local bw2 = onResearchSpeedAd and (pw - 58) or (pw - 16)
            local bx2, by2, bh2 = px + 8, vy + 15, 6
            nvgBeginPath(vg); nvgRoundedRect(vg, bx2, by2, bw2, bh2, 2)
            nvgFillColor(vg, clr(20,40,20,180)); nvgFill(vg)
            if pct > 0 then
                nvgBeginPath(vg); nvgRoundedRect(vg, bx2, by2, bw2 * pct, bh2, 2)
                nvgFillColor(vg, clr(60,200,120,230)); nvgFill(vg)
            end
            -- 百分比标注
            text(bx2 + bw2 / 2, by2 + 3, string.format("%d%%", math.floor(pct * 100)), 7, 100, 220, 140, 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
            -- 广告加速按钮（进度条右侧）
            if onResearchSpeedAd then
                local adBx = px + pw - 46
                local adBy = by2 - 2
                panel(adBx, adBy, 40, 10, 3, {0,60,35,100}, {0,170,90,210})
                text(adBx + 20, adBy + 5, "🎬+5m", 7, 80, 255, 160, 255, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                addHit(adBx, adBy, 40, 10, function()
                    if onResearchSpeedAd then onResearchSpeedAd() end
                end)
            end
        end
        vy = vy + progressH
    end

    -- 节点图基准 Y（含 Tier 标签行）
    local graphBaseY = vy + 4

    -- ── P1-1: Tier 标签（带颜色主题）────────────────────────────
    for tier = 1, #TIER_NODES do
        local tc  = TIER_COLORS[tier]
        local lx  = px + CONTENT_X + (tier - 1) * TIER_GAP + NODE_W / 2
        local ly  = graphBaseY + 8
        if ly > clipY1 - 14 and ly < clipY2 then
            -- Tier 标签底部线
            local lLineX = px + CONTENT_X + (tier - 1) * TIER_GAP
            nvgBeginPath(vg)
            nvgMoveTo(vg, lLineX + 2, ly + 6)
            nvgLineTo(vg, lLineX + NODE_W - 2, ly + 6)
            nvgStrokeColor(vg, clr(tc[1], tc[2], tc[3], 100))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)
            text(lx, ly, "T" .. tier .. " " .. TIER_LABELS[tier], 8, tc[1], tc[2], tc[3], 200, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        end
    end

    -- 节点图真实起始 Y（跳过标签行）
    local nodesBaseY = graphBaseY + HEADER_H

    -- ── 连线（先画，节点在上层）──────────────────────────────────
    nvgSave(vg)
    for _, id in ipairs(TECH_ORDER) do
        local t   = TECHS[id]
        local pos = NODE_POS[id]
        if not pos then goto continue_line end
        -- 目标节点左边缘中心
        local nx  = px + pos.rx
        local ny  = nodesBaseY + pos.ry + NODE_H / 2
        for _, pre in ipairs(t.prereqs) do
            local ppos = NODE_POS[pre]
            if ppos then
                -- 前置节点右边缘中心
                local px2 = px + ppos.rx + NODE_W
                local py2 = nodesBaseY + ppos.ry + NODE_H / 2
                -- P3-2: 连线颜色：绿(前置已解锁)、灰(前置未解锁)、红(互斥锁定)
                local preUnlocked = rs.unlocked[pre]
                local targetExcluded = (not rs.unlocked[id]) and rs.isExcluded and rs:isExcluded(id) or false
                local prePos   = ppos
                local tc       = TIER_COLORS[prePos.tier]
                local r2, g2, b2, a2
                if targetExcluded then
                    r2, g2, b2, a2 = 200, 50, 50, 140  -- 红色：互斥锁定
                elseif preUnlocked then
                    r2, g2, b2, a2 = tc[1], tc[2], tc[3], 160  -- 绿/主题色：前置已解锁
                else
                    r2, g2, b2, a2 = 55, 75, 120, 70   -- 灰色：前置未解锁
                end
                drawConnection(vg, clr, px2, py2, nx, ny, r2, g2, b2, a2)
            end
        end
        ::continue_line::
    end
    nvgRestore(vg)

    -- ── P3-2: 推荐研究路线高亮连线 ──────────────────────────────
    local recPath = computeRecommendedPath(rs)
    local recSet  = {}  -- 推荐路径节点集合（用于节点高亮脉冲）
    for _, rid in ipairs(recPath) do recSet[rid] = true end
    if #recPath >= 2 then
        nvgSave(vg)
        for i = 1, #recPath - 1 do
            local fromId = recPath[i]
            local toId   = recPath[i + 1]
            local fp     = NODE_POS[fromId]
            local tp     = NODE_POS[toId]
            if fp and tp then
                local fx = px + fp.rx + NODE_W
                local fy = nodesBaseY + fp.ry + NODE_H / 2
                local tx = px + tp.rx
                local ty = nodesBaseY + tp.ry + NODE_H / 2
                drawConnection(vg, clr, fx, fy, tx, ty, 255, 215, 50, 140, true)
            end
        end
        nvgRestore(vg)
    end

    -- ── P3-2: 互斥组虚线框 + "二选一" 标签 ──────────────────────
    for groupName, groupIds in pairs(EXCLUSIVE_GROUPS) do
        -- 计算组内节点包围盒
        local minX, minY, maxX, maxY = 9999, 9999, -9999, -9999
        for _, gid in ipairs(groupIds) do
            local gp = NODE_POS[gid]
            if gp then
                local gnx = px + gp.rx
                local gny = nodesBaseY + gp.ry
                if gnx < minX then minX = gnx end
                if gny < minY then minY = gny end
                if gnx + NODE_W > maxX then maxX = gnx + NODE_W end
                if gny + NODE_H > maxY then maxY = gny + NODE_H end
            end
        end
        -- 加 padding
        local pad = 4
        minX = minX - pad; minY = minY - pad
        maxX = maxX + pad;  maxY = maxY + pad
        if maxX > minX and maxY > minY and minY < clipY2 and maxY > clipY1 then
            -- 虚线框（用短段模拟虚线）
            local boxW = maxX - minX
            local boxH = maxY - minY
            nvgBeginPath(vg)
            nvgRoundedRect(vg, minX, minY, boxW, boxH, 4)
            nvgStrokeColor(vg, clr(220, 60, 60, 120))
            nvgStrokeWidth(vg, 1.0)
            -- NanoVG 没有原生虚线，用 lineDash 近似：画一条实线半透明
            nvgStroke(vg)
            -- "二选一" 标签
            text(minX + boxW / 2, minY - 1, "二选一", 7, 220, 80, 80, 200, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        end
    end

    -- ── P3-2: Hover 检测准备 ─────────────────────────────────────
    local cursorX = UICommon.cursorX or 0
    local cursorY = UICommon.cursorY or 0
    hoveredId_ = nil  -- 每帧重置

    -- ── 节点 ─────────────────────────────────────────────────────
    for _, id in ipairs(TECH_ORDER) do
        local t       = TECHS[id]
        local pos     = NODE_POS[id]
        if not pos then goto continue_node end

        local nx      = px + pos.rx
        local ny      = nodesBaseY + pos.ry
        if ny + NODE_H < clipY1 or ny > clipY2 then goto continue_node end

        local unlocked  = rs.unlocked[id]
        local active    = rs.active and rs.active.id == id
        local canRes    = rs:canResearch(id)
        local isSel     = selectedId_ == id
        local tc        = TIER_COLORS[pos.tier]
        -- P1-1: 互斥锁定状态
        local isExcluded = (not unlocked) and rs.isExcluded and rs:isExcluded(id) or false
        -- P2-6: 核心等级不足锁定状态
        local isCoreLocked = (not unlocked) and t.coreLevelReq and (coreLevel < t.coreLevelReq)

        -- P1-1 状态色规范：
        --   已解锁 → 绿色背景
        --   研发中 → 蓝色背景
        --   可解锁 → 白色/亮色（plan 要求）
        --   互斥封锁 → 深红背景
        --   核心等级不足 → 深灰背景，🔒 锁
        --   未满足前置 → 暗灰
        local nr, ng, nb, na
        if unlocked then
            nr, ng, nb, na = 18, 72, 38, 230
        elseif active then
            nr, ng, nb, na = 18, 52, 110, 230
        elseif isExcluded then
            nr, ng, nb, na = 60, 15, 18, 210   -- 深红底（互斥锁定）
        elseif isCoreLocked then
            nr, ng, nb, na = 25, 25, 50, 200    -- 深灰底（核心等级不足）
        elseif canRes then
            nr, ng, nb, na = 60, 65, 80, 240   -- 亮白底
        else
            nr, ng, nb, na = 18, 22, 44, 185
        end

        -- 边框色：选中→金色，其余按 Tier 主题色（强度随状态调整）
        local br, bg, bb, ba
        if isSel then
            br, bg, bb, ba = 255, 215, 50, 255
        elseif unlocked then
            br, bg, bb, ba = 38, 195, 95, 230
        elseif active then
            br, bg, bb, ba = 50, 150, 255, 230
        elseif isExcluded then
            br, bg, bb, ba = 200, 40, 40, 200   -- 暗红边框（互斥锁定）
        elseif isCoreLocked then
            br, bg, bb, ba = 120, 110, 140, 180  -- 暗灰边框（核心等级不足）
        elseif canRes then
            -- P1-1: 可解锁用 Tier 主题色高亮边框
            br, bg, bb, ba = tc[1], tc[2], tc[3], 220
        else
            br, bg, bb, ba = 55, 70, 130, 100
        end

        -- 节点矩形
        nvgBeginPath(vg)
        nvgRoundedRect(vg, nx, ny, NODE_W, NODE_H, 4)
        nvgFillColor(vg, clr(nr, ng, nb, na)); nvgFill(vg)
        nvgStrokeColor(vg, clr(br, bg, bb, ba)); nvgStrokeWidth(vg, isSel and 2 or 1.2); nvgStroke(vg)

        -- P1-1: 互斥锁定节点 — 右上角锁图标
        if isExcluded then
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
            nvgFillColor(vg, clr(220, 60, 60, 210))
            nvgText(vg, nx + NODE_W - 1, ny + 1, "🔒")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
        -- P2-6: 核心等级不足 — 左上角 🔒 图标
        if isCoreLocked then
            nvgFontFace(vg, "sans"); nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, clr(200, 180, 80, 210))
            nvgText(vg, nx + 1, ny + 1, "🔒")
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        end
        -- P1-1: 可解锁节点加一个微弱的 Tier 色光晕
        if canRes and not unlocked and not active then
            nvgBeginPath(vg)
            nvgRoundedRect(vg, nx - 1, ny - 1, NODE_W + 2, NODE_H + 2, 5)
            nvgStrokeColor(vg, clr(tc[1], tc[2], tc[3], 55))
            nvgStrokeWidth(vg, 3); nvgStroke(vg)
        end
        -- P3-2: 可研究节点蓝色高亮脉冲
        if canRes and not unlocked and not active then
            local pulse = math.abs(math.sin((os.clock() or 0) * 2.5)) * 60 + 40
            nvgBeginPath(vg)
            nvgRoundedRect(vg, nx - 2, ny - 2, NODE_W + 4, NODE_H + 4, 6)
            nvgStrokeColor(vg, clr(80, 160, 255, math.floor(pulse)))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end
        -- P3-2: 推荐路线节点金色光晕
        if recSet[id] then
            local glow = math.abs(math.sin((os.clock() or 0) * 2.0 + 1.0)) * 50 + 30
            nvgBeginPath(vg)
            nvgRoundedRect(vg, nx - 2, ny - 2, NODE_W + 4, NODE_H + 4, 6)
            nvgStrokeColor(vg, clr(255, 215, 50, math.floor(glow)))
            nvgStrokeWidth(vg, 2); nvgStroke(vg)
        end

        -- P3-2: Hover 检测
        if cursorX >= nx and cursorX <= nx + NODE_W and cursorY >= ny and cursorY <= ny + NODE_H then
            hoveredId_ = id
        end

        -- 节点文字
        local nameR, nameG, nameB, nameA
        if unlocked then
            nameR, nameG, nameB, nameA = 100, 225, 130, 220
        elseif active then
            nameR, nameG, nameB, nameA = 80, 170, 255, 230
        elseif canRes then
            nameR, nameG, nameB, nameA = 230, 235, 245, 250  -- 亮白
        else
            nameR, nameG, nameB, nameA = 120, 135, 170, 180
        end

        -- P2-6: 节点名称（根据核心等级要求标注）
        local displayName = t.name
        if t.coreLevelReq then
            displayName = displayName .. " [核心Lv." .. t.coreLevelReq .. "]"
        end

        -- 状态符号（右下角）
        local stateSym
        if unlocked then
            stateSym = "✓"
        elseif active then
            stateSym = "▶"
        elseif isExcluded then
            stateSym = "✗"   -- P1-1: 互斥锁定
        elseif isCoreLocked then
            stateSym = "✗"   -- P2-6: 核心等级不足
        elseif canRes then
            stateSym = "●"
        else
            stateSym = "○"
        end
        local symR, symG, symB
        if unlocked then
            symR, symG, symB = 50, 210, 90
        elseif active then
            symR, symG, symB = 60, 180, 255
        elseif isExcluded then
            symR, symG, symB = 210, 55, 55   -- P1-1: 红色叉
        elseif isCoreLocked then
            symR, symG, symB = 200, 180, 80  -- P2-6: 金色锁
        elseif canRes then
            symR, symG, symB = tc[1], tc[2], tc[3]
        else
            symR, symG, symB = 70, 80, 120
        end

        text(nx + NODE_W / 2, ny + 11, displayName, 8, nameR, nameG, nameB, nameA, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        text(nx + NODE_W - 6, ny + NODE_H - 5, stateSym, 7, symR, symG, symB, 220, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)

        -- P1-2: 科技完成粒子特效
        local eff = ctx.techCompleteEffects and ctx.techCompleteEffects[id]
        if eff then
            local T     = eff.timer        -- 已过时间 (0 → TECH_EFFECT_DURATION)
            local DUR   = 2.2              -- 同 TECH_EFFECT_DURATION
            local cx    = nx + NODE_W / 2
            local cy    = ny + NODE_H / 2

            -- 节点 Tier 主题色
            local tc2   = TIER_COLORS[pos.tier]
            local er, eg, eb = tc2[1], tc2[2], tc2[3]

            -- ① 节点内部白色闪光覆盖（前0.3s）
            if T < 0.3 then
                local flashA = math.floor((1 - T / 0.3) * 180)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, NODE_W, NODE_H, 4)
                nvgFillColor(vg, clr(220, 240, 255, flashA))
                nvgFill(vg)
            end

            -- ② 扩散光环（前1.5s）
            if T < 1.5 then
                local ringT  = T / 1.5     -- 0→1
                local ringR  = ringT * 28  -- 半径 0→28px
                local ringA  = math.floor((1 - ringT) * 180)
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, ringR)
                nvgStrokeColor(vg, clr(er, eg, eb, ringA))
                nvgStrokeWidth(vg, 1.5)
                nvgStroke(vg)
                -- 第二道略大的环（延迟0.2s）
                if T > 0.2 then
                    local ringT2 = (T - 0.2) / 1.5
                    local ringR2 = ringT2 * 36
                    local ringA2 = math.floor((1 - ringT2) * 120)
                    nvgBeginPath(vg)
                    nvgCircle(vg, cx, cy, ringR2)
                    nvgStrokeColor(vg, clr(er, eg, eb, ringA2))
                    nvgStrokeWidth(vg, 1.0)
                    nvgStroke(vg)
                end
            end

            -- ③ 放射状光点（12颗，均匀分布）
            local PARTS = 12
            for pi = 1, PARTS do
                local angle = (pi - 1) * (math.pi * 2 / PARTS)
                -- 慢出缓动：距离在前1.8s内扩散到最大
                local distT  = math.min(T / 1.8, 1.0)
                local eased  = 1 - (1 - distT) * (1 - distT)   -- ease-out quad
                local dist   = eased * 32
                -- 透明度：前0.15s淡入，后半程淡出
                local alpha
                if T < 0.15 then
                    alpha = math.floor(T / 0.15 * 200)
                else
                    alpha = math.floor((1 - math.min((T - 0.15) / (DUR - 0.15), 1.0)) * 200)
                end
                local px2 = cx + math.cos(angle) * dist
                local py2 = cy + math.sin(angle) * dist
                -- 交替大小光点
                local pr = (pi % 3 == 0) and 2.5 or 1.8
                nvgBeginPath(vg)
                nvgCircle(vg, px2, py2, pr)
                nvgFillColor(vg, clr(er, eg, eb, alpha))
                nvgFill(vg)
            end

            -- ④ 中心星光（前0.6s，4射线）
            if T < 0.6 then
                local starA = math.floor((1 - T / 0.6) * 220)
                local starL = (1 - T / 0.6) * 12
                nvgStrokeColor(vg, clr(er, eg, eb, starA))
                nvgStrokeWidth(vg, 1.2)
                for si = 0, 3 do
                    local sa = si * math.pi / 2
                    nvgBeginPath(vg)
                    nvgMoveTo(vg, cx, cy)
                    nvgLineTo(vg, cx + math.cos(sa) * starL, cy + math.sin(sa) * starL)
                    nvgStroke(vg)
                end
            end
        end

        -- 点击选中
        local capturedId = id
        addHit(nx, ny, NODE_W, NODE_H, function()
            selectedId_ = (selectedId_ == capturedId) and nil or capturedId
        end)

        ::continue_node::
    end

    -- ── 选中科技的详情卡片 ────────────────────────────────────────
    if selectedId_ and TECHS[selectedId_] then
        local t     = TECHS[selectedId_]
        local selTc = NODE_POS[selectedId_] and TIER_COLORS[NODE_POS[selectedId_].tier] or {80,160,255}
        local dvy   = nodesBaseY + MAX_ROW * ROW_GAP + 2
        if dvy < clipY2 and dvy + detailH > clipY1 then
            -- 分隔线（Tier 主题色）
            nvgBeginPath(vg)
            nvgMoveTo(vg, px + 8, dvy)
            nvgLineTo(vg, px + pw - 8, dvy)
            nvgStrokeColor(vg, clr(selTc[1], selTc[2], selTc[3], 80))
            nvgStrokeWidth(vg, 1); nvgStroke(vg)

            local dy = dvy + 6
            -- 科技名 + 描述（P2-6: 标题附加核心等级要求）
            local titleText = t.name
            if t.coreLevelReq then
                titleText = titleText .. "  [需核心Lv." .. t.coreLevelReq .. "]"
            end
            text(px + 8,  dy,      titleText, 11, selTc[1], selTc[2], selTc[3], 255)
            text(px + 8,  dy + 14, t.desc, 9,  150, 165, 200, 220)

            -- P1-1: 费用行（含 credits）
            local rx = px + 8
            local ry = dy + 28
            -- 精炼资源费用
            for _, res in ipairs(RES_ORDER) do
                local need = t.cost[res] or 0
                if need > 0 then
                    local have   = rm.resources[res] or 0
                    local enough = have >= need
                    local cr, cg, cb = enough and 80 or 255, enough and 220 or 90, enough and 100 or 60
                    local lbl = (RES_LABELS[res] or res) .. ":" .. math.floor(have) .. "/" .. need
                    text(rx, ry, lbl, 8, cr, cg, cb, 230)
                    rx = rx + #lbl * 5.2 + 6
                end
            end
            -- credits 费用（P1-1: 补充显示）
            if (t.cost.credits or 0) > 0 then
                local have   = rm.resources.credits or 0
                local need   = t.cost.credits
                local enough = have >= need
                local cr, cg, cb = enough and 80 or 255, enough and 220 or 90, enough and 100 or 60
                local lbl = "点数:" .. math.floor(have) .. "/" .. need
                text(rx, ry, lbl, 8, cr, cg, cb, 230)
            end

            -- 研究按钮 / 状态提示
            local canRes = rs:canResearch(selectedId_)
            if canRes then
                local capturedId = selectedId_
                local bx3, by3, bw3, bh3 = px + pw - 74, dvy + 42, 70, 16
                if by3 > clipY1 - bh3 and by3 < clipY2 then
                    panel(bx3, by3, bw3, bh3, 4, {selTc[1], selTc[2], selTc[3], 50}, {selTc[1], selTc[2], selTc[3], 180})
                    text(bx3 + bw3 / 2, by3 + bh3 / 2, "开始研究", 9, selTc[1], selTc[2], selTc[3], 240, NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
                    addHit(bx3, by3, bw3, bh3, function()
                        if ctx.onResearch then ctx.onResearch(capturedId) end
                        selectedId_ = nil
                    end)
                end
            elseif rs.unlocked[selectedId_] then
                text(px + pw - 52, dvy + 48, "✓ 已解锁", 9, 50, 200, 100, 200)
                -- P1-3: 专精路线标签（当选中互斥科技且已选定时）
                local eg = t.exclusiveGroup
                if eg then
                    -- 在同组中找互斥伙伴（同组另一个未解锁 = 已选此路线）
                    local hasForkPartner = false
                    for otherId, otherT in pairs(TECHS) do
                        if otherId ~= selectedId_ and otherT.exclusiveGroup == eg
                           and not rs.unlocked[otherId] then
                            hasForkPartner = true; break
                        end
                    end
                    if hasForkPartner then
                        text(px + 8, dvy + 42, "⚡ 已选专精路线", 9, 255, 200, 60, 230)
                    end
                end
            -- P1-1: 互斥锁定提示（优先于其他状态）
            elseif rs.isExcluded and rs:isExcluded(selectedId_) then
                text(px + 8, dvy + 42, "❌ 被互斥", 9, 200, 60, 60, 230)
                text(px + 8, dvy + 53, "同级已研究另一分支，此科技永久封锁", 7, 160, 80, 80, 190)
            -- P2-6: 核心等级不足提示
            elseif t.coreLevelReq and coreLevel < t.coreLevelReq then
                text(px + 8, dvy + 42, "🔒 核心Lv." .. t.coreLevelReq .. "（当前Lv." .. coreLevel .. "）", 9, 220, 180, 80, 230)
                text(px + 8, dvy + 53, "升级基地核心至 Lv." .. t.coreLevelReq .. " 后解锁", 7, 180, 150, 100, 190)
            elseif rs.active and rs.active.id == selectedId_ then
                local pct = rs.active.progress or 0
                text(px + pw - 64, dvy + 48, string.format("▶ 研发中 %d%%", math.floor(pct * 100)), 9, 60, 160, 255, 200)
            else
                -- 显示缺少的前置
                local missing = {}
                for _, pre in ipairs(t.prereqs) do
                    if not rs.unlocked[pre] then
                        missing[#missing + 1] = TECHS[pre] and TECHS[pre].name or pre
                    end
                end
                if #missing > 0 then
                    text(px + 8, dvy + 48, "需要: " .. table.concat(missing, "、"), 8, 200, 130, 60, 200)
                end
            end
        end
    end

    nvgRestore(vg)

    -- ── P3-2: Hover 浮窗（剪切区外渲染，避免被裁剪）────────────
    if hoveredId_ and TECHS[hoveredId_] and hoveredId_ ~= selectedId_ then
        local ht     = TECHS[hoveredId_]
        local hpos   = NODE_POS[hoveredId_]
        local htc    = hpos and TIER_COLORS[hpos.tier] or {80,160,255}

        -- 浮窗定位：节点右侧偏移
        local tipX   = px + (hpos and hpos.rx or 0) + NODE_W + 6
        local tipY   = py + headerH + 4
        -- 如果超出面板右边则放左侧
        if tipX + 120 > px + pw then
            tipX = px + (hpos and hpos.rx or 0) - 126
        end

        -- 内容行（效果描述、前置、互斥、核心等级、下游）
        local lines = {}
        lines[#lines + 1] = { label = "效果", value = ht.desc }
        -- 前置科技
        if #ht.prereqs > 0 then
            local names = {}
            for _, pre in ipairs(ht.prereqs) do
                names[#names + 1] = TECHS[pre] and TECHS[pre].name or pre
            end
            lines[#lines + 1] = { label = "前置", value = table.concat(names, "、") }
        end
        -- 互斥科技
        local exPeers = getExclusivePeers(hoveredId_)
        if #exPeers > 0 then
            local names = {}
            for _, eid in ipairs(exPeers) do
                names[#names + 1] = TECHS[eid] and TECHS[eid].name or eid
            end
            lines[#lines + 1] = { label = "互斥", value = table.concat(names, "、"), red = true }
        end
        -- P2-6: 核心等级需求
        if ht.coreLevelReq then
            local ok = coreLevel >= ht.coreLevelReq
            lines[#lines + 1] = {
                label = "核心",
                value = "Lv." .. ht.coreLevelReq .. "（当前Lv." .. coreLevel .. (ok and " ✓" or " ✗") .. "）",
                yellow = not ok,
                red = false,
            }
        end
        -- 下游科技链
        local ds = getDownstream(hoveredId_)
        if #ds > 0 then
            local names = {}
            for _, did in ipairs(ds) do
                names[#names + 1] = TECHS[did] and TECHS[did].name or did
            end
            lines[#lines + 1] = { label = "解锁", value = table.concat(names, "→") }
        end

        local tipW = 130
        local tipH = 14 + #lines * 12
        -- 确保不超出屏幕底部
        if tipY + tipH > screenH - 8 then tipY = screenH - 8 - tipH end

        -- 浮窗背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, tipX, tipY, tipW, tipH, 4)
        nvgFillColor(vg, clr(6, 12, 28, 240))
        nvgFill(vg)
        nvgStrokeColor(vg, clr(htc[1], htc[2], htc[3], 160))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        -- 标题
        text(tipX + 4, tipY + 8, ht.name, 9, htc[1], htc[2], htc[3], 255, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        -- 内容行
        local ly = tipY + 18
        for _, line in ipairs(lines) do
            local lr, lg, lb = 140, 160, 200
            if line.red  then lr, lg, lb = 220, 80, 80 end
            if line.yellow then lr, lg, lb = 230, 190, 80 end
            text(tipX + 4, ly, line.label .. ": " .. line.value, 7, lr, lg, lb, 220, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            ly = ly + 12
        end
    end

    -- ── P3-2: 面板底部推荐路线文字提示 ───────────────────────────
    if #recPath > 0 then
        local recNames = {}
        for _, rid in ipairs(recPath) do
            recNames[#recNames + 1] = TECHS[rid] and TECHS[rid].name or rid
        end
        local recText = "推荐: " .. table.concat(recNames, " → ")
        text(px + 8, py + ph - 6, recText, 7, 255, 215, 50, 180, NVG_ALIGN_LEFT + NVG_ALIGN_BOTTOM)
    end

    -- ── 滚动条 ───────────────────────────────────────────────────
    if maxScroll > 0 then
        local sbH = math.max(16, contentAreaH * contentAreaH / (totalH - headerH + 1))
        local sbY = clipY1 + (contentAreaH - sbH) * (scrollY_ / maxScroll)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, px + pw - 4, sbY, 3, sbH, 1.5)
        nvgFillColor(vg, nvgRGBA(100, 150, 255, 140))
        nvgFill(vg)
    end
end

return TechPanel
