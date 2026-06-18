---@diagnostic disable: local-limit, assign-type-mismatch
-- ============================================================================
-- game/BattleScene.lua  -- 战术战斗场景
-- ============================================================================

local Audio        = require("game.AudioManager")
local UICommon     = require("game.ui.UICommon")
local BattleSkills = require("game.BattleSkills")
local Achievement  = require("game.AchievementSystem")   -- P2-3: 成就奖励应用
local Systems      = require("game.Systems")
local SHIP_MODULES = Systems.SHIP_MODULES                -- P1-1: 模块定义查找
local NemesisSystem = require("game.NemesisSystem")      -- P1-2: 宿敌系统
local AnomalySystem = require("game.AnomalySystem")      -- P2-1: 星域异象系统
local BattleReplaySystem = require("game.BattleReplaySystem") -- P3-1: 战斗回放系统
local Commander = require("game.CommanderSystem")             -- P1-3 V2.4: 指挥官系统
local SettingsPanel = require("game.ui.SettingsPanel")        -- P3-3: 画质档位读取
local LiverySystem  = require("game.LiverySystem")            -- P2-3 V2.4: 舰队涂装
local BattleState   = require("game.battle.BattleState")          -- P3-1c: 共享状态
local BattleRender  = require("game.battle.BattleRender")         -- P3-1c: 渲染模块
local FormationEditor = require("game.ui.FormationEditor")        -- P2-1 V2.5: 自定义阵型
local BattleAI        = require("game.battle.BattleAI")               -- P3-1a: 工厂/波次/阵型/被动
-- P3-2: 战斗逻辑子模块（Update 委托）
local BattleContext      = require("game.battle.BattleContext")
local BattleTimers       = require("game.battle.BattleTimers")
local BattleCombatPlayer = require("game.battle.BattleCombatPlayer")
local BattleCombatEnemy  = require("game.battle.BattleCombatEnemy")
local BattleDeath        = require("game.battle.BattleDeath")
local BattleVFX          = require("game.battle.BattleVFX")
local BattleWinLose      = require("game.battle.BattleWinLose")
local ctx = BattleContext  -- 共享状态上下文（Update 内通过 sync 桥与本地状态同步）

local BattleScene = {}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600

-- 舰船纹理（NanoVG image handles）
local shipImages_   = {}  -- { SCOUT=handle, FRIGATE=handle, DESTROYER=handle, MINER=handle }

local playerFleet_  = {}
local enemyFleet_   = {}
local projectiles_  = {}   -- {x,y,tx,ty,team,life}
local floatTexts_   = {}   -- {x,y,text,life,maxLife,vy,team}
local moveTarget_   = nil  -- 玩家舰队移动目标点
local moveTargetTimer_ = 0 -- 移动目标点自动消失计时
local leagueAttackMult_ = 1.0  -- P1-3: 联赛敌人攻击力修正

local state_        = "fighting"  -- "fighting" | "win" | "lose"
local stateTimer_   = 0
local battleEndFired_ = false  -- 防止 onBattleEnd_ 被每帧重复触发
local shootSfxTimer_ = 0       -- 射击音效节流（避免同帧多舰齐射时音效叠加爆音）
local loseBtn1_     = nil      -- M2: 战败"重新战斗"按钮区域
local loseBtn2_     = nil      -- M2: 战败"返回星图"按钮区域
-- P3-3: 波次星级评分
local initialPlayerCount_ = 0   -- 本波开始时我方舰队数量（用于存活率计算）
local currentWaveStar_    = 0   -- 本波评分（1-3 星，0 = 未决定）
local starAnim_           = 0   -- 星级出现动画计时器（胜利后开始计时）
local notifyFn_     = nil
local onBattleEnd_  = nil  -- 回调：战斗结束
local player_       = nil
local rm_           = nil  -- ResourceManager 引用（用于波次奖励）
local rs_           = nil  -- ResearchSystem 引用（技能解锁判断）
local spq_          = nil  -- ShipProductionQueue 引用
-- P1-3 V2.4: 指挥官系统
local commanderBonus_   = nil  -- {dmgMult, healthMult, resourceMult}
local commanderFleetId_ = nil  -- 当前战斗编队ID
local cmdSkillActive_   = false -- 指挥官技能是否激活中
local cmdSkillTimer_    = 0     -- 技能剩余持续时间
local cmdSkillDef_      = nil   -- 激活的技能定义

-- 波次系统
local waveNum_      = 1     -- 当前波次
local WAVE_GAP      = 8.0   -- P2-3: 备战期扩展至8秒（原3秒）
local waveGapTimer_ = 0     -- 倒计时
local prepSkipped_  = false -- P2-3: 玩家按SPACE跳过备战期

-- Boss波次系统
local BOSS_WAVE_INTERVAL = 5   -- 每隔5波出现一次Boss波（wave 5, 10, 15...）
local bossWarningTimer_  = 0   -- Boss警告横幅显示计时（>0 时显示）
local BOSS_WARNING_DUR   = 2.5 -- Boss警告显示时长（秒）
local bossDefeated_      = false  -- 当前波次Boss是否已被击败（防止重复奖励）

-- 新生产出的舰船临时存储（等待加入战场）
local pendingShips_ = {}

-- 燃烧粒子系统（低血量舰船火焰效果）
local fireParticles_ = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,size}
local fireTimer_     = 0   -- 粒子生成节流

-- 爆炸粒子系统（舰船被摧毁时的碎片爆炸）
local explParticles_ = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,size,type}

-- 击中火花系统（投射物命中时的瞬间火花）
local hitSparks_     = {}  -- {x,y,vx,vy,life,maxLife,r,g,b}

-- 冲击波环系统（大型武器/AOE 命中时扩张光环）
local shockRings_    = {}  -- {x,y,radius,maxRadius,life,maxLife,r,g,b,width}

-- 屏幕震动系统
local SK_ = {
    timer    = 0,   -- 震动剩余时间
    dur      = 0,   -- 震动总时长
    strength = 0,   -- 震动强度（像素）
    offX     = 0,   -- 当前帧震动偏移 X
    offY     = 0,   -- 当前帧震动偏移 Y
}

-- 烟花粒子系统（波次胜利特效）
local fwParticles_   = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,tail}
local fwLaunchTimer_ = 0   -- 下次发射烟花的倒计时

-- INTERCEPTOR 引擎音效节流
local interceptorEngineTimer_ = 0   -- 距离下次允许播放的冷却（秒）

-- P3-2: 全屏闪光 + Boss 横幅
local bossFlashAlpha_  = 0    -- 全屏白光透明度（0-255，衰减至0）
local bossFlashTimer_  = 0    -- 横幅显示倒计时（秒）
local BOSS_BANNER_DUR  = 2.5  -- 横幅显示时长

-- P2-3: 无尽模式里程碑 Boss 系统
local endlessRound_       = 0     -- 当前无尽层数（由 Client.lua 注入）
local milestoneFlashAlpha_= 0     -- 里程碑全屏红色闪光
local milestoneBannerTimer_= 0    -- 里程碑"第N层 通关！"横幅计时
local MILESTONE_BANNER_DUR = 4.0  -- 横幅显示时长（秒）
local milestoneRound_      = 0    -- 本次里程碑对应的层数（渲染用）

-- P3-2 V2.0: 血条低血闪烁计时器（持续累加，用 sin 产生闪烁波形）
local hpBlinkTimer_    = 0    -- 累加计时，sin(hpBlinkTimer_ * 2π / 0.5) 产生闪烁

-- P1-2: 战斗撤退 / 紧急增援系统
local retreatUsed_       = false  -- 每场战斗只能撤退一次
local retreatBtn_        = nil    -- 撤退按钮点击区域
local reinforceBtn_      = nil    -- 增援按钮点击区域
local reinforceCooldown_ = 0      -- 增援冷却（防连刷，秒）
local REINFORCE_COST_METAL   = 50
local REINFORCE_COST_CRYSTAL = 50
local RETREAT_COST_ENERGY    = 30 -- 撤退消耗能源

-- P2-2: 技能升级弹窗系统
local skillUpgradeCards_ = nil  -- nil=无弹窗；{n1,n2}=等待玩家选择的技能编号列表
local skillUpgradeCardBtns_ = {} -- 卡片点击区域列表

-- P2-2: 夹击模式
local isPincerWave_   = false  -- 本波是否为夹击波次（25%概率）
local pincerDefended_ = false  -- 本波已成功防守夹击（胜利时触发成就）
local pincerAnnounceTimer_ = 0 -- 夹击公告横幅显示计时（>0 时显示）
local PINCER_ANNOUNCE_DUR  = 2.2 -- 夹击公告时长（秒）

-- P1-2: 宿敌系统（战斗侧状态）
local nemesisActive_       = false  -- 当前波次是否为宿敌遭遇
local nemesisAnnounceTimer_= 0      -- 宿敌出场公告计时（>0 时显示横幅）
local NEMESIS_ANNOUNCE_DUR = 3.5    -- 宿敌出场公告时长（秒）
local nemesisResult_       = nil    -- 本波宿敌战后结果（OnPlayerWin/Lose 返回值，用于UI展示）
local nemesisResultTimer_  = 0      -- 宿敌结果展示计时
local NEMESIS_RESULT_DUR   = 4.0    -- 结果展示时长（秒）

-- P2-1: 星域异象
local anomalyNotify_      = nil    -- 新异象通知 {name,icon,desc,color,duration} (显示3秒后清除)
local anomalyNotifyTimer_ = 0      -- 异象通知剩余时间
local ANOMALY_NOTIFY_DUR  = 3.5    -- 异象通知显示时长

