-- ============================================================================
-- game/ui/AchievementPanel.lua  -- 成就大厅面板（徽章展示墙）
-- ============================================================================
local UICommon = require "game.ui.UICommon"

local AchievementPanel = {}

-- ── 分类常量 ─────────────────────────────────────────────────────────────────
-- color: 已解锁徽章背景主色 {r,g,b}
local ACHIEV_CATEGORIES = {
    colonize  = { label="殖民", icon="🌍", color={30,140,80}   },
    combat    = { label="战斗", icon="⚔️",  color={180,50,40}  },
    fleet     = { label="舰队", icon="🚀", color={40,90,200}   },
    research  = { label="科技", icon="🔬", color={100,50,200}  },
    resource  = { label="资源", icon="💎", color={20,140,170}  },
    victory   = { label="胜利", icon="🏆", color={190,140,20}  },
}
local ACHIEV_TAB_ORDER = { "all", "colonize", "combat", "fleet", "research", "resource", "victory", "rewards" }
local ACHIEV_TAB_LABEL = {
    all      = "全部",
    colonize = "殖民",
    combat   = "战斗",
    fleet    = "舰队",
    research = "科技",
    resource = "资源",
    victory  = "胜利",
    rewards  = "🎁奖励",
}

-- ── 私有状态 ─────────────────────────────────────────────────────────────────
local visible_    = false
local data_       = {}     -- { id, name, desc, category, unlocked, reward, redeemed } 列表
local total_      = 0      -- 成就总数
local scroll_     = 0      -- 滚动偏移（px）
local maxScroll_  = 0      -- 最大可滚动量
local tab_        = "all"  -- 当前分类筛选
local hoverIdx_   = -1     -- 当前悬停的徽章索引（-1=无）
local glow_       = 0      -- 动画计时器
-- P2-3: 奖励兑换
local redeemFn_   = nil    -- function(id) 兑换回调（由 Client.lua 注入）
local rewardScroll_   = 0  -- 奖励 tab 滚动偏移
local rewardMaxScroll_ = 0 -- 奖励 tab 最大滚动

