-- ============================================================================
-- network/Client.lua  -- 银河征服 客户端
-- 包含完整游戏逻辑 + 多人网络接入
-- ============================================================================
local Shared      = require("network.Shared")
local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")

local GameUI      = require("game.GameUI")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")

local Client = {}

-- ============================================================================
-- 私有状态
-- ============================================================================
local vg_           = nil
local screenW_      = 800
local screenH_      = 600

-- ============================================================================
-- 游戏时间限制
-- ============================================================================
local BASE_LIMIT      = 7200   -- 基础时长：2小时（秒）
local EXTRA_PER_AD    = 3600   -- 每次看广告增加：1小时（秒）
local MAX_EXTRA       = 7200   -- 最多可增加：2小时（秒）

local playTime_       = 0      -- 已游玩总时长（秒）
local extraTime_      = 0      -- 通过广告获得的额外时长（秒）
local timeoutTriggered_ = false  -- 是否已触发超时流程
local adWatching_     = false  -- 是否正在播放广告（防止重复点击）

-- 剩余可看广告次数（最多 MAX_EXTRA / EXTRA_PER_AD = 2 次）
local function getAdCount()
    return math.floor((MAX_EXTRA - extraTime_) / EXTRA_PER_AD)
end

-- 剩余游玩时间（秒）
local function getRemainingTime()
    return math.max(0, BASE_LIMIT + extraTime_ - playTime_)
end

local currentScene_   = "galaxy"
local refreshTimer_   = 0
local selectedPlanet_ = nil
local lastShownRemaining_ = -1   -- 上次传给 UI 的整秒值，相同时跳过调用

-- 游戏系统实例
local rm_      = Sys.ResourceManager.new()
local bs_      = Sys.BuildingSystem.new(rm_)       -- 行星建造系统
local bbs_     = Sys.BaseBuildingSystem.new(rm_)   -- 基地建造系统（独立）
local rs_      = Sys.ResearchSystem.new(rm_, bs_)
local ms_      = Sys.MarketSystem.new(rm_)
local player_  = Sys.PlayerProfile.new()
local spq_     = Sys.ShipProductionQueue.new(rm_)
local fm_      = Sys.FleetManager.new()
local activeFleetId_       = 1
local explorerColonizeMode_ = false   -- true 时点击未殖民星球将自动使用储备探索舰殖民

-- 基地模块效果脏标记（true=需要重算，避免每帧全量重算）
local baseEffectsDirty_ = true

-- 海盗 AI 实例（Init 时创建）
---@type table
local pirateAI_ = nil
-- 当前海盗进攻信息（nil=非海盗战斗）
local pirateAttackInfo_ = nil  -- { pirateLevel, baseId, targetName }
local pirateWarnPlayed_ = false  -- 海盗预警音效触发标记（避免每帧重复播放）

-- 结算状态
local endGameTriggered_ = false   -- 防止重复触发结算
local piratesKilled_    = 0       -- 累计击败海盗次数（战斗胜利计数）
local totalResearch_    = 0       -- 累计完成科技数（成就用）

-- 成就跨局持久化（softReset 时保存，setupSceneAndUI 时恢复）
local savedAchievements_ = nil   ---@type string[]|nil

-- 主菜单
local mainMenuActive_   = true    -- true=显示主菜单
local hasSave_          = false   -- 是否有本地存档
local mainMenuHover_    = nil     -- 当前悬停按钮 "new"|"continue"|nil
local skipSaveLoad_     = false   -- true=新游戏（跳过读档）

-- 难度选择
local difficultyChosen_ = false   -- false=正在显示难度选择屏幕
local difficulty_       = "normal"
local diffHoverBtn_     = nil     -- 当前悬停的难度按钮 key

local DIFFICULTY_CONFIGS = {
    -- attackFactor = 进攻间隔倍率（>1 越慢，<1 越快）
    -- 实际首攻窗口 = 210 × attackFactor × (0.75~1.30)
    -- initRes = 游戏开始时叠加到 ResourceManager 初始值的额外资源
    easy   = { label="简单", color={80,200,120},  attackFactor=2.2, maxThreat=2,
               desc="海盗进攻频率大幅降低，初始资源充裕，适合初次体验",
               initRes = { metal=800, esource=500, nuclear=200 } },
    normal = { label="普通", color={100,160,255}, attackFactor=1.0, maxThreat=5,
               desc="标准游戏体验，攻守均衡" },
    hard   = { label="困难", color={220,80,80},   attackFactor=0.65, maxThreat=5,
               desc="海盗进攻频繁，考验战略布局",
               initRes = { metal=-300, esource=-200 } },  -- 困难：初始资源削减
}
local DIFF_ORDER = {"easy", "normal", "hard"}

-- 网络状态
local scene_          = nil   -- 网络同步用 Scene
local serverConn_     = nil   -- 服务器连接
-- 云存档状态
local saveTimer_      = 0     -- 自动存档计时器
local AUTO_SAVE_INTERVAL = 60  -- 每 60 秒自动存档一次
local saveInProgress_ = false  -- 防止重复提交
local saveGame        -- 前向声明，函数体在网络部分定义

-- ============================================================================
-- 工具
-- ============================================================================
local function getDpr()
    return graphics:GetDPR()
end

local function getScreenSize()
    local dpr = getDpr()
    return graphics:GetWidth() / dpr, graphics:GetHeight() / dpr
end

-- ============================================================================
-- 基地模块效果应用
-- ============================================================================
--- 标记基地模块效果需要重算（下一帧 update 时执行）
local function markBaseEffectsDirty()
    baseEffectsDirty_ = true
end

--- 根据当前已安装的基地模块重新计算 rm_ 的速率加成和上限
--- 设计：通过 markBaseEffectsDirty() 延迟到 update 执行，避免每帧全量重算
local function applyBaseModuleEffects()
    if not baseEffectsDirty_ then return end
    baseEffectsDirty_ = false
    local base = GalaxyScene.GetBase()
    -- 先撤销上次由基地模块写入 rates 的加成（捕获旧值后再重置）
    local oldEsource = (rm_.baseBonus and rm_.baseBonus.esource) or 0
    local oldEnergy  = (rm_.baseBonus and rm_.baseBonus.energy)  or 0
    rm_.rates.energy  = (rm_.rates.energy  or 0) - oldEnergy
    rm_.rates.esource = (rm_.rates.esource or 0) - oldEsource
    -- S1 COLONY_BIOTECH: 撤销上次科技人口速率增量
    local oldTechPopDelta = (rm_.baseBonus and rm_.baseBonus.techPopRateDelta) or 0
    rm_.rates.population  = (rm_.rates.population or 0) - oldTechPopDelta
    -- 重置所有资源上限到基础值（精炼资源 + 原矿资源，避免模块效果叠加）
    local BASE_CAPS = { metal=99999, esource=99999, nuclear=9999, credits=9999999 }
    for res, cap in pairs(BASE_CAPS) do
        rm_.caps[res] = cap
    end
    -- 重置原矿上限（材料仓库模块影响这三项）
    rm_.caps.minerals = 9999
    rm_.caps.energy   = 9999
    rm_.caps.crystal  = 2000   -- 水晶上限提升至2000（避免新手快速满仓）
    rm_.baseBonus = {
        energy=0, esource=0,
        defense=0,           -- 防御炮台：每级 +50 基地防御力
        shield=0,            -- 护盾发生器：每级 +200 护盾值（科技SHIELD_REINFORCE叠加）
        shieldBonus=0,       -- 护盾强化科技额外护盾值
        defenseBonus=0,      -- 护盾强化科技额外防御比例
        researchMult=1.0,    -- 科研中心：每级 ×1.2 科研速度
        buildMult=1.0,       -- 行星探索中心：每级 ×0.75 建造时间
        shipyardMult=1.0,    -- 星际造船厂：每级 ×1.5 舰船建造速度
        fleetSpeedMult=1.0,  -- 曲速引擎科技/曲速闸门：舰队速度加成
        hasWarpGate=false,   -- 是否安装了曲速闸门
    }

    if not base or not base.colonized then
        rm_.refineryMult = 0
        return
    end

    -- 精炼厂：只判断存在与否（0=无，1=有），无倍率效果
    local refineryMult  = 0
    local commandLevels = 0   -- 所有指挥中枢等级之和

    for _, b in ipairs(base.buildings) do
        local lvl = b.level or 1
        if b.key == "ENERGY_CORE" then
            -- 能量核心：直接精炼所有原矿，精炼倍率 +0.5×/级（与精炼厂叠加）
            refineryMult = refineryMult + 0.5 * lvl
        elseif b.key == "SOLAR_ARRAY" then
            -- 太阳能阵列：直接产出能源 +3/s/级（无需精炼）
            rm_.baseBonus.esource = rm_.baseBonus.esource + 3 * lvl
        elseif b.key == "MINERAL_SILO" then
            -- 资源仓储：原矿存储上限 ×2^级（minerals/energy/crystal）
            local mult = 2 ^ lvl
            rm_.caps.minerals = rm_.caps.minerals * mult
            rm_.caps.energy   = rm_.caps.energy   * mult
            rm_.caps.crystal  = rm_.caps.crystal  * mult
        elseif b.key == "MATERIAL_DEPOT" then
            -- 材料仓库：精炼资源上限 ×2^级（metal/esource/nuclear）
            local mult = 2 ^ lvl
            rm_.caps.metal    = rm_.caps.metal    * mult
            rm_.caps.esource  = rm_.caps.esource  * mult
            rm_.caps.nuclear  = rm_.caps.nuclear  * mult
        elseif b.key == "REFINERY" then
            -- 精炼厂：Lv.1=1×  Lv.2=1.5×  Lv.3=2×  每级+0.5×
            refineryMult = 1.0 + 0.5 * (lvl - 1)
        elseif b.key == "COMMAND_CENTER" then
            -- 指挥中枢：每级 +1 编队上限（上限 10）
            commandLevels = commandLevels + lvl
        elseif b.key == "DEFENSE_CANNON" then
            -- 防御炮台：每级 +50 基地防御力（海盗攻击时减伤）
            rm_.baseBonus.defense = rm_.baseBonus.defense + 50 * lvl
        elseif b.key == "BASE_SHIELD" then   -- L3: 原SHIELD_GEN，已重命名避免与行星建筑冲突
            -- 护盾发生器：每级 +200 护盾值（先于HP承伤）
            rm_.baseBonus.shield = rm_.baseBonus.shield + 200 * lvl
        elseif b.key == "RESEARCH_CENTER" then
            -- 科研中心：每级科研速度 ×1.2（累乘）
            rm_.baseBonus.researchMult = rm_.baseBonus.researchMult * (1.2 ^ lvl)
        elseif b.key == "BUILD_CENTER" then
            -- 行星探索中心：每级建造时间 ×0.75（累乘，最低为25%原时间）
            rm_.baseBonus.buildMult = math.max(0.25, rm_.baseBonus.buildMult * (0.75 ^ lvl))
        elseif b.key == "SHIPYARD" then
            -- 星际造船厂：每级舰船建造速度 ×1.5（累乘）
            rm_.baseBonus.shipyardMult = rm_.baseBonus.shipyardMult * (1.5 ^ lvl)
        elseif b.key == "WARP_GATE" then
            -- 曲速闸门：解锁舰队快速移动（速度×2），与WARP_DRIVE科技叠加
            rm_.baseBonus.hasWarpGate  = true
            rm_.baseBonus.fleetSpeedMult = rm_.baseBonus.fleetSpeedMult * (2.0 ^ lvl)
        end
    end

    -- 保留已解锁科技的加成（避免被重置清除）
    -- S1: 统一重放所有已解锁科技的特殊 bonus 到 baseBonus
    local techBonus = rm_.baseBonus
    if rs_ and rs_.unlocked then
        for id, _ in pairs(rs_.unlocked) do
            local td = TECHS[id]
            if td and td.bonus then
                local b = td.bonus
                -- WARP_DRIVE: 舰队速度
                if b.fleetSpeedMult then
                    techBonus.fleetSpeedMult = techBonus.fleetSpeedMult * b.fleetSpeedMult
                end
                -- SHIELD_REINFORCE: 护盾/防御
                if b.shieldBonus then
                    techBonus.shieldBonus  = (techBonus.shieldBonus  or 0) + b.shieldBonus
                    techBonus.defenseBonus = (techBonus.defenseBonus or 0) + (b.defenseBonus or 0)
                end
                -- HULL_ALLOY: 舰船最大耐久倍率
                if b.shipHealthMult then
                    techBonus.shipHealthMult = (techBonus.shipHealthMult or 1.0) * b.shipHealthMult
                end
                -- ADVANCED_WEAPONS: 舰船攻击力倍率
                if b.shipDmgMult then
                    techBonus.shipDmgMult = (techBonus.shipDmgMult or 1.0) * b.shipDmgMult
                end
                -- RAPID_REFINE: 全局精炼速率倍率
                if b.globalRefineMult then
                    techBonus.globalRefineMult = (techBonus.globalRefineMult or 1.0) * b.globalRefineMult
                end
                -- CRYSTAL_PROCESS: 水晶→核能精炼效率
                if b.refineMult == "crystal" then
                    techBonus.crystalRefineMult = (techBonus.crystalRefineMult or 1.0) * (b.val or 1.0)
                end
                -- COLONY_BIOTECH: 人口增长速率倍率
                if b.colonyPopMult then
                    techBonus.colonyPopMult = (techBonus.colonyPopMult or 1.0) * b.colonyPopMult
                end
                -- QUANTUM_CORE: 核心升级费用折扣 & 科研速度
                if b.coreUpgradeCostMult then
                    techBonus.coreUpgradeCostMult = (techBonus.coreUpgradeCostMult or 1.0) * b.coreUpgradeCostMult
                end
                if b.researchSpeedMult then
                    techBonus.researchSpeedMult = (techBonus.researchSpeedMult or 1.0) * b.researchSpeedMult
                end
            end
        end
    end

    -- 人口影响舰队上限：每100人口额外+1编队（最多+3）
    local popBonus = math.min(3, math.floor((rm_.resources.population or 0) / 100))

    -- 应用指挥中枢效果：基础 5 + 所有指挥中枢等级之和 + 人口加成，上限 10
    fm_:setMaxFleets(5 + commandLevels + popBonus)

    -- 应用太阳能阵列加成（直接写入精炼资源层，无需精炼）
    rm_.rates.esource = (rm_.rates.esource or 0) + rm_.baseBonus.esource

    -- 星航基地核心 Lv.2+ 提供基础精炼能力（mult=0.3 → 矿石2.1/s）
    -- 若 REFINERY 已安装则取较大值（Lv.1=1.0×/7/s，Lv.2=1.5×/10.5/s，Lv.3=2.0×/14/s）
    local coreLevel = (base and base.coreLevel) or 1
    if coreLevel >= 2 then
        local coreRefineMult = 0.3
        refineryMult = math.max(refineryMult, coreRefineMult)
    end

    -- 更新精炼倍率
    rm_.refineryMult = refineryMult

    -- H1 修复：Gas Giant esourceMult 加成 —— 乘以精炼倍率（在所有模块计算完成后）
    -- applyPlanetTypeBonus 将 esourceMult 存入 rm_.baseBonus.esourceMult，这里才真正生效
    if rm_.baseBonus.esourceMult and rm_.baseBonus.esourceMult > 1.0 then
        rm_.refineryMult = rm_.refineryMult * rm_.baseBonus.esourceMult
    end

    -- S1 COLONY_BIOTECH: 人口增长速率倍率（累乘方式，避免与行星加成冲突）
    local colPopMult = techBonus.colonyPopMult or 1.0
    if colPopMult ~= 1.0 then
        local baseRate   = rm_.rates.population or 0
        local techDelta  = baseRate * (colPopMult - 1.0)
        rm_.rates.population          = baseRate + techDelta
        techBonus.techPopRateDelta    = techDelta
    else
        techBonus.techPopRateDelta    = 0
    end
