-- ============================================================================
-- game/BattleScene.lua  -- 战术战斗场景
-- ============================================================================

local Audio        = require("game.AudioManager")
local UICommon     = require("game.ui.UICommon")
local BattleSkills = require("game.BattleSkills")
local Achievement  = require("game.AchievementSystem")   -- P2-3: 成就奖励应用

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

-- 波次系统
local waveNum_      = 1     -- 当前波次
local WAVE_GAP      = 3.0   -- 胜利后等待下一波的秒数
local waveGapTimer_ = 0     -- 倒计时

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
local shakeTimer_    = 0   -- 震动剩余时间
local shakeDur_      = 0   -- 震动总时长
local shakeStrength_ = 0   -- 震动强度（像素）
local shakeOffX_     = 0   -- 当前帧震动偏移 X
local shakeOffY_     = 0   -- 当前帧震动偏移 Y

-- 烟花粒子系统（波次胜利特效）
local fwParticles_   = {}  -- {x,y,vx,vy,life,maxLife,r,g,b,tail}
local fwLaunchTimer_ = 0   -- 下次发射烟花的倒计时

-- INTERCEPTOR 引擎音效节流
local interceptorEngineTimer_ = 0   -- 距离下次允许播放的冷却（秒）

-- P3-2: 全屏闪光 + Boss 横幅
local bossFlashAlpha_  = 0    -- 全屏白光透明度（0-255，衰减至0）
local bossFlashTimer_  = 0    -- 横幅显示倒计时（秒）
local BOSS_BANNER_DUR  = 2.5  -- 横幅显示时长

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
local WAVE_SUMMARY_DUR = 2.8  -- 摘要显示时长（显示在 win 阶段结束前）

-- P2-2: 单舰信息面板 + 集火指令
local selectedShip_    = nil  -- 当前选中的舰船引用（nil = 未选中）
local focusTarget_     = nil  -- 集火目标（仅敌方，nil = 无集火）

