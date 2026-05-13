# Self-Improving Agent - 详细使用指南

## 目录

1. [ID 编号规则](#id-编号规则)
2. [完整 Learning 条目示例](#完整-learning-条目示例)
3. [完整 Error 条目示例](#完整-error-条目示例)
4. [完整 Feature Request 条目示例](#完整-feature-request-条目示例)
5. [Simplify-and-Harden 完整示例](#simplify-and-harden-完整示例)
6. [提升到 CLAUDE.md 示例](#提升到-claudemd-示例)
7. [回顾报告格式](#回顾报告格式)

---

## ID 编号规则

每个条目使用格式 `[TYPE-YYYYMMDD-XXX]`：

- **TYPE**: `LRN`（学习）、`ERR`（错误）、`FEAT`（功能请求）
- **YYYYMMDD**: 记录日期
- **XXX**: 当天序号，从 001 开始递增

查找当天最大序号：在对应文件中搜索当天日期前缀，取最大序号 +1。

---

## 完整 Learning 条目示例

```markdown
## [LRN-20260508-001] correction
**Logged**: 2026-05-08T14:30:00
**Priority**: high
**Status**: pending
**Area**: engine
### Summary
UrhoX 的 NanoVG 渲染必须在 NanoVGRender 事件中执行，不能在 Update 中调用
### Details
在 HandleUpdate 中调用 nvgBeginFrame/nvgEndFrame 时，画面不显示任何内容。
用户指出必须使用 SubscribeToEvent("NanoVGRender", ...) 事件。
引擎在该事件中才设置正确的渲染状态。
### Suggested Action
所有 NanoVG 绘制代码移到 NanoVGRender 事件处理函数中。
在代码模板中添加注释提醒。
### Metadata
- Source: user_feedback
- Related Files: scripts/main.lua
- Tags: nanovg, rendering, event
```

---

## 完整 Error 条目示例

```markdown
## [ERR-20260508-001] build_failure
**Logged**: 2026-05-08T10:15:00
**Severity**: high
**Status**: resolved
**Context**: build
### Command Failed
mcp__sce-urhox__build (entry: main.lua)
### Error Message
Lua LSP check failed: scripts/main.lua:42: attempt to index a nil value (local 'node')
### Analysis
变量 node 在声明时赋值为 nil，未添加类型标注，后续调用 node:SetPosition() 时
LSP 无法推断类型，报 undefined-field 错误。
### Resolution
添加 ---@type Node 类型标注到变量声明处。
### Prevention
所有赋值为 nil 的变量必须添加 EmmyLua 类型标注（见 CLAUDE.md 规则 #11）。
### Metadata
- Source: automated
- Related Files: scripts/main.lua:42
- See Also: LRN-20260507-003
```

---

## 完整 Feature Request 条目示例

```markdown
## [FEAT-20260508-001] gameplay
**Logged**: 2026-05-08T16:00:00
**Priority**: medium
**Status**: proposed
**Requested By**: user
### Description
希望游戏支持手柄/控制器输入，除了键盘鼠标之外
### Use Case
玩家使用 Xbox/PS 手柄时能正常操控角色移动和攻击
### Implementation Notes
需要使用 UrhoX 的 JoystickState API，参考 engine-docs/api/input.md 中的手柄部分。
需要为现有的 InputManager 添加手柄映射层。
### Status History
- 2026-05-08: proposed - 用户首次提出需求
```

---

## Simplify-and-Harden 完整示例

```markdown
## [LRN-20260508-002] best_practice
**Logged**: 2026-05-08T11:00:00
**Priority**: high
**Status**: pending
**Source**: simplify-and-harden
**Area**: config
### Pattern-Key: harden.type_annotation
### Issue Being Addressed
多次因缺少类型标注导致 LSP 误报和运行时 nil 错误
### Current State
开发者声明变量时经常遗漏 ---@type 标注，导致后续代码中出现
undefined-field 警告或运行时 nil 访问错误
### Target State
所有 nil 初始化变量自动添加类型标注，IDE 提供完整补全
### Implementation Steps
1. 代码模板中预置类型标注示例
2. 构建前检查增加 nil 变量无标注警告
### Verification
LSP 诊断零 undefined-field 警告
### Metadata
- Recurrence-Count: 5
- First-Seen: 2026-04-20
- Last-Seen: 2026-05-08
- Tags: type-safety, lsp, lua
```

---

## 提升到 CLAUDE.md 示例

当一个学习条目被多次验证且广泛适用时，提升到 CLAUDE.md：

**原条目**（LEARNINGS.md）：
```markdown
## [LRN-20260501-003] best_practice
**Status**: promoted → CLAUDE.md
...
```

**提升后**（追加到 CLAUDE.md）：
```markdown
### 从 Self-Improvement 提升的规则

#### NanoVG 必须使用 NanoVGRender 事件
- **来源**: LRN-20260501-003
- 所有 NanoVG 绘制必须在 NanoVGRender 事件中执行
- 在 Update/PostUpdate 中调用不会显示任何内容
```

---

## 回顾报告格式

当用户请求"查看学习记录"或"改进报告"时，按此格式输出：

```markdown
# 自我改进报告

## 统计
- 总学习条目: X
- 总错误记录: Y
- 总功能请求: Z
- 待处理 (pending): N
- 已解决 (resolved): M

## 高优先级待处理
1. [LRN-XXXXXXXX-XXX] 摘要...
2. [ERR-XXXXXXXX-XXX] 摘要...

## 最近记录 (最近 5 条)
...

## 建议提升
以下条目出现频率高或影响广泛，建议提升到 CLAUDE.md：
- [LRN-XXXXXXXX-XXX] 原因...

## 反复模式
以下模式重复出现，建议系统性解决：
- Pattern-Key: xxx.yyy (出现 N 次)
```
