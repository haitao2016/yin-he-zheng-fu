# UrhoX Lua 代码审查详细清单

按需阅读：当用户请求代码审查、review 或质量检查时，参考此清单逐项审查。

## 审查范围

**仅审查以下目录**：
- `scripts/` — 用户游戏代码
- 用户自建的其他目录（如 `docs/`、`config/` 等）

**忽略以下目录**：
- `engine-docs/`、`urhox-libs/`、`examples/`、`templates/`、`.emmylua/`、`.claude/`

---

## P0: 致命问题（必修复）

### 1. 数组索引起始

```lua
-- 错误示例
for i = 0, #arr - 1 do arr[i] ... end   -- Lua 数组从 1 开始
local first = arr[0]                      -- 返回 nil

-- 正确做法
for i = 1, #arr do arr[i] ... end
local first = arr[1]
```

**检查方法**: 搜索 `[0]`、`= 0,`（循环起始）、`i = 0` 模式。

### 2. eventData 访问方式

```lua
-- 错误示例
local x = eventData.X
local dt = eventData["TimeStep"]

-- 正确做法
local x = eventData["X"]:GetInt()
local dt = eventData["TimeStep"]:GetFloat()
-- 或更高效的方式
local x = eventData:GetInt("X")
local dt = eventData:GetFloat("TimeStep")
```

**检查方法**: 搜索 `eventData.` 或未调用 `:Get*()` 的 `eventData["..."]`。

### 3. NanoVG 渲染事件

```lua
-- 错误示例：在 Update 中绘制 NanoVG
function HandleUpdate(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)  -- 错误位置
end

-- 正确做法
SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, w, h, 1.0)
    -- 绘制代码
    nvgEndFrame(vg)
end
```

**检查方法**: 搜索 `nvgBeginFrame`，确认其所在函数是否订阅了 `NanoVGRender` 事件。

### 4. NanoVG 字体创建泄漏

```lua
-- 错误示例：每帧调用导致显存泄漏
function HandleNanoVGRender(eventType, eventData)
    nvgCreateFont(vg, "sans", "Fonts/xxx.ttf")  -- 每帧创建
end

-- 正确做法：初始化时创建一次
function Start()
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/xxx.ttf")
end
```

**检查方法**: 搜索 `nvgCreateFont`，确认不在渲染循环内。

### 5. 鼠标按钮判断

```lua
-- 错误示例
if button == 0 then ...   -- 不要用数字
if button ~= 0 then ...

-- 正确做法
if button == MOUSEB_LEFT then ...
if button == MOUSEB_RIGHT then ...
```

**检查方法**: 搜索 `button == 0`、`button ~= 0`、`button > 0` 等数字比较。

### 6. Box2D 碰撞体位置

```lua
-- 错误示例：碰撞体在子节点上（不会触发碰撞回调）
local bodyNode = scene_:CreateChild("Body")
bodyNode:CreateComponent("RigidBody2D")
local shapeNode = bodyNode:CreateChild("Shape")
shapeNode:CreateComponent("CollisionBox2D")  -- 在子节点

-- 正确做法：碰撞体与 RigidBody2D 在同一节点
local bodyNode = scene_:CreateChild("Body")
bodyNode:CreateComponent("RigidBody2D")
local shape = bodyNode:CreateComponent("CollisionBox2D")  -- 同节点
shape.center = Vector2(0, 0.5)  -- 用 center 偏移
```

### 7. nil 变量成员访问

```lua
-- 错误示例
local scene = nil
scene:CreateChild("Node")  -- 崩溃

-- 正确做法
---@type Scene
local scene = nil
-- 后续赋值后再使用
```

---

## P1: 重要问题（强烈建议修复）

### 8. 分辨率 API 使用

分辨率设置 API 已被引擎禁用。正确方式：

```lua
local w, h = graphics:GetWidth(), graphics:GetHeight()
local dpr = graphics:GetDPR()
```

### 9. 资源路径前缀

```lua
-- 错误：不应加目录前缀
cache:GetResource("Texture2D", "assets/Textures/player.png")

-- 正确：直接从资源根开始
cache:GetResource("Texture2D", "Textures/player.png")
```

### 10. 硬编码数字枚举

```lua
-- 错误
if input:GetKeyDown(32) then ...
body.bodyType = 2

-- 正确
if input:GetKeyDown(KEY_SPACE) then ...
body.bodyType = BT_DYNAMIC
```

### 11. 手动第三人称相机计算

不要手动计算第三人称相机位置和旋转，使用 `ThirdPersonCamera` 库。

### 12. 使用原生 UI 系统

原生 UI 系统已废弃，应使用 `urhox-libs/UI` 组件库（40+ 控件）。

### 13. 单文件过大

| 行数阈值 | 建议 |
|----------|------|
| < 1000 行 | 可接受 |
| 1000-1500 行 | 考虑拆分 |
| > 1500 行 | 必须拆分为模块 |

---

## P2: 建议优化

### 14. table.unpack 位置陷阱

`table.unpack()` 只在表构造器**最后位置**才完全展开。

```lua
-- 陷阱
local t = { table.unpack(items), "extra" }  -- 只展开第一个
-- 正确
local t = { "header", table.unpack(items) }
```

### 15. 全局变量污染

所有模块内变量应使用 `local` 修饰，避免全局污染。

### 16. 重复代码

超过 3 次的相似代码模式应提取为函数。

### 17. 魔法数字

```lua
-- 差
player.speed = 5.0

-- 好
local CONFIG = { moveSpeed = 5.0 }
player.speed = CONFIG.moveSpeed
```

### 18. 缺少资源清理

所有模块应提供 `Cleanup()` 函数：
- 取消事件订阅
- 释放节点引用
- 清空缓存表

---

## 评分标准

| 类别 | 1 分 | 3 分 | 5 分 |
|------|------|------|------|
| 正确性 | 有 P0 错误 | 无 P0，少量 P1 | 无 P0/P1 |
| 安全性 | 存在崩溃风险 | 偶发 nil 风险 | 健壮的错误处理 |
| 架构 | 全局变量满天飞 | 基本模块化 | 职责分离清晰 |
| 性能 | 每帧创建资源 | 无明显瓶颈 | 对象池+缓存优化 |
| 规范性 | 多项不合规 | 基本合规 | 完全符合最佳实践 |