-- P1-1: 战斗阵型系统
-- "assault"=突击  "defense"=防守  "encircle"=包围
local currentFormation_ = "defense"
local formationBtn_ = {}   -- 三个按钮点击区域 {x,y,w,h,key}
-- 阵型配置
local FORMATION_CONFIG = {
    assault = {
        label = "突击",
        icon  = "⚔",
        desc  = "速度+20% 攻击+15%",
        color = {255, 110, 80},
        -- 舰船布置：紧凑向前
        posX  = 150,   -- 基础 x（偏前）
        posXSpread = 25,
        posYBase   = 0,   -- 相对于 midY，0=居中
        posYSpread = 45,
        speedMult  = 1.20,
        dmgMult    = 1.15,
        healthMult = 1.00,
    },
    defense = {
        label = "防守",
        icon  = "🛡",
        desc  = "血量+20% 护盾+10%",
        color = {80, 160, 255},
        posX       = 100,
        posXSpread = 20,
        posYBase   = 0,
        posYSpread = 60,
        speedMult  = 1.00,
        dmgMult    = 1.00,
        healthMult = 1.20,
    },
    encircle = {
        label = "包围",
        icon  = "↕",
        desc  = "纵深包抄 速度+10%",
        color = {120, 230, 150},
        posX       = 110,
        posXSpread = 30,
        posYBase   = 0,
        posYSpread = 0,   -- 特殊：包围由 applyFormationPositions 单独处理
        speedMult  = 1.10,
        dmgMult    = 1.00,
        healthMult = 1.00,
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
}

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
    local hp = math.floor(cfg.health * hm)
    return {
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
        shotRate  = cfg.shotRate or 1.0,
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
    }
end

-- 生成 Boss 旗舰（基于普通舰种，但数值大幅强化）
local function makeBossShip(baseType, x, y)
    local ship = makeShip(baseType, x, y, "enemy")
    ship.isBoss    = true
    ship.health    = ship.maxHealth * 4   -- 血量×4
    ship.maxHealth = ship.maxHealth * 4
    ship.dmg       = ship.dmg * 2         -- 伤害×2
    ship.speed     = ship.speed * 0.8     -- 速度降低（更有压迫感）
    -- Boss护盾值 = 基础血量的50%
    local shieldVal = math.floor(ship.maxHealth * 0.5)
    ship.shield    = shieldVal
    ship.maxShield = shieldVal
    -- Boss特殊颜色（亮金色）
    ship.color     = {255, 200, 50}
    return ship
end

-- ============================================================================
-- P1-1: 阵型应用（对玩家舰队重新定位并叠加属性加成）
-- ============================================================================
--- 根据 currentFormation_ 重新排列 fleet 中的我方舰船坐标，并叠加属性倍率。
--- @param fleet table  玩家舰队数组
local function applyFormationPositions(fleet)
    local fc = FORMATION_CONFIG[currentFormation_]
    if not fc then return end

    local midY = (screenH_ + 88) / 2
    local count = #fleet
    if count == 0 then return end

    if currentFormation_ == "encircle" then
        -- 包围阵型：上半组 (index <= half) 靠上，下半组靠下
        local half = math.ceil(count / 2)
        local topY1    = 88 + (screenH_ - 88) * 0.12   -- 上组顶端
        local botY1    = 88 + (screenH_ - 88) * 0.55   -- 下组顶端
        local groupH   = (screenH_ - 88) * 0.30         -- 每组纵向范围
        for i, ship in ipairs(fleet) do
            if i <= half then
                local t = half > 1 and (i - 1) / (half - 1) or 0.5
                ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
                ship.y = topY1 + t * groupH
            else
                local j = i - half
                local botCount = count - half
                local t = botCount > 1 and (j - 1) / (botCount - 1) or 0.5
                ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
                ship.y = botY1 + t * groupH
            end
        end
    else
        -- 突击 / 防守：以 midY 为轴均匀分布
        local spread = fc.posYSpread
        for i, ship in ipairs(fleet) do
            local t = count > 1 and (i - 1) / (count - 1) or 0.5
            ship.x = fc.posX + math.random(-fc.posXSpread, fc.posXSpread)
            ship.y = midY + fc.posYBase + (t - 0.5) * spread * 2
            -- 钳位在战场范围内
            ship.y = math.max(92, math.min(screenH_ - 12, ship.y))
        end
    end

    -- 叠加属性倍率（仅乘以 baseStats，而非每次重叠）
    for _, ship in ipairs(fleet) do
        local cfg = SHIP_TYPES[ship.stype]
        -- 重新计算基础值以避免多次叠加
        local hm = (rm_ and rm_.baseBonus and rm_.baseBonus.shipHealthMult) or 1.0
        local dm = (rm_ and rm_.baseBonus and rm_.baseBonus.shipDmgMult)    or 1.0
        local baseHP  = math.floor(cfg.health * hm)
        local baseDMG = cfg.dmg * dm
        local baseSpd = cfg.speed

        ship.speed    = baseSpd * fc.speedMult
        ship.dmg      = baseDMG * fc.dmgMult
        -- 血量：先按 healthMult 调整最大值，再按比例折算当前血量
        local newMax  = math.floor(baseHP  * fc.healthMult)
        local ratio   = ship.maxHealth > 0 and (ship.health / ship.maxHealth) or 1.0
        ship.maxHealth = newMax
        ship.health    = math.max(1, math.floor(newMax * ratio))
    end
end

--- 公开接口：切换阵型并立即重新排列当前存活舰队
function BattleScene.SetFormation(name)
    if not FORMATION_CONFIG[name] then return end
    if currentFormation_ == name then return end
    currentFormation_ = name
    applyFormationPositions(playerFleet_)
    if notifyFn_ then
        local fc = FORMATION_CONFIG[name]
        notifyFn_("阵型切换：" .. fc.label .. " — " .. fc.desc, "info")
    end
end

--- 公开接口：查询当前阵型
function BattleScene.GetFormation()
    return currentFormation_
end

-- ============================================================================
-- 波次配置（波次越高敌舰越强）
-- ============================================================================
local function buildEnemyWave(wave)
    local fleet = {}
    local battleH = screenH_ - 88
    -- 基础敌舰数 = 2 + wave，上限随波次提高
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    for i = 1, count do
        local stype
        local roll = math.random()
        if wave <= 1 then
            stype = roll < 0.7 and "SCOUT" or "FRIGATE"
        elseif wave <= 3 then
            stype = roll < 0.4 and "SCOUT" or (roll < 0.8 and "FRIGATE" or "DESTROYER")
        elseif wave <= 5 then
            stype = roll < 0.2 and "SCOUT" or (roll < 0.6 and "FRIGATE" or "DESTROYER")
        elseif wave <= 9 then
            -- 波次 6-9：战列舰 + 开始混入拦截舰群
            if roll < 0.15 then
                stype = "BATTLECRUISER"
            elseif roll < 0.40 then
                stype = "INTERCEPTOR"  -- 廉价快速，成群出现
            elseif roll < 0.70 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        else
            -- 波次 10+：母舰时代，拦截舰大量出现
            if roll < 0.10 then
                stype = "BATTLECRUISER"
            elseif roll < 0.45 then
                stype = "INTERCEPTOR"
            elseif roll < 0.65 then
                stype = "DESTROYER"
            else
                stype = "FRIGATE"
            end
        end
        local x = screenW_ - 100 - math.random() * 100
        local y = 88 + battleH * 0.05 + math.random() * battleH * 0.9
        fleet[#fleet+1] = makeShip(stype, x, y, "enemy")
    end
    -- 波次 8+（非Boss波）：额外添加 1 艘敌方战列舰
    if wave >= 8 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW_ - 60 - math.random() * 40
        local y = 88 + battleH * 0.3 + math.random() * battleH * 0.4
        fleet[#fleet+1] = makeShip("BATTLECRUISER", x, y, "enemy")
    end
    -- 波次 10+（非Boss波）：额外派遣 1 艘敌方母舰压阵
    if wave >= 10 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        local x = screenW_ - 50 - math.random() * 30
        local y = 88 + battleH * 0.35 + math.random() * battleH * 0.3
        fleet[#fleet+1] = makeShip("CARRIER", x, y, "enemy")
    end
    -- Boss波次（每隔 BOSS_WAVE_INTERVAL 波）：生成强化旗舰 Boss
    if wave % BOSS_WAVE_INTERVAL == 0 then
        local bossType = wave >= 10 and "CARRIER" or "BATTLECRUISER"
        local bx = screenW_ - 60 - math.random() * 30
        local by = 88 + battleH * 0.4 + math.random() * battleH * 0.2
        fleet[#fleet+1] = makeBossShip(bossType, bx, by)
    end
    return fleet
end

-- ============================================================================
-- 波次预报：纯预测，无随机，返回下一波的舰型组成
-- ============================================================================
-- 返回格式: { total=N, groups={ {stype, name, count, isBoss} } }
local function getNextWavePreview(wave)
    local count = math.min(2 + wave, wave >= 7 and 12 or 8)
    -- 各舰型期望比例（与 buildEnemyWave 概率一致）
    local distrib
    if wave <= 1 then
        distrib = { {s="SCOUT",prob=0.70},{s="FRIGATE",prob=0.30} }
    elseif wave <= 3 then
        distrib = { {s="SCOUT",prob=0.40},{s="FRIGATE",prob=0.40},{s="DESTROYER",prob=0.20} }
    elseif wave <= 5 then
        distrib = { {s="SCOUT",prob=0.20},{s="FRIGATE",prob=0.20},{s="DESTROYER",prob=0.60} }
    elseif wave <= 9 then
        distrib = { {s="BATTLECRUISER",prob=0.15},{s="INTERCEPTOR",prob=0.25},{s="DESTROYER",prob=0.30},{s="FRIGATE",prob=0.30} }
    else
        distrib = { {s="BATTLECRUISER",prob=0.10},{s="INTERCEPTOR",prob=0.35},{s="DESTROYER",prob=0.20},{s="FRIGATE",prob=0.35} }
    end
    local groups = {}
    for _, d in ipairs(distrib) do
        local est = math.max(1, math.floor(count * d.prob + 0.5))
        local cfg = SHIP_TYPES[d.s]
        groups[#groups+1] = { stype=d.s, name=(cfg and cfg.name or d.s), count=est }
    end
    -- Boss波预告
    if wave % BOSS_WAVE_INTERVAL == 0 then
        local bossType = wave >= 10 and "CARRIER" or "BATTLECRUISER"
        local bossName = bossType == "CARRIER" and "⚠️旗舰BOSS·母舰" or "⚠️旗舰BOSS·战列"
        groups[#groups+1] = { stype=bossType, name=bossName, count=1, isBoss=true }
    elseif wave >= 8 then
        groups[#groups+1] = { stype="BATTLECRUISER", name="旗舰", count=1, isBoss=true }
    end
    if wave >= 10 and wave % BOSS_WAVE_INTERVAL ~= 0 then
        groups[#groups+1] = { stype="CARRIER", name="母舰", count=1, isBoss=true }
    end
    return { total=count, groups=groups, isBossWave=(wave % BOSS_WAVE_INTERVAL == 0) }
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
    pendingShips_= {}
    -- 海盗进攻时从指定波次开始（pirateLevel 1~5 对应 wave 1~5）
    waveNum_     = math.max(1, opts.startWave or 1)

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
    -- 根据波次生成敌方舰队
    enemyFleet_      = buildEnemyWave(waveNum_)
    projectiles_     = {}
    floatTexts_      = {}
    fireParticles_   = {}
    fireTimer_       = 0
    explParticles_   = {}
    hitSparks_       = {}
    shockRings_      = {}
    shakeTimer_      = 0
    shakeStrength_   = 0
    shakeOffX_       = 0
    shakeOffY_       = 0
    fwParticles_            = {}
    fwLaunchTimer_          = 0
    interceptorEngineTimer_ = 0
    -- P3-1: 初始化背景星星（只在首次或全局重置时生成）
    if #bgStars_ == 0 then
        bgStars_ = {}
        bgScrollX_ = 0
        bgScrollY_ = 0
        -- layer 1: 远景小星（慢速，暗淡）
        for _ = 1, 60 do
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
        for _ = 1, 35 do
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
        for _ = 1, 12 do
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
    -- P1-1: 每波统计清零
    waveKills_     = 0
    waveMaxCombo_  = 0
    waveDmgDealt_  = 0
    waveShipsLost_ = 0
    waveSummary_   = nil
    selectedShip_  = nil  -- P2-2: 重置时取消选中
    focusTarget_   = nil  -- P2-2: 重置集火目标
    initialPlayerCount_  = #playerFleet_
    currentWaveStar_     = 0
    starAnim_            = 0
    moveTarget_             = nil
    moveTargetTimer_ = 0
    state_           = "fighting"
    stateTimer_      = 0
    battleEndFired_  = false
    waveGapTimer_    = 0
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
    bossDefeated_    = false
    bossFlashAlpha_  = 0
    bossFlashTimer_  = 0
    if waveNum_ % BOSS_WAVE_INTERVAL == 0 then
        bossWarningTimer_ = BOSS_WARNING_DUR
    else
        bossWarningTimer_ = 0
    end
    -- P1-1: 按当前阵型重新排布玩家舰队位置和属性
    applyFormationPositions(playerFleet_)

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
    enemyFleet_       = buildEnemyWave(waveNum_)
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
    if isBossW then
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
    -- P1-1: 新波次按阵型重新排布（仅对新加入的舰船；存活舰船保持原位）
    applyFormationPositions(playerFleet_)
    -- P1-1 NOVA_CANNON: 新波次开始时预充能技能
    if rm_ and rm_.baseBonus and rm_.baseBonus.battleStartSkillCharge then
        BattleSkills.PreChargeOnWaveStart(rm_.baseBonus.battleStartSkillCharge)
    end
    -- P1-1 FORTRESS_PROTOCOL: 护盾回复计时器清零
    fortressRegenTimer_ = 0

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
    print("[BattleScene] Wave " .. waveNum_ .. " 开始  敌方: " .. #enemyFleet_ .. "  阵型: " .. currentFormation_)
end

-- ============================================================================
-- 工具
-- ============================================================================
local function dist2(x1,y1,x2,y2)
    local dx,dy = x2-x1, y2-y1
    return math.sqrt(dx*dx+dy*dy)
end

local function clamp(v,lo,hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet)
    local best, bd = nil, math.huge
    for _, s in ipairs(fleet) do
        local d = dist2(ship.x, ship.y, s.x, s.y)
        if d < bd then best=s; bd=d end
    end
    return best, bd
end

-- ============================================================================
-- 特效辅助函数（模块级，Update 和 Render 均可调用）
-- ============================================================================

--- 生成击中火花（投射物命中时瞬间爆散）
local function spawnHitSparks(x, y, dmg, team)
    local count = math.min(10, 3 + math.floor(dmg / 20))
    local speed = 40 + math.min(80, dmg * 0.8)
    local r, g, b
    if team == "enemy" then
        r, g, b = 100 + math.random(80), 200 + math.random(55), 255
    else
        r, g, b = 255, 120 + math.random(80), math.random(60)
    end
    for _ = 1, count do
        local ang = math.random() * math.pi * 2
        local spd = speed * (0.4 + math.random() * 0.8)
        hitSparks_[#hitSparks_ + 1] = {
            x = x + (math.random()-0.5) * 4,
            y = y + (math.random()-0.5) * 4,
            vx = math.cos(ang) * spd,
            vy = math.sin(ang) * spd,
            life    = 0.18 + math.random() * 0.14,
            maxLife = 0.32,
            r = r, g = g, b = b,
        }
    end
end

--- 生成冲击波扩张光环（大型武器/AOE 命中时）
local function spawnShockRing(x, y, maxR, dur, r, g, b)
    shockRings_[#shockRings_ + 1] = {
        x = x, y = y,
        radius = 0, maxRadius = maxR,
        life = dur, maxLife = dur,
        r = r, g = g, b = b,
        width = math.max(1.5, maxR * 0.08),
    }
end

-- ============================================================================
-- 逻辑更新
-- ============================================================================
function BattleScene.Update(dt)
    shootSfxTimer_ = math.max(0, shootSfxTimer_ - dt)
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- === P1-2: 增援冷却倒计时 ===
    if reinforceCooldown_ > 0 then
        reinforceCooldown_ = math.max(0, reinforceCooldown_ - dt)
    end

    -- === P3-1: 背景星星视差滚动 + 闪烁更新 ===
    bgScrollX_ = bgScrollX_ + BG_SCROLL_VX * dt
    bgScrollY_ = bgScrollY_ + BG_SCROLL_VY * dt
    for _, s in ipairs(bgStars_) do
        s.twinklePhase = s.twinklePhase + s.twinkleSpeed * dt
    end

    -- === P3-2: 全屏闪光衰减 + Boss 横幅倒计时 ===
    if bossFlashAlpha_ > 0 then
        bossFlashAlpha_ = math.max(0, bossFlashAlpha_ - dt * 280)
    end
    if bossFlashTimer_ > 0 then
        bossFlashTimer_ = bossFlashTimer_ - dt
    end

    -- === P1-2: 战斗环境更新 ===
    if envAnnounceTimer_ > 0 then
        envAnnounceTimer_ = envAnnounceTimer_ - dt
        -- 渐出阶段（最后 0.5 秒淡出）
        if envAnnounceTimer_ < 0.5 then
            envAnnounceAlpha_ = math.floor(envAnnounceTimer_ / 0.5 * 255)
        else
            envAnnounceAlpha_ = 255
        end
    end
    -- 环境粒子生成与更新
    local pt = currentEnv_.particleType
    if pt ~= "none" then
        -- 生成粒子（每帧少量生成）
        local spawnCount = 0
        if pt == "nebula" then spawnCount = 3
        elseif pt == "asteroid" then spawnCount = 2
        elseif pt == "magstor" then spawnCount = 2 end

        for _ = 1, spawnCount do
            local pr, pg, pb = currentEnv_.pR, currentEnv_.pG, currentEnv_.pB
            local p = {}
            if pt == "nebula" then
                -- 星云：慢漂移的半透明大雾团
                p.x      = math.random() * screenW_
                p.y      = math.random() * screenH_
                p.vx     = (math.random() - 0.5) * 8
                p.vy     = (math.random() - 0.5) * 6
                p.size   = 20 + math.random() * 50
                p.life   = 4.0 + math.random() * 3.0
                p.maxLife= p.life
                p.r      = pr + math.random(-20, 20)
                p.g      = pg + math.random(-10, 10)
                p.b      = pb + math.random(-20, 20)
                p.maxA   = 30 + math.random(20)   -- 最大透明度（低透保持背景可读）
            elseif pt == "asteroid" then
                -- 小行星带：从右向左快速飞过的小岩石
                p.x      = screenW_ + 10
                p.y      = 88 + math.random() * (screenH_ - 88)
                p.vx     = -(60 + math.random() * 80)
                p.vy     = (math.random() - 0.5) * 20
                p.size   = 2 + math.random() * 5
                p.life   = 2.0 + math.random() * 1.5
                p.maxLife= p.life
                p.r      = pr + math.random(-20, 20)
                p.g      = pg + math.random(-15, 15)
                p.b      = pb + math.random(-15, 15)
                p.maxA   = 160 + math.random(60)
            elseif pt == "magstor" then
                -- 磁暴：从底部向上快速划过的绿色电弧线段
                p.x      = math.random() * screenW_
                p.y      = screenH_ + 10
                p.vx     = (math.random() - 0.5) * 30
                p.vy     = -(80 + math.random() * 120)
                p.size   = 1.0 + math.random() * 1.5   -- 线宽
                p.len    = 8 + math.random() * 20       -- 线长
                p.life   = 0.4 + math.random() * 0.4
                p.maxLife= p.life
                p.r      = pr + math.random(-10, 40)
                p.g      = pg + math.random(-20, 20)
                p.b      = pb + math.random(-10, 10)
                p.maxA   = 180 + math.random(60)
            end
            p.r = math.max(0, math.min(255, p.r))
            p.g = math.max(0, math.min(255, p.g))
            p.b = math.max(0, math.min(255, p.b))
            envParticles_[#envParticles_ + 1] = p
        end

        -- 更新 + 清理粒子
        local pi = 1
        while pi <= #envParticles_ do
            local p = envParticles_[pi]
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(envParticles_, pi)
            else
                pi = pi + 1
            end
        end

        -- 小行星带：周期性碎片伤害
        if pt == "asteroid" and state_ == "fighting" then
            envAsteroidTimer_ = envAsteroidTimer_ - dt
            if envAsteroidTimer_ <= 0 then
                envAsteroidTimer_ = currentEnv_.asteroidInterval or 2.0
                -- 随机命中一艘舰船（我方或敌方各 50%）
                local allShips = {}
                for _, s in ipairs(playerFleet_) do allShips[#allShips+1] = {s=s, team="player"} end
                for _, s in ipairs(enemyFleet_)  do allShips[#allShips+1] = {s=s, team="enemy"} end
                if #allShips > 0 then
                    local target = allShips[math.random(#allShips)]
                    local dmg = currentEnv_.asteroidDamage
                    target.s.health = target.s.health - dmg
                    target.s.hitFlash = 0.6
                    spawnHitSparks(target.s.x, target.s.y, dmg, target.team)
                    floatTexts_[#floatTexts_+1] = {
                        x      = target.s.x, y = target.s.y - 20,
                        text   = "☄-" .. dmg,
                        life   = 1.0, maxLife = 1.0,
                        vy     = -28, team = target.team,
                    }
                end
            end
        end
    end

    -- === 连击计时更新（P2-2: 超时结算 credits 奖励）===
    if comboCount_ > 0 then
        comboTimer_ = comboTimer_ + dt
        if comboTimer_ >= COMBO_RESET_TIME then
            -- 连击结束：≥3连击才给予 credits 奖励
            if comboCount_ >= 3 and rm_ then
                local credits = comboCount_ * 20
                rm_:add("credits", credits)
                -- 屏幕中央飘字提示
                floatTexts_[#floatTexts_+1] = {
                    x = screenW_ * 0.5,
                    y = screenH_ * 0.38,
                    text = string.format("连击奖励 +%d 星币！", credits),
                    life = 2.0, maxLife = 2.0, vy = -16, team = "combo_reward"
                }
            end
            comboCount_ = 0
            comboTimer_ = 0
        end
    end
    if comboDisplayTimer_ > 0 then
        comboDisplayTimer_ = math.max(0, comboDisplayTimer_ - dt)
    end

    -- === 主动技能计时 ===
    if state_ == "fighting" then
        BattleSkills.Update(dt, {
            state       = state_,
            rs          = rs_,
            notifyFn    = notifyFn_,
            playerFleet = playerFleet_,
            floatTexts  = floatTexts_,
            screenW     = screenW_,
            screenH     = screenH_,
            makeShip    = makeShip,
        })
        -- P1-1 FORTRESS_PROTOCOL: 每10s为玩家舰队回复 shieldRegenPct 的 HP
        if rm_ and rm_.baseBonus and rm_.baseBonus.shieldRegenPct then
            fortressRegenTimer_ = fortressRegenTimer_ + dt
            if fortressRegenTimer_ >= 10.0 then
                fortressRegenTimer_ = fortressRegenTimer_ - 10.0
                local regen = rm_.baseBonus.shieldRegenPct
                for _, ship in ipairs(playerFleet_) do
                    if ship.health > 0 then
                        local heal = math.max(1, math.floor(ship.maxHealth * regen))
                        ship.health = math.min(ship.maxHealth, ship.health + heal)
                    end
                end
                print("[Battle] FORTRESS_PROTOCOL 护盾回复 " .. tostring(math.floor(regen*100)) .. "% HP")
            end
        end
    end

    if state_ == "lose" then
        stateTimer_ = stateTimer_ + dt
        if stateTimer_ > 3.0 and onBattleEnd_ and not battleEndFired_ then
            battleEndFired_ = true
            onBattleEnd_("lose")
        end
        return
    end

    if state_ == "win" then
        -- 显示倒计时后自动进入下一波
        waveGapTimer_ = waveGapTimer_ + dt
        stateTimer_   = stateTimer_ + dt  -- P1-1: 驱动战报摘要淡入淡出
        starAnim_     = starAnim_ + dt   -- P3-3: 驱动星星依次亮起动画
        if waveGapTimer_ >= WAVE_GAP then
            BattleScene.StartNextWave()
        end
        -- 烟花粒子：周期性发射
        fwLaunchTimer_ = fwLaunchTimer_ - dt
        if fwLaunchTimer_ <= 0 then
            fwLaunchTimer_ = 0.22 + math.random() * 0.18
            -- 随机颜色
            local hue = math.random()
            local r = math.floor(128 + 127 * math.abs(math.sin(hue * math.pi * 2)))
            local g = math.floor(128 + 127 * math.abs(math.sin((hue + 0.33) * math.pi * 2)))
            local b = math.floor(128 + 127 * math.abs(math.sin((hue + 0.66) * math.pi * 2)))
            local cx = screenW_ * (0.15 + math.random() * 0.7)
            local cy = screenH_ * (0.1 + math.random() * 0.4)
            -- 爆炸碎片（18 粒）
            for _ = 1, 18 do
                local angle = math.random() * math.pi * 2
                local spd   = 55 + math.random() * 95
                fwParticles_[#fwParticles_+1] = {
                    x = cx, y = cy,
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 40,   -- 轻微上飘偏向
                    life = 0.7 + math.random() * 0.5,
                    maxLife = 1.2,
                    r = r, g = g, b = b,
                }
            end
        end
        -- 更新烟花粒子
        local i = 1
        while i <= #fwParticles_ do
            local p = fwParticles_[i]
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            p.vy   = p.vy + 60 * dt   -- 重力
            p.life = p.life - dt
            if p.life <= 0 then
                fwParticles_[i] = fwParticles_[#fwParticles_]
                fwParticles_[#fwParticles_] = nil
            else
                i = i + 1
            end
        end
        return
    end

    -- === 玩家舰队 ===
    -- 相位加速：激活时移速×(2.5 * effectMult)，Lv3 最高 ×5.0
    local phaseMult = BattleSkills.IsActive(5) and (2.5 * BattleSkills.GetEffectMult(5)) or 1.0
    for _, ship in ipairs(playerFleet_) do
        if ship.target then
            local dx = ship.target.x - ship.x
            local dy = ship.target.y - ship.y
            local d  = math.sqrt(dx*dx + dy*dy)
            if d > 4 then
                local spd = ship.speed * dt * phaseMult
                ship.x = ship.x + dx/d * spd
                ship.y = ship.y + dy/d * spd
                ship.vx = dx/d; ship.vy = dy/d
            else
                ship.target = nil
                ship.vx=0; ship.vy=0
            end
        end
        ship.x = clamp(ship.x, 10, screenW_-10)
        ship.y = clamp(ship.y, 88, screenH_-10)

        if #enemyFleet_ > 0 then
            -- P2-2: 集火指令 — 优先攻击指定目标，目标死亡时自动恢复 findNearest
            local nearest, nd
            if focusTarget_ and focusTarget_.health > 0 then
                nearest = focusTarget_
                nd = dist2(ship.x, ship.y, focusTarget_.x, focusTarget_.y)
            else
                if focusTarget_ then focusTarget_ = nil end  -- 目标已死，清除
                nearest, nd = findNearest(ship, enemyFleet_)
            end
            if nearest and nd < ship.range then
                ship.lastShot = ship.lastShot + dt
                if ship.lastShot >= 1.0 / ship.shotRate then
                    ship.lastShot = 0
                    -- 全体集火：激活时伤害×(1+effectMult)，Lv3 最高 ×3.0
                    local focusMult = BattleSkills.IsActive(1) and (1.0 + BattleSkills.GetEffectMult(1)) or 1.0
                    local actualDmg = math.floor(ship.dmg * focusMult)
                    -- 主目标伤害（Boss 护盾优先吸收，磁暴降低吸收率）
                    if nearest.isBoss and nearest.shield > 0 then
                        local shieldAbsorbRate = currentEnv_.shieldAbsorb or 1.0
                        local absorbed = math.floor(math.min(nearest.shield, actualDmg) * shieldAbsorbRate)
                        nearest.shield = math.max(0, nearest.shield - absorbed)
                        actualDmg = actualDmg - absorbed
                    end
                    nearest.health = nearest.health - actualDmg
                    nearest.hitFlash = 1.0
                    battleStats_.dmgDealt = battleStats_.dmgDealt + actualDmg
                    waveDmgDealt_ = waveDmgDealt_ + actualDmg  -- P1-1
                    -- P3-2: 追踪单舰伤害 + 击杀归属
                    ship.statDmg = ship.statDmg + actualDmg
                    nearest.lastHitter = ship
                    -- 击中特效：火花 + 大伤害冲击波环
                    spawnHitSparks(nearest.x, nearest.y, actualDmg, "enemy")
                    if actualDmg >= 30 or ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER" then
                        spawnShockRing(nearest.x, nearest.y,
                            math.max(18, actualDmg * 0.6), 0.22, 80, 200, 255)
                    end
                    -- 战列舰 AOE：对主目标周围所有敌舰造成 50% 溅射伤害
                    if ship.aoeRadius > 0 then
                        local aoeDmg = math.floor(actualDmg * 0.5)
                        -- AOE 冲击波（以目标为中心的大环）
                        spawnShockRing(nearest.x, nearest.y,
                            ship.aoeRadius, 0.35, 80, 220, 255)
                        for _, splash in ipairs(enemyFleet_) do
                            if splash ~= nearest then
                                local sx = splash.x - nearest.x
                                local sy = splash.y - nearest.y
                                if sx*sx + sy*sy <= ship.aoeRadius * ship.aoeRadius then
                                    splash.health = splash.health - aoeDmg
                                    battleStats_.dmgDealt = battleStats_.dmgDealt + aoeDmg
                                    -- P3-2: AOE 伤害也归属到该舰
                                    ship.statDmg = ship.statDmg + aoeDmg
                                    splash.lastHitter = ship
                                    spawnHitSparks(splash.x, splash.y, aoeDmg, "enemy")
                                    floatTexts_[#floatTexts_+1] = {
                                        x=splash.x + math.random(-4,4), y=splash.y - 14,
                                        text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                        vy=-28, team="enemy"
                                    }
                                end
                            end
                        end
                    end
                    projectiles_[#projectiles_+1] = {
                        x=ship.x, y=ship.y,
                        tx=nearest.x, ty=nearest.y,
                        team="player", life=0.15,
                        isBig = (ship.stype == "BATTLECRUISER")
                    }
                    if shootSfxTimer_ <= 0 then
                        local sfx
                        if ship.stype == "CARRIER" then
                            sfx = Audio.SFX.CARRIER_ATTACK
                        elseif ship.stype == "BATTLECRUISER" or ship.stype == "DESTROYER" then
                            sfx = Audio.SFX.SHOOT_MISSILE
                        else
                            sfx = Audio.SFX.SHOOT_LASER
                        end
                        Audio.Play(sfx, 0.5)
                        shootSfxTimer_ = 0.12
                    end
                    -- 飘字：敌舰受到伤害（集火时显示实际伤害）
                    -- P3-2: 暴击判断（伤害 ≥ 目标满血量的30%）
                    local isCrit = actualDmg >= nearest.maxHealth * 0.3
                    local dmgText = isCrit
                        and ("-" .. actualDmg .. "!!")
                        or ((focusMult > 1.0)
                            and ("-" .. actualDmg .. "!")
                            or  ("-" .. actualDmg))
                    floatTexts_[#floatTexts_+1] = {
                        x=nearest.x + math.random(-6,6),
                        y=nearest.y - 16,
                        text=dmgText,
                        life = isCrit and 1.2 or 0.9,
                        maxLife = isCrit and 1.2 or 0.9,
                        vy = isCrit and -50 or -38,
                        team="enemy",
                        isCrit = isCrit,
                    }
                end
            end
        end
    end

    -- === 敌方 AI ===
    -- P1-2: 星云环境降低敌方射程
    local envEnemyRangeMult = currentEnv_.enemyRangeMult or 1.0
    for _, es in ipairs(enemyFleet_) do
        if #playerFleet_ > 0 then
            local target, td = findNearest(es, playerFleet_)
            if target then
                -- EMP冲击：敌方移速降低（Lv3 更强，最低降至 12.5%）
                local empMult = BattleSkills.IsActive(3) and math.max(0.05, 0.25 / BattleSkills.GetEffectMult(3)) or 1.0
                local effectiveRange = es.range * envEnemyRangeMult
                if td > effectiveRange * 0.8 then
                    local dx = target.x - es.x
                    local dy = target.y - es.y
                    local d  = math.sqrt(dx*dx+dy*dy)
                    if d > 4 then
                        local spd = es.speed * dt * empMult
                        es.x = es.x + dx/d * spd
                        es.y = es.y + dy/d * spd
                        es.vx = dx/d; es.vy = dy/d
                    end
                end
                -- 护盾强化：我方受伤减少（Lv3 最高减至 25%）
                local shieldMult = BattleSkills.IsActive(4) and math.max(0.1, 0.5 / BattleSkills.GetEffectMult(4)) or 1.0
                if td < effectiveRange then
                    -- EMP同时降低敌方射速（倍率复用 empMult）
                    es.lastShot = es.lastShot + dt * empMult
                    if es.lastShot >= 1.0 / es.shotRate then
                        es.lastShot = 0
                        -- 主目标伤害（护盾强化时减半）
                        local actualEsDmg = math.floor(es.dmg * shieldMult)
                        target.health = target.health - actualEsDmg
                        target.hitFlash = 1.0
                        battleStats_.dmgTaken = battleStats_.dmgTaken + actualEsDmg
                        -- 敌方命中玩家：橙红火花
                        spawnHitSparks(target.x, target.y, actualEsDmg, "player")
                        -- 敌方战列舰 AOE
                        if es.aoeRadius > 0 then
                            local aoeDmg = math.floor(es.dmg * 0.5)
                            spawnShockRing(target.x, target.y,
                                es.aoeRadius, 0.30, 255, 120, 40)
                            for _, splash in ipairs(playerFleet_) do
                                if splash ~= target then
                                    local sx = splash.x - target.x
                                    local sy = splash.y - target.y
                                    if sx*sx + sy*sy <= es.aoeRadius * es.aoeRadius then
                                        splash.health = splash.health - aoeDmg
                                        battleStats_.dmgTaken = battleStats_.dmgTaken + aoeDmg
                                        spawnHitSparks(splash.x, splash.y, aoeDmg, "player")
                                        floatTexts_[#floatTexts_+1] = {
                                            x=splash.x + math.random(-4,4), y=splash.y - 14,
                                            text="-"..aoeDmg, life=0.7, maxLife=0.7,
                                            vy=-28, team="player"
                                        }
                                    end
                                end
                            end
                        end
                        projectiles_[#projectiles_+1] = {
                            x=es.x, y=es.y,
                            tx=target.x, ty=target.y,
                            team="enemy", life=0.15,
                            isBig = (es.stype == "BATTLECRUISER")
                        }
                        -- 飘字：我方舰船受到伤害（护盾强化时显示减伤）
                        local dmgLabel = (shieldMult < 1.0)
                            and ("-" .. actualEsDmg .. "🛡")
                            or  ("-" .. actualEsDmg)
                        floatTexts_[#floatTexts_+1] = {
                            x=target.x + math.random(-6,6),
                            y=target.y - 16,
                            text=dmgLabel,
                            life=0.9, maxLife=0.9,
                            vy=-38,
                            team="player"
                        }
                    end
                end
            end
        end
        es.x = clamp(es.x, 10, screenW_-10)
        es.y = clamp(es.y, 88, screenH_-10)
    end

    -- === 辅助：生成爆炸粒子 + 屏幕震动 ===
    local function spawnExplosion(ship)
        local st  = ship.stype
        local isBig = (st == "BATTLECRUISER" or st == "DESTROYER"
                       or st == "CARRIER")
        local count  = isBig and 22 or 10
        local speed  = isBig and 90 or 50
        local life   = isBig and 0.7 or 0.45
        -- 核心白光闪
        explParticles_[#explParticles_+1] = {
            x=ship.x, y=ship.y, vx=0, vy=0,
            life=0.18, maxLife=0.18,
            r=255, g=255, b=255, size=isBig and 22 or 12,
            ptype="flash"
        }
        -- 碎片
        for _ = 1, count do
            local angle = math.random() * math.pi * 2
            local spd   = speed * (0.5 + math.random() * 0.8)
            local r, g, b
            if ship.team == "player" then
                r, g, b = 80+math.random(60), 160+math.random(60), 255
            else
                r, g, b = 255, 80+math.random(80), math.random(40)
            end
            explParticles_[#explParticles_+1] = {
                x    = ship.x + (math.random()-0.5) * 8,
                y    = ship.y + (math.random()-0.5) * 8,
                vx   = math.cos(angle) * spd,
                vy   = math.sin(angle) * spd,
                life = life * (0.6 + math.random() * 0.6),
                maxLife = life,
                r=r, g=g, b=b,
                size = isBig and (3 + math.random()*4) or (1.5 + math.random()*2),
                ptype="shard"
            }
        end
        -- 屏幕震动（叠加，取较大值）
        local str = isBig and 6.0 or 2.5
        local dur = isBig and 0.28 or 0.14
        if str > shakeStrength_ or shakeTimer_ <= 0 then
            shakeStrength_ = str
            shakeDur_      = dur
            shakeTimer_    = dur
        end
    end

    -- === 清理死亡舰船（爆炸粒子 + 音效 + 震动）===
    for i = #playerFleet_, 1, -1 do
        if playerFleet_[i].health <= 0 then
            local ship = playerFleet_[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            spawnExplosion(ship)
            waveShipsLost_          = waveShipsLost_ + 1  -- P1-1: 本波损失舰船
            battleStats_.shipsLost  = battleStats_.shipsLost + 1  -- P2-3
            table.remove(playerFleet_, i)
        end
    end
    for i = #enemyFleet_, 1, -1 do
        if enemyFleet_[i].health <= 0 then
            local ship = enemyFleet_[i]
            local st   = ship.stype
            local sfx  = (st == "BATTLECRUISER" or st == "DESTROYER" or st == "CARRIER")
                and Audio.SFX.EXPLOSION_BIG or Audio.SFX.EXPLOSION_SMALL
            Audio.Play(sfx, 0.7)
            spawnExplosion(ship)
            battleStats_.enemiesKilled = battleStats_.enemiesKilled + 1
            waveKills_ = waveKills_ + 1  -- P1-1: 本波击杀累计
            -- P2-3: 过度击杀统计（超出血量的伤害比例）
            if ship.maxHealth and ship.maxHealth > 0 and ship.health < 0 then
                local overkillRatio = (-ship.health) / ship.maxHealth
                if overkillRatio > battleStats_.overkillMax then
                    battleStats_.overkillMax = overkillRatio
                end
            end
            -- P2-3: 集火击杀统计 (overkillMax 由攻击时追踪，focusBossKill 在此处)
            if focusTarget_ == ship then
                focusTarget_ = nil
                if ship.isBoss then battleStats_.focusBossKill = true end
                -- 集火击杀通知（供 Client.lua 读取后触发成就）
                if battleStats_.focusKillCount then
                    battleStats_.focusKillCount = battleStats_.focusKillCount + 1
                else
                    battleStats_.focusKillCount = 1
                end
            end
            -- P3-2: 击杀归属到最后一次打这艘敌舰的玩家舰
            if ship.lastHitter then
                ship.lastHitter.statKills = ship.lastHitter.statKills + 1
            end
            -- === 连击系统 ===
            comboCount_ = comboCount_ + 1
            comboTimer_ = 0          -- 重置重置倒计时
            comboDisplayTimer_ = 2.0 -- 显示2秒
            if comboCount_ > waveMaxCombo_ then waveMaxCombo_ = comboCount_ end  -- P1-1
            local lv = getComboLevel()
            if lv then
                -- P2-2: 连击飘字（击杀位置上方），credits 奖励在连击结束时统一结算
                floatTexts_[#floatTexts_+1] = {
                    x=ship.x, y=ship.y - 30,
                    text=string.format("x%d %s", comboCount_, lv.label),
                    life=1.2, maxLife=1.2, vy=-22, team="combo"
                }
            elseif comboCount_ >= 2 then
                floatTexts_[#floatTexts_+1] = {
                    x=ship.x, y=ship.y - 26,
                    text=string.format("x%d", comboCount_),
                    life=0.9, maxLife=0.9, vy=-18, team="combo"
                }
            end
            -- Boss 击败：额外奖励 + 多次爆炸 + 屏幕震动
            if ship.isBoss and not bossDefeated_ then
                bossDefeated_ = true
                -- 额外爆炸特效（3次）
                for _ = 1, 3 do spawnExplosion(ship) end
                -- 强烈屏幕震动
                shakeStrength_ = 12
                shakeDur_      = 0.5
                shakeTimer_    = 0.5
                -- P3-2: 全屏闪光 + BOSS DESTROYED 横幅
                bossFlashAlpha_ = 220
                bossFlashTimer_ = BOSS_BANNER_DUR
                -- P3-3: Boss击败 — 播放胜利fanfare + 恢复BGM正常音调
                Audio.PlayBGM(Audio.BGM.VICTORY_FANFARE, 0.8, false)
                Audio.ResetBGMPitch()
                -- 稀有资源奖励
                local nucBonus    = 80  + waveNum_ * 20
                local crystalBonus= 30  + waveNum_ * 10
                if rm_ then
                    rm_:add("nuclear", nucBonus)
                    rm_:add("crystal", crystalBonus)
                end
                if notifyFn_ then
                    notifyFn_(string.format("⚔️ BOSS已击败！核能+%d  水晶+%d", nucBonus, crystalBonus), "success")
                end
                print(string.format("[Boss] Wave%d Boss击败  核能+%d 水晶+%d", waveNum_, nucBonus, crystalBonus))
            end
            table.remove(enemyFleet_, i)
        end
    end

    -- === 更新子弹 ===
    for i = #projectiles_, 1, -1 do
        local p = projectiles_[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(projectiles_, i) end
    end

    -- === 更新飘字 ===
    for i = #floatTexts_, 1, -1 do
        local ft = floatTexts_[i]
        ft.y    = ft.y + ft.vy * dt
        ft.life = ft.life - dt
        if ft.life <= 0 then table.remove(floatTexts_, i) end
    end

    -- === 移动目标点自动消失（2 秒后淡出）===
    if moveTarget_ then
        moveTargetTimer_ = moveTargetTimer_ + dt
        if moveTargetTimer_ > 2.0 then
            moveTarget_      = nil
            moveTargetTimer_ = 0
        end
    end

    -- === 燃烧粒子：为低血量舰船生成火花 ===
    fireTimer_ = fireTimer_ + dt
    if fireTimer_ >= 0.05 then  -- 每 50ms 生成一批粒子
        fireTimer_ = 0
        local function spawnFire(fleet)
            for _, s in ipairs(fleet) do
                local hp = s.health / s.maxHealth
                if hp < 0.35 then
                    -- 血量越低，粒子越多越红
                    local count = hp < 0.15 and 3 or 1
                    for _ = 1, count do
                        local angle = math.random() * math.pi * 2
                        local speed = 15 + math.random() * 25
                        local r = hp < 0.15 and 255 or 220
                        local g = math.floor(hp * 300)
                        fireParticles_[#fireParticles_+1] = {
                            x    = s.x + (math.random()-0.5) * 10,
                            y    = s.y + (math.random()-0.5) * 10,
                            vx   = math.cos(angle) * speed,
                            vy   = math.sin(angle) * speed - 20,  -- 向上偏移
                            life = 0.4 + math.random() * 0.3,
                            maxLife = 0.7,
                            r    = r,
                            g    = math.max(0, math.min(255, g)),
                            size = 2 + math.random() * 2,
                        }
                    end
                end
            end
        end
        spawnFire(playerFleet_)
        spawnFire(enemyFleet_)
    end
    -- 更新/清理粒子
    local i = 1
    while i <= #fireParticles_ do
        local p = fireParticles_[i]
        p.x    = p.x + p.vx * dt
        p.y    = p.y + p.vy * dt
        p.vy   = p.vy + 40 * dt   -- 轻微重力
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(fireParticles_, i)
        else
            i = i + 1
        end
    end

    -- === 更新爆炸粒子 ===
    local ei = 1
    while ei <= #explParticles_ do
        local ep = explParticles_[ei]
        ep.x    = ep.x + ep.vx * dt
        ep.y    = ep.y + ep.vy * dt
        ep.vx   = ep.vx * (1 - dt * 3)   -- 阻力衰减
        ep.vy   = ep.vy * (1 - dt * 3) + 20 * dt  -- 轻微重力
        ep.life = ep.life - dt
        if ep.life <= 0 then
            table.remove(explParticles_, ei)
        else
            ei = ei + 1
        end
    end

    -- === 更新击中火花 ===
    local si = 1
    while si <= #hitSparks_ do
        local sp = hitSparks_[si]
        sp.x    = sp.x + sp.vx * dt
        sp.y    = sp.y + sp.vy * dt
        sp.vx   = sp.vx * (1 - dt * 6)
        sp.vy   = sp.vy * (1 - dt * 6) + 30 * dt
        sp.life = sp.life - dt
        if sp.life <= 0 then table.remove(hitSparks_, si)
        else si = si + 1 end
    end

    -- === 更新冲击波环 ===
    local ri = 1
    while ri <= #shockRings_ do
        local ring = shockRings_[ri]
        ring.life   = ring.life - dt
        -- 半径随时间扩张
        local frac  = 1 - ring.life / ring.maxLife
        ring.radius = ring.maxRadius * frac
        if ring.life <= 0 then table.remove(shockRings_, ri)
        else ri = ri + 1 end
    end

    -- === 衰减受击闪白 ===
    local flashDecay = dt * 8   -- 0.125 秒内衰减到 0
    for _, s in ipairs(playerFleet_) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end
    for _, s in ipairs(enemyFleet_) do
        if s.hitFlash > 0 then s.hitFlash = math.max(0, s.hitFlash - flashDecay) end
    end

    -- === INTERCEPTOR 引擎音效（节流 0.6s，有拦截舰高速移动时触发）===
    interceptorEngineTimer_ = math.max(0, interceptorEngineTimer_ - dt)
    if interceptorEngineTimer_ <= 0 then
        local hasMoving = false
        for _, s in ipairs(playerFleet_) do
            if s.stype == "INTERCEPTOR" and s.target and (s.vx ~= 0 or s.vy ~= 0) then
                hasMoving = true; break
            end
        end
        if not hasMoving then
            for _, s in ipairs(enemyFleet_) do
                if s.stype == "INTERCEPTOR" and (s.vx ~= 0 or s.vy ~= 0) then
                    hasMoving = true; break
                end
            end
        end
        if hasMoving then
            Audio.Play(Audio.SFX.INTERCEPTOR_ENGINE)
            interceptorEngineTimer_ = 0.6   -- 0.6s 冷却，避免连续叠放
        end
    end

    -- === 更新 Boss 警告计时 ===
    if bossWarningTimer_ > 0 then
        bossWarningTimer_ = bossWarningTimer_ - dt
    end

    -- === 更新屏幕震动 ===
    if shakeTimer_ > 0 then
        shakeTimer_ = shakeTimer_ - dt
        local frac  = shakeTimer_ / math.max(0.001, shakeDur_)
        local str   = shakeStrength_ * frac
        shakeOffX_  = (math.random() * 2 - 1) * str
        shakeOffY_  = (math.random() * 2 - 1) * str
        if shakeTimer_ <= 0 then
            shakeOffX_, shakeOffY_ = 0, 0
        end
    end

    -- === 判断胜负 ===
    if #playerFleet_ == 0 and state_ == "fighting" then
        state_ = "lose"
        stateTimer_ = 0
        if notifyFn_ then notifyFn_("舰队覆灭！战斗失败", "error") end
        if player_ then player_.battles = (player_.battles or 0) + 1 end
        print("[Battle] Wave " .. waveNum_ .. " 失败")
    elseif #enemyFleet_ == 0 and state_ == "fighting" then
        state_ = "win"
        stateTimer_ = 0
        waveGapTimer_ = 0
        battleStats_.wavesCleared = battleStats_.wavesCleared + 1
        -- P3-3: 计算本波星级评分（基于存活率）
        do
            local survivors  = #playerFleet_
            local initCount  = math.max(1, initialPlayerCount_)
            local ratio      = survivors / initCount
            if ratio >= 0.75 then
                currentWaveStar_ = 3  -- 精英：≥75% 存活
            elseif ratio >= 0.40 then
                currentWaveStar_ = 2  -- 良好：≥40% 存活
            else
                currentWaveStar_ = 1  -- 惨胜：< 40% 存活
            end
            starAnim_ = 0   -- 重置动画计时器，触发星星依次亮起
        end
        -- 记录存活最久舰型（以 maxHealth 作代理指标）
        if #playerFleet_ > 0 then
            local best = playerFleet_[1]
            for _, s in ipairs(playerFleet_) do
                if s.health > best.health then best = s end
            end
            battleStats_.bestSurvivor = best.stype
        end
        -- 波次胜利资源奖励（随波次递增）
        local mReward = 150 + waveNum_ * 80   -- 调优：基础 100→150，每波系数 50→80
        local eReward = 80  + waveNum_ * 40   -- 新增：能源奖励（减少精炼瓶颈）
        local cReward = 15  + waveNum_ * 8    -- 调优：基础 10→15，每波系数 5→8
        if rm_ then
            rm_:add("metal",   mReward)
            rm_:add("esource", eReward)
            rm_:add("nuclear", cReward)
        end
        if notifyFn_ then
            notifyFn_(string.format("第 %d 波胜利！金属+%d  能源+%d  核能+%d",
                waveNum_, mReward, eReward, cReward), "success")
        end
        -- P1-1: 保存本波摘要快照（在重置连击前捕获 waveMaxCombo_）
        -- P3-2: 计算本波 MVP（最高伤害玩家舰）
        local mvp = nil
        local mvpDmg = 0
        for _, ps in ipairs(playerFleet_) do
            if ps.statDmg > mvpDmg then
                mvpDmg = ps.statDmg
                mvp = { stype = ps.stype, dmg = ps.statDmg, kills = ps.statKills }
            end
        end
        waveSummary_ = {
            wave     = waveNum_,
            kills    = waveKills_,
            maxCombo = waveMaxCombo_,
            dmg      = math.floor(waveDmgDealt_),
            lost     = waveShipsLost_,
            mReward  = mReward,
            eReward  = eReward,
            cReward  = cReward,
            stars    = currentWaveStar_,
            mvp      = mvp,   -- P3-2: {stype, dmg, kills} 或 nil
        }
        -- 重置连击（新波次重新积累）
        comboCount_ = 0
        comboTimer_ = 0
        if player_ then
            player_.battles = (player_.battles or 0) + 1
            player_.wins    = (player_.wins or 0) + 1
            player_:addExp(200 + waveNum_ * 100)
        end
        print("[Battle] Wave " .. waveNum_ .. " 胜利  奖励: 金属+" .. mReward .. " 核能+" .. cReward)
        -- P2-2: 每 3 波发放 1 个技能点，触发升级弹窗
        if waveNum_ % 3 == 0 then
            BattleSkills.AddPoint()
            -- 生成 2 张可选升级卡（随机选非满级技能）
            local candidates = {}
            for skillN = 1, 6 do
                if BattleSkills.GetLevel(skillN) < 3 then
                    candidates[#candidates+1] = skillN
                end
            end
            if #candidates >= 2 then
                -- 随机打乱，取前 2
                for ci = #candidates, 2, -1 do
                    local j = math.random(1, ci)
                    candidates[ci], candidates[j] = candidates[j], candidates[ci]
                end
                skillUpgradeCards_ = { candidates[1], candidates[2] }
            elseif #candidates == 1 then
                skillUpgradeCards_ = { candidates[1] }
            end
        end
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================
-- ============================================================================
-- P1-2: 环境粒子渲染
-- ============================================================================
local function drawEnvParticles()
    if #envParticles_ == 0 then return end
    local pt = currentEnv_.particleType
    for _, p in ipairs(envParticles_) do
        local frac  = p.life / p.maxLife
        local alpha = math.floor(frac * (p.maxA or 200))
        if alpha <= 0 then goto continue end

        if pt == "nebula" then
            -- 大雾团：圆形渐变（中心稍亮，边缘淡出）
            local rad = p.size * (0.5 + frac * 0.5)  -- 先小后大
            nvgBeginPath(vg_)
            nvgCircle(vg_, p.x, p.y, math.max(1, rad))
            nvgFillColor(vg_, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgFill(vg_)
        elseif pt == "asteroid" then
            -- 小岩石：不规则多边形（用简单椭圆近似）
            nvgSave(vg_)
            nvgTranslate(vg_, p.x, p.y)
            nvgRotate(vg_, p.life * 1.5)  -- 自旋
            local s = p.size
            nvgBeginPath(vg_)
            nvgEllipse(vg_, 0, 0, s, s * 0.7)
            nvgFillColor(vg_, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgFill(vg_)
            -- 高光描边
            nvgStrokeColor(vg_, nvgRGBA(
                math.min(255, p.r + 60),
                math.min(255, p.g + 50),
                math.min(255, p.b + 30), math.floor(alpha * 0.5)))
            nvgStrokeWidth(vg_, 0.5)
            nvgStroke(vg_)
            nvgRestore(vg_)
        elseif pt == "magstor" then
            -- 电弧线段：快速竖向线，有发光感
            local len = p.len or 12
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, p.x, p.y)
            nvgLineTo(vg_, p.x + p.vx * 0.05, p.y + p.vy * 0.05)
            nvgStrokeColor(vg_, nvgRGBA(p.r, p.g, p.b, alpha))
            nvgStrokeWidth(vg_, p.size or 1.5)
            nvgStroke(vg_)
            -- 外层更宽的低透线（模拟发光）
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, p.x, p.y)
            nvgLineTo(vg_, p.x + p.vx * 0.05, p.y + p.vy * 0.05)
            nvgStrokeColor(vg_, nvgRGBA(p.r, p.g, p.b, math.floor(alpha * 0.25)))
            nvgStrokeWidth(vg_, (p.size or 1.5) * 3)
            nvgStroke(vg_)
        end
        ::continue::
    end
end

--- P1-2: 环境 HUD（左上角小徽标）
local function drawEnvHUD()
    if currentEnv_.key == "NONE" then return end
    local ex = 8
    local ey = 32   -- 在顶部标题栏下方
    local ew = 90
    local eh = 20

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, ex, ey, ew, eh, 5)
    -- 背景色随环境变化
    local bgA = 180
    if currentEnv_.key == "NEBULA" then
        nvgFillColor(vg_, nvgRGBA(20, 5, 50, bgA))
    elseif currentEnv_.key == "ASTEROID" then
        nvgFillColor(vg_, nvgRGBA(35, 20, 5, bgA))
    elseif currentEnv_.key == "MAGSTOR" then
        nvgFillColor(vg_, nvgRGBA(5, 30, 20, bgA))
    end
    nvgFill(vg_)
    -- 边框（环境颜色）
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, ex + 0.5, ey + 0.5, ew - 1, eh - 1, 5)
    nvgStrokeColor(vg_, nvgRGBA(currentEnv_.pR, currentEnv_.pG, currentEnv_.pB, 140))
    nvgStrokeWidth(vg_, 0.8)
    nvgStroke(vg_)

    -- 图标 + 文字
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 10)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(currentEnv_.pR, currentEnv_.pG, currentEnv_.pB, 220))
    nvgText(vg_, ex + 5, ey + eh / 2, currentEnv_.icon .. " " .. currentEnv_.label)
end

--- P1-2: 环境进入公告横幅（战斗开始时中央短暂显示）
local function drawEnvAnnounce()
    if envAnnounceAlpha_ <= 0 then return end
    if currentEnv_.key == "NONE" then return end
    local a = envAnnounceAlpha_
    local cx = screenW_ / 2
    local cy = screenH_ * 0.28

    -- 横幅背景
    local bw, bh = 280, 52
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgFillColor(vg_, nvgRGBA(0, 0, 0, math.floor(a * 0.75)))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - bw/2 + 0.5, cy - bh/2 + 0.5, bw - 1, bh - 1, 8)
    nvgStrokeColor(vg_, nvgRGBA(currentEnv_.pR, currentEnv_.pG, currentEnv_.pB, a))
    nvgStrokeWidth(vg_, 1.5)
    nvgStroke(vg_)

    -- 标题行：环境名称
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 16)
    nvgFillColor(vg_, nvgRGBA(currentEnv_.pR, currentEnv_.pG, currentEnv_.pB, a))
    nvgText(vg_, cx, cy - 10, currentEnv_.icon .. "  进入" .. currentEnv_.label .. "区域")

    -- 描述行
    nvgFontSize(vg_, 9.5)
    nvgFillColor(vg_, nvgRGBA(200, 200, 200, math.floor(a * 0.85)))
    nvgText(vg_, cx, cy + 12, currentEnv_.desc)
end

--- P3-1: 动态背景星星（视差三层 + 闪烁 + 近景十字光晕）
local function drawBgStars()
    -- 视差系数：layer 越大移动越快（近景视差更明显）
    local layerParallax = { 0.15, 0.35, 0.65 }
    -- Boss 波次时整体偏红色调
    local isBossWave = (waveNum_ % BOSS_WAVE_INTERVAL == 0) and state_ == "fighting"

    for _, s in ipairs(bgStars_) do
        local pf  = layerParallax[s.layer] or 0.3
        -- 视差后的屏幕坐标（循环滚动，星星飘出屏幕左/下侧后从右/上侧重现）
        local sx = (s.x - bgScrollX_ * pf) % (screenW_ + 40)
        local sy = (s.y - bgScrollY_ * pf) % (screenH_ + 40)
        -- 闪烁：alpha 在基础值 ±30% 之间正弦波动
        local twinkle = math.sin(s.twinklePhase)
        local a = math.max(20, math.min(255, math.floor(s.alpha + twinkle * s.alpha * 0.3)))

        -- 星星颜色：正常白蓝，Boss波带橙红调
        local sr, sg, sb
        if isBossWave then
            sr = math.min(255, 200 + math.floor(twinkle * 30))
            sg = math.max(80,  140 - math.floor(twinkle * 20))
            sb = math.max(60,  100 - math.floor(twinkle * 20))
        else
            sr = math.min(255, 200 + math.floor(twinkle * 40))
            sg = math.min(255, 210 + math.floor(twinkle * 30))
            sb = 255
        end

        -- 绘制星点
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, s.r)
        nvgFillColor(vg_, nvgRGBA(sr, sg, sb, a))
        nvgFill(vg_)

        -- layer 3 近景大星：十字光晕
        if s.layer == 3 then
            local glowLen = s.r * (3.5 + twinkle * 1.5)
            local ga      = math.floor(a * 0.5)
            nvgStrokeWidth(vg_, 0.8)
            nvgStrokeColor(vg_, nvgRGBA(sr, sg, sb, ga))
            -- 水平光芒
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, sx - glowLen, sy)
            nvgLineTo(vg_, sx + glowLen, sy)
            nvgStroke(vg_)
            -- 垂直光芒
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, sx, sy - glowLen)
            nvgLineTo(vg_, sx, sy + glowLen)
            nvgStroke(vg_)
        end
    end
end

local function drawGrid()
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    -- P1-2: 背景色随环境微调
    nvgFillColor(vg_, nvgRGBA(currentEnv_.bgR, currentEnv_.bgG, currentEnv_.bgB, 255))
    nvgFill(vg_)
    nvgStrokeColor(vg_, nvgRGBA(50,100,200, 20))
    nvgStrokeWidth(vg_, 1)
    local step = 60
    for x = 0, screenW_, step do
        nvgBeginPath(vg_); nvgMoveTo(vg_,x,0); nvgLineTo(vg_,x,screenH_); nvgStroke(vg_)
    end
    for y = 0, screenH_, step do
        nvgBeginPath(vg_); nvgMoveTo(vg_,0,y); nvgLineTo(vg_,screenW_,y); nvgStroke(vg_)
    end
end

local SHIP_LABEL = {
    SCOUT        = "侦察",
    FRIGATE      = "护卫",
    DESTROYER    = "驱逐",
    BATTLECRUISER= "战列",
    MINER        = "采矿",
    ENGINEER     = "工程",
    EXPLORER     = "探索",
}

local function drawShip(ship)
    -- Boss 金色光晕 aura（渲染在血条/图片之下）
    if ship.isBoss then
        local glowBase = 30
        for i = 3, 1, -1 do
            nvgBeginPath(vg_)
            nvgCircle(vg_, ship.x, ship.y, glowBase + i * 6)
            nvgFillColor(vg_, nvgRGBA(255, 200, 50, math.floor(25 / i)))
            nvgFill(vg_)
        end
        -- 外圈描边
        nvgBeginPath(vg_)
        nvgCircle(vg_, ship.x, ship.y, glowBase + 5)
        nvgStrokeColor(vg_, nvgRGBA(255, 200, 50, 120))
        nvgStrokeWidth(vg_, 1.5)
        nvgStroke(vg_)
    end

    -- Boss 护盾条（在血条上方 y-22）
    if ship.isBoss and ship.maxShield > 0 then
        local shieldFrac = math.max(0, ship.shield / ship.maxShield)
        -- 护盾底轨
        nvgBeginPath(vg_)
        nvgRect(vg_, ship.x-12, ship.y-22, 24, 4)
        nvgFillColor(vg_, nvgRGBA(30, 0, 60, 220))
        nvgFill(vg_)
        -- 护盾前景（紫色）
        if shieldFrac > 0 then
            nvgBeginPath(vg_)
            nvgRect(vg_, ship.x-12, ship.y-22, math.floor(24*shieldFrac), 4)
            nvgFillColor(vg_, nvgRGBA(160, 60, 255, 230))
            nvgFill(vg_)
        end
        -- 护盾条描边
        nvgBeginPath(vg_)
        nvgRect(vg_, ship.x-12, ship.y-22, 24, 4)
        nvgStrokeColor(vg_, nvgRGBA(200, 100, 255, 120))
        nvgStrokeWidth(vg_, 0.8)
        nvgStroke(vg_)
    end

    -- 血条背景
    nvgBeginPath(vg_)
    nvgRect(vg_, ship.x-12, ship.y-16, 24, 4)
    nvgFillColor(vg_, nvgRGBA(100,0,0, 200))
    nvgFill(vg_)
    -- 血条前景
    local hp = math.max(0, ship.health / ship.maxHealth)
    nvgBeginPath(vg_)
    nvgRect(vg_, ship.x-12, ship.y-16, math.floor(24*hp), 4)
    local hpR = math.floor(255*(1-hp))
    local hpG = math.floor(255*hp)
    nvgFillColor(vg_, nvgRGBA(hpR, hpG, 0, 220))
    nvgFill(vg_)

    -- 舰船图片渲染
    nvgSave(vg_)
    nvgTranslate(vg_, ship.x, ship.y)
    local angle = 0
    if math.abs(ship.vx) > 0.01 or math.abs(ship.vy) > 0.01 then
        angle = math.atan(ship.vy, ship.vx)
    elseif ship.team == "enemy" then
        angle = math.pi
    end
    nvgRotate(vg_, angle)

    local scale = 1.0
    if ship.stype == "SCOUT"         then scale = 0.85 end
    if ship.stype == "DESTROYER"     then scale = 1.4  end
    if ship.stype == "BATTLECRUISER" then scale = 1.8  end
    if ship.stype == "MINER"         then scale = 1.1  end
    if ship.stype == "ENGINEER"      then scale = 1.0  end
    if ship.stype == "EXPLORER"      then scale = 1.0  end
    if ship.stype == "CARRIER"       then scale = 2.5  end
    if ship.stype == "INTERCEPTOR"   then scale = 0.75 end

    local imgHandle = shipImages_[ship.stype]
    if imgHandle and imgHandle >= 0 then
        -- 用 nvgImagePattern 渲染纹理
        local half = 18 * scale
        -- 敌方舰船叠加红色调
        if ship.team == "enemy" then
            nvgGlobalAlpha(vg_, 0.85)
        end
        local paint = nvgImagePattern(vg_, -half, -half, half*2, half*2, 0, imgHandle, 1.0)
        nvgBeginPath(vg_)
        nvgRect(vg_, -half, -half, half*2, half*2)
        nvgFillPaint(vg_, paint)
        nvgFill(vg_)
        -- 敌方叠加半透明红色蒙版
        if ship.team == "enemy" then
            nvgBeginPath(vg_)
            nvgRect(vg_, -half, -half, half*2, half*2)
            nvgFillColor(vg_, nvgRGBA(200, 30, 30, 80))
            nvgFill(vg_)
            nvgGlobalAlpha(vg_, 1.0)
        end
    else
        -- 纹理未加载时回退到三角形
        local c = ship.color
        if ship.team == "enemy" then c = {255,60,60} end
        nvgBeginPath(vg_)
        nvgMoveTo(vg_,  12*scale,  0)
        nvgLineTo(vg_, -8*scale,  -8*scale)
        nvgLineTo(vg_, -5*scale,   0)
        nvgLineTo(vg_, -8*scale,   8*scale)
        nvgClosePath(vg_)
        nvgFillColor(vg_, nvgRGBA(c[1],c[2],c[3], 230))
        nvgFill(vg_)
    end

    -- 受击闪白叠加（transform 空间内，与舰船同步）
    if ship.hitFlash and ship.hitFlash > 0 then
        local flashAlpha = math.floor(ship.hitFlash * 200)
        local half = 18 * scale + 2
        nvgBeginPath(vg_)
        nvgRect(vg_, -half, -half, half*2, half*2)
        nvgFillColor(vg_, nvgRGBA(255, 255, 255, flashAlpha))
        nvgFill(vg_)
    end

    nvgRestore(vg_)

    -- 舰船类型标签（血条上方）
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    if ship.team == "player" then
        nvgFillColor(vg_, nvgRGBA(120, 200, 255, 180))
    else
        nvgFillColor(vg_, nvgRGBA(255, 120, 120, 180))
    end
    -- Boss 时类型标签上移一格，腾出空间给 BOSS 标题
    local labelOffY = ship.isBoss and -28 or -17
    nvgText(vg_, ship.x, ship.y + labelOffY, SHIP_LABEL[ship.stype] or ship.stype)

    -- Boss 专属标题标签
    if ship.isBoss then
        nvgFontSize(vg_, 11)
        nvgFillColor(vg_, nvgRGBA(255, 200, 50, 230))
        nvgText(vg_, ship.x, ship.y - 37, "★BOSS★")
    end
end

local function drawProjectile(p)
    if p.isBig then
        -- 战列舰主炮：粗线 + 圆形弹头
        local alpha = math.floor(p.life * 1200)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, p.x, p.y)
        nvgLineTo(vg_, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(vg_, nvgRGBA(200,120,255, alpha))
        else
            nvgStrokeColor(vg_, nvgRGBA(255,140,40, alpha))
        end
        nvgStrokeWidth(vg_, 5)
        nvgStroke(vg_)
        -- 弹头圆点
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.tx, p.ty, 5)
        if p.team == "player" then
            nvgFillColor(vg_, nvgRGBA(240,180,255, alpha))
        else
            nvgFillColor(vg_, nvgRGBA(255,200,80, alpha))
        end
        nvgFill(vg_)
    else
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, p.x, p.y)
        nvgLineTo(vg_, p.tx, p.ty)
        if p.team == "player" then
            nvgStrokeColor(vg_, nvgRGBA(100,200,255, math.floor(p.life*1200)))
        else
            nvgStrokeColor(vg_, nvgRGBA(255,80,80, math.floor(p.life*1200)))
        end
        nvgStrokeWidth(vg_, 2)
        nvgStroke(vg_)
    end
end

local function drawFloatTexts()
    if #floatTexts_ == 0 then return end
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for _, ft in ipairs(floatTexts_) do
        local lifeFrac = ft.life / ft.maxLife
        local alpha    = math.floor(lifeFrac * 255)

        if ft.team == "combo" then
            -- 连击飘字：金黄色，放大动画
            local scale = 1.0 + (1 - lifeFrac) * 0.5
            local fs = math.floor((13 + (comboCount_ >= 10 and 3 or 0)) * scale)
            nvgFontSize(vg_, fs)
            nvgText(vg_, ft.x + 1, ft.y + 1, ft.text)
            nvgFillColor(vg_, nvgRGBA(140, 70, 0, math.floor(alpha * 0.55)))
            nvgText(vg_, ft.x, ft.y, ft.text)
            nvgFillColor(vg_, nvgRGBA(255, 220, 40, alpha))
            nvgText(vg_, ft.x, ft.y, ft.text)
        elseif ft.team == "combo_reward" then
            -- P2-2: 连击 credits 奖励飘字：青绿大字，居中
            local scale = 1.0 + (1 - lifeFrac) * 0.3
            nvgFontSize(vg_, math.floor(16 * scale))
            -- 阴影
            nvgFillColor(vg_, nvgRGBA(0, 80, 60, math.floor(alpha * 0.5)))
            nvgText(vg_, ft.x + 1, ft.y + 1, ft.text)
            -- 主色：青绿
            nvgFillColor(vg_, nvgRGBA(60, 255, 200, alpha))
            nvgText(vg_, ft.x, ft.y, ft.text)
        else
            -- 伤害数字：根据数值分级渲染
            local numVal = tonumber(ft.text:match("%-?(%d+)")) or 0
            local isBig  = numVal >= 40
            local isMed  = numVal >= 20 and not isBig
            -- 字号：大伤害更大，并随生命周期轻微缩放
            local baseSize = isBig and 15 or (isMed and 13 or 11)
            local scaleAnim = 1.0 + (1 - lifeFrac) * (isBig and 0.4 or 0.15)
            nvgFontSize(vg_, math.floor(baseSize * scaleAnim))

            if ft.team == "enemy" then
                -- P3-2: 暴击：金色大字放大1.5倍
                if ft.isCrit then
                    nvgFontSize(vg_, math.floor(baseSize * scaleAnim * 1.5))
                    -- 深色描边
                    nvgFillColor(vg_, nvgRGBA(120, 80, 0, math.floor(alpha * 0.6)))
                    nvgText(vg_, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(vg_, nvgRGBA(255, 210, 0, alpha))
                -- P3-2: 连击期间颜色渐变（橙→黄→白循环）
                elseif comboCount_ >= 3 then
                    local t = (comboTimer_ / COMBO_RESET_TIME) * math.pi * 4
                    local gr = math.floor(200 + 55 * math.abs(math.sin(t)))
                    local gg = math.floor(150 + 105 * math.abs(math.cos(t * 0.7)))
                    nvgFillColor(vg_, nvgRGBA(gr, gg, 80, alpha))
                -- 命中敌舰：青绿色，大伤害加白色描边
                elseif isBig then
                    nvgFillColor(vg_, nvgRGBA(180, 255, 220, math.floor(alpha * 0.5)))
                    nvgText(vg_, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(vg_, nvgRGBA(0, 255, 140, alpha))
                elseif isMed then
                    nvgFillColor(vg_, nvgRGBA(80, 255, 140, alpha))
                else
                    nvgFillColor(vg_, nvgRGBA(100, 220, 120, alpha))
                end
            else
                -- 命中我舰：橙红色，大伤害加深色描边
                if isBig then
                    nvgFillColor(vg_, nvgRGBA(120, 40, 0, math.floor(alpha * 0.5)))
                    nvgText(vg_, ft.x + 1, ft.y + 1, ft.text)
                    nvgFillColor(vg_, nvgRGBA(255, 100, 40, alpha))
                elseif isMed then
                    nvgFillColor(vg_, nvgRGBA(255, 150, 60, alpha))
                else
                    nvgFillColor(vg_, nvgRGBA(220, 160, 80, alpha))
                end
            end
            nvgText(vg_, ft.x, ft.y, ft.text)
        end
    end
end

local function drawMoveTarget()
    if not moveTarget_ then return end
    nvgBeginPath(vg_)
    nvgCircle(vg_, moveTarget_.x, moveTarget_.y, 10)
    nvgStrokeColor(vg_, nvgRGBA(50,220,120,200))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)
    nvgBeginPath(vg_)
    nvgCircle(vg_, moveTarget_.x, moveTarget_.y, 5)
    nvgFillColor(vg_, nvgRGBA(50,220,120,150))
    nvgFill(vg_)
end

-- drawTitleBar 已移至 GameUI.RenderSceneTitle，此处删除避免重叠

--- 渲染燃烧粒子（低血量舰船火焰特效）
local function drawFireParticles()
    if #fireParticles_ == 0 then return end
    for _, p in ipairs(fireParticles_) do
        local alpha = math.floor(255 * (p.life / p.maxLife))
        local size  = p.size * (p.life / p.maxLife)  -- 随生命周期缩小
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.x, p.y, math.max(0.5, size))
        nvgFillColor(vg_, nvgRGBA(p.r, p.g, 0, alpha))
        nvgFill(vg_)
    end
end

--- 渲染爆炸粒子（舰船被摧毁时的闪光+碎片）
local function drawExplParticles()
    if #explParticles_ == 0 then return end
    for _, ep in ipairs(explParticles_) do
        local frac  = ep.life / ep.maxLife
        local alpha = math.floor(frac * 255)
        if ep.ptype == "flash" then
            -- 扩张白光圆，淡出
            local r = ep.size * (2 - frac)
            nvgBeginPath(vg_)
            nvgCircle(vg_, ep.x, ep.y, math.max(0.5, r))
            nvgFillColor(vg_, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(vg_)
        else
            -- 碎片：小点，收缩+淡出
            local sz = ep.size * frac
            nvgBeginPath(vg_)
            nvgCircle(vg_, ep.x, ep.y, math.max(0.5, sz))
            nvgFillColor(vg_, nvgRGBA(ep.r, ep.g, ep.b, alpha))
            nvgFill(vg_)
        end
    end
end

--- 渲染击中火花（细小射线状粒子）
local function drawHitSparks()
    if #hitSparks_ == 0 then return end
    for _, sp in ipairs(hitSparks_) do
        local frac  = sp.life / sp.maxLife
        local alpha = math.floor(frac * 220)
        local len   = math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy) * 0.04 + 1.5
        local nx = sp.vx == 0 and 0 or sp.vx / math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy)
        local ny = sp.vy == 0 and 0 or sp.vy / math.sqrt(sp.vx*sp.vx + sp.vy*sp.vy)
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, sp.x - nx * len, sp.y - ny * len)
        nvgLineTo(vg_, sp.x + nx * len, sp.y + ny * len)
        nvgStrokeColor(vg_, nvgRGBA(sp.r, sp.g, sp.b, alpha))
        nvgStrokeWidth(vg_, math.max(0.5, frac * 1.5))
        nvgStroke(vg_)
    end
end

--- 渲染冲击波环（扩张光圈）
local function drawShockRings()
    if #shockRings_ == 0 then return end
    for _, ring in ipairs(shockRings_) do
        if ring.radius > 0 then
            local frac  = ring.life / ring.maxLife  -- 1→0
            local alpha = math.floor(frac * 180)
            nvgBeginPath(vg_)
            nvgCircle(vg_, ring.x, ring.y, ring.radius)
            nvgStrokeColor(vg_, nvgRGBA(ring.r, ring.g, ring.b, alpha))
            nvgStrokeWidth(vg_, ring.width * frac)
            nvgStroke(vg_)
            -- 内层更亮的细环（增强层次感）
            if ring.radius > 6 then
                nvgBeginPath(vg_)
                nvgCircle(vg_, ring.x, ring.y, ring.radius * 0.6)
                nvgStrokeColor(vg_, nvgRGBA(
                    math.min(255, ring.r + 80),
                    math.min(255, ring.g + 40),
                    ring.b,
                    math.floor(frac * 100)))
                nvgStrokeWidth(vg_, ring.width * frac * 0.4)
                nvgStroke(vg_)
            end
        end
    end
end

--- 战斗中顶部波次信息 HUD
local function drawWaveHUD()
    if state_ ~= "fighting" then return end
    local cx = screenW_ / 2
    -- P1-1: 扩大 HUD 宽度，分上下两行（hh=48 容纳进度条+标签）
    local hw, hh = 140, 48
    -- 背景胶囊
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - hw, 4, hw * 2, hh, 8)
    nvgFillColor(vg_, nvgRGBA(8, 12, 30, 210))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - hw, 4, hw * 2, hh, 8)
    nvgStrokeColor(vg_, nvgRGBA(60, 120, 255, 140))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")

    -- 第一行：波次文字 + 兵力
    local row1Y = 4 + 13
    nvgFontSize(vg_, 11)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local isBossNow = (waveNum_ % BOSS_WAVE_INTERVAL == 0)
    if isBossNow then
        nvgFillColor(vg_, nvgRGBA(255, 120, 40, 240))
    else
        nvgFillColor(vg_, nvgRGBA(100, 180, 255, 220))
    end
    nvgText(vg_, cx - hw + 10, row1Y,
        isBossNow and string.format("第 %d 波 ⚡ BOSS", waveNum_)
                   or string.format("第 %d 波", waveNum_))

    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(80, 220, 120, 200))
    nvgText(vg_, cx + hw - 10, row1Y,
        string.format("我方 %d  敌方 %d", #playerFleet_, #enemyFleet_))

    -- 第二行：波次时间线进度条
    -- 以 BOSS_WAVE_INTERVAL 为一个阶段，显示当前阶段内进度
    local barY   = 4 + 26
    local barH   = 7
    local barX0  = cx - hw + 10
    local barX1  = cx + hw - 10
    local barW   = barX1 - barX0

    -- 阶段：每 BOSS_WAVE_INTERVAL 波一组
    local stageSize  = BOSS_WAVE_INTERVAL           -- 5
    local stageStart = math.floor((waveNum_ - 1) / stageSize) * stageSize + 1
    local stageEnd   = stageStart + stageSize - 1

    -- 轨道背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, barX0, barY, barW, barH, 3)
    nvgFillColor(vg_, nvgRGBA(20, 35, 70, 200))
    nvgFill(vg_)

    -- 已完成段（包含当前波）
    local pct = (waveNum_ - stageStart) / stageSize
    if pct > 0 then
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, barX0, barY, barW * pct, barH, 3)
        if isBossNow then
            nvgFillColor(vg_, nvgRGBA(255, 100, 20, 200))
        else
            nvgFillColor(vg_, nvgRGBA(60, 140, 255, 200))
        end
        nvgFill(vg_)
    end

    -- 节点圆点：stageSize 个节点（每波一个）
    local nodeR = 4.5
    for i = 1, stageSize do
        local wave_i  = stageStart + i - 1
        local nx      = barX0 + barW * (i - 0.5) / stageSize
        local ny      = barY + barH / 2
        local isBoss  = (wave_i % BOSS_WAVE_INTERVAL == 0)
        local isPast  = (wave_i < waveNum_)
        local isCur   = (wave_i == waveNum_)

        -- 节点底色
        nvgBeginPath(vg_)
        nvgCircle(vg_, nx, ny, isBoss and nodeR + 1 or nodeR)
        if isBoss then
            if isCur then
                nvgFillColor(vg_, nvgRGBA(255, 80, 20, 255))
            elseif isPast then
                nvgFillColor(vg_, nvgRGBA(180, 60, 20, 220))
            else
                nvgFillColor(vg_, nvgRGBA(80, 30, 10, 200))
            end
        else
            if isCur then
                nvgFillColor(vg_, nvgRGBA(80, 200, 255, 255))
            elseif isPast then
                nvgFillColor(vg_, nvgRGBA(40, 100, 180, 220))
            else
                nvgFillColor(vg_, nvgRGBA(25, 45, 90, 200))
            end
        end
        nvgFill(vg_)

        -- 当前波节点：外圈发光
        if isCur then
            nvgBeginPath(vg_)
            nvgCircle(vg_, nx, ny, (isBoss and nodeR + 3 or nodeR + 2))
            nvgStrokeWidth(vg_, 1.5)
            if isBoss then
                nvgStrokeColor(vg_, nvgRGBA(255, 120, 40, 180))
            else
                nvgStrokeColor(vg_, nvgRGBA(100, 200, 255, 180))
            end
            nvgStroke(vg_)
        end

        -- Boss 节点符号（骷髅/闪电）
        if isBoss then
            nvgFontSize(vg_, 7)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(255, 220, 100, 255))
            nvgText(vg_, nx, ny, "B")
        end
    end

    -- 阶段标签（左 W1 右 W5）
    nvgFontSize(vg_, 8)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(80, 120, 200, 160))
    nvgText(vg_, barX0, barY + barH + 6, string.format("W%d", stageStart))
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(200, 100, 60, 160))
    nvgText(vg_, barX1, barY + barH + 6, string.format("BOSS W%d", stageEnd))
end

--- 连击计数 HUD（右上角）
local function drawComboHUD()
    if state_ ~= "fighting" then return end
    if comboCount_ < 2 then return end
    local alpha = 255
    if comboDisplayTimer_ < 0.5 then
        alpha = math.floor(comboDisplayTimer_ / 0.5 * 255)
    end
    if alpha <= 0 then return end

    local lv    = getComboLevel()
    local color = lv and { 255, 220, 40 } or { 180, 220, 255 }
    local label = lv and lv.label or "COMBO"

    local bx = screenW_ - 120
    local by = 6
    local bw = 112
    local bh = 40

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, bw, bh, 6)
    nvgFillColor(vg_, nvgRGBA(10, 15, 35, math.floor(alpha * 0.8)))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, bw, bh, 6)
    nvgStrokeColor(vg_, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.7)))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    -- 大连击数字
    nvgFontSize(vg_, 20)
    nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], alpha))
    nvgText(vg_, bx + bw * 0.38, by + bh * 0.5, string.format("x%d", comboCount_))
    -- 标签文字
    nvgFontSize(vg_, 8)
    nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.85)))
    nvgText(vg_, bx + bw * 0.75, by + bh * 0.38, label)
    -- 倍率提示（P2-2: 显示预计 credits 奖励）
    if lv and comboCount_ >= 3 then
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, nvgRGBA(120, 255, 160, math.floor(alpha * 0.9)))
        nvgText(vg_, bx + bw * 0.75, by + bh * 0.68,
            string.format("+%d星币", comboCount_ * 20))
    end
    -- 衰减条（剩余连击时间）
    if comboCount_ > 0 then
        local pct = 1.0 - math.min(1, comboTimer_ / COMBO_RESET_TIME)
        nvgBeginPath(vg_)
        nvgRect(vg_, bx + 4, by + bh - 4, (bw - 8) * pct, 2)
        nvgFillColor(vg_, nvgRGBA(color[1], color[2], color[3], math.floor(alpha * 0.7)))
        nvgFill(vg_)
    end
