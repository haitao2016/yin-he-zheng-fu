---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- BattleRender.lua — 薄包装器
-- 加载 4 层渲染子模块，组装 Render() 入口
-- 拆分后仅做调度，所有绘制逻辑已迁移至 Render*.lua
-- ============================================================================

local BS              = require("game.battle.BattleState")
local RenderEnv       = require("game.battle.RenderEnv")
local RenderEntities  = require("game.battle.RenderEntities")
local RenderHUD       = require("game.battle.RenderHUD")
local RenderOverlays  = require("game.battle.RenderOverlays")

local BattleRender = {}

-- 快捷局部引用（避免每帧查表）
local drawGrid              = RenderEnv.drawGrid
local drawBgStars           = RenderEnv.drawBgStars
local drawEnvParticles      = RenderEnv.drawEnvParticles
local drawEnvHUD            = RenderEnv.drawEnvHUD
local drawEnvAnnounce       = RenderEnv.drawEnvAnnounce

local drawShip              = RenderEntities.drawShip
local drawProjectile        = RenderEntities.drawProjectile
local drawFloatTexts        = RenderEntities.drawFloatTexts
local drawMoveTarget        = RenderEntities.drawMoveTarget
local drawFireParticles     = RenderEntities.drawFireParticles
local drawExplParticles     = RenderEntities.drawExplParticles
local drawHitSparks         = RenderEntities.drawHitSparks
local drawShockRings        = RenderEntities.drawShockRings

local drawWaveHUD           = RenderHUD.drawWaveHUD
local drawBossPhaseBanner   = RenderHUD.drawBossPhaseBanner
local drawSuperBossHealthBar = RenderHUD.drawSuperBossHealthBar
local drawComboHUD          = RenderHUD.drawComboHUD
local drawShipInfoPanel     = RenderHUD.drawShipInfoPanel
local drawFocusRing         = RenderHUD.drawFocusRing
local drawFocusHUD          = RenderHUD.drawFocusHUD
local drawFormationBar      = RenderHUD.drawFormationBar
local drawRetreatReinforce  = RenderHUD.drawRetreatReinforce
local drawSkillUpgrade      = RenderHUD.drawSkillUpgrade
local drawSpeedControl      = RenderHUD.drawSpeedControl
local drawPauseScreen       = RenderHUD.drawPauseScreen  -- P1-10: 暂停界面
local drawCommandBar       = RenderHUD.drawCommandBar   -- P1-P2-1: 战斗指令按钮

local drawBossDestroyedEffect  = RenderOverlays.drawBossDestroyedEffect
local drawFireworks            = RenderOverlays.drawFireworks
local drawMilestoneBanner      = RenderOverlays.drawMilestoneBanner
local drawBossWarning          = RenderOverlays.drawBossWarning
local drawPincerBanner         = RenderOverlays.drawPincerBanner
local drawNemesisOverlay       = RenderOverlays.drawNemesisOverlay
local drawAnomalyBanner        = RenderOverlays.drawAnomalyBanner
local drawAnomalyHUD          = RenderOverlays.drawAnomalyHUD
local drawReinforcementWarning = RenderOverlays.drawReinforcementWarning
local drawWaveSummary          = RenderOverlays.drawWaveSummary
local drawStateOverlay         = RenderOverlays.drawStateOverlay

-- ============================================================================
-- 公开渲染入口
-- ============================================================================