-- P2-1: 战中增援系统
local RF_ = {
    pending        = false,  -- 本波是否将触发增援（波次开始时15%概率）
    warning        = 0,      -- 增援预警倒计时（>0 显示预警条）
    spawned        = false,  -- 本波增援是否已生成
    remain         = 0,      -- 尚存活的增援舰船数量
    defeated       = false,  -- 本波是否已全歼增援（用于逆境奖励）
    startEnemyCnt  = 0,      -- 本波开始时的初始敌舰数量（用于50%判定）
    WARN_DUR       = 3.0,    -- 增援预警时长（秒）
    PROB           = 0.15,   -- 增援触发概率
    MIN_WAVE       = 5,      -- 最早触发波次
}

-- P1-1: 舰船被动专属能力
local scoutAuraApplied_      = false  -- SCOUT先敌洞察：本波是否已施加压制（每波一次）
local engineerHealTimer_     = 0      -- ENGINEER战场维修：回复计时
local ENGINEER_HEAL_INTERVAL = 30.0   -- 工程师回复间隔（秒）
local ENGINEER_HEAL_AMOUNT   = 10     -- 工程师每次回复量（HP）
---@type table|nil
local explorerMarkTarget_    = nil    -- EXPLORER图绘先行：当前标记敌舰（最高HP）
local DESTROYER_PIERCE_COUNT = 5      -- 穿甲弹触发间隔（每N次攻击触发一次）
local INTERCEPTOR_SPD_MULT   = 1.30   -- INTERCEPTOR攻速加成倍率
local FRIGATE_SHARE_RATIO    = 0.20   -- FRIGATE协同护卫：分担伤害比例
local BATTLECRUISER_BLOCK    = 0.10   -- BATTLECRUISER重甲要塞：格挡概率
local CARRIER_FIGHTER_LIFE   = 5.0    -- CARRIER舰载机群：临时战斗机存活时间（秒）

-- P1-1: 改装模块系统（战斗侧）
local moduleMap_    = {}   -- { [shipType] = moduleKey } 从 Init 传入
-- P1-2 V2.5: 变异舰船系统（战斗侧）
local mutantMap_    = {}   -- { [shipType] = { id, baseType, affixes={key,...} } } 从 Init 传入

-- P3-1: 动态背景星星系统
local bgStars_    = {}   -- {x,y,r,alpha,speed,twinklePhase,twinkleSpeed,layer}
local bgScrollX_  = 0    -- 视差滚动偏移 X（layer 1 最慢）
local bgScrollY_  = 0    -- 视差滚动偏移 Y
local BG_SCROLL_VX = 4   -- 每秒滚动速度 X（像素）
local BG_SCROLL_VY = 1   -- 每秒滚动速度 Y（像素）

-- P1-2: 战斗环境系统
---@type table
local BATTLE_ENVIRONMENTS = {
    NONE = {
        key   = "NONE",
        label = "无",
        icon  = "",
        desc  = "",
        bgR = 0, bgG = 5, bgB = 16,       -- 背景色调（正常深蓝）
        -- 数值修正（均为乘数，1.0 = 无影响）
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 1.0,
        asteroidDamage   = 0,
        -- 粒子类型（"none" | "nebula" | "asteroid" | "magstor"）
        particleType = "none",
    },
    NEBULA = {
        key   = "NEBULA",
        label = "星云",
        icon  = "☁",
        desc  = "浓密星云降低能见度，敌方射程 -25%",
        bgR = 8,  bgG = 0,  bgB = 22,
        enemyRangeMult   = 0.75,  -- 敌方射程折减
        shieldAbsorb     = 1.0,
        asteroidDamage   = 0,
        particleType = "nebula",
        -- 粒子颜色（蓝紫雾气）
        pR = 80, pG = 40, pB = 200,
    },
    ASTEROID = {
        key   = "ASTEROID",
        label = "小行星带",
        icon  = "☄",
        desc  = "飞石频繁撞击，每2秒随机舰船受到碎片伤害",
        bgR = 12, bgG = 8,  bgB = 5,
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 1.0,
        asteroidDamage   = 12,    -- 每次碎片伤害值
        asteroidInterval = 2.0,   -- 碎片间隔（秒）
        particleType = "asteroid",
        pR = 140, pG = 110, pB = 60,
    },
    MAGSTOR = {
        key   = "MAGSTOR",
        label = "磁暴",
        icon  = "⚡",
        desc  = "强烈磁暴干扰护盾系统，护盾吸收率 -40%",
        bgR = 0,  bgG = 12, bgB = 8,
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 0.60,  -- 护盾吸收率（原本100%→60%）
        asteroidDamage   = 0,
        particleType = "magstor",
        pR = 40, pG = 220, pB = 120,
    },
}
-- 环境池（出现概率：70% 随机一种，30% 无）
local ENV_POOL = { "NEBULA", "ASTEROID", "MAGSTOR" }

---@type table
local currentEnv_       = BATTLE_ENVIRONMENTS.NONE  -- 当前环境配置
local envParticles_     = {}   -- 环境背景粒子 {x,y,vx,vy,life,maxLife,r,g,b,size,alpha}
local envTimer_         = 0    -- 通用环境计时器（小行星带伤害倒计时 / 磁暴闪烁）
local envAsteroidTimer_ = 0    -- 小行星带伤害计时
local envAnnounceAlpha_ = 0    -- 环境公告横幅透明度（战斗开始时显示 1.5 秒）
local envAnnounceTimer_ = 0    -- 环境公告计时（>0 时显示）
local ENV_ANNOUNCE_DUR  = 2.0  -- 公告显示时长（秒）

-- P1-1: FORTRESS_PROTOCOL 护盾回复计时器
local fortressRegenTimer_ = 0   -- 每 10s 为玩家舰队回复 shieldRegenPct 的 HP

-- P1-1: 波次战斗摘要
local waveKills_       = 0    -- 本波击杀数
local waveMaxCombo_    = 0    -- 本波最高连击
local waveDmgDealt_    = 0    -- 本波造成伤害
local waveShipsLost_   = 0    -- 本波损失舰船数
local waveSummary_     = nil  -- 上波摘要快照 {wave,kills,maxCombo,dmg,lost,reward}
-- P2-1 V2.0: 每轮无尽战斗击杀率追踪（用于连胜判定）
local waveEnemyTotal_  = 0    -- 本场战斗敌人生成总数（跨所有波次累加）
local waveKillTotal_   = 0    -- 本场战斗实际击杀总数
local WAVE_SUMMARY_DUR = 2.8  -- 摘要显示时长（显示在 win 阶段结束前）

-- P2-2: 单舰信息面板 + 集火指令
local selectedShip_    = nil  -- 当前选中的舰船引用（nil = 未选中）
local focusTarget_     = nil  -- 集火目标（仅敌方，nil = 无集火）

-- P1-3: 战斗连锁反应
local chainCount_      = 0     -- 本场战斗连锁触发次数
local CHAIN_RADIUS     = 80    -- 连锁 AOE 半径（px）
local CHAIN_AOE_PCT    = 0.20  -- AOE 伤害占目标最大生命值比例
local CHAIN_MIN_KILLS  = 3     -- 触发连锁所需同帧击杀数

-- P2-3: 阵型战术系统（4种阵型，仅备战期可选）
-- "wedge"=锋矢  "circle"=圆环  "scatter"=散兵  "charge"=冲锋
local currentFormation_ = "wedge"
local formationBtn_ = {}   -- 5个按钮点击区域 {x,y,w,h,key,locked}
local formationLocked_ = false  -- 战斗开始后锁定阵型
-- 阵型配置
local FORMATION_CONFIG = {
    wedge = {
        label = "锋矢阵",
        icon  = "🔺",
        desc  = "前排攻+20% 后排受击-30%",
        color = {255, 110, 80},
        -- 舰船布置：V型前突
        posX       = 140,
        posXSpread = 40,
        posYBase   = 0,
        posYSpread = 50,
        speedMult  = 1.00,
        dmgMult    = 1.00,   -- 前排+20%在战斗逻辑中单独判断
        healthMult = 1.00,
        shotRateMult = 1.00,
        -- 特殊：前排攻击力+20%，后排受击概率-30%
        mechanic   = "wedge_frontback",
    },
    circle = {
        label = "圆环阵",
        icon  = "⭕",
        desc  = "伤害均摊 修复+50%",
        color = {80, 200, 255},
        posX       = 110,
        posXSpread = 35,
        posYBase   = 0,
        posYSpread = 0,   -- 特殊：圆形排列
        speedMult  = 1.00,
        dmgMult    = 1.00,
        healthMult = 1.00,
        shotRateMult = 1.00,
        -- 特殊：伤害均摊到全队，ENGINEER修复+50%
        mechanic   = "circle_share",
        engineerHealMult = 1.5,
    },
    scatter = {
        label = "散兵阵",
        icon  = "✦",
        desc  = "AOE减半 无协同护卫",
        color = {120, 230, 150},
        posX       = 120,
        posXSpread = 60,
        posYBase   = 0,
        posYSpread = 80,
        speedMult  = 1.00,
        dmgMult    = 1.00,
        healthMult = 1.00,
        shotRateMult = 1.00,
        -- 特殊：AOE伤害减半，但禁用协同护卫
        mechanic   = "scatter_aoe",
        aoeDmgMult = 0.5,
        disableFrigateShare = true,
    },
    charge = {
        label = "冲锋阵",
        icon  = "⚡",
        desc  = "攻速+30% HP-15%",
        color = {255, 200, 50},
        posX       = 160,
        posXSpread = 20,
        posYBase   = 0,
        posYSpread = 40,
        speedMult  = 1.10,
        dmgMult    = 1.00,
        healthMult = 0.85,   -- HP-15%
        shotRateMult = 0.70, -- 攻速+30%（shotRate越低射速越快）
        mechanic   = "charge_speed",
    },
    -- P2-1 V2.5: 自定义阵型（从阵型编辑器读取坐标，无属性加成）
    custom = {
        label = "自定义",
        icon  = "✎",
        desc  = "编辑器布置 无加成",
        color = {200, 160, 255},
        posX       = 120,
        posXSpread = 40,
        posYBase   = 0,
        posYSpread = 60,
        speedMult  = 1.00,
        dmgMult    = 1.00,
        healthMult = 1.00,
        shotRateMult = 1.00,
        mechanic   = "custom_editor",
    },
}