end

--- P2-2: 绘制单舰信息面板（选中舰船时显示在其旁边）
local function drawShipInfoPanel()
    local ship = selectedShip_
    if not ship then return end
    -- 检查舰船仍在舰队中（可能已阵亡）
    local alive = false
    for _, s in ipairs(playerFleet_) do if s == ship then alive = true; break end end
    if not alive then
        for _, s in ipairs(enemyFleet_) do if s == ship then alive = true; break end end
    end
    if not alive then selectedShip_ = nil; return end

    local isPlayer = (ship.team == "player")
    -- 面板内容
    local cfg = SHIP_TYPES[ship.stype] or {}
    local typeName = cfg.name or ship.stype
    local panW, panH = 148, 120
    -- 定位：舰船右侧（或左侧若超边界）
    local px = ship.x + 18
    local py = ship.y - panH / 2
    if px + panW > screenW_ - 8 then px = ship.x - panW - 18 end
    if py < 92 then py = 92 end
    if py + panH > screenH_ - 6 then py = screenH_ - panH - 6 end

    -- 面板背景
    local bgR = isPlayer and 5  or 30
    local bgG = isPlayer and 20 or 5
    local bgB = isPlayer and 50 or 5
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, panW, panH, 6)
    nvgFillColor(vg_, nvgRGBA(bgR, bgG, bgB, 215))
    nvgFill(vg_)
    -- 边框
    local borderR = isPlayer and 60  or 200
    local borderG = isPlayer and 160 or 60
    local borderB = isPlayer and 255 or 60
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px + 0.5, py + 0.5, panW - 1, panH - 1, 6)
    nvgStrokeColor(vg_, nvgRGBA(borderR, borderG, borderB, 160))
    nvgStrokeWidth(vg_, 1); nvgStroke(vg_)

    -- 标题行
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 12)
    nvgFillColor(vg_, nvgRGBA(borderR, borderG, borderB, 230))
    local teamLabel = isPlayer and "我方" or "敌方"
    nvgText(vg_, px + 8, py + 11, teamLabel .. " · " .. typeName)
    if ship.isBoss then
        nvgFillColor(vg_, nvgRGBA(255, 80, 80, 220))
        nvgText(vg_, px + panW - 30, py + 11, "BOSS")
    end
    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 6, py + 19); nvgLineTo(vg_, px + panW - 6, py + 19)
    nvgStrokeColor(vg_, nvgRGBA(borderR, borderG, borderB, 60))
    nvgStrokeWidth(vg_, 0.5); nvgStroke(vg_)

    -- HP 条
    local barX, barY = px + 8, py + 27
    local barW2, barH2 = panW - 16, 8
    local hpRatio = math.max(0, ship.health / ship.maxHealth)
    -- HP背景
    nvgBeginPath(vg_); nvgRoundedRect(vg_, barX, barY, barW2, barH2, 3)
    nvgFillColor(vg_, nvgRGBA(40, 40, 40, 160)); nvgFill(vg_)
    -- HP填充（颜色随血量变：绿→黄→红）
    local hpR = math.floor(math.min(255, (1 - hpRatio) * 510))
    local hpG = math.floor(math.min(255, hpRatio * 510))
    nvgBeginPath(vg_); nvgRoundedRect(vg_, barX, barY, barW2 * hpRatio, barH2, 3)
    nvgFillColor(vg_, nvgRGBA(hpR, hpG, 30, 200)); nvgFill(vg_)
    -- HP 数字
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(220, 220, 220, 200))
    nvgText(vg_, px + panW - 8, barY + barH2/2,
        string.format("HP %d/%d", math.floor(ship.health), ship.maxHealth))

    -- 护盾条（若有）
    local rowY = barY + barH2 + 5
    if ship.maxShield and ship.maxShield > 0 then
        local shRatio = math.max(0, (ship.shield or 0) / ship.maxShield)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, barX, rowY, barW2, barH2, 3)
        nvgFillColor(vg_, nvgRGBA(40, 40, 40, 160)); nvgFill(vg_)
        nvgBeginPath(vg_); nvgRoundedRect(vg_, barX, rowY, barW2 * shRatio, barH2, 3)
        nvgFillColor(vg_, nvgRGBA(80, 160, 255, 200)); nvgFill(vg_)
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFontSize(vg_, 9)
        nvgFillColor(vg_, nvgRGBA(160, 200, 255, 200))
        nvgText(vg_, px + panW - 8, rowY + barH2/2,
            string.format("护盾 %d/%d", math.floor(ship.shield or 0), ship.maxShield))
        rowY = rowY + barH2 + 5
    end

    -- 数值行（攻击 / 速度 / 射程）
    local statY = rowY + 4
    local function statLine(label, val, unit)
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(160, 160, 160, 180))
        nvgText(vg_, px + 8, statY, label)
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(230, 230, 230, 220))
        nvgText(vg_, px + panW - 8, statY, string.format("%.0f %s", val, unit))
        statY = statY + 14
    end
    statLine("攻击", ship.dmg,   "dmg")
    statLine("速度", ship.speed, "px/s")
    statLine("射程", ship.range, "px")

    -- 选中高亮（在舰船周围画一个选择圈）
    local hlR = (ship.isBoss and 12 or 10)
    nvgBeginPath(vg_)
    nvgCircle(vg_, ship.x, ship.y, hlR)
    nvgStrokeColor(vg_, nvgRGBA(borderR, borderG, borderB, 180))
    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
    -- 连接线（舰船中心 → 面板）
    local lineEndX = (ship.x + 18 >= screenW_ - 8 - panW) and (px + panW) or px
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, ship.x, ship.y)
    nvgLineTo(vg_, lineEndX, py + panH/2)
    nvgStrokeColor(vg_, nvgRGBA(borderR, borderG, borderB, 60))
    nvgStrokeWidth(vg_, 0.8); nvgStroke(vg_)