end

-- ============================================================================
-- 结算触发
-- ============================================================================
--- 计算总游戏时长（秒），由 handleUpdate 中的 totalPlayTime_ 维护
local totalPlayTime_ = 0

-- 前向声明（函数体在后面定义）
local softReset
local setupSceneAndUI
local onGameReady

--- 触发结算界面（只触发一次，防止重复）
local function triggerEndGame(gameType)
    if endGameTriggered_ then return end
    endGameTriggered_ = true

    -- 收集统计数据
    local colonized = 0
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}) do
        if p.colonized then colonized = colonized + 1 end
    end

    local stats = {
        playTime      = totalPlayTime_,   -- 秒数，由 GameUI 格式化
        colonized     = colonized,
        piratesKilled = piratesKilled_,
        level         = (player_ and player_.level) or 1,
        rank          = (player_ and player_.rank)  or "指挥官",
    }

    -- 结算时停止自动存档、暂停海盗 AI
    if pirateAI_ then pirateAI_.paused = true end

    -- 提交本局得分到排行榜
    -- 得分公式：殖民地 × 100 + 击败海盗 × 50 - 游戏时长（分钟，越短越好）
    local scoreVal = colonized * 100
                   + piratesKilled_ * 50
                   - math.floor((totalPlayTime_ or 0) / 60)
    scoreVal = math.max(0, scoreVal)
    -- 只有高于历史最高分才提交（避免刷低分）
    clientCloud:Get("galaxy_score", {
        ok = function(_, iscores)
            local best = iscores.galaxy_score or 0
            if scoreVal > best then
                clientCloud:BatchSet()
                    :SetInt("galaxy_score",   scoreVal)
                    :SetInt("galaxy_colonized", colonized)
                    :SetInt("galaxy_kills",   piratesKilled_)
                    :Save("结算提交", {
                        ok = function()
                            print(string.format("[Client] 排行榜分数已更新: %d (旧 %d)", scoreVal, best))
                        end,
                        error = function(_, reason)
                            print("[Client] 排行榜提交失败: " .. tostring(reason))
                        end,
                    })
            end
        end,
        error = function() end,
        timeout = function() end,
    })

    GameUI.ShowEndGame(gameType, stats, function()
        GameUI.HideEndGame()
        softReset()   -- 完整重置所有系统，开始新游戏
    end)
end

--- 检查是否满足胜利条件：所有海盗基地均已摧毁（active == false）
local function checkVictory()
    if endGameTriggered_ then return end
    if not pirateAI_ or not pirateAI_.bases then return end
    local allDestroyed = true
    for _, b in ipairs(pirateAI_.bases) do
        if b.active then allDestroyed = false; break end
    end
    if allDestroyed then
        print("[Game] 胜利！所有海盗基地已摧毁")
        Achievement.Check("victory", { victory = true, playTime = playTime_ })
        Audio.StopBGM()
        Audio.Play(Audio.SFX.VICTORY or Audio.SFX.BATTLE_WIN)
        -- 播放胜利 fanfare（单次，不循环）
        Audio.PlayBGM(Audio.BGM.VICTORY_FANFARE, 0, false)
        triggerEndGame("win")
    end
end

--- 检查是否满足失败条件：星航基地 HP ≤ 0
local function checkDefeat()
    if endGameTriggered_ then return end
    local base = GalaxyScene.GetBase and GalaxyScene.GetBase()
    if not base then return end
    local hp = base.hp or base.currentHP or (base.colonized and 100 or nil)
    if hp ~= nil and hp <= 0 then
        print("[Game] 失败！星航基地被摧毁")
        Audio.Play(Audio.SFX.BATTLE_LOSE)
        triggerEndGame("lose")
    end
end

-- ============================================================================
-- 场景切换
-- ============================================================================
local function switchScene(name)
    currentScene_ = name
    local hasPlanet = (GalaxyScene.GetSelected() ~= nil)
    GameUI.ShowScene(name, hasPlanet)
    -- BGM 随场景切换
    if name == "battle" then
        Audio.PlayBGM(Audio.BGM.BATTLE_THEME, 1.5)
    elseif name == "galaxy" then
        Audio.PlayBGM(Audio.BGM.GALAXY_MAIN, 1.5)
    end
end

