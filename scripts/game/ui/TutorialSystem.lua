-- ============================================================================
-- game/ui/TutorialSystem.lua  -- 游戏内教程系统（NanoVG 实现）
-- 银河征服 MMOSLG 新手引导
-- ============================================================================

local UICommon = require("game.ui.UICommon")

local TutorialSystem = {}

-- ============================================================================
-- 教程步骤定义
-- ============================================================================
-- highlight: 高亮区域 {x,y,w,h} 或 nil（全屏遮罩）
-- 位置使用"锚点"策略，运行时根据实际屏幕尺寸计算
-- anchor: "center"|"top"|"bottom"|"left"|"right"|"topbar"
-- ============================================================================
local STEPS = {
    -- 第 1 步：欢迎
    {
        id       = "welcome",
        anchor   = "center",
        title    = "欢迎来到银河征服！",
        body     = "你是一名星际指挥官，从一艘种子飞船起步，\n建立属于自己的星际帝国。\n\n让我们开始你的征途！",
        btnText  = "出发！",
        highlight = nil,
        trigger  = "start",   -- 触发时机：游戏开始时
    },
    -- 第 2 步：认识银河地图
    {
        id       = "galaxy_map",
        anchor   = "bottom",
        title    = "银河地图",
        body     = "这就是你的银河——数十个星系等待探索。\n\n• 拖动屏幕  平移视野\n• 双指捏合  缩放地图\n• 圆点 = 恒星系，小圆 = 行星",
        btnText  = "明白了",
        highlight = nil,
        trigger  = "start",
    },
    -- 第 3 步：种子飞船
    {
        id       = "seed_ship",
        anchor   = "bottom",
        title    = "你的种子飞船",
        body     = "飞船图标就是你，现在还没有基地。\n\n移动到一颗合适的行星旁边，\n然后点击「▶ 在此展开基地」\n或按 SPACE 键，在此安营扎寨！",
        btnText  = "去找行星",
        highlight = nil,
        trigger  = "start",
    },
    -- 第 4 步：展开基地后 — 认识资源栏
    {
        id       = "topbar",
        anchor   = "top",
        title    = "顶部资源栏",
        body     = "展开基地后，顶部会显示你所有的资源。\n\n原矿（矿石/能量块/水晶）→ 精炼后\n变为精炼资源（金属/能源/核能）\n才能用于建造和科研。",
        btnText  = "懂了",
        highlight = "topbar",  -- 高亮顶部栏
        trigger  = "deployed",  -- 触发时机：展开基地后
    },
    -- 第 5 步：基地面板
    {
        id       = "base_panel",
        anchor   = "right",
        title    = "星航基地",
        body     = "点击基地星球可以打开「星航基地」面板。\n\n建议优先建造：\n① 能量核心 — 精炼原矿（必须！）\n② 太阳能阵列 — 直接产出能源\n③ 资源精炼厂 — 加快精炼速度",
        btnText  = "去建造",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 6 步：精炼系统说明
    {
        id       = "refinery",
        anchor   = "center",
        title    = "资源精炼系统",
        body     = "原矿  →  精炼资源（精炼厂转化）\n\n矿石  ×3 → 金属\n能量块 ×2 → 能源\n水晶   ×5 → 核能\n\n建造「能量核心」和「资源精炼厂」\n可大幅提升精炼效率！",
        btnText  = "明白了",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 7 步：舰队面板
    {
        id       = "fleet_panel",
        anchor   = "bottom",
        title    = "编队管理",
        body     = "右下角是你的编队面板。\n\n• 工程舰 — 采集小行星原矿\n• 探索舰 — 殖民新行星\n• 侦察舰/护卫舰/驱逐舰 — 战斗\n\n建造「星际造船厂」后可生产舰船。",
        btnText  = "好的",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 8 步：科研面板
    {
        id       = "tech_panel",
        anchor   = "left",
        title    = "科研系统",
        body     = "选中已殖民的行星，建造「科研中心」\n即可看到科研面板。\n\n优先研究：\n• 深层采矿 — 矿井产量+20%\n• 高效光伏 — 电站产量+15%",
        btnText  = "收到",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 9 步：殖民扩张
    {
        id       = "colonize",
        anchor   = "center",
        title    = "殖民扩张",
        body     = "建造探索舰后，点击编队面板的\n「探索模式」，再点击银河地图上\n未殖民的星球即可发起殖民！\n\n更多行星 = 更多资源 = 更强帝国",
        btnText  = "明白了",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 10 步：海盗威胁
    {
        id       = "pirates",
        anchor   = "center",
        title    = "⚠ 小心海盗！",
        body     = "银河中潜伏着海盗势力。\n随着时间推移，他们会进犯你的基地！\n\n• 升级「防御炮台」提高基地防御\n• 建造战斗舰队保卫家园\n• 击败海盗可削弱其巢穴",
        btnText  = "我会备战",
        highlight = nil,
        trigger  = "deployed",
    },
    -- 第 11 步：完成
    {
        id       = "done",
        anchor   = "center",
        title    = "教程完成！",
        body     = "你已掌握银河征服的基础玩法！\n\n• 建造基地模块扩大生产\n• 殖民更多星球获取资源\n• 研究科技强化帝国实力\n• 组建舰队抵御海盗\n\n愿星途顺遂，星系统治者！🚀",
        btnText  = "开始征服！",
        highlight = nil,
        trigger  = "deployed",
        isLast   = true,
    },
}

-- 各 trigger 分组
local STEPS_BY_TRIGGER = {}
for _, s in ipairs(STEPS) do
    local t = s.trigger or "start"
    if not STEPS_BY_TRIGGER[t] then STEPS_BY_TRIGGER[t] = {} end
    STEPS_BY_TRIGGER[t][#STEPS_BY_TRIGGER[t] + 1] = s
end

-- ============================================================================
-- 状态
-- ============================================================================
local active_       = false      -- 教程是否激活
local currentStep_  = nil        -- 当前步骤对象
local stepQueue_    = {}         -- 待显示步骤队列
local stepIdx_      = 0          -- 当前队列索引
local animT_        = 0          -- 入场动画计时（0→1）
local skipHover_    = false      -- 跳过按钮悬停状态
local ANIM_DUR      = 0.22       -- 秒

-- 已完成步骤集合（用于防止重复显示）
local completed_    = {}

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 启动"start"触发的步骤（游戏开始时调用）
function TutorialSystem.TriggerStart()
    if completed_["tutorial_done"] then return end
    TutorialSystem._Queue(STEPS_BY_TRIGGER["start"] or {})
end

--- 启动"deployed"触发的步骤（展开基地后调用）
function TutorialSystem.TriggerDeployed()
    if completed_["tutorial_done"] then return end
    TutorialSystem._Queue(STEPS_BY_TRIGGER["deployed"] or {})
end

--- 强制跳过整个教程
function TutorialSystem.Skip()
    active_      = false
    currentStep_ = nil
    stepQueue_   = {}
    stepIdx_     = 0
    completed_["tutorial_done"] = true
end

--- 是否当前有教程弹窗在显示
function TutorialSystem.IsActive()
    return active_
end

--- 每帧更新（动画计时）
function TutorialSystem.Update(dt)
    if not active_ then return end
    animT_ = math.min(1, animT_ + dt / ANIM_DUR)
end

-- ============================================================================
-- 内部：入队并开始
-- ============================================================================
function TutorialSystem._Queue(steps)
    for _, s in ipairs(steps) do
        if not completed_[s.id] then
            stepQueue_[#stepQueue_ + 1] = s
        end
    end
    if not active_ and #stepQueue_ > 0 then
        TutorialSystem._ShowNext()
    end
end

function TutorialSystem._ShowNext()
    stepIdx_ = stepIdx_ + 1
    if stepIdx_ > #stepQueue_ then
        active_      = false
        currentStep_ = nil
        return
    end
    currentStep_ = stepQueue_[stepIdx_]
    active_      = true
    animT_       = 0
end

function TutorialSystem._OnConfirm()
    if not currentStep_ then return end
    completed_[currentStep_.id] = true
    if currentStep_.isLast then
        completed_["tutorial_done"] = true
        TutorialSystem.Skip()
        return
    end
    TutorialSystem._ShowNext()
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 主渲染入口（在 GameUI.RenderHUD 最后调用）
function TutorialSystem.Render()
    if not active_ or not currentStep_ then return end

    local vg      = UICommon.vg
    local screenW = UICommon.screenW
    local screenH = UICommon.screenH
    local addHit  = UICommon.addHit

    if not vg or not screenW then return end

    local step = currentStep_
    local ease = animT_ * animT_ * (3 - 2 * animT_)  -- smoothstep

    -- ——— 半透明遮罩（整屏）———
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 20, math.floor(180 * ease)))
    nvgFill(vg)

    -- ——— 高亮区域挖空（topbar）———
    if step.highlight == "topbar" then
        local TOPBAR_H = UICommon.TOPBAR_H or 44
        -- 用加亮描边标记顶部栏
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, screenW, TOPBAR_H + 2)
        nvgFillColor(vg, nvgRGBA(60, 160, 255, math.floor(30 * ease)))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, screenW, TOPBAR_H + 2)
        nvgStrokeColor(vg, nvgRGBA(80, 200, 255, math.floor(220 * ease)))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
    end

    -- ——— 弹窗尺寸与位置 ———
    local PW, PH = 340, 220   -- 面板宽高（基准）
    -- 根据行数自动调整高度
    local lineCount = select(2, step.body:gsub("\n", "\n")) + 1
    PH = 80 + lineCount * 18 + 50

    local px, py
    local anchor = step.anchor or "center"

    if anchor == "center" then
        px = (screenW - PW) / 2
        py = (screenH - PH) / 2
    elseif anchor == "top" then
        px = (screenW - PW) / 2
        py = (UICommon.TOPBAR_H or 44) + 10
    elseif anchor == "bottom" then
        px = (screenW - PW) / 2
        py = screenH - PH - 20
    elseif anchor == "left" then
        px = 16
        py = math.max((UICommon.TOPBAR_H or 48), (screenH - PH) / 2)
    elseif anchor == "right" then
        px = screenW - PW - 16
        py = math.max((UICommon.TOPBAR_H or 48), (screenH - PH) / 2)
    elseif anchor == "topbar" then
        px = (screenW - PW) / 2
        py = (UICommon.TOPBAR_H or 44) + 14
    else
        px = (screenW - PW) / 2
        py = (screenH - PH) / 2
    end

    -- 动画：从屏幕外滑入
    local slideOff = (1 - ease) * 30
    py = py + slideOff

    -- ——— 面板背景 ———
    -- 外层光晕
    local shadow = nvgBoxGradient(vg, px - 4, py - 4, PW + 8, PH + 8, 10, 16,
        nvgRGBA(40, 100, 240, math.floor(80 * ease)),
        nvgRGBA(0, 0, 20, 0))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px - 8, py - 8, PW + 16, PH + 16, 14)
    nvgFillPaint(vg, shadow)
    nvgFill(vg)

    -- 面板本体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, PW, PH, 10)
    nvgFillColor(vg, nvgRGBA(12, 18, 36, math.floor(245 * ease)))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(60, 130, 255, math.floor(200 * ease)))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)

    -- 顶部标题渐变条
    local titleGrad = nvgLinearGradient(vg, px, py, px + PW, py,
        nvgRGBA(20, 60, 180, math.floor(200 * ease)),
        nvgRGBA(40, 20, 120, math.floor(160 * ease)))
    nvgBeginPath(vg)
    nvgRoundedRectVarying(vg, px, py, PW, 34, 10, 10, 0, 0)
    nvgFillPaint(vg, titleGrad)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- ——— 标题文字 ———
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(200, 230, 255, math.floor(255 * ease)))
    nvgText(vg, px + PW / 2, py + 17, step.title or "")

    -- ——— 步骤进度（右上角小字） ———
    local total = #stepQueue_
    if total > 1 then
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(100, 140, 200, math.floor(180 * ease)))
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgText(vg, px + PW - 10, py + 17,
            string.format("%d / %d", stepIdx_, total))
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, px + 16, py + 34)
    nvgLineTo(vg, px + PW - 16, py + 34)
    nvgStrokeColor(vg, nvgRGBA(60, 100, 220, math.floor(100 * ease)))
    nvgStrokeWidth(vg, 0.8)
    nvgStroke(vg)

    -- ——— 正文多行文字 ———
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))

    local textX = px + 18
    local textY = py + 42
    local lineH = 17

    -- 手动按 \n 换行绘制
    local body = step.body or ""
    local lineNum = 0
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        -- 处理•符号的颜色
        if line:sub(1,1) == "•" then
            nvgFillColor(vg, nvgRGBA(100, 200, 255, math.floor(200 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        elseif line:find("^%①") or line:find("^%②") or line:find("^%③") then
            nvgFillColor(vg, nvgRGBA(120, 255, 160, math.floor(220 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        elseif line:find("×") then
            nvgFillColor(vg, nvgRGBA(255, 220, 80, math.floor(220 * ease)))
            nvgText(vg, textX, textY + lineNum * lineH, line)
            nvgFillColor(vg, nvgRGBA(190, 210, 240, math.floor(230 * ease)))
        else
            nvgText(vg, textX, textY + lineNum * lineH, line)
        end
        lineNum = lineNum + 1
    end

    -- ——— 确认按钮 ———
    local btnW, btnH = 120, 28
    local btnX = px + PW - btnW - 16
    local btnY = py + PH - btnH - 14

    -- 跳过按钮（左侧，加背景使其更醒目）
    local skipW, skipH = 80, 26
    local skipX = px + 14
    local skipY = py + PH - skipH - 14
    local skipAlpha = math.floor(220 * ease)
    -- 根据鼠标位置计算跳过按钮悬停状态
    local isSkipHover = false
    if UICommon.cursorX and UICommon.cursorY then
        isSkipHover = UICommon.cursorX >= skipX and UICommon.cursorX <= skipX + skipW
                   and UICommon.cursorY >= skipY and UICommon.cursorY <= skipY + skipH
    end
    skipHover_ = isSkipHover

    -- 按钮背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, skipX, skipY, skipW, skipH, 5)
    nvgFillColor(vg, nvgRGBA(40, 50, 80, math.floor((isSkipHover and 180 or 110) * ease)))
    nvgFill(vg)

    -- 按钮边框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, skipX, skipY, skipW, skipH, 5)
    nvgStrokeColor(vg, nvgRGBA(100, 130, 200, math.floor((isSkipHover and 200 or 130) * ease)))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    -- 按钮文字
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(160, 180, 230, skipAlpha))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, skipX + skipW / 2, skipY + skipH / 2, "跳过教程")

    -- 整个面板区域拦截，防止点击穿透到星图（必须最先注册，优先级最低）
    addHit(px, py, PW, PH, function() end)

    -- 跳过按钮点击区
    addHit(skipX, skipY, skipW, skipH, function()
        TutorialSystem.Skip()
    end)

    -- 确认按钮背景
    local hover = false
    if UICommon.cursorX and UICommon.cursorY then
        hover = UICommon.cursorX >= btnX and UICommon.cursorX <= btnX + btnW
             and UICommon.cursorY >= btnY and UICommon.cursorY <= btnY + btnH
    end
    local fillA = hover and 230 or 200
    local grad = nvgLinearGradient(vg, btnX, btnY, btnX, btnY + btnH,
        nvgRGBA(30, 100, 240, fillA),
        nvgRGBA(15, 60, 160, fillA))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 6)
    nvgFillPaint(vg, grad)
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 160, 255, hover and 255 or 180))
    nvgStrokeWidth(vg, 1.2)
    nvgStroke(vg)

    -- 按钮文字
    nvgFontSize(vg, 11)
    nvgFillColor(vg, nvgRGBA(220, 240, 255, math.floor(255 * ease)))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, step.btnText or "下一步")

    -- 确认按钮点击区（最后注册 = 最高优先级，确保覆盖面板背景拦截）
    addHit(btnX, btnY, btnW, btnH, function()
        TutorialSystem._OnConfirm()
    end)
end

-- ============================================================================
-- 存档支持（与游戏云存档集成）
-- ============================================================================

--- 序列化已完成步骤（用于云存档）
function TutorialSystem.Serialize()
    local out = {}
    for k, v in pairs(completed_) do
        if v then out[#out + 1] = k end
    end
    return out
end

--- 从云存档恢复已完成步骤
function TutorialSystem.Deserialize(list)
    if not list then return end
    for _, k in ipairs(list) do
        completed_[k] = true
    end
end

--- 查询教程是否已全部完成
function TutorialSystem.IsDone()
    return completed_["tutorial_done"] == true
end

return TutorialSystem
