------------------------------------------------------------
-- galaxy/GalaxyRender.lua — 银河场景渲染薄调度器
-- 按正确 Z-order 调用所有渲染子模块，不含任何绘制逻辑。
------------------------------------------------------------
local GS           = require("game.galaxy.GalaxyState")
local Starmap      = require("game.galaxy.RenderStarmap")
local Fleets       = require("game.galaxy.RenderFleets")
local HUD          = require("game.galaxy.RenderHUD")
local StarWeather  = require("game.StarWeather")
local GalaxyEvents = require("game.GalaxyEvents")

local M = {}

--- 主渲染入口，由 GalaxyScene 在 NanoVGRender 事件中调用。
function M.Draw()
    -- 初始化未完成时跳过
    if not GS.bgStars or #GS.bgStars == 0 then return end

    -------------------------------------------------------
    -- Layer 1: 背景（星空 + 天气 + 威胁热力图）
    -------------------------------------------------------
    Starmap.drawBackground()
    StarWeather.Render(GS.vg, GS.screenW, GS.screenH, GS.totalTime, GS.camera, GS.zoom)
    Starmap.drawPirateThreatHeatmap()

    -------------------------------------------------------
    -- Layer 2: 世界空间物体（小行星 → 深空 → 星系 → 航线）
    -------------------------------------------------------
    Fleets.drawAsteroids()

    -- 深空星系（渲染在普通星系之前，避免遮挡）
    for _, sys in ipairs(GS.deepSpaceSystems) do
        Starmap.drawDeepSpaceSystem(sys, GS.deepSpaceAnimT)
    end
    for _, sys in ipairs(GS.starSystems) do
        Starmap.drawStarSystem(sys)
    end

    -- 星际航线网络（需 _sx/_sy 已由 drawStarSystem 缓存）
    if GS.zoom >= 0.6 then
        Starmap.drawTradeRoutes()
    end

    -- 派系关系弧线
    Starmap.drawDiploRelLines()
    -- 远征路径动画
    Starmap.drawExpeditionPaths()

    -------------------------------------------------------
    -- Layer 3: 动态实体（涟漪 → 编队 → 海盗 → 种子船）
    -------------------------------------------------------
    Starmap.drawColonyRipples()
    Fleets.drawFleets()

    -- 海盗基地和舰队（pirateAI 有自己的 :render 方法）
    if GS.pirateAI then
        GS.pirateAI:render(GS.vg, GS.w2s, GS.zoom)
    end

    Fleets.drawSeedShip()

    -------------------------------------------------------
    -- Layer 4: 事件覆盖层
    -------------------------------------------------------
    GalaxyEvents.Draw({
        vg      = GS.vg,
        screenW = GS.screenW,
        screenH = GS.screenH,
        w2s     = GS.w2s,
    })

    -------------------------------------------------------
    -- Layer 5: HUD 覆盖层（从远到近：摘要 → 标签 → 小地图 → 指标 → 悬浮提示 → 信号）
    -------------------------------------------------------
    Fleets.drawAsteroidSummary()
    HUD.drawSeedLabel()
    HUD.drawMinimap()
    HUD.drawAnomalyIndicator()
    HUD.drawWeatherHUD()

    -- 海盗进攻预警（仅有海盗舰队在途时）
    if GS.pirateAI and #GS.pirateAI.fleets > 0 then
        HUD.drawPirateWarningHUD()
    end

    -- Tooltip 浮于所有内容之上
    HUD.drawTooltip(GS.hoveredPlanet)
    HUD.drawAsteroidTooltip(GS.hoveredAsteroid)

    -- 信号系统（最顶层）
    HUD.drawSignalBanners()
    HUD.drawSignalButton()
end

return M
