-- ============================================================================
-- game/PirateAI.lua  -- 海盗势力 AI 系统
-- 负责：基地生成、舰队周期进攻、到达触发战斗、胜负后强度调整
-- ============================================================================

local PirateAI = {}
PirateAI.__index = PirateAI

-- ============================================================================
-- 常量
-- ============================================================================
local PIRATE_BASE_COUNT        = 2       -- 海盗基地数量
local PIRATE_BASE_HP           = 100     -- 基地初始血量
local PIRATE_FLEET_SPEED       = 55      -- 海盗舰队移动速度（世界坐标/秒）
local PIRATE_ARRIVE_RADIUS     = 40      -- 到达玩家目标的判定半径（世界坐标）
local PIRATE_ATTACK_INTERVAL   = 210     -- 进攻间隔基准（秒）；实际 = 基准 × factor × jitter
local PIRATE_ATTACK_JITTER_LO  = 0.75   -- 随机抖动下限（原 0.5 → 更长保底冷却）
local PIRATE_ATTACK_JITTER_HI  = 0.55   -- 随机抖动区间长度（0.75~1.30）
local PIRATE_WEAKEN_AMOUNT     = 20      -- 玩家胜利后海盗基地扣血量
local PIRATE_RECOVER_INTERVAL  = 300     -- 海盗基地每 5 分钟恢复 10 HP
local PIRATE_RECOVER_AMOUNT    = 10

-- 动态难度 escalation 常量
local THREAT_CHECK_INTERVAL    = 150     -- 每 150 秒检查一次是否升级（原 120→更缓和）
local COLONY_PER_LEVEL         = 4       -- 每新增 4 个殖民地考虑提升一级（原 3→更缓和）
local TIME_PER_LEVEL           = 720     -- 每 720 秒（12 分钟）考虑提升一级（原 600→更缓和）
local ESCALATION_STREAK_BUFFER = 2       -- 连续击败 N 次后下次 escalation 跳过

-- 海盗基地颜色（深红）
local COLOR_BASE  = {220, 50, 50}
-- 海盗舰队颜色（橙红）
local COLOR_FLEET = {255, 100, 40}

-- ============================================================================
-- 构造函数
-- ============================================================================

---@param opts table
function PirateAI.new(opts)
    local self = setmetatable({}, PirateAI)
    self.notifyFn      = opts.notifyFn      -- function(msg, level)
    self.onAttack      = opts.onAttack      -- function(pirateLevel, baseId) 海盗舰队到达玩家目标时触发
    self.getTargets    = opts.getTargets    -- function() → [{x,y,name}] 玩家可被攻击的位置列表
    self.getProgress   = opts.getProgress   -- function() → {colonized, gameTime, piratesKilled}
    self.bases         = {}                 -- 海盗基地列表
    self.fleets        = {}                 -- 活跃海盗舰队列表
    self.recoverTimer  = 0
    -- 难度参数
    self.attackIntervalFactor = opts.attackIntervalFactor or 1.0  -- 进攻间隔倍率（简单>1, 困难<1）
    self.maxThreatLevel       = opts.maxThreatLevel       or 5    -- 威胁等级上限
    -- 动态难度状态
    self.threatTimer   = 0                  -- 距下次威胁检查计时
    self.streakKills   = 0                  -- 自上次 escalation 后连续击败次数
    self.skipCount     = 0                  -- 因连击缓冲跳过的 escalation 次数
    return self
end

-- ============================================================================
-- 初始化：在星图世界坐标中生成海盗基地
-- ============================================================================