end

--- P2-2: 绘制集火目标橙色脉冲光环
local function drawFocusRing()
    if not focusTarget_ or focusTarget_.health <= 0 then return end
    local t     = (os.clock() % 1.2) / 1.2          -- 0→1 周期 1.2s
    local pulse = 0.75 + 0.5 * math.abs(math.sin(t * math.pi))
    local r     = 22 * pulse

    -- 外环（橙色脉冲）
    nvgBeginPath(vg_)
    nvgCircle(vg_, focusTarget_.x, focusTarget_.y, r)
    nvgStrokeColor(vg_, nvgRGBA(255, 140, 0, 200))
    nvgStrokeWidth(vg_, 2.5)
    nvgStroke(vg_)

    -- 内环（固定小圆，强调目标核心）
    nvgBeginPath(vg_)
    nvgCircle(vg_, focusTarget_.x, focusTarget_.y, 14)
    nvgStrokeColor(vg_, nvgRGBA(255, 200, 60, 130))
    nvgStrokeWidth(vg_, 1.2)
    nvgStroke(vg_)

    -- 十字准线（四段短横线）
    local cross = 9
    nvgStrokeColor(vg_, nvgRGBA(255, 160, 40, 180))
    nvgStrokeWidth(vg_, 1.5)
    for _, dir in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, focusTarget_.x + dir[1] * (r + 3), focusTarget_.y + dir[2] * (r + 3))
        nvgLineTo(vg_, focusTarget_.x + dir[1] * (r + 3 + cross), focusTarget_.y + dir[2] * (r + 3 + cross))
        nvgStroke(vg_)
    end

    -- "集火" 小标签
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 180, 60, 210))
    nvgText(vg_, focusTarget_.x, focusTarget_.y - r - 7, "◎ 集火")
