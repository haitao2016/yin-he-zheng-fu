-- Auto-split from ClientMenus.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function ClientMenus.RenderHeritagePanel(vg, sw, sh, ctx)
    local tree     = ctx.evolutionTree
    local pts      = ctx.evolutionPoints   or 0
    local unlocked = ctx.evolutionUnlocked or {}
    local hover    = ctx.hover
    local t        = ctx.menuT or 0

    -- 全屏遮罩
    local bg = nvgLinearGradient(vg, 0, 0, 0, sh,
        nvgRGBA(2, 5, 18, 245), nvgRGBA(5, 12, 38, 245))
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, sw, sh)
    nvgFillPaint(vg, bg)
    nvgFill(vg)

    -- 稀疏星点背景
    math.randomseed(77)
    for _ = 1, 40 do
        local sx = math.random() * sw
        local sy = math.random() * sh
        local sr = math.random() * 1.0 + 0.3
        local a  = math.random(40, 140)
        nvgBeginPath(vg)
        nvgCircle(vg, sx, sy, sr)
        nvgFillColor(vg, nvgRGBA(180, 200, 255, a))
        nvgFill(vg)
    end

    -- 面板主体
    local PW = math.min(620, sw - 40)
    local PH = 460
    local px = (sw - PW) * 0.5
    local py = (sh - PH) * 0.5

    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgFillColor(vg, nvgRGBA(10, 15, 40, 230))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 14)
    nvgStrokeColor(vg, nvgRGBA(80, 130, 220, 200))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(180, 210, 255, 255))
    nvgText(vg, sw / 2, py + 22, "⚙  星际传承进化树")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 20, py + 38)
    nvgLineTo(vg, px + PW - 20, py + 38)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 180, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 积分显示（右上角）
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 215, 80, 240))
    nvgText(vg, px + PW - 36, py + 22, string.format("文明积分：%d", pts))

    -- 关闭按钮（X）
    local closeX, closeY = getHeritageClosePos(sw, sh)
    local closeDist = hover == "close" and 0 or 999
    local isCloseHov = (hover == "close")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, isCloseHov and nvgRGBA(255, 100, 100, 255) or nvgRGBA(160, 170, 200, 200))
    nvgText(vg, closeX, closeY, "✕")

    -- 路线 + 节点
    local nodeW  = math.floor((PW - 48) / 4) - 8
    local nodeH  = 78
    local gapX   = 8
    local lineH  = nodeH + 28

    -- 预先计算每条路线前一层是否已解锁（用于节点连线颜色）
    -- 按路线分组
    local byLine = {}
    for _, node in ipairs(tree) do
        byLine[node.line] = byLine[node.line] or {}
        byLine[node.line][node.tier] = node
    end

    for li, lineName in ipairs(LINE_ORDER) do
        local meta  = LINE_META[lineName]
        local cr, cg, cb = meta.color[1], meta.color[2], meta.color[3]
        local rowY  = py + 70 + (li - 1) * (lineH + 12)

        -- 路线标签
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
        nvgText(vg, px + 24, rowY + 10, meta.label)

        -- 节点连线（4个节点之间画3段连线）
        for tier = 1, 3 do
            local n1  = byLine[lineName][tier]
            local n2  = byLine[lineName][tier + 1]
            if n1 and n2 then
                local col1 = tier - 1
                local col2 = tier
                local x1   = px + 24 + col1 * (nodeW + gapX) + nodeW
                local x2   = px + 24 + col2 * (nodeW + gapX)
                local cy2  = rowY + 24 + nodeH / 2
                local bothUnlocked = unlocked[n1.id] and unlocked[n2.id]
                nvgBeginPath(vg)
                nvgMoveTo(vg, x1, cy2)
                nvgLineTo(vg, x2, cy2)
                if bothUnlocked then
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 200))
                    nvgStrokeWidth(vg, 2.5)
                elseif unlocked[n1.id] then
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 100))
                    nvgStrokeWidth(vg, 1.5)
                else
                    nvgStrokeColor(vg, nvgRGBA(60, 70, 100, 120))
                    nvgStrokeWidth(vg, 1)
                end
                nvgStroke(vg)
            end
        end

        -- 各节点格子
        for _, node in ipairs(tree) do
            if node.line == lineName then
                local col    = node.tier - 1
                local nx     = px + 24 + col * (nodeW + gapX)
                local ny     = rowY + 24
                local isUnlocked = unlocked[node.id]
                local isHov  = (hover == node.id)

                -- 检查是否可解锁（前置节点已解锁 且 积分足够）
                local prereqOk = true
                if node.tier > 1 then
                    local prev = byLine[lineName][node.tier - 1]
                    if prev then prereqOk = unlocked[prev.id] == true end
                end
                local canUnlock = prereqOk and not isUnlocked and pts >= node.unlockCost

                -- 节点背景色
                local bgR, bgG, bgB, bgA
                if isUnlocked then
                    bgR, bgG, bgB = cr, cg, cb
                    bgA = isHov and 90 or 55
                elseif canUnlock then
                    bgR, bgG, bgB = cr, cg, cb
                    bgA = isHov and 50 or 28
                else
                    bgR, bgG, bgB, bgA = 30, 35, 55, isHov and 60 or 35
                end

                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, nodeW, nodeH, 8)
                local nodeBg = nvgLinearGradient(vg, nx, ny, nx, ny + nodeH,
                    nvgRGBA(bgR, bgG, bgB, bgA + 10),
                    nvgRGBA(bgR, bgG, bgB, bgA))
                nvgFillPaint(vg, nodeBg)
                nvgFill(vg)

                -- 边框
                local borderA, borderW
                if isUnlocked then
                    borderA = isHov and 240 or 180
                    borderW = isHov and 2.0 or 1.5
                elseif canUnlock then
                    borderA = isHov and 200 or 140
                    borderW = isHov and 2.0 or 1.2
                else
                    borderA = 60
                    borderW = 0.8
                end
                nvgBeginPath(vg)
                nvgRoundedRect(vg, nx, ny, nodeW, nodeH, 8)
                nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, borderA))
                nvgStrokeWidth(vg, borderW)
                nvgStroke(vg)

                -- hover 外发光
                if isHov and (canUnlock or isUnlocked) then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, nx - 3, ny - 3, nodeW + 6, nodeH + 6, 11)
                    nvgStrokeColor(vg, nvgRGBA(cr, cg, cb, 70))
                    nvgStrokeWidth(vg, 5)
                    nvgStroke(vg)
                end

                -- 节点内容
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                -- 图标
                nvgFontSize(vg, 18)
                nvgFillColor(vg, nvgRGBA(cr, cg, cb, isUnlocked and 255 or 160))
                nvgText(vg, nx + nodeW / 2, ny + 16, node.icon)
                -- 名称
                nvgFontSize(vg, 11)
                nvgFillColor(vg, nvgRGBA(200, 220, 255, isUnlocked and 230 or 150))
                nvgText(vg, nx + nodeW / 2, ny + 33, node.name)
                -- 描述
                nvgFontSize(vg, 9)
                nvgFillColor(vg, nvgRGBA(160, 180, 220, isUnlocked and 200 or 110))
                nvgText(vg, nx + nodeW / 2, ny + 47, node.desc)
                -- 费用 / 状态
                if isUnlocked then
                    nvgFontSize(vg, 10)
                    nvgFillColor(vg, nvgRGBA(cr, cg, cb, 220))
                    nvgText(vg, nx + nodeW / 2, ny + 62, "✓ 已解锁")
                elseif canUnlock then
                    nvgFontSize(vg, 10)
                    nvgFillColor(vg, nvgRGBA(255, 215, 80, 230))
                    nvgText(vg, nx + nodeW / 2, ny + 62,
                        string.format("点击解锁 ✦%d", node.unlockCost))
                else
                    nvgFontSize(vg, 10)
                    local costColor = pts >= node.unlockCost
                        and nvgRGBA(200, 200, 100, 160)
                        or  nvgRGBA(160, 80, 80, 180)
                    nvgFillColor(vg, costColor)
                    if not prereqOk then
                        nvgText(vg, nx + nodeW / 2, ny + 62, "🔒 前置未解")
                    else
                        nvgText(vg, nx + nodeW / 2, ny + 62,
                            string.format("需 ✦%d", node.unlockCost))
                    end
                end
            end
        end
    end

    -- 底部提示
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(100, 120, 170, 180))
    nvgText(vg, sw / 2, py + PH - 18,
        "赢得游戏获得文明积分 · 积分永久保留 · 传承加成在下局自动生效")
end

return ClientMenus
