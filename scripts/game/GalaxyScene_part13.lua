-- Auto-split from GalaxyScene.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）


-- 种子飞船（游戏起始阶段）
-- ============================================================================
local SEED_SPEED      = 300   -- 世界坐标/秒（未展开时移动速度）
local SEED_DEPLOY_DUR = 2.5   -- 展开动画时长（秒）

-- seedShip_.state:
--   "moving"    - 可移动，未展开
--   "deploying" - 展开动画播放中（不可操控）
--   "deployed"  - 展开完毕，位置固定，游戏正式开始
seedShip_ = {
    x = 0, y = 0,        -- 世界坐标（Init 时随机设置）
    state = "moving",
    timer = 0,           -- 展开动画计时器
    angle = -math.pi/2,  -- 飞船朝向（弧度）
    pulse = 0,           -- 光晕脉冲计时器
    onDeploy = nil,      -- 展开完成回调（由 Client.lua 注入）
    -- === 基地模块建造（展开后作为可建造实体，兼容 renderPlanetPanel）===
    name        = "星航基地",
    ptype       = "基地",
    size        = 8,
    colonized   = false,      -- 展开后置为 true，解锁 canBuild
    buildings   = {},
    constructing= nil,
    coreLevel   = 1,          -- 基地核心等级（1~7），控制模块解锁
    color       = {80, 200, 255},
    isBase      = true,       -- 标记：这是基地而非行星
}

-- 键盘按下状态（由 GalaxyScene.OnKeyDown/Up 维护）
local keyDown_ = { up=false, down=false, left=false, right=false }

-- 点击移动目标（世界坐标）；nil = 无点击目标
local seedClickTarget_ = nil   -- { x, y }

-- ============================================================================
-- 编队采矿参数
-- ============================================================================
local FLEET_MINE_RANGE    = 30    -- 编队靠近多少距离开始采矿（世界坐标）
local FLEET_MINE_INTERVAL = 2.0   -- 每次采矿间隔（秒）

--- 计算编队中 ENGINEER 船的总数