end

--- P2-2: 绘制顶部集火状态条（含取消按钮）
local focusHudBtn_ = nil  -- 取消按钮区域，供 OnClick 检测

local function drawFocusHUD()
    focusHudBtn_ = nil
    if not focusTarget_ or focusTarget_.health <= 0 then return end

    local cfg       = SHIP_TYPES[focusTarget_.stype] or {}
    local typeName  = cfg.name or focusTarget_.stype
    local hpPct     = math.max(0, focusTarget_.health / (focusTarget_.maxHealth or focusTarget_.health))

    -- 状态条尺寸与位置（紧贴顶边，居中）
    local barW, barH = 220, 26
    local bx = screenW_ / 2 - barW / 2
    local by = 58  -- waveHUD 下方

    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx, by, barW, barH, 5)
    nvgFillColor(vg_, nvgRGBA(40, 18, 5, 210))
    nvgFill(vg_)

    -- 橙色边框
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, bx + 0.5, by + 0.5, barW - 1, barH - 1, 5)
    nvgStrokeColor(vg_, nvgRGBA(255, 140, 0, 200))
    nvgStrokeWidth(vg_, 1.2); nvgStroke(vg_)

    -- 图标 + 文字
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 10)
    nvgFillColor(vg_, nvgRGBA(255, 160, 50, 230))
    nvgText(vg_, bx + 7, by + barH / 2, "◎ 集火: 敌方" .. typeName)

    -- HP 进度条（小型）
    local hpBarX = bx + 105
    local hpBarW = 68
    local hpBarH = 4
    local hpBarY = by + barH / 2 - hpBarH / 2
    nvgBeginPath(vg_)
    nvgRect(vg_, hpBarX, hpBarY, hpBarW, hpBarH)
    nvgFillColor(vg_, nvgRGBA(60, 20, 10, 180))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRect(vg_, hpBarX, hpBarY, hpBarW * hpPct, hpBarH)
    local hpR = math.floor(200 * (1 - hpPct) + 60  * hpPct)
    local hpG = math.floor(60  * (1 - hpPct) + 180 * hpPct)
    nvgFillColor(vg_, nvgRGBA(hpR, hpG, 40, 220))
    nvgFill(vg_)

    -- HP 数字
    nvgFontSize(vg_, 8)
    nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(200, 200, 200, 180))
    nvgText(vg_, hpBarX + hpBarW + 3, by + barH / 2,
        string.format("%d/%d", math.max(0, math.floor(focusTarget_.health)),
                                math.floor(focusTarget_.maxHealth or focusTarget_.health)))

    -- [✕] 取消按钮
    local btnW, btnH = 22, 16
    local btnX = bx + barW - btnW - 4
    local btnY = by + barH / 2 - btnH / 2
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, btnX, btnY, btnW, btnH, 3)
    nvgFillColor(vg_, nvgRGBA(180, 50, 30, 200))
    nvgFill(vg_)
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(255, 220, 200, 230))
    nvgText(vg_, btnX + btnW / 2, btnY + btnH / 2, "✕")
    focusHudBtn_ = { x = btnX, y = btnY, w = btnW, h = btnH }
