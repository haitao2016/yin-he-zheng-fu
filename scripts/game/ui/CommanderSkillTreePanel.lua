---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/CommanderSkillTreePanel.lua -- 指挥官技能树面板
-- V3.3 M2
-- ============================================================================

local CommanderSkillTreePanel = {}

local panel = nil
local playerStateRef = nil

-- 3 分支配置（攻击/防御/辅助）
local BRANCHES = {
    ATTACK  = { name = "攻击", color = { 240, 120, 90 },  desc = "提升舰队火力与暴击" },
    DEFENSE = { name = "防御", color = { 100, 170, 230 }, desc = "提升装甲与护盾强度" },
    SUPPORT = { name = "辅助", color = { 170, 230, 130 }, desc = "提升支援与协同能力" },
}

-- 节点模板：每个分支 4 层（Tier 1-4）
local BRANCH_NODES = {
    ATTACK = {
        { id = "ATTACK_1", name = "快速装填",  cost = 1, tier = 1, desc = "主武器装填速度 +8%" },
        { id = "ATTACK_2", name = "精准瞄准",  cost = 2, tier = 2, desc = "命中率 +5%，暴击率 +3%" },
        { id = "ATTACK_3", name = "重型弹药",  cost = 3, tier = 3, desc = "火炮伤害 +12%，穿透 +6" },
        { id = "ATTACK_4", name = "火力集中",  cost = 5, tier = 4, desc = "全武器伤害 +20%，暴击伤害 +35%" },
    },
    DEFENSE = {
        { id = "DEFENSE_1", name = "强化装甲",  cost = 1, tier = 1, desc = "舰体装甲值 +150" },
        { id = "DEFENSE_2", name = "能量护盾",  cost = 2, tier = 2, desc = "护盾容量 +250，恢复 +3/秒" },
        { id = "DEFENSE_3", name = "主动防御",  cost = 3, tier = 3, desc = "受到攻击时有 15% 几率免疫伤害" },
        { id = "DEFENSE_4", name = "坚不可摧",  cost = 5, tier = 4, desc = "承伤减少 18%，生命值上限 +25%" },
    },
    SUPPORT = {
        { id = "SUPPORT_1", name = "战术协调",  cost = 1, tier = 1, desc = "队友伤害加成 +3%" },
        { id = "SUPPORT_2", name = "补给链",    cost = 2, tier = 2, desc = "战斗内资源恢复 +10%" },
        { id = "SUPPORT_3", name = "战场指挥",  cost = 3, tier = 3, desc = "指挥值 +15，释放技能消耗 -10%" },
        { id = "SUPPORT_4", name = "战略大师",  cost = 5, tier = 4, desc = "所有队友属性 +8%，协同能力 +25%" },
    },
}

---打开技能树面板
---@param playerState table
---@return table
function CommanderSkillTreePanel.open(playerState)
    playerStateRef = playerState
    panel = {
        visible = true,
        w = 640,
        h = 500,
        currentCommanderId = nil,
        commanders = CommanderSkillTreePanel.getCommanderList(),
        selectedNodeId = nil,
        tab = "TREE",
    }
    if #panel.commanders > 0 then
        panel.currentCommanderId = panel.commanders[1].id
    end
    return panel
end

---关闭面板
function CommanderSkillTreePanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

---是否打开
---@return boolean
function CommanderSkillTreePanel.isOpen()
    return panel ~= nil and panel.visible == true
end

---切换选中的指挥官
---@param commanderId string|number
function CommanderSkillTreePanel.selectCommander(commanderId)
    if not panel then return end
    panel.currentCommanderId = commanderId
    panel.selectedNodeId = nil
end

---选中某技能节点查看详情
---@param nodeId string
function CommanderSkillTreePanel.selectNode(nodeId)
    if not panel then return end
    panel.selectedNodeId = nodeId
end

---解锁技能节点（消耗技能点）
---@param nodeId string
---@return boolean ok
function CommanderSkillTreePanel.unlockNode(nodeId)
    if not panel then return false end
    local node = CommanderSkillTreePanel.findNode(nodeId)
    if not node then return false end

    local tree = CommanderSkillTreePanel.getSkillTreeData()
    if tree.unlocked[nodeId] then return false end
    if tree.freePoints < node.cost then return false end

    -- 前置检查：必须先解锁同分支上一级节点
    local prevNode = CommanderSkillTreePanel.getPreviousNode(nodeId)
    if prevNode and not tree.unlocked[prevNode.id] then return false end

    -- 对接后端
    local ok, CS = pcall(require, "game.systems.CommanderSystem")
    if ok and CS and CS.unlockSkillNode then
        local result = CS.unlockSkillNode(panel.currentCommanderId, nodeId)
        if not result then return false end
    end

    tree.unlocked[nodeId] = true
    tree.freePoints = tree.freePoints - node.cost
    return true
