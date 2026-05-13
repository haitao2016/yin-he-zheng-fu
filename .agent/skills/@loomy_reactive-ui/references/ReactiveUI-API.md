# ReactiveUI API

UrhoX UI 响应式状态管理框架 —— 数据驱动的局部 UI 更新，告别整树重建。

## 目录

- [快速上手](#快速上手)
- [核心概念](#核心概念)
- [API 参考](#api-参考)
  - [构造函数](#构造函数)
  - [数据读写](#数据读写)
  - [watch / unwatch](#watch--unwatch)
  - [computed](#computed)
  - [effect](#effect)
  - [batch](#batch)
  - [bind / unbind](#bind--unbind)
  - [bindList](#bindlist)
  - [列表操作](#列表操作)
  - [调试工具](#调试工具)
- [设计原则](#设计原则)
- [注意事项](#注意事项)

---

## 快速上手

```lua
local UI = require "urhox-libs/UI"
local ReactiveUI = require "ReactiveUI"

-- 1. 创建 Store
local store = ReactiveUI.new({ score = 0, hp = 100 })

-- 2. 创建 UI（只执行一次）
local label = UI.Label { text = "Score: 0" }

-- 3. 绑定数据到 UI
store:bind(label, "text", "score", function(v)
    return "Score: " .. v
end)

-- 4. 修改数据 → UI 自动更新
store.score = 999  -- label.text 自动变为 "Score: 999"
```

---

## 核心概念

```
┌─────────────────────────────────────────────────┐
│                  ReactiveUI                     │
│                                                 │
│  store.score = 100                              │
│       │                                         │
│       ▼                                         │
│  ┌─────────┐    ┌───────────┐    ┌───────────┐  │
│  │  data   │───▶│ watchers  │───▶│  widget   │  │
│  │ (原始值) │    │ (监听回调) │    │ (UI 控件) │  │
│  └─────────┘    └───────────┘    └───────────┘  │
│       │                                         │
│       ▼                                         │
│  ┌──────────┐                                   │
│  │ computed │  派生值自动级联更新                  │
│  │ (派生值)  │                                   │
│  └──────────┘                                   │
└─────────────────────────────────────────────────┘
```

| 概念 | 说明 |
|------|------|
| **Store** | 响应式数据容器，通过 `store.key` 读写，写入自动触发通知 |
| **Watcher** | 数据变化的监听回调，收到 `(newVal, oldVal, key)` |
| **Computed** | 依赖其他字段自动计算的派生值，依赖变化时级联更新 |
| **Effect** | 自动追踪依赖的副作用函数，依赖变化时重新执行 |
| **Bind** | 将 Store 字段绑定到 Widget 属性，数据变化时自动赋值 |
| **BindList** | 将数组字段绑定到容器，增删改排序时精确操作对应 DOM 节点 |
| **Batch** | 批量修改多个字段，合并通知，避免中间状态触发多次更新 |

---

## API 参考

### 构造函数

#### `ReactiveUI.new(initialData)`

创建一个新的响应式 Store 实例。

| 参数 | 类型 | 说明 |
|------|------|------|
| `initialData` | `table?` | 初始数据，浅拷贝到 Store 内部 |

**返回值**: `ReactiveUI` 实例（metatable 代理对象）

```lua
local store = ReactiveUI.new({
    score    = 0,
    hp       = 100,
    maxHp    = 100,
    name     = "Player",
    items    = {},
})
```

---

### 数据读写

Store 通过 metatable 代理实现透明读写，像普通 table 一样使用。

#### 读取: `store.key`

```lua
local score = store.score      -- 读取普通字段
local pct   = store.hpPercent  -- 读取 computed 字段（同样语法）
```

**优先级**: 方法 > computed > data

#### 写入: `store.key = value`

```lua
store.score = 100  -- 写入并自动通知所有 watcher / binding
store.hp = 80      -- 同上
```

**行为**:
- 值类型（number/string/boolean）：新旧值相同时**跳过通知**
- table 类型：**始终触发通知**（因为浅比较无法检测内部变化）
- 写入 computed 字段会抛出错误

#### `store:get(key)`

显式读取，等价于 `store.key`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `key` | `string` | 字段名 |

**返回值**: 字段当前值（computed 返回计算结果）

#### `store:set(key, value)`

显式写入，等价于 `store.key = value`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `key` | `string` | 字段名 |
| `value` | `any` | 新值 |

#### `store:silent(key, value)`

静默写入，**不触发任何通知**。适用于初始化或批量导入数据不想触发 UI 更新的场景。

| 参数 | 类型 | 说明 |
|------|------|------|
| `key` | `string` | 字段名 |
| `value` | `any` | 新值 |

```lua
-- 从存档恢复大量数据，不触发 UI 更新
store:silent("score", savedData.score)
store:silent("hp", savedData.hp)
-- 最后手动触发一次整体刷新
store:refresh()  -- 通知所有字段的 watcher 和 binding
```

#### `store:refresh(keyOrKeys?)`

手动触发指定字段（或全部字段）的通知。常用于 `silent` 批量写入后的一次性刷新。

| 参数 | 类型 | 说明 |
|------|------|------|
| `keyOrKeys` | `string \| string[] \| nil` | 省略则刷新所有字段；传入字符串或数组则只刷新指定字段 |

```lua
store:refresh("score")           -- 刷新单个字段
store:refresh({ "score", "hp" }) -- 刷新多个字段
store:refresh()                  -- 刷新所有字段
```

---

### watch / unwatch

#### `store:watch(keyOrKeys, fn)`

监听一个或多个字段的变化。

| 参数 | 类型 | 说明 |
|------|------|------|
| `keyOrKeys` | `string \| string[]` | 监听的字段名，单个字符串或字符串数组 |
| `fn` | `function` | 回调 `fn(newVal, oldVal, key)` |

**返回值**: `integer | integer[]` —— watcher ID（用于 `unwatch`）

```lua
-- 监听单个字段
local id = store:watch("hp", function(newVal, oldVal, key)
    print(key .. ": " .. oldVal .. " → " .. newVal)
end)

-- 监听多个字段
local ids = store:watch({"hp", "score"}, function(newVal, oldVal, key)
    print(key .. " changed to " .. tostring(newVal))
end)
-- 注意：传入数组会为每个字段各注册一个 watcher，返回对应的 ID 数组。
```

#### `store:unwatch(idOrIds)`

移除 watcher。

| 参数 | 类型 | 说明 |
|------|------|------|
| `idOrIds` | `integer \| integer[]` | `watch` 返回的 ID |

---

### computed

#### `store:computed(name, deps, fn)`

定义一个派生值。依赖字段变化时自动重新计算，并通知该 computed 自身的 watcher。

| 参数 | 类型 | 说明 |
|------|------|------|
| `name` | `string` | 派生值的字段名 |
| `deps` | `string[]` | 依赖的字段名列表（可依赖 data 或其他 computed） |
| `fn` | `function` | 计算函数，参数按 deps 顺序传入 |

**返回值**: 初始计算结果

```lua
store:computed("hpPercent", { "hp", "maxHp" }, function(hp, maxHp)
    return math.floor(hp / maxHp * 100)
end)

store:computed("hpColor", { "hpPercent" }, function(pct)
    if pct < 30 then return { 220, 50, 50, 255 }
    elseif pct < 60 then return { 220, 160, 40, 255 }
    else return { 60, 180, 80, 255 } end
end)
```

**级联**: computed A 依赖 computed B → B 变化时 A 自动更新（拓扑排序）。
**只读**: 对 computed 字段赋值会抛出错误。

#### `store:removeComputed(name)`

移除一个已定义的 computed 字段及其所有 watcher。

---

### effect

#### `store:effect(fn)`

创建一个自动追踪依赖的副作用函数。`fn(store)` 执行期间读取的字段自动成为依赖。

| 参数 | 类型 | 说明 |
|------|------|------|
| `fn` | `function(store)` | 副作用函数，参数为 store 自身 |

**返回值**: `function` —— dispose 函数，调用后 effect 停止响应

```lua
local dispose = store:effect(function(s)
    print("Score is now: " .. s.score)
end)
store.score = 100  -- 输出: Score is now: 100
dispose()          -- 停止响应
```

**与 watch 的区别**:

| 特性 | `watch` | `effect` |
|------|---------|----------|
| 依赖声明 | 手动指定 key | **自动追踪** |
| 回调参数 | `(newVal, oldVal, key)` | `(store)` |
| 动态依赖 | 不支持 | **支持** |
| 典型用途 | 响应单个字段变化 | 复杂副作用、多字段联合判断 |

**配合 bindList 使用**:

```lua
local effectDisposers = {}
store:bindList(container, "cards", {
    key = function(item) return item.id end,
    render = function(item, i)
        local widget = createCardWidget(item)
        effectDisposers[widget] = store:effect(function(s)
            local canAfford = s.gold >= item.cost
            widget:SetStyle({ borderColor = canAfford and GREEN or GRAY })
        end)
        return widget
    end,
    remove = function(widget)
        local dispose = effectDisposers[widget]
        if dispose then dispose(); effectDisposers[widget] = nil end
    end,
})
```

---

### batch

#### `store:batch(fn)`

批量修改多个字段，合并通知。

| 参数 | 类型 | 说明 |
|------|------|------|
| `fn` | `function` | 包含多次写入的函数 |

```lua
store:batch(function()
    store.score = 100
    store.combo = 5
    store.hp = 80
end)
-- 只在结束时通知一次（而非 3 次）
```

---

### bind / unbind

#### `store:bind(widget, prop, keyOrKeys, transform?)`

将 Store 字段绑定到 Widget 属性。字段变化时自动执行 `widget[prop] = value`。

| 参数 | 类型 | 说明 |
|------|------|------|
| `widget` | `Widget` | UI 控件实例 |
| `prop` | `string` | 要更新的属性名 |
| `keyOrKeys` | `string \| string[]` | 绑定的数据字段 |
| `transform` | `function?` | 可选转换函数 |

**返回值**: `integer` —— binding ID

```lua
store:bind(label, "text", "score", function(v) return "Score: " .. v end)
store:bind(hpLabel, "text", { "hp", "maxHp" }, function(hp, max) return hp .. "/" .. max end)
store:bind(comboLabel, "visible", "combo", function(v) return v > 0 end)
```

**行为**: 调用时立即执行一次赋值（初始同步）；Widget 被 `Destroy()` 时自动解绑。

#### `store:unbind(bindId)` / `store:unbindWidget(widget)` / `store:unbindAll()`

分别移除单个绑定、Widget 所有绑定、全部绑定+watcher+列表绑定。

---

### bindList

#### `store:bindList(container, key, opts)`

将数组字段绑定到容器 Widget。

**opts 字段**:

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `key` | `function(item) -> any` | 是 | 返回 item 唯一标识 |
| `render` | `function(item, index) -> Widget` | 是 | 创建新 Widget |
| `update` | `function(widget, item, index)` | 否 | 复用更新 |
| `remove` | `function(widget)` | 否 | 销毁前清理回调 |

---

### 列表操作

| 方法 | 说明 |
|------|------|
| `store:listAppend(key, item)` | 末尾追加 |
| `store:listInsert(key, index, item)` | 指定位置插入 |
| `store:listRemove(key, predicateOrIndex)` | 按索引或条件移除 |
| `store:listUpdate(key, predicate, patch)` | 更新匹配项 |
| `store:listReplace(key, newItems)` | 整体替换（key-based diff） |
| `store:listSort(key, comparator)` | 排序 |
| `store:listClear(key)` | 清空 |

---

### 调试工具

| 方法 | 说明 |
|------|------|
| `store:dump()` | 导出全部数据为 table |
| `store:getBindingCount()` | 活跃 bind 数量 |
| `store:getWatcherCount(key?)` | watcher 数量 |

---

## 设计原则

1. **零侵入** — 不修改 UI 库代码，通过 `widget[prop] = value` 赋值
2. **闭包隔离** — 内部状态封闭在 `ReactiveUI.new()` 闭包中
3. **自动清理** — Widget 销毁时自动解绑
4. **精确更新** — bind 只更新属性，bindList 精确操作节点，batch 合并通知

---

## 注意事项

1. **table 类型始终触发通知**（浅比较无法检测内部变化）
2. **computed 只读**，赋值会抛错
3. **列表必须用专用方法**（`listAppend` 等），直接 `table.insert` 不会更新 UI
4. **effect 的 dispose 必须管理**，否则内存泄漏
5. **bindList 的 key 必须唯一**
6. **batch 中错误**：已修改数据保留，通知仍触发，错误向上传播