end

--- P1-1: 绘制阵型选择栏（技能栏左侧，竖排 3 个小按钮）
local FORMATION_ORDER = {"assault", "defense", "encircle"}
local function drawFormationBar()
    if state_ ~= "fighting" then
        formationBtn_ = {}
        return
    end

    -- 对齐技能栏左端：在技能栏开始 X 的左侧
    local skillBtnW  = 74
    local skillGapX  = 6
    local skillCols  = 3
    local skillTotalW = skillBtnW * skillCols + skillGapX * (skillCols - 1)
    local skillStartX = screenW_ / 2 - skillTotalW / 2

    -- 阵型按钮尺寸：宽60 高25，gap4，竖排3行，右对齐到技能栏左端-8px
    local btnW, btnH = 60, 25
    local gap        = 4
    local totalH     = btnH * 3 + gap * 2
    local bx         = skillStartX - btnW - 10
    local row2Y      = screenH_ - 74 - 6 - 5   -- 与 skill row2Y 对齐
    local topY       = row2Y + (74 - totalH) / 2  -- 垂直居中对齐双行技能栏

    -- 小标题
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(160, 180, 220, 130))
    nvgText(vg_, bx + btnW/2, topY - 8, "阵型")

    formationBtn_ = {}
    for i, key in ipairs(FORMATION_ORDER) do
        local fc   = FORMATION_CONFIG[key]
        local by   = topY + (i - 1) * (btnH + gap)
        local active = (currentFormation_ == key)

        -- 背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, btnW, btnH, 5)
        if active then
            nvgFillColor(vg_, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 210))
        else
            nvgFillColor(vg_, nvgRGBA(18, 24, 45, 170))
        end
        nvgFill(vg_)

        -- 边框
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx + 0.5, by + 0.5, btnW - 1, btnH - 1, 5)
        if active then
            nvgStrokeColor(vg_, nvgRGBA(255, 255, 255, 200))
        else
            nvgStrokeColor(vg_, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 120))
        end
        nvgStrokeWidth(vg_, 1.2)
        nvgStroke(vg_)

        -- 图标 + 标签
        nvgFontSize(vg_, 11)
        if active then
            nvgFillColor(vg_, nvgRGBA(255, 255, 255, 255))
        else
            nvgFillColor(vg_, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 200))
        end
        nvgText(vg_, bx + btnW/2, by + btnH/2, fc.icon .. " " .. fc.label)

        -- 记录点击区域
        formationBtn_[i] = { x=bx, y=by, w=btnW, h=btnH, key=key }
    end

    -- 当前阵型效果提示（显示在按钮右侧小标签）
    local fc = FORMATION_CONFIG[currentFormation_]
    if fc then
        nvgFontSize(vg_, 8)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(fc.color[1], fc.color[2], fc.color[3], 160))
        -- 简短效果文字显示在标题位置下方（紧凑）
    end
end

