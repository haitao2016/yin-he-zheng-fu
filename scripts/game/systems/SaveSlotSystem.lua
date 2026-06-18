---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
SaveSlotSystem.lua - 多槽存档系统
V3.0 P3-P2-1
支持多槽手动/自动存档
增强：压缩存档、增量存档、存档元数据
]]

local SaveSlotSystem = {}

SaveSlotSystem.MAX_SAVE_SLOTS = 5
SaveSlotSystem.AUTO_SAVE_SLOT = 0

-- P3-P2-1: 游戏版本（用于存档兼容性检查）
SaveSlotSystem.GAME_VERSION = "3.0.0"

-- 默认值表（用于排除默认字段，节省存档空间）
SaveSlotSystem.DEFAULT_VALUES = {
    resources = { metal = 0, esource = 0, nuclear = 0, crystal = 0, credits = 0 },
    fleet = { ships = {} },
    planets = {},
    research = { unlocked = {} },
    achievements = {},
}

local runtimeSlots = {}
local lastSaveHash = {}  -- slotId -> 上次存档的数据 hash（用于增量存档）

-- P3-P2-1: 计算数据表 hash（用于增量存档比较）
local function dataHash(data)
    if type(data) ~= "table" then return tostring(data) end
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        parts[#parts + 1] = tostring(k) .. "=" .. dataHash(data[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- P3-P2-1: 压缩存档数据（排除默认值字段，减少存档体积）
local function compressSaveData(data)
    if type(data) ~= "table" then return data end
    local result = {}
    for k, v in pairs(data) do
        if type(v) == "table" then
            local compressed = compressSaveData(v)
            -- 跳过空表
            if next(compressed) then
                result[k] = compressed
            end
        elseif v ~= nil and v ~= 0 and v ~= false and v ~= "" then
            result[k] = v
        end
    end
    return result
end

-- P3-P2-1: 检查数据是否有变化（用于增量存档）
local function hasChanges(slotId, gameData)
    local currentHash = dataHash(gameData)
    local lastHash = lastSaveHash[slotId]
    if lastHash and currentHash == lastHash then
        return false  -- 没有变化
    end
    lastSaveHash[slotId] = currentHash
    return true
end

local function nowTimestamp()
    if os and os.time then return os.time() end
    return 0
end

local function formatTime(ts)
    if not ts or ts == 0 then return "未知时间" end
    if os and os.date then
        local ok, s = pcall(os.date, "%Y-%m-%d %H:%M:%S", ts)
        if ok and s then return s end
    end
    return tostring(ts)
end

local function getSlotInternal(slotId)
    if slotId == nil then return nil end
    local key = tostring(slotId)
    if not runtimeSlots[key] then
        runtimeSlots[key] = {
            id = slotId,
            slotName = "存档 " .. tostring(slotId),
            playerName = "",
            saveTime = 0,
            playTime = 0,
            currentWave = 0,
            currentChapter = 1,
            resourcesSnapshot = {},
            difficulty = "normal",
            mapSeed = 0,
            gameData = nil,
            exists = false,
        }
    end
    return runtimeSlots[key]
end

local function cloneSnapshot(gameData)
    if not gameData then return {} end
    local snap = {}
    for k, v in pairs(gameData) do
        local tk = type(v)
        if tk == "number" or tk == "string" or tk == "boolean" then
            snap[k] = v
        elseif tk == "table" and k ~= "__cache" then
            snap[k] = cloneSnapshot(v)
        end
    end
    return snap
end

function SaveSlotSystem.saveToSlot(slotId, gameData, opts)
    slotId = tonumber(slotId) or slotId
    opts = opts or {}
    local slot = getSlotInternal(slotId)
    if not slot then return false, "无效存档槽" end

    -- P3-P2-1: 增量存档检查（除非强制保存）
    if not opts.force and not hasChanges(slotId, gameData) then
        print("[SaveSlot] 槽 " .. tostring(slotId) .. " 数据无变化，跳过存档")
        return true, slot, "unchanged"
    end

    slot.playerName = (gameData and gameData.playerName) or slot.playerName or "玩家"
    slot.saveTime = nowTimestamp()
    slot.playTime = (gameData and gameData.playTime) or slot.playTime or 0
    slot.currentWave = (gameData and gameData.currentWave) or 0
    slot.currentChapter = (gameData and gameData.currentChapter) or 1
    slot.resourcesSnapshot = (gameData and gameData.resources) and cloneSnapshot(gameData.resources) or {}
    slot.difficulty = (gameData and gameData.difficulty) or slot.difficulty or "normal"
    slot.mapSeed = (gameData and gameData.mapSeed) or slot.mapSeed or 0
    slot.slotName = (gameData and gameData.slotName) or ("存档 " .. tostring(slotId) .. " - " .. slot.playerName)

    -- P3-P2-1: 压缩存档数据（排除默认值字段）
    local compressedData = compressSaveData(cloneSnapshot(gameData))
    slot.gameData = compressedData

    -- P3-P2-1: 存档元数据
    slot.metadata = {
        gameVersion = SaveSlotSystem.GAME_VERSION,
        saveTimestamp = slot.saveTime,
        playTimeSeconds = slot.playTime,
        -- P3-P2-1: 云端同步预留字段
        cloudSyncStatus = "local",  -- "local" | "synced" | "pending"
        cloudSyncTime = nil,
    }

    slot.exists = true

    local saveSize = #dataHash(compressedData)  -- 粗略估算
    print("[SaveSlot] 已保存到槽 " .. tostring(slotId) .. " 于 " .. formatTime(slot.saveTime) .. " (版本 " .. SaveSlotSystem.GAME_VERSION .. ")")
    return true, slot, "saved"
end

--- P3-P2-1: 强制保存（忽略增量检查）
function SaveSlotSystem.saveToSlotForce(slotId, gameData)
    return SaveSlotSystem.saveToSlot(slotId, gameData, { force = true })
end

function SaveSlotSystem.autoSave(gameData)
    return SaveSlotSystem.saveToSlot(SaveSlotSystem.AUTO_SAVE_SLOT, gameData)
end

function SaveSlotSystem.loadFromSlot(slotId)
    slotId = tonumber(slotId) or slotId
    local slot = getSlotInternal(slotId)
    if not slot or not slot.exists then
        return nil, "存档槽不存在"
    end
    print("[SaveSlot] 从槽 " .. tostring(slotId) .. " 读取存档")
    return slot.gameData, slot
end

function SaveSlotSystem.deleteSlot(slotId, confirm)
    slotId = tonumber(slotId) or slotId
    local slot = getSlotInternal(slotId)
    if not slot or not slot.exists then
        return false, "存档槽不存在"
    end
    if not confirm then
        return false, "需要确认删除操作"
    end

    runtimeSlots[tostring(slotId)] = {
        id = slotId,
        slotName = "存档 " .. tostring(slotId),
        playerName = "",
        saveTime = 0,
        playTime = 0,
        currentWave = 0,
        currentChapter = 1,
        resourcesSnapshot = {},
        difficulty = "normal",
        mapSeed = 0,
        gameData = nil,
        exists = false,
    }
    print("[SaveSlot] 已删除存档槽 " .. tostring(slotId))
    return true
end

function SaveSlotSystem.getSlot(slotId)
    slotId = tonumber(slotId) or slotId
    local slot = runtimeSlots[tostring(slotId)]
    if not slot or not slot.exists then return nil end
    return {
        id = slot.id,
        slotName = slot.slotName,
        playerName = slot.playerName,
        saveTime = slot.saveTime,
        saveTimeStr = formatTime(slot.saveTime),
        playTime = slot.playTime,
        currentWave = slot.currentWave,
        currentChapter = slot.currentChapter,
        resourcesSnapshot = slot.resourcesSnapshot,
        difficulty = slot.difficulty,
        mapSeed = slot.mapSeed,
        exists = slot.exists,
    }
end

function SaveSlotSystem.listAllSlots()
    local list = {}
    for i = 1, SaveSlotSystem.MAX_SAVE_SLOTS do
        table.insert(list, SaveSlotSystem.getSlot(i))
    end
    return list
end

function SaveSlotSystem.getAutoSaveSlot()
    return SaveSlotSystem.getSlot(SaveSlotSystem.AUTO_SAVE_SLOT)
end

function SaveSlotSystem.serialize()
    local data = {}
    for k, slot in pairs(runtimeSlots) do
        data[k] = {
            id = slot.id,
            slotName = slot.slotName,
            playerName = slot.playerName,
            saveTime = slot.saveTime,
            playTime = slot.playTime,
            currentWave = slot.currentWave,
            currentChapter = slot.currentChapter,
            resourcesSnapshot = slot.resourcesSnapshot,
            difficulty = slot.difficulty,
            mapSeed = slot.mapSeed,
            gameData = slot.gameData,
            exists = slot.exists,
        }
    end
    return data
end

function SaveSlotSystem.deserialize(data)
    runtimeSlots = {}
    if not data then return end
    for k, v in pairs(data) do
        runtimeSlots[k] = v
    end
end

return SaveSlotSystem
