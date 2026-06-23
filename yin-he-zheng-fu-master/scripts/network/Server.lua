-- ============================================================================
-- network/Server.lua  -- 银河征服 服务端：跟踪在线玩家并广播列表
-- Headless 模式，无游戏逻辑，只负责：
--   1. 管理连接生命周期
--   2. 通过 ClientIdentity 获取真实昵称
--   3. 每 5 秒广播一次在线玩家列表
-- ============================================================================
local Shared = require("network.Shared")

local Server = {}

local SERVER_MAX_PLAYERS = 100   -- 与 settings.json max_players 保持一致
local SAVE_KEY           = "galaxy_save"   -- serverCloud 存储键名

-- 场景（网络同步必须有 Scene）
---@type Scene
local scene_ = nil

-- 在线玩家表  [connKey] = { connection, nickname, status }
local players_ = {}

-- 广播计时器
local broadcastTimer_ = 0
local BROADCAST_INTERVAL = 5.0  -- 秒

-- ============================================================================
-- 工具
-- ============================================================================
local function connKey(conn)
    return tostring(conn:GetAddress()) .. ":" .. tostring(conn:GetPort())
end

-- ============================================================================
-- 广播玩家列表到所有客户端
-- ============================================================================
local function broadcastPlayerList()
    local eventData = VariantMap()
    local count = 0
    local connections = network:GetClientConnections()
    for _, conn in ipairs(connections) do
        local key = connKey(conn)
        local info = players_[key]
        if info then
            local name    = info.nickname or "指挥官"
            local latency = math.floor(conn.roundTripTime)
            local status  = info.status  or "在线"
            eventData["P" .. count .. "Name"]    = Variant(name)
            eventData["P" .. count .. "Latency"] = Variant(latency)
            eventData["P" .. count .. "Status"]  = Variant(status)
            count = count + 1
        end
    end
    eventData["Count"] = Variant(count)
    if count > 0 then
        network:BroadcastRemoteEvent(Shared.EVENTS.PLAYER_LIST, true, eventData)
    end
end

-- ============================================================================
-- 连接事件
-- ============================================================================
local function handleClientConnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local key  = connKey(conn)
    -- 不在此处设置 scene，等 ClientReady 后再设置
    players_[key] = { connection = conn, nickname = nil, status = "连接中" }
    print("[Server] 客户端连接: " .. key)
end

local function handleClientDisconnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local key  = connKey(conn)
    players_[key] = nil
    print("[Server] 客户端断开: " .. key)
    broadcastPlayerList()
end

-- ClientIdentity：客户端认证完成，可获取 user_id 查询昵称
local function handleClientIdentity(eventType, eventData)
    local conn     = eventData["Connection"]:GetPtr("Connection")
    local identity = conn.identity
    local key      = connKey(conn)

    local userIdVar = identity["user_id"]
    if not userIdVar or userIdVar:IsEmpty() then
        if players_[key] then players_[key].nickname = "指挥官" end
        return
    end

    local userId = userIdVar:GetInt64()
    GetUserNickname({
        userIds   = { userId },
        onSuccess = function(nicknames)
            if players_[key] and nicknames[1] then
                players_[key].nickname = nicknames[1].nickname
                players_[key].status   = "在线"
                print("[Server] 玩家昵称: " .. players_[key].nickname)
                broadcastPlayerList()
            end
        end,
        onError = function()
            if players_[key] then
                players_[key].nickname = "指挥官"
            end
        end,
    })
end