--- P1-2: 撤退 / 紧急增援按钮（右下角）
local function drawRetreatReinforce()
    if state_ ~= "fighting" then
        retreatBtn_   = nil
        reinforceBtn_ = nil
        return
    end

    local btnW, btnH = 72, 24
    local marginR = 10
    local marginB = 10

    -- 增援按钮（仅在波次间隙且有敌空时显示）
    local canReinforce = (#enemyFleet_ == 0 and waveGapTimer_ < WAVE_GAP
                         and reinforceCooldown_ <= 0)
    local metal   = rm_ and (rm_.resources.metal   or 0) or 0
    local crystal = rm_ and (rm_.resources.crystal or 0) or 0
    local hasResMeta = (metal >= REINFORCE_COST_METAL and crystal >= REINFORCE_COST_CRYSTAL)

    -- 确定按钮布局（增援在撤退上方）
    local retreatX = screenW_ - btnW - marginR
    local retreatY = screenH_ - btnH - marginB
    local reinforceY = retreatY - btnH - 6

    -- ── 撤退按钮 ──
    if not retreatUsed_ then
        local energy = rm_ and (rm_.resources.energy or 0) or 0
        local canRetreat = (energy >= RETREAT_COST_ENERGY)
        -- 背景
        local bgR, bgG, bgB = canRetreat and 160 or 60, 30, canRetreat and 30 or 30
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, retreatX, retreatY, btnW, btnH, 5)
        nvgFillColor(vg_, nvgRGBA(bgR, bgG, bgB, 200))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, retreatX, retreatY, btnW, btnH, 5)
        nvgStrokeColor(vg_, canRetreat and nvgRGBA(255, 80, 60, 200) or nvgRGBA(100, 60, 60, 160))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
        -- 文字
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, canRetreat and nvgRGBA(255, 180, 160, 240) or nvgRGBA(150, 100, 100, 180))
        nvgText(vg_, retreatX + btnW/2, retreatY + btnH/2 - 5, "⚑ 战略撤退")
        nvgFontSize(vg_, 8)
        nvgFillColor(vg_, nvgRGBA(200, 160, 140, 180))
        nvgText(vg_, retreatX + btnW/2, retreatY + btnH/2 + 6,
            string.format("能源 -%d", RETREAT_COST_ENERGY))
        retreatBtn_ = { x=retreatX, y=retreatY, w=btnW, h=btnH }
    else
        -- 已撤退：灰显"已使用"
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, retreatX, retreatY, btnW, btnH, 5)
        nvgFillColor(vg_, nvgRGBA(40, 40, 40, 150))
        nvgFill(vg_)
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 9)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(120, 100, 100, 160))
        nvgText(vg_, retreatX + btnW/2, retreatY + btnH/2, "撤退（已用）")
        retreatBtn_ = nil
    end

    -- ── 紧急增援按钮 ──
    if canReinforce then
        local bgG2 = hasResMeta and 120 or 40
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, retreatX, reinforceY, btnW, btnH, 5)
        nvgFillColor(vg_, nvgRGBA(20, bgG2, 40, 200))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, retreatX, reinforceY, btnW, btnH, 5)
        nvgStrokeColor(vg_, hasResMeta and nvgRGBA(60, 220, 100, 200) or nvgRGBA(60, 100, 60, 160))
        nvgStrokeWidth(vg_, 1)
        nvgStroke(vg_)
        nvgFontFace(vg_, "sans")
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, hasResMeta and nvgRGBA(120, 255, 160, 240) or nvgRGBA(100, 160, 100, 180))
        nvgText(vg_, retreatX + btnW/2, reinforceY + btnH/2 - 5, "⊕ 紧急增援")
        nvgFontSize(vg_, 8)
        nvgFillColor(vg_, nvgRGBA(160, 200, 160, 180))
        nvgText(vg_, retreatX + btnW/2, reinforceY + btnH/2 + 6,
            string.format("金属%d 晶体%d", REINFORCE_COST_METAL, REINFORCE_COST_CRYSTAL))
        reinforceBtn_ = { x=retreatX, y=reinforceY, w=btnW, h=btnH, canDo=hasResMeta }
    else
        reinforceBtn_ = nil
    end
end

-- ============================================================================
-- P2-2: 技能升级选择弹窗（波次间隙覆盖层）
-- ============================================================================
local function drawSkillUpgrade()
    if not skillUpgradeCards_ or #skillUpgradeCards_ == 0 then return end
    if state_ ~= "win" then return end  -- 仅在波次间隙期间显示

    local vg = vg_
    -- 半透明背景遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW_, screenH_)
    nvgFillColor(vg, nvgRGBA(0, 0, 10, 170))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(255, 220, 80, 240))
    nvgText(vg, screenW_ / 2, screenH_ / 2 - 80, "⬆ 技能强化 — 选择一项升级")

    local cardW, cardH = 130, 90
    local cardGap = 20
    local n = #skillUpgradeCards_
    local totalW = n * cardW + (n - 1) * cardGap
    local startX = screenW_ / 2 - totalW / 2
    local cardY  = screenH_ / 2 - cardH / 2 - 10

    skillUpgradeCardBtns_ = {}
    for i, skillIdx in ipairs(skillUpgradeCards_) do
        local cx = startX + (i - 1) * (cardW + cardGap)
        local lv = BattleSkills.GetLevel(skillIdx)
        local nextLv = lv + 1
        local icon = BattleSkills.GetIcon(skillIdx)
        local name = BattleSkills.GetName(skillIdx)

        -- 卡片背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cardY, cardW, cardH, 10)
        nvgFillColor(vg, nvgRGBA(18, 28, 60, 220))
        nvgFill(vg)
        -- 卡片边框（金色高亮）
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx + 0.5, cardY + 0.5, cardW - 1, cardH - 1, 10)
        nvgStrokeColor(vg, nvgRGBA(255, 190, 40, 200))
        nvgStrokeWidth(vg, 1.5)
        nvgStroke(vg)

        -- 技能图标 + 名称
        nvgFontSize(vg, 20)
        nvgFillColor(vg, nvgRGBA(240, 240, 255, 255))
        nvgText(vg, cx + cardW / 2, cardY + 22, icon)
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(200, 225, 255, 230))
        nvgText(vg, cx + cardW / 2, cardY + 42, name)

        -- 等级箭头
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(120, 180, 120, 200))
        nvgText(vg, cx + cardW / 2, cardY + 58, "Lv" .. lv .. " → Lv" .. nextLv)

        -- 升级效果描述
        nvgFontSize(vg, 9)
        if nextLv == 2 then
            nvgFillColor(vg, nvgRGBA(160, 220, 160, 190))
            nvgText(vg, cx + cardW / 2, cardY + 72, "效果 +50%")
        else
            nvgFillColor(vg, nvgRGBA(255, 200, 80, 200))
            nvgText(vg, cx + cardW / 2, cardY + 68, "效果 +100%")
            nvgFillColor(vg, nvgRGBA(160, 200, 255, 180))
            nvgText(vg, cx + cardW / 2, cardY + 80, "冷却 -20%")
        end

        -- "点击选择" 提示
        nvgFontSize(vg, 9)
        nvgFillColor(vg, nvgRGBA(255, 230, 100, 160))
        nvgText(vg, cx + cardW / 2, cardY + cardH - 6, "点击选择")

        skillUpgradeCardBtns_[#skillUpgradeCardBtns_ + 1] = {
            x = cx, y = cardY, w = cardW, h = cardH, skillIdx = skillIdx
        }
    end
end

--- P3-2: Boss击破全屏闪光 + BOSS DESTROYED 横幅
local function drawBossDestroyedEffect()
    -- 全屏白光（快速衰减）
    if bossFlashAlpha_ > 0 then
        nvgBeginPath(vg_)
        nvgRect(vg_, 0, 0, screenW_, screenH_)
        nvgFillColor(vg_, nvgRGBA(255, 240, 180, math.floor(bossFlashAlpha_)))
        nvgFill(vg_)
    end
    -- 横幅（显示 BOSS_BANNER_DUR 秒）
    if bossFlashTimer_ <= 0 then return end
    local elapsed = BOSS_BANNER_DUR - bossFlashTimer_
    local alpha
    if elapsed < 0.25 then
        alpha = elapsed / 0.25
    elseif bossFlashTimer_ < 0.5 then
        alpha = bossFlashTimer_ / 0.5
    else
        alpha = 1.0
    end
    local ia = math.floor(alpha * 255)
    local cx = screenW_ * 0.5
    local cy = screenH_ * 0.28
    local bw, bh = 260, 44
    -- 背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgFillColor(vg_, nvgRGBA(20, 10, 0, math.floor(ia * 0.82)))
    nvgFill(vg_)
    -- 金色边框（脉冲）
    local pulse = 0.6 + 0.4 * math.abs(math.sin(bossFlashTimer_ * 5))
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, cx - bw/2, cy - bh/2, bw, bh, 8)
    nvgStrokeColor(vg_, nvgRGBA(255, 200, 0, math.floor(ia * pulse)))
    nvgStrokeWidth(vg_, 2)
    nvgStroke(vg_)
    -- 主文字
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 22)
    nvgFillColor(vg_, nvgRGBA(60, 30, 0, math.floor(ia * 0.5)))
    nvgText(vg_, cx + 1, cy + 1, "★  BOSS DESTROYED  ★")
    nvgFillColor(vg_, nvgRGBA(255, 220, 40, ia))
    nvgText(vg_, cx, cy, "★  BOSS DESTROYED  ★")
end

--- 渲染烟花粒子（波次胜利特效，在 StateOverlay 之前渲染）
local function drawFireworks()
    if #fwParticles_ == 0 then return end
    for _, p in ipairs(fwParticles_) do
        local frac  = p.life / p.maxLife
        local alpha = math.floor(frac * 220)
        local sz    = math.max(0.8, 3.5 * frac)
        nvgBeginPath(vg_)
        nvgCircle(vg_, p.x, p.y, sz)
        nvgFillColor(vg_, nvgRGBA(p.r, p.g, p.b, alpha))
        nvgFill(vg_)
    end
end

--- Boss波次警告横幅（bossWarningTimer_ > 0 时显示）
local function drawBossWarning()
    if bossWarningTimer_ <= 0 or state_ ~= "fighting" then return end

    -- 渐入渐出 alpha（前 0.3s 淡入，最后 0.5s 淡出）
    local alpha
    local elapsed = BOSS_WARNING_DUR - bossWarningTimer_
    if elapsed < 0.3 then
        alpha = elapsed / 0.3
    elseif bossWarningTimer_ < 0.5 then
        alpha = bossWarningTimer_ / 0.5
    else
        alpha = 1.0
    end

    -- 全屏红色蒙版
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(180, 10, 10, math.floor(alpha * 55)))
    nvgFill(vg_)

    -- 中央警告横幅
    local bannerH = 74
    local by = screenH_ / 2 - bannerH / 2
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, by, screenW_, bannerH)
    nvgFillColor(vg_, nvgRGBA(60, 0, 0, math.floor(alpha * 220)))
    nvgFill(vg_)

    -- 上下红色边框线
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, by, screenW_, 2)
    nvgFillColor(vg_, nvgRGBA(255, 50, 50, math.floor(alpha * 255)))
    nvgFill(vg_)
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, by + bannerH - 2, screenW_, 2)
    nvgFillColor(vg_, nvgRGBA(255, 50, 50, math.floor(alpha * 255)))
    nvgFill(vg_)

    -- 主标题
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 28)
    nvgFillColor(vg_, nvgRGBA(255, 200, 50, math.floor(alpha * 255)))
    nvgText(vg_, screenW_/2, by + bannerH/2 - 12, "⚠  旗舰 BOSS 来袭  ⚠")

    -- 副标题
    nvgFontSize(vg_, 13)
    nvgFillColor(vg_, nvgRGBA(255, 130, 130, math.floor(alpha * 220)))
    nvgText(vg_, screenW_/2, by + bannerH/2 + 14,
        string.format("第 %d 波 · 强化旗舰 · 护盾 + 血量 + 伤害全面增强", waveNum_))
end

-- P1-1: 波次战斗摘要弹窗（显示在 win 阶段右侧）
local function drawWaveSummary()
    if not waveSummary_ then return end
    if state_ ~= "win" then return end

    local s   = waveSummary_
    local t   = stateTimer_                         -- 当前 win 状态已过秒数
    local fadeIn  = math.min(1, t / 0.4)           -- 0.4 秒淡入
    local fadeOut = math.max(0, 1 - math.max(0, t - (WAVE_GAP - 0.5)) / 0.4)  -- 最后0.5s淡出
    local ease    = fadeIn * fadeOut
    if ease <= 0 then return end

    local a = math.floor(ease * 255)
    local panW = 190
    -- P3-2: 如果有 MVP 数据，面板多出一行（+24px）
    local hasMvp = (s.mvp ~= nil and s.mvp.dmg > 0)
    local panH = hasMvp and 176 or 152
    local margin = 18
    -- 显示在屏幕右侧中部
    local px = screenW_ - panW - margin
    local py = screenH_ / 2 - panH / 2

    -- 面板背景
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px, py, panW, panH, 10)
    nvgFillColor(vg_, nvgRGBA(4, 12, 28, math.floor(a * 0.88)))
    nvgFill(vg_)
    -- 边框（按星级着色）
    local bc = ({
        [1] = {180, 100, 60},
        [2] = {60, 160, 255},
        [3] = {255, 210, 40},
    })[s.stars] or {80, 120, 200}
    nvgBeginPath(vg_)
    nvgRoundedRect(vg_, px + 0.5, py + 0.5, panW - 1, panH - 1, 10)
    nvgStrokeColor(vg_, nvgRGBA(bc[1], bc[2], bc[3], math.floor(a * 0.7)))
    nvgStrokeWidth(vg_, 1.5)
    nvgStroke(vg_)

    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 标题
    nvgFontSize(vg_, 11)
    nvgFillColor(vg_, nvgRGBA(bc[1], bc[2], bc[3], a))
    nvgText(vg_, px + panW/2, py + 14, string.format("— 第 %d 波 战报 —", s.wave))

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 12, py + 24)
    nvgLineTo(vg_, px + panW - 12, py + 24)
    nvgStrokeColor(vg_, nvgRGBA(bc[1], bc[2], bc[3], math.floor(a * 0.4)))
    nvgStrokeWidth(vg_, 0.5)
    nvgStroke(vg_)

    -- 数据行
    local rows = {
        { icon = "🎯", label = "击落敌舰",  val = string.format("%d 艘",  s.kills)    },
        { icon = "⚔️",  label = "最高连击",  val = s.maxCombo > 0 and string.format("x%d", s.maxCombo) or "—" },
        { icon = "💥", label = "造成伤害",  val = s.dmg >= 1000 and string.format("%.1fK", s.dmg/1000) or tostring(s.dmg) },
        { icon = "🚀", label = "损失舰船",  val = s.lost == 0 and "无损！" or string.format("%d 艘", s.lost) },
    }

    local rowH   = 22
    local startY = py + 34
    for i, row in ipairs(rows) do
        local ry = startY + (i - 1) * rowH
        -- 左侧 label
        nvgFontSize(vg_, 10)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(130, 160, 200, a))
        nvgText(vg_, px + 14, ry + rowH/2, row.icon .. " " .. row.label)
        -- 右侧 val（无损显示绿色，伤亡显示橙色）
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        local vc = (row.label == "损失舰船" and s.lost == 0) and {80, 255, 120}
                or (row.label == "损失舰船" and s.lost > 0)  and {255, 160, 60}
                or {220, 230, 255}
        nvgFillColor(vg_, nvgRGBA(vc[1], vc[2], vc[3], a))
        nvgText(vg_, px + panW - 14, ry + rowH/2, row.val)
    end

    -- P3-2: MVP 行（伤害最高的玩家舰）
    local afterRowsY = startY + #rows * rowH + 2
    if hasMvp then
        -- MVP 分隔线
        nvgBeginPath(vg_)
        nvgMoveTo(vg_, px + 12, afterRowsY)
        nvgLineTo(vg_, px + panW - 12, afterRowsY)
        nvgStrokeColor(vg_, nvgRGBA(200, 160, 40, math.floor(a * 0.35)))
        nvgStrokeWidth(vg_, 0.5)
        nvgStroke(vg_)

        local mvpY  = afterRowsY + 11
        local m     = s.mvp
        -- 舰种名
        local SHIP_NAMES = {
            FIGHTER="战斗机", DESTROYER="驱逐舰", BATTLECRUISER="战列舰",
            CARRIER="航母", INTERCEPTOR="拦截机",
        }
        local stypeName = SHIP_NAMES[m.stype] or m.stype
        local dmgStr    = m.dmg >= 1000
            and string.format("%.1fK", m.dmg / 1000)
            or  tostring(m.dmg)
        -- 皇冠 + MVP 标签
        nvgFontSize(vg_, 9.5)
        nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255, 210, 50, a))
        nvgText(vg_, px + 14, mvpY, "👑 MVP  " .. stypeName)
        -- 右侧：伤害 / 击杀
        nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255, 230, 120, a))
        nvgText(vg_, px + panW - 14, mvpY,
            string.format("%s  ×%d", dmgStr, m.kills))
    end

    -- 底部奖励摘要
    local sepY = afterRowsY + (hasMvp and 24 or 0) + 2
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, px + 12, sepY)
    nvgLineTo(vg_, px + panW - 12, sepY)
    nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, math.floor(a * 0.4)))
    nvgStrokeWidth(vg_, 0.5)
    nvgStroke(vg_)

    nvgFontSize(vg_, 9)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg_, nvgRGBA(100, 200, 120, math.floor(a * 0.85)))
    nvgText(vg_, px + panW/2, sepY + 11,
        string.format("奖励  金属+%d  能源+%d  核能+%d", s.mReward, s.eReward, s.cReward))
