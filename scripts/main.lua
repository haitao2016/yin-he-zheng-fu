-- ============================================================================
-- main.lua  -- 银河征服 入口
-- ============================================================================
local Client = require("network.Client")

function Start()
    Client.Start()
end

function Stop()
    Client.Stop()
end