--- BattleRender.Render() — 在 NanoVGRender 事件中由外部调用
function BattleRender.Render()
    local shaking = BS.SK.offX ~= 0 or BS.SK.offY ~= 0
    if shaking then
        nvgSave(BS.vg)
        nvgTranslate(BS.vg, BS.SK.offX, BS.SK.offY)
    end

    drawGrid()
    drawBgStars()
    drawEnvParticles()
    for _, p in ipairs(BS.projectiles) do drawProjectile(p) end
    drawFireParticles()
    drawExplParticles()
    drawShockRings()
    for _, s in ipairs(BS.playerFleet) do drawShip(s) end
    for _, s in ipairs(BS.enemyFleet)  do drawShip(s) end
    drawHitSparks()
    drawMoveTarget()
    drawFloatTexts()

    if shaking then nvgRestore(BS.vg) end

    drawWaveHUD()
    drawEnvHUD()
    drawAnomalyHUD()
    drawEnvAnnounce()
    drawAnomalyBanner()
    drawFocusRing()
    drawShipInfoPanel()
    drawFocusHUD()
    drawComboHUD()
    drawFormationBar()
    drawRetreatReinforce()
    drawSpeedControl()
    drawCommandBar()  -- P1-P2-1: 战斗指令按钮
    BS.BattleSkills.Draw({ vg = BS.vg, state = BS.state, rs = BS.rs, screenW = BS.screenW, screenH = BS.screenH })
    drawBossPhaseBanner()
    drawSuperBossHealthBar()
    drawBossWarning()
    drawPincerBanner()
    drawNemesisOverlay()
    drawReinforcementWarning()
    drawBossDestroyedEffect()
    drawMilestoneBanner()
    drawFireworks()
    drawStateOverlay()
    drawWaveSummary()
    drawSkillUpgrade()
    drawPauseScreen()  -- P1-10: 暂停界面（最上层）
end

---@param shipList table
---@param batchSize number
---@return number
function BattleRender.batchDrawShips(shipList, batchSize)
    if not shipList then return 0 end
    local n = #shipList
    if n <= 0 then return 0 end
    local bs = batchSize or 16
    if bs <= 0 then bs = 16 end

    local drawn = 0
    local batchCount = 0
    for i = 1, n, bs do
        local j = math.min(i + bs - 1, n)
        if j >= i then
            nvgSave(BS.vg)
            for k = i, j do
                local s = shipList[k]
                if s then
                    drawShip(s)
                    drawn = drawn + 1
                end
            end
            nvgRestore(BS.vg)
            batchCount = batchCount + 1
        end
    end

    _renderStats = _renderStats or {}
    _renderStats.drawnShips = (_renderStats.drawnShips or 0) + drawn
    _renderStats.batchCount = (_renderStats.batchCount or 0) + batchCount
    return drawn
end

---@param particles table
---@param cullDistance number
---@return number
function BattleRender.optimizeParticleDraw(particles, cullDistance)
    if not particles then return 0 end
    local n = #particles
    if n <= 0 then return 0 end
    local cd = cullDistance or 600
    local cx = (BS.screenW or 0) / 2
    local cy = (BS.screenH or 0) / 2

    local groups = {}
    local drawn = 0
    local culled = 0

    for _, p in ipairs(particles) do
        if p then
            local px = p.x or 0
            local py = p.y or 0
            local dx = px - cx
            local dy = py - cy
            local distSq = dx * dx + dy * dy
            if distSq > cd * cd then
                culled = culled + 1
            else
                local tex = p.texture or "__default"
                if not groups[tex] then groups[tex] = {} end
                table.insert(groups[tex], p)
            end
        end
    end

    for tex, group in pairs(groups) do
        nvgSave(BS.vg)
        for _, p in ipairs(group) do
            local func = p.draw or drawFireParticles or nil
            if type(func) == "function" then
                func(p)
            end
            drawn = drawn + 1
        end
        nvgRestore(BS.vg)
    end

    _renderStats = _renderStats or {}
    _renderStats.drawnParticles = (_renderStats.drawnParticles or 0) + drawn
    _renderStats.culledParticles = (_renderStats.culledParticles or 0) + culled
    return drawn
end

---@return table
function BattleRender.getRenderStats()
    _renderStats = _renderStats or {}
    return {
        drawnShips = _renderStats.drawnShips or 0,
        drawnParticles = _renderStats.drawnParticles or 0,
        batchCount = _renderStats.batchCount or 0,
        culledParticles = _renderStats.culledParticles or 0,
    }
end

return BattleRender
