# 银河征服 V2.5 稳定化更新计划

> 创建时间: 2026-06-17
> 状态: 待执行
> 类型: 🔴 紧急稳定化（Stabilization）+ V2.5 新功能

---

## 0. 背景与关键发现

V2.0–V2.4 的大量系统（外交/危机/指挥官/巨构/任务板/涂装/百科/变异舰船/文明遗产/自定义阵型等）
在提交 `20356d8`（"同步项目最新进度"）中一次性合入，**同时把单体 `Client.lua` 拆分为
`ClientSetup` / `ClientBattle` / `ClientGalaxy` / `ClientInput` / `ClientSave` 多个模块**。

这次拆分引入了**系统性接口命名漂移（interface naming drift）**：
拆分时调用方写下了"理想中的函数名/字段名/参数签名"，但被调用模块里的**实际名字不同**。
由于 Lua 是动态语言，这类 `attempt to call a nil value` / 参数错位问题**构建期不报错，只在运行时触发**。

### 已修复（本轮 06-17 已完成）

| 编号 | 位置 | 问题 | 修复 |
|------|------|------|------|
| FIXED-1 | `Client.lua:1242` | `GameUI.RenderNotifications` 未定义 | 补函数，接通 `NotifyPanel.RenderToasts` |
| FIXED-2 | `ClientSetup.lua:245` | `onSeedDeploy` 调用不存在的 `ColonizePlanet`、签名错误 | 对照 git 历史恢复（解锁 UI + 切场景） |
| FIXED-3 | `ClientSetup.lua:241` | `onFleetContactPlanet` 调用 `ColonizePlanet` | 改为 `ClientGalaxy.DoColonize` |
| FIXED-4 | `ClientBattle.lua:577` | `GetPlayerTargets` 返回 `{name,pos}`，但 `PirateAI` 期望 `{x,y,name}` → 海盗进攻时 `t.x` 为 nil，每帧崩溃 | 对照 git 历史恢复轨道世界坐标 `{x,y,name}` |
| FIXED-5 | `TutorialSystem.lua` | 全屏遮罩 `addHit` 最后注册，被 `OnClick`"后注册优先"最先命中 → 吞掉教程按钮点击（点击无反应） | 遮罩改为最先注册，按钮优先命中（顺序漂移） |
| FIXED-6 | `QuestBoard.lua:171/173/177` | `rm:getMetal()/getEnergy()/getSalvage()` 方法不存在 → 任务条件检测时崩溃 | 改为 `rm.resources.metal`/`.esource` + 新增 `fm` 参数取 `fm.salvageParts` |

### 仍存在的回归（本计划核心）

经静态审计 + 逐个 grep 实证验证，**确认 16 处同类回归 + 1 处需确认**。
影响面覆盖几乎所有核心流程：**点击星球、点击编队、进入战斗、战斗结算、场景切换、市场、
银河事件、批量建造、探索任务、战役模式**。

**回归共分三类形态**（修复时都要警惕）：
1. **接口命名漂移**：调用方用了理想中的函数名，目标模块实际名字不同（如 `ShowPlanetPanel`→`RefreshPlanetPanel`、`StartBattle`→`OnFleetSiegeBase`、`QuestBoard` 的 `rm:getMetal()` 实际是 `rm.resources.metal`）。本计划阶段一 16 项多属此类。
2. **数据结构契约漂移**：跨模块传递的 table 字段结构不一致（如 FIXED-4：`GetPlayerTargets` 返回 `{name,pos}`，消费方 `PirateAI` 却读 `t.x`/`t.y`）。函数名正确、构建通过，但运行时取到 nil。
3. **事件/命中顺序漂移**：immediate-mode UI 的 `addHit` 注册顺序与 `OnClick` 的"后注册优先"遍历相互矛盾（如教程全屏遮罩最后注册，反而吞掉按钮点击）。

> **修复时必须逐一核对：① 目标函数名是否存在；② 跨模块数据 getter/回调的字段契约；③ UI 热区/事件注册顺序。**

> **结论：游戏当前几乎不可玩。** 在跑通一局之前，不应推进任何 V2.5 新功能。

### 修复方法论（金标准）

所有正确实现都保留在**重构前的单体 `Client.lua`（`20356d8` 之前的历史版本）**中。
统一修复方法：
1. `git log -p -S "<回调名>" -- scripts/network/Client.lua` 提取重构前原始实现；
2. grep 确认目标模块中**实际存在**的函数名/签名；
3. 对照恢复，确保**语义一致**（不是简单改名，要核对行为）；
4. 每修一批 → `build` → 预览验证对应流程。

---

## 阶段一 · P0：紧急回归修复（恢复可玩性）

> 按**游戏流程触发顺序**分组，每修一组即可预览验证一段流程。

### P0-A：核心主循环（开局 → 操作 → 战斗 → 结算）

