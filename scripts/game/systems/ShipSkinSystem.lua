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

ShipSkinSystem.SKIN_RARITY = {
    COMMON = { id = "COMMON", name = "普通", tier = 1, color = { 180, 180, 180 }, stats = { hp = 0, attack = 0, speed = 0 }, dropRate = 0.50 },
    UNCOMMON = { id = "UNCOMMON", name = "优秀", tier = 2, color = { 80, 180, 100 }, stats = { hp = 0.02, attack = 0.02, speed = 0.01 }, dropRate = 0.30 },
    RARE = { id = "RARE", name = "稀有", tier = 3, color = { 80, 140, 220 }, stats = { hp = 0.05, attack = 0.04, speed = 0.02 }, dropRate = 0.14 },
    EPIC = { id = "EPIC", name = "史诗", tier = 4, color = { 170, 90, 200 }, stats = { hp = 0.08, attack = 0.07, speed = 0.04 }, dropRate = 0.05 },
    LEGENDARY = { id = "LEGENDARY", name = "传说", tier = 5, color = { 240, 150, 60 }, stats = { hp = 0.15, attack = 0.12, speed = 0.08 }, dropRate = 0.01 },
}

ShipSkinSystem.SKIN_THEMES = {
    DEFAULT = { id = "DEFAULT", name = "标准", permanent = true, event = nil },
    SPRING_FESTIVAL = { id = "SPRING_FESTIVAL", name = "春节", permanent = true, event = "spring_festival", startDate = "2026-01-20", endDate = "2026-02-20" },
    MID_AUTUMN = { id = "MID_AUTUMN", name = "中秋", permanent = true, event = "mid_autumn", startDate = "2026-09-15", endDate = "2026-10-15" },
    SUMMER = { id = "SUMMER", name = "夏季赛季", permanent = false, event = "summer_2026", startDate = "2026-06-01", endDate = "2026-09-01" },
    WINTER = { id = "WINTER", name = "冬季赛季", permanent = false, event = "winter_2026", startDate = "2026-12-01", endDate = "2027-03-01" },
    HALLOWEEN = { id = "HALLOWEEN", name = "万圣节", permanent = true, event = "halloween", startDate = "2026-10-25", endDate = "2026-11-05" },
    ANNIVERSARY = { id = "ANNIVERSARY", name = "周年庆", permanent = true, event = "anniversary", startDate = "2026-03-15", endDate = "2026-04-15" },
}

ShipSkinSystem.SKINS.DEFAULT.rarity = "COMMON"
ShipSkinSystem.SKINS.DEFAULT.theme = "DEFAULT"
ShipSkinSystem.SKINS.DEFAULT.effects = { particlePath = "particles/default.pfx", particleColor = { 255, 255, 255 } }

ShipSkinSystem.SKINS.RED.rarity = "UNCOMMON"
ShipSkinSystem.SKINS.RED.theme = "DEFAULT"
ShipSkinSystem.SKINS.RED.effects = { particlePath = "particles/fire.pfx", particleColor = { 255, 100, 50 } }

ShipSkinSystem.SKINS.BLUE.rarity = "UNCOMMON"
ShipSkinSystem.SKINS.BLUE.theme = "DEFAULT"
ShipSkinSystem.SKINS.BLUE.effects = { particlePath = "particles/ocean.pfx", particleColor = { 80, 180, 255 } }

ShipSkinSystem.SKINS.GOLD.rarity = "RARE"
ShipSkinSystem.SKINS.GOLD.theme = "DEFAULT"
ShipSkinSystem.SKINS.GOLD.effects = { particlePath = "particles/gold.pfx", particleColor = { 255, 215, 80 } }

ShipSkinSystem.SKINS.PURPLE.rarity = "RARE"
ShipSkinSystem.SKINS.PURPLE.theme = "DEFAULT"
ShipSkinSystem.SKINS.PURPLE.effects = { particlePath = "particles/void.pfx", particleColor = { 200, 100, 255 } }

ShipSkinSystem.SKINS.RAINBOW.rarity = "EPIC"
ShipSkinSystem.SKINS.RAINBOW.theme = "DEFAULT"
ShipSkinSystem.SKINS.RAINBOW.effects = { particlePath = "particles/rainbow.pfx", particleColor = { 255, 255, 255 } }

