---
name: reactive-ui
description: "ReactiveUI 响应式 UI 框架的初始化与开发指南。Use when users need to (1) 初始化UI框架 / 初始化响应式UI / 添加ReactiveUI, (2) 编写UI / 编写任意UI / 用响应式方式写UI / 数据驱动UI / 局部更新UI, (3) 用户提到 ReactiveUI 或响应式状态管理, (4) 需要将数据绑定到 UrhoX UI 控件实现自动更新。"
---

# ReactiveUI 响应式 UI 框架

数据驱动的局部 UI 更新，告别整树重建。修改 `store.score = 999`，绑定的 Label 自动变为 `"999"`。

## 两种使用模式

### 模式 A：初始化框架

**触发词**: "初始化ui框架"、"添加ReactiveUI"、"初始化响应式UI"

**操作**: 将 `assets/ReactiveUI.lua` 复制到用户项目的 `scripts/ReactiveUI.lua`。

```bash
cp <skill-dir>/assets/ReactiveUI.lua /workspace/scripts/ReactiveUI.lua
```

复制后提示用户：
- 已将 ReactiveUI.lua 放入 `scripts/` 目录
- 使用方式：`local ReactiveUI = require "ReactiveUI"`

### 模式 B：编写 UI

**触发词**: "编写UI"、"编写任意UI"、"用响应式方式写UI"、"数据驱动UI"、需要将数据绑定到控件

**操作**:

1. 读取 `references/ReactiveUI-API.md` 了解完整 API
2. 读取 `references/example.lua` 了解实际用法模式
3. 确认 `scripts/ReactiveUI.lua` 已存在（不存在则先执行模式 A）
4. 基于框架编写代码

## 核心用法速查

```lua
local UI = require "urhox-libs/UI"
local ReactiveUI = require "ReactiveUI"

-- 创建 Store
local store = ReactiveUI.new({ score = 0, hp = 100, maxHp = 100 })

-- 派生值
store:computed("hpPct", { "hp", "maxHp" }, function(hp, max)
    return math.floor(hp / max * 100)
end)

-- 绑定到控件（只做一次，后续自动更新）
local label = UI.Label { text = "0" }
store:bind(label, "text", "score", function(v) return tostring(v) end)

-- 多字段绑定
store:bind(hpLabel, "text", { "hp", "maxHp" }, function(hp, max)
    return hp .. "/" .. max
end)

-- 批量更新（合并通知）
store:batch(function()
    store.score = store.score + 100
    store.hp = math.max(0, store.hp - 10)
end)

-- effect（自动追踪依赖）
local dispose = store:effect(function(s)
    local canAfford = s.gold >= item.cost
    buyBtn:SetDisabled(not canAfford)
end)
-- dispose()  -- 停止响应

-- 列表绑定（支持 remove 清理回调）
local effectDisposers = {}
store:bindList(container, "items", {
    key = function(item) return item.id end,
    render = function(item, i)
        local w = UI.Label { text = item.name }
        effectDisposers[w] = store:effect(function(s)
            -- 自动追踪依赖，依赖变化时重新执行
        end)
        return w
    end,
    update = function(widget, item, i) widget.text = item.name end,
    remove = function(widget)
        local d = effectDisposers[widget]
        if d then d(); effectDisposers[widget] = nil end
    end,
})
store:listAppend("items", { id = 1, name = "Sword" })

-- 清理
store:unbindAll()
```

## API 清单

| 方法 | 说明 |
|------|------|
| `ReactiveUI.new(data)` | 创建 Store |
| `store.key` / `store.key = val` | 透明读写，写入自动通知 |
| `store:get(key)` / `store:set(key, val)` | 显式读写 |
| `store:silent(key, val)` | 静默写入（不通知） |
| `store:refresh(keyOrKeys?)` | 手动触发通知（配合 silent 使用） |
| `store:watch(key, fn)` | 监听变化 → 返回 watcher ID |
| `store:unwatch(id)` | 移除监听 |
| `store:computed(name, deps, fn)` | 派生值（拓扑排序级联更新） |
| `store:removeComputed(name)` | 移除派生值 |
| `store:effect(fn)` | 自动追踪依赖的副作用 → 返回 dispose 函数 |
| `store:batch(fn)` | 批量修改，合并通知 |
| `store:bind(widget, prop, key, transform?)` | 绑定控件属性 |
| `store:unbind(id)` | 解除单个绑定 |
| `store:unbindWidget(widget)` | 解除控件所有绑定 |
| `store:unbindAll()` | 全部解除 |
| `store:bindList(container, key, opts)` | 列表绑定（opts: key/render/update/remove） |
| `store:listAppend/Insert/Remove/Update/Replace/Sort/Clear` | 列表操作 |
| `store:dump()` | 导出全部数据 |
| `store:getBindingCount()` / `store:getWatcherCount(key?)` | 调试计数 |

完整 API 细节、参数签名、返回值 → 读取 `references/ReactiveUI-API.md`

完整使用示例（bind/computed/batch/bindList/watch/effect 全演示）→ 读取 `references/example.lua`

## 关键注意事项

1. **table 类型始终触发通知**（浅比较无法检测内部变化）
2. **computed 只读**，赋值会抛错
3. **列表必须用专用方法**（`listAppend` 等），直接 `table.insert` 不会更新 UI
4. **Widget 销毁自动解绑**，无需手动清理
5. **effect 返回 dispose**，必须在适当时机调用（或通过 bindList remove 自动管理）
6. **Stop() 中调用 `store:unbindAll()`** 释放所有资源
