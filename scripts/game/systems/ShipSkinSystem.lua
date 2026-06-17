--[[
ShipSkinSystem.lua - 涂装外观系统
V2.7 P2-3
舰船视觉自定义
]]

local ShipSkinSystem = {}

-- 涂装定义（8种：默认+7种付费）
ShipSkinSystem.SKINS = {
    DEFAULT = { name = "默认", color = { 100, 150, 200 }, cost = 0 },
    RED = { name = "烈焰红", color = { 200, 80, 80 }, cost = { blueCrystal = 20 } },
    BLUE = { name = "深海蓝", color = { 80, 120, 200 }, cost = { blueCrystal = 20 } },
    GOLD = { name = "黄金", color = { 200, 150, 50 }, cost = { purpleCrystal = 10 } },
    PURPLE = { name = "虚空紫", color = { 150, 80, 200 }, cost = { purpleCrystal = 10 } },
    RAINBOW = { name = "彩虹", color = { 255, 255, 255 }, cost = { rainbowCrystal = 5 }, rainbow = true },
    STEALTH = { name = "隐形涂装", color = { 50, 50, 80 }, cost = { blueCrystal = 30 }, stealthBonus = 0.1 },
    ARMOR = { name = "装甲涂装", color = { 100, 100, 100 }, cost = { blueCrystal = 30 }, armorBonus = 0.05 },
}

-- 获取舰船涂装
function ShipSkinSystem.getSkin(ship)
    return ship.skin or "DEFAULT"
end

-- 应用涂装
function ShipSkinSystem.applySkin(ship, skinId, playerState, rm)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return false, "涂装不存在" end
    
    -- 检查是否已拥有
    playerState.ownedSkins = playerState.ownedSkins or {}
    if skinId ~= "DEFAULT" and not playerState.ownedSkins[skinId] then
        -- 需要购买
        if skin.cost and skin.cost ~= 0 then
            for res, amount in pairs(skin.cost) do
                if not (rm.rareResources and (rm.rareResources[res] or 0) >= amount) then
                    return false, "资源不足: " .. (RARE_RES_LABELS[res] or res)
                end
            end
            -- 消耗资源
            for res, amount in pairs(skin.cost) do
                rm:addRare(res, -amount)
            end
            playerState.ownedSkins[skinId] = true
        end
    end
    
    ship.skin = skinId
    ship.skinColor = skin.color
    
    -- 应用涂装效果
    if skin.stealthBonus then
        ship.stealthBonus = (ship.stealthBonus or 0) + skin.stealthBonus
    end
    if skin.armorBonus then
        ship.armorBonus = (ship.armorBonus or 0) + skin.armorBonus
    end
    
    return true, "涂装已应用"
end

-- 获取涂装颜色（彩虹涂装动态变化）
function ShipSkinSystem.getSkinColor(ship)
    local skinId = ship.skin or "DEFAULT"
    local skin = ShipSkinSystem.SKINS[skinId]
    if skin and skin.rainbow then
        -- 彩虹涂装动态颜色
        local t = os.clock()
        return { 
            math.floor(127 + 127 * math.sin(t * 2)),
            math.floor(127 + 127 * math.sin(t * 2 + 2)),
            math.floor(127 + 127 * math.sin(t * 2 + 4)),
        }
    end
    return skin and skin.color or { 100, 150, 200 }
end

-- 获取所有可用涂装列表
function ShipSkinSystem.getAllSkins(playerState)
    local list = {}
    playerState.ownedSkins = playerState.ownedSkins or {}
    for id, skin in pairs(ShipSkinSystem.SKINS) do
        list[#list + 1] = {
            id = id,
            name = skin.name,
            color = skin.color,
            cost = skin.cost,
            owned = id == "DEFAULT" or playerState.ownedSkins[id] or false,
            rainbow = skin.rainbow,
            stealthBonus = skin.stealthBonus,
            armorBonus = skin.armorBonus,
        }
    end
    return list
end

-- 检查是否拥有涂装
function ShipSkinSystem.hasSkin(playerState, skinId)
    if skinId == "DEFAULT" then return true end
    playerState.ownedSkins = playerState.ownedSkins or {}
    return playerState.ownedSkins[skinId] or false
end

-- 移除涂装效果（切换涂装时需要先移除旧效果）
function ShipSkinSystem.removeSkinEffects(ship, skinId)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return end
    if skin.stealthBonus then
        ship.stealthBonus = (ship.stealthBonus or 0) - skin.stealthBonus
        if ship.stealthBonus < 0 then ship.stealthBonus = 0 end
    end
    if skin.armorBonus then
        ship.armorBonus = (ship.armorBonus or 0) - skin.armorBonus
        if ship.armorBonus < 0 then ship.armorBonus = 0 end
    end
end

-- 切换涂装（先移除旧效果再应用新效果）
function ShipSkinSystem.switchSkin(ship, newSkinId, playerState, rm)
    local oldSkinId = ship.skin or "DEFAULT"
    ShipSkinSystem.removeSkinEffects(ship, oldSkinId)
    return ShipSkinSystem.applySkin(ship, newSkinId, playerState, rm)
end

return ShipSkinSystem