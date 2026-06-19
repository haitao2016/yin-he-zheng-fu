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
SaveSlotSystem.SAVE_FORMAT_VERSION = 2  -- P2-3: 存档格式版本

-- 默认值表（用于排除默认字段，节省存档空间）
SaveSlotSystem.DEFAULT_VALUES = {
    resources = { metal = 0, esource = 0, nuclear = 0, crystal = 0, credits = 0 },
    fleet = { ships = {} },
    planets = {},
    research = { unlocked = {} },
    achievements = {},
}

-- P2-3: 存档优化配置
SaveSlotSystem.OPTIMIZATION = {
    enableCompression = true,
    enableChecksum = true,
    enableDeltaSave = true,
    maxDeltaSavesPerSlot = 3,
    compressThresholdBytes = 1024,
}

local runtimeSlots = {}
local lastSaveHash = {}

-- ============================================================================
-- P2-3: 增强的压缩与校验算法
-- ============================================================================

-- 简单的 32 位校验和（类 FNV-1a）
local function checksum32(data)
    local hash = 2166136261
    local s = type(data) == "string" and data or (data and tostring(data) or "")
    for i = 1, #s do
        local b = string.byte(s, i)
        hash = (hash ~ b) % 4294967296
        hash = (hash * 16777619) % 4294967296
    end
    return hash
end

-- P2-3: 键名压缩映射（将常用键名替换为短标识符，显著减少存档体积）
local KEY_COMPRESS_MAP = {
    resources = "r",
    fleet = "f",
    planets = "p",
    research = "rs",
    achievements = "a",
    playerName = "pn",
    playTime = "pt",
    currentWave = "cw",
    currentChapter = "cc",
    mapSeed = "ms",
    difficulty = "d",
    ships = "s",
    unlocked = "u",
    slotName = "sn",
    health = "h",
    attack = "at",
    defense = "df",
    speed = "sp",
    type = "tp",
    level = "lv",
    name = "nm",
    owner = "ow",
    colonized = "cl",
    metal = "m",
    energy = "e",
    crystal = "cr",
    nuclear = "nc",
    credits = "cd",
    x = "x",
    y = "y",
    id = "i",
}
local KEY_DECOMPRESS_MAP = {}
for long, short in pairs(KEY_COMPRESS_MAP) do KEY_DECOMPRESS_MAP[short] = long end

-- P2-3: 递归压缩数据（键名压缩 + 默认值省略）
local function compressSaveDataV2(data, depth)
    depth = depth or 0
    if depth > 100 then return data end  -- 防止递归溢出
    if type(data) ~= "table" then return data end
    local result = {}
    for k, v in pairs(data) do
        if k == "__cache" then goto continue end  -- 跳过缓存字段
        local key = KEY_COMPRESS_MAP[k] or k
        if type(v) == "table" then
            local compressed = compressSaveDataV2(v, depth + 1)
            if next(compressed) then result[key] = compressed end
        elseif v ~= nil and v ~= 0 and v ~= false and v ~= "" then
            result[key] = v
        end
        ::continue::
    end
    return result
end

-- P2-3: 解压存档数据
local function decompressSaveDataV2(data, depth)
    depth = depth or 0
    if depth > 100 then return data end
    if type(data) ~= "table" then return data end
    local result = {}
    for k, v in pairs(data) do
        local key = KEY_DECOMPRESS_MAP[k] or k
        if type(v) == "table" then
            result[key] = decompressSaveDataV2(v, depth + 1)
        else
            result[key] = v
        end
    end
    return result
end

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