-- ============================================================================
-- 海盗：获取玩家所有可被攻击的目标位置
-- ============================================================================
local function getPlayerTargets()
    local targets = {}
    -- 已殖民行星
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        -- 使用行星在星系中的世界坐标
        local wx = p.system and (p.system.x + math.cos(p.angle) * p.orbitRadius) or 0
        local wy = p.system and (p.system.y + math.sin(p.angle) * p.orbitRadius) or 0
        targets[#targets+1] = { x=wx, y=wy, name=p.name }
    end
    -- 星航基地（已展开时才是目标）
    local base = GalaxyScene.GetBase()
    if base and base.colonized then
        targets[#targets+1] = { x=base.x or 0, y=base.y or 0, name="星航基地" }
    end
    return targets
end

-- ============================================================================
-- 海盗进攻触发：切入战斗场景
-- ============================================================================
local BattleScene = require("game.BattleScene")

local function onPirateAttack(pirateLevel, baseId, targetName)
    -- 记录此次进攻信息，战斗结束后根据胜负处理
    pirateAttackInfo_ = { pirateLevel=pirateLevel, baseId=baseId, targetName=targetName }

    -- 以海盗等级作为起始波次初始化战斗场景
    BattleScene.Init({
        vg          = vg_,
        notifyFn    = GameUI.Notify,
        player      = player_,
        rm          = rm_,
        spq         = spq_,
        startWave   = pirateLevel,
        onBattleEnd = function(result)
            if result == "win" then
                Audio.Play(Audio.SFX.BATTLE_WIN)
                piratesKilled_ = piratesKilled_ + 1
                Achievement.Check("pirate_kill", { piratesKilled = piratesKilled_ })
                -- 玩家胜利：削弱海盗基地
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                end
                GameUI.Notify("击退海盗！返回星图", "success")
                checkVictory()
            else
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                -- 玩家战败：扣除资源（基础惩罚15%，防御/护盾可减伤）
                -- 防御炮台：每50防御力减1%惩罚（上限 -10%）
                -- 护盾发生器/护盾强化：每200护盾值减1%惩罚（上限 -5%）
                local defVal    = (rm_.baseBonus and rm_.baseBonus.defense) or 0
                local shldVal   = ((rm_.baseBonus and rm_.baseBonus.shield) or 0)
                               + ((rm_.baseBonus and rm_.baseBonus.shieldBonus) or 0)
                local defReduce   = math.min(0.10, math.floor(defVal  / 50)  * 0.01)
                local shldReduce  = math.min(0.05, math.floor(shldVal / 200) * 0.01)
                local penalty = math.max(0.02, 0.15 - defReduce - shldReduce)
                local lostParts = {}
                for _, res in ipairs({"minerals","energy","crystal","metal","esource","nuclear"}) do
                    local cur = rm_.resources[res] or 0
                    local loss = math.floor(cur * penalty)
                    if loss > 0 then
                        rm_:add(res, -loss)
                        lostParts[#lostParts+1] = (RES_LABELS and RES_LABELS[res] or res) .. "-" .. loss
                    end
                end
                -- 海盗基地强化
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:strengthenBase(pirateAttackInfo_.baseId)
                end
                local penaltyPct = math.floor(penalty * 100)
                local lostStr = #lostParts > 0
                    and ("资源损失(" .. penaltyPct .. "%): " .. table.concat(lostParts, " "))
                    or "无资源损失"
                GameUI.Notify("舰队覆灭！" .. lostStr, "error")
                checkDefeat()
            end
            pirateAttackInfo_ = nil
            -- 切回星图
            switchScene("galaxy")
            saveGame()
        end,
    })

    -- 将玩家编队中的舰船加入战斗
    if fm_ then
        for i = 1, fm_.maxFleets do
            local fl = fm_.fleets[i]
            if fl then
                for _, entry in ipairs(fl.ships) do
                    for _ = 1, entry.count do
                        BattleScene.AddProductionShip(entry.shipType)
                    end
                end
            end
        end
    end

    switchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("海盗Lv%d 进犯 %s！进入战斗！", pirateLevel, targetName), "error")
end

-- ============================================================================
-- 玩家主动突袭海盗基地（编队到达海盗基地时触发）
-- ============================================================================
local function onFleetSiegeBase(fleetId, baseId)
    -- 找到对应基地
    local base = nil
    if pirateAI_ then
        for _, b in ipairs(pirateAI_.bases) do
            if b.id == baseId then base = b; break end
        end
    end
    if not base or not base.active then
        GameUI.Notify("海盗基地已被摧毁，编队返航", "info")
        return
    end

    -- 记录突袭信息（siege=true 标记区别于被动防守）
    pirateAttackInfo_ = { pirateLevel=base.level, baseId=baseId, targetName="海盗基地", fleetId=fleetId, siege=true }

    BattleScene.Init({
        vg          = vg_,
        notifyFn    = GameUI.Notify,
        player      = player_,
        rm          = rm_,
        spq         = spq_,
        startWave   = base.level,
        onBattleEnd = function(result)
            if result == "win" then
                Audio.Play(Audio.SFX.BATTLE_WIN)
                piratesKilled_ = piratesKilled_ + 1
                Achievement.Check("pirate_kill", { piratesKilled = piratesKilled_ })
                -- 突袭胜利：双倍削弱（主动突袭比被动防守伤害更大）
                if pirateAI_ and pirateAttackInfo_ then
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                    pirateAI_:weakenBase(pirateAttackInfo_.baseId)
                end
                GameUI.Notify("突袭成功！海盗基地受到重创！", "success")
                checkVictory()
            else
                Audio.Play(Audio.SFX.BATTLE_LOSE)
                -- 突袭失败：该编队损失约 50% 舰船
                if pirateAttackInfo_ and pirateAttackInfo_.fleetId and fm_ then
                    local fid = pirateAttackInfo_.fleetId
                    local fl  = fm_.fleets[fid]
                    if fl then
                        -- 收集需要移除的舰船（避免遍历时修改）
                        local toRemove = {}
                        for _, entry in ipairs(fl.ships) do
                            local loss = math.max(1, math.floor(entry.count * 0.5))
                            for _ = 1, loss do
                                toRemove[#toRemove+1] = entry.shipType
                            end
                        end
                        for _, st in ipairs(toRemove) do
                            fm_:removeShip(fid, st)
                        end
                        GalaxyScene.InvalidateFleetColor(fid)
                        GameUI.RefreshFleetPanel(fm_, fid)
                    end
                end
                GameUI.Notify("突袭失败！舰队损失惨重！", "error")
            end
            pirateAttackInfo_ = nil
            switchScene("galaxy")
            saveGame()
        end,
    })

    -- 将该编队的舰船加入战斗（突袭只用派出的编队，不用全部舰队）
    if fm_ then
        local fl = fm_.fleets[fleetId]
        if fl then
            for _, entry in ipairs(fl.ships) do
                for _ = 1, entry.count do
                    BattleScene.AddProductionShip(entry.shipType)
                end
            end
        end
    end

    switchScene("battle")
    Audio.Play(Audio.SFX.BATTLE_START)
    GameUI.Notify(string.format("突袭海盗基地 Lv%d！进入战斗！", base.level), "error")
end

-- ============================================================================
-- 升级奖励处理
-- ============================================================================
local function handleLevelUp(leveled, newLevel, newRank, rewards)
    if not leveled then return end
    Audio.Play(Audio.SFX.LEVELUP)
    rm_:add("metal",   rewards.metal)
    rm_:add("esource", rewards.esource)
    rm_:add("nuclear", rewards.nuclear)
    local isMilestone = (newLevel % 5 == 0)
    local tag = isMilestone and "里程碑晋升" or "晋升"
    GameUI.Notify(
        tag .. " Lv." .. newLevel .. " [" .. newRank .. "]  奖励: 金属+" ..
        rewards.metal .. " 能源+" .. rewards.esource .. " 核能+" .. rewards.nuclear,
        isMilestone and "success" or "info"
    )
end

-- ============================================================================
-- 阶段性目标检测
-- ============================================================================
local completedGoals_ = {}   -- 已完成的目标 id 集合
local totalShipsBuilt_ = 0   -- 累计造船数量

local function checkStageGoals()
    if not STAGE_GOALS then return end
    -- 构建 gameState 快照（按需填充）
    local gameState = {
        profile        = player_,
        base           = GalaxyScene.GetBase(),
        rs             = rs_,
        totalShipsBuilt= totalShipsBuilt_,
    }
    for _, goal in ipairs(STAGE_GOALS) do
        if not completedGoals_[goal.id] then
            local callOk, checkResult = pcall(goal.check, gameState)
            if callOk and checkResult then   -- checkResult 是 goal.check 返回的布尔值
                completedGoals_[goal.id] = true
                -- 发放奖励
                local rewardStr = ""
                if goal.reward then
                    local parts = {}
                    for res, amt in pairs(goal.reward) do
                        rm_:add(res, amt)
                        local label = RES_LABELS and RES_LABELS[res] or res
                        parts[#parts+1] = label .. "+" .. amt
                    end
                    rewardStr = " 奖励: " .. table.concat(parts, " ")
                end
                GameUI.Notify("✓ 目标达成: " .. goal.title .. rewardStr, "success")
                print("[Goal] 完成: " .. goal.id)
            end
        end
    end
end

-- ============================================================================
-- 回调
-- ============================================================================
local function onBuildCb(key, isUpgrade, bldIdx)
    if key == "__switch_galaxy" then switchScene("galaxy"); return end
    local planet = GalaxyScene.GetSelected()
    if not planet then GameUI.Notify("请先选择一个已探索星球", "warn"); return end
    local ok, reason
    if isUpgrade then
        ok, reason = bs_:upgrade(bldIdx, planet)
    else
        ok, reason = bs_:build(key, planet)
    end
    if ok then
        Audio.Play(Audio.SFX.BUILD_START)
        GameUI.Notify("开始" .. (isUpgrade and "升级" or "建造") .. ": " .. BUILDINGS[key].name, "info")
        GameUI.RefreshPlanetPanel(planet)
    else
        GameUI.Notify((isUpgrade and "升级" or "建造") .. "失败: " .. (reason or ""), "error")
    end
end

local function onBaseBuildCb(key, isUpgrade, bldIdx)
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason
    if isUpgrade then
        ok, reason = bbs_:upgrade(bldIdx, base)
    else
        ok, reason = bbs_:build(key, base)
    end
    if ok then
        Audio.Play(Audio.SFX.BUILD_START)
        local modName = BASE_MODULES[key] and BASE_MODULES[key].name or key
        GameUI.Notify("开始" .. (isUpgrade and "升级" or "安装") .. ": " .. modName, "info")
        GameUI.RefreshPlanetPanel(base)
    else
        GameUI.Notify((isUpgrade and "升级" or "安装") .. "失败: " .. (reason or ""), "error")
    end
end

local function onCoreUpgradeCb()
    local base = GalaxyScene.GetBase()
    if not base or not base.colonized then
        GameUI.Notify("基地尚未建立", "warn"); return
    end
    local ok, reason = bbs_:upgradeCore(base)
    if ok then
        local nextLv = (base.coreLevel or 1)   -- upgradeCore 已入队，level 在完成时写入
        GameUI.Notify("核心升级已启动 → Lv." .. nextLv + 1 .. " (建造中…)", "info")
        GameUI.RefreshPlanetPanel(base)
    else
        GameUI.Notify("核心升级失败: " .. (reason or ""), "error")
    end
end

local function onResearchCb(id)
    local ok, reason = rs_:start(id)
    if ok then
        Audio.Play(Audio.SFX.RESEARCH_START)
        GameUI.Notify("开始研发: " .. TECHS[id].name, "info")
        GameUI.RefreshTechPanel()
    else
        GameUI.Notify("研发失败: " .. (reason or ""), "error")
    end
end

local function onMarketCb(action, res, amount)
    local ok, val
    if action == "sell" then
        ok, val = ms_:sell(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("出售 " .. RES_LABELS[res] .. "×" .. amount .. "  +★" .. val, "success")
        else GameUI.Notify("出售失败: " .. (val or ""), "error") end
    else
        ok, val = ms_:buy(res, amount)
        if ok then
            Audio.Play(Audio.SFX.MARKET_TRADE)
            GameUI.Notify("购买 " .. RES_LABELS[res] .. "×" .. amount .. "  -★" .. val, "success")
        else GameUI.Notify("购买失败: " .. (val or ""), "error") end
    end
    GameUI.RefreshMarketPanel()
    GameUI.RefreshResourceBar()
end

--- 应用星球类型加成到资源速率（幂等设计：每次调用前先撤销旧加成再重新应用）
--- planet.appliedBonus 存储上次已应用的加成量，避免重复叠加
local function applyPlanetTypeBonus(planet)
    local ptype = planet.ptype
    if not ptype or not PLANET_TYPE_BONUS then return end
    local bonus = PLANET_TYPE_BONUS[ptype]
    if not bonus then return end

    -- 先撤销上次对该行星应用过的加成（幂等保障）
    local prev = planet.appliedBonus or {}
    if prev.mineralsDelta then
        rm_.rates.minerals = (rm_.rates.minerals or 0) - prev.mineralsDelta
    end
    if prev.energyDelta then
        rm_.rates.energy = (rm_.rates.energy or 0) - prev.energyDelta
    end
    if prev.popDelta then
        rm_.rates.population = (rm_.rates.population or 0) - prev.popDelta
    end
    if prev.crystalDelta then
        rm_.rates.crystal = (rm_.rates.crystal or 0) - prev.crystalDelta
    end
    if prev.metalCapBonus then
        rm_.caps.metal = math.floor((rm_.caps.metal or 99999) - prev.metalCapBonus)
    end

    -- 重置 esourceMult（由所有殖民行星循环后重新累乘）
    -- 注意：esourceMult 在 reapplyAllPlanetBonuses 中统一重置，这里只处理单行星
    planet.appliedBonus = {}
    local ab = planet.appliedBonus

    -- 矿石产量加成（Terran/Volcanic）
    if bonus.mineralMult then
        local delta = 0
        for _, b in ipairs(planet.buildings or {}) do
            if b.key == "MINE" and b.currentProd then
                delta = delta + (b.currentProd.minerals or 0) * (bonus.mineralMult - 1.0)
            end
        end
        if delta ~= 0 then
            rm_.rates.minerals = (rm_.rates.minerals or 0) + delta
            ab.mineralsDelta = delta
        end
    end
    -- 能量产量加成（Desert）
    if bonus.energyMult then
        local delta = 0
        for _, b in ipairs(planet.buildings or {}) do
            if b.key == "POWER_PLANT" and b.currentProd then
                delta = delta + (b.currentProd.energy or 0) * (bonus.energyMult - 1.0)
            end
        end
        if delta ~= 0 then
            rm_.rates.energy = (rm_.rates.energy or 0) + delta
            ab.energyDelta = delta
        end
    end
    -- 人口增长加成（Oceanic）—— 使用加法增量（避免乘法导致的指数膨胀）
    if bonus.popMult then
        local basePopRate = 0.1   -- ResourceManager.new() 中的初始 population rate
        local delta = basePopRate * (bonus.popMult - 1.0)
        rm_.rates.population = (rm_.rates.population or 0) + delta
        ab.popDelta = delta
        markBaseEffectsDirty()
    end
    -- 水晶产量加成（Volcanic）
    if bonus.crystalMult then
        local base_rate = 2.0   -- ResourceManager.new() 中的 crystal rate 基准
        local delta = base_rate * (bonus.crystalMult - 1.0)
        rm_.rates.crystal = (rm_.rates.crystal or 0) + delta
        ab.crystalDelta = delta
    end
    -- 金属容量加成（Barren）
    if bonus.metalCapMult then
        local capBonus = math.floor(99999 * (bonus.metalCapMult - 1.0))
        rm_.caps.metal = (rm_.caps.metal or 99999) + capBonus
        ab.metalCapBonus = capBonus
    end
    -- 能源精炼加成（Gas Giant）：标记到 baseBonus，由 applyBaseModuleEffects 读取
    if bonus.esourceMult then
        rm_.baseBonus = rm_.baseBonus or {}
        rm_.baseBonus.esourceMult = (rm_.baseBonus.esourceMult or 1.0) * bonus.esourceMult
    end
    print("[Colony] 星球类型加成 " .. ptype .. " → " .. (bonus.label or ""))
end

--- 重新对所有已殖民行星应用类型加成（读档后调用，确保速率一致）
local function reapplyAllPlanetBonuses()
    -- 先清空所有行星的 appliedBonus，让 applyPlanetTypeBonus 从零开始
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        p.appliedBonus = nil
    end
    -- 重置 esourceMult（避免累乘多次）
    if rm_.baseBonus then rm_.baseBonus.esourceMult = nil end
    -- 逐一重新应用
    for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
        applyPlanetTypeBonus(p)
    end
    markBaseEffectsDirty()
end

-- 内部殖民执行（消耗资源 + 调用 GalaxyScene）
local function doColonize(planet)
    if not planet or planet.colonized then return false end
    local cost = { metal = 200, esource = 100 }
    if not rm_:canAfford(cost) then
        GameUI.Notify("资源不足: 探索需要 金属×200 能源×100", "error")
        return false
    end
    rm_:spend(cost)
    local leveled, newLevel, newRank, rewards = GalaxyScene.Colonize(planet)
    Audio.Play(Audio.SFX.COLONIZE_SUCCESS)
    -- 成就检查：殖民类
    do
        local colonized = #(GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {})
        Achievement.Check("colonize", { totalColonized = colonized })
    end
    -- 应用星球类型加成
    applyPlanetTypeBonus(planet)
    local ptypeLabel = (PLANET_TYPE_BONUS and planet.ptype and PLANET_TYPE_BONUS[planet.ptype]) and
                       ("  [" .. (PLANET_TYPE_BONUS[planet.ptype].label or planet.ptype) .. "]") or ""
    GameUI.Notify("探索成功: " .. planet.name .. ptypeLabel .. "  (金属-200  能源-100)", "success")
    handleLevelUp(leveled, newLevel, newRank, rewards)
    GameUI.RefreshPlanetPanel(planet)
    checkStageGoals()   -- 殖民后检查阶段目标
    saveGame()
    return true
end

--- 检查指定编队是否含有探索舰
local function fleetHasExplorer(fleetId)
    if not fm_ then return false end
    local fl = fm_.fleets[fleetId]
    if not fl then return false end
    for _, e in ipairs(fl.ships) do
        if e.shipType == "EXPLORER" and e.count > 0 then return true end
    end
    return false
end

-- 探索舰殖民回调（由 GameUI 储备面板"殖民"按钮触发）
-- 现在触发条件改为：储备中有探索舰（直接消耗储备池）
local function onExplorerColonizeCb()
    -- 检查储备中有探索舰
    local cnt = fm_.reserve and (fm_.reserve["EXPLORER"] or 0) or 0
    if cnt <= 0 then
        GameUI.Notify("储备中没有探索舰", "warn"); return
    end
    local sel = GalaxyScene.GetSelected()
    if sel and not sel.colonized and not sel.isBase then
        -- 已选中未殖民星球，直接殖民
        local ok = doColonize(sel)
        if ok then
            fm_.reserve["EXPLORER"] = cnt - 1
            if fm_.reserve["EXPLORER"] <= 0 then fm_.reserve["EXPLORER"] = nil end
            explorerColonizeMode_ = false
            GameUI.RefreshReservePanel(fm_)
        end
    else
        -- 进入殖民选择模式，提示玩家点击目标星球
        explorerColonizeMode_ = true
        GameUI.Notify("已选择探索舰 — 请点击一个未探索星球执行探索", "info")
        GameUI.SetExplorerColonizeMode(true)
    end
end

local function onShipQueueCb(shipType)
    local planet = GalaxyScene.GetSelected()
    -- 若未选中星球，尝试用基地
    if not planet then
        local base = GalaxyScene.GetBase()
        if base and base.colonized then planet = base end
    end
    if not planet then GameUI.Notify("请先选择有造船厂的星球或基地", "warn"); return end
    local ok, reason = spq_:queue(shipType, planet)
    if ok then
        GameUI.Notify("加入建造队列: " .. SHIP_TYPES[shipType].name, "info")
        GameUI.RefreshShipyardPanel()
    else
        GameUI.Notify("造船失败: " .. (reason or ""), "error")
    end
end

local function onPlanetSelect(planet)
    selectedPlanet_ = planet
    -- 探索舰殖民模式：点击未殖民星球直接执行殖民
    if explorerColonizeMode_ and planet and not planet.colonized and not planet.isBase then
        local cnt = fm_.reserve and (fm_.reserve["EXPLORER"] or 0) or 0
        if cnt > 0 then
            local ok = doColonize(planet)
            if ok then
                fm_.reserve["EXPLORER"] = cnt - 1
                if fm_.reserve["EXPLORER"] <= 0 then fm_.reserve["EXPLORER"] = nil end
                GameUI.RefreshReservePanel(fm_)
            end
        end
        explorerColonizeMode_ = false
        GameUI.SetExplorerColonizeMode(false)
    end
    GameUI.RefreshPlanetPanel(planet)
    GameUI.RefreshShipyardPanel()
    GameUI.ShowScene("galaxy", planet ~= nil)
end

-- ============================================================================
-- 云存档：序列化当前游戏状态为 JSON
-- ============================================================================
local function buildSaveData()
    local galaxyData = GalaxyScene.GetSaveData()
    local saveData = {
        version   = 1,
        resources = rm_:serialize().resources,
        research  = rs_:serialize(),
        player    = player_:serialize(),
        shipQueue = spq_:serialize(),
        fleet     = fm_:serialize(),
        planets   = galaxyData.planets,
        base      = galaxyData.base,
        pirate       = pirateAI_ and pirateAI_:serialize() or nil,
        tutorial     = GameUI.TutorialSerialize(),   -- 教程完成进度
        achievements = Achievement.GetUnlocked(),    -- 已解锁成就列表
        totalShipsBuilt = totalShipsBuilt_,          -- 累计造船数（阶段目标用）
        completedGoals  = completedGoals_,           -- 已完成目标 id 集合（防止重复奖励）
        totalResearch   = totalResearch_,            -- 累计科技数（成就用）
    }
    return cjson.encode(saveData)
end

-- 保存到本地文件
saveGame = function()
    if saveInProgress_ then return end
    saveInProgress_ = true
    -- H3: 用 pcall 包裹，任何异常都不会导致 saveInProgress_ 永久锁死
    local ok, err = pcall(function()
        local jsonStr = buildSaveData()
        local file = File("galaxy_save.json", FILE_WRITE)
        if file:IsOpen() then
            file:WriteString(jsonStr)
            file:Close()
        end
    end)
    saveInProgress_ = false   -- 无论成败都清除，防止锁死
    if not ok then
        print("[Save] 存档失败: " .. tostring(err))
    end
end

-- 从存档数据恢复游戏状态
local function restoreGame(jsonStr)
    if not jsonStr or jsonStr == "" then
        print("[Client] 新玩家，使用初始状态")
        return
    end
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or not data then
        print("[Client] 存档解析失败，使用初始状态")
        return
    end
    print("[Client] 恢复存档 v" .. (data.version or 0))

    -- 先恢复星图（会重建行星 buildings），然后恢复资源（保留存档值）
    GalaxyScene.LoadSaveData({ planets = data.planets, base = data.base }, rm_)
    markBaseEffectsDirty()
    applyBaseModuleEffects()   -- 恢复基地模块对 rates/caps 的效果
    rm_:deserialize({ resources = data.resources })
    rs_:deserialize(data.research)
    player_:deserialize(data.player)

    -- 造船队列恢复（需要行星引用）
    local planetLookup = {}
    for _, p in ipairs(GalaxyScene.GetAllPlanets()) do
        planetLookup[p.id] = p
    end
    spq_:deserialize(data.shipQueue, function(id) return planetLookup[id] end)
    fm_:deserialize(data.fleet)

    -- 恢复海盗AI状态
    if pirateAI_ and data.pirate then
        pirateAI_:deserialize(data.pirate)
    end

    -- 恢复教程完成进度（已完成则不再弹窗）
    if data.tutorial then
        GameUI.TutorialDeserialize(data.tutorial)
    end

    -- 恢复成就已解锁列表
    if data.achievements then
        Achievement.SetUnlocked(data.achievements)
    end

    -- 恢复阶段目标进度（防止重复奖励 / 成就计数归零）
    totalShipsBuilt_ = data.totalShipsBuilt or 0
    totalResearch_   = data.totalResearch   or 0
    if type(data.completedGoals) == "table" then
        completedGoals_ = data.completedGoals
    end

    -- H2 修复：读档后重新应用所有殖民行星的类型加成（之前只恢复了基地模块效果）
    reapplyAllPlanetBonuses()

    -- 同步 UI 状态
    if GalaxyScene.IsDeployed() then
        GameUI.SetDeployed(true)
        local base = GalaxyScene.GetBase()
        if base then GameUI.RefreshPlanetPanel(base) end
    end
    GameUI.RefreshTechPanel()
    GameUI.RefreshResourceBar()
    GameUI.Notify("存档已恢复", "success")
end

-- 收到服务器的存档应答
local function handleSaveAck(eventType, eventData)
    saveInProgress_ = false
    local ok  = eventData["Ok"]:GetBool()
    local msg = eventData["Msg"]:GetString()
    if not ok then
        print("[Client] 存档失败: " .. msg)
    end
end

-- 收到服务器返回的存档数据
local function handleLoadData(eventType, eventData)
    local ok      = eventData["Ok"]:GetBool()
    local jsonStr = eventData["Data"]:GetString()
    if ok then
        restoreGame(jsonStr)
    else
        print("[Client] 读档请求失败，使用初始状态")
    end
end

-- ============================================================================
-- 网络连接就绪后初始化
-- ============================================================================
onGameReady = function()
    -- 新游戏流程：跳过读档
    if skipSaveLoad_ then
        skipSaveLoad_ = false
        print("[Client] 新游戏：跳过存档加载")
        return
    end
    -- 继续游戏：从本地文件加载存档
    if fileSystem:FileExists("galaxy_save.json") then
        local file = File("galaxy_save.json", FILE_READ)
        if file:IsOpen() then
            local jsonStr = file:ReadString()
            file:Close()
            restoreGame(jsonStr)
            return
        end
    end
    print("[Client] 无本地存档，新游戏开始")
end

-- ============================================================================
-- 主菜单屏幕
-- ============================================================================

--- 返回主菜单按钮布局 { key, x, y, w, h, label, enabled }
local function getMainMenuBtnLayout(sw, sh)
    local btnW, btnH = 240, 56
    local cx = sw / 2 - btnW / 2
    local baseY = sh * 0.52
    return {
        { key="new",      x=cx, y=baseY,        w=btnW, h=btnH, label="新  游  戏", enabled=true },
        { key="continue", x=cx, y=baseY + 72,   w=btnW, h=btnH, label="继 续 游 戏", enabled=hasSave_ },
    }
end

--- 命中检测：返回命中按钮 key 或 nil
local function getMainMenuHit(mx, my, sw, sh)
    local btns = getMainMenuBtnLayout(sw, sh)
    for _, btn in ipairs(btns) do
        if btn.enabled and mx >= btn.x and mx <= btn.x + btn.w
            and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    return nil
end

--- 绘制主菜单全屏 UI
local function renderMainMenu(sw, sh)
    -- 深空渐变背景
    local bg = nvgLinearGradient(vg_, 0, 0, 0, sh,
        nvgRGBA(4, 8, 24, 255), nvgRGBA(8, 18, 48, 255))
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, sw, sh)
    nvgFillPaint(vg_, bg)
    nvgFill(vg_)

    -- 装饰星点
    math.randomseed(42)
    for _ = 1, 80 do
        local sx = math.random() * sw
        local sy = math.random() * sh * 0.85
        local sr = math.random() * 1.4 + 0.3
        local sa = math.random(120, 220)
        nvgBeginPath(vg_)
        nvgCircle(vg_, sx, sy, sr)
        nvgFillColor(vg_, nvgRGBA(200, 210, 255, sa))
        nvgFill(vg_)
    end

    -- 游戏 Logo 大标题
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    -- 阴影层
    nvgFontSize(vg_, 52)
    nvgFillColor(vg_, nvgRGBA(30, 60, 160, 120))
    nvgText(vg_, sw / 2 + 3, sh * 0.24 + 3, "银河征服")

    -- 主标题
    nvgFontSize(vg_, 52)
    local titleGrad = nvgLinearGradient(vg_, sw/2 - 120, sh*0.19, sw/2 + 120, sh*0.29,
        nvgRGBA(160, 200, 255, 255), nvgRGBA(80, 140, 255, 255))
    nvgBeginPath(vg_)
    nvgRect(vg_, sw/2 - 130, sh*0.18, 260, 80)
    nvgFillPaint(vg_, titleGrad)
    nvgFill(vg_)
    -- NanoVG 文本叠加（无法直接用渐变填充文字，用白色描边代替视觉效果）
    nvgFontSize(vg_, 52)
    nvgFillColor(vg_, nvgRGBA(200, 220, 255, 255))
    nvgText(vg_, sw / 2, sh * 0.24, "银河征服")

    -- 副标题
    nvgFontSize(vg_, 15)
    nvgFillColor(vg_, nvgRGBA(120, 150, 210, 200))
    nvgText(vg_, sw / 2, sh * 0.34, "GALACTIC CONQUEST")

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, sw * 0.30, sh * 0.40)
    nvgLineTo(vg_, sw * 0.70, sh * 0.40)
    nvgStrokeColor(vg_, nvgRGBA(60, 90, 180, 100))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    -- 按钮
    local btns = getMainMenuBtnLayout(sw, sh)
    for _, btn in ipairs(btns) do
        local isHover   = (mainMenuHover_ == btn.key)
        local isEnabled = btn.enabled
        local baseAlpha = isEnabled and 255 or 80

        -- 按钮背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, btn.x, btn.y, btn.w, btn.h, 10)
        if isEnabled then
            local btnBg = nvgLinearGradient(vg_, btn.x, btn.y, btn.x, btn.y + btn.h,
                nvgRGBA(40, 80, 180, isHover and 160 or 90),
                nvgRGBA(20, 50, 140, isHover and 200 or 120))
            nvgFillPaint(vg_, btnBg)
        else
            nvgFillColor(vg_, nvgRGBA(30, 40, 60, 60))
        end
        nvgFill(vg_)

        -- 按钮边框
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, btn.x, btn.y, btn.w, btn.h, 10)
        nvgStrokeColor(vg_, nvgRGBA(80, 130, 255, isHover and 240 or (isEnabled and 160 or 50)))
        nvgStrokeWidth(vg_, isHover and 2.0 or 1.2)
        nvgStroke(vg_)

        -- 悬停光晕
        if isHover and isEnabled then
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, btn.x - 3, btn.y - 3, btn.w + 6, btn.h + 6, 13)
            nvgStrokeColor(vg_, nvgRGBA(100, 160, 255, 60))
            nvgStrokeWidth(vg_, 5)
            nvgStroke(vg_)
        end

        -- 按钮文字
        nvgFontSize(vg_, 20)
        nvgFillColor(vg_, nvgRGBA(200, 220, 255, baseAlpha))
        nvgText(vg_, btn.x + btn.w / 2, btn.y + btn.h / 2, btn.label)
    end

    -- 无存档时的提示
    if not hasSave_ then
        nvgFontSize(vg_, 11)
        nvgFillColor(vg_, nvgRGBA(100, 110, 150, 150))
        nvgText(vg_, sw / 2, sh * 0.52 + 72 + 72, "（暂无存档）")
    end

    -- 底部版权
    nvgFontSize(vg_, 11)
    nvgFillColor(vg_, nvgRGBA(70, 90, 130, 150))
    nvgText(vg_, sw / 2, sh * 0.94, "银河征服 · 点击开始你的星际征途")