ShipSkinSystem.SKINS.STEALTH.rarity = "EPIC"
ShipSkinSystem.SKINS.STEALTH.theme = "DEFAULT"
ShipSkinSystem.SKINS.STEALTH.effects = { particlePath = "particles/stealth.pfx", particleColor = { 100, 120, 160 } }

ShipSkinSystem.SKINS.ARMOR.rarity = "UNCOMMON"
ShipSkinSystem.SKINS.ARMOR.theme = "DEFAULT"
ShipSkinSystem.SKINS.ARMOR.effects = { particlePath = "particles/armor.pfx", particleColor = { 150, 150, 150 } }

function ShipSkinSystem.getRarity(rarityId)
    return ShipSkinSystem.SKIN_RARITY[rarityId]
end

function ShipSkinSystem.getRarityStats(rarityId)
    local rarity = ShipSkinSystem.getRarity(rarityId)
    if not rarity then return { hp = 0, attack = 0, speed = 0 } end
    return { hp = rarity.stats.hp, attack = rarity.stats.attack, speed = rarity.stats.speed }
end

function ShipSkinSystem.getTheme(themeId)
    return ShipSkinSystem.SKIN_THEMES[themeId]
end

function ShipSkinSystem.isThemeAvailable(themeId, nowTs)
    local theme = ShipSkinSystem.getTheme(themeId)
    if not theme then return false end
    if theme.permanent then return true end
    if not theme.startDate or not theme.endDate then return theme.permanent end
    local function dateToTs(dateStr)
        local y, m, d = dateStr:match("(%d+)-(%d+)-(%d+)")
        if not y or not m or not d then return nil end
        return os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
    end
    local now = nowTs or os.time()
    local startTs = dateToTs(theme.startDate)
    local endTs = dateToTs(theme.endDate)
    if not startTs or not endTs then return theme.permanent end
    return now >= startTs and now <= endTs
end

function ShipSkinSystem.getSkinRarity(skinId)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return nil end
    return skin.rarity or "COMMON"
end

function ShipSkinSystem.getSkinTheme(skinId)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return nil end
    return skin.theme or "DEFAULT"
end

function ShipSkinSystem.getSkinEffects(skinId)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return nil end
    return skin.effects or { particlePath = nil, particleColor = { 255, 255, 255 } }
end

---@param playerState table
---@return number
function ShipSkinSystem.getUnlockedCount(playerState)
    playerState.ownedSkins = playerState.ownedSkins or {}
    local count = 1
    for skinId, _ in pairs(playerState.ownedSkins) do
        if ShipSkinSystem.SKINS[skinId] then count = count + 1 end
    end
    return count
end

---@param playerState table
---@return table
function ShipSkinSystem.getUnlockedByRarity(playerState)
    playerState.ownedSkins = playerState.ownedSkins or {}
    local result = { COMMON = 0, UNCOMMON = 0, RARE = 0, EPIC = 0, LEGENDARY = 0 }
    if ShipSkinSystem.SKINS.DEFAULT then
        local r = ShipSkinSystem.SKINS.DEFAULT.rarity or "COMMON"
        result[r] = (result[r] or 0) + 1
    end
    for skinId, _ in pairs(playerState.ownedSkins) do
        local skin = ShipSkinSystem.SKINS[skinId]
        if skin then
            local r = skin.rarity or "COMMON"
            result[r] = (result[r] or 0) + 1
        end
    end
    return result
end

---@param playerState table
---@return table
function ShipSkinSystem.getActiveSkins(playerState)
    local result = {}
    playerState.ownedSkins = playerState.ownedSkins or {}
    for id, skin in pairs(ShipSkinSystem.SKINS) do
        local owned = id == "DEFAULT" or playerState.ownedSkins[id] or false
        if owned then
            result[#result + 1] = {
                id = id,
                name = skin.name,
                color = skin.color,
                rarity = skin.rarity or "COMMON",
                theme = skin.theme or "DEFAULT",
                effects = skin.effects,
            }
        end
    end
    return result
end

---@param skinId string
---@return table
function ShipSkinSystem.getSkinStats(skinId)
    local skin = ShipSkinSystem.SKINS[skinId]
    if not skin then return { hp = 0, attack = 0, speed = 0, stealthBonus = 0, armorBonus = 0, rarity = nil } end
    local rarity = ShipSkinSystem.getRarity(skin.rarity or "COMMON")
    local stats = { hp = 0, attack = 0, speed = 0, stealthBonus = 0, armorBonus = 0, rarity = skin.rarity or "COMMON" }
    if rarity then
        stats.hp = rarity.stats.hp
        stats.attack = rarity.stats.attack
        stats.speed = rarity.stats.speed
    end
    stats.stealthBonus = skin.stealthBonus or 0
    stats.armorBonus = skin.armorBonus or 0
    return stats
