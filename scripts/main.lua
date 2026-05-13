-- ============================================================================
-- main.lua  -- 银河征服 MMOSLG  入口分发器
-- 根据运行模式加载 Server 或 Client
-- ============================================================================
local Module = nil

function Start()
    if IsServerMode() then
        Module = require("network.Server")
    else
        Module = require("network.Client")
    end
    Module.Start()
end

function Stop()
    if Module and Module.Stop then
        Module.Stop()
    end
end
