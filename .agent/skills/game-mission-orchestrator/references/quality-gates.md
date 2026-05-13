# 质量门禁详细检查项

每个 Phase 完成后执行的质量验证清单。根据 Phase 类型选择对应检查集。

---

## 通用检查项（所有 Phase 必须通过）

| # | 检查项 | 验证方式 | 严重度 |
|---|--------|----------|--------|
| G1 | Build 通过 | 调用 UrhoX MCP `build` 工具 | BLOCKER |
| G2 | 无语法错误 | Build 工具内含 Lua LSP 检查 | BLOCKER |
| G3 | 已有功能无回归 | 在 Preview 中验证核心交互仍正常 | BLOCKER |
| G4 | 代码在 scripts/ 目录 | 检查文件路径 | BLOCKER |
| G5 | 单文件不超过 1500 行 | `wc -l` 检查 | MAJOR |
| G6 | 未写入 dist/ 目录 | 检查文件操作 | BLOCKER |

---

## Phase 特定检查项

### P0-Foundation 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| F1 | 使用了正确脚手架 | 2D→scaffold-2d, 3D角色→scaffold-3d-character 等 |
| F2 | Start() 函数存在 | 入口函数完整 |
| F3 | 场景/相机正确初始化 | Preview 能看到初始场景 |
| F4 | 坐标系理解正确 | Y-up 左手系，单位为米 |

### P1-Core 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| C1 | 核心循环可玩 | 最小可玩原型能跑通 |
| C2 | 输入响应正确 | 键盘/鼠标/触屏按预期工作 |
| C3 | 枚举值正确使用 | MOUSEB_LEFT 而非数字 0，KEY_SPACE 而非数字 |
| C4 | 物理配置合理 | 重力、碰撞层、刚体类型正确 |
| C5 | 鼠标模式匹配游戏类型 | FPS/TPS 用 MM_RELATIVE |

### P2-Content 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| T1 | 内容系统数据驱动 | 配置与逻辑分离 |
| T2 | 新内容不破坏核心循环 | 添加敌人/道具后核心玩法仍正常 |
| T3 | 模型尺寸正确 | 使用 boundingBox 或查 built-in-models.md |

### P3-UI 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| U1 | 使用 urhox-libs/UI 组件 | 不使用已废弃的原生 UI |
| U2 | UI.Init 正确配置 | fonts 和 scale 参数设置 |
| U3 | 布局在不同分辨率下正常 | 使用百分比/flex 布局 |
| U4 | 交互反馈明确 | 按钮有点击反馈 |

### P4-Audio 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| A1 | 音频资源存在 | assets/ 下有对应文件 |
| A2 | 音量可控 | 提供音量调节能力 |
| A3 | BGM 不重叠 | 场景切换时正确停止/切换 |

### P5-Polish 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| L1 | 特效不影响性能 | 无明显帧率下降 |
| L2 | 动画流畅 | 无卡顿或跳帧 |
| L3 | NanoVG 渲染在正确事件中 | 使用 NanoVGRender 事件 |

### P6-Balance 检查项

| # | 检查项 | 说明 |
|---|--------|------|
| B1 | 数值可配置 | 关键数值提取为常量/配置 |
| B2 | 难度曲线渐进 | 不会突然变难或变简单 |
| B3 | 经济系统不崩溃 | 收入/支出比例合理 |

---

## 门禁执行流程

```
Phase 开发完成
  |
  v
执行通用检查项 G1-G6
  |
  +-- 任一 BLOCKER 不通过 -> FAIL -> 修复后重新检查
  |
  v
执行 Phase 特定检查项
  |
  +-- 任一关键项不通过 -> PARTIAL -> 记录 issues，评估影响
  |
  v
所有检查通过 -> PASS
  |
  v
更新 snapshot.json，记录 quality_gate 结果
  |
  v
进入下一 Phase
```

---

## 门禁结果记录格式

写入 snapshot.json 的 `quality_gate` 字段：

```json
{
  "passed": true,
  "checked_at": "2026-05-12T14:30:00Z",
  "results": {
    "G1": "pass",
    "G2": "pass",
    "G3": "pass",
    "C1": "pass",
    "C2": "pass"
  },
  "issues": []
}
```

不通过示例：

```json
{
  "passed": false,
  "checked_at": "2026-05-12T14:30:00Z",
  "results": {
    "G1": "pass",
    "G5": "fail",
    "U1": "fail"
  },
  "issues": [
    "G5: main.lua 已达 1623 行，需要拆分模块",
    "U1: 暂停菜单使用了原生 UI，需改为 urhox-libs/UI"
  ]
}
```

---

## 常见不通过原因与修复指引

| 检查项 | 常见原因 | 快速修复 |
|--------|---------|---------|
| G1 Build 失败 | 语法错误、未定义变量 | 根据 LSP 报告修复 |
| G5 文件过长 | 功能堆积在单文件 | 按规则 #13 提取模块 |
| C3 枚举值 | 使用数字代替枚举 | 查 enums.md 替换 |
| C5 鼠标模式 | FPS 游戏未设 MM_RELATIVE | 在 Start() 中添加 |
| U1 UI 系统 | 使用了废弃的原生 UI | 改用 urhox-libs/UI |
| L3 NanoVG 事件 | 在 Update 中绘制 NanoVG | 改用 NanoVGRender 事件 |
