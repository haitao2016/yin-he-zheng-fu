-- ============================================================================
-- game/MutantShipSystem.lua  -- P1-2 V2.5: 变异舰船系统
-- 变异舰船生成、词缀效果定义、持久化存储
-- ============================================================================
local cjson = require "cjson"

---@class MutantAffix
---@field key string
---@field name string
---@field desc string
---@field icon string
---@field positive boolean
---@field effect table

---@class MutantShip
---@field id string        -- unique id (uuid-like)
---@field baseType string  -- SHIP_TYPES key (e.g. "FRIGATE")
---@field affixes string[] -- list of affix keys (1-2)
---@field source string    -- "boss" | "anomaly" | "quest"

-- ============================================================================
-- 词缀定义（12 种：8 正面 + 4 负面）
-- ============================================================================

local POSITIVE_AFFIXES = {
    { key = "vampiric",   name = "吸血",   icon = "🩸", desc = "击杀回复5%最大HP",
      effect = { type = "vampiric", healPct = 0.05 } },
    { key = "fission",    name = "分裂",   icon = "🧬", desc = "死亡时生成2艘微型副本",
      effect = { type = "fission", count = 2, scaleFactor = 0.4 } },
    { key = "berserk",    name = "狂暴",   icon = "💢", desc = "HP<30%时攻击×2",
      effect = { type = "berserk", threshold = 0.30, dmgMult = 2.0 } },
    { key = "stealth",    name = "隐形",   icon = "👁️", desc = "每20s隐身3s",
      effect = { type = "stealth", interval = 20, duration = 3.0 } },
    { key = "regen",      name = "再生",   icon = "💚", desc = "每秒回复1%最大HP",
      effect = { type = "regen", healRate = 0.01 } },
    { key = "overcharge", name = "过载",   icon = "⚡", desc = "攻速+50%但持续扣HP",
      effect = { type = "overcharge", rateMult = 1.5, dpsPercent = 0.005 } },
    { key = "shock",      name = "感电",   icon = "🌩️", desc = "攻击附带范围溅射",
      effect = { type = "shock", splashRadius = 40, splashRatio = 0.3 } },
    { key = "guardian",   name = "守护",   icon = "🛡️", desc = "相邻友军减伤15%",
      effect = { type = "guardian", radius = 80, dmgReduction = 0.15 } },
}

local NEGATIVE_AFFIXES = {
    { key = "fragile",    name = "脆弱",   icon = "💔", desc = "最大HP-20%",
      effect = { type = "fragile", hpMult = 0.80 } },
    { key = "sluggish",   name = "迟缓",   icon = "🐌", desc = "移动速度-30%",
      effect = { type = "sluggish", speedMult = 0.70 } },
    { key = "costly",     name = "耗能",   icon = "💸", desc = "维护费×2",
      effect = { type = "costly", costMult = 2.0 } },
    { key = "unstable",   name = "不稳定", icon = "🎲", desc = "每30s随机失控2s",
      effect = { type = "unstable", interval = 30, duration = 2.0 } },
}

-- Lookup table for quick access
local ALL_AFFIXES = {}
for _, a in ipairs(POSITIVE_AFFIXES) do
    a.positive = true
    ALL_AFFIXES[a.key] = a
end
for _, a in ipairs(NEGATIVE_AFFIXES) do
    a.positive = false
    ALL_AFFIXES[a.key] = a
end

-- ============================================================================
-- Module
-- ============================================================================

local SAVE_FILE         = "mutant_ships.json"
local MAX_PER_FLEET     = 2   -- 每编队最多变异舰船数
local MAX_STORAGE       = 30  -- 仓库上限

---@class MutantShipSystemModule
local MutantShipSystem = {}

---@type MutantShip[]
local inventory_ = {}

-- ============================================================================
-- Private helpers
-- ============================================================================

local idCounter_ = 0

local function generateId()
    idCounter_ = idCounter_ + 1
    return string.format("mutant_%d_%d", os.time(), idCounter_)
end