---@param worldRange number  世界半径（约 2000）
function PirateAI:generateBases(worldRange, opts)
    self.bases = {}
    -- P2-2: BIPOLAR 模式下海盗基地集中在中线（x≈0，上/下方）
    local baseAngles
    if opts and opts.bipolar then
        baseAngles = { math.pi * 0.5, math.pi * 1.5 }   -- 正上 / 正下
    else
        -- 两个基地对称分布在星图边缘，角度错开 180°
        baseAngles = { math.pi * 0.25, math.pi * 1.25 }
    end
    for i, angle in ipairs(baseAngles) do
        local dist = worldRange * 0.65 + math.random() * worldRange * 0.25
        self.bases[i] = {
            id          = i,
            x           = math.cos(angle) * dist,
            y           = math.sin(angle) * dist,
            hp          = PIRATE_BASE_HP,
            maxHp       = PIRATE_BASE_HP,
            level       = 1,          -- 1~5，影响出兵波次强度
            attackTimer = PIRATE_ATTACK_INTERVAL * self.attackIntervalFactor * (PIRATE_ATTACK_JITTER_LO + math.random() * PIRATE_ATTACK_JITTER_HI),  -- 首次进攻随机延迟（受难度影响）
            recoverTimer = 0,
            pulse       = math.random() * math.pi * 2,
            active      = true,
        }
    end
    print(string.format("[PirateAI] 生成 %d 个海盗基地", #self.bases))
end

--- P2-2: 战役模式固定海盗基地（位置和等级均预设）
---@param defs table[] { {x, y, level}, ... }
function PirateAI:generateFixedBases(defs)
    self.bases = {}
    for i, def in ipairs(defs) do
        self.bases[i] = {
            id          = i,
            x           = def.x,
            y           = def.y,
            hp          = PIRATE_BASE_HP,
            maxHp       = PIRATE_BASE_HP,
            level       = def.level or 3,
            attackTimer = PIRATE_ATTACK_INTERVAL * self.attackIntervalFactor * (1.5 + i * 0.5),
            recoverTimer = 0,
            pulse       = i * 1.2,
            active      = true,
        }
    end
    print(string.format("[PirateAI] 战役固定基地: %d 个", #self.bases))
end

-- ============================================================================
-- 核心更新（每帧调用）
-- ============================================================================

---@param dt number
function PirateAI:update(dt)
    -- 1. 更新所有活跃海盗基地的攻击计时器
    for _, base in ipairs(self.bases) do
        if not base.active then goto continueBases end
        base.pulse = base.pulse + dt

        -- 情报计时器递减
        if base.intelTimer and base.intelTimer > 0 then
            base.intelTimer = base.intelTimer - dt
            if base.intelTimer <= 0 then
                base.intelTimer = 0
                if self.notifyFn then
                    self.notifyFn(string.format("海盗基地 #%d 情报已失效", base.id), "warn")
                end
            end
        end

        -- 攻击倒计时（M2 修复：levelFactor 最低值 0.4→0.6，高级海盗不再超密）
        base.attackTimer = base.attackTimer - dt
        if base.attackTimer <= 0 then
            self:launchAttack(base)
            local levelFactor = math.max(0.6, 1.0 - (base.level - 1) * 0.08)
            base.attackTimer = PIRATE_ATTACK_INTERVAL * levelFactor * self.attackIntervalFactor * (PIRATE_ATTACK_JITTER_LO + math.random() * PIRATE_ATTACK_JITTER_HI)
        end

        ::continueBases::
    end

    -- 2. 全局基地恢复
    self.recoverTimer = self.recoverTimer + dt
    if self.recoverTimer >= PIRATE_RECOVER_INTERVAL then
        self.recoverTimer = 0
        for _, base in ipairs(self.bases) do
            if base.active and base.hp < base.maxHp then
                base.hp = math.min(base.maxHp, base.hp + PIRATE_RECOVER_AMOUNT)
            end
        end
    end

    -- 2.5 动态难度：定期评估并提升威胁等级
    if self.getProgress then
        self.threatTimer = self.threatTimer + dt
        if self.threatTimer >= THREAT_CHECK_INTERVAL then
            self.threatTimer = 0
            self:evaluateThreat()
        end
    end

    -- 3. 更新所有海盗舰队的移动
    for i = #self.fleets, 1, -1 do
        local fl = self.fleets[i]
        fl.pulse = fl.pulse + dt

        local dx = fl.targetX - fl.x
        local dy = fl.targetY - fl.y
        local d  = math.sqrt(dx * dx + dy * dy)

        if d <= PIRATE_ARRIVE_RADIUS then
            -- 到达目标：触发战斗回调，然后移除该舰队
            if self.onAttack then
                self.onAttack(fl.pirateLevel, fl.baseId, fl.targetName)
            end
            table.remove(self.fleets, i)
        else
            fl.angle = math.atan(dy, dx)
            fl.x = fl.x + (dx / d) * PIRATE_FLEET_SPEED * dt
            fl.y = fl.y + (dy / d) * PIRATE_FLEET_SPEED * dt
        end
    end
end

-- ============================================================================
-- 动态难度评估：根据玩家进展提升海盗威胁等级
-- 每 THREAT_CHECK_INTERVAL 秒调用一次
-- ============================================================================

function PirateAI:evaluateThreat()
    local prog = self.getProgress()
    if not prog then return end

    local colonized    = prog.colonized    or 0
    local gameTime     = prog.gameTime     or 0
    local piratesKilled = prog.piratesKilled or 0

    -- 根据殖民地数量和游戏时间，计算"期望威胁等级"
    -- 期望等级 = max(殖民地驱动, 时间驱动)，上限 5
    local colonyLevel  = 1 + math.floor(colonized / COLONY_PER_LEVEL)
    local timeLevel    = 1 + math.floor(gameTime  / TIME_PER_LEVEL)
    local targetLevel  = math.min(self.maxThreatLevel, math.max(colonyLevel, timeLevel))

    -- 遍历所有活跃基地，尝试提升等级
    for _, base in ipairs(self.bases) do
        if not base.active then goto nextEscBase end

        if base.level < targetLevel then
            -- 检查连击缓冲：玩家最近连续击败 N 次，跳过本次提升
            if self.streakKills >= ESCALATION_STREAK_BUFFER then
                self.skipCount   = self.skipCount + 1
                self.streakKills = 0
                if self.notifyFn then
                    self.notifyFn(
                        string.format("海盗势力因惨败而犹豫，威胁升级暂缓（已跳过 %d 次）", self.skipCount),
                        "info"
                    )
                end
                print(string.format("[PirateAI] escalation 因玩家连击缓冲跳过（streakKills=%d）", ESCALATION_STREAK_BUFFER))
                goto nextEscBase
            end

            -- 升级
            local oldLevel = base.level
            base.level = base.level + 1
            self.streakKills = 0  -- 升级后重置连击计数

            if self.notifyFn then
                local threatName = {"低", "中", "高", "极高", "最高"}
                self.notifyFn(
                    string.format("⚠ 海盗基地 #%d 威胁升至 Lv%d（%s），进攻更加频繁！",
                        base.id, base.level, threatName[base.level] or "未知"),
                    "error"
                )
            end
            print(string.format("[PirateAI] 动态难度：基地%d Lv%d → Lv%d（殖民地=%d 游戏时间=%.0fs）",
                base.id, oldLevel, base.level, colonized, gameTime))
        end

        ::nextEscBase::
    end
end

-- ============================================================================
-- 发起进攻：从指定基地派舰队攻击玩家最近目标
-- ============================================================================

function PirateAI:launchAttack(base)
    -- 获取玩家可被攻击的目标（殖民行星 + 星航基地）
    local targets = self.getTargets and self.getTargets() or {}
    if #targets == 0 then
        -- 玩家尚无目标（游戏早期），延迟进攻
        base.attackTimer = PIRATE_ATTACK_INTERVAL * 0.5
        return
    end

    -- L4: 距离加权随机选目标（近目标概率更高，但非必然）
    -- 权重 = 1/d（距离越近权重越高），随机抽取
    local weights = {}
    local totalW  = 0
    for _, t in ipairs(targets) do
        local d = math.sqrt((base.x - t.x)^2 + (base.y - t.y)^2) + 1  -- +1 防除零
        local w = 1.0 / d
        weights[#weights + 1] = { target=t, w=w }
        totalW = totalW + w
    end
    local nearest = nil
    local roll = math.random() * totalW
    local acc  = 0
    for _, wd in ipairs(weights) do
        acc = acc + wd.w
        if acc >= roll then
            nearest = wd.target
            break
        end
    end
    if not nearest then nearest = weights[#weights].target end  -- 保险兜底

    -- 派出海盗舰队
    local ox = base.x + (math.random() - 0.5) * 60
    local oy = base.y + (math.random() - 0.5) * 60
    local fl = {
        x          = ox,
        y          = oy,
        originX    = ox,   -- P2-1: 保存出发地（用于绘制已行驶路段）
        originY    = oy,
        targetX    = nearest.x,
        targetY    = nearest.y,
        targetName = nearest.name or "未知区域",
        angle      = 0,
        pulse      = 0,
        pirateLevel = base.level,
        baseId     = base.id,
    }
    fl.angle = math.atan(fl.targetY - fl.y, fl.targetX - fl.x)
    self.fleets[#self.fleets + 1] = fl

    local msg = string.format("⚠ 海盗舰队（强度%d）正在进袭 %s！", base.level, fl.targetName)
    if self.notifyFn then self.notifyFn(msg, "error") end
    print(string.format("[PirateAI] 基地%d 派出等级%d舰队 → %s", base.id, base.level, fl.targetName))
end

-- ============================================================================
-- 玩家胜利：削弱指定海盗基地
-- ============================================================================

---@param baseId number
function PirateAI:weakenBase(baseId)
    for _, base in ipairs(self.bases) do
        if base.id == baseId then
            base.hp = math.max(0, base.hp - PIRATE_WEAKEN_AMOUNT)
            if base.hp <= 0 then
                base.active = false
                self.streakKills = self.streakKills + 1  -- 摧毁基地也算连击
                if self.notifyFn then
                    self.notifyFn(string.format("海盗基地 #%d 已被摧毁！", baseId), "success")
                end
                print(string.format("[PirateAI] 基地%d 已摧毁", baseId))
            else
                -- 削弱后降低等级（最低1级）
                if base.hp <= base.maxHp * 0.3 and base.level > 1 then
                    base.level = base.level - 1
                end
                -- 记录玩家获胜连击（用于动态难度缓冲）
                self.streakKills = self.streakKills + 1
                if self.notifyFn then
                    self.notifyFn(string.format("海盗基地 #%d 受损 (HP %d/%d)", baseId, base.hp, base.maxHp), "success")
                end
            end
            return
        end
    end
end

-- ============================================================================
-- 玩家战败：海盗基地强化
-- ============================================================================

---@param baseId number
function PirateAI:strengthenBase(baseId)
    for _, base in ipairs(self.bases) do
        if base.id == baseId and base.active then
            base.level = math.min(5, base.level + 1)
            print(string.format("[PirateAI] 基地%d 强化至等级%d", baseId, base.level))
            return
        end
    end
end

-- ============================================================================
-- 情报系统：侦察任务完成后揭露海盗基地情报
-- ============================================================================

--- 对威胁最高的海盗基地启动情报（由探索任务回调）
--- duration: 情报持续时间（秒），默认 120
--- 同时延缓该基地下次进攻 30 秒（给玩家准备时间）
--- 返回情报摘要字符串（用于通知文本）
function PirateAI:RevealMostThreateningBase(duration)
    duration = duration or 120
    -- 找最近要进攻的基地（攻击倒计时最短且活跃）
    local target = nil
    for _, base in ipairs(self.bases) do
        if base.active then
            if not target or base.attackTimer < target.attackTimer then
                target = base
            end
        end
    end
    if not target then return "未探测到海盗活动" end

    target.intelTimer = duration
    -- 延缓进攻（+30 秒缓冲，惩罚效果）
    target.attackTimer = target.attackTimer + 30
    print(string.format("[PirateAI] 情报揭露基地#%d Lv%d，进攻延迟+30s，情报有效%ds",
        target.id, target.level, duration))
    return string.format("基地#%d Lv%d  进攻倒计时: %ds  HP:%d/%d",
        target.id, target.level, math.ceil(target.attackTimer), target.hp, target.maxHp)
end

-- ============================================================================
-- P1-3: 情报查询 —— 返回当前有效情报数据（供 GameUI 渲染情报面板）
-- ============================================================================

-- 按等级预测舰型编组（±20% 误差在 GameUI 侧呈现）
local FLEET_COMPOSITION = {
    [1] = "护卫舰×3",
    [2] = "护卫舰×2  驱逐舰×1",
    [3] = "护卫舰×1  驱逐舰×2",
    [4] = "驱逐舰×3  巡洋舰×1",
    [5] = "驱逐舰×2  巡洋舰×2",
}

--- 返回所有有效情报条目（intelTimer > 0 的基地）
--- 每条条目：{ id, level, attackTimer, intelTimer, hp, maxHp, x, y, composition }
function PirateAI:GetActiveIntel()
    local result = {}
    for _, base in ipairs(self.bases) do
        if base.active and base.intelTimer and base.intelTimer > 0 then
            -- P1-3: 攻击时间加入 ±20% 随机误差（每条情报固定，避免每帧跳变）
            if not base.intelErrorFactor then
                base.intelErrorFactor = 0.8 + math.random() * 0.4   -- [0.8, 1.2]
            end
            local estimatedAttack = math.ceil(base.attackTimer * base.intelErrorFactor)
            local lvl = math.min(base.level, 5)
            result[#result + 1] = {
                id              = base.id,
                level           = base.level,
                attackTimer     = base.attackTimer,
                estimatedAttack = estimatedAttack,
                intelTimer      = base.intelTimer,
                hp              = base.hp,
                maxHp           = base.maxHp,
                x               = base.x,
                y               = base.y,
                composition     = FLEET_COMPOSITION[lvl] or ("等级" .. base.level .. "编队"),
            }
        else
            -- 情报失效后清除误差因子（下次揭露重新随机）
            base.intelErrorFactor = nil
        end
    end
    return result
end

-- ============================================================================
-- 渲染（由 GalaxyScene 在 Render() 中调用）
-- ============================================================================

---@param vg userdata  NanoVG context
---@param w2s function  world→screen 坐标转换
---@param zoom number   当前缩放级别
function PirateAI:render(vg, w2s, zoom)
    -- 渲染海盗基地
    for _, base in ipairs(self.bases) do
        if not base.active then goto nextBase end
        local sx, sy = w2s(base.x, base.y)
        local pulse  = math.abs(math.sin(base.pulse * 1.2)) * 0.35 + 0.65
        local r      = (10 + (base.level - 1) * 1.5) * zoom

        -- 威胁光晕
        local glowR = r * 2.8 * pulse
        local glow  = nvgRadialGradient(vg, sx, sy, r * 0.5, glowR,
            nvgRGBA(COLOR_BASE[1], COLOR_BASE[2], COLOR_BASE[3], 70),
            nvgRGBA(COLOR_BASE[1], COLOR_BASE[2], COLOR_BASE[3], 0))
        nvgBeginPath(vg); nvgCircle(vg, sx, sy, glowR)
        nvgFillPaint(vg, glow); nvgFill(vg)

        -- 基地主体（六角星形：用两个三角形旋转叠加）
        nvgSave(vg)
        nvgTranslate(vg, sx, sy)
        for rot = 0, 1 do
            nvgSave(vg)
            nvgRotate(vg, rot * math.pi / 3)
            nvgBeginPath(vg)
            for k = 0, 2 do
                local a = k * math.pi * 2 / 3 - math.pi / 2
                local px = math.cos(a) * r
                local py = math.sin(a) * r
                if k == 0 then nvgMoveTo(vg, px, py)
                else nvgLineTo(vg, px, py) end
            end
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(
                COLOR_BASE[1], COLOR_BASE[2], COLOR_BASE[3],
                math.floor((150 + pulse * 60))))
            nvgFill(vg)
            nvgStrokeColor(vg, nvgRGBA(255, 150, 100, math.floor(200 * pulse)))
            nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
            nvgRestore(vg)
        end
        nvgRestore(vg)

        -- HP 条（仅缩放>0.6 时显示）
        if zoom > 0.6 then
            local barW = r * 2.4
            local barX = sx - barW / 2
            local barY = sy + r + 4
            nvgBeginPath(vg); nvgRect(vg, barX, barY, barW, 4)
            nvgFillColor(vg, nvgRGBA(60, 0, 0, 180)); nvgFill(vg)
            nvgBeginPath(vg); nvgRect(vg, barX, barY, barW * (base.hp / base.maxHp), 4)
            nvgFillColor(vg, nvgRGBA(220, 50, 50, 220)); nvgFill(vg)
        end

        -- 情报光环（有效情报时显示青色扫描环）
        local hasIntel = base.intelTimer and base.intelTimer > 0
        if hasIntel then
            local scanR = r * 2.0 + math.abs(math.sin(base.pulse * 3)) * r * 0.5
            nvgBeginPath(vg); nvgCircle(vg, sx, sy, scanR)
            nvgStrokeColor(vg, nvgRGBA(60, 240, 220, math.floor(120 * (base.intelTimer / 120))))
            nvgStrokeWidth(vg, 1.5); nvgStroke(vg)
        end

        -- 标签（有情报时显示完整信息，无情报时隐藏进攻倒计时）
        if zoom > 0.5 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, math.max(8, 10 * zoom))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            local labelY = sy + r + 10
            if hasIntel then
                -- 有情报：显示倒计时、HP、情报剩余时间
                local atStr = base.attackTimer > 0
                    and string.format("⚡基地Lv%d  进攻: %ds", base.level, math.ceil(base.attackTimer))
                    or  string.format("⚡基地Lv%d  出击中!", base.level)
                nvgFillColor(vg, nvgRGBA(80, 240, 220, 230))
                nvgText(vg, sx, labelY, atStr)
                nvgFontSize(vg, math.max(7, 9 * zoom))
                nvgFillColor(vg, nvgRGBA(60, 200, 180, 180))
                nvgText(vg, sx, labelY + 12, string.format("HP:%d/%d  情报:%ds", base.hp, base.maxHp, math.ceil(base.intelTimer)))
            else
                -- 无情报：只显示等级，不透露倒计时
                nvgFillColor(vg, nvgRGBA(255, 120, 80, 200))
                nvgText(vg, sx, labelY, string.format("海盗基地Lv%d", base.level))
            end
        end

        ::nextBase::
    end

    -- 渲染海盗舰队
    for _, fl in ipairs(self.fleets) do
        local sx, sy = w2s(fl.x, fl.y)
        local pulse  = math.abs(math.sin(fl.pulse * 2.5)) * 0.4 + 0.6
        local r      = (8 + (fl.pirateLevel - 1) * 1) * zoom

        -- P2-1: 增强航迹线——已行驶路段（灰色虚线）+ 剩余路段（彩色动态虚线箭头）+ 目标警告圈
        local tx, ty = w2s(fl.targetX, fl.targetY)
        -- 颜色随海盗等级加深：Lv1=橙黄, Lv4=深红
        local lvRatio = math.min(1.0, (fl.pirateLevel - 1) / 3)
        local pathR = math.floor(255)
        local pathG = math.floor(160 - lvRatio * 120)  -- 160→40
        local pathB = math.floor(40  - lvRatio * 40)   -- 40→0

        -- ① 已行驶路段：出发地 → 当前位置（灰色半透明虚线）
        if fl.originX then
            local ox2, oy2 = w2s(fl.originX, fl.originY)
            local dx2, dy2 = sx - ox2, sy - oy2
            local segLen2 = math.sqrt(dx2*dx2 + dy2*dy2)
            if segLen2 > 2 then
                local dashL2, gapL2 = 8, 6
                local steps2 = math.floor(segLen2 / (dashL2 + gapL2))
                local ux2, uy2 = dx2/segLen2, dy2/segLen2
                nvgBeginPath(vg)
                for s = 0, steps2 - 1 do
                    local t0 = s * (dashL2 + gapL2)
                    local t1 = math.min(t0 + dashL2, segLen2)
                    nvgMoveTo(vg, ox2 + ux2*t0, oy2 + uy2*t0)
                    nvgLineTo(vg, ox2 + ux2*t1, oy2 + uy2*t1)
                end
                nvgStrokeColor(vg, nvgRGBA(160, 160, 160, 55))
                nvgStrokeWidth(vg, 1.0 * zoom); nvgStroke(vg)
            end
        end

        -- ② 剩余路段：当前位置 → 目标（动态流动虚线，由 fl.pulse 驱动）
        local rdx, rdy = tx - sx, ty - sy
        local rLen = math.sqrt(rdx*rdx + rdy*rdy)
        if rLen > 2 then
            local dashL, gapL = 10, 7
            local period = dashL + gapL
            local flowOffset = (fl.pulse * 40) % period   -- 每秒流动 40px
            local rux, ruy = rdx/rLen, rdy/rLen
            nvgBeginPath(vg)
            local startD = flowOffset - period
            while startD < rLen do
                local d0 = math.max(0, startD)
                local d1 = math.min(rLen, startD + dashL)
                if d1 > d0 then
                    nvgMoveTo(vg, sx + rux*d0, sy + ruy*d0)
                    nvgLineTo(vg, sx + rux*d1, sy + ruy*d1)
                end
                startD = startD + period
            end
            nvgStrokeColor(vg, nvgRGBA(pathR, pathG, pathB, 170))
            nvgStrokeWidth(vg, 1.5 * zoom); nvgStroke(vg)

            -- ② 箭头头部（目标方向）
            local arrowDist = math.max(0, rLen - 12 * zoom)
            local ax = sx + rux * arrowDist
            local ay = sy + ruy * arrowDist
            local perpX, perpY = -ruy, rux
            local arrowSize = 5 * zoom
            nvgBeginPath(vg)
            nvgMoveTo(vg, tx, ty)
            nvgLineTo(vg, ax + perpX*arrowSize, ay + perpY*arrowSize)
            nvgLineTo(vg, ax - perpX*arrowSize, ay - perpY*arrowSize)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(pathR, pathG, pathB, 200))
            nvgFill(vg)
        end

        -- ③ 目标位置警告圈（双圈脉冲动画）
        local warnPulse = math.abs(math.sin(fl.pulse * 3.0))
        local warnR1 = (14 + warnPulse * 8) * zoom
        local warnR2 = (22 + warnPulse * 6) * zoom
        -- 外圈（浅色，快速脉冲）
        nvgBeginPath(vg)
        nvgCircle(vg, tx, ty, warnR2)
        nvgStrokeColor(vg, nvgRGBA(pathR, pathG, pathB, math.floor(60 * (1 - warnPulse))))
        nvgStrokeWidth(vg, 1.0 * zoom); nvgStroke(vg)
        -- 内圈（深色，持续显示）
        nvgBeginPath(vg)
        nvgCircle(vg, tx, ty, warnR1)
        nvgStrokeColor(vg, nvgRGBA(pathR, pathG, pathB, math.floor(100 + warnPulse * 80)))
        nvgStrokeWidth(vg, 1.2 * zoom); nvgStroke(vg)
        -- 十字准星
        local crossSize = 5 * zoom
        nvgBeginPath(vg)
        nvgMoveTo(vg, tx - crossSize, ty); nvgLineTo(vg, tx + crossSize, ty)
        nvgMoveTo(vg, tx, ty - crossSize); nvgLineTo(vg, tx, ty + crossSize)
        nvgStrokeColor(vg, nvgRGBA(pathR, pathG, pathB, math.floor(120 + warnPulse * 100)))
        nvgStrokeWidth(vg, 1.0 * zoom); nvgStroke(vg)

        -- 引擎尾焰
        local tailX = sx - math.cos(fl.angle) * r * 1.6
        local tailY = sy - math.sin(fl.angle) * r * 1.6
        local flameG = nvgLinearGradient(vg, sx, sy, tailX, tailY,
            nvgRGBA(255, 80, 20, 200), nvgRGBA(255, 80, 20, 0))
        nvgBeginPath(vg)
        nvgMoveTo(vg, tailX + math.cos(fl.angle+math.pi/2)*3*zoom, tailY + math.sin(fl.angle+math.pi/2)*3*zoom)
        nvgLineTo(vg, sx, sy)
        nvgLineTo(vg, tailX - math.cos(fl.angle+math.pi/2)*3*zoom, tailY - math.sin(fl.angle+math.pi/2)*3*zoom)
        nvgClosePath(vg); nvgFillPaint(vg, flameG); nvgFill(vg)

        -- 船体（箭头形，红色）
        nvgSave(vg)
        nvgTranslate(vg, sx, sy)
        nvgRotate(vg, fl.angle)
        nvgBeginPath(vg)
        nvgMoveTo(vg,  r*1.2, 0)
        nvgLineTo(vg, -r*0.8,  r*0.6)
        nvgLineTo(vg, -r*0.4, 0)
        nvgLineTo(vg, -r*0.8, -r*0.6)
        nvgClosePath(vg)
        nvgFillColor(vg, nvgRGBA(COLOR_FLEET[1], COLOR_FLEET[2], COLOR_FLEET[3], math.floor(200 + pulse*50)))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(255, 200, 180, 160))
        nvgStrokeWidth(vg, 1.2); nvgStroke(vg)
        nvgRestore(vg)

        -- 标签
        if zoom > 0.5 then
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, math.max(8, 9 * zoom))
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 150, 100, 220))
            nvgText(vg, sx, sy + r + 3, "海盗 Lv" .. fl.pirateLevel)
        end
    end

    -- 在小地图上标注海盗基地（由 drawMinimapExtras 调用）