-- ClientReady：客户端准备完毕，此时才关联场景（触发全量同步）
local function handleClientReady(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local key  = connKey(conn)
    conn.scene = scene_
    print("[Server] 已关联场景: " .. key)
    broadcastPlayerList()
end

-- ============================================================================
-- 云存档处理
-- ============================================================================

-- 获取连接对应的 userId（若未认证返回 nil）
local function getUid(conn)
    local identity = conn.identity
    local v = identity and identity["user_id"]
    if not v or v:IsEmpty() then return nil end
    return v:GetInt64()
end

-- 客户端请求保存存档
local function handleSaveRequest(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local uid  = getUid(conn)
    if not uid then
        local ack = VariantMap()
        ack["Ok"]  = Variant(false)
        ack["Msg"] = Variant("未认证，无法存档")
        conn:SendRemoteEvent(Shared.EVENTS.SAVE_ACK, true, ack)
        return
    end

    local jsonVar = eventData["Data"]
    if not jsonVar or jsonVar:IsEmpty() then return end
    local jsonStr = jsonVar:GetString()

    -- 解析 JSON 验证格式（如有异常直接拒绝）
    local ok, parsed = pcall(cjson.decode, jsonStr)
    if not ok or not parsed then
        local ack = VariantMap()
        ack["Ok"]  = Variant(false)
        ack["Msg"] = Variant("存档数据格式错误")
        conn:SendRemoteEvent(Shared.EVENTS.SAVE_ACK, true, ack)
        return
    end

    -- 写入 serverCloud
    serverCloud:Set(uid, SAVE_KEY, parsed, {
        ok = function()
            print("[Server] 存档成功: uid=" .. tostring(uid))
            local ack = VariantMap()
            ack["Ok"]  = Variant(true)
            ack["Msg"] = Variant("存档成功")
            conn:SendRemoteEvent(Shared.EVENTS.SAVE_ACK, true, ack)
        end,
        error = function(code, reason)
            print("[Server] 存档失败: " .. tostring(reason))
            local ack = VariantMap()
            ack["Ok"]  = Variant(false)
            ack["Msg"] = Variant("存档失败: " .. (reason or ""))
            conn:SendRemoteEvent(Shared.EVENTS.SAVE_ACK, true, ack)
        end,
    })
end

-- 客户端请求加载存档
local function handleLoadRequest(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local uid  = getUid(conn)
    if not uid then
        local res = VariantMap()
        res["Ok"]   = Variant(false)
        res["Data"] = Variant("")
        conn:SendRemoteEvent(Shared.EVENTS.LOAD_DATA, true, res)
        return
    end

    serverCloud:Get(uid, SAVE_KEY, {
        ok = function(scores)
            local saveData = scores and scores[SAVE_KEY]
            local res = VariantMap()
            if saveData then
                local jsonStr = cjson.encode(saveData)
                res["Ok"]   = Variant(true)
                res["Data"] = Variant(jsonStr)
                print("[Server] 读档成功: uid=" .. tostring(uid))
            else
                -- 新玩家，无存档
                res["Ok"]   = Variant(true)
                res["Data"] = Variant("")
                print("[Server] 新玩家无存档: uid=" .. tostring(uid))
            end
            conn:SendRemoteEvent(Shared.EVENTS.LOAD_DATA, true, res)
        end,
        error = function(code, reason)
            print("[Server] 读档失败: " .. tostring(reason))
            local res = VariantMap()
            res["Ok"]   = Variant(false)
            res["Data"] = Variant("")
            conn:SendRemoteEvent(Shared.EVENTS.LOAD_DATA, true, res)
        end,
    })
end

-- ============================================================================
-- 帧更新：定时广播
-- ============================================================================
local function handleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    broadcastTimer_ = broadcastTimer_ + dt
    if broadcastTimer_ >= BROADCAST_INTERVAL then
        broadcastTimer_ = 0
        broadcastPlayerList()
    end
end

-- ============================================================================
-- 入口
-- ============================================================================
function Server.Start()
    print("[Server] 银河征服服务端启动 | 最大玩家数: " .. SERVER_MAX_PLAYERS)

    -- 创建空场景（网络同步媒介，不做渲染）
    scene_ = Scene()
    scene_:CreateComponent("Octree", LOCAL)

    -- 注册远程事件
    Shared.RegisterServerEvents()

    -- 订阅连接管理事件
    SubscribeToEvent("ClientConnected",    handleClientConnected)
    SubscribeToEvent("ClientDisconnected", handleClientDisconnected)
    SubscribeToEvent("ClientIdentity",     handleClientIdentity)
    SubscribeToEvent(Shared.EVENTS.CLIENT_READY,   handleClientReady)
    SubscribeToEvent(Shared.EVENTS.SAVE_REQUEST,   handleSaveRequest)
    SubscribeToEvent(Shared.EVENTS.LOAD_REQUEST,   handleLoadRequest)
    SubscribeToEvent("Update",             handleUpdate)

    print("[Server] 就绪，等待玩家连接...")
end

function Server.Stop()
    print("[Server] 关闭")
end

return Server