--- Roll 1-2 affixes for a mutant ship.
--- Rules: at least 1 positive; if 2 affixes, second may be negative (50% chance).
---@return string[]
local function rollAffixes()
    local result = {}
    -- First affix: always positive
    local idx1 = math.random(1, #POSITIVE_AFFIXES)
    result[1] = POSITIVE_AFFIXES[idx1].key

    -- 60% chance of getting a second affix
    if math.random() < 0.60 then
        if math.random() < 0.50 then
            -- Second positive (different from first)
            local pool = {}
            for i, a in ipairs(POSITIVE_AFFIXES) do
                if i ~= idx1 then pool[#pool + 1] = a.key end
            end
            if #pool > 0 then
                result[2] = pool[math.random(1, #pool)]
            end
        else
            -- Second negative
            local idx2 = math.random(1, #NEGATIVE_AFFIXES)
            result[2] = NEGATIVE_AFFIXES[idx2].key
        end
    end

    return result
end

--- Pick a random combat ship type (not ENGINEER/EXPLORER)
---@return "SCOUT"|"FRIGATE"|"DESTROYER"|"BATTLECRUISER"|"INTERCEPTOR"|"CARRIER"
local function rollBaseType()
    local combatTypes = { "SCOUT", "FRIGATE", "DESTROYER", "BATTLECRUISER", "INTERCEPTOR", "CARRIER" }
    return combatTypes[math.random(1, #combatTypes)] ---@diagnostic disable-line: return-type-mismatch
end

-- ============================================================================
-- Persistence
-- ============================================================================

local function saveToFile()
    local json = cjson.encode(inventory_)
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
end

local function loadFromFile()
    if not fileSystem:FileExists(SAVE_FILE) then
        return {}
    end
    local file = File(SAVE_FILE, FILE_READ) ---@diagnostic disable-line: param-type-mismatch
    if not file:IsOpen() then
        return {}
    end
    local raw = file:ReadString()
    file:Close()
    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" then
        return {}
    end
    return decoded
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Initialize the system (load from disk).
function MutantShipSystem.Init()
    inventory_ = loadFromFile()
end

--- Get all mutant ships in inventory.
---@return MutantShip[]
function MutantShipSystem.GetInventory()
    return inventory_
end

--- Get a specific mutant ship by id.
---@param id string
---@return MutantShip|nil
function MutantShipSystem.GetById(id)
    for _, ship in ipairs(inventory_) do
        if ship.id == id then return ship end
    end
    return nil
end

--- Get mutant ships equipped for a fleet, keyed by baseType.
--- Currently returns all inventory ships (max 2 per fleet rule enforced by caller).
--- Future: add per-fleet assignment UI.
---@param fleetId any  (reserved for future fleet assignment)
---@return table  { [shipType] = { id, baseType, affixes={key,...} } }
function MutantShipSystem.GetEquippedForFleet(fleetId)
    local map = {}
    local count = 0
    for _, ship in ipairs(inventory_) do
        if not map[ship.baseType] and count < MAX_PER_FLEET then
            map[ship.baseType] = ship
            count = count + 1
        end
    end
    return map
end

--- Get affix definition by key.
---@param key string
---@return MutantAffix|nil
function MutantShipSystem.GetAffix(key)
    return ALL_AFFIXES[key]
end

--- Get all affix definitions.
---@return table<string, MutantAffix>
function MutantShipSystem.GetAllAffixes()
    return ALL_AFFIXES
end

--- Attempt to generate a mutant ship from boss kill.
--- Returns the new ship or nil if roll failed.
---@param dropChance? number  Override drop chance (default 0.15)
---@return MutantShip|nil
function MutantShipSystem.TryBossDrop(dropChance)
    dropChance = dropChance or 0.15
    if math.random() > dropChance then return nil end
    if #inventory_ >= MAX_STORAGE then return nil end

    local ship = {
        id       = generateId(),
        baseType = rollBaseType(),
        affixes  = rollAffixes(),
        source   = "boss",
    }
    inventory_[#inventory_ + 1] = ship
    saveToFile()
    return ship
end

--- Generate a mutant ship from anomaly event.
---@param dropChance? number  Override drop chance (default 0.50)
---@return MutantShip|nil
function MutantShipSystem.TryAnomalyDrop(dropChance)
    dropChance = dropChance or 0.50
    if math.random() > dropChance then return nil end
    if #inventory_ >= MAX_STORAGE then return nil end

    local ship = {
        id       = generateId(),
        baseType = rollBaseType(),
        affixes  = rollAffixes(),
        source   = "anomaly",
    }
    inventory_[#inventory_ + 1] = ship
    saveToFile()
    return ship
end

--- Award a guaranteed mutant ship (from quest completion).
---@param specificType? string  Force a ship type (optional)
---@return MutantShip|nil
function MutantShipSystem.AwardFromQuest(specificType)
    if #inventory_ >= MAX_STORAGE then return nil end

    local ship = {
        id       = generateId(),
        baseType = specificType or rollBaseType(),
        affixes  = rollAffixes(),
        source   = "quest",
    }
    inventory_[#inventory_ + 1] = ship
    saveToFile()
    return ship
end

--- Remove a mutant ship by id (dismantle/scrap).
---@param id string
---@return boolean
function MutantShipSystem.Remove(id)
    for i, ship in ipairs(inventory_) do
        if ship.id == id then
            table.remove(inventory_, i)
            saveToFile()
            return true
        end
    end
    return false
end

--- Check if a fleet can add more mutant ships.
---@param fleetMutantCount integer  Current mutant ship count in fleet
---@return boolean
function MutantShipSystem.CanAddToFleet(fleetMutantCount)
    return fleetMutantCount < MAX_PER_FLEET
end

--- Get max mutant ships per fleet.
---@return integer
function MutantShipSystem.GetMaxPerFleet()
    return MAX_PER_FLEET
end

--- Get display name for a mutant ship (with icon prefix).
---@param ship MutantShip
---@return string
function MutantShipSystem.GetDisplayName(ship)
    local baseName = SHIP_TYPES[ship.baseType] and SHIP_TYPES[ship.baseType].name or ship.baseType
    local affixNames = {}
    for _, key in ipairs(ship.affixes) do
        local affix = ALL_AFFIXES[key]
        if affix then
            affixNames[#affixNames + 1] = affix.icon .. affix.name
        end
    end
    return string.format("⚡%s [%s]", baseName, table.concat(affixNames, "/"))
end

--- Get affix summary text for UI tooltip.
---@param ship MutantShip
---@return string
function MutantShipSystem.GetAffixSummary(ship)
    local lines = {}
    for _, key in ipairs(ship.affixes) do
        local affix = ALL_AFFIXES[key]
        if affix then
            local prefix = affix.positive and "+" or "-"
            lines[#lines + 1] = string.format("%s %s%s: %s", affix.icon, prefix, affix.name, affix.desc)
        end
    end
    return table.concat(lines, "\n")
end

--- Count unique affixes across all inventory (for achievement).
---@return integer
function MutantShipSystem.CountUniqueAffixes()
    local seen = {}
    for _, ship in ipairs(inventory_) do
        for _, key in ipairs(ship.affixes) do
            seen[key] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    return count
end

--- Count mutant ships with at least N different affixes (for achievement).
---@return integer
function MutantShipSystem.CountShipsWithDistinctAffixes()
    local seen = {}
    for _, ship in ipairs(inventory_) do
        for _, key in ipairs(ship.affixes) do
            seen[key] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    return count
end

--- Apply mutant affix stat modifiers to a ship table (used at battle spawn).
--- Mutates the ship data in-place with modified stats.
---@param shipData table  The runtime ship data in battle (has health, dmg, speed, etc.)
---@param affixKeys string[]
function MutantShipSystem.ApplyAffixStats(shipData, affixKeys)
    for _, key in ipairs(affixKeys) do
        local affix = ALL_AFFIXES[key]
        if affix then
            local e = affix.effect
            if e.type == "fragile" then
                shipData.maxHealth = math.floor(shipData.maxHealth * e.hpMult)
                shipData.health = math.min(shipData.health, shipData.maxHealth)
            elseif e.type == "sluggish" then
                shipData.speed = shipData.speed * e.speedMult
            elseif e.type == "overcharge" then
                shipData.shotRate = (shipData.shotRate or 1.0) * e.rateMult
            end
            -- Other affixes are handled at runtime in battle tick
        end
    end
end

--- Check if a given affix key triggers on kill event.
---@param key string
---@return boolean
function MutantShipSystem.IsOnKillAffix(key)
    return key == "vampiric"
end

--- Check if a given affix triggers on death event.
---@param key string
---@return boolean
function MutantShipSystem.IsOnDeathAffix(key)
    return key == "fission"
end

--- Check if a given affix is a passive aura.
---@param key string
---@return boolean
function MutantShipSystem.IsAuraAffix(key)
    return key == "guardian"
end

--- Check if affix is a periodic effect.
---@param key string
---@return boolean
function MutantShipSystem.IsPeriodicAffix(key)
    return key == "stealth" or key == "unstable" or key == "regen" or key == "overcharge"
end

--- Persist immediately.
function MutantShipSystem.Save()
    saveToFile()
end

return MutantShipSystem
