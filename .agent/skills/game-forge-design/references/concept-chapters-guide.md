---
title: Game Forge 概念章节编写指南
description: 15 章概念文档的详细编写指引，包含每章的必填项、模板和 UrhoX 适配要点
---

# 概念章节编写指南

本文档为 Game Forge Stage 1 的 15 章概念文档提供详细编写指引。

---

## ch01: 目标用户 (Target Users)

### 必填内容
- **主要用户群** — 年龄、性别、游戏偏好
- **次要用户群** — 潜在扩展人群
- **平台偏好** — 移动端(TapTap) / PC / 全平台
- **使用场景** — 碎片化 / 沉浸式 / 社交

### 模板

```markdown
## 主要用户群 (C-01-001)
- 年龄段: 18-30
- 游戏偏好: [休闲/硬核/社交]
- 平台: [移动/PC/全平台]
- 每日游戏时长: [15分钟/1小时/2小时+]

## 次要用户群 (C-01-002)
- ...

## 平台偏好 (C-01-003)
- 主平台: TapTap (移动端)
- 支持平台: PC (taptap_publish.app_platforms: "1,2")
- 输入方式: 触控 + 键鼠（使用 urhox-libs/Platform/InputManager 适配）
```

### UrhoX 适配要点
- 使用 `InputManager` 做跨平台输入适配
- `screen_orientation` 决定横屏/竖屏
- 通过 `graphics:GetWidth()` / `graphics:GetHeight()` 获取分辨率

---

## ch02: 核心玩法 (Core Gameplay)

### 必填内容
- **30秒体验** — 用一段话描述核心游戏体验
- **操控方式** — 触控/键鼠/手柄 操作映射
- **核心乐趣** — 玩家为什么会觉得好玩
- **核心动词** — 游戏中最频繁的 3-5 个动作

### 模板

```markdown
## 30秒体验 (C-02-001)
玩家 [做什么] 来 [达成什么目标]，过程中 [核心乐趣点]。

## 操控方式 (C-02-002)
| 操作 | 移动端 | PC |
|------|--------|-----|
| 移动 | 虚拟摇杆 | WASD |
| 攻击 | 点击 | 鼠标左键 |
| 跳跃 | 按钮 | 空格键 |

## 核心乐趣 (C-02-003)
1. [成长感 / 探索 / 竞技 / 收集 / 创造]

## 核心动词 (C-02-004)
跑、跳、打、捡、升级
```

### UrhoX 适配要点
- 根据操控方式选择鼠标模式：FPS/TPS → `MM_RELATIVE`
- 使用 `InputManager` 映射多平台输入
- 触控：虚拟摇杆参考 `urhox-libs/Platform/`

---

## ch03: 游戏循环 (Game Loops)

### 必填内容
- **核心循环** — 最短的游戏循环（秒级）
- **中期循环** — 关卡/任务/赛季级别
- **长期循环** — 元进度、永久解锁
- **循环关系图** — 三层循环如何嵌套

### 模板

```markdown
## 核心循环 (C-03-001) — 每 10-60 秒
动作 → 反馈 → 奖励 → 决策 → 动作

## 中期循环 (C-03-002) — 每 5-30 分钟
完成关卡 → 获取资源 → 升级/解锁 → 挑战更高难度

## 长期循环 (C-03-003) — 每天/每周
日常任务 → 积累进度 → 赛季奖励 → 新赛季
```

---

## ch04: 关卡设计 (Level Design)

> **按类型跳过**: idle 类型跳过此章

### 必填内容
- **关卡结构** — 线性 / 分支 / 开放世界
- **难度递进** — 关卡间的难度变化
- **节奏控制** — 紧张与放松的交替

### UrhoX 适配要点
- 2D 关卡：瓦片地图或 NanoVG 绘制
- 3D 关卡：Scene 节点树 + Prefab
- 大型关卡：考虑模块化加载

---

## ch05: 难度系统 (Difficulty)

### 必填内容
- **难度曲线** — 整体难度走向（平缓/陡峭/波浪）
- **自适应难度** — 是否根据玩家表现调整
- **挫败感控制** — 失败后的缓解机制

### 与 Stage 3B 的关系
此章定义**设计意图**，Stage 3B 提供**具体公式和数值**。

---

## ch06: 新手引导 (Onboarding)

### 必填内容
- **教程类型** — 引导关卡 / 提示框 / 学习曲线
- **功能解锁顺序** — 渐进式功能开放
- **首次体验** — 前 5 分钟的完整流程

### UrhoX 适配要点
- UI 提示使用 `urhox-libs/UI` 的 Tooltip / Modal 组件
- 高亮引导可用 NanoVG 叠加遮罩
- 存储教程完成状态：本地 `File` API 或 `clientCloud`

---

## ch07: 留存设计 (Retention)

### 必填内容
- **日留存机制** — 每日登录奖励、限时活动
- **周留存机制** — 周任务、赛季进度
- **回流钩子** — 离线收益、推送通知
- **社交留存** — 排行榜、好友互动

### UrhoX 适配要点
- 排行榜：`clientCloud` score API
- 离线收益：记录离线时间戳到 `clientCloud`

---

## ch08: 商业化 (Monetization)

> **按类型跳过**: casual 类型跳过此章

