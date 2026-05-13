# UrhoX Lua 游戏 BUG 模式完整参考

> 17 类已验证 BUG 模式的错误代码/正确代码对照、检测命令和修复方案。

---

## 致命级 (Critical) - 游戏无法正常运行

### C1: Box2D 脚底传感器碰撞失效

**症状**: 按空格无法跳跃，地面检测失败，`onGround` 始终为 `false`

**错误代码**:
```lua
-- [X] 脚底传感器在身体中心，地面检测永远失败
local footSensor = node:CreateComponent("CollisionCircle2D")
footSensor.radius = 0.35
footSensor.trigger = true
-- 缺少 center 偏移，传感器在角色中心而非脚底
```

**正确代码**:
```lua
-- [OK] 使用 center 偏移到脚底
local footSensor = node:CreateComponent("CollisionCircle2D")
footSensor.radius = 0.35
footSensor.center = Vector2(0, -0.45)  -- 偏移到角色脚底
footSensor.trigger = true
footSensor.categoryBits = 4
footSensor.maskBits = 1
```

**关键原则**: 一个刚体可以有多个碰撞形状。脚底传感器必须通过 `center` 偏移到角色脚下，而不是留在身体中心。

**检测命令**:
```bash
grep -rn "trigger = true" scripts/ | grep -v "center"
```

---

### C2: 3D 角色控制器挂墙

**症状**: 角色碰到墙壁侧面卡住（挂墙），无法自动下滑

**错误代码**:
```lua
-- [X] 每帧直接设置刚体速度 -> 撞墙卡住
local body = node:CreateComponent("RigidBody")
body.mass = 1.0
-- Update 中：
body:SetLinearVelocity(Vector3(moveDir.x * speed, vel.y, moveDir.z * speed))
```

**正确代码**:
```lua
-- [OK] 三层组件架构
-- 1. RigidBody: 仅用于碰撞检测
local body = node:CreateComponent("RigidBody")
body.mass = 1.0
body:SetLinearFactor(Vector3.ZERO)      -- 禁用刚体移动
body:SetAngularFactor(Vector3.ZERO)
body.collisionEventMode = COLLISION_ALWAYS

-- 2. CollisionShape: 胶囊体
local shape = node:CreateComponent("CollisionShape")
shape:SetCapsule(0.7, 1.8, Vector3(0.0, 0.86, 0.0))

-- 3. KinematicCharacterController: 实际控制移动
local kcc = node:CreateComponent("KinematicCharacterController")
kcc:SetCollisionLayerAndMask(CollisionLayerKinematic, CollisionMaskKinematic)
kcc.jumpSpeed = 8.0
```

**三个组件的职责**:

| 组件 | 职责 |
|------|------|
| RigidBody (LinearFactor=ZERO) | 碰撞检测，不参与移动 |
| KinematicCharacterController | 实际控制角色移动、跳跃 |
| CharacterComponent (可选) | 高层封装：输入、空中控制 |

**检测命令**:
```bash
grep -rn "SetLinearVelocity" scripts/
```

---

### C3: eventData 访问格式错误

**症状**: `attempt to call method 'GetInt'` 或数据读取错误

**错误代码**:
```lua
-- [X] 格式1：点语法（不支持）
local node = eventData.NodeA

-- [X] 格式2：缺少类型转换
local dt = eventData["TimeStep"]  -- 返回 Variant 对象，不是数字

-- [X] 格式3：变量名而非字符串
local x = eventData:GetInt(X)  -- X 是变量，不是字符串
```

**正确代码**:
```lua
-- [OK] 格式A：索引 + 类型转换（经典方式）
local dt = eventData["TimeStep"]:GetFloat()
local key = eventData["Key"]:GetInt()
local node = eventData["NodeA"]:GetPtr("Node")

-- [OK] 格式B：直接方法调用（新 API，更高效）
local dt = eventData:GetFloat("TimeStep")
local key = eventData:GetInt("Key")
```

**类型转换对照**:

| 数据类型 | 转换方法 | 示例 |
|---------|---------|------|
| 整数 | `:GetInt()` | `eventData["Key"]:GetInt()` |
| 浮点数 | `:GetFloat()` | `eventData["TimeStep"]:GetFloat()` |
| 布尔值 | `:GetBool()` | `eventData["Qualifiers"]:GetBool()` |
| 字符串 | `:GetString()` | `eventData["FileName"]:GetString()` |
| 对象指针 | `:GetPtr("Type")` | `eventData["NodeA"]:GetPtr("Node")` |