end

--- 玩家在主菜单点击按钮
local function onMainMenuSelect(key)
    if key == "new" then
        -- 新游戏：跳过读档，直接进入难度选择
        skipSaveLoad_   = true
        mainMenuActive_ = false
        print("[Client] 主菜单：选择新游戏")
    elseif key == "continue" and hasSave_ then
        -- 继续游戏：直接选择上次难度（默认 normal）并读档
        mainMenuActive_ = false
        print("[Client] 主菜单：选择继续游戏")
        -- 继续游戏直接跳过难度选择，使用默认难度（存档会恢复实际进度）
        difficulty_       = "normal"
        difficultyChosen_ = true
        setupSceneAndUI()
        onGameReady()
        GameUI.Notify("欢迎回来，指挥官！", "info")
    end
end

-- ============================================================================
-- 难度选择屏幕
-- ============================================================================

--- 返回三个按钮的布局参数 { key, x, y, w, h, cfg }
local function getDifficultyBtnLayout(sw, sh)
    local btnW, btnH = 220, 110
    local gap        = 24
    local totalW     = btnW * 3 + gap * 2
    local startX     = (sw - totalW) / 2
    local btnY       = sh * 0.52
    local result     = {}
    for i, key in ipairs(DIFF_ORDER) do
        result[i] = {
            key = key,
            x   = startX + (i - 1) * (btnW + gap),
            y   = btnY,
            w   = btnW,
            h   = btnH,
            cfg = DIFFICULTY_CONFIGS[key],
        }
    end
    return result
