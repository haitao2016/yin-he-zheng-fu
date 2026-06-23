# 银河征服 - 开发计划

> 创建时间: 2026-05-13
> 最后更新: 2026-05-13
> 来源: 自由对话（多轮迭代开发）
> 状态: 已完成

---

## 1. 项目概述

**银河征服**是一款太空策略游戏，玩家从一颗星球出发，通过资源采集、建筑建造、科技研究、舰队作战，逐步殖民银河系并击败海盗势力。

- **核心玩法**：银河地图殖民 + 实时战斗 + 科技树解锁 + 经济管理
- **技术栈**：UrhoX + Lua，NanoVG 全屏渲染，多人/单机双模式
- **已上线版本**：V1.4（全功能完整版）

---

## 2. 需求摘要

- 完整的太空策略 4X 体验（探索、扩张、开发、消灭）
- 可玩性强的波次战斗系统，支持技能与连击
- 丰富的科技树（13 项科技，4 个 Tier）
- 海盗 AI 智能进攻，情报系统闭环
- 成就系统云端同步
- 广告变现（建造加速、科研加速、资源补给）
- 全设备适配（PC / 移动端触控）

---

## 3. 技术选型

- **渲染**：raw NanoVG（全虚拟坐标系，DPR 自适应）
- **物理**：无（纯逻辑计算）
- **网络**：UrhoX 多人模式（Client.lua / Server.lua）
- **存档**：本地 JSON 文件存储
- **云端**：clientCloud 成就同步 + 排行榜
- **广告**：sdk_:ShowRewardVideoAd

---

## 4. 任务拆解

### 已完成（V1.0 ~ V1.3）

✅ V1.0 核心玩法（资源/建筑/科技/舰队/海盗AI/存档/结算）
✅ V1.1 难度平衡 · 科技树扩展(13项) · 新舰种(CARRIER/INTERCEPTOR) · 成就云端同步
✅ V1.1补丁 新舰种贴图 · 难度存档修复 · 成就扩充7→15 · 星球管理优化 · 波次预报 · 战斗技能 · 星图随机事件 · 基地升级 · 受击闪白+烟花粒子 · 音效补全
✅ V1.2 P1-3战斗结算统计 · P1-1成就查看面板 · P2-2Boss波次 · P1-2无尽征服 · P2-1探索任务系统 · P2-3星图事件扩展(3→8) · P3-1战斗技能扩展(3→6) · P3-2星球视觉差异化 · P3-3成就通知合并
✅ V1.3 P1-1科技树可视化 · P1-2星球特产系统 · P1-3海盗情报闭环 · P2-1资源危机预警 · P2-2战斗连击奖励 · P2-3阶段目标×15 · P3-1星际航线网络 · P3-2战斗伤害特效 · P3-3结算星级评分
✅ 广告变现接入（建造加速/科研加速/资源补给）
✅ 全设备适配（BUG-1设置面板触控拖拽 + BUG-2广告防重复点击）

### V1.4 已全部完成

#### P1 核心体验

✅ P1-1 波次战斗摘要弹窗
  - 每波胜利后中央悬浮卡片：击杀数、伤害输出、最高连击、己方损失
  - 淡入淡出动画，3 秒后自动消失
  - 文件：`BattleScene.lua`（waveSummary_ 状态 + drawWaveSummary 函数）

✅ P1-2 资源趋势箭头
  - TopBar 精炼资源数字旁 ▲绿 / ▼红 / →灰
  - 基于 10 秒均值变化计算，resTrendDir_ 变量
  - 文件：`GameUI.lua`（RenderTopBar 区块）

✅ P1-3 建筑升级收益对比
  - BasePanel 升级按钮右侧显示"Lv.N→N+1 +benefit"绿色提示
  - 从 modDef.desc 正则提取每级收益数值
  - 文件：`BasePanel.lua`（line ~398）

#### P2 玩法深度

✅ P2-1 星球殖民优先标记
  - PlanetPanel 优先殖民切换按钮（最多 2 颗）
  - 星图橙色菱形图标 + 脉冲光晕；探索舰优先前往
  - 文件：`PlanetPanel.lua`、`GalaxyScene.lua`（priorityPlanetIds_）、`Client.lua`

✅ P2-2 海盗威胁热力叠层
  - 以海盗基地为中心半透明红色渐变叠层，urgency 脉冲（attackTimer < 20）
  - drawPirateThreatHeatmap() 函数
  - 文件：`GalaxyScene.lua`（line ~2804）

✅ P2-3 星图随机事件扩展（8→14）
  - 新增 6 种事件：TECH_RELIC、FUEL_DEPOT、ALIEN_SIGNAL、METEOR_SWARM、STRANDED_CREW、DARK_MATTER
  - EVENT_TYPE_KEYS 从 8 扩展至 14 个条目
  - 文件：`GalaxyScene.lua`（EVENT_TYPES 表 + EVENT_TYPE_KEYS 数组）

