--[[
SaveSlotSystem.lua - 多槽存档系统
V2.7 P3-2
支持多槽手动/自动存档
]]

local SaveSlotSystem = {}

SaveSlotSystem.MAX_SAVE_SLOTS = 5
SaveSlotSystem.AUTO_SAVE_SLOT = 0

local runtimeSlots = {}

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

function SaveSlotSystem.saveToSlot(slotId, gameData)
    slotId = tonumber(slotId) or slotId
    local slot = getSlotInternal(slotId)
    if not slot then return false, "无效存档槽" end

    slot.playerName = (gameData and gameData.playerName) or slot.playerName or "玩家"
    slot.saveTime = nowTimestamp()
    slot.playTime = (gameData and gameData.playTime) or slot.playTime or 0
    slot.currentWave = (gameData and gameData.currentWave) or 0
    slot.currentChapter = (gameData and gameData.currentChapter) or 1
    slot.resourcesSnapshot = (gameData and gameData.resources) and cloneSnapshot(gameData.resources) or {}
    slot.difficulty = (gameData and gameData.difficulty) or slot.difficulty or "normal"
    slot.mapSeed = (gameData and gameData.mapSeed) or slot.mapSeed or 0
    slot.slotName = (gameData and gameData.slotName) or ("存档 " .. tostring(slotId) .. " - " .. slot.playerName)
    slot.gameData = cloneSnapshot(gameData)
    slot.exists = true

    print("[SaveSlot] 已保存到槽 " .. tostring(slotId) .. " 于 " .. formatTime(slot.saveTime))
    return true, slot
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