end

--- 判断鼠标 (mx,my) 命中哪个按钮，返回 key 或 nil
local function getDifficultyHit(mx, my, sw, sh)
    for _, btn in ipairs(getDifficultyBtnLayout(sw, sh)) do
        if mx >= btn.x and mx <= btn.x + btn.w
        and my >= btn.y and my <= btn.y + btn.h then
            return btn.key
        end
    end
    return nil
end

--- 绘制难度选择全屏 UI
local function renderDifficultyScreen(sw, sh)
    -- 深空背景
    local bg = nvgLinearGradient(vg_, 0, 0, 0, sh,
        nvgRGBA(5, 10, 30, 255), nvgRGBA(10, 20, 50, 255))
    nvgBeginPath(vg_)
    nvgRect(vg_, 0, 0, sw, sh)
    nvgFillPaint(vg_, bg)
    nvgFill(vg_)

    -- 标题
    nvgFontFace(vg_, "sans")
    nvgTextAlign(vg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFontSize(vg_, 38)
    nvgFillColor(vg_, nvgRGBA(200, 220, 255, 255))
    nvgText(vg_, sw / 2, sh * 0.20, "银河征服")
    nvgFontSize(vg_, 18)
    nvgFillColor(vg_, nvgRGBA(140, 160, 200, 200))
    nvgText(vg_, sw / 2, sh * 0.28, "选择难度")

    -- 分隔线
    nvgBeginPath(vg_)
    nvgMoveTo(vg_, sw * 0.25, sh * 0.33)
    nvgLineTo(vg_, sw * 0.75, sh * 0.33)
    nvgStrokeColor(vg_, nvgRGBA(80, 100, 160, 120))
    nvgStrokeWidth(vg_, 1)
    nvgStroke(vg_)

    -- 三个难度按钮
    local btns = getDifficultyBtnLayout(sw, sh)
    for _, btn in ipairs(btns) do
        local cfg     = btn.cfg
        local r, g, b = cfg.color[1], cfg.color[2], cfg.color[3]
        local isHover = (diffHoverBtn_ == btn.key)
        local alpha   = isHover and 220 or 160

        -- 按钮背景
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, btn.x, btn.y, btn.w, btn.h, 12)
        local btnBg = nvgLinearGradient(vg_, btn.x, btn.y, btn.x, btn.y + btn.h,
            nvgRGBA(r, g, b, isHover and 60 or 30),
            nvgRGBA(r, g, b, isHover and 90 or 50))
        nvgFillPaint(vg_, btnBg)
        nvgFill(vg_)

        -- 按钮边框
        nvgBeginPath(vg_)
        nvgRoundedRect(vg_, btn.x, btn.y, btn.w, btn.h, 12)
        nvgStrokeColor(vg_, nvgRGBA(r, g, b, alpha))
        nvgStrokeWidth(vg_, isHover and 2.5 or 1.5)
        nvgStroke(vg_)

        -- 难度标签
        nvgFontSize(vg_, 22)
        nvgFillColor(vg_, nvgRGBA(r, g, b, 255))
        nvgText(vg_, btn.x + btn.w / 2, btn.y + 36, cfg.label)

        -- 描述文字
        nvgFontSize(vg_, 12)
        nvgFillColor(vg_, nvgRGBA(180, 200, 230, 200))
        nvgText(vg_, btn.x + btn.w / 2, btn.y + 70, cfg.desc)

        -- 悬停光晕
        if isHover then
            nvgBeginPath(vg_)
            nvgRoundedRect(vg_, btn.x - 2, btn.y - 2, btn.w + 4, btn.h + 4, 14)
            nvgStrokeColor(vg_, nvgRGBA(r, g, b, 80))
            nvgStrokeWidth(vg_, 4)
            nvgStroke(vg_)
        end
    end

    -- 底部提示
    nvgFontSize(vg_, 13)
    nvgFillColor(vg_, nvgRGBA(100, 120, 160, 180))
    nvgText(vg_, sw / 2, sh * 0.78, "点击选择难度开始游戏")