end

local function drawStateOverlay()
    if state_ == "fighting" then return end

    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, screenW_, screenH_)
    nvgFillColor(vg_, nvgRGBA(0,0,0,140))
    nvgFill(vg_)

    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, 48)
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if state_ == "win" then
        nvgFillColor(vg_, nvgRGBA(50,255,100,255))
        nvgText(vg_, screenW_/2, screenH_/2 - 20, "胜 利")

        -- P3-3: 星级评分（3颗星依次亮起）
        if currentWaveStar_ > 0 then
            local starCount  = 3
            local starR      = 18              -- 星星外接圆半径
            local starGap    = 52              -- 星星间距
            local totalW     = (starCount - 1) * starGap
            local cx         = screenW_ / 2
            local sy         = screenH_ / 2 + 8   -- 在"胜利"和进度条之间

            -- 闪入延迟：每颗星间隔 0.22 秒出现
            local STAR_DELAY = 0.22

            for si = 1, starCount do
                local earned  = si <= currentWaveStar_
                local appear  = starAnim_ - (si - 1) * STAR_DELAY
                local prog    = math.max(0, math.min(1, appear / 0.25))  -- 0.25秒放大进场
                local scale   = prog < 1 and (1.2 - 0.2 * prog) or 1.0  -- 过冲缩放
                local sx      = cx - totalW / 2 + (si - 1) * starGap

                if prog <= 0 then
                    -- 尚未出现：画暗灰空星轮廓
                    nvgBeginPath(vg_)
                    local pts = 5
                    for pi = 0, pts * 2 - 1 do
                        local a  = pi * math.pi / pts - math.pi / 2
                        local r  = (pi % 2 == 0) and starR or starR * 0.42
                        local px = sx + math.cos(a) * r
                        local py = sy + math.sin(a) * r
                        if pi == 0 then nvgMoveTo(vg_, px, py)
                        else           nvgLineTo(vg_, px, py) end
                    end
                    nvgClosePath(vg_)
                    nvgStrokeColor(vg_, nvgRGBA(80, 80, 80, 120))
                    nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
                else
                    -- 已出现：画实心星（earned=金色，unearned=灰色轮廓）
                    local sr = starR * scale
                    nvgBeginPath(vg_)
                    local pts = 5
                    for pi = 0, pts * 2 - 1 do
                        local a  = pi * math.pi / pts - math.pi / 2
                        local r  = (pi % 2 == 0) and sr or sr * 0.42
                        local px = sx + math.cos(a) * r
                        local py = sy + math.sin(a) * r
                        if pi == 0 then nvgMoveTo(vg_, px, py)
                        else           nvgLineTo(vg_, px, py) end
                    end
                    nvgClosePath(vg_)

                    if earned then
                        -- 金色实心星 + 发光晕
                        local pulse = 0.85 + 0.15 * math.abs(math.sin(starAnim_ * 2.4 + si * 1.1))
                        local glowR = sr * 1.6 * pulse
                        -- 外晕（模拟 glow）
                        nvgFillColor(vg_, nvgRGBA(255, 220, 60, math.floor(40 * pulse)))
                        nvgFill(vg_)
                        -- 重绘实心（glow路径污染了fill，重新画）
                        nvgBeginPath(vg_)
                        for pi = 0, pts * 2 - 1 do
                            local a  = pi * math.pi / pts - math.pi / 2
                            local r  = (pi % 2 == 0) and sr or sr * 0.42
                            local px = sx + math.cos(a) * r
                            local py = sy + math.sin(a) * r
                            if pi == 0 then nvgMoveTo(vg_, px, py)
                            else           nvgLineTo(vg_, px, py) end
                        end
                        nvgClosePath(vg_)
                        nvgFillColor(vg_, nvgRGBA(255, 210, 40, 255))
                        nvgFill(vg_)
                        -- 高光描边
                        nvgStrokeColor(vg_, nvgRGBA(255, 255, 180, math.floor(180 * pulse)))
                        nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
                        -- 中心光点
                        nvgBeginPath(vg_)
                        nvgCircle(vg_, sx, sy - sr * 0.15, sr * 0.18)
                        nvgFillColor(vg_, nvgRGBA(255, 255, 220, math.floor(200 * pulse)))
                        nvgFill(vg_)
                        -- 4射线光芒
                        if glowR > 10 then
                            for ri = 0, 3 do
                                local ra = ri * math.pi / 2 + starAnim_ * 0.4
                                nvgBeginPath(vg_)
                                nvgMoveTo(vg_, sx + math.cos(ra) * sr * 0.6, sy + math.sin(ra) * sr * 0.6)
                                nvgLineTo(vg_, sx + math.cos(ra) * glowR * 0.5, sy + math.sin(ra) * glowR * 0.5)
                                nvgStrokeColor(vg_, nvgRGBA(255, 240, 120, math.floor(80 * pulse)))
                                nvgStrokeWidth(vg_, 1.0); nvgStroke(vg_)
                            end
                        end
                    else
                        -- 未点亮：灰色空心星
                        nvgFillColor(vg_, nvgRGBA(60, 60, 60, 160))
                        nvgFill(vg_)
                        nvgStrokeColor(vg_, nvgRGBA(120, 120, 120, 140))
                        nvgStrokeWidth(vg_, 1.5); nvgStroke(vg_)
                    end
                end
            end

            -- 星级标签文字
            local labelT = { [1]="惨 胜", [2]="良 好", [3]="完 美" }
            local labelC = {
                [1] = {200, 120, 80},
                [2] = {140, 210, 255},
                [3] = {255, 220, 60},
            }
            local allShown = starAnim_ >= (currentWaveStar_ - 1) * STAR_DELAY + 0.4
            if allShown then
                local lc = labelC[currentWaveStar_] or {200,200,200}
                local labelAlpha = math.min(255, math.floor((starAnim_ - 0.6) / 0.3 * 255))
                if labelAlpha > 0 then
                    nvgFontSize(vg_, 12)
                    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg_, nvgRGBA(lc[1], lc[2], lc[3], math.min(255, labelAlpha)))
                    nvgText(vg_, screenW_/2, sy + starR + 14, labelT[currentWaveStar_] or "")
                end
            end
        end

        -- 倒计时进度条
        local gap = WAVE_GAP
        local pct = math.min(1, waveGapTimer_ / gap)
        local barW = 200
        local bx = screenW_/2 - barW/2
        local by = screenH_/2 + 52
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, barW, 10, 5)
        nvgFillColor(vg_, nvgRGBA(30,30,30,180))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx, by, barW * pct, 10, 5)
        nvgFillColor(vg_, nvgRGBA(50,220,100,200))
        nvgFill(vg_)
        nvgFontSize(vg_, 14)
        nvgFillColor(vg_, nvgRGBA(200,255,200,220))
        nvgText(vg_, screenW_/2, by + 28,
            string.format("%.1f 秒后进入第 %d 波", math.max(0, gap - waveGapTimer_), waveNum_+1))

        -- ── 波次预报面板 ──────────────────────────────────────────────────
        local forecast = getNextWavePreview(waveNum_ + 1)
        if forecast and #forecast.groups > 0 then
            -- 面板尺寸
            local panW  = math.min(screenW_ - 40, 320)
            local itemH = 22
            local padV  = 10
            local titleH = 18
            local panH  = titleH + padV + #forecast.groups * itemH + padV
            local panX  = screenW_ / 2 - panW / 2
            local panY  = by + 50

            -- 面板背景
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, panX, panY, panW, panH, 8)
            nvgFillColor(vg_, nvgRGBA(5, 15, 30, 210))
            nvgFill(vg_)
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, panX + 0.5, panY + 0.5, panW - 1, panH - 1, 8)
            nvgStrokeColor(vg_, nvgRGBA(60, 140, 255, 100))
            nvgStrokeWidth(vg_, 1)
            nvgStroke(vg_)

            -- 标题行
            nvgFontSize(vg_, 11)
            nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg_, nvgRGBA(120, 180, 255, 200))
            nvgText(vg_, screenW_ / 2, panY + titleH / 2 + 2,
                string.format("— 第 %d 波 预报（共约 %d 艘）—", waveNum_ + 1, forecast.total))

            -- 分隔线
            local sepY = panY + titleH + 2
            nvgBeginPath(vg_)
            nvgMoveTo(vg_, panX + 12, sepY)
            nvgLineTo(vg_, panX + panW - 12, sepY)
            nvgStrokeColor(vg_, nvgRGBA(60, 100, 180, 80))
            nvgStrokeWidth(vg_, 0.5)
            nvgStroke(vg_)

            -- 舰型条目
            local rowY = sepY + padV
            -- 颜色映射
            local SHIP_COLOR = {
                SCOUT         = {r=100, g=180, b=255},
                FRIGATE       = {r=80,  g=220, b=140},
                DESTROYER     = {r=255, g=180, b=80 },
                BATTLECRUISER = {r=255, g=100, b=80 },
                INTERCEPTOR   = {r=200, g=100, b=255},
                CARRIER       = {r=255, g=60,  b=60 },
            }

            for _, grp in ipairs(forecast.groups) do
                local clr = SHIP_COLOR[grp.stype] or {r=200,g=200,b=200}
                local isBoss = grp.isBoss == true

                -- 左侧色块圆点
                local dotX = panX + 18
                nvgBeginPath(vg_)
                nvgCircle(vg_, dotX, rowY + itemH / 2, 4)
                nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 255 or 200))
                nvgFill(vg_)
                if isBoss then
                    nvgBeginPath(vg_)
                    nvgCircle(vg_, dotX, rowY + itemH / 2, 5)
                    nvgStrokeColor(vg_, nvgRGBA(255, 200, 60, 220))
                    nvgStrokeWidth(vg_, 1)
                    nvgStroke(vg_)
                end

                -- 舰型名称
                nvgFontSize(vg_, 11)
                nvgTextAlign(vg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                if isBoss then
                    nvgFillColor(vg_, nvgRGBA(255, 200, 60, 240))
                else
                    nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, 220))
                end
                local label = isBoss and ("★ " .. grp.name) or grp.name
                nvgText(vg_, dotX + 12, rowY + itemH / 2, label)

                -- 右侧数量条 + 数字
                local barMaxW = panW * 0.35
                local barFrac = math.min(1, grp.count / math.max(1, forecast.total))
                local barFillW = math.max(4, math.floor(barMaxW * barFrac))
                local barX = panX + panW - 14 - barMaxW
                local barY = rowY + itemH / 2 - 4
                -- 底轨
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, barX, barY, barMaxW, 8, 3)
                nvgFillColor(vg_, nvgRGBA(20, 30, 50, 180))
                nvgFill(vg_)
                -- 填充
                nvgBeginPath(vg_)
                nvgRoundedRect(vg_, barX, barY, barFillW, 8, 3)
                nvgFillColor(vg_, nvgRGBA(clr.r, clr.g, clr.b, isBoss and 220 or 160))
                nvgFill(vg_)
                -- 数量数字
                nvgFontSize(vg_, 10)
                nvgTextAlign(vg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg_, nvgRGBA(200, 220, 255, 200))
                nvgText(vg_, panX + panW - 8, rowY + itemH / 2,
                    string.format("×%d", grp.count))

                rowY = rowY + itemH
            end
        end
        -- ── 波次预报结束 ──────────────────────────────────────────────────
    else
        nvgFillColor(vg_, nvgRGBA(255,50,50,255))
        nvgText(vg_, screenW_/2, screenH_/2 - 10, "战 败")

        -- M2: 添加触屏可点击按钮（同时保留键盘提示）
        local btnW, btnH = 130, 36
        local gap        = 20
        local totalW     = btnW * 2 + gap
        local bx1        = screenW_/2 - totalW/2
        local bx2        = bx1 + btnW + gap
        local by         = screenH_/2 + 28

        -- 按钮底色
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx1, by, btnW, btnH, 6)
        nvgFillColor(vg_, nvgRGBA(60,140,255,220))
        nvgFill(vg_)
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, bx2, by, btnW, btnH, 6)
        nvgFillColor(vg_, nvgRGBA(80,80,80,200))
        nvgFill(vg_)

        -- 按钮文字
        nvgFontSize(vg_, 15)
        nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg_, nvgRGBA(255,255,255,240))
        nvgText(vg_, bx1 + btnW/2, by + btnH/2, "[2] 重新战斗")
        nvgText(vg_, bx2 + btnW/2, by + btnH/2, "[1] 返回星图")

        -- 记录按钮区域供 OnClick 使用
        loseBtn1_ = { x=bx1, y=by, w=btnW, h=btnH }
        loseBtn2_ = { x=bx2, y=by, w=btnW, h=btnH }
    end
end

function BattleScene.Render()
    -- 屏幕震动偏移（战场内容整体平移，HUD/UI 不跟随震动）
    local shaking = shakeOffX_ ~= 0 or shakeOffY_ ~= 0
    if shaking then
        nvgSave(vg_)
        nvgTranslate(vg_, shakeOffX_, shakeOffY_)
    end

    drawGrid()
    drawBgStars()                      -- P3-1: 动态背景星星（视差三层 + 闪烁）
    drawEnvParticles()                 -- P1-2: 环境背景粒子（网格之上，舰船之下）
    for _, p in ipairs(projectiles_) do drawProjectile(p) end
    drawFireParticles()                -- 燃烧粒子在舰船下方渲染
    drawExplParticles()                -- 爆炸碎片粒子
    drawShockRings()                   -- 冲击波环（舰船下方，视觉层次感）
    for _, s in ipairs(playerFleet_) do drawShip(s) end
    for _, s in ipairs(enemyFleet_)  do drawShip(s) end
    drawHitSparks()                    -- 击中火花（舰船上方）
    drawMoveTarget()
    drawFloatTexts()                   -- 飘字在舰船上方渲染

    if shaking then nvgRestore(vg_) end

    drawWaveHUD()                      -- 波次信息 HUD（最上层，不随震动）
    drawEnvHUD()                       -- P1-2: 环境类型指示器（左上角）
    drawEnvAnnounce()                  -- P1-2: 进入新环境时的公告横幅
    drawFocusRing()                    -- P2-2: 集火目标橙色脉冲光环
    drawShipInfoPanel()                -- P2-2: 选中单舰信息面板（悬浮于战场上方）
    drawFocusHUD()                     -- P2-2: 顶部集火状态条（含取消按钮）
    drawComboHUD()                     -- 连击计数 HUD（右上角）
    drawFormationBar()                 -- P1-1: 阵型选择栏（技能栏左侧）
    drawRetreatReinforce()             -- P1-2: 撤退/增援按钮（右下角）
    BattleSkills.Draw({ vg = vg_, state = state_, rs = rs_, screenW = screenW_, screenH = screenH_ })  -- 底部技能栏
    drawBossWarning()                  -- Boss波次警告横幅（战斗开始时短暂显示）
    drawBossDestroyedEffect()          -- P3-2: Boss击破全屏闪光 + BOSS DESTROYED横幅
    drawFireworks()                    -- 烟花粒子（胜利特效，在 overlay 下方）
    drawStateOverlay()
    drawWaveSummary()                  -- P1-1: 波次战报摘要弹窗（win 阶段右侧）
    drawSkillUpgrade()                 -- P2-2: 技能升级选择弹窗（最顶层覆盖）
end

-- ============================================================================
-- 状态查询
-- ============================================================================
function BattleScene.GetState()       return state_ end
function BattleScene.GetWave()        return waveNum_ end
function BattleScene.GetPlayerCount() return #playerFleet_ end
function BattleScene.GetEnemyCount()  return #enemyFleet_ end
function BattleScene.GetStats()
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
        -- P3-1: 最高连击
        maxCombo       = battleStats_.maxCombo or 0,
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
            BattleScene.SetFormation(btn.key)
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
            shakeTimer_ = dur; shakeDur_ = dur; shakeStrength_ = str
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