-- ── 渲染 ─────────────────────────────────────────────────────────────────────
local function render()
    if not visible_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local cursorX = UICommon.cursorX
    local cursorY = UICommon.cursorY
    local addHit  = UICommon.addHit
    local addScroll = UICommon.addScroll

    glow_ = glow_ + 0.04

    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 170))
    nvgFill(vg)

    -- 面板尺寸
    local pw, ph = 520, 480
    local px = (screenW - pw) / 2
    local py = (screenH - ph) / 2

    -- 外发光层
    local glowA = math.floor(18 + 10 * math.sin(glow_ * 1.2))
    for i = 1, 3 do
        nvgBeginPath(vg); nvgRoundedRect(vg, px - i*3, py - i*3, pw + i*6, ph + i*6, 16 + i*2)
        nvgFillColor(vg, nvgRGBA(200, 160, 40, glowA)); nvgFill(vg)
    end

    -- 面板主体
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 14)
    nvgFillColor(vg, nvgRGBA(6, 8, 20, 254)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, px, py, pw, ph, 14)
    nvgStrokeColor(vg, nvgRGBA(200, 160, 40, 200))
    nvgStrokeWidth(vg, 2); nvgStroke(vg)

    -- 标题区
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 19)
    nvgFillColor(vg, nvgRGBA(255, 215, 60, 255))
    nvgText(vg, px + pw/2, py + 26, "🏆  成就大厅  🏆")

    -- 解锁进度统计
    local unlockCnt = 0
    for _, a in ipairs(data_) do if a.unlocked then unlockCnt = unlockCnt + 1 end end
    local total = math.max(1, total_)
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(140, 190, 140, 220))
    nvgText(vg, px + pw/2, py + 46,
        string.format("已解锁  %d / %d  (%.0f%%)", unlockCnt, total, unlockCnt / total * 100))

    -- 进度条
    local barX, barY, barW, barH = px + 30, py + 56, pw - 60, 5
    nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, barW, barH, 2)
    nvgFillColor(vg, nvgRGBA(20, 35, 20, 200)); nvgFill(vg)
    local fillW = math.floor(barW * unlockCnt / total)
    if fillW > 0 then
        local grad = nvgLinearGradient(vg, barX, barY, barX + fillW, barY,
            nvgRGBA(40, 180, 80, 240), nvgRGBA(120, 240, 100, 220))
        nvgBeginPath(vg); nvgRoundedRect(vg, barX, barY, fillW, barH, 2)
        nvgFillPaint(vg, grad); nvgFill(vg)
    end

    -- 分类 Tab 栏
    local tabY      = py + 70
    local tabH      = 24
    local tabGap    = 4
    local totalTabs = #ACHIEV_TAB_ORDER
    local tabTotalW = pw - 24
    local tabW      = math.floor((tabTotalW - tabGap * (totalTabs - 1)) / totalTabs)
    local tabStartX = px + 12

    for ti, tabKey in ipairs(ACHIEV_TAB_ORDER) do
        local tx = tabStartX + (ti - 1) * (tabW + tabGap)
        local isActive = (tab_ == tabKey)

        local cnt = 0
        for _, a in ipairs(data_) do
            if (tabKey == "all" or a.category == tabKey) and a.unlocked then cnt = cnt + 1 end
        end

        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 5)
        nvgFillColor(vg, isActive and nvgRGBA(140, 100, 20, 200) or nvgRGBA(14, 22, 50, 180))
        nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, tx, tabY, tabW, tabH, 5)
        nvgStrokeColor(vg, isActive and nvgRGBA(255, 200, 60, 220) or nvgRGBA(50, 80, 150, 100))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, isActive and nvgRGBA(255, 230, 80, 255) or nvgRGBA(140, 160, 210, 200))
        nvgText(vg, tx + tabW/2, tabY + tabH/2,
            ACHIEV_TAB_LABEL[tabKey] .. (cnt > 0 and ("(" .. cnt .. ")") or ""))

        local capturedKey = tabKey
        addHit(tx, tabY, tabW, tabH, function()
            tab_    = capturedKey
            scroll_ = 0
        end)
    end

    -- ── P2-3: 奖励兑换视图（rewards 专用 tab） ──────────────────────────────
    if tab_ == "rewards" then
        local CARD_W   = 220
        local CARD_H   = 66
        local CARD_GAP = 8
        local COLS_R   = 2
        local gridX2   = px + (pw - (COLS_R * CARD_W + (COLS_R - 1) * CARD_GAP)) / 2
        local gridY2   = tabY + tabH + 10
        local gridH2   = ph - (gridY2 - py) - 50

        -- 统计
        local redeemable, active = 0, 0
        local rewardCards = {}
        for _, a in ipairs(data_) do
            if a.reward then
                rewardCards[#rewardCards + 1] = a
                if a.unlocked and not a.redeemed then redeemable = redeemable + 1 end
                if a.redeemed then active = active + 1 end
            end
        end

        -- 顶部说明文字
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(120, 180, 240, 200))
        nvgText(vg, px + pw/2, gridY2 - 6,
            string.format("已激活 %d 项加成  |  可兑换 %d 项", active, redeemable))

        -- 内容滚动区
        local rows2       = math.ceil(#rewardCards / COLS_R)
        local contentH2   = rows2 * (CARD_H + CARD_GAP)
        rewardMaxScroll_  = math.max(0, contentH2 - gridH2)
        rewardScroll_     = math.max(0, math.min(rewardMaxScroll_, rewardScroll_))

        nvgScissor(vg, gridX2 - 2, gridY2, COLS_R * CARD_W + (COLS_R - 1) * CARD_GAP + 4, gridH2)

        for idx, a in ipairs(rewardCards) do
            local col2  = (idx - 1) % COLS_R
            local row2  = math.floor((idx - 1) / COLS_R)
            local cx2   = gridX2 + col2 * (CARD_W + CARD_GAP)
            local cy2   = gridY2 + row2 * (CARD_H + CARD_GAP) - rewardScroll_

            if cy2 + CARD_H > gridY2 - 2 and cy2 < gridY2 + gridH2 + 2 then
                local canRedeem = a.unlocked and not a.redeemed
                local isHov2    = cursorX >= cx2 and cursorX <= cx2 + CARD_W
                               and cursorY >= cy2 and cursorY <= cy2 + CARD_H

                -- 卡片背景
                local bgA = a.redeemed and 220 or (a.unlocked and 200 or 100)
                local bgR = a.redeemed and 20 or (a.unlocked and 10 or 8)
                local bgG = a.redeemed and 40 or (a.unlocked and 22 or 12)
                local bgB = a.redeemed and 20 or (a.unlocked and 45 or 30)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, CARD_W, CARD_H, 8)
                nvgFillColor(vg, nvgRGBA(bgR, bgG, bgB, bgA)); nvgFill(vg)
                -- 边框
                local borderR = a.redeemed and 40 or (canRedeem and (isHov2 and 100 or 70) or 30)
                local borderG = a.redeemed and 180 or (canRedeem and (isHov2 and 220 or 160) or 50)
                local borderB = a.redeemed and 40 or (canRedeem and (isHov2 and 100 or 70) or 80)
                local borderAl = a.redeemed and 200 or (canRedeem and (isHov2 and 255 or 180) or 80)
                nvgBeginPath(vg); nvgRoundedRect(vg, cx2, cy2, CARD_W, CARD_H, 8)
                nvgStrokeColor(vg, nvgRGBA(borderR, borderG, borderB, borderAl))
                nvgStrokeWidth(vg, isHov2 and 1.8 or 1.2); nvgStroke(vg)

                -- 成就名称
                nvgFontFace(vg, "sans")
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFontSize(vg, 11)
                local nameClr = a.redeemed and nvgRGBA(80,220,80,255)
                    or (a.unlocked and nvgRGBA(220,240,210,255) or nvgRGBA(90,110,150,160))
                nvgFillColor(vg, nameClr)
                nvgText(vg, cx2 + 10, cy2 + 16, a.name or "")

                -- 奖励描述
                nvgFontSize(vg, 9.5)
                nvgFillColor(vg, a.unlocked and nvgRGBA(140,200,255,230) or nvgRGBA(70,90,130,130))
                nvgText(vg, cx2 + 10, cy2 + 32, a.reward.desc or "")

                -- 状态标签 / 兑换按钮
                if a.redeemed then
                    -- 已兑换绿色标签
                    nvgBeginPath(vg); nvgRoundedRect(vg, cx2 + CARD_W - 54, cy2 + CARD_H - 22, 44, 16, 4)
                    nvgFillColor(vg, nvgRGBA(20, 120, 40, 180)); nvgFill(vg)
                    nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(100, 255, 100, 240))
                    nvgText(vg, cx2 + CARD_W - 32, cy2 + CARD_H - 14, "✓ 已激活")
                elseif canRedeem then
                    -- 兑换按钮
                    local btnX2 = cx2 + CARD_W - 58
                    local btnY2 = cy2 + CARD_H - 24
                    nvgBeginPath(vg); nvgRoundedRect(vg, btnX2, btnY2, 48, 18, 5)
                    nvgFillColor(vg, isHov2
                        and nvgRGBA(60, 180, 80, 230)
                        or  nvgRGBA(40, 140, 60, 180))
                    nvgFill(vg)
                    nvgFontSize(vg, 9.5); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(220, 255, 220, 255))
                    nvgText(vg, btnX2 + 24, btnY2 + 9, "🎁 兑换")

                    if isHov2 then
                        local capturedId = a.id
                        addHit(btnX2, btnY2, 48, 18, function()
                            if redeemFn_ then redeemFn_(capturedId) end
                        end)
                    end
                else
                    -- 未解锁灰色锁定
                    nvgFontSize(vg, 9); nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(70, 90, 130, 120))
                    nvgText(vg, cx2 + CARD_W - 8, cy2 + CARD_H - 14, "🔒 未解锁")
                end
            end
        end

        nvgResetScissor(vg)

        -- 奖励 tab 滚动条
        if rewardMaxScroll_ > 0 then
            local sbX2 = px + pw - 8
            local sbY2 = gridY2
            local sbH2 = gridH2
            local thumbH2 = math.max(20, sbH2 * gridH2 / (gridH2 + rewardMaxScroll_))
            local thumbY2 = sbY2 + (sbH2 - thumbH2) * rewardScroll_ / rewardMaxScroll_
            nvgBeginPath(vg); nvgRoundedRect(vg, sbX2, sbY2, 4, sbH2, 2)
            nvgFillColor(vg, nvgRGBA(20, 30, 70, 120)); nvgFill(vg)
            nvgBeginPath(vg); nvgRoundedRect(vg, sbX2, thumbY2, 4, thumbH2, 2)
            nvgFillColor(vg, nvgRGBA(60, 200, 80, 180)); nvgFill(vg)
        end
        if #rewardCards == 0 then
            nvgFontSize(vg, 12); nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(100, 120, 180, 160))
            nvgText(vg, px + pw/2, gridY2 + gridH2/2, "暂无可用奖励")
        end

        addScroll(gridX2, gridY2, COLS_R * CARD_W + (COLS_R - 1) * CARD_GAP, gridH2, function(delta)
            rewardScroll_ = math.max(0, math.min(rewardMaxScroll_, rewardScroll_ - delta * 36))
        end)

        -- 跳过徽章墙，直接渲染关闭按钮
        goto draw_close
    end

    -- P3-1: 圆形徽章展示墙（彩色背景 + 分类色 + 金色外发光）
    do  -- ← do/end 使局部变量不跨越 goto draw_close 的目标，避免 Lua goto-into-scope 报错
    local COLS      = 4
    local BADGE_W   = 108
    local BADGE_H   = 96
    local BADGE_GAP = 10
    local CIRCLE_R  = 32   -- 圆形徽章半径
    local gridX     = px + (pw - (COLS * BADGE_W + (COLS-1) * BADGE_GAP)) / 2
    local gridY     = tabY + tabH + 8
    local gridH     = ph - (gridY - py) - 50

    -- 过滤当前 Tab 的成就
    local filtered = {}
    for _, a in ipairs(data_) do
        if tab_ == "all" or a.category == tab_ then
            filtered[#filtered + 1] = a
        end
    end

    local rows     = math.ceil(#filtered / COLS)
    local contentH = rows * (BADGE_H + BADGE_GAP)
    maxScroll_ = math.max(0, contentH - gridH)
    scroll_    = math.max(0, math.min(maxScroll_, scroll_))

    nvgScissor(vg, gridX - 2, gridY, COLS * BADGE_W + (COLS-1) * BADGE_GAP + 4, gridH)
    hoverIdx_ = -1

    for idx, ach in ipairs(filtered) do
        local col  = (idx - 1) % COLS
        local row  = math.floor((idx - 1) / COLS)
        local bx   = gridX + col * (BADGE_W + BADGE_GAP)
        local by   = gridY + row * (BADGE_H + BADGE_GAP) - scroll_
        local cx   = bx + BADGE_W / 2        -- 圆心X
        local cy   = by + CIRCLE_R + 8       -- 圆心Y（顶部留 8px 空间给外发光）

        if by + BADGE_H > gridY - 2 and by < gridY + gridH + 2 then
            local isUnlocked = ach.unlocked
            local isHover = (cursorX >= bx and cursorX <= bx + BADGE_W
                          and cursorY >= by and cursorY <= by + BADGE_H)
            if isHover then hoverIdx_ = idx end

            local cat = ACHIEV_CATEGORIES[ach.category] or { label="?", icon="⭐", color={100,100,100} }
            local cr, cg, cb = cat.color[1], cat.color[2], cat.color[3]

            if isUnlocked then
                local pulse = math.abs(math.sin(glow_ * 1.8 + idx * 0.5))
                -- 金色外发光光晕（3层渐变圆）
                for i = 3, 1, -1 do
                    local haloA = math.floor((22 + 14 * pulse) * (4 - i) / 3)
                    nvgBeginPath(vg)
                    nvgCircle(vg, cx, cy, CIRCLE_R + i * 4)
                    nvgFillColor(vg, nvgRGBA(255, 210, 60, haloA))
                    nvgFill(vg)
                end
                -- 彩色背景圆（分类特色色 + 渐变）
                local grad = nvgRadialGradient(vg, cx, cy - CIRCLE_R * 0.3, CIRCLE_R * 0.3, CIRCLE_R,
                    nvgRGBA(math.min(255,cr+60), math.min(255,cg+60), math.min(255,cb+60), 230),
                    nvgRGBA(cr, cg, cb, 210))
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, CIRCLE_R)
                nvgFillPaint(vg, grad)
                nvgFill(vg)
                -- 金色圆边框
                local borderA = math.floor(180 + 60 * pulse)
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, CIRCLE_R)
                nvgStrokeColor(vg, nvgRGBA(255, 210, 60, borderA))
                nvgStrokeWidth(vg, isHover and 2.5 or 1.8)
                nvgStroke(vg)
                -- 顶部高光弧线
                nvgBeginPath(vg)
                nvgArc(vg, cx, cy, CIRCLE_R - 2, math.pi * 1.2, math.pi * 1.8, NVG_CW)
                nvgStrokeColor(vg, nvgRGBA(255, 255, 255, math.floor(80 + 50 * pulse)))
                nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
                -- 成就图标 emoji（居中）
                nvgFontSize(vg, 26)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
                nvgText(vg, cx, cy, cat.icon)
                -- 右上角金星
                nvgFontSize(vg, 11)
                nvgFillColor(vg, nvgRGBA(255, 240, 60, 230))
                nvgText(vg, cx + CIRCLE_R - 4, cy - CIRCLE_R + 6, "★")
            else
                -- 未解锁：灰色空心圆 + 问号
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, CIRCLE_R)
                nvgFillColor(vg, nvgRGBA(16, 22, 50, 200))
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgCircle(vg, cx, cy, CIRCLE_R)
                nvgStrokeColor(vg, isHover and nvgRGBA(80,100,180,160) or nvgRGBA(50, 70, 130, 100))
                nvgStrokeWidth(vg, isHover and 1.8 or 1); nvgStroke(vg)
                -- 虚线圆轮廓（装饰）
                nvgFontSize(vg, 22)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, nvgRGBA(80, 100, 160, 140))
                nvgText(vg, cx, cy, "?")
                -- 锁图标（右上角）
                nvgFontSize(vg, 10)
                nvgFillColor(vg, nvgRGBA(100, 120, 180, 140))
                nvgText(vg, cx + CIRCLE_R - 4, cy - CIRCLE_R + 6, "🔒")
            end

            -- 成就名称（圆下方）
            local nameY = cy + CIRCLE_R + 10
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isUnlocked and nvgRGBA(220, 245, 210, 255) or nvgRGBA(100, 120, 170, 160))
            nvgText(vg, cx, nameY, ach.name or "")
            -- 分类标签
            nvgFontSize(vg, 8)
            nvgFillColor(vg, isUnlocked and nvgRGBA(cr, cg, cb, 200) or nvgRGBA(60, 80, 130, 120))
            nvgText(vg, cx, nameY + 13, cat.label)
        end
    end

    nvgResetScissor(vg)

    -- Tooltip（悬停时显示）
    if hoverIdx_ >= 1 and hoverIdx_ <= #filtered then
        local ach = filtered[hoverIdx_]
        local col = (hoverIdx_ - 1) % COLS
        local row = math.floor((hoverIdx_ - 1) / COLS)
        local bx  = gridX + col * (BADGE_W + BADGE_GAP)
        local by  = gridY + row * (BADGE_H + BADGE_GAP) - scroll_

        local tipW = 180
        local tipH = 40
        local tipX = bx + BADGE_W/2 - tipW/2
        local tipY = by + BADGE_H + 4
        if tipY + tipH > py + ph - 48 then tipY = by - tipH - 4 end
        tipX = math.max(px + 4, math.min(px + pw - tipW - 4, tipX))

        nvgBeginPath(vg); nvgRoundedRect(vg, tipX, tipY, tipW, tipH, 6)
        nvgFillColor(vg, nvgRGBA(8, 12, 30, 240)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, tipX, tipY, tipW, tipH, 6)
        nvgStrokeColor(vg, nvgRGBA(200, 160, 40, 160))
        nvgStrokeWidth(vg, 1); nvgStroke(vg)

        nvgFontSize(vg, 9.5)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 230, 200, 240))
        nvgText(vg, tipX + tipW/2, tipY + 14, ach.name or "")
        nvgFontSize(vg, 8.5)
        nvgFillColor(vg, nvgRGBA(140, 170, 140, 210))
        nvgText(vg, tipX + tipW/2, tipY + 28, ach.desc or "")
    end

    -- 滚动条
    if maxScroll_ > 0 then
        local sbX = px + pw - 8
        local sbY = gridY
        local sbH = gridH
        local thumbH = math.max(20, sbH * gridH / (gridH + maxScroll_))
        local thumbY = sbY + (sbH - thumbH) * scroll_ / maxScroll_
        nvgBeginPath(vg); nvgRoundedRect(vg, sbX, sbY, 4, sbH, 2)
        nvgFillColor(vg, nvgRGBA(20, 30, 70, 120)); nvgFill(vg)
        nvgBeginPath(vg); nvgRoundedRect(vg, sbX, thumbY, 4, thumbH, 2)
        nvgFillColor(vg, nvgRGBA(200, 160, 40, 180)); nvgFill(vg)
    end

    -- 空列表提示
    if #filtered == 0 then
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(100, 120, 180, 160))
        nvgText(vg, px + pw/2, gridY + gridH/2, "该分类暂无成就")
    end

    -- 徽章墙滚动注册（必须在 do 块内，变量有效）
    addScroll(gridX, gridY, COLS * BADGE_W + (COLS-1) * BADGE_GAP, gridH, function(delta)
        scroll_ = math.max(0, math.min(maxScroll_, scroll_ - delta * 36))
    end)
    end -- do（徽章墙局部变量作用域结束）

    -- P2-3: 奖励 tab 跳转标签
    ::draw_close::

    -- 关闭按钮
    local cbx = px + pw/2 - 55
    local cby = py + ph - 40
    nvgBeginPath(vg); nvgRoundedRect(vg, cbx, cby, 110, 30, 7)
    nvgFillColor(vg, nvgRGBA(20, 40, 80, 200)); nvgFill(vg)
    nvgBeginPath(vg); nvgRoundedRect(vg, cbx, cby, 110, 30, 7)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 220, 180))
    nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 200, 255, 240))
    nvgText(vg, px + pw/2, cby + 15, "关闭")

    addHit(cbx, cby, 110, 30, function()
        visible_ = false
        scroll_  = 0
    end)
    addHit(px, py, pw, ph, function() end)
    addHit(0, 0, screenW, screenH, function()
        visible_ = false
        scroll_  = 0
    end)