### 必填内容
- **付费模型** — 买断 / F2P / 订阅
- **内购设计** — 虚拟货币、道具、外观
- **广告策略** — 激励视频、插屏
- **价值感知** — 付费玩家与免费玩家的体验差异

### UrhoX 适配要点
- TapTap 广告集成：`get_ad_config` 工具
- 广告位类型：激励视频（rewarded）、插屏（interstitial）

---

## ch09: 美术方向 (Art Direction)

### 必填内容
- **视觉风格** — 写实 / 卡通 / 像素 / 低多边形
- **色彩方案** — 主色、辅色、强调色（含 HEX 值）
- **参考作品** — 2-3 个视觉参考游戏
- **资源风格指南** — 角色/场景/UI 的视觉一致性

### UrhoX 适配要点
- PBR 材质：参考 `materials` skill
- AI 图像生成：使用 `generate_image` 工具生成概念图
- 像素风格：参考 `pixel-art-generator` skill
- 角色立绘：参考 `character-portraits` skill

---

## ch10: UI/UX

### 必填内容
- **界面架构** — 主菜单、游戏内 HUD、暂停、设置
- **交互流程** — 界面跳转关系图
- **视觉风格** — 与 ch09 美术方向一致
- **适配方案** — 横屏/竖屏、不同分辨率

### UrhoX 适配要点（重要）
- **必须使用** `urhox-libs/UI` 组件库（原生 UI 已废弃）
- 布局方案：Yoga Flexbox
- 适配策略：`UI.Scale.DEFAULT` 或自定义设计分辨率
- 参考：`examples/14-ui-widgets-gallery.lua`（40+ 组件示例）
- UI 主题：参考 `ui-astroon` / `ui-brawlforge` / `soyoyo_gothic-ui` skill

---

## ch11: 技术需求 (Tech Requirements)

### 必填内容
- **脚手架选择** — 2D / 2D物理 / 3D场景 / 3D角色
- **物理引擎** — Box2D (2D) / Bullet (3D) / 无
- **渲染方案** — NanoVG (2D自绘) / 3D PBR / 混合
- **代码组织** — 单文件 / 多模块（超过 1000 行必须拆分）
- **性能预算** — 目标帧率、同屏上限

### 模板

```markdown
## 技术选型 (C-11-001)
- 脚手架: scaffold-2d-physics.lua（2D 平台跳跃）
- 物理: Box2D
- 渲染: NanoVG（纯 2D 自绘）
- 入口文件: scripts/main.lua

## 代码组织 (C-11-002)
scripts/
├── main.lua            # 入口
├── game/
│   ├── Player.lua      # 玩家逻辑
│   ├── Enemy.lua       # 敌人逻辑
│   └── Level.lua       # 关卡管理
├── ui/
│   └── HUD.lua         # 界面
└── config/
    └── balance.lua     # 数值配置

## 构建配置 (C-11-003)
- 入口: scripts/main.lua
- 构建工具: UrhoX MCP build
- 发布平台: TapTap (移动+PC)
```

---

## ch12: 数据分析 (Analytics)

> **按类型跳过**: casual 类型跳过此章

### 必填内容
- **关键指标** — DAU、留存率、ARPU、转化率
- **埋点方案** — 关键行为的数据记录
- **AB测试计划** — 需要测试的设计假设

---

## ch13: 投资回报 (ROI)

> **按类型跳过**: casual、strategy 类型跳过此章

### 必填内容
- **开发资源估算** — 时间、人力
- **目标收入** — 预期收入来源和规模
- **里程碑** — 关键交付节点

---

## ch14: 多人模式 (Multiplayer)

> **按类型跳过**: puzzle、idle 类型跳过此章

### 必填内容
- **多人类型** — 合作 / 对抗 / 混合
- **同步方案** — 状态同步 / 帧同步
- **匹配机制** — ELO / 随机 / 好友

### UrhoX 适配要点（关键）
- 读取 `.project/settings.json` 中的 `multiplayer.enabled`
- C/S 架构：分离 `scripts/network/Client.lua` 和 `Server.lua`
- 云变量：`serverCloud` 管理服务端状态
- 匹配：构建配置中的 `match_info` 设置
- 参考：`examples/22-third-person-shooter`（多人射击示例）

---

## ch15: 平台集成 (Platform Integration)

### 必填内容
- **发布平台** — TapTap 移动端 + PC
- **云服务** — 云存档、排行榜、成就
- **社交功能** — 分享、邀请

### UrhoX 适配要点
- TapTap 发布：`publish_to_taptap` 工具
- 云存档：`clientCloud` 变量存储
- 排行榜：`clientCloud` score + leaderboard API
- 广告：`get_ad_config` 工具
- 测试：`generate_test_qrcode` 生成测试二维码

---

## 通用编写原则

1. **具体优于抽象** — 不要写"好的UI"，写"使用 Panel + Label + Button 的暗色主题菜单"
2. **引用 ID** — 每个关键设计决策都分配 C-XX-NNN 格式的 ID
3. **关联章节** — 明确标注与其他章节的引用关系
4. **UrhoX 可行性** — 确保所有技术描述在引擎能力范围内
5. **适当深度** — 每章不少于 200 字，核心章节（ch02/ch03）不少于 500 字