-- ============================================================================
-- 连击系统
-- ============================================================================
local COMBO_RESET_TIME  = 5.0   -- 无击杀后连击重置时间（秒）P2-2: 5s窗口
local COMBO_LEVELS = {          -- {minCombo, mult, label}
    { min = 20, mult = 2.0,  label = "ULTRA COMBO!" },
    { min = 10, mult = 1.5,  label = "MEGA COMBO!"  },
    { min = 5,  mult = 1.25, label = "GREAT COMBO!" },
    { min = 3,  mult = 1.1,  label = "COMBO!"       },  -- P2-2: 门槛3连击
}

local comboCount_       = 0     -- 当前连击数
local comboTimer_       = 0     -- 距离重置的计时器
local comboDisplayTimer_= 0     -- 连击数显示渐隐计时器（>0 时显示）

local function getComboLevel()
    for _, lv in ipairs(COMBO_LEVELS) do
        if comboCount_ >= lv.min then return lv end
    end
    return nil
end

-- ============================================================================
-- 战斗统计（每场战斗累计，通过 BattleScene.GetStats() 导出）
-- ============================================================================
local battleStats_ = {
    dmgDealt     = 0,   -- 我方造成总伤害
    dmgTaken     = 0,   -- 我方承受总伤害
    enemiesKilled= 0,   -- 击落敌舰数量
    wavesCleared = 0,   -- 通关波次数
    bestSurvivor = nil, -- 存活最久的舰型（最大 survivedWaves 的舰型）
    -- P2-3: 隐藏成就统计
    shipsLost     = 0,   -- 本场战斗我方损失舰船数
    overkillMax   = 0,   -- 单目标最大过度击杀倍率（dmg / maxHealth）
    focusBossKill = false,-- 是否用集火指令击毁 BOSS
    focusKillCount= 0,   -- 集火击杀数
    chainCount    = 0,   -- P1-3: 连锁反应触发次数
    reinforceWin  = false, -- P2-1: 本场是否全歼增援
}

-- ============================================================================
-- P2-2b: 战斗日志（记录关键事件，最多 30 条）
-- ============================================================================
local BATTLE_LOG_MAX = 30
local battleLog_ = {}        -- { {wave=N, text="..."}, ... }
local fleetName_ = "舰队"   -- 由 Init(opts.fleetName) 传入