end

---重置技能树并返还技能点
---@return boolean ok
function CommanderSkillTreePanel.resetNodes()
    if not panel then return false end
    local ok, CS = pcall(require, "game.systems.CommanderSystem")
    if ok and CS and CS.resetSkillTree then
        local result = CS.resetSkillTree(panel.currentCommanderId)
        if not result then return false end
    end
    local tree = CommanderSkillTreePanel.getSkillTreeData()
    local total = 0
    for id, _ in pairs(tree.unlocked) do
        local n = CommanderSkillTreePanel.findNode(id)
        if n then total = total + n.cost end
    end
    tree.unlocked = {}
    tree.freePoints = tree.freePoints + total
    return true
end

---主渲染入口
function CommanderSkillTreePanel.render()
    local vg = _G.BS and _G.BS.vg or nil
    if not vg then return end
    CommanderSkillTreePanel.draw(vg)
end

---返回完整技能树数据（节点 + 已解锁 + 可用点数）
---@return table
function CommanderSkillTreePanel.getSkillTreeData()
    local tree = {
        nodes = {},
        unlocked = {},
        freePoints = 8,
        maxPoints = 42,
    }

    for branchId, list in pairs(BRANCH_NODES) do
        for _, n in ipairs(list) do
            tree.nodes[n.id] = {
                id = n.id,
                name = n.name,
                cost = n.cost,
                tier = n.tier,
                branch = branchId,
                desc = n.desc,
            }
        end
    end

    local ok, CS = pcall(require, "game.systems.CommanderSystem")
    if ok and CS and CS.getSkillTree and panel and panel.currentCommanderId then
        local remote = CS.getSkillTree(panel.currentCommanderId)
        if remote then
            if type(remote.unlocked) == "table" then
                for id, flag in pairs(remote.unlocked) do
                    if flag then tree.unlocked[id] = true end
                end
            end
            if remote.freePoints then tree.freePoints = remote.freePoints end
            if remote.maxPoints  then tree.maxPoints  = remote.maxPoints end
        end
    end

    return tree
end

---返回某节点详细说明
---@param nodeId string
---@return table|nil
function CommanderSkillTreePanel.getNodeInfo(nodeId)
    local tree = CommanderSkillTreePanel.getSkillTreeData()
    local n = tree.nodes[nodeId]
    if not n then return nil end
    return {
        id = n.id,
        name = n.name,
        cost = n.cost,
        tier = n.tier,
        branch = n.branch,
        branchName = BRANCHES[n.branch].name,
        desc = n.desc,
        unlocked = tree.unlocked[nodeId] == true,
        canUnlock = (not tree.unlocked[nodeId])
                    and tree.freePoints >= n.cost
                    and CommanderSkillTreePanel.isPrereqSatisfied(n),
    }
end

-- ============================================================================
-- 内部辅助
-- ============================================================================

function CommanderSkillTreePanel.findNode(nodeId)
    for _, list in pairs(BRANCH_NODES) do
        for _, n in ipairs(list) do
            if n.id == nodeId then return n end
        end
    end
    return nil
end

function CommanderSkillTreePanel.getPreviousNode(nodeId)
    for _, list in pairs(BRANCH_NODES) do
        for i, n in ipairs(list) do
            if n.id == nodeId then
                if i > 1 then return list[i - 1] end
                return nil
            end
        end
    end
    return nil
end

function CommanderSkillTreePanel.isPrereqSatisfied(node)
    if not node then return false end
    local prev = CommanderSkillTreePanel.getPreviousNode(node.id)
    if not prev then return true end
    local tree = CommanderSkillTreePanel.getSkillTreeData()
    return tree.unlocked[prev.id] == true
end

function CommanderSkillTreePanel.getCommanderList()
    local ok, CS = pcall(require, "game.systems.CommanderSystem")
    if ok and CS and CS.getCommanders then
        local list = CS.getCommanders()
        if list and #list > 0 then return list end
    end
    return {
        { id = "cmd_alpha", name = "艾拉·维克", level = 12, faction = "联邦", freePoints = 5 },
        { id = "cmd_beta",  name = "凯恩·雷",   level = 8,  faction = "联邦", freePoints = 3 },
        { id = "cmd_gamma", name = "瑟拉芬",     level = 15, faction = "帝国", freePoints = 8 },
    }