#### P3 视觉润色

✅ P3-1 星球殖民涟漪动画
  - 殖民成功时扩散 3 圈蓝色光环（半径递增+透明度递减）
  - drawColonyRipples() + colonyRipples_ 状态
  - 文件：`GalaxyScene.lua`（line ~2852）

✅ P3-2 舰队编组预设
  - FleetPanel 3 个预设槽，支持保存/加载舰队阵型
  - 预设数据本地持久化
  - 文件：`FleetPanel.lua`（presets_ 状态 + 保存/加载逻辑）

✅ P3-3 排行榜入场动画
  - 条目从下方依次飞入（间隔 30ms），金色发光边框高亮自己排名
  - lbAnimT_ 动画计时器，stagger 偏移计算
  - 文件：`GameUI.lua`（排行榜渲染区块 line ~1902）

---

## 5. 文件结构

```
scripts/
├── main.lua
├── network/
│   ├── Client.lua           # 客户端主逻辑（2733 行）
│   ├── Server.lua           # 服务端
│   └── Shared.lua           # 共享常量
└── game/
    ├── GalaxyScene.lua      # 银河地图（3455 行）
    ├── BattleScene.lua      # 战斗场景（2573 行）
    ├── GameUI.lua           # UI 主模块（3112 行）
    ├── PirateAI.lua         # 海盗 AI
    ├── Systems.lua          # 游戏系统（1304 行）
    ├── AudioManager.lua     # 音频
    ├── AchievementSystem.lua# 成就
    └── ui/
        ├── UICommon.lua
        ├── TopBar.lua
        ├── BasePanel.lua
        ├── FleetPanel.lua
        ├── TechPanel.lua
        ├── PlanetPanel.lua
        ├── NotifyPanel.lua
        └── TutorialSystem.lua
```

---

## 6. 风险与注意事项

- **文件行数过长**：GalaxyScene.lua(3455行)、GameUI.lua(3112行)、Client.lua(2733行)、BattleScene.lua(2573行) 建议适时重构
- **NanoVG 坐标系**：所有坐标使用虚拟坐标（`UICommon.getVirtualSize()` 返回值），不直接使用物理分辨率
- **触控兼容**：新增 UI 交互必须同时支持鼠标和触控（参考 BUG-1 修复模式）
- **广告回调**：广告加载中状态（`adLoading_`）必须在调用前设 true、回调后设 false（参考 BUG-2 修复模式）

---

## 7. 验收标准

- V1.4 所有 9 个功能点实现完毕 ✅
- 构建无错误 ✅
- 新功能在 PC 鼠标和移动端触控均可正常使用 ✅
- 无新增 Lua LSP 错误 ✅

---

## 完成摘要

- **完成时间**: 2026-05-13
- **总任务数**: 9
- **完成任务**: 9 (100%)
- **取消任务**: 0

### 全部任务清单
✅ 1. P1-1 波次战斗摘要弹窗
✅ 2. P1-2 资源趋势箭头
✅ 3. P1-3 建筑升级收益对比
✅ 4. P2-1 星球殖民优先标记
✅ 5. P2-2 海盗威胁热力叠层
✅ 6. P2-3 星图随机事件扩展（8→14）
✅ 7. P3-1 星球殖民涟漪动画
✅ 8. P3-2 舰队编组预设
✅ 9. P3-3 排行榜入场动画

### 关键产出
- `scripts/game/BattleScene.lua` — 波次摘要弹窗（waveSummary_ + drawWaveSummary）
- `scripts/game/GameUI.lua` — 资源趋势箭头（resTrendDir_）+ 排行榜入场动画（lbAnimT_）
- `scripts/game/ui/BasePanel.lua` — 建筑升级收益对比
- `scripts/game/ui/PlanetPanel.lua` — 殖民优先标记按钮
- `scripts/game/GalaxyScene.lua` — 优先标记橙色图标 + 热力叠层 + 14种随机事件 + 涟漪动画
- `scripts/game/ui/FleetPanel.lua` — 舰队编组预设（3槽保存/加载）
- `scripts/network/Client.lua` — 优先标记回调 + 广告防重复（BUG-2修复）

### 回顾
- **亮点**: 9项功能均提前在代码中实现，V1.4开发工作已完成度极高；BUG-1/BUG-2广告防护修复完善了变现系统的稳定性
- **问题**: settingsDragCtx_ 前向声明问题（Lua 变量需在引用前声明，移至顶部变量块解决）
- **可改进**: 4个核心文件均超 2500 行，建议按功能职责拆分模块（GalaxyRender/GalaxyLogic、UIPanel 独立等）

---

## 修订记录

| 版本 | 日期 | 变更内容 |
|------|------|---------|
| v1 | 2026-05-13 | 初始保存，包含 V1.0~V1.3 完成记录 + V1.4 全部 9 项待开发计划 |
| v2 | 2026-05-13 | 开发完成，结项归档。V1.4 全部 9 项均已实现，构建通过 |
