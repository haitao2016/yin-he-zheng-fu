--- ============================================================================
--- game/BlueprintSystem.lua  -- P2-3 V2.5: 战术蓝图系统
--- 保存/加载/分享完整战术配置（阵型+编队构成+模块+指挥官+名称）
--- ============================================================================

local cjson = require("cjson")
local AchievementSystem = require("game.AchievementSystem")

local BlueprintSystem = {}

-- ============================================================================
-- 常量
-- ============================================================================
local MAX_BLUEPRINTS = 5
local SHARE_CODE_LEN = 12
local BASE62_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local FILE_NAME = "blueprints.json"

-- ============================================================================
-- 内部状态
-- ============================================================================
---@type table[]  -- 最多 5 条蓝图
local blueprints_ = {}
---@type table[]  -- 收藏的他人蓝图（从排行榜长按获取）
local bookmarks_ = {}

-- ============================================================================
-- 文件持久化
-- ============================================================================

--- 保存到磁盘
local function saveToFile()
    local data = { blueprints = blueprints_, bookmarks = bookmarks_ }
    local ok, json = pcall(cjson.encode, data)
    if not ok then
        print("[Blueprint] 序列化失败: " .. tostring(json))
        return
    end
    local file = File(FILE_NAME, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(json)
        file:Close()
        print("[Blueprint] 已保存 " .. #blueprints_ .. " 套蓝图")
    end
end

--- 从磁盘加载
local function loadFromFile()
    if not fileSystem:FileExists(FILE_NAME) then return end
    local file = File(FILE_NAME, FILE_READ)
    if not file:IsOpen() then return end
    local json = file:ReadString()
    file:Close()
    if #json == 0 then return end
    local ok, data = pcall(cjson.decode, json)
    if not ok or type(data) ~= "table" then
        print("[Blueprint] 解析失败")
        return
    end
    blueprints_ = data.blueprints or {}
    bookmarks_  = data.bookmarks or {}
    print("[Blueprint] 加载 " .. #blueprints_ .. " 套蓝图, " .. #bookmarks_ .. " 个收藏")
end

-- ============================================================================
-- Base62 分享码编解码
-- ============================================================================

--- 将蓝图数据压缩为紧凑字节串
---@param bp table  蓝图数据
---@return string  二进制字节串
local function packBlueprint(bp)
    -- 格式：名称长度(1B) + 名称(UTF8) + 编队数(1B) + 每编队{shipCount(1B) + ships(shipType 1B + count 1B) + moduleKey长(1B) + moduleKey} + 阵型数(1B) + 阵型槽{r(1B) + c(1B) + typeIdx(1B)}
    -- 使用 cjson 压缩后 base62 编码（简化实现）
    local ok, json = pcall(cjson.encode, {
        n = bp.name,
        f = bp.fleets,
        m = bp.modules,
        fm = bp.formation,
        c = bp.commanderSpec,
    })
    if not ok then return "" end
    return json --[[@as string]]
end

--- 从紧凑字节串恢复蓝图
---@param packed string
---@return table|nil
local function unpackBlueprint(packed)
    local ok, data = pcall(cjson.decode, packed)
    if not ok or type(data) ~= "table" then return nil end
    return {
        name          = data.n or "导入蓝图",
        fleets        = data.f or {},
        modules       = data.m or {},
        formation     = data.fm,
        commanderSpec = data.c,
    }
end

--- Base62 编码字节串
---@param bytes string
---@return string  base62 字符串
local function base62Encode(bytes)
    -- 将字节串视为大整数，逐位取模
    -- 简化：对 JSON 字符串做简单哈希映射 + 校验位
    -- 实际采用对称编码：分段 6 字节 → 8 字符
    local result = {}
    local len = #bytes
    for i = 1, len, 5 do
        local chunk = 0
        for j = 0, 4 do
            local idx = i + j
            local b = (idx <= len) and string.byte(bytes, idx) or 0
            chunk = chunk * 256 + b
        end
        -- 5 bytes = 40 bits → ceil(40/5.95) ≈ 7 base62 chars
        for _ = 1, 7 do
            local rem = chunk % 62
            result[#result + 1] = string.sub(BASE62_CHARS, rem + 1, rem + 1)
            chunk = math.floor(chunk / 62)
        end
    end
    -- 截断/填充到固定长度
    local code = table.concat(result)
    if #code >= SHARE_CODE_LEN then
        return string.sub(code, 1, SHARE_CODE_LEN)
    end
    -- 填充
    while #code < SHARE_CODE_LEN do
        code = code .. "0"
    end
    return code
end

--- Base62 解码为字节串
---@param code string  12 字符分享码
---@return string  原始字节串
local function base62Decode(code)
    if #code ~= SHARE_CODE_LEN then return "" end
    local result = {}
    local pos = 1
    while pos <= #code do
        local segLen = math.min(7, #code - pos + 1)
        local chunk = 0
        -- 反向：最后编码的字符在高位
        for j = segLen, 1, -1 do
            local ch = string.sub(code, pos + j - 1, pos + j - 1)
            local val = string.find(BASE62_CHARS, ch, 1, true)
            if not val then val = 1 end
            val = val - 1
            chunk = chunk * 62 + val
        end
        -- 提取 5 字节
        local bytes5 = {}
        for _ = 1, 5 do
            bytes5[#bytes5 + 1] = chunk % 256
            chunk = math.floor(chunk / 256)
        end
        -- 反序写入
        for j = #bytes5, 1, -1 do
            result[#result + 1] = string.char(bytes5[j])
        end
        pos = pos + segLen
    end
    return table.concat(result)
end

--- 生成分享码（完整流程：蓝图 → JSON → Base62 分段编码）
--- 由于完整蓝图 JSON 可能很长，实际分享码存储在本地映射表
--- 分享码功能使用简化方案：本地保存完整数据，码为摘要索引
---@param bp table
---@return string  12 位分享码
local function generateShareCode(bp)
    -- 使用数据哈希生成确定性码
    local packed = packBlueprint(bp)
    if #packed == 0 then return "000000000000" end
    -- 简单哈希：FNV-1a 变体
    local h = 2166136261
    for i = 1, #packed do
        h = ((h ~ string.byte(packed, i)) * 16777619) & 0xFFFFFFFF
    end
    -- 加入阵型和编队信息的额外熵
    local extra = #(bp.fleets or {}) * 7 + #(bp.formation or {}) * 13
    h = ((h ~ extra) * 16777619) & 0xFFFFFFFF
    -- 扩展到 12 字符
    local code = {}
    local seed = h
    for _ = 1, SHARE_CODE_LEN do
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
        local idx = (seed % 62) + 1
        code[#code + 1] = string.sub(BASE62_CHARS, idx, idx)
    end
    return table.concat(code)
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化（游戏启动/恢复存档时调用）
function BlueprintSystem.Init()
    blueprints_ = {}
    bookmarks_  = {}
    loadFromFile()
end

--- 获取所有蓝图
---@return table[]
function BlueprintSystem.GetAll()
    return blueprints_
end

--- 获取蓝图数量
---@return number
function BlueprintSystem.Count()
    return #blueprints_
end

--- 是否还能保存新蓝图
---@return boolean
function BlueprintSystem.CanSave()
    return #blueprints_ < MAX_BLUEPRINTS
end

--- 保存当前配置为蓝图
---@param name string  蓝图名称
---@param fm table  FleetManager 实例
---@param formationSlot table|nil  阵型数据 { {r,c,t}, ... }
---@param commanderId number|nil  指挥官 ID
---@return boolean success, string msg
function BlueprintSystem.SaveCurrent(name, fm, formationSlot, commanderId)
    if #blueprints_ >= MAX_BLUEPRINTS then
        return false, "蓝图已满（上限" .. MAX_BLUEPRINTS .. "套）"
    end
    if not name or #name == 0 then
        name = "蓝图 " .. (#blueprints_ + 1)
    end
    -- 收集编队数据
    local fleets = {}
    for i, fl in ipairs(fm.fleets) do
        local ships = {}
        for _, e in ipairs(fl.ships) do
            ships[#ships + 1] = { shipType = e.shipType, count = e.count }
        end
        fleets[i] = { name = fl.name, ships = ships }
    end
    -- 收集模块数据
    local modules = {}
    for i, fl in ipairs(fm.fleets) do
        if fl.modules then
            modules[i] = {}
            for st, mKey in pairs(fl.modules) do
                modules[i][st] = mKey
            end
        end
    end
    -- 指挥官专精（不保存 id，保存 spec 以便跨存档应用）
    local cmdSpec = nil
    if commanderId then
        local Commander = require("game.CommanderSystem")
        local cmd = Commander.GetById(commanderId)
        if cmd then cmdSpec = cmd.spec end
    end
    local bp = {
        name          = name,
        fleets        = fleets,
        modules       = modules,
        formation     = formationSlot,
        commanderSpec = cmdSpec,
        savedAt       = os.time and os.time() or 0,
        shareCode     = nil,  -- 懒生成
    }
    blueprints_[#blueprints_ + 1] = bp
    saveToFile()
    print(string.format("[Blueprint] 保存蓝图 '%s' (第%d套)", name, #blueprints_))
    -- P2-3: 触发成就
    AchievementSystem.Check("blueprint_save", { totalBlueprints = #blueprints_ })
    return true, string.format("📋 蓝图 \"%s\" 已保存！(%d/%d)", name, #blueprints_, MAX_BLUEPRINTS)
end

--- 删除指定蓝图
---@param idx number  1-based
---@return boolean
function BlueprintSystem.Delete(idx)
    if idx < 1 or idx > #blueprints_ then return false end
    table.remove(blueprints_, idx)
    saveToFile()
    return true
end

--- 覆盖指定槽位蓝图
---@param idx number
---@param name string
---@param fm table
---@param formationSlot table|nil
---@param commanderId number|nil
---@return boolean, string
function BlueprintSystem.Overwrite(idx, name, fm, formationSlot, commanderId)
    if idx < 1 or idx > #blueprints_ then
        return false, "无效槽位"
    end
    -- 先删除再存入
    table.remove(blueprints_, idx)
    -- 临时解除上限检查
    local saved = #blueprints_
    local ok, msg = BlueprintSystem.SaveCurrent(name, fm, formationSlot, commanderId)
    if ok and #blueprints_ > saved + 1 then
        -- 移动到正确位置（SaveCurrent 会 append 到末尾）
        local bp = table.remove(blueprints_)
        table.insert(blueprints_, idx, bp)
        saveToFile()
    end
    return ok, msg
end

--- 应用蓝图到编队管理器
---@param idx number  蓝图索引
---@param fm table  FleetManager 实例
---@return boolean success, string msg
function BlueprintSystem.Apply(idx, fm)
    local bp = blueprints_[idx]
    if not bp then return false, "蓝图不存在" end

    -- 应用编队构成
    for i, bpFleet in ipairs(bp.fleets) do
        if fm.fleets[i] then
            -- 只覆盖有船的舰队，保留名称
            if bpFleet.ships and #bpFleet.ships > 0 then
                -- 先把当前编队的船放回储备
                for _, e in ipairs(fm.fleets[i].ships) do
                    fm.reserve[e.shipType] = (fm.reserve[e.shipType] or 0) + e.count
                end
                fm.fleets[i].ships = {}
                -- 从储备分配蓝图中的船
                for _, entry in ipairs(bpFleet.ships) do
                    local avail = fm.reserve[entry.shipType] or 0
                    local assign = math.min(entry.count, avail)
                    if assign > 0 then
                        fm.fleets[i].ships[#fm.fleets[i].ships + 1] = {
                            shipType = entry.shipType,
                            count = assign,
                        }
                        fm.reserve[entry.shipType] = avail - assign
                    end
                end
            end
        end
    end

    -- 应用模块（仅当库存中有对应模块时）
    if bp.modules then
        for i, mods in pairs(bp.modules) do
            local fi = tonumber(i) or i
            if fm.fleets[fi] then
                for st, mKey in pairs(mods) do
                    -- 检查库存
                    local owned = fm.moduleInventory and fm.moduleInventory[mKey] or 0
                    if owned > 0 or (fm.fleets[fi].modules and fm.fleets[fi].modules[st] == mKey) then
                        if not fm.fleets[fi].modules then fm.fleets[fi].modules = {} end
                        fm.fleets[fi].modules[st] = mKey
                    end
                end
            end
        end
    end

    -- 应用阵型（加载到 FormationEditor）
    if bp.formation and #bp.formation > 0 then
        local FEditor = require("game.ui.FormationEditor")
        -- 写入第一个空槽或覆盖当前槽
        local slots = FEditor.GetSlots()
        local targetSlot = 1
        for s = 1, 3 do
            if not slots[s] or #slots[s] == 0 then
                targetSlot = s
                break
            end
        end
        slots[targetSlot] = bp.formation
        FEditor.LoadSlots(slots)
        FEditor.Save()
    end

    print(string.format("[Blueprint] 应用蓝图 '%s'", bp.name))
    return true, string.format("✅ 蓝图 \"%s\" 已应用！", bp.name)
end

--- 获取/生成蓝图分享码
---@param idx number
---@return string|nil
function BlueprintSystem.GetShareCode(idx)
    local bp = blueprints_[idx]
    if not bp then return nil end
    if not bp.shareCode then
        bp.shareCode = generateShareCode(bp)
        saveToFile()
        -- P2-3: 首次生成分享码触发成就
        AchievementSystem.Check("blueprint_share", { shared = 1 })
    end
    return bp.shareCode
end

--- 从分享码导入蓝图（本地码表查找 / 在线查询占位）
--- 简化实现：分享码与蓝图数据一起保存在本地，
--- 其他玩家的蓝图通过排行榜长按获取并保存到 bookmarks
---@param code string  12 位分享码
---@return boolean, string
function BlueprintSystem.ImportFromCode(code)
    if not code or #code ~= SHARE_CODE_LEN then
        return false, "无效分享码（需要" .. SHARE_CODE_LEN .. "位）"
    end
    -- 在收藏中查找
    for _, bm in ipairs(bookmarks_) do
        if bm.shareCode == code then
            if #blueprints_ >= MAX_BLUEPRINTS then
                return false, "蓝图已满，无法导入"
            end
            local bp = {
                name          = bm.name or "导入蓝图",
                fleets        = bm.fleets or {},
                modules       = bm.modules or {},
                formation     = bm.formation,
                commanderSpec = bm.commanderSpec,
                savedAt       = os.time and os.time() or 0,
                shareCode     = code,
            }
            blueprints_[#blueprints_ + 1] = bp
            saveToFile()
            -- P2-3: 导入成就
            AchievementSystem.Check("blueprint_import", { imported = 1 })
            return true, string.format("📥 蓝图 \"%s\" 导入成功！", bp.name)
        end
    end
    -- 本地蓝图中查找（自己的码分享给自己）
    for _, bp in ipairs(blueprints_) do
        if bp.shareCode == code then
            return false, "该蓝图已存在"
        end
    end
    return false, "未找到该分享码对应的蓝图"
end

--- 从排行榜收藏蓝图（长按玩家条目 → 保存到 bookmarks）
---@param blueprintData table  从排行榜获取的蓝图数据
---@return boolean, string
function BlueprintSystem.Bookmark(blueprintData)
    if not blueprintData then return false, "数据为空" end
    -- 检查重复
    local code = blueprintData.shareCode
    if code then
        for _, bm in ipairs(bookmarks_) do
            if bm.shareCode == code then
                return false, "已收藏该蓝图"
            end
        end
    end
    -- 生成分享码（如果没有）
    if not code then
        code = generateShareCode(blueprintData)
        blueprintData.shareCode = code
    end
    bookmarks_[#bookmarks_ + 1] = blueprintData
    saveToFile()
    -- P2-3: 收藏成就
    AchievementSystem.Check("blueprint_bookmark", { bookmarks = #bookmarks_ })
    return true, "⭐ 已收藏蓝图！"
end

--- 获取收藏列表
---@return table[]
function BlueprintSystem.GetBookmarks()
    return bookmarks_
end

--- 删除收藏
---@param idx number
function BlueprintSystem.RemoveBookmark(idx)
    if idx >= 1 and idx <= #bookmarks_ then
        table.remove(bookmarks_, idx)
        saveToFile()
    end
end

--- 构建可分享的蓝图数据（用于排行榜展示）
---@param idx number
---@return table|nil
function BlueprintSystem.ExportForLeaderboard(idx)
    local bp = blueprints_[idx]
    if not bp then return nil end
    return {
        name          = bp.name,
        fleets        = bp.fleets,
        modules       = bp.modules,
        formation     = bp.formation,
        commanderSpec = bp.commanderSpec,
        shareCode     = BlueprintSystem.GetShareCode(idx),
    }
end

--- 序列化（用于存档系统）
---@return table
function BlueprintSystem.Serialize()
    return { blueprints = blueprints_, bookmarks = bookmarks_ }
end

--- 反序列化（从存档恢复）
---@param data table|nil
function BlueprintSystem.Deserialize(data)
    if type(data) ~= "table" then return end
    blueprints_ = data.blueprints or {}
    bookmarks_  = data.bookmarks or {}
    saveToFile()  -- 同步到磁盘
end

--- 获取最大蓝图数
---@return number
function BlueprintSystem.GetMaxSlots()
    return MAX_BLUEPRINTS
end

return BlueprintSystem