end

-- ============================================================================
-- 小地图渲染扩展（供 GalaxyScene 在 drawMinimap 内部调用）
-- ============================================================================

---@param vg userdata
---@param offX number  小地图世界原点像素 X
---@param offY number  小地图世界原点像素 Y
---@param scaleX number
---@param scaleY number
function PirateAI:renderMinimap(vg, offX, offY, scaleX, scaleY)
    for _, base in ipairs(self.bases) do
        if not base.active then goto nextMM end
        local bx = offX + base.x * scaleX
        local by = offY + base.y * scaleY
        nvgBeginPath(vg)
        nvgCircle(vg, bx, by, 3.5)
        nvgFillColor(vg, nvgRGBA(220, 50, 50, 220))
        nvgFill(vg)
        ::nextMM::
    end
    for _, fl in ipairs(self.fleets) do
        local fx = offX + fl.x * scaleX
        local fy = offY + fl.y * scaleY
        nvgBeginPath(vg)
        nvgCircle(vg, fx, fy, 2)
        nvgFillColor(vg, nvgRGBA(255, 100, 40, 200))
        nvgFill(vg)
    end
end

-- ============================================================================
-- 存档 / 读档
-- ============================================================================

function PirateAI:serialize()
    local bases = {}
    for i, b in ipairs(self.bases) do
        bases[i] = {
            id = b.id, x = b.x, y = b.y,
            hp = b.hp, maxHp = b.maxHp, level = b.level,
            attackTimer = b.attackTimer, active = b.active,
            intelTimer = b.intelTimer or 0,
        }
    end
    -- M7: 保存全局恢复计时器，避免读档后计时器归零
    return {
        bases        = bases,
        recoverTimer = self.recoverTimer,
        threatTimer  = self.threatTimer,
        streakKills  = self.streakKills,
        skipCount    = self.skipCount,
    }
end

function PirateAI:deserialize(data)
    if not data or not data.bases then return end
    for i, bd in ipairs(data.bases) do
        local base = self.bases[i]
        if base then
            base.hp          = bd.hp          or base.maxHp
            base.level       = bd.level       or 1
            base.attackTimer = bd.attackTimer or PIRATE_ATTACK_INTERVAL
            base.active      = (bd.active ~= false)
            base.intelTimer  = bd.intelTimer  or 0
        end
    end
    -- M7: 恢复全局恢复计时器
    self.recoverTimer = data.recoverTimer or 0
    -- 恢复动态难度状态
    self.threatTimer  = data.threatTimer  or 0
    self.streakKills  = data.streakKills  or 0
    self.skipCount    = data.skipCount    or 0
    print("[PirateAI] 读档完成")
end

return PirateAI


-- NOTE: 此文件已被 code_health_check.py 自动拆分，详见同目录 *_part*.lua 文件。
