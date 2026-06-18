--- Civilization Legacy System
--- Tracks Legacy Points (LP) and a 3-branch upgrade tree that persists across game rounds.
--- Persistence: cjson + File API, saved to "legacy_data.json" in the sandbox root.

local cjson = require "cjson"

---@class LegacyTreeBranch
---@field level integer  -- 0..5

---@class LegacyTree
---@field military    LegacyTreeBranch
---@field economy     LegacyTreeBranch
---@field diplomacy   LegacyTreeBranch

---@class LegacyData
---@field lp       integer      -- current unspent LP
---@field spent    integer      -- total LP ever spent on upgrades
---@field tree     LegacyTree

---@class LegacyBonuses
---@field extraFleets           integer   -- military L1: initial fleet +N
---@field extraModSlot          integer   -- military L2: mod slot +N
---@field skillCdReduction      number    -- military L3: battle skill CD reduction (0..1)
---@field commanderStartLevel   integer   -- military L4: commander starts at Lv2
---@field bossDmgBonus          number    -- military L5: boss first-hit damage bonus (0..1)
---@field resourceBonus         number    -- economy  L1: initial resource multiplier bonus (0..1)
---@field buildSpeedBonus       number    -- economy  L2: build speed multiplier bonus (0..1)
---@field blackMarketDiscount   number    -- economy  L3: black market discount (0..1)
---@field colonizeSpeedBonus    number    -- economy  L4: colonize speed bonus (0..1)
---@field megaPhaseReduction    number    -- economy  L5: megastructure phase seconds reduced
---@field factionFavorBonus     integer   -- diplomacy L1: initial faction favor +N
---@field agreementCdReduction  number    -- diplomacy L2: agreement CD reduction (0..1)
---@field diploPositiveBonus    number    -- diplomacy L3: positive diplomatic event rate bonus (0..1)
---@field questRefreshReduction number    -- diplomacy L4: quest board refresh CD reduction (seconds)
---@field crisisCountdownBonus  number    -- diplomacy L5: crisis countdown extension (seconds)

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------

local SAVE_FILE     = "legacy_data.json"
local LP_CAP        = 999
local RESET_COST    = 50
local MAX_LEVEL     = 5
local BRANCHES      = { "military", "economy", "diplomacy" }

--- LP cost to reach each level (index = target level 1..5)
local UPGRADE_COST  = { 10, 25, 50, 100, 200 }

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

---@class LegacySystemModule
local LegacySystem = {}

---@type LegacyData
local data = nil

-- ---------------------------------------------------------------------------
-- Private helpers
-- ---------------------------------------------------------------------------

---@return LegacyData
local function newData()
    return {
        lp    = 0,
        spent = 0,
        tree  = {
            military   = { level = 0 },
            economy    = { level = 0 },
            diplomacy  = { level = 0 },
        },
    }
end

local function saveToFile()
    local json = cjson.encode(data)
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
    end
end

---@return LegacyData|nil
local function loadFromFile()
    if not fileSystem:FileExists(SAVE_FILE) then
        return nil
    end
    local file = File(SAVE_FILE, FILE_READ) ---@diagnostic disable-line: param-type-mismatch
    if not file:IsOpen() then
        return nil
    end
    local raw = file:ReadString()
    file:Close()
    local ok, decoded = pcall(cjson.decode, raw)
    if not ok or type(decoded) ~= "table" then
        return nil
    end
    -- Validate / back-fill missing fields defensively
    decoded.lp    = math.min(math.max(decoded.lp or 0, 0), LP_CAP)
    decoded.spent = math.max(decoded.spent or 0, 0)
    decoded.tree  = decoded.tree or {}
    for _, branch in ipairs(BRANCHES) do
        decoded.tree[branch] = decoded.tree[branch] or { level = 0 }
        decoded.tree[branch].level = math.min(
            math.max(decoded.tree[branch].level or 0, 0), MAX_LEVEL)
    end
    return decoded
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Load legacy data from disk, or create fresh data if none exists.
function LegacySystem.Init()
    data = loadFromFile() or newData()
end

--- Return current unspent LP.
---@return integer
function LegacySystem.GetLP()
    return data.lp
end

--- Return a copy of the upgrade tree.
---@return LegacyTree
function LegacySystem.GetTree()
    return {
        military   = { level = data.tree.military.level },
        economy    = { level = data.tree.economy.level },
        diplomacy  = { level = data.tree.diplomacy.level },
    }
end

--- Return total LP spent on upgrades (not counting resets).
---@return integer
function LegacySystem.GetTotalSpent()
    return data.spent