end

---@param playerState table
---@return table
function ShipSkinSystem.getCodex(playerState)
    playerState.ownedSkins = playerState.ownedSkins or {}
    local codex = {}
    for id, skin in pairs(ShipSkinSystem.SKINS) do
        local rarity = ShipSkinSystem.getRarity(skin.rarity or "COMMON")
        local theme = ShipSkinSystem.getTheme(skin.theme or "DEFAULT")
        codex[#codex + 1] = {
            id = id,
            name = skin.name,
            color = skin.color,
            rarity = skin.rarity or "COMMON",
            rarityName = rarity and rarity.name or "普通",
            tier = rarity and rarity.tier or 1,
            theme = skin.theme or "DEFAULT",
            themeName = theme and theme.name or "标准",
            cost = skin.cost,
            owned = id == "DEFAULT" or playerState.ownedSkins[id] or false,
            effects = skin.effects,
            stats = rarity and rarity.stats or { hp = 0, attack = 0, speed = 0 },
        }
    end
    table.sort(codex, function(a, b)
        local ra = ShipSkinSystem.getRarity(a.rarity)
        local rb = ShipSkinSystem.getRarity(b.rarity)
        local ta = ra and ra.tier or 1
        local tb = rb and rb.tier or 1
        if ta ~= tb then return ta < tb end
        return a.id < b.id
    end)
    return codex
end

---@param playerState table
---@return table
function ShipSkinSystem.getCodexSummary(playerState)
    playerState.ownedSkins = playerState.ownedSkins or {}
    local totalSkins = 0
    for _ in pairs(ShipSkinSystem.SKINS) do totalSkins = totalSkins + 1 end
    local unlocked = ShipSkinSystem.getUnlockedCount(playerState)
    local byRarity = ShipSkinSystem.getUnlockedByRarity(playerState)
    local totalByRarity = { COMMON = 0, UNCOMMON = 0, RARE = 0, EPIC = 0, LEGENDARY = 0 }
    for id, skin in pairs(ShipSkinSystem.SKINS) do
        local r = skin.rarity or "COMMON"
        totalByRarity[r] = (totalByRarity[r] or 0) + 1
    end
    local rarityStats = {}
    for rId, rInfo in pairs(ShipSkinSystem.SKIN_RARITY) do
        rarityStats[#rarityStats + 1] = {
            id = rId,
            name = rInfo.name,
            tier = rInfo.tier,
            owned = byRarity[rId] or 0,
            total = totalByRarity[rId] or 0,
        }
    end
    table.sort(rarityStats, function(a, b) return a.tier < b.tier end)
    return {
        totalSkins = totalSkins,
        unlocked = unlocked,
        locked = math.max(0, totalSkins - unlocked),
        progressPercent = totalSkins > 0 and math.floor((unlocked / totalSkins) * 100) or 0,
        byRarity = rarityStats,
    }
end

---@param ship table
---@return table
function ShipSkinSystem.applyRarityBonuses(ship)
    local skinId = ship.skin or "DEFAULT"
    local stats = ShipSkinSystem.getSkinStats(skinId)
    ship.hpBonus = (ship.hpBonus or 0) + stats.hp
    ship.attackBonus = (ship.attackBonus or 0) + stats.attack
    ship.speedBonus = (ship.speedBonus or 0) + stats.speed
    return stats
end

---@param ship table
---@return table
function ShipSkinSystem.removeRarityBonuses(ship)
    local skinId = ship.skin or "DEFAULT"
    local stats = ShipSkinSystem.getSkinStats(skinId)
    ship.hpBonus = math.max(0, (ship.hpBonus or 0) - stats.hp)
    ship.attackBonus = math.max(0, (ship.attackBonus or 0) - stats.attack)
    ship.speedBonus = math.max(0, (ship.speedBonus or 0) - stats.speed)
    return stats
end

---@param ship table
---@return table
function ShipSkinSystem.getCurrentEffects(ship)
    local skinId = ship.skin or "DEFAULT"
    return ShipSkinSystem.getSkinEffects(skinId)
end

return ShipSkinSystem