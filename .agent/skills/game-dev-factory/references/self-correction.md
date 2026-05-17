# 自我修正循环详细规则

> 本文档定义 R6（测试员）↔ R4（程序员）之间的自我修正循环的完整规则。

---

## 1. 修正循环触发条件

### 1.1 何时触发

R6 调用 UrhoX MCP `build` 工具后，当构建结果包含以下任一情况时触发：

| 错误类型 | 示例 | 触发修正 |
|---------|------|---------|
| Lua 语法错误 | `unexpected symbol near '}'` | ✅ 是 |
| 未定义变量/函数 | `attempt to call a nil value` | ✅ 是 |
| 类型错误 | `attempt to index a nil value` | ✅ 是 |
| 模块引用失败 | `module 'xxx' not found` | ✅ 是 |
| 资源路径错误 | `Resource not found` | ✅ 是 |
| LSP 诊断 Error 级别 | `undefined-field`, `missing-parameter` | ✅ 是 |
| LSP 诊断 Warning 级别 | `unused-local`, `lowercase-global` | ❌ 否（仅记录） |

### 1.2 何时不触发

| 情况 | 处理方式 |
|------|---------|
| 构建成功无错误 | 直接交接 R7 |
| 仅有 Warning | 记录在测试报告中，通过 |
| 运行时逻辑错误（构建成功但行为不对） | 不触发自动修正，报告给用户 |

---

## 2. 修正循环流程

### 2.1 单轮修正流程

```
R6 构建失败
  ↓
1. 提取错误信息（文件、行号、错误类型）
  ↓
2. 分析根因（查引擎规则、查 API 文档）
  ↓
3. 生成修正建议（具体到代码行）
  ↓
4. 切换到 R4 角色执行修改
  ↓
5. R4 修改代码并保存
  ↓
6. 切换回 R6 角色
  ↓
7. 重新调用 build 工具
  ↓
8. 检查结果
   ├─ 成功 → 交接 R7
   └─ 失败 → correction_round + 1，重复步骤 1-7
```

### 2.2 多错误处理

当构建输出包含多个错误时：

1. **优先级排序**: 语法错误 > 引用错误 > 类型错误 > 资源错误
2. **批量修复**: 同一文件的多个错误在一轮中全部修复
3. **依赖链错误**: 如果错误A导致错误B，只修复A（B会自动消失）

---

## 3. 修正轮次管理

### 3.1 轮次计数

```json
{
  "correction_round": 0,
  "max_correction_rounds": 3,
  "correction_history": [
    {
      "round": 1,
      "errors_found": 3,
      "errors_fixed": 3,
      "remaining_errors": 0,
      "files_modified": ["scripts/main.lua"]
    }
  ]
}
```

### 3.2 轮次上限处理

当 `correction_round >= 3` 且仍有错误时：

```markdown
### 【🧪 测试员】— 修正循环终止

**状态**: ❌ 自我修正失败（已达 3 轮上限）

**剩余错误**:
1. {错误1描述}
2. {错误2描述}

**已尝试的修复**:
- 第1轮: {修改摘要}
- 第2轮: {修改摘要}
- 第3轮: {修改摘要}

**建议**: 以下错误可能需要人工介入：
- {具体问题和建议方向}

**项目状态**: failed
```

此时 `factory-state.json` 的 `status` 设为 `"failed"`。

---

## 4. 常见错误的自动修正模式

### 4.1 错误 → 修正映射表

| 错误信息 | 常见原因 | 自动修正策略 |
|---------|---------|-------------|
| `unexpected symbol near '}'` | 多余或缺少括号 | 检查括号匹配 |
| `attempt to call a nil value 'xxx'` | 函数名拼写错误或未 require | 检查拼写、补充 require |
| `module 'xxx' not found` | 路径错误 | 检查 scripts/ 下的文件结构 |
| `attempt to index a nil value` | 变量未初始化 | 追溯赋值链，添加初始化 |
| `Resource not found: 'assets/xxx'` | 路径多了 assets/ 前缀 | 移除 assets/ 前缀（规则 #1.5） |
| `attempt to perform arithmetic on a nil value` | eventData 访问方式错误 | 改为 GetInt/GetFloat（规则 #3） |

### 4.2 引擎规则相关的修正

| 违反的规则 | 修正动作 |
|-----------|---------|
| #4 数组索引 | 将 `[0]` 改为 `[1]`，循环起始改为 1 |
| #6 NanoVG 事件 | 将渲染代码移入 NanoVGRender 回调 |
| #7 字体创建 | 在 Start() 中添加 nvgCreateFont |
| #9.6 材质路径 | 替换为 PBRNoTexture 系列 |
| #10 UI 系统 | 替换原生 UI 为 urhox-libs/UI |
| #12 枚举值 | 将数字替换为枚举常量 |

---

## 5. 修正循环的输出格式

### 5.1 R6 → R4 修正请求

```markdown
### 【🧪 测试员】→ 修正请求（第 {N}/3 轮）

**构建错误**:
```
{构建工具的原始错误输出}
```

**根因分析**:
- 文件: `scripts/{file}.lua`
- 行号: {line}
- 原因: {分析}
- 违反规则: {规则编号}（如适用）

**修正指令**:
1. 打开 `scripts/{file}.lua`
2. 第 {line} 行: 将 `{旧代码}` 改为 `{新代码}`
3. {其他修改}

→ R4 执行修正
```

### 5.2 R4 修正回复

```markdown
### 【💻 程序员】— 修正完成（第 {N}/3 轮）

**已修改文件**:
- `scripts/{file}.lua`: {修改描述}

**修改摘要**:
- 修改了 {N} 处
- {具体修改列表}

→ 交回 R6 重新构建验证
```

---

## 6. 与 build 工具的交互

### 6.1 调用时机

| 阶段 | 是否调用 build |
|------|---------------|
| R4 首次编码完成 | 不调用（交给 R5 审查） |
| R5 审查通过后 | 不调用（交给 R6） |
| R6 测试阶段 | **必须调用** |
| R6 修正循环每轮 | **必须调用** |
| R7 终审阶段 | 确认 R6 最后一次构建成功即可 |

### 6.2 构建参数

R6 调用 build 时使用项目当前配置，不额外传递特殊参数。入口文件由 R3 架构师在架构设计中确定。