| 编号 | 位置 | 错误调用 | 正确目标（已 grep 验证） | 修复方式 | 触发点 |
|------|------|---------|------------------------|---------|--------|
| BUG-04 | `ClientSetup.lua:233` | `GameUI.ShowPlanetPanel(p)` | 该函数不存在；历史版 `onPlanetSelect` **不含此调用** | 移除调用，恢复原始逻辑（设 `selectedPlanet_` + 殖民模式判断） | 点击星球 |
| BUG-05 | `ClientSetup.lua:237,439` | `GameUI.ShowFleetPanel(fid)` | `RefreshFleetPanel(fm,fid)` + `SetMapSelectedFleet(fid)` | 对照历史恢复两处 | 点击编队 |
| BUG-02 | `ClientSetup.lua:254` | `ClientBattle.StartBattle(fleet,base)` | `ClientBattle.OnFleetSiegeBase(fleetId,baseId)` | 改名 + 传 `.id` 字段 | 舰队围攻海盗基地 |
| BUG-15 | `ClientBattle.lua:289-295` | `dda.history` | 字段实际名 `dda.recentResults` | 统一字段名 | 每场战斗结束 |
| BUG-01 | `ClientBattle.lua:1192` | `ShowEndGame(gameType,stats,scoreVal,cb)` 4 参 | `ShowEndGame(gameType,stats,onRetry)` 3 参 | 把 `scoreVal` 并入 `stats`，回调作第 3 参 | 战斗结算 / 再来一局 |
| BUG-10 | `ClientBattle.lua:569,572` | `Audio.SwitchBGM("galaxy"/"battle")` | `Audio.PlayBGM(path,dur,looped)` | 建立场景→BGM 路径映射后调用 | 星图↔战斗切换 |

### P0-B：次级交互流程

| 编号 | 位置 | 错误调用 | 正确目标 | 修复方式 | 触发点 |
|------|------|---------|---------|---------|--------|
| BUG-03 | `ClientSetup.lua:288` | `GameUI.ShowEventChoices(ev,cb)` | `GameUI.ShowEventPopup(ev,onChoice)` | 改名 + 核对回调参数 | 选择型银河事件 |
| BUG-14 | `ClientSetup.lua:320` | `GalaxyEvents.TriggerChain(ev)` | `GalaxyEvents.ScheduleChain(typeKey,wx,wy)` | 改名 + 补坐标参数 | 链式事件触发 |
| BUG-06 | `ClientGalaxy.lua:151` | `GameUI.RefreshMarketPanel()` | 不存在；确认市场刷新机制 | 改为正确刷新调用或移除（**需确认**） | 市场交易后 |
| BUG-07 | `ClientSetup.lua:540` | `GalaxyScene.JumpToPlanet(planet)` | 不存在（`WarpFleetToPlanet` 语义不同） | 确认意图：相机聚焦 or 派舰队（**需确认**） | 帝国总览星球跳转 |
| BUG-08 | `ClientSetup.lua:536` | `ClientGalaxy.OnBatchBuild(...)` | 不存在（有 `OnBatchUpgrade`） | 确认批量建造逻辑去向（**需确认**） | 批量建造 |
| BUG-09 | `ClientSetup.lua:434` | `ClientGalaxy.OnExplorerTask(...)` | 不存在（有 `OnExplorerColonize`） | 确认探索任务派遣逻辑（**需确认**） | 探索任务派遣 |

### P0-C：静默失效（不崩溃但功能完全废掉）

| 编号 | 位置 | 问题 | 正确目标 | 修复方式 | 影响 |
|------|------|------|---------|---------|------|
| BUG-13 | `ClientBattle.lua:541,1096` | 读 `S.isCampaignMode` | 代理表字段是 `campaignMode` | 统一字段名（或代理表加别名） | 战役模式判断恒为 false |
| BUG-11 | `ClientBattle.lua:542` | `Campaign.OnMissionComplete(diff)` | `CampaignSystem.CompleteLevel()` | 改名 + 核对参数 | 战役关卡无法完成 |
| BUG-12 | `ClientBattle.lua:1097` | `Campaign.OnMissionScore(score,stars)` | 不存在 | 确认战役计分接口（**需确认**） | 战役计分失效 |
| BUG-16 | `ClientBattle.lua:1165` | `AwardEndOfGame(gameType,score,stars,time)` 4 散值 | `AwardEndOfGame(stats)` 单表 | 构造 `stats` 表（`survived10Waves`/`kills`/`builtMegastructure`…） | 文明遗产积分恒为 0 |

### P0-D：待确认

| 编号 | 位置 | 问题 | 待确认 |
|------|------|------|--------|
| SUSPECT-1 | `ClientSetup.lua:926` | `MegastructureSystem.StartPhase(megaId,rm_)` 多传 `rm_` | 定义仅收 `key`；确认巨构阶段建造的**资源扣除**是否在别处完成，避免免费建造 |

---

## 阶段二 · P1：回归防护（避免再次发生）

这次灾难的根因是**缺少捕获 nil 调用/参数错位的检查手段**。修复后必须补防护：