end

--- 玩家点击选择难度
local function onDifficultySelect(key)
    difficulty_       = key
    difficultyChosen_ = true
    local cfg = DIFFICULTY_CONFIGS[key]
    print(string.format("[Client] 难度已选择: %s (attackFactor=%.1f, maxThreat=%d)",
        cfg.label, cfg.attackFactor, cfg.maxThreat))
    -- 根据难度初始化游戏
    setupSceneAndUI()
    onGameReady()
    GameUI.Notify("难度: " .. cfg.label .. " —— 征服银河！", "info")
end

-- ============================================================================
-- NanoVGRender 主渲染
-- ============================================================================
local function handleNanoVGRender(eventType, eventData)
    local dpr = getDpr()
    screenW_, screenH_ = getScreenSize()
    nvgBeginFrame(vg_, screenW_, screenH_, dpr)

    -- 主菜单（最高优先级）
    if mainMenuActive_ then
        renderMainMenu(screenW_, screenH_)
        nvgEndFrame(vg_)
        return
    end

    -- 难度选择界面（游戏正式开始前全屏覆盖）
    if not difficultyChosen_ then
        renderDifficultyScreen(screenW_, screenH_)
        nvgEndFrame(vg_)
        return
    end

    if currentScene_ == "battle" then
        BattleScene.Render()
    else
        GalaxyScene.Render()
        GameUI.RenderProgressBars(selectedPlanet_)
    end

    GameUI.RenderTopBar()
    GameUI.RenderSceneTitle()
    GameUI.RenderHUD()
    GameUI.RenderNotifications()

    nvgEndFrame(vg_)
end

-- ============================================================================
-- 广告延时：看完广告后执行
-- ============================================================================
---@diagnostic disable-next-line: undefined-global
local sdk_ = sdk  -- 引擎全局 SDK 对象

local function onWatchAdClicked()
    if adWatching_ then return end
    if getAdCount() <= 0 then return end

    adWatching_ = true
    GameUI.Notify("广告加载中，请稍候...", "info")

    sdk_:ShowRewardVideoAd(function(result)
        adWatching_ = false
        if result.success then
            extraTime_ = math.min(MAX_EXTRA, extraTime_ + EXTRA_PER_AD)
            local newAdCount = getAdCount()
            GameUI.UpdateTimeoutAdCount(newAdCount)
            GameUI.Notify(
                "广告观看完成！已延长1小时。剩余可延长次数：" .. newAdCount,
                "success"
            )
            if getRemainingTime() > 0 then
                -- 恢复游戏
                timeoutTriggered_ = false
                GameUI.HideTimeoutScreen()
            end
        else
            GameUI.Notify("广告未完整观看 (" .. (result.msg or "") .. ")，无法获得奖励", "warn")
        end
    end)
end

