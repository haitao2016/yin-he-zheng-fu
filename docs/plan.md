# 银河征服 - 开发计划

> 最后更新：2026-05-13（V1.1 全量完成后更新）

---

## ✅ 已完成（V1.0 & V1.1）

### V1.0 核心功能
- P1-1 战斗结算界面（胜利/失败弹窗 + 数据展示）
- P1-2 存档与读档（本地 File API + 云端 serverCloud）
- P1-3 主菜单（Logo + 新游戏/继续游戏 + 难度选择）
- P3-1 音效完善（攻击/建造/科技/通知/胜败 BGM 全覆盖）

### V1.1 深度扩展
- P2-1 难度平衡（easy/hard 初始资源、进攻间隔、动态威胁参数）
- P2-2 科技树扩展（NANO_REPAIR / DEFENSE_MATRIX / PHASE_DRIVE，共 13 科技）
- P2-3 星球视觉特化（PLANET_TYPE_COLORS，6 种星球类型色系）
- P2-4 新舰种（CARRIER 母舰 AOE / INTERCEPTOR 拦截舰高速，完整 8 舰种）
- P3-2 成就云端同步（解锁时回调 clientCloud:SetString）
- P3-3 UI 微交互（资源数字滚动动画 + 按钮点击涟漪效果）
- P3-4 新手引导优化（跳过按钮样式升级至带背景/边框的真实按钮）
- P3-5 性能优化（涟漪 swap-remove O(1) 替代 table.remove O(n)）
- Bug Fix：设置按钮热区修复

---

## 🐛 已知 Bug（待修复）

| 优先级 | 描述 | 文件 | 修复思路 |
|--------|------|------|---------|
| 🔴 高 | CARRIER/INTERCEPTOR 战斗中显示为三角形（未加载贴图） | `BattleScene.lua:135` | 生成对应舰船图片并加入 shipImages_ 加载 |
| 🔴 高 | CARRIER/INTERCEPTOR 从未出现在敌方波次中（buildEnemyWave 未引用） | `BattleScene.lua:93` | 高波次（wave≥10）加入 CARRIER；INTERCEPTOR 作为群攻型敌方 |
| 🟡 中 | 继续游戏难度固定为 normal（存档中未保存难度） | `Client.lua:1271` | 存档写入 difficulty_；读档时恢复，跳过难度选择直接使用 |

---

## 🔲 V1.2 开发计划（新版）

### B1 - Bug 修复（必须最先完成）

**B1-1 新舰种贴图与战斗集成**
- 生成 CARRIER（母舰）和 INTERCEPTOR（拦截舰）舰船贴图（AI 生图）
- `BattleScene.lua`：在 `BattleScene.Init` 中加载两张新贴图
- `BattleScene.lua`：在 `buildEnemyWave` 中：wave≥7 引入 INTERCEPTOR 群；wave≥10 引入 CARRIER
- `BattleScene.lua`：在 renderShip 的 scale 表里加入 CARRIER(2.5) / INTERCEPTOR(0.8) 的尺寸配置
- 预期效果：新舰种在战斗中正常显示并参与战斗

**B1-2 难度存档修复**
- `Client.lua`：存档 JSON 中写入 `difficulty` 字段
- `Client.lua`：读档时恢复 `difficulty_` 并直接设 `difficultyChosen_=true`，跳过难度选择
- 预期效果：继续游戏保持原局难度，而非强制 normal

---

### P1 - 内容扩充（高优先级）

**P1-1 成就扩充**
- 当前仅 7 个成就，增加到 15 个
- 新增类型：
  - `fleet_builder`：建造 20 艘舰船
  - `tech_master`：研究全部科技
  - `resource_hoarder`：同时持有 5000 金属
  - `wave_survivor`：在单次战斗中存活 10 波
  - `colony_10`：殖民 10 颗星球
  - `pirate_destroyer`：击败 10 次海盗袭击
  - `no_damage_win`：基地 HP 满血胜利（高难度成就）
  - `carrier_deploy`：建造并使用第一艘母舰
- 文件：`AchievementSystem.lua`

**P1-2 战斗场景增强**
- 新增技能按钮（战斗中可用主动技能）：
  - 「全体集火」：全舰队攻击同一目标 5 秒（冷却 30s）
  - 「紧急修复」：所有舰船回复 20% HP（冷却 60s，需 NANO_REPAIR 科技）
- CARRIER 的特殊能力：定期在周围召唤 2 艘 SCOUT 无人机
- 文件：`BattleScene.lua`