**检测命令**:
```bash
grep -rn 'eventData\.' scripts/ | grep -v 'eventData\["' | grep -v 'eventData:Get'
```

---

### C4: SetEnabled 无法隐藏子节点渲染

**症状**: 调用 `node:SetEnabled(false)` 后子节点的 StaticModel/AnimatedModel 仍可见

**错误代码**:
```lua
-- [X] 只禁用父节点，子节点组件仍渲染
node:SetEnabled(false)
```

**正确代码**:
```lua
-- [OK] 递归禁用整个子树
node:SetDeepEnabled(false)

-- 恢复时：
node:SetDeepEnabled(true)
```

**适用条件**: 仅当节点有子节点且子节点包含渲染组件时。叶子节点用 `SetEnabled` 没问题。

**检测命令**:
```bash
grep -rn 'SetEnabled(false)' scripts/ | grep -v 'DeepEnabled'
```

---

## 高危级 (High) - 大概率运行时错误

### H1: 数组索引从 0 开始

**症状**: `attempt to index a nil value` 或逻辑错误

**错误代码**:
```lua
-- [X] C/JavaScript 习惯
local items = {10, 20, 30}
for i = 0, #items - 1 do
    print(items[i])  -- items[0] 返回 nil
end

-- [X] 边界计算可能得到 0
local idx = math.min(0, #arr)
```

**正确代码**:
```lua
-- [OK] Lua 从 1 开始
local items = {10, 20, 30}
for i = 1, #items do
    print(items[i])
end

-- [OK] 边界保护
local idx = math.max(1, myIndex)
```

**检测命令**:
```bash
grep -rn 'for i = 0,' scripts/
grep -rn '\[0\]' scripts/
```

---

### H2: Unicode 转义语法错误

**症状**: `missing '{' near '"\u...'` 编译错误

**错误代码**:
```lua
local star = "\u2605"    -- [X] JavaScript 语法
local heart = "\u2764"   -- [X] 缺花括号
```

**正确代码**:
```lua
local star = "\u{2605}"  -- [OK] Lua 5.4 花括号语法
local star = "★"         -- [OK] 直接写字符（推荐）
```

**检测命令**:
```bash
grep -rnP '\\u[0-9A-Fa-f]{4}[^{]' scripts/ 2>/dev/null
```

---

### H3: 使用数字常量代替枚举值

**症状**: 按钮判断失效或行为错误

**错误代码**:
```lua
if button == 0 then ...  -- [X] MOUSEB_LEFT 不一定是 0
if key == 32 then ...    -- [X] 应用 KEY_SPACE
```

**正确代码**:
```lua
if button == MOUSEB_LEFT then ...  -- [OK]
if key == KEY_SPACE then ...       -- [OK]
```

**常用枚举**:

| 类别 | 枚举值 |
|------|--------|
| 鼠标 | `MOUSEB_LEFT`, `MOUSEB_MIDDLE`, `MOUSEB_RIGHT` |
| 键盘 | `KEY_SPACE`, `KEY_ESCAPE`, `KEY_RETURN`, `KEY_A`~`KEY_Z` |
| 鼠标模式 | `MM_ABSOLUTE`, `MM_RELATIVE`, `MM_FREE` |
| 刚体类型 | `BT_STATIC`, `BT_DYNAMIC`, `BT_KINEMATIC` |

**检测命令**:
```bash
grep -rn 'button == [0-9]' scripts/
grep -rn 'key == [0-9]' scripts/
```

---

## 中危级 (Medium) - 显示异常或行为不符预期

### M1: NanoVG 文本不显示（缺少字体初始化）

**症状**: 图形能显示，但文本不出现

**修复**: 在 `Start()` 中添加 `nvgCreateFont()` 调用（只调一次）：

```lua
function Start()
    vg = nvgCreate(1)
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")  -- 只调一次
end
```

**检测命令**:
```bash
for f in $(grep -rln 'nvgText' scripts/ 2>/dev/null); do grep -L 'nvgCreateFont' "$f" 2>/dev/null; done
```

---

### M2: NanoVG 图形不显示（错误的渲染事件）

**症状**: NanoVG 代码运行但什么也不显示

**修复**: 将 NanoVG 渲染代码移到 `NanoVGRender` 事件（不是 `Update`）：

```lua
SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")  -- 不是 "Update"
```

