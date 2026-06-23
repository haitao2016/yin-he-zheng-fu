---@diagnostic disable: assign-type-mismatch, return-type-mismatch
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
local drawComboHUD          = RenderHUD.drawComboHUD
local drawShipInfoPanel     = RenderHUD.drawShipInfoPanel
local drawFocusRing         = RenderHUD.drawFocusRing
local drawFocusHUD          = RenderHUD.drawFocusHUD
local drawFormationBar      = RenderHUD.drawFormationBar
local drawRetreatReinforce  = RenderHUD.drawRetreatReinforce
local drawSkillUpgrade      = RenderHUD.drawSkillUpgrade

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
    BS.BattleSkills.Draw({ vg = BS.vg, state = BS.state, rs = BS.rs, screenW = BS.screenW, screenH = BS.screenH })
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
end

return BattleRender