end

function CommanderSkillTreePanel.getCurrentCommander()
    if not panel or not panel.currentCommanderId then return nil end
    for _, c in ipairs(panel.commanders) do
        if c.id == panel.currentCommanderId then return c end
    end
    return nil
end

-- ============================================================================
-- 绘制主流程
-- ============================================================================

---@param vg userdata
function CommanderSkillTreePanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or 800) / 2, (BS and BS.screenH or 600) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 245))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 45, 12)
    nvgRect(vg, px, py + 20, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "指挥官技能树")

    -- 关闭按钮
    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        CommanderSkillTreePanel.close()
    end)

    local tree = CommanderSkillTreePanel.getSkillTreeData()
    local curCmd = CommanderSkillTreePanel.getCurrentCommander()

    -- 指挥官信息条
    local infoY = py + 55
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px + 10, infoY, pw - 20, 40, 4)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 230))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(230, 235, 255, 255))
    nvgText(vg, px + 20, infoY + 20, curCmd and ("指挥官: " .. curCmd.name) or "无指挥官")

    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    if curCmd then
        nvgText(vg, px + 240, infoY + 20, "Lv." .. tostring(curCmd.level) .. " | " .. (curCmd.faction or ""))
    end

    -- 可用技能点
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.RIGHT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
    nvgText(vg, px + pw - 150, infoY + 20, "技能点: " .. tostring(tree.freePoints) .. " / " .. tostring(tree.maxPoints))

    -- 重置按钮
    local resetX = px + pw - 140
    local resetY = infoY + 6
    local resetW = 130
    local resetH = 28
    nvgBeginPath(vg)
    nvgRoundedRect(vg, resetX, resetY, resetW, resetH, 4)
    nvgFillColor(vg, nvgRGBA(180, 70, 90, 220))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 240, 240, 255))
    nvgText(vg, resetX + resetW / 2, resetY + resetH / 2, "↺ 重置技能树")
    addHit(resetX, resetY, resetW, resetH, function()
        CommanderSkillTreePanel.resetNodes()
    end)

    -- 主内容区（左侧指挥官列表 / 中央技能树 / 右侧节点详情）
    local contentY = infoY + 50
    local contentH = ph - (contentY - py) - 10

    -- 左侧指挥官列表
    local listX = px + 10
    local listY = contentY
    local listW = 150
    nvgBeginPath(vg)
    nvgRoundedRect(vg, listX, listY, listW, contentH, 6)
    nvgFillColor(vg, nvgRGBA(20, 30, 50, 220))
    nvgFill(vg)

    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, listX + 10, listY + 18, "指挥官列表")

    for i, cmd in ipairs(panel.commanders) do
        local itemY = listY + 30 + (i - 1) * 60
        local itemH = 50
        local selected = panel.currentCommanderId == cmd.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, listX + 8, itemY, listW - 16, itemH, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(30, 45, 70, 220))
        nvgFill(vg)

        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(240, 245, 255, 255))
        nvgText(vg, listX + 16, itemY + 16, cmd.name)

        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
        nvgText(vg, listX + 16, itemY + 30, "Lv." .. tostring(cmd.level))

        nvgFillColor(vg, nvgRGBA(150, 220, 255, 255))
        nvgText(vg, listX + 16, itemY + 42, cmd.faction or "")

        addHit(listX + 8, itemY, listW - 16, itemH, function()
            CommanderSkillTreePanel.selectCommander(cmd.id)
        end)
    end

    -- 中央技能树（3 列分支，每列 4 个节点，带连接线）
    local treeX = listX + listW + 10
    local treeY = contentY
    local treeW = pw - (treeX - px) - 220
    nvgBeginPath(vg)
    nvgRoundedRect(vg, treeX, treeY, treeW, contentH, 6)
    nvgFillColor(vg, nvgRGBA(18, 26, 45, 230))
    nvgFill(vg)

    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, treeX + 12, treeY + 18, "技能树（点击节点查看详情）")

    -- 3 列布局
    local branches_ordered = { "ATTACK", "DEFENSE", "SUPPORT" }
    local nodeW = 110
    local nodeH = 48
    local startX = treeX + (treeW - (#branches_ordered * nodeW + (#branches_ordered - 1) * 30)) / 2
    local startY = treeY + 40

    for bIdx, branchId in ipairs(branches_ordered) do
        local bc = BRANCHES[branchId]
        local colX = startX + (bIdx - 1) * (nodeW + 30)

        -- 分支标题
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 255))
        nvgText(vg, colX + nodeW / 2, treeY + 18, bc.name)

        -- 画分支内部连接线（纵向）
        local nodes = BRANCH_NODES[branchId]
        for nIdx = 1, #nodes - 1 do
            local y1 = startY + (nIdx - 1) * (nodeH + 18) + nodeH
            local y2 = startY + nIdx * (nodeH + 18)
            local lineX = colX + nodeW / 2
            nvgBeginPath(vg)
            nvgMoveTo(vg, lineX, y1)
            nvgLineTo(vg, lineX, y2)
            nvgStrokeColor(vg, nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 120))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)
        end

        -- 节点
        for nIdx, node in ipairs(nodes) do
            local ny = startY + (nIdx - 1) * (nodeH + 18)
            local isUnlocked = tree.unlocked[node.id] == true
            local isSelected = panel.selectedNodeId == node.id
            local prevNode = nIdx > 1 and nodes[nIdx - 1] or nil
            local prereqOk = (prevNode == nil) or (tree.unlocked[prevNode.id] == true)
            local canAfford = tree.freePoints >= node.cost
            local canUnlock = (not isUnlocked) and prereqOk and canAfford

            local nr, ng, nb = 40, 55, 85
            if isUnlocked then
                nr, ng, nb = math.floor(bc.color[1] * 0.55), math.floor(bc.color[2] * 0.55), math.floor(bc.color[3] * 0.55)
            elseif canUnlock then
                nr, ng, nb = math.floor(bc.color[1] * 0.35), math.floor(bc.color[2] * 0.35), math.floor(bc.color[3] * 0.35)
            end

            -- 节点背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, colX, ny, nodeW, nodeH, 6)
            nvgFillColor(vg, nvgRGBA(nr, ng, nb, 240))
            nvgFill(vg)
            nvgStrokeColor(vg, isSelected and nvgRGBA(255, 220, 120, 240)
                                      or nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 200))
            nvgStrokeWidth(vg, isSelected and 2.5 or 1.2)
            nvgStroke(vg)

            -- 已解锁光晕
            if isUnlocked then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, colX - 2, ny - 2, nodeW + 4, nodeH + 4, 8)
                nvgStrokeColor(vg, nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 140))
                nvgStrokeWidth(vg, 2)
                nvgStroke(vg)
            end

            -- 名称
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.CENTER)
            nvgFillColor(vg, nvgRGBA(235, 240, 255, 255))
            nvgText(vg, colX + nodeW / 2, ny + 16, node.name)

            -- 消耗/状态
            nvgFontSize(vg, 9)
            if isUnlocked then
                nvgFillColor(vg, nvgRGBA(140, 255, 170, 255))
                nvgText(vg, colX + nodeW / 2, ny + 30, "✓ 已解锁")
            elseif canUnlock then
                nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
                nvgText(vg, colX + nodeW / 2, ny + 30, "消耗 " .. tostring(node.cost) .. " 点")
            elseif not prereqOk then
                nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
                nvgText(vg, colX + nodeW / 2, ny + 30, "需先解锁前置")
            else
                nvgFillColor(vg, nvgRGBA(220, 120, 120, 255))
                nvgText(vg, colX + nodeW / 2, ny + 30, "点数不足")
            end

            -- Tier 标记（左侧）
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBA(200, 220, 255, 220))
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgText(vg, colX + 6, ny + nodeH - 6, "T" .. tostring(node.tier))

            addHit(colX, ny, nodeW, nodeH, function()
                CommanderSkillTreePanel.selectNode(node.id)
            end)
        end
    end

    -- 右侧节点详情 + 解锁按钮
    local detailX = treeX + treeW + 10
    local detailY = contentY
    local detailW = pw - (detailX - px) - 10

    nvgBeginPath(vg)
    nvgRoundedRect(vg, detailX, detailY, detailW, contentH, 6)
    nvgFillColor(vg, nvgRGBA(22, 32, 55, 230))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
    nvgText(vg, detailX + 10, detailY + 18, "节点详情")

    if not panel.selectedNodeId then
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 160, 180, 240))
        nvgText(vg, detailX + detailW / 2, detailY + contentH / 2, "请选择左侧任意技能节点")
    else
        local info = CommanderSkillTreePanel.getNodeInfo(panel.selectedNodeId)
        if info then
            local bc = BRANCHES[info.branch]
            nvgFontSize(vg, 14)
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgFillColor(vg, nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 255))
            nvgText(vg, detailX + 12, detailY + 38, info.name)

            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 200, 230, 240))
            nvgText(vg, detailX + 12, detailY + 54, "分支: " .. info.branchName .. "  |  Tier " .. tostring(info.tier))

            -- 描述框
            local descX = detailX + 10
            local descY = detailY + 64
            local descW = detailW - 20
            local descH = 70
            nvgBeginPath(vg)
            nvgRoundedRect(vg, descX, descY, descW, descH, 4)
            nvgFillColor(vg, nvgRGBA(18, 28, 50, 240))
            nvgFill(vg)

            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.TOP)
            nvgFillColor(vg, nvgRGBA(220, 230, 245, 255))
            local dy = descY + 8
            for line in string.gmatch(info.desc, "([^。]+。?)") do
                nvgText(vg, descX + 8, dy, line)
                dy = dy + 16
            end
            nvgTextAlign(vg, NVG_ALIGN.LEFT)

            -- 消耗显示
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(255, 220, 120, 255))
            nvgText(vg, detailX + 12, detailY + 150, "消耗技能点: " .. tostring(info.cost))

            nvgFillColor(vg, nvgRGBA(150, 180, 220, 255))
            nvgText(vg, detailX + 12, detailY + 168, "当前可用: " .. tostring(tree.freePoints))

            -- 解锁按钮
            local btnY = detailY + 185
            local btnX = detailX + 12
            local btnW = detailW - 24
            local btnH = 32

            if info.unlocked then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
                nvgFillColor(vg, nvgRGBA(80, 150, 100, 220))
                nvgFill(vg)
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
                nvgFillColor(vg, nvgRGBA(240, 255, 240, 255))
                nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "✓ 已解锁")
            elseif info.canUnlock then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
                nvgFillColor(vg, nvgRGBA(bc.color[1], bc.color[2], bc.color[3], 220))
                nvgFill(vg)
                nvgFontSize(vg, 12)
                nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
                nvgFillColor(vg, nvgRGBA(15, 20, 30, 255))
                nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "🔓 解锁技能（-" .. tostring(info.cost) .. "点）")
                addHit(btnX, btnY, btnW, btnH, function()
                    CommanderSkillTreePanel.unlockNode(panel.selectedNodeId)
                end)
            else
                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
                nvgFillColor(vg, nvgRGBA(80, 80, 100, 220))
                nvgFill(vg)
                nvgFontSize(vg, 11)
                nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
                nvgFillColor(vg, nvgRGBA(220, 220, 220, 240))
                local reason = (tree.freePoints < info.cost) and "点数不足" or "需先解锁前置节点"
                nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, reason)
            end

            -- 分支总览
            local summaryY = btnY + btnH + 16
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgFillColor(vg, nvgRGBA(180, 200, 230, 255))
            nvgText(vg, detailX + 12, summaryY, bc.name .. "分支总览:")

            local nodes_list = BRANCH_NODES[info.branch]
            local unlocked_count = 0
            for _, n in ipairs(nodes_list) do
                if tree.unlocked[n.id] then unlocked_count = unlocked_count + 1 end
            end

            for i, n in ipairs(nodes_list) do
                local sy = summaryY + 18 + (i - 1) * 20
                local flag = tree.unlocked[n.id]
                nvgFontSize(vg, 10)
                nvgFillColor(vg, flag and nvgRGBA(150, 230, 170, 255) or nvgRGBA(150, 160, 180, 220))
                nvgText(vg, detailX + 16, sy, flag and "✓" or "○")

                nvgFillColor(vg, flag and nvgRGBA(230, 245, 235, 255) or nvgRGBA(170, 180, 200, 220))
                nvgText(vg, detailX + 30, sy, n.name)

                nvgFillColor(vg, nvgRGBA(255, 220, 150, 220))
                nvgTextAlign(vg, NVG_ALIGN.RIGHT)
                nvgText(vg, detailX + detailW - 16, sy, tostring(n.cost) .. "pt")
                nvgTextAlign(vg, NVG_ALIGN.LEFT)
            end

            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(200, 220, 240, 240))
            nvgText(vg, detailX + 12, summaryY + 18 + #nodes_list * 20 + 4,
                string.format("进度 %d/%d", unlocked_count, #nodes_list))
        end
    end
end

return CommanderSkillTreePanel
