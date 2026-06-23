---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
local SaveMigrationTool = {}

SaveMigrationTool.CURRENT_VERSION = 3
SaveMigrationTool.STATUS_SUCCESS = "SUCCESS"
SaveMigrationTool.STATUS_FAILED = "FAILED"
SaveMigrationTool.STATUS_ROLLBACK = "ROLLBACK"

local migrationHistory = {}
local currentStatus = nil

local V1_TO_V2_KEY_MAP = {
    resources = "r",
    planets = "p",
    commanders = "c",
    tech = "t",
    fleets = "f",
    achievements = "a",
    buildings = "b",
}

local V2_TO_V3_TECH_REMAP = {
    t1 = "energy_core",
    t2 = "hyperdrive",
    t3 = "shield_matrix",
    t4 = "weapon_array",
    t5 = "mining_laser",
    t6 = "terraforming",
    t7 = "diplomacy",
    t8 = "logistics",
}

local V3_BASE_LEVEL_CAP = 100
local V2_BASE_LEVEL_CAP = 50

local DEFAULT_COMMANDER_FIELDS = {
    level = 1,
    exp = 0,
    morale = 100,
    loyalty = 100,
    rank = "ensign",
    skills = {},
    assignments = {},
}

local function fnv1aHash(data)
    local hash = 2166136261
    local s = type(data) == "string" and data or (data and tostring(data) or "")
    for i = 1, #s do
        local b = string.byte(s, i)
        hash = (hash ~ b) % 4294967296
        hash = (hash * 16777619) % 4294967296
    end
    return hash
end