local function handleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    Audio.Update(dt)

    -- 难度选择界面阶段：跳过游戏逻辑
    if not difficultyChosen_ then return end

    -- ---- 总游戏时长（结算统计用，不受超时暂停影响）----
    if not endGameTriggered_ then
        totalPlayTime_ = totalPlayTime_ + dt
    end

    -- ---- 游戏时间追踪 ----
    if not timeoutTriggered_ then
        playTime_ = playTime_ + dt
        local secRemaining = math.floor(getRemainingTime())
        if secRemaining ~= lastShownRemaining_ then
            lastShownRemaining_ = secRemaining
            GameUI.SetRemainingTime(secRemaining)
        end

        -- 检测超时
        if getRemainingTime() <= 0 then
            timeoutTriggered_ = true
            -- 显示超时覆盖层
            GameUI.ShowTimeoutScreen(getAdCount(), onWatchAdClicked)
            print("[Client] 游戏时间到期")
        end

        -- 剩余30分钟提示
        local remaining = getRemainingTime()
        if remaining <= 1800 and remaining > 1798 then
            GameUI.Notify("在线时间剩余30分钟，观看广告可延长1小时", "warn")
        elseif remaining <= 300 and remaining > 298 then
            GameUI.Notify("警告：在线时间仅剩5分钟！", "error")
        end
    end

    rm_:update(dt)
    ms_:update(dt)

    -- 自动存档（H3 修复：去掉 serverConn_ 判断，单机模式也会自动存档）
    saveTimer_ = saveTimer_ + dt
    if saveTimer_ >= AUTO_SAVE_INTERVAL then
        saveTimer_ = 0
        saveGame()
    end

    local techDone = rs_:update(dt)
    if techDone then
        Audio.Play(Audio.SFX.RESEARCH_COMPLETE)
        totalResearch_ = totalResearch_ + 1
        Achievement.Check("research_complete", { totalResearch = totalResearch_ })
        GameUI.Notify("科技完成: " .. TECHS[techDone].name, "success")
        GameUI.RefreshTechPanel()
        checkStageGoals()   -- 科技完成后检查阶段目标
        saveGame()   -- 科技完成立即存档
    end

    local shipDone = spq_:update(dt)
    if shipDone then
        local st = SHIP_TYPES[shipDone.shipType]
        fm_:addToReserve(shipDone.shipType)
        totalShipsBuilt_ = totalShipsBuilt_ + 1
        Audio.Play(Audio.SFX.BUILD_COMPLETE)
        GalaxyScene.InvalidateFleetColor(activeFleetId_)  -- 储备池变化，主编队颜色可能改变
        GameUI.Notify("舰船建造完成: " .. st.name .. "  → 已进入储备池", "success")
        GameUI.RefreshFleetPanel(fm_, activeFleetId_)
        GameUI.RefreshReservePanel(fm_)
        GameUI.RefreshShipyardPanel()
        checkStageGoals()   -- 造船完成后检查阶段目标
    end

    if currentScene_ == "battle" then
        BattleScene.Update(dt)
    end

    if currentScene_ == "galaxy" then
        GalaxyScene.Update(dt)
        -- 行星建造队列更新（仅遍历已殖民行星，跳过全量扫描）
        for _, p in ipairs(GalaxyScene.GetColonizedPlanets()) do
            local done = bs_:update(dt, p)
            if done then
                Audio.Play(Audio.SFX.BUILD_COMPLETE)
                GameUI.Notify("建造完成: " .. BUILDINGS[done].name, "success")
                GameUI.RefreshPlanetPanel(GalaxyScene.GetSelected())
                if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                saveGame()   -- 建造完成立即存档
            end
        end
        -- 基地模块建造队列更新（独立系统）
        local base = GalaxyScene.GetBase()
        if base and base.colonized then
            local done = bbs_:update(dt, base)
            if done then
                if done == "__CORE_UPGRADE__" then
                    -- 核心等级升级完成（base.coreLevel 已在 update 内写入新值）
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local newLv = base.coreLevel or 1
                    local unlocked = BASE_CORE_UNLOCK_PREVIEW[newLv] or {}
                    local names = {}
                    for _, k in ipairs(unlocked) do
                        names[#names+1] = BASE_MODULES[k] and BASE_MODULES[k].name or k
                    end
                    local unlockStr = #names > 0 and ("解锁: " .. table.concat(names, " / ")) or ""
                    -- Lv.2 额外提示：解锁原矿精炼能力（矿石/能量块/水晶 → 精炼资源）
                    if newLv == 2 then
                        unlockStr = unlockStr .. "  ＋基础精炼能力（0.3×）"
                    end
                    GameUI.Notify("★ 核心升级完成！已达 Lv." .. newLv
                        .. (#unlockStr > 0 and "  " .. unlockStr or ""), "success")
                    markBaseEffectsDirty()
                    applyBaseModuleEffects()   -- 核心升级后重算模块效果（含编队上限）
                    checkStageGoals()          -- 核心升级后检查阶段目标
                    saveGame()
                else
                    Audio.Play(Audio.SFX.BUILD_COMPLETE)
                    local modName = BASE_MODULES[done] and BASE_MODULES[done].name or done
                    GameUI.Notify("模块安装完成: " .. modName, "success")
                    if done == "SHIPYARD" then GameUI.SetShipyardBuilt(true) end
                    markBaseEffectsDirty()
                    applyBaseModuleEffects()   -- 应用新模块效果
                    checkStageGoals()          -- 模块完成后检查阶段目标
                    saveGame()   -- 基地模块完成立即存档
                end
            end
            local sel = GalaxyScene.GetSelected()
            if sel and sel.isBase then
                GameUI.RefreshPlanetPanel(base)
            end
        end
    end

    GameUI.UpdateNotifications(dt)

    -- 海盗进攻预警：每帧更新最近倒计时
    if pirateAI_ then
        local minT = math.huge
        for _, b in ipairs(pirateAI_.bases) do
            if b.active and b.attackTimer and b.attackTimer < minT then
                minT = b.attackTimer
            end
        end
        GameUI.SetPirateWarning(minT)
        -- 首次进入预警阈值时播放音效
        if minT <= 30 and not pirateWarnPlayed_ then
            pirateWarnPlayed_ = true
            Audio.Play(Audio.SFX.PIRATE_WARNING)
        elseif minT > 30 then
            pirateWarnPlayed_ = false  -- 威胁解除后重置，下次可再次触发
        end
    end

    refreshTimer_ = refreshTimer_ + dt
    if refreshTimer_ >= 0.5 then
        refreshTimer_ = 0
        GameUI.RefreshResourceBar()
        local sel = GalaxyScene.GetSelected()
        if sel and currentScene_ == "galaxy" then
            GameUI.RefreshPlanetPanel(sel)
        end
    end
end

-- ============================================================================
-- 输入处理
-- ============================================================================
local function handleMouseButtonDown(eventType, eventData)
    if mainMenuActive_ then return end
    if not difficultyChosen_ then return end
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr
    local my  = eventData["Y"]:GetInt() / dpr
    if currentScene_ == "galaxy" then GalaxyScene.OnMouseDown(mx, my) end
end

local function handleMouseButtonUp(eventType, eventData)
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr
    local my  = eventData["Y"]:GetInt() / dpr
    -- 主菜单点击
    if mainMenuActive_ then
        local hit = getMainMenuHit(mx, my, screenW_, screenH_)
        if hit then onMainMenuSelect(hit) end
        return
    end
    -- 难度选择屏幕点击
    if not difficultyChosen_ then
        local hit = getDifficultyHit(mx, my, screenW_, screenH_)
        if hit then onDifficultySelect(hit) end
        return
    end
    if GameUI.OnClick(mx, my) then return end
    GalaxyScene.OnMouseUp(mx, my)
end

local function handleMouseMove(eventType, eventData)
    local dpr = getDpr()
    local mx  = eventData["X"]:GetInt() / dpr
    local my  = eventData["Y"]:GetInt() / dpr
    -- 主菜单悬停
    if mainMenuActive_ then
        mainMenuHover_ = getMainMenuHit(mx, my, screenW_, screenH_)
        return
    end
    -- 难度选择屏幕悬停
    if not difficultyChosen_ then
        diffHoverBtn_ = getDifficultyHit(mx, my, screenW_, screenH_)
        return
    end
    if currentScene_ == "galaxy" then GalaxyScene.OnMouseMove(mx, my) end
end

local function handleMouseWheel(eventType, eventData)
    if not difficultyChosen_ then return end
    if currentScene_ ~= "galaxy" then return end
    local dpr   = getDpr()
    local wheel = eventData["Wheel"]:GetInt()
    local pos   = input:GetMousePosition()
    local mx    = pos.x / dpr
    local my    = pos.y / dpr
    if GameUI.OnScroll(mx, my, wheel) then return end
    GalaxyScene.OnMouseWheel(mx, my, wheel)
end

local function handleKeyDown(eventType, eventData)
    if not difficultyChosen_ then return end
    local key = eventData["Key"]:GetInt()
    -- 飞船展开前：WASD/方向键/空格键全部转发给 GalaxyScene
    if currentScene_ == "galaxy" and not GalaxyScene.IsDeployed() then
        GalaxyScene.OnKeyDown(key)
        return  -- 展开前不响应场景切换等快捷键
    end
    if key == KEY_ESCAPE and explorerColonizeMode_ then
        explorerColonizeMode_ = false
        GameUI.SetExplorerColonizeMode(false)
        GameUI.Notify("已取消探索模式", "info")
        return
    end

end

local function handleKeyUp(eventType, eventData)
    if not difficultyChosen_ then return end
    local key = eventData["Key"]:GetInt()
    GalaxyScene.OnKeyUp(key)
end

-- ============================================================================
-- 场景与UI初始化（供 Start 和 softReset 复用）
-- ============================================================================
setupSceneAndUI = function()
    -- 读取当前难度配置
    local diffCfg = DIFFICULTY_CONFIGS[difficulty_] or DIFFICULTY_CONFIGS["normal"]

    -- 初始化海盗 AI（generateBases 由 GalaxyScene.Init 内部调用）
    pirateAI_ = PirateAI.new({
        notifyFn           = GameUI.Notify,
        onAttack           = onPirateAttack,
        getTargets         = getPlayerTargets,
        attackIntervalFactor = diffCfg.attackFactor,
        maxThreatLevel       = diffCfg.maxThreat,
        getProgress = function()
            local colonized = 0
            local planets = GalaxyScene.GetColonizedPlanets and GalaxyScene.GetColonizedPlanets() or {}
            for _, p in ipairs(planets) do
                if p.colonized then colonized = colonized + 1 end
            end
            return {
                colonized     = colonized,
                gameTime      = playTime_,
                piratesKilled = piratesKilled_,
            }
        end,
    })

    -- 初始化游戏场景
    GalaxyScene.Init({
        vg             = vg_,
        bs             = bs_,
        rm             = rm_,
        fm             = fm_,
        player         = player_,
        notifyFn       = GameUI.Notify,
        onPlanetSelect = onPlanetSelect,
        onFleetSelect  = function(fleetId)
            -- 地图上点击编队图标：同步到 UI 面板选中状态（含地图选中橙色高亮）
            activeFleetId_ = fleetId  -- nil 也允许（取消选中）
            GameUI.RefreshFleetPanel(fm_, fleetId)
            GameUI.SetMapSelectedFleet(fleetId)  -- 更新 tab 橙色高亮
        end,
        onFleetContactPlanet = function(fleetId, planet)
            -- 含探索舰的编队到达未殖民行星 → 进入殖民选择模式
            if not fleetHasExplorer(fleetId) then return end
            if planet.colonized then return end
            -- 自动选中该行星并触发殖民
            selectedPlanet_ = planet
            GameUI.RefreshPlanetPanel(planet)
            local ok = doColonize(planet)
            if ok then
                -- 消耗编队中一艘探索舰
                fm_:removeShip(fleetId, "EXPLORER")
                GameUI.RefreshFleetPanel(fm_, fleetId)
            else
                GameUI.Notify("编队抵达 " .. planet.name .. " — 点击面板探索或继续前进", "info")
            end
        end,
        onSeedDeploy   = function(wx, wy, base)
            Audio.Play(Audio.SFX.FLEET_DEPLOY)
            -- 飞船展开完成：解锁全部 UI 面板
            GameUI.SetDeployed(true)
            -- 选中基地，显示模块建造面板（base.colonized 已由 GalaxyScene 设为 true）
            selectedPlanet_ = base
            GameUI.ShowScene("galaxy", true)
            GameUI.RefreshPlanetPanel(base)
            -- 新玩家首次展开基地：赠予 4 艘工程舰（储备池为空时视为新玩家）
            local totalReserve = 0
            if fm_.reserve then
                for _, n in pairs(fm_.reserve) do totalReserve = totalReserve + n end
            end
            if totalReserve == 0 then
                for i = 1, 4 do fm_:addToReserve("ENGINEER") end
                GameUI.RefreshReservePanel(fm_)
                GameUI.Notify("星航基地已建立！获得 4 艘工程舰，可在右侧面板建造功能模块", "success")
            else
                GameUI.Notify("星航基地已建立！可在右侧面板建造功能模块", "success")
            end
        end,
        pirateAI = pirateAI_,
        onFleetContactPirateBase = onFleetSiegeBase,
        onFleetMove = function() Audio.Play(Audio.SFX.FLEET_MOVE) end,
    })
    rs_:setPlanetGetter(GalaxyScene.GetAllPlanets)
    GameUI.Init({
        vg              = vg_,
        rm              = rm_,
        bs              = bs_,
        bbs             = bbs_,
        rs              = rs_,
        ms              = ms_,
        player          = player_,
        spq             = spq_,
        fm              = fm_,
        onBuildCb       = onBuildCb,
        onBaseBuildCb   = onBaseBuildCb,
        onCoreUpgradeCb = onCoreUpgradeCb,
        onResearchCb    = onResearchCb,
        onMarketCb      = onMarketCb,
        onExchangeCb    = function(fromRes, toRes)
            local ok, result = rm_:exchange(fromRes, toRes)
            if ok then
                local fromLabel = RES_LABELS[fromRes]
                local toLabel   = RES_LABELS[toRes]
                GameUI.Notify(fromLabel .. " -" .. EXCHANGE_AMOUNT ..
                    "  →  " .. toLabel .. " +" .. result, "success")
            else
                GameUI.Notify("互换失败: " .. (result or ""), "error")
            end
        end,
        onShipQueueCb          = onShipQueueCb,
        onExplorerColonizeCb   = onExplorerColonizeCb,
        onFleetSelectCb = function(selectedFid)
            activeFleetId_ = selectedFid
            GameUI.RefreshFleetPanel(fm_, selectedFid)
            -- 同步地图上的编队选中状态，使点击地图空地可直接移动该编队
            GalaxyScene.SelectFleet(selectedFid)
        end,
        onFleetMoveShipCb = function(srcId, dstId, shipType)
            local ok, reason = fm_:moveShip(srcId, dstId, shipType)
            if ok then
                GalaxyScene.InvalidateFleetColor(srcId)   -- 舰船移出，源编队颜色可能改变
                GalaxyScene.InvalidateFleetColor(dstId)   -- 舰船移入，目标编队颜色可能改变
                GameUI.Notify("已将 " .. SHIP_TYPES[shipType].name ..
                    " 从编队" .. srcId .. " 移入编队" .. dstId, "success")
                GameUI.RefreshFleetPanel(fm_, activeFleetId_)
            else
                GameUI.Notify("移动失败: " .. (reason or ""), "error")
            end
        end,
        onAssignReserveCb = function(shipType)
            local ok, reason = fm_:assignFromReserve(shipType, activeFleetId_)
            if ok then
                GalaxyScene.InvalidateFleetColor(activeFleetId_)  -- 舰船加入编队，颜色可能改变
                GameUI.Notify(SHIP_TYPES[shipType].name .. " 已加入编队 " .. activeFleetId_, "success")
                GameUI.RefreshFleetPanel(fm_, activeFleetId_)
                GameUI.RefreshReservePanel(fm_)
            else
                GameUI.Notify("加入编队失败: " .. (reason or ""), "warn")
            end
        end,
        -- 星币加速建造：M6 修复：1★/10秒，上限50★，最少5★
        onSpeedUpBuildCb = function(target)
            -- target 是 planet 或 base 对象
            if not target or not target.constructing then
                GameUI.Notify("当前没有建造中的项目", "warn"); return
            end
            local remaining = target.constructing.remaining or 0
            if remaining <= 0 then GameUI.Notify("已接近完成", "info"); return end
            local cost = math.max(5, math.min(50, math.ceil(remaining / 10)))  -- 1★/10s，上限50★
            if not rm_:canAfford({ credits = cost }) then
                GameUI.Notify("星币不足（需要 ★" .. cost .. "）", "error"); return
            end
            rm_:spend({ credits = cost })
            target.constructing.remaining = 0
            target.constructing.progress  = 1.0
            GameUI.Notify("★ 使用 " .. cost .. " 星币立即完成建造！", "success")
            GameUI.RefreshPlanetPanel(target)
        end,
        -- 星币购买核能（市场快速入口）
        onBuyNuclearCb = function(amount)
            local pricePerUnit = (ms_ and ms_.rates and ms_.rates.nuclear and ms_.rates.nuclear.buy) or 10.0
            local totalCost = math.ceil(amount * pricePerUnit)
            if not rm_:canAfford({ credits = totalCost }) then
                GameUI.Notify("星币不足（需要 ★" .. totalCost .. "）", "error"); return
            end
            rm_:spend({ credits = totalCost })
            rm_:add("nuclear", amount)
            GameUI.Notify("购买核能×" .. amount .. "  消耗 ★" .. totalCost, "success")
            GameUI.RefreshResourceBar()
        end,
        getConquestProgress = function()
            local allPlanets    = GalaxyScene.GetAllPlanets()
            local colonized     = GalaxyScene.GetColonizedPlanets()
            local total         = allPlanets and #allPlanets or 0
            local colCount      = colonized  and #colonized  or 0
            local piratesTotal  = 0
            local piratesKilled = 0
            if pirateAI_ and pirateAI_.bases then
                for _, b in ipairs(pirateAI_.bases) do
                    piratesTotal = piratesTotal + 1
                    if not b.active then piratesKilled = piratesKilled + 1 end
                end
            end
            -- 计算当前海盗最高威胁等级（供 HUD 显示）
            local maxThreat = 0
            if pirateAI_ and pirateAI_.bases then
                for _, b in ipairs(pirateAI_.bases) do
                    if b.active and b.level > maxThreat then
                        maxThreat = b.level
                    end
                end
            end
            return {
                colonized     = colCount,
                total         = total,
                piratesKilled = piratesKilled,
                piratesTotal  = piratesTotal,
                pirateThreat  = maxThreat,
            }
        end,
        onShowLeaderboard = function(callback)
            -- 并行拉取：排行榜列表 + 本人排名
            local rankList   = nil
            local myRank     = nil
            local myScore    = nil
            local nicksReady = false
            local rankReady  = false

            local function tryAssemble()
                if not (nicksReady and rankReady) then return end
                callback(rankList, myRank, myScore)
            end

            -- 1. 拉取排行榜（附带 galaxy_colonized / galaxy_kills 扩展字段）
            clientCloud:GetRankList("galaxy_score", 0, 10, {
                ok = function(_, rows)
                    -- rows: { {userId, iscores={galaxy_score=N, galaxy_colonized=N, galaxy_kills=N}}, ... }
                    local userIds = {}
                    for _, row in ipairs(rows) do
                        table.insert(userIds, row.userId)
                    end
                    -- 2. 批量拉取昵称
                    GetUserNickname({
                        userIds   = userIds,
                        onSuccess = function(nickMap)
                            rankList = {}
                            for rank, row in ipairs(rows) do
                                table.insert(rankList, {
                                    rank      = rank,
                                    userId    = row.userId,
                                    name      = nickMap[tostring(row.userId)] or ("玩家" .. tostring(row.userId):sub(-4)),
                                    score     = (row.iscores and row.iscores.galaxy_score)     or 0,
                                    colonized = (row.iscores and row.iscores.galaxy_colonized) or 0,
                                    kills     = (row.iscores and row.iscores.galaxy_kills)     or 0,
                                })
                            end
                            nicksReady = true
                            tryAssemble()
                        end,
                        onError = function()
                            -- 昵称获取失败，用占位名继续
                            rankList = {}
                            for rank, row in ipairs(rows) do
                                table.insert(rankList, {
                                    rank      = rank,
                                    userId    = row.userId,
                                    name      = "玩家" .. tostring(row.userId):sub(-4),
                                    score     = (row.iscores and row.iscores.galaxy_score)     or 0,
                                    colonized = (row.iscores and row.iscores.galaxy_colonized) or 0,
                                    kills     = (row.iscores and row.iscores.galaxy_kills)     or 0,
                                })
                            end
                            nicksReady = true
                            tryAssemble()
                        end,
                    })
                end,
                error = function()
                    rankList   = {}
                    nicksReady = true
                    tryAssemble()
                end,
                timeout = function()
                    rankList   = {}
                    nicksReady = true
                    tryAssemble()
                end,
            }, "galaxy_colonized", "galaxy_kills")

            -- 3. 拉取本人排名（独立请求，与上面并行）
            local selfId = clientCloud.userId
            if selfId then
                clientCloud:GetUserRank(selfId, "galaxy_score", {
                    ok = function(_, rankInfo)
                        myRank  = rankInfo and rankInfo.rank
                        myScore = rankInfo and rankInfo.score
                        rankReady = true
                        tryAssemble()
                    end,
                    error = function()
                        rankReady = true
                        tryAssemble()
                    end,
                    timeout = function()
                        rankReady = true
                        tryAssemble()
                    end,
                })
            else
                rankReady = true
            end
        end,
    })

    GameUI.ShowScene("galaxy", false)

    -- 注入"在此展开基地"按钮回调：等价于玩家按下空格键
    GameUI.SetDeployCallback(function()
        if not GalaxyScene.IsDeployed() then
            GalaxyScene.OnKeyDown(KEY_SPACE)
        end
    end)

    -- 触发新手引导（start 阶段；若已完成教程则静默跳过）
    GameUI.TutorialTriggerStart()

    -- 初始化成就系统：跨局保留已解锁成就；云存档读档后由 SetUnlocked 覆盖
    Achievement.Init({
        notifyFn = GameUI.Notify,
        unlocked = savedAchievements_,   -- nil = 全新游戏；非 nil = 再来一局时恢复
        onUnlock = function(id, list)
            -- 成就解锁时同步到云端（忽略网络错误，不影响游戏流程）
            local cjson = require("cjson")
            local ok, jsonStr = pcall(cjson.encode, list)
            if not ok then return end
            clientCloud:SetString("galaxy_achievements", jsonStr, function(success)
                if success then
                    print("[Achievement] 云端同步成功: " .. id)
                else
                    print("[Achievement] 云端同步失败（已忽略）: " .. id)
                end
            end)
        end,
    })
    savedAchievements_ = nil   -- 消费后清空，避免影响后续流程

    -- 启动星系探索 BGM
    Audio.PlayBGM(Audio.BGM.GALAXY_MAIN, 2.0)
end

-- ============================================================================
-- 软重启（再来一局）
-- ============================================================================
--- 重置所有游戏系统，重新开始一局（不销毁 vg_/scene_ 等引擎资源）
softReset = function()
    print("[Client] softReset: 开始软重启...")

    -- 0. 保存已解锁成就（跨局保留，不随新局重置）
    savedAchievements_ = Achievement.GetUnlocked()
    print("[Client] softReset: 保存成就 " .. #savedAchievements_ .. " 条")

    -- 1. 关闭旧 UI（释放 UI 树，但保留 vg_）
    GameUI.Shutdown()

    -- 2. 关闭旧场景（释放地图/舰队数据，但保留 vg_）
    if GalaxyScene.Shutdown then GalaxyScene.Shutdown() end

    -- 3. 重建所有游戏系统实例
    rm_      = Sys.ResourceManager.new()
    -- 按难度调整初始资源
    local diffInitRes = (DIFFICULTY_CONFIGS[difficulty_] or {}).initRes
    if diffInitRes then
        for res, delta in pairs(diffInitRes) do
            local cur = rm_.resources[res] or 0
            rm_.resources[res] = math.max(0, cur + delta)
        end
        print(string.format("[Client] 难度 %s 初始资源已调整", difficulty_))
    end
    bs_      = Sys.BuildingSystem.new(rm_)
    bbs_     = Sys.BaseBuildingSystem.new(rm_)
    rs_      = Sys.ResearchSystem.new(rm_, bs_)
    ms_      = Sys.MarketSystem.new(rm_)
    player_  = Sys.PlayerProfile.new()
    spq_     = Sys.ShipProductionQueue.new(rm_)
    fm_      = Sys.FleetManager.new()

    -- 4. 重置游戏状态变量
    currentScene_         = "galaxy"
    selectedPlanet_       = nil
    activeFleetId_        = 1
    explorerColonizeMode_ = false
    refreshTimer_         = 0
    lastShownRemaining_   = -1
    baseEffectsDirty_     = true
    endGameTriggered_     = false
    piratesKilled_        = 0
    totalResearch_        = 0
    pirateAttackInfo_     = nil
    pirateWarnPlayed_     = false
    playTime_             = 0
    totalPlayTime_        = 0
    extraTime_            = 0
    timeoutTriggered_     = false
    saveTimer_            = 0
    saveInProgress_       = false

    -- 5. 返回主菜单（刷新存档状态，让玩家重新选择）
    difficultyChosen_ = false
    diffHoverBtn_     = nil
    mainMenuActive_   = true
    mainMenuHover_    = nil
    hasSave_          = fileSystem:FileExists("galaxy_save.json")
    print("[Client] softReset: 完成，返回主菜单")
end

-- ============================================================================
-- Start / Stop
-- ============================================================================
function Client.Start()
    print("=== Galactic Conquest Client Start ===")

    -- 初始化 NanoVG 渲染上下文（整个生命周期只创建一次）
    vg_      = nvgCreate(1)
    screenW_ = graphics:GetWidth()  / graphics:GetDPR()
    screenH_ = graphics:GetHeight() / graphics:GetDPR()

    -- 初始化音频（需要 Scene 节点挂载 SoundSource）
    scene_   = Scene()
    Audio.Init(scene_)

    -- 检测本地存档（决定主菜单是否显示"继续游戏"）
    hasSave_ = fileSystem:FileExists("galaxy_save.json")
    print("[Client] 存档状态: " .. (hasSave_ and "有存档" or "无存档"))

    -- 创建 NanoVG 字体（主菜单/难度屏幕/游戏 UI 共用）
    nvgCreateFont(vg_, "sans", "Fonts/MiSans-Regular.ttf")

    -- 订阅引擎事件（只注册一次，softReset 不重复注册）
    -- 注意：setupSceneAndUI 由玩家在难度选择屏幕点击后由 onDifficultySelect 调用
    SubscribeToEvent("NanoVGRender",    handleNanoVGRender)
    SubscribeToEvent("Update",          handleUpdate)
    SubscribeToEvent("MouseButtonDown", handleMouseButtonDown)
    SubscribeToEvent("MouseButtonUp",   handleMouseButtonUp)
    SubscribeToEvent("MouseMove",       handleMouseMove)
    SubscribeToEvent("MouseWheel",      handleMouseWheel)
    SubscribeToEvent("KeyDown",         handleKeyDown)
    SubscribeToEvent("KeyUp",           handleKeyUp)

    -- 触摸事件（移动端双指缩放 + 单指拖拽）
    SubscribeToEvent("TouchBegin", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        local tx  = ed["X"]:GetInt()
        local ty  = ed["Y"]:GetInt()
        if GameUI.OnTouchBegin(tid, tx, ty) then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchBegin(tid, tx, ty)
    end)
    SubscribeToEvent("TouchMove", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        local tx  = ed["X"]:GetInt()
        local ty  = ed["Y"]:GetInt()
        if GameUI.OnTouchMove(tid, tx, ty) then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchMove(tid, tx, ty)
    end)
    SubscribeToEvent("TouchEnd", function(_, ed)
        local tid = ed["TouchID"]:GetInt()
        local tx  = ed["X"]:GetInt()
        local ty  = ed["Y"]:GetInt()
        if GameUI.OnTouchEnd(tid, tx, ty) then return end
        if currentScene_ ~= "galaxy" then return end
        GalaxyScene.OnTouchEnd(tid, tx, ty)
    end)

    -- 游戏就绪（等待玩家在难度选择界面点击后正式开始）
    print("=== 就绪 | 等待难度选择... ===")
end

function Client.Stop()
    GameUI.Shutdown()
    if vg_ then nvgDelete(vg_); vg_ = nil end
    print("=== Galactic Conquest Client Stop ===")
end

return Client