end

-- ============================================================================
-- 公开 API
-- ============================================================================

--- 显示成就面板
function AchievementPanel.Show()
    visible_ = true
    scroll_  = 0
end

--- 隐藏成就面板
function AchievementPanel.Hide()
    visible_ = false
    scroll_  = 0
end

--- 是否当前可见
function AchievementPanel.IsVisible()
    return visible_
end

--- 切换显示状态
function AchievementPanel.Toggle()
    visible_ = not visible_
    scroll_  = 0
end

--- 返回已解锁成就数量（供 TopBar 徽章显示）
function AchievementPanel.GetUnlockCount()
    local cnt = 0
    for _, a in ipairs(data_) do
        if a.unlocked then cnt = cnt + 1 end
    end
    return cnt
end

--- 注入成就数据（由 Client.lua 在初始化/解锁时调用）
---@param data table  { {id, name, desc, category, unlocked, reward, redeemed}, ... }
---@param total number 成就总数
function AchievementPanel.SetData(data, total)
    data_  = data or {}
    total_ = total or #data_
end

--- P2-3: 注入兑换回调（由 Client.lua 在初始化时调用）
---@param fn function  function(id:string) 兑换指定成就奖励
function AchievementPanel.SetRedeemCallback(fn)
    redeemFn_ = fn
end

--- P2-3: 返回可兑换数量（供 TopBar 显示角标）
function AchievementPanel.GetRedeemableCount()
    local cnt = 0
    for _, a in ipairs(data_) do
        if a.reward and a.unlocked and not a.redeemed then cnt = cnt + 1 end
    end
    return cnt
end

--- 渲染（每帧调用）
function AchievementPanel.Render()
    render()
end

return AchievementPanel