local function serializeTable(t, depth)
    depth = depth or 0
    if depth > 100 then return tostring(t) end
    if type(t) ~= "table" then return tostring(t) end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = tostring(k) .. "=" .. serializeTable(t[k], depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function computeChecksum(data)
    return fnv1aHash(serializeTable(data))
end

local function deepCopy(obj, seen)
    seen = seen or {}
    if type(obj) ~= "table" then return obj end
    if seen[obj] then return seen[obj] end
    local copy = {}
    seen[obj] = copy
    for k, v in pairs(obj) do
        copy[deepCopy(k, seen)] = deepCopy(v, seen)
    end
    return copy
end

---@param data table
---@return number
local function detectVersion(data)
    if not data or type(data) ~= "table" then return 1 end
    local meta = data.__meta or data.metadata or {}
    if meta.version then return tonumber(meta.version) or 1 end
    if meta.saveFormatVersion then return tonumber(meta.saveFormatVersion) or 1 end
    if data.r or data.p or data.c or data.t or data.f or data.a or data.b then
        return 2
    end
    if data.v3_marker or (data.meta and data.meta.v3) then
        return 3
    end
    if data.resources or data.planets or data.commanders or data.tech or data.fleets then
        return 1
    end
    return 1
end

---@param data table
---@return table, string
local function convertV1toV2(data)
    if not data or type(data) ~= "table" then return data, "input_invalid" end
    local result = {}
    for k, v in pairs(data) do
        local newKey = V1_TO_V2_KEY_MAP[k] or k
        if type(v) == "table" then
            result[newKey] = convertV1toV2(v)
        else
            result[newKey] = v
        end
    end
    result.__meta = {
        version = 2,
        migratedFrom = 1,
        migratedAt = os and os.time() or 0,
        checksum = nil,
    }
    result.__meta.checksum = computeChecksum(result)
    return result, "ok"
end

---@param techData table
---@return table
local function remapTechTree(techData)
    if not techData or type(techData) ~= "table" then
        return { unlocked = {}, progress = {}, treeVersion = "v3" }
    end
    local result = {
        unlocked = {},
        progress = {},
        treeVersion = "v3",
    }
    for k, v in pairs(techData) do
        local newKey = V2_TO_V3_TECH_REMAP[k] or k
        if type(v) == "table" then
            result.unlocked[newKey] = true
            result.progress[newKey] = v.progress or v or 0
        else
            result.unlocked[newKey] = true
            result.progress[newKey] = tonumber(v) or 0
        end
    end
    return result
end

---@param baseData table
---@return table
local function expandBaseLevels(baseData)
    if not baseData or type(baseData) ~= "table" then
        return { level = 1, maxLevel = V3_BASE_LEVEL_CAP, buildings = {} }
    end
    local result = deepCopy(baseData)
    result.maxLevel = V3_BASE_LEVEL_CAP
    result.level = math.min(tonumber(result.level) or 1, V3_BASE_LEVEL_CAP)
    if result.level > V2_BASE_LEVEL_CAP * 0.8 then
        result.bonusPool = (result.bonusPool or 0) + math.floor(result.level * 0.1)
    end
    if not result.buildings then result.buildings = {} end
    if type(result.buildings) == "table" then
        for _, building in pairs(result.buildings) do
            if type(building) == "table" then
                building.maxLevel = math.max(tonumber(building.maxLevel) or 10, 25)
                building.v3_expanded = true
            end
        end
    end
    result.v3_expanded = true
    return result
end

---@param commandersData table
---@return table
local function completeCommandersData(commandersData)
    if not commandersData or type(commandersData) ~= "table" then
        return {}
    end
    local result = {}
    for id, cmdr in pairs(commandersData) do
        if type(cmdr) == "table" then
            local complete = deepCopy(cmdr)
            for field, default in pairs(DEFAULT_COMMANDER_FIELDS) do
                if complete[field] == nil then
                    complete[field] = type(default) == "table" and {} or default
                end
            end
            complete.id = id
            complete.v3_migrated = true
            result[id] = complete
        else
            result[id] = { id = id, v3_migrated = true }
            for field, default in pairs(DEFAULT_COMMANDER_FIELDS) do
                result[id][field] = type(default) == "table" and {} or default
            end
        end
    end
    return result
end

---@param data table
---@return table, string
local function convertV2toV3(data)
    if not data or type(data) ~= "table" then return data, "input_invalid" end
    local result = deepCopy(data)
    result.t = remapTechTree(result.t or result.tech)
    result.b = expandBaseLevels(result.b or result.buildings)
    result.c = completeCommandersData(result.c or result.commanders)
    if result.planets and type(result.planets) == "table" then
        for _, planet in pairs(result.planets) do
            if type(planet) == "table" then
                planet.v3_level = tonumber(planet.level) or 1
                planet.v3_colonized = planet.colonized ~= nil and planet.colonized or false
            end
        end
    end
    if result.p and type(result.p) == "table" then
        for _, planet in pairs(result.p) do
            if type(planet) == "table" then
                planet.v3_level = tonumber(planet.level) or 1
                planet.v3_colonized = planet.colonized ~= nil and planet.colonized or false
            end
        end
    end
    result.__meta = result.__meta or {}
    result.__meta.version = 3
    result.__meta.migratedFromV2 = true
    result.__meta.migratedAt = os and os.time() or 0
    result.__meta.checksum = computeChecksum(result)
    result.__meta.v3_tree_version = "v3"
    return result, "ok"
end

---@param slotData table
---@return table
local function createBackup(slotData)
    if not slotData then return {} end
    local backup = {
        original = deepCopy(slotData),
        timestamp = os and os.time() or 0,
        version = detectVersion(slotData),
        checksum = computeChecksum(slotData),
    }
    return backup
end

---@param version number
---@return number
local function nextVersion(version)
    if version == 1 then return 2 end
    if version == 2 then return 3 end
    return version
end

---@param data table
---@return table, string, number
function SaveMigrationTool.migrate(data)
    if not data or type(data) ~= "table" then
        local entry = {
            status = SaveMigrationTool.STATUS_FAILED,
            fromVersion = 0,
            toVersion = 0,
            timestamp = os and os.time() or 0,
            error = "invalid_input",
        }
        table.insert(migrationHistory, entry)
        currentStatus = entry
        return data or {}, "invalid_input", 0
    end
    local startVersion = detectVersion(data)
    local backup = createBackup(data)
    local working = deepCopy(data)
    local lastStatus = SaveMigrationTool.STATUS_SUCCESS
    local errMsg = nil
    local version = startVersion
    local ok, converted, err = pcall(function()
        while version < SaveMigrationTool.CURRENT_VERSION do
            if version == 1 then
                local r, e = convertV1toV2(working)
                if e ~= "ok" then return nil, "v1_to_v2_failed" end
                working = r
                version = 2
            elseif version == 2 then
                local r, e = convertV2toV3(working)
                if e ~= "ok" then return nil, "v2_to_v3_failed" end
                working = r
                version = 3
            else
                break
            end
        end
        return working, nil
    end)
    if not ok then
        lastStatus = SaveMigrationTool.STATUS_ROLLBACK
        errMsg = "exception: " .. tostring(converted)
        working = deepCopy(backup.original)
        version = startVersion
    elseif err then
        lastStatus = SaveMigrationTool.STATUS_ROLLBACK
        errMsg = err
        working = deepCopy(backup.original)
        version = startVersion
    else
        working = converted
        local ok2, cs = pcall(function() return computeChecksum(working) end)
        if ok2 and type(working) == "table" then
            working.__meta = working.__meta or {}
            working.__meta.checksum = cs
        end
        lastStatus = SaveMigrationTool.STATUS_SUCCESS
    end
    local entry = {
        status = lastStatus,
        fromVersion = startVersion,
        toVersion = version,
        timestamp = os and os.time() or 0,
        backup = backup,
        error = errMsg,
    }
    table.insert(migrationHistory, entry)
    currentStatus = entry
    return working, lastStatus, version
end

---@param data table
---@return number
function SaveMigrationTool.detectSaveVersion(data)
    return detectVersion(data)
end

---@param data table
---@return number
function SaveMigrationTool.computeChecksum(data)
    return computeChecksum(data)
end

---@return table|nil
function SaveMigrationTool.getMigrationStatus()
    return currentStatus
end

---@return table
function SaveMigrationTool.getMigrationHistory()
    local history = {}
    for i = 1, #migrationHistory do
        history[i] = migrationHistory[i]
    end
    return history
end

---@return boolean
function SaveMigrationTool.clearHistory()
    migrationHistory = {}
    currentStatus = nil
    return true
end

---@param data table
---@param targetVersion number
---@return table, string, number
function SaveMigrationTool.migrateTo(data, targetVersion)
    targetVersion = tonumber(targetVersion) or SaveMigrationTool.CURRENT_VERSION
    if targetVersion > SaveMigrationTool.CURRENT_VERSION then
        targetVersion = SaveMigrationTool.CURRENT_VERSION
    end
    if not data or type(data) ~= "table" then
        return data or {}, SaveMigrationTool.STATUS_FAILED, 0
    end
    local startVersion = detectVersion(data)
    if startVersion >= targetVersion then
        return data, SaveMigrationTool.STATUS_SUCCESS, startVersion
    end
    local result, status, version = SaveMigrationTool.migrate(data)
    if version > targetVersion then
        return result, status, version
    end
    return result, status, version
end

return SaveMigrationTool