end

--- Check whether the player can afford the next level of a branch.
---@param branch string  "military" | "economy" | "diplomacy"
---@return boolean
function LegacySystem.CanUpgrade(branch)
    local b = data.tree[branch]
    if not b then return false end
    if b.level >= MAX_LEVEL then return false end
    local cost = UPGRADE_COST[b.level + 1]
    return data.lp >= cost
end

--- Spend LP to upgrade a branch by one level.
--- Returns true on success, false if unable (max level or insufficient LP).
---@param branch string
---@return boolean
function LegacySystem.Upgrade(branch)
    if not LegacySystem.CanUpgrade(branch) then
        return false
    end
    local b    = data.tree[branch]
    local cost = UPGRADE_COST[b.level + 1]
    data.lp    = data.lp - cost
    data.spent = data.spent + cost
    b.level    = b.level + 1
    saveToFile()
    return true
end

--- Spend 50 LP to reset all branch levels back to 0.
--- Refunds spent LP minus the reset fee.
--- Returns true on success, false if insufficient LP.
---@return boolean
function LegacySystem.Reset()
    if data.lp < RESET_COST then
        return false
    end
    -- Recalculate LP refund: sum of costs for currently-purchased levels
    local refund = 0
    for _, branch in ipairs(BRANCHES) do
        local lvl = data.tree[branch].level
        for l = 1, lvl do
            refund = refund + UPGRADE_COST[l]
        end
        data.tree[branch].level = 0
    end
    data.lp    = math.min(data.lp - RESET_COST + refund, LP_CAP)
    data.spent = 0
    saveToFile()
    return true
end

--- Add LP directly (capped at 999). Persists immediately.
---@param amount integer
---@param reason string  Human-readable label (for future logging)
function LegacySystem.AwardLP(amount, reason)
    data.lp = math.min(data.lp + math.max(amount, 0), LP_CAP)
    saveToFile()
end

--- Calculate and award LP from end-of-game statistics.
--- Expected fields in stats (all optional, default false/0):
---   survived10Waves (bool), kills (int), builtMegastructure (bool),
---   survivedCrisis (bool), leagueRank (int 1-3 counts)
---@param stats table
function LegacySystem.AwardEndOfGame(stats)
    stats = stats or {}
    local earned = 0
    if stats.survived10Waves   then earned = earned + 5  end
    if (stats.kills or 0) >= 100 then earned = earned + 3  end
    if stats.builtMegastructure then earned = earned + 10 end
    if stats.survivedCrisis     then earned = earned + 15 end
    if (stats.leagueRank or 0) >= 1 and (stats.leagueRank or 0) <= 3 then
        earned = earned + 8
    end
    if earned > 0 then
        LegacySystem.AwardLP(earned, "end_of_game")
    end
end

--- Return a flat bonuses table derived from the current tree levels.
---@return LegacyBonuses
function LegacySystem.GetBonuses()
    local mil  = data.tree.military.level
    local eco  = data.tree.economy.level
    local dip  = data.tree.diplomacy.level

    ---@type LegacyBonuses
    local b = {
        -- Military branch
        extraFleets           = mil >= 1 and 1    or 0,
        extraModSlot          = mil >= 2 and 1    or 0,
        skillCdReduction      = mil >= 3 and 0.10 or 0,
        commanderStartLevel   = mil >= 4 and 2    or 1,
        bossDmgBonus          = mil >= 5 and 0.20 or 0,
        -- Economy branch
        resourceBonus         = eco >= 1 and 0.15 or 0,
        buildSpeedBonus       = eco >= 2 and 0.10 or 0,
        blackMarketDiscount   = eco >= 3 and 0.10 or 0,
        colonizeSpeedBonus    = eco >= 4 and 0.20 or 0,
        megaPhaseReduction    = eco >= 5 and 15   or 0,
        -- Diplomacy branch
        factionFavorBonus     = dip >= 1 and 5    or 0,
        agreementCdReduction  = dip >= 2 and 0.20 or 0,
        diploPositiveBonus    = dip >= 3 and 0.10 or 0,
        questRefreshReduction = dip >= 4 and 30   or 0,
        crisisCountdownBonus  = dip >= 5 and 30   or 0,
    }
    return b
end

--- Persist current data to disk immediately.
function LegacySystem.Save()
    saveToFile()
end

-- 导出常量供 UI 面板共享
LegacySystem.UPGRADE_COST = UPGRADE_COST
LegacySystem.RESET_COST   = RESET_COST

return LegacySystem