--- 添加一条战斗日志（FIFO，超过上限移除最旧条目）
local function logBattleEvent(text)
    battleLog_[#battleLog_ + 1] = { wave = waveNum_, text = text }
    if #battleLog_ > BATTLE_LOG_MAX then
        table.remove(battleLog_, 1)
    end
end

-- ============================================================================
-- 舰船工厂
-- ============================================================================
local function makeShip(stype, x, y, team)
    local cfg = SHIP_TYPES[stype]
    -- S1 HULL_ALLOY / ADVANCED_WEAPONS: 玩家舰队应用科技加成
    local hm = 1.0
    local dm = 1.0
    if team == "player" and rm_ and rm_.baseBonus then
        hm = rm_.baseBonus.shipHealthMult or 1.0
        dm = rm_.baseBonus.shipDmgMult    or 1.0
    end
    -- P1-3 V2.4: 指挥官被动加成（叠加）
    if team == "player" and commanderBonus_ then
        hm = hm * (1.0 + (commanderBonus_.healthMult or 0))
        dm = dm * (1.0 + (commanderBonus_.dmgMult or 0))
    end
    local hp = math.floor(cfg.health * hm)
    local ship = {
        x        = x,      y=y,
        vx       = 0,      vy=0,
        team     = team,
        stype    = stype,
        speed    = cfg.speed,
        health   = hp,
        maxHealth= hp,
        range    = cfg.range,
        dmg      = cfg.dmg * dm,
        color    = cfg.color,
        lastShot = 0,
        -- P1-1 INTERCEPTOR: 超音速穿越 — 玩家拦截舰攻速+30%
        shotRate  = (cfg.shotRate or 1.0) * (team == "player" and stype == "INTERCEPTOR" and INTERCEPTOR_SPD_MULT or 1.0),
        -- P1-1 NOVA_CANNON: 玩家舰队 AOE 半径受科技加成（敌方不受影响）
        aoeRadius = (cfg.aoeRadius or 0) * (team == "player" and (rm_ and rm_.baseBonus and rm_.baseBonus.aoeRadiusMult or 1.0) or 1.0),
        target    = nil,
        attackTarget = nil,
        hitFlash  = 0,   -- 受击闪白强度（1.0=刚受击，0=正常）
        isBoss    = false,  -- 是否为Boss舰
        shield    = 0,      -- 护盾当前值（Boss专用）
        maxShield = 0,      -- 护盾最大值（Boss专用）
        -- P3-2: 单舰 MVP 统计字段
        statDmg   = 0,      -- 本波造成伤害（玩家舰）/ 被谁最后打（用于归属击杀）
        statKills = 0,      -- 本波击杀数（玩家舰）
        lastHitter= nil,    -- 最后一次打我的玩家舰（敌舰专用，用于击杀归属）
        -- P1-1: 被动能力专用字段
        pierceCounter = 0,  -- DESTROYER穿甲弹计数
        isFighter    = false, -- CARRIER临时战斗机标志
        fighterLife  = 0,   -- 战斗机剩余存活时间
        -- P1-1: 改装模块字段
        moduleKey    = nil,  -- 装备的模块key
        moduleEffect = nil,  -- 缓存的 effect 表引用
        burnTargets  = nil,  -- 灼烧目标列表 {target, remaining}
        stealthTimer = 0,    -- 隐匿剩余时间
        pulseCount   = 0,    -- 脉冲过载攻击计数
        -- P1-2 V2.5: 变异词缀字段
        mutantAffixes    = nil,  -- affix key列表 (string[])
        mutantStealthCd  = 0,    -- 隐形词缀冷却计时器
        mutantStealthOn  = 0,    -- 隐形词缀激活计时器
        mutantUnstableCd = 0,    -- 不稳定词缀冷却计时器
        mutantUnstableOn = 0,    -- 不稳定词缀失控计时器
        mutantBerserkActive = false, -- 狂暴是否激活
    }
    -- P1-1: 玩家舰船应用改装模块属性
    if team == "player" and moduleMap_[stype] then
        local mKey = moduleMap_[stype]
        local mDef = SHIP_MODULES[mKey]
        if mDef then
            ship.moduleKey    = mKey
            ship.moduleEffect = mDef.effect
            local eff = mDef.effect
            -- 属性型模块：在创建时直接修改数值
            if eff.type == "hpMult" then
                ship.maxHealth = math.floor(ship.maxHealth * eff.value)
                ship.health    = ship.maxHealth
            elseif eff.type == "shield" then
                ship.shield    = math.floor(ship.maxHealth * eff.value)
                ship.maxShield = ship.shield
            elseif eff.type == "speedMult" then
                ship.speed = ship.speed * eff.value
            elseif eff.type == "shotRateMult" then
                ship.shotRate = ship.shotRate * eff.value
            elseif eff.type == "dmgUp" then
                ship.dmg      = ship.dmg * eff.dmgMult
                ship.shotRate = ship.shotRate * (eff.rateMult or 1.0)
            elseif eff.type == "stealth" then
                ship.stealthTimer = eff.duration
            end
        end
    end
    -- P1-2 V2.5: 玩家舰船应用变异词缀属性
    if team == "player" and mutantMap_[stype] then
        local mutantData = mutantMap_[stype]
        local affixKeys = mutantData.affixes
        if affixKeys and #affixKeys > 0 then
            ship.mutantAffixes = affixKeys
            -- 构建 affixSet 字典供 BattleAI O(1) 查询
            ship.affixSet = {}
            for _, k in ipairs(affixKeys) do ship.affixSet[k] = true end
            -- 应用属性型词缀 (fragile/sluggish/overcharge 的数值修改)
            local MutantShip = require("game.MutantShipSystem")
            MutantShip.ApplyAffixStats(ship, affixKeys)
        end
    end
    return ship
end

-- ============================================================================
-- P3-1a: 同步标量状态到 BattleAI
-- ============================================================================
local function syncAIVars()
    BattleAI.SyncVarsIn({
        screenW          = screenW_,
        screenH          = screenH_,
        endlessRound     = endlessRound_,
        isPincerWave     = isPincerWave_,
        currentFormation = currentFormation_,
        waveNum          = waveNum_,
        scoutAuraApplied = scoutAuraApplied_,
        explorerMarkTarget = explorerMarkTarget_,
        engineerHealTimer  = engineerHealTimer_,
        comboCount       = comboCount_,
        battleLog        = battleLog_,
    })
end

--- P3-1a: 从 BattleAI 回写标量状态
local function syncAIVarsBack()
    local v = BattleAI.GetVarsOut()
    scoutAuraApplied_   = v.scoutAuraApplied
    explorerMarkTarget_ = v.explorerMarkTarget
    engineerHealTimer_  = v.engineerHealTimer
end

--- P3-1a: 刷新 BattleAI 的表引用（Reset/StartNextWave 后调用）
local function syncAIRefs()
    BattleAI.SyncRefs({
        playerFleet   = playerFleet_,
        enemyFleet    = enemyFleet_,
        projectiles   = projectiles_,
        floatTexts    = floatTexts_,
        explParticles = explParticles_,
        hitSparks     = hitSparks_,
        shockRings    = shockRings_,
        fwParticles   = fwParticles_,
    })
end

-- ============================================================================
-- 初始化战场
-- ============================================================================
function BattleScene.Init(opts)
    vg_          = opts.vg
    notifyFn_    = opts.notifyFn
    onBattleEnd_ = opts.onBattleEnd
    player_      = opts.player
    rm_          = opts.rm
    rs_          = opts.rs
    spq_         = opts.spq
    moduleMap_   = opts.moduleMap or {}  -- P1-1: 改装模块映射
    mutantMap_   = opts.mutantMap or {}  -- P1-2 V2.5: 变异舰船映射
    leagueAttackMult_ = opts.leagueAttackMult or 1.0  -- P1-3: 联赛敌人攻击力修正
    pendingShips_= {}
    -- 海盗进攻时从指定波次开始（pirateLevel 1~5 对应 wave 1~5）
    waveNum_     = math.max(1, opts.startWave or 1)
    -- P2-3: 无尽模式层数（用于判断里程碑 Boss）
    endlessRound_ = opts.endlessRound or 0
    -- P1-3 V2.4: 指挥官加成
    commanderBonus_   = opts.commanderBonus or nil
    commanderFleetId_ = opts.commanderFleetId or nil
    -- P2-2b: 舰队名称（用于战斗日志）
    fleetName_ = opts.fleetName or "舰队"
    cmdSkillActive_   = false
    cmdSkillTimer_    = 0
    cmdSkillDef_      = nil

    -- 加载舰船纹理
    local imageFlags = NVG_IMAGE_PREMULTIPLIED
    shipImages_["SCOUT"]         = nvgCreateImage(vg_, "image/ship_scout_20260511185829.png",         imageFlags)
    shipImages_["FRIGATE"]       = nvgCreateImage(vg_, "image/ship_frigate_20260511185830.png",       imageFlags)
    shipImages_["DESTROYER"]     = nvgCreateImage(vg_, "image/ship_destroyer_20260511185818.png",     imageFlags)
    shipImages_["BATTLECRUISER"] = nvgCreateImage(vg_, "image/ship_battlecruiser_20260512164935.png", imageFlags)
    shipImages_["MINER"]         = nvgCreateImage(vg_, "image/ship_miner_20260511185819.png",         imageFlags)
    shipImages_["ENGINEER"]      = nvgCreateImage(vg_, "image/ship_engineer_20260512071656.png",      imageFlags)
    shipImages_["EXPLORER"]      = nvgCreateImage(vg_, "image/ship_explorer_20260512071647.png",      imageFlags)
    shipImages_["CARRIER"]       = nvgCreateImage(vg_, "image/ship_carrier_20260513074052.png",       imageFlags)
    shipImages_["INTERCEPTOR"]   = nvgCreateImage(vg_, "image/ship_interceptor_20260513074045.png",   imageFlags)
    print("[BattleScene] 舰船纹理加载完成")

    -- P3-1: 重置星场，让 Reset() 重新生成
    bgStars_   = {}
    bgScrollX_ = 0
    bgScrollY_ = 0
    -- P2-2: 全新战斗 — 重置技能等级/点数/弹窗
    BattleSkills.FullReset()
    -- P2-3: 应用成就奖励中的技能加成
    do
        local activeRewards = Achievement.GetActiveRewards()
        for _, entry in ipairs(activeRewards) do
            local r = entry.reward
            if r.type == "skill_point" then
                BattleSkills.AddPoints(r.value)
            elseif r.type == "skill_level" then
                local curLv = BattleSkills.GetLevel(r.value.skill)
                BattleSkills.SetLevel(r.value.skill, math.max(curLv, r.value.level))
            end
        end
    end
    skillUpgradeCards_    = nil
    skillUpgradeCardBtns_ = {}

    -- P3-1a: 初始化 BattleAI 模块（传入所有表引用）
    BattleAI.Init({
        makeShip        = makeShip,
        playerFleet     = playerFleet_,
        enemyFleet      = enemyFleet_,
        projectiles     = projectiles_,
        floatTexts      = floatTexts_,
        explParticles   = explParticles_,
        hitSparks       = hitSparks_,
        shockRings      = shockRings_,
        fwParticles     = fwParticles_,
        SK              = SK_,
        RF              = RF_,
        battleStats     = battleStats_,
        FORMATION_CONFIG = FORMATION_CONFIG,
        COMBO_LEVELS    = COMBO_LEVELS,
        rm              = rm_,
        SHIP_TYPES      = Systems.SHIP_TYPES,
    })

    BattleScene.Reset()
    print("[BattleScene] 初始化完成")
end

function BattleScene.Reset()
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 基础玩家舰队
    local midY = (screenH_ + 88) / 2   -- 战场中线（排除顶部标题区）
    playerFleet_ = {
        makeShip("FRIGATE",  100, midY,      "player"),
        makeShip("SCOUT",    120, midY - 55, "player"),
        makeShip("SCOUT",    120, midY + 55, "player"),
    }
    -- 加入已生产的舰船
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_    = {}
    -- P2-2: 先确定是否为夹击波次（25%概率；Boss波不触发夹击）
    isPincerWave_   = (waveNum_ % BOSS_WAVE_INTERVAL ~= 0) and (math.random() < 0.25)
    pincerDefended_ = false
    pincerAnnounceTimer_ = isPincerWave_ and PINCER_ANNOUNCE_DUR or 0
    -- 根据波次生成敌方舰队
    syncAIVars()
    enemyFleet_      = BattleAI.BuildEnemyWave(waveNum_)
    -- P2-1: 增援状态重置（wave1 不触发，重新开局时清空）
    RF_.pending  = false
    RF_.warning  = 0
    RF_.spawned  = false
    RF_.remain   = 0
    RF_.defeated = false
    RF_.startEnemyCnt = #enemyFleet_
    waveEnemyTotal_  = waveEnemyTotal_ + #enemyFleet_  -- P2-1: 累积本场敌人总数
    projectiles_     = {}
    floatTexts_      = {}
    fireParticles_   = {}
    fireTimer_       = 0
    explParticles_   = {}
    hitSparks_       = {}
    shockRings_      = {}
    SK_.timer      = 0
    SK_.strength   = 0
    SK_.offX       = 0
    SK_.offY       = 0
    fwParticles_            = {}
    fwLaunchTimer_          = 0
    interceptorEngineTimer_ = 0
    -- P3-1: 初始化背景星星（只在首次或全局重置时生成）
    if #bgStars_ == 0 then
        bgStars_ = {}
        bgScrollX_ = 0
        bgScrollY_ = 0
        -- P3-3: 画质缩放（低=0.5, 中=1.0, 高=1.5）
        local qScale = SettingsPanel.GetQualityScale()
        local n1 = math.max(10, math.floor(60 * qScale))
        local n2 = math.max(6,  math.floor(35 * qScale))
        local n3 = math.max(3,  math.floor(12 * qScale))
        -- layer 1: 远景小星（慢速，暗淡）
        for _ = 1, n1 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 0.6 + math.random() * 0.8,
                alpha        = 80  + math.floor(math.random() * 80),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 0.5 + math.random() * 1.0,
                layer        = 1,
            }
        end
        -- layer 2: 中景中星（中速，中亮）
        for _ = 1, n2 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 1.0 + math.random() * 1.2,
                alpha        = 120 + math.floor(math.random() * 80),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 0.8 + math.random() * 1.5,
                layer        = 2,
            }
        end
        -- layer 3: 近景大星（快速，明亮，带十字光晕）
        for _ = 1, n3 do
            bgStars_[#bgStars_+1] = {
                x            = math.random() * (screenW_ + 200),
                y            = math.random() * screenH_,
                r            = 1.8 + math.random() * 1.5,
                alpha        = 180 + math.floor(math.random() * 60),
                twinklePhase = math.random() * math.pi * 2,
                twinkleSpeed = 1.2 + math.random() * 2.0,
                layer        = 3,
            }
        end
    end
    -- 连击系统重置（每次完整开局清零）
    comboCount_        = 0
    comboTimer_        = 0
    comboDisplayTimer_ = 0
    -- 战斗统计清零（仅在完全重置时清零，波次间累计）
    battleStats_.dmgDealt      = 0
    battleStats_.dmgTaken      = 0
    battleStats_.enemiesKilled = 0
    battleStats_.wavesCleared  = 0
    battleStats_.bestSurvivor  = nil
    battleStats_.shipsLost      = 0     -- P2-3
    battleStats_.overkillMax    = 0     -- P2-3
    battleStats_.focusBossKill  = false -- P2-3
    battleStats_.focusKillCount = 0     -- P2-3
    battleLog_ = {}  -- P2-2b: 重置战斗日志
    -- P1-1: 每波统计清零
    waveKills_     = 0
    waveMaxCombo_  = 0
    waveDmgDealt_  = 0
    waveShipsLost_ = 0
    waveSummary_   = nil
    -- P2-1 V2.0: 全场击杀率追踪（整场战斗从第1波开始累积）
    waveEnemyTotal_ = 0
    waveKillTotal_  = 0
    selectedShip_  = nil  -- P2-2: 重置时取消选中
    focusTarget_   = nil  -- P2-2: 重置集火目标
    initialPlayerCount_  = #playerFleet_
    currentWaveStar_     = 0
    -- P3-1: 战斗回放系统启动录制
    BattleReplaySystem.StartRecording()
    for _, ship in ipairs(playerFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    for _, ship in ipairs(enemyFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    starAnim_            = 0
    moveTarget_             = nil
    moveTargetTimer_ = 0
    state_           = "fighting"
    stateTimer_      = 0
    battleEndFired_  = false
    waveGapTimer_    = 0
    formationLocked_ = true  -- P2-3: 战斗开始锁定阵型
    -- P1-2: 撤退/增援状态重置
    retreatUsed_       = false
    retreatBtn_        = nil
    reinforceBtn_      = nil
    reinforceCooldown_ = 0
    -- P2-2: 技能升级弹窗重置（新波次开始时关闭弹窗）
    skillUpgradeCards_     = nil
    skillUpgradeCardBtns_  = {}
    -- 技能状态重置（跨波次保留冷却，不重置激活效果）
    BattleSkills.Reset()
    -- P1-1 NOVA_CANNON: 每波开始时预充能技能
    if rm_ and rm_.baseBonus and rm_.baseBonus.battleStartSkillCharge then
        BattleSkills.PreChargeOnWaveStart(rm_.baseBonus.battleStartSkillCharge)
    end
    -- P1-1 FORTRESS_PROTOCOL: 护盾回复计时器清零
    fortressRegenTimer_ = 0
    -- Boss 波状态重置
    bossDefeated_        = false
    bossFlashAlpha_      = 0
    bossFlashTimer_      = 0
    milestoneFlashAlpha_ = 0
    milestoneBannerTimer_= 0
    hpBlinkTimer_    = 0  -- P3-2 V2.0: 低血闪烁计时器重置
    if waveNum_ % BOSS_WAVE_INTERVAL == 0 then
        bossWarningTimer_ = BOSS_WARNING_DUR
    else
        bossWarningTimer_ = 0
    end
    -- P1-1: 按当前阵型重新排布玩家舰队位置和属性
    syncAIVars(); syncAIRefs()
    BattleAI.ApplyFormationPositions(playerFleet_)
    -- P1-1: 触发波次开始型被动（SCOUT/EXPLORER/CARRIER/ENGINEER）
    BattleAI.ApplyWaveStartPassives()
    syncAIVarsBack()

    -- P1-2: 随机选择战斗环境（70% 有环境，30% 无）
    local function selectEnv()
        if math.random() < 0.30 then
            currentEnv_ = BATTLE_ENVIRONMENTS.NONE
        else
            local key = ENV_POOL[math.random(#ENV_POOL)]
            currentEnv_ = BATTLE_ENVIRONMENTS[key]
        end
        envParticles_    = {}
        envAsteroidTimer_ = currentEnv_.asteroidInterval or 2.0
        envAnnounceTimer_ = (currentEnv_.key ~= "NONE") and ENV_ANNOUNCE_DUR or 0
        envAnnounceAlpha_ = (currentEnv_.key ~= "NONE") and 255 or 0
        print("[BattleScene] P1-2 环境: " .. currentEnv_.key)
    end
    selectEnv()

    print("[BattleScene] 重置 Wave " .. waveNum_ .. "  我方: " .. #playerFleet_ .. "  敌方: " .. #enemyFleet_ .. "  阵型: " .. currentFormation_)
end

--- 从 ShipProductionQueue 获取新生产的舰船
function BattleScene.AddProductionShip(shipType)
    pendingShips_[#pendingShips_+1] = shipType
end

--- 手动开始新波次（保留我方存活舰船）
function BattleScene.StartNextWave()
    waveNum_ = waveNum_ + 1
    -- P2-1: 推进异象状态（上一波结束）
    local newAnomaly = AnomalySystem.OnWaveEnd(waveNum_ - 1)
    if newAnomaly then
        anomalyNotify_      = newAnomaly
        anomalyNotifyTimer_ = ANOMALY_NOTIFY_DUR
        if notifyFn_ then
            notifyFn_(newAnomaly.icon .. " " .. newAnomaly.name .. " — " .. newAnomaly.desc, "info")
        end
        print(string.format("[P2-1] 新异象: %s 持续%d波", newAnomaly.name, newAnomaly.duration))
    end
    -- 保留存活玩家舰船
    local survivors = playerFleet_
    screenW_, screenH_ = UICommon.getVirtualSize()
    playerFleet_ = survivors
    -- 加入排队新舰
    for _, ps in ipairs(pendingShips_) do
        local x = 80 + math.random() * 60
        local y = screenH_*0.2 + math.random() * screenH_*0.6
        playerFleet_[#playerFleet_+1] = makeShip(ps, x, y, "player")
    end
    pendingShips_     = {}
    -- P2-2: 先确定是否为夹击波次（25%概率；Boss波不触发夹击）
    isPincerWave_   = (waveNum_ % BOSS_WAVE_INTERVAL ~= 0) and (math.random() < 0.25)
    pincerDefended_ = false
    pincerAnnounceTimer_ = isPincerWave_ and PINCER_ANNOUNCE_DUR or 0
    -- P1-2: 宿敌遭遇判定（非Boss波时检查）
    nemesisActive_ = false
    nemesisAnnounceTimer_ = 0
    nemesisResult_        = nil
    nemesisResultTimer_   = 0
    local nemesisCaptainId = NemesisSystem.CheckEncounter(waveNum_)
    syncAIVars()
    if nemesisCaptainId then
        -- 触发宿敌遭遇：替换常规敌舰队
        NemesisSystem.StartEncounter(nemesisCaptainId, waveNum_)
        nemesisActive_ = true
        nemesisAnnounceTimer_ = NEMESIS_ANNOUNCE_DUR
        enemyFleet_ = BattleAI.BuildNemesisWave(nemesisCaptainId)
        -- 宿敌波不触发夹击
        isPincerWave_ = false
        pincerAnnounceTimer_ = 0
    else
        enemyFleet_ = BattleAI.BuildEnemyWave(waveNum_)
    end
    waveEnemyTotal_   = waveEnemyTotal_ + #enemyFleet_  -- P2-1: 累积本场敌人总数
    projectiles_      = {}
    floatTexts_       = {}
    hitSparks_        = {}
    shockRings_       = {}
    moveTarget_       = nil
    moveTargetTimer_  = 0
    state_            = "fighting"
    stateTimer_       = 0
    battleEndFired_   = false
    waveGapTimer_     = 0
    formationLocked_  = true   -- P2-3: 战斗开始锁定阵型
    prepSkipped_      = false  -- P2-3: 重置跳过标记
    initialPlayerCount_ = #playerFleet_
    currentWaveStar_    = 0
    starAnim_           = 0
    -- Boss 波状态重置
    bossDefeated_     = false
    -- P1-1: 新波次开始，重置本波统计
    waveKills_     = 0
    waveMaxCombo_  = 0
    waveDmgDealt_  = 0
    waveShipsLost_ = 0
    -- P3-2: 存活舰船的 MVP 统计字段随波次清零
    for _, ps in ipairs(playerFleet_) do
        ps.statDmg   = 0
        ps.statKills = 0
    end
    local isBossW = (waveNum_ % BOSS_WAVE_INTERVAL == 0)
    bossWarningTimer_ = isBossW and BOSS_WARNING_DUR or 0
    -- P3-1: 注册新舰船到回放系统（新波次的新增舰船）
    for _, ship in ipairs(playerFleet_) do
        if not ship._replayId then BattleReplaySystem.RegisterShip(ship) end
    end
    for _, ship in ipairs(enemyFleet_) do
        BattleReplaySystem.RegisterShip(ship)
    end
    if nemesisActive_ then
        -- P1-2: 宿敌遭遇优先级最高的通知
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        Audio.SetBGMPitch(1.08)  -- 宿敌波更紧张的音调
        local capInfo = NemesisSystem.GetActiveCaptain()
        local capName = capInfo and capInfo.name or "宿敌"
        local lvl     = capInfo and capInfo.level or 1
        local isFinale = capInfo and capInfo.isFinale
        if isFinale then
            if notifyFn_ then notifyFn_("☠ 最终决战 — " .. capName .. " 再次现身！", "error") end
        else
            if notifyFn_ then notifyFn_("⚔ 宿敌来袭 — " .. capName .. " [Lv." .. lvl .. "]", "error") end
        end
    elseif isBossW then
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        -- P3-3: Boss波次音调提升5%，增强紧张感
        Audio.SetBGMPitch(1.05)
        if notifyFn_ then notifyFn_("⚠️ 第 " .. waveNum_ .. " 波 — 旗舰Boss来袭！", "error") end
    else
        Audio.Play(Audio.SFX.WAVE_INCOMING)
        -- P3-3: 非Boss波恢复正常音调
        Audio.ResetBGMPitch()
        if notifyFn_ then notifyFn_("第 " .. waveNum_ .. " 波敌军来袭！", "warn") end
    end
    -- P2-2b: 记录新波次开始
    logBattleEvent(string.format("第 %d 波战斗开始 — %s 迎战", waveNum_, fleetName_))
    -- P2-2: 夹击波次通知
    if isPincerWave_ and notifyFn_ then
        notifyFn_("↕ 上下夹击！敌军从两侧突袭", "error")
    end
    -- P1-1: 新波次按阵型重新排布（仅对新加入的舰船；存活舰船保持原位）
    syncAIVars(); syncAIRefs()
    BattleAI.ApplyFormationPositions(playerFleet_)
    -- P1-1: 触发波次开始型被动（SCOUT/EXPLORER/CARRIER/ENGINEER）
    BattleAI.ApplyWaveStartPassives()
    syncAIVarsBack()
    -- P1-1 NOVA_CANNON: 新波次开始时预充能技能
    if rm_ and rm_.baseBonus and rm_.baseBonus.battleStartSkillCharge then
        BattleSkills.PreChargeOnWaveStart(rm_.baseBonus.battleStartSkillCharge)
    end
    -- P1-1 FORTRESS_PROTOCOL: 护盾回复计时器清零
    fortressRegenTimer_ = 0

    -- P2-1: 应用星域异象修正到双方舰船
    local anomMods = AnomalySystem.GetBattleModifiers()
    if anomMods.damageMult ~= 1.0 or anomMods.speedMult ~= 1.0 or anomMods.hpMult ~= 1.0 or anomMods.shieldMult ~= 1.0 then
        for _, ship in ipairs(playerFleet_) do
            ship.dmg   = ship.dmg * anomMods.damageMult
            ship.speed = ship.speed * anomMods.speedMult
            if anomMods.hpMult ~= 1.0 then
                local newMax = math.max(1, math.floor(ship.maxHealth * anomMods.hpMult))
                local ratio  = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
                ship.maxHealth = newMax
                ship.health    = math.max(1, math.floor(newMax * ratio))
            end
        end
    end
    if anomMods.enemyDamageMult ~= 1.0 or anomMods.enemySpeedMult ~= 1.0 or anomMods.hpMult ~= 1.0 then
        for _, ship in ipairs(enemyFleet_) do
            ship.dmg   = ship.dmg * anomMods.enemyDamageMult
            ship.speed = ship.speed * anomMods.enemySpeedMult
            if anomMods.hpMult ~= 1.0 then
                local newMax = math.max(1, math.floor(ship.maxHealth * anomMods.hpMult))
                local ratio  = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
                ship.maxHealth = newMax
                ship.health    = math.max(1, math.floor(newMax * ratio))
            end
        end
    end
    -- 存储首轮伤害倍率(首次射击后恢复)
    if anomMods.firstStrikeMult ~= 1.0 then
        for _, ship in ipairs(playerFleet_) do ship.firstStrikeMult = anomMods.firstStrikeMult end
        for _, ship in ipairs(enemyFleet_) do  ship.firstStrikeMult = anomMods.firstStrikeMult end
    end

    -- P1-3: 联赛敌人攻击力修正
    if leagueAttackMult_ ~= 1.0 then
        for _, ship in ipairs(enemyFleet_) do
            ship.dmg = ship.dmg * leagueAttackMult_
        end
    end

    -- P1-2: 新波次重新随机环境
    if math.random() < 0.30 then
        currentEnv_ = BATTLE_ENVIRONMENTS.NONE
    else
        local key = ENV_POOL[math.random(#ENV_POOL)]
        currentEnv_ = BATTLE_ENVIRONMENTS[key]
    end
    envParticles_     = {}
    envAsteroidTimer_ = currentEnv_.asteroidInterval or 2.0
    envAnnounceTimer_ = (currentEnv_.key ~= "NONE") and ENV_ANNOUNCE_DUR or 0
    envAnnounceAlpha_ = (currentEnv_.key ~= "NONE") and 255 or 0
    if currentEnv_.key ~= "NONE" and notifyFn_ then
        notifyFn_(currentEnv_.icon .. " 进入" .. currentEnv_.label .. "区域！" .. currentEnv_.desc, "info")
    end
    -- P2-1: 新波次增援状态重置（Boss波不触发，wave < RF_.MIN_WAVE 不触发）
    local isBossThisWave = (waveNum_ % BOSS_WAVE_INTERVAL == 0)
    ---@diagnostic disable-next-line: undefined-global
    RF_.pending    = not isBossThisWave and waveNum_ >= RF_.MIN_WAVE and math.random() < RF_.PROB
    RF_.warning    = 0
    RF_.spawned    = false
    RF_.remain     = 0
    RF_.defeated   = false
    RF_.startEnemyCnt = #enemyFleet_
    if RF_.pending then
        print(string.format("[P2-1] Wave%d 将触发增援（Boss波=%s）", waveNum_, tostring(isBossThisWave)))
    end
    print("[BattleScene] Wave " .. waveNum_ .. " 开始  敌方: " .. #enemyFleet_ .. "  阵型: " .. currentFormation_)
end

-- ============================================================================
-- 逻辑更新
-- ============================================================================
--- 将本地状态推入共享上下文 ctx（每帧 Update 开始时调用）
--- 表字段为引用拷贝（子模块对内容的修改自动可见）；标量为值拷贝；常量每帧覆盖
local function pushToCtx()
    -- 表（引用拷贝，内容修改自动可见）
    ctx.playerFleet   = playerFleet_
    ctx.enemyFleet    = enemyFleet_
    ctx.projectiles   = projectiles_
    ctx.floatTexts    = floatTexts_
    ctx.fireParticles = fireParticles_
    ctx.explParticles = explParticles_
    ctx.hitSparks     = hitSparks_
    ctx.shockRings    = shockRings_
    ctx.fwParticles   = fwParticles_
    ctx.bgStars       = bgStars_
    ctx.envParticles  = envParticles_
    ctx.battleStats   = battleStats_
    ctx.battleLog     = battleLog_
    ctx.SK            = SK_
    ctx.RF            = RF_
    ctx.FORMATION_CONFIG = FORMATION_CONFIG
    ctx.COMBO_LEVELS  = COMBO_LEVELS
    ctx.currentEnv    = currentEnv_
    -- 外部引用
    ctx.rm          = rm_
    ctx.rs          = rs_
    ctx.player      = player_
    ctx.notifyFn    = notifyFn_
    ctx.onBattleEnd = onBattleEnd_
    ctx.fleetName   = fleetName_
    -- 常量（每帧覆盖 BattleContext 默认值，确保用 BattleScene 真实值）
    ctx.WAVE_GAP               = WAVE_GAP
    ctx.BOSS_BANNER_DUR        = BOSS_BANNER_DUR
    ctx.MILESTONE_BANNER_DUR   = MILESTONE_BANNER_DUR
    ctx.NEMESIS_RESULT_DUR     = NEMESIS_RESULT_DUR
    ctx.BG_SCROLL_VX           = BG_SCROLL_VX
    ctx.BG_SCROLL_VY           = BG_SCROLL_VY
    ctx.DESTROYER_PIERCE_COUNT = DESTROYER_PIERCE_COUNT
    ctx.FRIGATE_SHARE_RATIO    = FRIGATE_SHARE_RATIO
    ctx.BATTLECRUISER_BLOCK    = BATTLECRUISER_BLOCK
    ctx.CHAIN_RADIUS           = CHAIN_RADIUS
    ctx.CHAIN_AOE_PCT          = CHAIN_AOE_PCT
    ctx.CHAIN_MIN_KILLS        = CHAIN_MIN_KILLS
    ctx.COMBO_RESET_TIME       = COMBO_RESET_TIME
    ctx.ENGINEER_HEAL_INTERVAL = ENGINEER_HEAL_INTERVAL
    ctx.ENGINEER_HEAL_AMOUNT   = ENGINEER_HEAL_AMOUNT
    ctx.BATTLE_LOG_MAX         = BATTLE_LOG_MAX
    -- 标量 + 可空引用
    ctx.screenW            = screenW_
    ctx.screenH            = screenH_
    ctx.shootSfxTimer      = shootSfxTimer_
    ctx.reinforceCooldown  = reinforceCooldown_
    ctx.state              = state_
    ctx.stateTimer         = stateTimer_
    ctx.battleEndFired     = battleEndFired_
    ctx.waveGapTimer       = waveGapTimer_
    ctx.prepSkipped        = prepSkipped_
    ctx.waveNum            = waveNum_
    ctx.bossDefeated       = bossDefeated_
    ctx.bossWarningTimer   = bossWarningTimer_
    ctx.bossFlashAlpha     = bossFlashAlpha_
    ctx.bossFlashTimer     = bossFlashTimer_
    ctx.milestoneFlashAlpha  = milestoneFlashAlpha_
    ctx.milestoneBannerTimer = milestoneBannerTimer_
    ctx.milestoneRound     = milestoneRound_
    ctx.endlessRound       = endlessRound_
    ctx.hpBlinkTimer       = hpBlinkTimer_
    ctx.interceptorEngineTimer = interceptorEngineTimer_
    ctx.fireTimer          = fireTimer_
    ctx.fwLaunchTimer      = fwLaunchTimer_
    ctx.bgScrollX          = bgScrollX_
    ctx.bgScrollY          = bgScrollY_
    ctx.currentWaveStar    = currentWaveStar_
    ctx.starAnim           = starAnim_
    ctx.initialPlayerCount = initialPlayerCount_
    ctx.engineerHealTimer  = engineerHealTimer_
    ctx.chainCount         = chainCount_
    ctx.envAnnounceAlpha   = envAnnounceAlpha_
    ctx.envAnnounceTimer   = envAnnounceTimer_
    ctx.envAsteroidTimer   = envAsteroidTimer_
    ctx.fortressRegenTimer = fortressRegenTimer_
    ctx.pincerAnnounceTimer = pincerAnnounceTimer_
    ctx.pincerDefended     = pincerDefended_
    ctx.isPincerWave       = isPincerWave_
    ctx.nemesisActive      = nemesisActive_
    ctx.nemesisAnnounceTimer = nemesisAnnounceTimer_
    ctx.nemesisResult      = nemesisResult_
    ctx.nemesisResultTimer = nemesisResultTimer_
    ctx.anomalyNotify      = anomalyNotify_
    ctx.anomalyNotifyTimer = anomalyNotifyTimer_
    ctx.moveTarget         = moveTarget_
    ctx.moveTargetTimer    = moveTargetTimer_
    ctx.cmdSkillActive     = cmdSkillActive_
    ctx.cmdSkillTimer      = cmdSkillTimer_
    ctx.cmdSkillDef        = cmdSkillDef_
    ctx.commanderFleetId   = commanderFleetId_
    ctx.currentFormation   = currentFormation_
    ctx.formationLocked    = formationLocked_
    ctx.focusTarget        = focusTarget_
    ctx.explorerMarkTarget = explorerMarkTarget_
    ctx.skillUpgradeCards  = skillUpgradeCards_
    ctx.waveSummary        = waveSummary_
    ctx.waveKills          = waveKills_
    ctx.waveKillTotal      = waveKillTotal_
    ctx.waveMaxCombo       = waveMaxCombo_
    ctx.waveDmgDealt       = waveDmgDealt_
    ctx.waveShipsLost      = waveShipsLost_
    ctx.comboCount         = comboCount_
    ctx.comboTimer         = comboTimer_
    ctx.comboDisplayTimer  = comboDisplayTimer_
end

--- 将 ctx 中被子模块修改的标量/可空引用拉回本地状态（每帧 Update 结束时调用）
--- 纯表/常量/只读引用无需拉回（表为同一对象，常量不变）
local function pullFromCtx()
    screenW_            = ctx.screenW
    screenH_            = ctx.screenH
    shootSfxTimer_      = ctx.shootSfxTimer
    reinforceCooldown_  = ctx.reinforceCooldown
    state_              = ctx.state
    stateTimer_         = ctx.stateTimer
    battleEndFired_     = ctx.battleEndFired
    waveGapTimer_       = ctx.waveGapTimer
    prepSkipped_        = ctx.prepSkipped
    waveNum_            = ctx.waveNum
    bossDefeated_       = ctx.bossDefeated
    bossWarningTimer_   = ctx.bossWarningTimer
    bossFlashAlpha_     = ctx.bossFlashAlpha
    bossFlashTimer_     = ctx.bossFlashTimer
    milestoneFlashAlpha_  = ctx.milestoneFlashAlpha
    milestoneBannerTimer_ = ctx.milestoneBannerTimer
    milestoneRound_     = ctx.milestoneRound
    endlessRound_       = ctx.endlessRound
    hpBlinkTimer_       = ctx.hpBlinkTimer
    interceptorEngineTimer_ = ctx.interceptorEngineTimer
    fireTimer_          = ctx.fireTimer
    fwLaunchTimer_      = ctx.fwLaunchTimer
    bgScrollX_          = ctx.bgScrollX
    bgScrollY_          = ctx.bgScrollY
    currentWaveStar_    = ctx.currentWaveStar
    starAnim_           = ctx.starAnim
    initialPlayerCount_ = ctx.initialPlayerCount
    engineerHealTimer_  = ctx.engineerHealTimer
    chainCount_         = ctx.chainCount
    envAnnounceAlpha_   = ctx.envAnnounceAlpha
    envAnnounceTimer_   = ctx.envAnnounceTimer
    envAsteroidTimer_   = ctx.envAsteroidTimer
    fortressRegenTimer_ = ctx.fortressRegenTimer
    pincerAnnounceTimer_ = ctx.pincerAnnounceTimer
    pincerDefended_     = ctx.pincerDefended
    isPincerWave_       = ctx.isPincerWave
    nemesisActive_      = ctx.nemesisActive
    nemesisAnnounceTimer_ = ctx.nemesisAnnounceTimer
    nemesisResult_      = ctx.nemesisResult
    nemesisResultTimer_ = ctx.nemesisResultTimer
    anomalyNotify_      = ctx.anomalyNotify
    anomalyNotifyTimer_ = ctx.anomalyNotifyTimer
    moveTarget_         = ctx.moveTarget
    moveTargetTimer_    = ctx.moveTargetTimer
    cmdSkillActive_     = ctx.cmdSkillActive
    cmdSkillTimer_      = ctx.cmdSkillTimer
    cmdSkillDef_        = ctx.cmdSkillDef
    commanderFleetId_   = ctx.commanderFleetId
    currentFormation_   = ctx.currentFormation
    formationLocked_    = ctx.formationLocked
    focusTarget_        = ctx.focusTarget
    explorerMarkTarget_ = ctx.explorerMarkTarget
    skillUpgradeCards_  = ctx.skillUpgradeCards
    waveSummary_        = ctx.waveSummary
    waveKills_          = ctx.waveKills
    waveKillTotal_      = ctx.waveKillTotal
    waveMaxCombo_       = ctx.waveMaxCombo
    waveDmgDealt_       = ctx.waveDmgDealt
    waveShipsLost_      = ctx.waveShipsLost
    comboCount_         = ctx.comboCount
    comboTimer_         = ctx.comboTimer
    comboDisplayTimer_  = ctx.comboDisplayTimer
end

--- 主逻辑更新：sync 桥 + 委托战斗子模块
function BattleScene.Update(dt)
    pushToCtx()

    -- 已结束状态守卫（win/lose）：处理倒计时/烟花，跳过战斗逻辑
    local handled, startNext = BattleWinLose.UpdateGuard(dt, ctx)
    if handled then
        pullFromCtx()
        if startNext then BattleScene.StartNextWave() end
        return
    end

    -- 计时器/背景/环境粒子/连击衰减/增援/自适应音乐/指挥官技能/要塞回复
    BattleTimers.Update(dt, ctx, makeShip)
    -- 玩家舰队战斗（移动/集火/模块/词缀/伤害）
    BattleCombatPlayer.Update(dt, ctx)
    -- 敌方 AI 战斗（移动/索敌/伤害/阵型/反弹）
    BattleCombatEnemy.Update(dt, ctx)
    -- 死亡清理 + 击杀归属 + 连击 + Boss奖励 + 连锁反应
    BattleDeath.Update(dt, ctx, makeShip)
    -- 视觉/音效更新（子弹/飘字/粒子/震动/被动治疗等）
    BattleVFX.Update(dt, ctx)
    -- 胜负检测与结算（资源奖励/星级/技能卡）
    BattleWinLose.Detect(dt, ctx)

    pullFromCtx()
end

-- ============================================================================
-- 渲染（委托给 BattleRender 模块）
-- ============================================================================
function BattleScene.Render()
    -- 同步状态到 BattleState 共享表
    local BS = BattleState
    BS.vg       = vg_
    BS.screenW  = screenW_
    BS.screenH  = screenH_

    BS.playerFleet = playerFleet_
    BS.enemyFleet  = enemyFleet_
    BS.projectiles = projectiles_
    BS.floatTexts  = floatTexts_

    BS.fireParticles = fireParticles_
    BS.explParticles = explParticles_
    BS.hitSparks     = hitSparks_
    BS.shockRings    = shockRings_
    BS.fwParticles   = fwParticles_

    BS.state      = state_
    BS.stateTimer = stateTimer_
    BS.waveNum    = waveNum_

    BS.SK = SK_

    BS.bossWarningTimer  = bossWarningTimer_
    BS.bossFlashAlpha    = bossFlashAlpha_
    BS.bossFlashTimer    = bossFlashTimer_
    BS.bossDefeated      = bossDefeated_
    BS.BOSS_WAVE_INTERVAL = BOSS_WAVE_INTERVAL

    BS.comboCount        = comboCount_
    BS.comboTimer        = comboTimer_
    BS.comboDisplayTimer = comboDisplayTimer_
    BS.COMBO_LEVELS      = COMBO_LEVELS

    BS.waveGapTimer = waveGapTimer_
    BS.prepSkipped  = prepSkipped_
    BS.WAVE_GAP     = WAVE_GAP

    BS.bgStars   = bgStars_
    BS.bgScrollX = bgScrollX_
    BS.bgScrollY = bgScrollY_
    BS.currentEnv    = currentEnv_
    BS.envParticles  = envParticles_
    BS.envAnnounceAlpha = envAnnounceAlpha_
    BS.envAnnounceTimer = envAnnounceTimer_

    BS.moveTarget      = moveTarget_
    BS.moveTargetTimer = moveTargetTimer_

    BS.shipImages = shipImages_

    BS.selectedShip = selectedShip_
    BS.focusTarget  = focusTarget_

    BS.currentFormation = currentFormation_
    BS.formationLocked  = formationLocked_
    BS.FORMATION_CONFIG = FORMATION_CONFIG

    BS.retreatUsed       = retreatUsed_
    BS.reinforceCooldown = reinforceCooldown_

    BS.skillUpgradeCards = skillUpgradeCards_

    BS.nemesisActive        = nemesisActive_
    BS.nemesisAnnounceTimer = nemesisAnnounceTimer_
    BS.nemesisResult        = nemesisResult_
    BS.nemesisResultTimer   = nemesisResultTimer_

    BS.isPincerWave        = isPincerWave_
    BS.pincerAnnounceTimer = pincerAnnounceTimer_

    BS.anomalyNotify      = anomalyNotify_
    BS.anomalyNotifyTimer = anomalyNotifyTimer_

    BS.RF = RF_

    BS.endlessRound        = endlessRound_
    BS.milestoneFlashAlpha = milestoneFlashAlpha_
    BS.milestoneBannerTimer = milestoneBannerTimer_
    BS.milestoneRound      = milestoneRound_

    BS.waveSummary = waveSummary_

    BS.currentWaveStar = currentWaveStar_
    BS.starAnim        = starAnim_
    BS.hpBlinkTimer    = hpBlinkTimer_

    BS.battleStats        = battleStats_
    BS.initialPlayerCount = initialPlayerCount_

    BS.explorerMarkTarget = explorerMarkTarget_

    -- 模块/函数引用（仅首次或变化时需要，但每帧赋值开销极低）
    BS.LiverySystem  = LiverySystem
    BS.BattleSkills  = BattleSkills
    BS.rm            = rm_
    BS.rs            = rs_
    BS.notifyFn      = notifyFn_
    BS.getComboLevel      = getComboLevel
    BS.getNextWavePreview = BattleAI.GetNextWavePreview
    BS.SHIP_TYPES    = Systems.SHIP_TYPES
    BS.NemesisSystem = NemesisSystem
    BS.AnomalySystem = AnomalySystem

    -- 执行渲染
    BattleRender.Render()

    -- 回写：渲染函数可能修改的按钮区域/选中状态
    formationBtn_         = BS.formationBtn
    retreatBtn_           = BS.retreatBtn
    reinforceBtn_         = BS.reinforceBtn
    focusHudBtn_          = BS.focusHudBtn
    skillUpgradeCardBtns_ = BS.skillUpgradeCardBtns
    selectedShip_         = BS.selectedShip
    loseBtn1_             = BS.loseBtn1
    loseBtn2_             = BS.loseBtn2
end


-- ============================================================================
-- 状态查询
-- ============================================================================
function BattleScene.GetState()       return state_ end
function BattleScene.GetWave()        return waveNum_ end
function BattleScene.GetPlayerCount() return #playerFleet_ end
function BattleScene.GetEnemyCount()  return #enemyFleet_ end
function BattleScene.GetStats()
    -- P3-1: 从回放系统获取 MVP 数据
    local replayMVP = BattleReplaySystem.GetMVP()
    local mvpShip = nil
    local mvpReason = nil
    local mvpScore = 0
    if replayMVP then
        mvpShip   = replayMVP.stype
        mvpReason = replayMVP.reason
        mvpScore  = replayMVP.score
    end

    return {
        dmgDealt       = battleStats_.dmgDealt,
        dmgTaken       = battleStats_.dmgTaken,
        enemiesKilled  = battleStats_.enemiesKilled,
        wavesCleared   = battleStats_.wavesCleared,
        bestSurvivor   = battleStats_.bestSurvivor,
        -- P2-3: 隐藏成就字段
        shipsLost      = battleStats_.shipsLost,
        overkillMax    = battleStats_.overkillMax,
        focusBossKill  = battleStats_.focusBossKill,
        focusKillCount = battleStats_.focusKillCount or 0,
        -- P3-1: 最高连击 & MVP
        maxCombo       = battleStats_.maxCombo or 0,
        mvpShip        = mvpShip,
        mvpReason      = mvpReason,
        mvpScore       = mvpScore,
        -- P2-1 V2.0: 全场击杀率计算字段
        waveEnemyTotal = waveEnemyTotal_,
        waveKillTotal  = waveKillTotal_,
        -- P1-3: 连锁反应次数
        chainCount     = battleStats_.chainCount,
        -- P2-1: 是否全歼增援
        reinforceWin   = battleStats_.reinforceWin or false,
        -- P2-2b: 战斗日志
        battleLog      = battleLog_,
    }
end

--- P2-2b: 获取战斗日志（供 EndGamePanel 调用）
---@return table[] {{wave=number, text=string}, ...}
function BattleScene.GetBattleLog()
    return battleLog_
end

--- P3-1: 获取回放数据（供 EndGamePanel 调用）
---@return table {highlights, mvp, duration, frameCount, eventCount}
function BattleScene.GetReplayData()
    return {
        highlights  = BattleReplaySystem.GetHighlights(),
        mvp         = BattleReplaySystem.GetMVP(),
        duration    = BattleReplaySystem.GetDuration(),
        frameCount  = #BattleReplaySystem.GetFrames(),
        eventCount  = #BattleReplaySystem.GetEvents(),
    }
end

-- ============================================================================
-- 输入（由 main.lua 调用）
-- ============================================================================
function BattleScene.OnClick(mx, my)
    -- P2-2: 技能升级弹窗期间优先处理卡片点击，屏蔽其他输入
    if skillUpgradeCards_ and #skillUpgradeCards_ > 0 and state_ == "win" then
        for _, btn in ipairs(skillUpgradeCardBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                BattleSkills.UpgradeSkill(btn.skillIdx)
                local lv = BattleSkills.GetLevel(btn.skillIdx)
                if notifyFn_ then
                    notifyFn_(BattleSkills.GetIcon(btn.skillIdx) .. " " ..
                        BattleSkills.GetName(btn.skillIdx) .. " 升至 Lv" .. lv, "success")
                end
                skillUpgradeCards_    = nil
                skillUpgradeCardBtns_ = {}
                return
            end
        end
        return  -- 点击弹窗以外区域也吃掉，不传递
    end

    -- M2: 战败画面触屏按钮处理
    if state_ == "lose" then
        local function inBtn(b)
            return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
        end
        if inBtn(loseBtn1_) then
            -- 重新战斗：重置战场
            BattleScene.Reset()
            return
        elseif inBtn(loseBtn2_) then
            -- 返回星图：触发战败回调
            if onBattleEnd_ and not battleEndFired_ then
                battleEndFired_ = true
                onBattleEnd_("lose")
            end
            return
        end
        return  -- 战败时屏蔽其他区域点击
    end
    if state_ ~= "fighting" then return end

    -- P2-2: 检测集火取消按钮（顶部状态条右侧 ✕）
    if focusHudBtn_ then
        local b = focusHudBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            focusTarget_ = nil
            return
        end
    end

    -- P2-2: 舰船点击检测（我方 + 敌方，点击舰船显示信息面板）
    local SHIP_HIT_RADIUS = 14  -- 点击热区半径（px）
    local clickedShip = nil
    -- 优先检测我方（玩家通常想了解自己的舰船）
    for _, s in ipairs(playerFleet_) do
        local dx, dy = mx - s.x, my - s.y
        if dx*dx + dy*dy <= SHIP_HIT_RADIUS * SHIP_HIT_RADIUS then
            clickedShip = s; break
        end
    end
    if not clickedShip then
        for _, s in ipairs(enemyFleet_) do
            local dx, dy = mx - s.x, my - s.y
            if dx*dx + dy*dy <= SHIP_HIT_RADIUS * SHIP_HIT_RADIUS then
                clickedShip = s; break
            end
        end
    end
    if clickedShip then
        if clickedShip.team == "enemy" then
            -- P2-2: 点击敌方舰船 → 设置/取消集火目标
            if focusTarget_ == clickedShip then
                focusTarget_ = nil   -- 再次点击同一敌方 → 取消集火
            else
                focusTarget_ = clickedShip
            end
        end
        -- 同时更新信息面板选中
        if selectedShip_ == clickedShip then
            selectedShip_ = nil
        else
            selectedShip_ = clickedShip
        end
        return
    end

    -- P1-2: 撤退按钮点击
    if retreatBtn_ then
        local b = retreatBtn_
        if mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h then
            local energy = rm_ and (rm_.resources.energy or 0) or 0
            if energy < RETREAT_COST_ENERGY then
                if notifyFn_ then notifyFn_(string.format("能源不足（需%d）", RETREAT_COST_ENERGY), "warn") end
            else
                rm_:add("energy", -RETREAT_COST_ENERGY)
                retreatUsed_    = true
                battleEndFired_ = true
                if onBattleEnd_ then onBattleEnd_("retreat") end
            end
            return
        end
    end

    -- P1-2: 增援按钮点击
    if reinforceBtn_ then
        local b = reinforceBtn_
        if mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h then
            if not b.canDo then
                if notifyFn_ then
                    notifyFn_(string.format("增援需金属%d 晶体%d", REINFORCE_COST_METAL, REINFORCE_COST_CRYSTAL), "warn")
                end
            else
                rm_:add("metal",   -REINFORCE_COST_METAL)
                rm_:add("crystal", -REINFORCE_COST_CRYSTAL)
                reinforceCooldown_ = 12  -- 12秒内不能再次增援
                -- 派入 2 艘 FRIGATE
                for _ = 1, 2 do
                    local x = 60 + math.random() * 50
                    local y = screenH_ * 0.2 + math.random() * screenH_ * 0.6
                    playerFleet_[#playerFleet_+1] = makeShip("FRIGATE", x, y, "player")
                end
                if notifyFn_ then notifyFn_("紧急增援！2艘护卫舰抵达战场！", "success") end
            end
            return
        end
    end

    -- P1-1: 阵型按钮点击判断
    for _, btn in ipairs(formationBtn_) do
        if mx >= btn.x and mx <= btn.x+btn.w and my >= btn.y and my <= btn.y+btn.h then
            if btn.locked then return end  -- P2-1: 锁定状态不响应点击
            if btn.key == "custom" then
                -- P2-1 V2.5: 自定义阵型 → 打开编辑器
                FormationEditor.Open(playerFleet_)
            else
                BattleScene.SetFormation(btn.key)
            end
            return
        end
    end

    -- 技能按钮点击判断
    local function inBtn(b)
        return b and mx >= b.x and mx <= b.x+b.w and my >= b.y and my <= b.y+b.h
    end
    if BattleSkills.OnClick(mx, my, {
        rs          = rs_,
        notifyFn    = notifyFn_,
        playerFleet = playerFleet_,
        enemyFleet  = enemyFleet_,
        floatTexts  = floatTexts_,
        battleStats = battleStats_,
        screenW     = screenW_,
        screenH     = screenH_,
        onShake     = function(dur, str)
            SK_.timer = dur; SK_.dur = dur; SK_.strength = str
        end,
    }) then return end

    -- 普通点击：移动指令（同时取消单舰选中）
    selectedShip_ = nil
    for i, s in ipairs(playerFleet_) do
        local spread = (#playerFleet_ > 1) and (i - (#playerFleet_+1)/2) * 28 or 0
        s.target = { x=mx, y=my + spread }
    end
    moveTarget_ = { x=mx, y=my }
end

return BattleScene
