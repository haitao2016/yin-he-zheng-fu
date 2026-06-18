--[[
ShipEnhancementSystem.lua - 舰船强化系统
V2.7 P0-4
]]

require "game.GameConstants"

local ShipEnhancementSystem = {}

-- 应用强化效果到舰船
function ShipEnhancementSystem.applyEnhancement(ship, material, effectScale)
    local scale = effectScale or ENHANCE_EFFECT_SCALE
    local level = ship.enhanceLevel or 0

    if effectScale.health then
        ship.maxHealth = ship.maxHealth * (1 + scale.health * level)
        ship.health = math.min(ship.health, ship.maxHealth)
    end
    if effectScale.dmg then
        ship.dmg = ship.dmg * (1 + scale.dmg * level)
    end
    if effectScale.shield then
        ship.maxShield = (ship.maxShield or ship.maxHealth * 0.3) * (1 + scale.shield * level)
    end
    if effectScale.speed then
        ship.speed = ship.speed * (1 + scale.speed * level)
    end
    if effectScale.all then
        ship.maxHealth = ship.maxHealth * (1 + scale.all * level)
        ship.dmg = ship.dmg * (1 + scale.all * level)
        ship.speed = ship.speed * (1 + scale.all * level)
    end
end

-- 强化舰船
function ShipEnhancementSystem.enhanceShip(ship, materialKey, rm)
    local material = ENHANCEMENT_MATERIALS[materialKey]
    if not material then return false, "材料不存在" end

    local maxLv = SHIP_ENHANCE_MAX[ship.stype] or 10
    if (ship.enhanceLevel or 0) >= maxLv then
        return false, "已达强化上限 Lv." .. maxLv
    end

    -- 检查普通资源
    if rm and rm.canAfford then
        for res, amount in pairs(material.cost) do
            if not rm:canAfford(res, amount) then
                return false, "资源不足: " .. res
            end
        end
    end

    -- 消耗资源
    if rm and rm.spendResources then
        rm:spendResources(material.cost)
    end

    -- 增加强化等级
    ship.enhanceLevel = (ship.enhanceLevel or 0) + 1

    -- 应用效果
    ShipEnhancementSystem.applyEnhancement(ship, material, material.effect)

    return true, "强化成功！Lv." .. ship.enhanceLevel .. "/" .. maxLv
end

-- 获取舰船强化描述
function ShipEnhancementSystem.getEnhancementDesc(ship)
    local level = ship.enhanceLevel or 0
    local maxLv = SHIP_ENHANCE_MAX[ship.stype] or 10

    if level == 0 then
        return "未强化"
    end

    local effects = {}
    local scale = ENHANCE_EFFECT_SCALE

    if scale.health then
        effects[#effects + 1] = "生命 +" .. string.format("%.1f", scale.health * level * 100) .. "%"
    end
    if scale.dmg then
        effects[#effects + 1] = "攻击 +" .. string.format("%.1f", scale.dmg * level * 100) .. "%"
    end
    if scale.speed then
        effects[#effects + 1] = "速度 +" .. string.format("%.1f", scale.speed * level * 100) .. "%"
    end

    return table.concat(effects, " | ")
end

-- 获取可用强化材料列表
function ShipEnhancementSystem.getAvailableMaterials()
    return ENHANCEMENT_MATERIALS
end

return ShipEnhancementSystem