**P1-3 星球管理优化**
- PlanetPanel 增加「全部征收」快捷按钮（一键收取所有星球资源）
- 星球列表增加筛选/排序（按类型/按产量）
- 显示当前全局资源生产速率（顶栏 +X/s 提示）
- 文件：`GameUI.lua`、`PlanetPanel.lua`、`TopBar.lua`

---

### P2 - 体验深化（中优先级）

**P2-1 波次预报系统**
- 战斗前 10 秒显示下一波组成（「即将到来：3 驱逐舰 + 1 战列舰」）
- 顶栏显示当前波次进度（Wave N / ∞）和下一波倒计时
- 文件：`BattleScene.lua`、`GameUI.lua`

**P2-2 星图探索事件**
- 随机星系事件（概率触发，类似随机卡牌事件）：
  - 「废弃矿场」：派 EXPLORER 可获得随机资源包
  - 「中立商人」：花费金属购买科技加速（减少 30% 研究时间）
  - 「时空裂缝」：舰队穿越可瞬移到任意星球（随机正负效果）
- 事件节点显示在星图上（闪烁标记）
- 文件：`GalaxyScene.lua`、`Client.lua`

**P2-3 基地升级系统**
- 当前主基地只有耐久，增加升级路线：
  - Lv2：+2 资源槽位、防御炮台（基地自动抵挡伤害）
  - Lv3：+1 舰队编队上限、研究速度 +20%
- BasePanel 增加「基地升级」入口
- 文件：`BasePanel.lua`、`Client.lua`

---

### P3 - 体验打磨（低优先级）

**P3-1 多人在线大厅**
- 当前 Server.lua 仅广播玩家列表，无实际多人互动
- 增加多人合作模式：两玩家共享同一星图，可互相支援舰队
- 需要 Server.lua 增加事件转发（玩家 A 的舰队支援事件广播给 B）
- 文件：`Server.lua`、`Client.lua`、`network/Shared.lua`

**P3-2 视觉升级**
- 战斗场景添加背景星空（NanoVG 绘制动态星点，视差滚动）
- 舰船受击时短暂闪白（hit flash 效果）
- 波次胜利时烟花粒子特效
- 文件：`BattleScene.lua`

**P3-3 音效补全**
- 目前缺少：
  - CARRIER 特殊攻击音效（重低音）
  - INTERCEPTOR 高速移动音效（引擎声）
  - 成就解锁专属音效（fanfare）
  - 波次预报倒计时「滴答」声
- 文件：`AudioManager.lua`、`BattleScene.lua`

---

## 📊 技术债务

| 文件 | 行数 | 建议 |
|------|------|------|
| `GalaxyScene.lua` | 2562 行 | 考虑拆分为 `GalaxyRender.lua`（渲染）+ `GalaxyLogic.lua`（逻辑） |
| `Client.lua` | 2196 行 | 考虑拆分 `GameLogic.lua`（胜负/存档/成就）+ `InputHandler.lua` |
| `GameUI.lua` | 2159 行 | 结算层、排行榜层可独立为 `ui/EndGamePanel.lua`、`ui/LeaderboardPanel.lua` |

> 当前无性能瓶颈，拆分优先级低，可在下一次大功能开发前进行。

---

## 📁 项目结构（当前）

```
scripts/
├── main.lua
├── network/
│   ├── Client.lua           # 客户端主逻辑（2196 行）
│   ├── Server.lua           # 服务端（255 行）
│   └── Shared.lua           # 共享常量
└── game/
    ├── GalaxyScene.lua      # 银河地图（2562 行）
    ├── BattleScene.lua      # 战斗场景（867 行）
    ├── GameUI.lua           # UI 主模块（2159 行）
    ├── PirateAI.lua         # 海盗 AI（511 行）
    ├── Systems.lua          # 游戏系统（1234 行）
    ├── AudioManager.lua     # 音频
    ├── AchievementSystem.lua# 成就（121 行）
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

## 🗓️ 推荐执行顺序

```
1. B1-1（新舰种贴图 + 战斗集成）  ← 修复已上线但不可用的功能
2. B1-2（难度存档修复）            ← 影响游戏体验的存档 bug
3. P1-1（成就扩充）                ← 无代码风险，内容填充
4. P1-3（星球管理优化）            ← 提升日常操作效率
5. P2-1（波次预报）                ← 提升战斗可读性
6. P1-2（战斗技能）                ← 需要较多 BattleScene 改动
7. P2-2（星图探索事件）            ← 新系统，需设计验证后再开发
8. P2-3（基地升级）                ← 涉及存档兼容，需谨慎
9. P3-x（视觉/音效/多人）         ← 最后润色
```
