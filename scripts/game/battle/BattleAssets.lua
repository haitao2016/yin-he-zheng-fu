---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- BattleAssets.lua — 战斗资源 & 对象池
-- 负责：舰船纹理（NanoVG 图像句柄）加载/卸载/按类型查询，
--       以及战斗对象池（projectiles / floatTexts / hitSparks / shockRings）管理。
-- 通过共享表引用与 BattleScene / BattleOrchestrator 通信。
-- ============================================================================

local NVG_IMAGE_FLAGS = _G.NVG_IMAGE_PREMULTIPLIED or 0

local BattleAssets = {}

-- 共享表引用：由 BattleScene.InitAssets 注入（均为 table 引用，原地修改）
local vg_            = nil   ---@type userdata
local shipImages_    = nil   ---@type table
local projectiles_   = nil   ---@type table
local floatTexts_    = nil   ---@type table
local hitSparks_     = nil   ---@type table
local shockRings_    = nil   ---@type table
local fireParticles_ = nil   ---@type table
local explParticles_ = nil   ---@type table
local fwParticles_   = nil   ---@type table
local bgStars_       = nil   ---@type table
local envParticles_  = nil   ---@type table

-- 舰船纹理资源表（按 stype 映射文件路径，保持与 BattleScene.Init 原逻辑一致）
---@type table<string, string>
local SHIP_IMAGE_FILES = {
    SCOUT         = "image/ship_scout_20260511185829.png",
    FRIGATE       = "image/ship_frigate_20260511185830.png",
    DESTROYER     = "image/ship_destroyer_20260511185818.png",
    BATTLECRUISER = "image/ship_battlecruiser_20260512164935.png",
    MINER         = "image/ship_miner_20260511185819.png",
    ENGINEER      = "image/ship_engineer_20260512071656.png",
    EXPLORER      = "image/ship_explorer_20260512071647.png",
    CARRIER       = "image/ship_carrier_20260513074052.png",
    INTERCEPTOR   = "image/ship_interceptor_20260513074045.png",
}

-- ============================================================================
-- Init / Release
-- ============================================================================

--- 注入共享表引用（由 BattleScene.Init 调用，传入所有战斗相关的 table 引用）
--- 所有参数均为 table 引用，子模块对内容的修改对 BattleScene 立即可见。
---@param vg            userdata  NanoVG 上下文
---@param shipImages    table     { SCOUT=handle, FRIGATE=handle, ... }
---@param projectiles   table     投射物池
---@param floatTexts    table     飘字池
---@param hitSparks     table     命中火花池
---@param shockRings    table     冲击波环池
---@param fireParticles table     燃烧粒子池
---@param explParticles table     爆炸粒子池
---@param fwParticles   table     烟花粒子池
---@param bgStars       table     背景星池
---@param envParticles  table     环境粒子池
function BattleAssets.Init(vg, shipImages, projectiles, floatTexts, hitSparks,
                           shockRings, fireParticles, explParticles,
                           fwParticles, bgStars, envParticles)
    vg_            = vg
    shipImages_    = shipImages
    projectiles_   = projectiles
    floatTexts_    = floatTexts
    hitSparks_     = hitSparks
    shockRings_    = shockRings
    fireParticles_ = fireParticles
    explParticles_ = explParticles
    fwParticles_   = fwParticles
    bgStars_       = bgStars
    envParticles_  = envParticles
end

--- 加载舰船纹理（在 BattleScene.Init 调用；保持与原逻辑一致）
--- 对每个 SHIP_IMAGE_FILES 中的 stype 创建 NanoVG 图像句柄，写入 shipImages_
function BattleAssets.LoadShipImages()
    if not vg_ or not shipImages_ then return end
    for stype, file in pairs(SHIP_IMAGE_FILES) do
        shipImages_[stype] = nvgCreateImage(vg_, file, NVG_IMAGE_FLAGS)
    end
    print("[BattleAssets] 舰船纹理加载完成")
end

--- 卸载舰船纹理（可选清理；不强制调用，避免破坏外部仍在使用的句柄）
function BattleAssets.ReleaseShipImages()
    if not vg_ or not shipImages_ then return end
    for stype, handle in pairs(shipImages_) do
        if handle and nvgDeleteImage then nvgDeleteImage(vg_, handle) end
        shipImages_[stype] = nil
    end
end

-- ============================================================================
-- 纹理查询（供 RenderEntities.drawShip 等绘制函数使用）
-- ============================================================================

--- 获取指定舰船类型的 NanoVG 图像句柄
---@param stype string
---@return userdata|nil
function BattleAssets.GetShipImage(stype)
    if not shipImages_ then return nil end
    return shipImages_[stype]
end

--- 返回整个舰船纹理表（只读使用）
---@return table
function BattleAssets.GetShipImages() return shipImages_ end

-- ============================================================================
-- 对象池清空（在 Reset / 波次切换时调用）
-- ============================================================================

--- 清空投射物池
function BattleAssets.ClearProjectiles()
    if projectiles_ then for i = #projectiles_, 1, -1 do projectiles_[i] = nil end end
end

--- 清空飘字池
function BattleAssets.ClearFloatTexts()
    if floatTexts_ then for i = #floatTexts_, 1, -1 do floatTexts_[i] = nil end end
end

--- 清空命中火花池
function BattleAssets.ClearHitSparks()
    if hitSparks_ then for i = #hitSparks_, 1, -1 do hitSparks_[i] = nil end end
end

--- 清空冲击波环池
function BattleAssets.ClearShockRings()
    if shockRings_ then for i = #shockRings_, 1, -1 do shockRings_[i] = nil end end
end

--- 清空燃烧粒子池
function BattleAssets.ClearFireParticles()
    if fireParticles_ then for i = #fireParticles_, 1, -1 do fireParticles_[i] = nil end end
end

--- 清空爆炸粒子池
function BattleAssets.ClearExplParticles()
    if explParticles_ then for i = #explParticles_, 1, -1 do explParticles_[i] = nil end end
end

--- 清空烟花粒子池
function BattleAssets.ClearFwParticles()
    if fwParticles_ then for i = #fwParticles_, 1, -1 do fwParticles_[i] = nil end end
end

--- 清空背景星池
function BattleAssets.ClearBgStars()
    if bgStars_ then for i = #bgStars_, 1, -1 do bgStars_[i] = nil end end
end

--- 清空环境粒子池
function BattleAssets.ClearEnvParticles()
    if envParticles_ then for i = #envParticles_, 1, -1 do envParticles_[i] = nil end end
end

--- 波次重置时一键清空所有战斗对象池（保留舰船纹理等资源）
function BattleAssets.ClearAllPools()
    BattleAssets.ClearProjectiles()
    BattleAssets.ClearFloatTexts()
    BattleAssets.ClearHitSparks()
    BattleAssets.ClearShockRings()
    BattleAssets.ClearFireParticles()
    BattleAssets.ClearExplParticles()
    BattleAssets.ClearFwParticles()
end

return BattleAssets