**检测命令**:
```bash
grep -rln 'nvgBeginFrame' scripts/ 2>/dev/null | xargs grep -L 'NanoVGRender' 2>/dev/null
```

---

### M3: UI 层级冲突（NanoVG + UI 组件混用）

**症状**: NanoVG 和 UI 组件互相遮挡或渲染错乱

**原则**: UI 需求用 `urhox-libs/UI`，自定义图形用 raw NanoVG，不要混用。

**检测命令**:
```bash
grep -rln 'nvgCreate' scripts/ 2>/dev/null | xargs grep -l 'UI.Init\|UI.SetRoot' 2>/dev/null
```

---

### M4: SetMode 已禁用

**症状**: 代码运行但无效果

**修复**: 替换为 `graphics:GetWidth()` / `graphics:GetHeight()` / `graphics:GetDPR()`。

**检测命令**:
```bash
grep -rn 'SetMode' scripts/ | grep -i 'graphic'
```

---

### M5: nvgCreateFont 每帧调用（显存泄漏）

**症状**: 运行一段时间后内存持续增长

**原则**: `nvgCreateFont` 只在 `Start()` 或初始化函数中调用一次。

**检测命令**:
```bash
grep -rn 'nvgCreateFont' scripts/ | grep -vi 'start\|init\|setup\|create'
```

---

### M6: 正交相机 orthoSize 缺少 0.5 因子

**症状**: 手动坐标转换结果与 `GetScreenRay` 有 2x 误差

**修复**: 手动计算中 `orthoSize` 必须乘以 `0.5`：

```lua
local viewX = ndcX * aspect * camera.orthoSize * 0.5  -- 注意 * 0.5
local viewY = ndcY * camera.orthoSize * 0.5
```

**检测命令**:
```bash
grep -rn 'orthoSize' scripts/ | grep -v '0\.5'
```

---

### M7: 小物体 Collision Margin 过大

**症状**: 碰撞体比视觉模型大，物体"漂浮"

**修复**: 对厘米级小物体添加 `shape:SetMargin(0.01)`。

**数据对比** (硬币厚度 0.03m):
- 默认 margin (0.04m): 碰撞厚度 0.11m (+267%)
- 调整后 (0.01m): 碰撞厚度 0.05m (+67%)

**检测命令**:
```bash
grep -rln 'SetCylinder\|SetSphere' scripts/ 2>/dev/null | xargs grep -L 'SetMargin' 2>/dev/null
```

---

## 低危级 (Low) - 代码质量建议

### L1: table.unpack 位置陷阱

**症状**: 结果表元素数量不对

```lua
-- [X] unpack 不在最后，只展开第一个元素
local t = { table.unpack(items), "extra" }  -- {items[1], "extra"}

-- [OK] unpack 放最后，完全展开
local t = { "header", table.unpack(items) }
```

**检测命令**:
```bash
grep -rn 'table.unpack' scripts/
```

---

### L2: GetRankList player 字段类型误用

**症状**: 字符串操作失败

```lua
-- [X] player 是 number，没有 sub 方法
entry.player:sub(1, 5)

-- [OK] 先转字符串
tostring(entry.player)
```

**检测命令**:
```bash
grep -rn '\.player:' scripts/
```

---

### L3: 不必要的 MarkDirty 调用

**症状**: 无（多余代码）

`GetScreenRay()` 每次实时计算，无缓存，无需手动 `MarkDirty()`。

**检测命令**:
```bash
grep -rn 'MarkDirty' scripts/
```

---

## 一键扫描脚本

将以下内容保存到本地可直接执行全量扫描：

