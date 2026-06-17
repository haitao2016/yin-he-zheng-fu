-- ============================================================================
-- game/ui/MegaPanel.lua  -- P2-2: 巨构工程面板（模态浮层）
-- 展示三种巨构的建造进度、阶段详情、资源需求、启动建造
-- ============================================================================
local UICommon = require("game.ui.UICommon")
local MegastructureSystem = require("game.MegastructureSystem")

local MegaPanel = {}

-- 面板状态
local open_     = false
local scrollY_  = 0
local hoverKey_ = nil   -- 当前悬浮的巨构 key

-- ============================================================================
-- 公开 API
-- ============================================================================

function MegaPanel.IsOpen() return open_ end
function MegaPanel.Open()   open_ = true; scrollY_ = 0 end
function MegaPanel.Close()  open_ = false end
function MegaPanel.Toggle()
    open_ = not open_
    if open_ then scrollY_ = 0 end
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 渲染巨构面板（模态浮层，居中显示）
---@param ctx table  { coreLevel:number, resources:table, onStartPhase:function(key), buildMult:number }
function MegaPanel.Render(ctx)
    if not open_ then return end

    local vg       = UICommon.vg
    local screenW  = UICommon.screenW
    local screenH  = UICommon.screenH
    local addHit   = UICommon.addHit
    local panel    = UICommon.panel
    local text     = UICommon.text
    local clr      = UICommon.clr
    local C        = UICommon.C

    local coreLevel = ctx.coreLevel or 1
    local resources = ctx.resources or {}
    local onStart   = ctx.onStartPhase
    local buildMult = ctx.buildMult or 1.0

    -- 面板尺寸（居中）
    local pw = math.min(520, screenW - 40)
    local ph = math.min(360, screenH - 40)
    local px = math.floor((screenW - pw) / 2)
    local py = math.floor((screenH - ph) / 2)

    -- 遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, clr(0, 0, 0, 160))
    nvgFill(vg)
    -- 点击遮罩关闭
    addHit(0, 0, screenW, screenH, function() MegaPanel.Close() end)

    -- 面板背景
    panel(px, py, pw, ph, 8, C.panelBgDark, C.panelBorder)
    -- 阻断遮罩点击
    addHit(px, py, pw, ph, function() end)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(vg, clr(100, 200, 255, 255))
    nvgText(vg, px + pw/2, py + 8, "⚙ 巨构工程")

    -- 关闭按钮
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(vg, clr(200, 200, 200, 200))
    nvgText(vg, px + pw - 10, py + 8, "✕")
    addHit(px + pw - 28, py + 4, 24, 18, function() MegaPanel.Close() end)

    -- 内容区起始
    local cy = py + 30
    local cx = px + 12
    local cardW = pw - 24
    local cardH = 95  -- 每个巨构卡片高度

    -- 滚动区域
    local contentH = #MEGA_ORDER * (cardH + 8) + 10
    local visH = ph - 38
    addHit(px, cy, pw, visH, function() end)  -- 阻断底层

    -- 限制滚动范围
    local maxScroll = math.max(0, contentH - visH)
    scrollY_ = math.max(0, math.min(scrollY_, maxScroll))

    -- 裁剪区域
    nvgSave(vg)
    nvgScissor(vg, px, cy, pw, visH)

    local drawY = cy - scrollY_

    for idx, key in ipairs(MEGA_ORDER) do
        local def   = MEGASTRUCTURES[key]
        local state = MegastructureSystem.GetState(key)
        local unlocked = MegastructureSystem.IsUnlocked(key, coreLevel)
        local cardY = drawY + (idx - 1) * (cardH + 8)

        -- 卡片可见性裁剪
        if cardY + cardH >= cy and cardY <= cy + visH then
            -- 卡片背景
            local bgAlpha = unlocked and 200 or 120
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx, cardY, cardW, cardH, 6)
            nvgFillColor(vg, clr(15, 25, 50, bgAlpha))
            nvgFill(vg)
            nvgStrokeColor(vg, clr(60, 120, 200, unlocked and 150 or 60))
            nvgStrokeWidth(vg, 1)
            nvgStroke(vg)

            -- 图标 + 名称
            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, clr(255, 255, 255, unlocked and 255 or 100))
            nvgText(vg, cx + 8, cardY + 6, def.icon .. " " .. def.name)

            -- 解锁要求
            if not unlocked then
                nvgFontSize(vg, 10)
                nvgFillColor(vg, clr(200, 100, 100, 200))
                nvgText(vg, cx + 8, cardY + 26, "🔒 需要基地核心 Lv." .. def.unlockCoreLevel)
                nvgFontSize(vg, 9)
                nvgFillColor(vg, clr(150, 170, 200, 150))
                nvgText(vg, cx + 8, cardY + 40, def.desc)
            else
                -- 状态描述
                nvgFontSize(vg, 9)
                nvgFillColor(vg, clr(150, 200, 255, 180))
                nvgText(vg, cx + 8, cardY + 24, def.desc)

                -- 阶段进度
                local phaseTxt
                if state.completed then
                    phaseTxt = "✅ 已完工 (" .. #def.phases .. "/" .. #def.phases .. ")"
                elseif state.building then
                    phaseTxt = "🔨 建造中: " .. def.phases[state.currentPhase].name ..
                               " (" .. state.currentPhase .. "/" .. #def.phases .. ")"
                elseif state.currentPhase > 0 then
                    phaseTxt = "阶段 " .. state.currentPhase .. "/" .. #def.phases .. " 已完成"
                else
                    phaseTxt = "未开始 (0/" .. #def.phases .. ")"
                end
                nvgFontSize(vg, 10)
                nvgFillColor(vg, clr(200, 220, 255, 220))
                nvgText(vg, cx + 8, cardY + 37, phaseTxt)

                -- 进度条（建造中时显示）
                if state.building then
                    local progress = MegastructureSystem.GetProgress(key)
                    local barX = cx + 8
                    local barY = cardY + 52
                    local barW = cardW - 120
                    local barH = 8
                    -- 背景
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
                    nvgFillColor(vg, clr(20, 40, 80, 200))
                    nvgFill(vg)
                    -- 填充
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, barX, barY, barW * progress, barH, 3)
                    nvgFillColor(vg, clr(80, 200, 120, 240))
                    nvgFill(vg)
                    -- 时间文字
                    local phase = def.phases[state.currentPhase]
                    local remaining = math.max(0, phase.buildTime - state.timer)
                    local timeTxt = string.format("剩余 %ds", math.ceil(remaining / buildMult))
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, clr(160, 220, 160, 220))
                    nvgText(vg, barX + barW + 6, barY - 1, timeTxt)
                end

                -- 下一阶段按钮（非建造中 & 未完工）
                if not state.building and not state.completed then
                    local nextPhase = MegastructureSystem.GetCurrentPhaseCost(key)
                    if nextPhase then
                        -- 资源需求
                        local costTxt = ""
                        local canAfford = true
                        for res, need in pairs(nextPhase.cost) do
                            local have = resources[res] or 0
                            local label = res
                            if res == "metal" then label = "金属"
                            elseif res == "esource" then label = "能源"
                            elseif res == "nuclear" then label = "核能" end
                            costTxt = costTxt .. label .. ":" .. need .. " "
                            if have < need then canAfford = false end
                        end
                        nvgFontSize(vg, 9)
                        nvgFillColor(vg, clr(160, 180, 200, 180))
                        nvgText(vg, cx + 8, cardY + 52, "下一阶段: " .. nextPhase.name)
                        nvgFillColor(vg, clr(canAfford and 160 or 220, canAfford and 200 or 100, canAfford and 160 or 100, 200))
                        nvgText(vg, cx + 8, cardY + 64, costTxt .. " | " .. nextPhase.buildTime .. "s")

                        -- 建造按钮
                        local canBuild, reason = MegastructureSystem.CanStartPhase(key, resources, coreLevel)
                        local btnX = cx + cardW - 72
                        local btnY = cardY + 55
                        local btnW = 60
                        local btnH = 20
                        nvgBeginPath(vg)
                        nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)
                        if canBuild then
                            nvgFillColor(vg, clr(30, 120, 200, 220))
                        else
                            nvgFillColor(vg, clr(50, 50, 70, 180))
                        end
                        nvgFill(vg)
                        nvgFontSize(vg, 10)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, clr(220, 240, 255, canBuild and 255 or 100))
                        nvgText(vg, btnX + btnW/2, btnY + btnH/2, "开始建造")

                        if canBuild and onStart then
                            addHit(btnX, btnY, btnW, btnH, function()
                                onStart(key)
                            end)
                        end
                    end
                end

                -- 已完工：显示加成摘要
                if state.completed then
                    local fb = def.finalBonus
                    local bonusTxt = "加成: "
                    if fb.esourceRate then bonusTxt = bonusTxt .. "能源+" .. (def.bonusPerPhase.esourceRate * #def.phases + fb.esourceRate) .. "/s " end
                    if fb.researchMult then bonusTxt = bonusTxt .. "科研×" .. fb.researchMult .. " " end
                    if fb.instantWarp then bonusTxt = bonusTxt .. "瞬移 " end
                    if fb.defenseMult then bonusTxt = bonusTxt .. "防御×" .. fb.defenseMult .. " " end
                    nvgFontSize(vg, 9)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, clr(100, 255, 160, 220))
                    nvgText(vg, cx + 8, cardY + 52, bonusTxt)
                end
            end
        end
    end

    nvgRestore(vg)  -- 恢复裁剪

    -- 滚动交互
    UICommon.addScroll(px, cy, pw, visH, function(dy)
        scrollY_ = scrollY_ - dy
        scrollY_ = math.max(0, math.min(scrollY_, maxScroll))
    end)
end

return MegaPanel