local function hasChanges(slotId, gameData)
    local currentHash = dataHash(gameData)
    local lastHash = lastSaveHash[slotId]
    if lastHash and currentHash == lastHash then
        return false
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

    -- P2-3: 使用 V2 压缩格式（键名压缩 + 默认值省略）
    local compressedData = compressSaveDataV2(cloneSnapshot(gameData))
    slot.gameData = compressedData

    -- P2-3: 存档元数据与校验和
    local chksum = SaveSlotSystem.OPTIMIZATION.enableChecksum and checksum32(dataHash(compressedData)) or nil
    slot.metadata = {
        gameVersion = SaveSlotSystem.GAME_VERSION,
        saveFormatVersion = SaveSlotSystem.SAVE_FORMAT_VERSION,
        saveTimestamp = slot.saveTime,
        playTimeSeconds = slot.playTime,
        checksum = chksum,
        compressionFormat = "v2",
        dataSize = #dataHash(compressedData),  -- 粗略估算
        cloudSyncStatus = "local",
        cloudSyncTime = nil,
    }

    slot.exists = true

    print("[SaveSlot] 已保存到槽 " .. tostring(slotId) .. " 于 " .. formatTime(slot.saveTime) ..
          " (版本 " .. SaveSlotSystem.GAME_VERSION .. ", 格式 v" .. SaveSlotSystem.SAVE_FORMAT_VERSION .. ")")
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

    -- P2-3: 校验和验证
    if slot.metadata and slot.metadata.checksum and SaveSlotSystem.OPTIMIZATION.enableChecksum then
        local expected = slot.metadata.checksum
        local actual = checksum32(dataHash(slot.gameData))
        if expected ~= actual then
            print("[SaveSlot] 警告: 校验和不匹配 (expected=" .. tostring(expected) .. ", actual=" .. tostring(actual) .. ")")
        end
    end

    -- P2-3: 解压 V2 格式（如果需要）
    local formatVersion = (slot.metadata and slot.metadata.saveFormatVersion) or 1
    if formatVersion >= 2 then
        local decompressed = decompressSaveDataV2(slot.gameData)
        print("[SaveSlot] 使用 V2 压缩格式解压")
        return decompressed, slot
    else
        -- V1 格式（直接返回）
        return slot.gameData, slot
    end
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

-- P2-3: 获取存档统计信息（所有槽的汇总）
function SaveSlotSystem.getSaveStats()
    local totalSlots = SaveSlotSystem.MAX_SAVE_SLOTS
    local used = 0
    local latest = nil
    local oldest = nil
    local totalSize = 0
    for i = 1, totalSlots do
        local slot = SaveSlotSystem.getSlot(i)
        if slot then
            used = used + 1
            totalSize = totalSize + (slot.metadata and slot.metadata.dataSize or 0)
            if not latest or slot.saveTime > latest.saveTime then latest = slot end
            if not oldest or slot.saveTime < oldest.saveTime then oldest = slot end
        end
    end
    return {
        totalSlots = totalSlots,
        usedSlots = used,
        freeSlots = totalSlots - used,
        latestSlot = latest,
        oldestSlot = oldest,
        totalSize = totalSize,
        formatVersion = SaveSlotSystem.SAVE_FORMAT_VERSION,
        gameVersion = SaveSlotSystem.GAME_VERSION,
    }
end

-- P2-3: 验证存档完整性
function SaveSlotSystem.validateSlot(slotId)
    slotId = tonumber(slotId) or slotId
    local slot = runtimeSlots[tostring(slotId)]
    if not slot or not slot.exists then return false, "存档不存在" end
    if not slot.metadata then return false, "缺少元数据" end
    if slot.metadata.gameVersion and slot.metadata.gameVersion ~= SaveSlotSystem.GAME_VERSION then
        print("[SaveSlot] 警告: 游戏版本不匹配")
    end
    if slot.metadata.checksum then
        local actual = checksum32(dataHash(slot.gameData))
        if slot.metadata.checksum ~= actual then
            return false, "校验和不匹配: 存档可能损坏"
        end
    end
    return true, "存档完整"
end

-- P2-3: 复制存档到另一个槽
function SaveSlotSystem.copySlot(fromSlotId, toSlotId, newSlotName)
    local data, slot = SaveSlotSystem.loadFromSlot(fromSlotId)
    if not data then return false, slot end
    local copyData = cloneSnapshot(data)
    if newSlotName then copyData.slotName = newSlotName end
    copyData.slotName = (newSlotName and newSlotName or (slot and slot.slotName or "复制")) .. " (副本)"
    return SaveSlotSystem.saveToSlotForce(toSlotId, copyData)
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