```bash
#\!/bin/bash
echo "========================================"
echo "  UrhoX 游戏 BUG 自动扫描"
echo "========================================"

SCRIPTS_DIR="scripts/"
if [ \! -d "$SCRIPTS_DIR" ]; then
    echo "ERROR: scripts/ 目录不存在"
    exit 1
fi

FILE_COUNT=$(find $SCRIPTS_DIR -name "*.lua" | wc -l)
LINE_COUNT=$(find $SCRIPTS_DIR -name "*.lua" -exec cat {} + 2>/dev/null | wc -l)
echo "扫描范围: $SCRIPTS_DIR ($FILE_COUNT 个文件, $LINE_COUNT 行代码)"
echo ""

CRITICAL=0; HIGH=0; MEDIUM=0; LOW=0

echo "--- 致命级 ---"
R=$(grep -rn "trigger = true" $SCRIPTS_DIR 2>/dev/null | grep -v "center" | grep -c .)
if [ "$R" -gt 0 ]; then echo "[C1] Box2D 脚底传感器: $R 处可疑"; CRITICAL=$((CRITICAL+R)); fi

R=$(grep -rn "SetLinearVelocity" $SCRIPTS_DIR 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[C2] 角色控制器挂墙: $R 处可疑"; CRITICAL=$((CRITICAL+R)); fi

R=$(grep -rn 'eventData\.' $SCRIPTS_DIR 2>/dev/null | grep -v 'eventData\["' | grep -v 'eventData:Get' | grep -c .)
if [ "$R" -gt 0 ]; then echo "[C3] eventData 访问错误: $R 处"; CRITICAL=$((CRITICAL+R)); fi

R=$(grep -rn 'SetEnabled(false)' $SCRIPTS_DIR 2>/dev/null | grep -v 'DeepEnabled' | grep -c .)
if [ "$R" -gt 0 ]; then echo "[C4] SetEnabled 问题: $R 处可疑"; CRITICAL=$((CRITICAL+R)); fi

echo ""
echo "--- 高危级 ---"
R=$(grep -rn 'for i = 0,' $SCRIPTS_DIR 2>/dev/null | grep -c .)
R2=$(grep -rn '\[0\]' $SCRIPTS_DIR 2>/dev/null | grep -c .)
RT=$((R+R2))
if [ "$RT" -gt 0 ]; then echo "[H1] 数组索引: $RT 处可疑"; HIGH=$((HIGH+RT)); fi

R=$(grep -rnP '\\u[0-9A-Fa-f]{4}[^{]' $SCRIPTS_DIR 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[H2] Unicode 转义: $R 处"; HIGH=$((HIGH+R)); fi

R=$(grep -rn 'button == [0-9]' $SCRIPTS_DIR 2>/dev/null | grep -c .)
R2=$(grep -rn 'key == [0-9]' $SCRIPTS_DIR 2>/dev/null | grep -c .)
RT=$((R+R2))
if [ "$RT" -gt 0 ]; then echo "[H3] 数字常量: $RT 处"; HIGH=$((HIGH+RT)); fi

echo ""
echo "--- 中危级 ---"
for f in $(grep -rln 'nvgText' $SCRIPTS_DIR 2>/dev/null); do
    R=$(grep -L 'nvgCreateFont' "$f" 2>/dev/null | grep -c .)
    if [ "$R" -gt 0 ]; then echo "[M1] NanoVG 缺字体: $f"; MEDIUM=$((MEDIUM+1)); fi
done

R=$(grep -rln 'nvgBeginFrame' $SCRIPTS_DIR 2>/dev/null | xargs grep -L 'NanoVGRender' 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[M2] NanoVG 渲染事件: $R 个文件"; MEDIUM=$((MEDIUM+R)); fi

R=$(grep -rn 'SetMode' $SCRIPTS_DIR 2>/dev/null | grep -ic 'graphic')
if [ "$R" -gt 0 ]; then echo "[M4] SetMode 调用: $R 处"; MEDIUM=$((MEDIUM+R)); fi

R=$(grep -rn 'nvgCreateFont' $SCRIPTS_DIR 2>/dev/null | grep -vic 'start\|init\|setup\|create')
if [ "$R" -gt 0 ]; then echo "[M5] nvgCreateFont 泄漏: $R 处可疑"; MEDIUM=$((MEDIUM+R)); fi

echo ""
echo "--- 低危级 ---"
R=$(grep -rn 'table.unpack' $SCRIPTS_DIR 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[L1] table.unpack: $R 处需人工检查"; LOW=$((LOW+R)); fi

R=$(grep -rn '\.player:' $SCRIPTS_DIR 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[L2] player 类型: $R 处"; LOW=$((LOW+R)); fi

R=$(grep -rn 'MarkDirty' $SCRIPTS_DIR 2>/dev/null | grep -c .)
if [ "$R" -gt 0 ]; then echo "[L3] MarkDirty: $R 处"; LOW=$((LOW+R)); fi

echo ""
echo "========================================"
echo "  汇总: $CRITICAL 致命 / $HIGH 高危 / $MEDIUM 中危 / $LOW 低危"
echo "========================================"

if [ "$CRITICAL" -gt 0 ]; then
    echo ""
    echo "\!\! 发现致命级问题，请立即修复 \!\!"
fi
```
