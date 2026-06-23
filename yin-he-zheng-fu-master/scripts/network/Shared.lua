-- ============================================================================
-- network/Shared.lua  -- 客户端/服务端共享常量
-- ============================================================================
local Shared = {}

-- 远程事件名
Shared.EVENTS = {
    CLIENT_READY = "ClientReady",   -- 客户端 → 服务器：准备就绪
    PLAYER_LIST  = "PlayerList",    -- 服务器 → 所有客户端：在线玩家列表
    SAVE_REQUEST = "SaveRequest",   -- 客户端 → 服务器：请求保存存档
    SAVE_ACK     = "SaveAck",       -- 服务器 → 客户端：存档结果应答
    LOAD_REQUEST = "LoadRequest",   -- 客户端 → 服务器：请求加载存档
    LOAD_DATA    = "LoadData",      -- 服务器 → 客户端：存档数据
}

-- 服务器需要注册（接收）的事件
Shared.SERVER_EVENTS = {
    Shared.EVENTS.CLIENT_READY,
    Shared.EVENTS.SAVE_REQUEST,
    Shared.EVENTS.LOAD_REQUEST,
}

-- 客户端需要注册（接收）的事件
Shared.CLIENT_EVENTS = {
    Shared.EVENTS.PLAYER_LIST,
    Shared.EVENTS.SAVE_ACK,
    Shared.EVENTS.LOAD_DATA,
}

function Shared.RegisterServerEvents()
    for _, e in ipairs(Shared.SERVER_EVENTS) do
        network:RegisterRemoteEvent(e)
    end
end

function Shared.RegisterClientEvents()
    for _, e in ipairs(Shared.CLIENT_EVENTS) do
        network:RegisterRemoteEvent(e)
    end
end

return Shared