- **P1-1 端到端冒烟测试清单**：在 `docs/` 建立手动验证清单，覆盖完整一局核心流程
  （开局展开 → 殖民 → 建造 → 研究 → 派队 → 战斗 → 结算 → 再来一局 → 存读档 → 战役 → 联赛）。
  每次涉及 `network/` 改动后，按清单逐项点检。
- **P1-2 LSP 诊断接入**：当前云端 LSP（端口 9527）未启动，无法在构建前捕获 `undefined-field`。
  恢复 LSP 后，将 `textDocument/diagnostic severity=1` 纳入构建前必检流程。
- **P1-3 接口契约自检脚本**：编写一个轻量 grep/Lua 脚本，扫描 `network/` 对各模块的
  `Module.Fn(...)` 调用，比对目标模块的 `function Module.Fn` 定义，输出"调用了但未定义"清单
  （即本次审计的自动化版本），纳入提交前检查。

---

## 阶段三 · P2/P3：V2.5 新功能（稳定后再启动）

⚠️ **前置条件：阶段一全部修复完成、冒烟清单全绿、能稳定跑通完整一局。**

V2.5 的功能代码大多**已存在**（`MutantShipSystem.lua` / `LegacySystem.lua` / `ui/FormationEditor.lua`
/ `GalaxyGenerator.lua` 等文件都在），但因上述回归而**无法正常工作**。
因此 V2.5 阶段的重点是"**让已写好的功能真正跑起来 + 打磨**"，而非从零新增：

- **P2-1 星系生成器**：5 种星系形态 + 特殊星球类型（详见 `plan.md` § V2.5 P1-1）
- **P2-2 变异舰船**：12 种词缀 + Boss 掉落（`MutantShipSystem.lua` 已存在，需验证战斗触发链路）
- **P2-3 文明遗产**：跨局 LP + 3 条遗产树（依赖 BUG-16 修复后积分才正常）
- **P3-1 自定义阵型编辑器**：8×6 网格拖拽（`ui/FormationEditor.lua` 已存在，需验证战斗坐标加载）
- **P3-2 舰队命名与战斗日志**：（详见 `plan.md` § V2.5 P2-2）

> 具体设计沿用 `docs/plan.md` 第 1749 行起的 V2.5 章节，本计划不重复展开。

---

## 验收标准

### 阶段一（P0）
- [ ] 16 个回归全部修复，`build` 通过
- [ ] 能从开局走完整一局而**无运行时报错**：展开基地 → 点击星球/编队 → 殖民 → 建造/研究 →
      派队作战 → 战斗结算 → 再来一局
- [ ] 场景切换（星图↔战斗）BGM 正常、无崩溃
- [ ] 市场交易、银河事件选择、批量建造、探索任务、链式事件均不崩
- [ ] 战役模式可正常完成关卡（BUG-13/11/12）
- [ ] 文明遗产结算后 LP 正常增长（BUG-16）

### 阶段二（P1）
- [ ] 冒烟测试清单建立并跑通一轮
- [ ] 接口契约自检脚本可用，输出为空

### 阶段三（P2/P3）
- [ ] 各 V2.5 功能逐项验证可用

---

## 风险评估

| 风险 | 等级 | 说明 / 缓解 |
|------|------|------------|
| 修复时再次"猜函数名" | 🔴 高 | 必须对照 git 历史 + grep 实证，禁止凭记忆 |
| 语义偏差（改对名字但行为不对） | 🟠 中 | 每个回调核对重构前实现的完整逻辑，不只改符号 |
| "需确认"项（BUG-06/07/08/09/12 + S1）逻辑可能在重构中丢失 | 🟠 中 | 这些功能的实现可能未被拆分出去，需从历史定位原函数体并补回 |
| 修复引入新回归 | 🟡 低 | 分组修复 + 每组构建预览 + 冒烟清单 |
| LSP 不可用，构建期无静态保护 | 🟠 中 | 依赖人工审计 + P1-3 自检脚本兜底 |

---

## 推荐执行顺序

```
P0-A（核心主循环 6 项）  → build → 预览：开局到结算跑通
        ↓
P0-B（次级流程 6 项）    → build → 预览：事件/市场/建造/探索
        ↓
P0-C（静默失效 4 项）    → build → 预览：战役 + 遗产积分
        ↓
SUSPECT-1 确认           → 修复或确认无误
        ↓
P1（防护：冒烟清单 + 自检脚本）
        ↓
P2/P3（V2.5 新功能逐项验证与打磨）
```

---

## 涉及文件清单

- `scripts/network/ClientSetup.lua` — BUG-02/03/04/05/07/08/09/14 + S1
- `scripts/network/ClientBattle.lua` — BUG-01/10/11/12/13/15/16
- `scripts/network/ClientGalaxy.lua` — BUG-06
- 参考（金标准）：重构前 `scripts/network/Client.lua` 的 git 历史版本
- 被调用模块（核对定义）：`game/GameUI.lua`、`game/GalaxyScene.lua`、`game/AudioManager.lua`、
  `game/CampaignSystem.lua`、`game/GalaxyEvents.lua`、`game/LegacySystem.lua`、`game/MegastructureSystem.lua`
