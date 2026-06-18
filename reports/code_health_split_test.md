# 代码健康度检查报告

- **生成时间**: 2026-06-18 04:51:29
- **扫描目录**: `/workspace/scripts`
- **整体健康度评分**: **47 / 100**

## 📊 总体统计

| 指标 | 数值 |
|------|------|
| 代码文件数 | 93 |
| 总行数 | 49,927 |
| 代码行 | 38,991 |
| 注释行 | 6,648 |
| 平均注释率 | 13.3% |
| 函数总数 | 1087 |

## 📦 大文件建议（建议拆分）

> 超过 **600** 行的文件可能承担了过多职责，建议按功能拆分。

| 文件 | 总行数 | 代码行 | 注释率 |
|------|--------|--------|--------|
| `network/Client.lua` | 2428 | 1919 | 14.6% |
| `game/GalaxyScene.lua` | 2251 | 1797 | 13.1% |
| `game/ui/FleetPanel.lua` | 1690 | 1394 | 9.7% |
| `game/BattleScene.lua` | 1626 | 1311 | 12.8% |
| `game/GalaxyEvents.lua` | 1504 | 1279 | 10.7% |
| `game/GameUI.lua` | 1503 | 1070 | 18.9% |
| `game/ui/EndGamePanel.lua` | 1486 | 1195 | 9.4% |
| `game/battle/BattleAI.lua` | 1485 | 1201 | 12.1% |
| `game/ui/GalaxyPanels.lua` | 1394 | 1148 | 7.8% |
| `game/ui/PlanetPanel.lua` | 1227 | 1025 | 9.9% |
| `network/ClientBattle.lua` | 1205 | 936 | 14.8% |
| `code_health_check.py` | 1202 | 929 | 11.3% |
| `network/ClientSetup.lua` | 1138 | 943 | 11.2% |
| `network/ClientMenus.lua` | 1000 | 798 | 11.3% |
| `game/battle/RenderOverlays.lua` | 974 | 846 | 2.5% |
| `game/galaxy/RenderStarmap.lua` | 948 | 769 | 8.1% |
| `game/ui/TechPanel.lua` | 856 | 661 | 14.5% |
| `game/AchievementSystem.lua` | 814 | 699 | 10.2% |
| `game/PirateAI.lua` | 731 | 543 | 16.6% |
| `game/galaxy/RenderHUD.lua` | 712 | 573 | 7.7% |
| `game/systems/DiplomacySystem.lua` | 698 | 533 | 17.6% |
| `game/battle/RenderHUD.lua` | 666 | 559 | 5.4% |
| `game/ui/ReplayPlayer.lua` | 665 | 480 | 14.1% |
| `game/ui/TutorialSystem.lua` | 655 | 484 | 15.0% |
| `game/ui/TopBar.lua` | 636 | 528 | 11.2% |
| `game/ui/SettingsPanel.lua` | 628 | 489 | 11.6% |

## 🔧 过长函数（> 80 代码行，建议拆分）

| 文件 | 函数名 | 行号范围 | 总行数 | 代码行 |
|------|--------|----------|--------|--------|
| `game/ui/GalaxyPanels.lua` | `M.SetSelectedPlanet(p)` | L93-L475 | 383 | 293 |
| `code_health_check.py` | `generate_markdown` | L918-L1153 | 236 | 200 |
| `game/battle/BattleContext.lua` | `BattleContext.Reset()` | L10-L241 | 232 | 154 |
| `game/ui/MegaPanel.lua` | `MegaPanel.IsOpen()` | L19-L219 | 201 | 148 |
| `code_health_check.py` | `generate_split_plan` | L535-L720 | 186 | 140 |
| `game/ui/CareerPanel.lua` | `CareerPanel.IsOpen()` | L27-L192 | 166 | 119 |
| `game/battle/RenderEntities.lua` | `drawFloatTexts()` | L265-L411 | 147 | 118 |
| `code_health_check.py` | `identify_code_blocks_lua` | L358-L498 | 141 | 115 |
| `game/ui/LegacyPanel.lua` | `LegacyPanel.IsOpen()` | L67-L220 | 154 | 110 |
| `game/BattleScene.lua` | `pushToCtx()` | L1069-L1176 | 108 | 102 |
| `game/ui/NemesisRenderPanel.lua` | `NemesisRenderPanel.IsVisible()` | L18-L154 | 137 | 100 |
| `game/GameUI.lua` | `GameUI.IsFleetNaming()` | L1341-L1503 | 163 | 99 |
| `game/ui/EmpirePanel.lua` | `EmpirePanel.IsVisible()` | L19-L149 | 131 | 92 |
| `game/BattleScene.lua` | `BattleScene.Render()` | L1276-L1393 | 118 | 86 |
| `code_health_check.py` | `run_analysis` | L806-L917 | 112 | 83 |
| `network/Client.lua` | `buildSetupHost()` | L1810-L1895 | 86 | 81 |

## 🔁 重复代码块

> 以下位置存在相似代码（至少 **8** 行），建议抽取为公共函数/模块。

| 位置 A | 位置 B | 涉及行数 |
|--------|--------|----------|
| `code_health_check.py:L51` | `code_health_check.py:L53` | 8 行 |
| `code_health_check.py:L923` | `code_health_check.py:L1070` | 8 行 |
| `game/AchievementSystem.lua:L13` | `game/AchievementSystem.lua:L20` | 8 行 |
| `game/AchievementSystem.lua:L123` | `game/AchievementSystem.lua:L144` | 8 行 |
| `game/BattleScene.lua:L303` | `game/BattleScene.lua:L337` | 8 行 |
| `game/BattleScene.lua:L337` | `game/BattleScene.lua:L355` | 8 行 |
| `game/BattleSkills.lua:L187` | `game/BattleSkills.lua:L195` | 8 行 |
| `game/BattleSkills.lua:L407` | `game/BattleSkills.lua:L446` | 8 行 |
| `game/BlackMarketSystem.lua:L13` | `game/BlackMarketSystem.lua:L14` | 8 行 |
| `game/CampaignSystem.lua:L32` | `game/CampaignSystem.lua:L116` | 8 行 |
| `game/GalactopediaSystem.lua:L22` | `game/GalactopediaSystem.lua:L34` | 8 行 |
| `game/GalaxyEvents.lua:L72` | `game/GalaxyEvents.lua:L87` | 8 行 |
| `game/GalaxyEvents.lua:L221` | `game/GalaxyEvents.lua:L249` | 8 行 |
| `game/GalaxyScene.lua:L115` | `game/galaxy/GalaxyState.lua:L40` | 8 行 |
| `game/GalaxyScene.lua:L246` | `game/GalaxyScene.lua:L333` | 8 行 |
| `game/GameUI.lua:L55` | `game/ui/UICommon.lua:L19` | 8 行 |
| `game/LeagueSystem.lua:L93` | `game/LeagueSystem.lua:L123` | 8 行 |
| `game/LegacySystem.lua:L78` | `game/ui/FormationEditor.lua:L46` | 8 行 |
| `game/LegacySystem.lua:L79` | `game/MutantShipSystem.lua:L134` | 8 行 |
| `game/MutantShipSystem.lua:L134` | `game/ui/FormationEditor.lua:L47` | 8 行 |
| `game/LiverySystem.lua:L13` | `game/LiverySystem.lua:L29` | 8 行 |
| `game/MegastructureSystem.lua:L30` | `game/MegastructureSystem.lua:L44` | 8 行 |
| `game/MegastructureSystem.lua:L30` | `game/MegastructureSystem.lua:L58` | 8 行 |
| `game/MutantShipSystem.lua:L201` | `game/MutantShipSystem.lua:L220` | 8 行 |
| `game/NemesisSystem.lua:L21` | `game/NemesisSystem.lua:L36` | 8 行 |
| `game/NemesisSystem.lua:L166` | `game/NemesisSystem.lua:L192` | 8 行 |
| `game/QuestBoard.lua:L162` | `game/QuestBoard.lua:L164` | 8 行 |
| `game/QuestBoard.lua:L162` | `game/QuestBoard.lua:L187` | 8 行 |
| `game/StarWeather.lua:L19` | `game/StarWeather.lua:L28` | 8 行 |
| `game/battle/BattleAI.lua:L362` | `game/battle/BattleAI.lua:L372` | 8 行 |
| `game/battle/BattleAI.lua:L476` | `game/battle/BattleAI.lua:L522` | 8 行 |
| `game/battle/BattleAI.lua:L1293` | `game/battle/BattleDeath.lua:L202` | 8 行 |
| `game/battle/BattleCombatEnemy.lua:L178` | `game/battle/BattleCombatPlayer.lua:L273` | 8 行 |
| `game/battle/BattleTimers.lua:L211` | `game/battle/BattleTimers.lua:L223` | 8 行 |
| `game/battle/BattleUtils.lua:L116` | `game/battle/BattleUtils.lua:L199` | 8 行 |
| `game/battle/RenderEntities.lua:L281` | `game/battle/RenderEntities.lua:L291` | 8 行 |
| `game/battle/RenderEntities.lua:L281` | `game/battle/RenderEntities.lua:L314` | 8 行 |
| `game/battle/RenderOverlays.lua:L146` | `game/battle/RenderOverlays.lua:L192` | 8 行 |
| `game/battle/RenderOverlays.lua:L675` | `game/battle/RenderOverlays.lua:L692` | 8 行 |
| `game/galaxy/RenderFleets.lua:L498` | `game/galaxy/RenderHUD.lua:L306` | 8 行 |
| `game/galaxy/RenderHUD.lua:L463` | `game/galaxy/RenderStarmap.lua:L856` | 8 行 |
| `game/systems/BuildingSystem.lua:L142` | `game/systems/BuildingSystem.lua:L178` | 8 行 |
| `game/systems/ShipProductionQueue.lua:L15` | `game/ui/GalaxyPanels.lua:L1249` | 8 行 |
| `game/ui/EmpirePanel.lua:L79` | `game/ui/GalaxyPanels.lua:L712` | 8 行 |
| `game/ui/EmpirePanel.lua:L88` | `game/ui/LogPanel.lua:L80` | 8 行 |
| `game/ui/EndGamePanel.lua:L141` | `game/ui/EndGamePanel.lua:L339` | 8 行 |
| `game/ui/EndGamePanel.lua:L275` | `game/ui/LiveryPanel.lua:L103` | 8 行 |
| `game/ui/EndGamePanel.lua:L275` | `game/ui/SettingsPanel.lua:L433` | 8 行 |
| `game/ui/LiveryPanel.lua:L103` | `game/ui/SettingsPanel.lua:L433` | 8 行 |
| `game/ui/EndGamePanel.lua:L1201` | `game/ui/EndGamePanel.lua:L1212` | 8 行 |

## 💡 冗余逻辑 / 可简化结构

| 文件 | 行号 | 原代码 | 建议 |
|------|------|--------|------|
| `code_health_check.py` | L56 | `'`if cond then x = true else x = false end` 可简化为 `x = cond`'),` | `if cond then x = true else x = false end` 可简化为 `x = cond` |
| `game/AchievementSystem.lua` | L282 | `if s.victory ~= true then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/AchievementSystem.lua` | L403 | `check = function(s) return s.tier ~= nil end,` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/AchievementSystem.lua` | L432 | `check  = function(s) return s.tier ~= nil and (s.score or 0) >= 7 end,` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/BattleSkills.lua` | L121 | `if skillPoints_ <= 0 then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/BlueprintSystem.lua` | L286 | `if idx < 1 or idx > #blueprints_ then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/CampaignSystem.lua` | L180 | `if not level then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/CampaignSystem.lua` | L248 | `if not state_.showingDialogue then return true end` | `if cond then return true end` 可简化为 `return cond` |
| `game/CommanderSystem.lua` | L124 | `if not cmd or cmd.level >= COMMANDER_MAX_LEVEL then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/CommanderSystem.lua` | L262 | `if not cmd then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GalaxyEvents.lua` | L1468 | `return endgameCrisis_ ~= nil and not endgameCrisis_.resolved` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/GalaxyEvents.lua` | L1474 | `return endgameCrisis_ ~= nil` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/GalaxyScene.lua` | L358 | `local orbitR = (pi == nil and 1 or pi) * 0  -- 仅用 size 派生` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/GalaxyScene.lua` | L547 | `if not fm_ then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GalaxyScene.lua` | L549 | `if not fl then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GalaxyScene.lua` | L551 | `if e.shipType == "EXPLORER" and e.count > 0 then return true end` | `if cond then return true end` 可简化为 `return cond` |
| `game/GalaxyScene.lua` | L1096 | `if not planet then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GalaxyScene.lua` | L1337 | `if not fm_ then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GameConstants.lua` | L276 | `{ id="research_first", title="完成第一项科技",     desc="解锁任意一项科技",            check=fu` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/GameConstants.lua` | L281 | `if not (gs.rs and gs.rs.unlocked) then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GameConstants.lua` | L301 | `if not gs.colonizedPlanets then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/GameConstants.lua` | L305 | `if b.key == "TRADE_HUB" then return true end` | `if cond then return true end` 可简化为 `return cond` |
| `game/GameUI.lua` | L538 | `if not touchDragActive_ or touchDragId_ ~= id then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/LegacySystem.lua` | L102 | `decoded.lp    = math.min(math.max(decoded.lp or 0, 0), LP_CAP)` | 可提取为独立的 clamp() 函数以减少重复 |
| `game/LegacySystem.lua` | L149 | `if not b then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/LegacySystem.lua` | L150 | `if b.level >= MAX_LEVEL then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/LiverySystem.lua` | L90 | `if item.unlock == "free" then return true end` | `if cond then return true end` 可简化为 `return cond` |
| `game/MegastructureSystem.lua` | L119 | `if not def then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/MegastructureSystem.lua` | L170 | `if not state then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/NemesisSystem.lua` | L415 | `if not state_.activeCaptain then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/NemesisSystem.lua` | L431 | `if not cs or not cs.defeated then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/QuestBoard.lua` | L178 | `return fm ~= nil and (fm.salvageParts or 0) >= t` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/QuestBoard.lua` | L182 | `if not diplo then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/battle/RenderOverlays.lua` | L521 | `local hasMvp = (s.mvp ~= nil and s.mvp.dmg > 0)` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/systems/BuildingSystem.lua` | L246 | `if not planet.buildQueue then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/BuildingSystem.lua` | L248 | `if not job then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/FleetManager.lua` | L94 | `if not fl then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/FleetManager.lua` | L96 | `if not old then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L48 | `if not t or not t.exclusiveGroup then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L49 | `if self.unlocked[id] then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L62 | `if not t then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L63 | `if self.unlocked[id] then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L64 | `if self.active        then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResearchSystem.lua` | L66 | `if not self.unlocked[pre] then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResourceManager.lua` | L109 | `if (self.resources[res] or 0) < amt then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResourceManager.lua` | L115 | `if not self:canAfford(cost) then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ResourceManager.lua` | L123 | `if self.resources[resType] ~= nil then` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/systems/ResourceManager.lua` | L172 | `for k, v in pairs(data.resources) do if self.resources[k] ~= nil then self.resou` | 建议使用显式判空（如 `if x then ... end` 或 `if x is None`） |
| `game/systems/ShipProductionQueue.lua` | L50 | `if index < 1 or index > #self.items then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |
| `game/systems/ShipProductionQueue.lua` | L64 | `if index <= 1 or index > #self.items then return false end` | `if cond then return false end` 可简化为 `return not (cond)` |

## 📝 待办 / 遗留问题

| 类型 | 数量 |
|------|------|
| TODO | 3 |
| XXX | 1 |

### 明细

- [TODO] `code_health_check.py:L291` — 5. TODO / FIXME 统计
- [XXX] `code_health_check.py:L682` — 推断 require 路径：如果原文件位于 game/xxx.lua，则 require "game.{base}_{suffix}"
- [TODO] `code_health_check.py:L832` — 冗余逻辑 / TODO
- [TODO] `code_health_check.py:L1005` — —— TODO

## 🚀 优化建议汇总

- **文件拆分**: 26 个文件超过 600 行，建议按功能拆分为更小的模块。（见下方「📦 代码拆分方案」章节）
- **函数拆分**: 16 个函数逻辑过长，建议将其中重复/独立片段抽取为子函数。
- **去重**: 检测到 50 处重复代码，建议抽取公共 util / helper 函数。
- **简化逻辑**: 50 处冗余 if/return 模式，可直接简化。
- **清理待办**: 共 4 个 TODO/FIXME 标记，建议按优先级分批处理。

---

# 📦 代码拆分方案（自动生成）

> 本次为 **25** 个大文件生成了详细的拆分方案。使用 `--split` 参数可自动创建子模块骨架文件。

## 1. Client.lua

- **原文件路径**: `network/Client.lua`
- **原文件大小**: 2,428 行
- **拆分策略**: 检测到原文件 2428 行，超过阈值 600 行。 建议拆分为 5 个文件（1 个主文件 + 4 个子模块），总计 2253 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `Client_evolution_tree.lua` | 数据表模块（EVOLUTION_TREE 定义） | 53 | L179-L231 |
| 2 | `Client_scalars.lua` | 数据表模块（scalars 定义） | 30 | L1811-L1840 |
| 3 | `Client_general.lua` | general 相关函数（42 个函数，约 389 行代码） | 1903 | L63-L1965 |
| 4 | `Client_core.lua` | Client 相关函数（4 个函数，约 34 行代码） | 217 | L2210-L2426 |

### 子模块内容预览

#### `Client_evolution_tree.lua` — 数据表模块（EVOLUTION_TREE 定义）

- **对应原文件行**: `L179-L231` (53 行)
- **区块类型**: `data`

```lua
local EVOLUTION_TREE = {
    -- 军事路线 (军事线)
    { id="mil_1", line="military", tier=1, unlockCost=2,
      name="久战之师",   icon="⚔",
      desc="首波攻击+8%",
      apply = function(cfg) cfg._mil1 = true end },
    { id="mil_2", line="military", tier=2, unlockCost=5,
      name="钢铁洪流",   icon="🛡",
      d
...
```

#### `Client_scalars.lua` — 数据表模块（scalars 定义）

- **对应原文件行**: `L1811-L1840` (30 行)
- **区块类型**: `data`

```lua
local scalars = {
        pirateAI_               = function() return pirateAI_ end,
        ds_                     = function() return ds_ end,
        selectedPlanet_         = function() return selectedPlanet_ end,
        activeFleetId_          = function() return activeFleetId_ end,
...
```

#### `Client_general.lua` — general 相关函数（42 个函数，约 389 行代码）

- **对应原文件行**: `L63-L1965` (1903 行)
- **区块类型**: `module`
- **包含函数**: `getAdCount()`, `getRemainingTime()`, `buildEvolutionBonus()`, `getEvolutionUnlockedCount()`, `getTodayStr()`, `getDailyCountdown()`, `generateDailyChallenge(dateStr)`, `lcgRand(s)`（共 42 个，其余省略）

```lua
local function getAdCount()
    return math.floor((TL.MAX_EXTRA - TL.extraTime) / TL.EXTRA_PER_AD)
end

local function getRemainingTime()
    return math.max(0, TL.BASE_LIMIT + TL.extraTime - TL.playTime)
end
```

#### `Client_core.lua` — Client 相关函数（4 个函数，约 34 行代码）

- **对应原文件行**: `L2210-L2426` (217 行)
- **区块类型**: `module`
- **包含函数**: `Client.Start()`, `Client.Stop()`, `Client.GetCareerStats()`, `Client.GetPlayerName()`

```lua
function Client.Start()
    print("=== Galactic Conquest Client Start ===")

    -- 初始化 NanoVG 渲染上下文（整个生命周期只创建一次）

function Client.Stop()
    GameUI.Shutdown()
    if vg_ then nvgDelete(vg_); vg_ = nil end
    print("=== Galactic Conquest Client Stop ===")
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/Client.lua  -- 银河征服 客户端
-- ============================================================================

local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")

local GameUI      = require("game.GameUI")
local PlanetPanel = require("game.ui.PlanetPanel")  -- P3-2: 微动画触发
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local UICommon    = require("game.ui.UICommon")
local ClientMenus = require("network.ClientMenus")
local Campaign    = require("game.CampaignSystem")  -- P2-2: 战役模式
local NemesisSystem = require("game.NemesisSystem")  -- P1-2: 宿敌系统
local BlackMarket   = require("game.BlackMarketSystem") -- P2-2: 黑市走私网络
local Commander     = require("game.CommanderSystem")    -- P1-3 V2.4: 指挥官系统
local QuestBoard    = require("game.QuestBoard")         -- P2-1 V2.4: 程序化任务板
local GalaxyEvents  = require("game.GalaxyEvents")       -- P1-2 V2.4: 终局危机
local MegastructureSystem = require("game.MegastructureSystem") -- P2-2 V2.4: 巨构工程
local LiverySystem = require("game.LiverySystem")               -- P2-3 V2.4: 舰队涂装
local GalactopediaSystem = require("game.GalactopediaSystem")   -- P3-1 V2.4: 银河百科
local LegacySystem = require("game.LegacySystem")               -- P1-3 V2.5: 文明遗产
local ClientSave  = require("network.ClientSave")   -- 存档/读档逻辑
local ClientStats = require("network.ClientStats")  -- 统计面板渲染
local ClientBattle = require("network.ClientBattle") -- P3-1b: 战斗/波次/结算/远征/探索/DDA
local ClientGalaxy = require("network.ClientGalaxy") -- P3-1c: 建造/殖民/市场/外交
local BattleScene  = require("game.BattleScene")     -- 战术场景渲染/更新/点击
local ClientSetup  = require("network.ClientSetup")  -- P3-1d: setupSceneAndUI 逻辑
local ClientInput  = require("network.ClientInput")  -- P3-1d: 输入处理逻辑
-- P2-1: AnomalySystem 使用 inline require 以避免 upvalue 上限

-- 从拆分后的子模块导入
local Clientevolutiontree = require("network.Client_evolution_tree")
local Clientscalars = require("network.Client_scalars")
local Clientgeneral = require("network.Client_general")
local Clientcore = require("network.Client_core")

-- （剩余核心逻辑位于以下子文件：）
--   * Client_evolution_tree.lua  (53 行)  -- 数据表模块（EVOLUTION_TREE 定义）
--   * Client_scalars.lua  (30 行)  -- 数据表模块（scalars 定义）
--   * Client_general.lua  (1903 行)  -- general 相关函数（42 个函数，约 389 行代码）
--   * Client_core.lua  (217 行)  -- Client 相关函数（4 个函数，约 34 行代码）

return Client
```

---

## 2. GalaxyScene.lua

- **原文件路径**: `game/GalaxyScene.lua`
- **原文件大小**: 2,251 行
- **拆分策略**: 检测到原文件 2251 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 3355 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `GalaxyScene_config.lua` | 配置常量（从原文件拆分独立模块） | 150 | L17-L166 |
| 2 | `GalaxyScene_galaxy_scene.lua` | GalaxyScene 相关函数（44 个函数，约 247 行代码） | 1612 | L632-L2243 |
| 3 | `GalaxyScene_general.lua` | general 相关函数（25 个函数，约 230 行代码） | 1543 | L168-L1710 |

### 子模块内容预览

#### `GalaxyScene_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L17-L166` (150 行)
- **区块类型**: `config`

```lua
local pirateAI_ = nil
-- P1-3: 联赛修正器（由 Init 注入，nil 表示非联赛模式）
local leagueMod_ = nil
local PIRATE_FLEET_SPEED = 55  -- 与 PirateAI.lua 保持一致，用于 ETA 计算

-- ============================================================================
-- 数据常量
-- =============================================================
...
```

#### `GalaxyScene_galaxy_scene.lua` — GalaxyScene 相关函数（44 个函数，约 247 行代码）

- **对应原文件行**: `L632-L2243` (1612 行)
- **区块类型**: `module`
- **包含函数**: `GalaxyScene.Colonize(planet)`, `GalaxyScene.Init(opts)`, `GalaxyScene.GetAllPlanets()`, `GalaxyScene.GetColonizedPlanets()`, `GalaxyScene.GetSelected()`, `GalaxyScene.SelectPlanet(planet)`, `GalaxyScene.GetMapVariant()`, `GalaxyScene.GetSeed()`（共 44 个，其余省略）

```lua
function GalaxyScene.Colonize(planet)
    if not planet or planet.colonized then return end
    planet.colonized     = true
    planet.owner         = "player"

function GalaxyScene.Init(opts)
    vg_           = opts.vg
    bs_           = opts.bs
    rm_           = opts.rm
```

#### `GalaxyScene_general.lua` — general 相关函数（25 个函数，约 230 行代码）

- **对应原文件行**: `L168-L1710` (1543 行)
- **区块类型**: `module`
- **包含函数**: `dist2(x1,y1,x2,y2)`, `randItem(t)`, `nvgColor(c,`, `w2s(wx,`, `s2w(sx,`, `generateBgStars()`, `generateFixedStarSystems(fixedDefs)`, `generateStarSystems()`（共 25 个，其余省略）

```lua
local function dist2(x1,y1,x2,y2)
    local dx,dy = x2-x1, y2-y1
    return math.sqrt(dx*dx+dy*dy)
end

local function randItem(t)
    return t[math.random(1,#t)]
end
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: param-type-mismatch, assign-type-mismatch
-- ============================================================================
-- game/GalaxyScene.lua  -- 银河地图场景（渲染 + 逻辑）
-- ============================================================================

require "game.Systems"   -- 加载全局常量 SHIP_TYPES, SHIP_COSTS 等
local UICommon       = require("game.ui.UICommon")
local GalaxyEvents   = require("game.GalaxyEvents")
local AnomalySystem  = require("game.AnomalySystem")  -- P2-1: 星域异象
local StarWeather    = require("game.StarWeather")    -- P3-2: 动态星图天气
local GalaxyGenerator = require("game.GalaxyGenerator") -- P1-1: 程序化星系生成器
local GS             = require("game.galaxy.GalaxyState")
local GalaxyRender   = require("game.galaxy.GalaxyRender")

-- 从拆分后的子模块导入
local Galaxysceneconfig = require("game.GalaxyScene_config")
local Galaxyscenegalaxyscene = require("game.GalaxyScene_galaxy_scene")
local Galaxyscenegeneral = require("game.GalaxyScene_general")

-- （剩余核心逻辑位于以下子文件：）
--   * GalaxyScene_config.lua  (150 行)  -- 配置常量（从原文件拆分独立模块）
--   * GalaxyScene_galaxy_scene.lua  (1612 行)  -- GalaxyScene 相关函数（44 个函数，约 247 行代码）
--   * GalaxyScene_general.lua  (1543 行)  -- general 相关函数（25 个函数，约 230 行代码）

return GalaxyScene
```

---

## 3. FleetPanel.lua

- **原文件路径**: `game/ui/FleetPanel.lua`
- **原文件大小**: 1,690 行
- **拆分策略**: 检测到原文件 1690 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 1837 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `FleetPanel_config.lua` | 配置常量（从原文件拆分独立模块） | 50 | L7-L56 |
| 2 | `FleetPanel_fleet_panel.lua` | FleetPanel 相关函数（6 个函数，约 136 行代码） | 1489 | L101-L1589 |
| 3 | `FleetPanel_general.lua` | general 相关函数（5 个函数，约 18 行代码） | 248 | L69-L316 |

### 子模块内容预览

#### `FleetPanel_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L7-L56` (50 行)
- **区块类型**: `config`

```lua
local SHIP_MODULES       = Systems.SHIP_MODULES
local SHIP_MODULES_BY_CAT = Systems.SHIP_MODULES_BY_CAT
local MODULE_CAT         = Systems.MODULE_CAT

local FleetPanel = {}

-- 舰船类型颜色映射（用于折叠态圆点摘要）
local FLEET_SHIP_COLORS = {
    SCOUT         = {100,200,255},
    FRIGATE       = {80,160,255},
    DE
...
```

#### `FleetPanel_fleet_panel.lua` — FleetPanel 相关函数（6 个函数，约 136 行代码）

- **对应原文件行**: `L101-L1589` (1489 行)
- **区块类型**: `module`
- **包含函数**: `FleetPanel.OnTextInput(text)`, `FleetPanel.OnBackspace()`, `FleetPanel.OnEnter()`, `FleetPanel.IsNaming()`, `FleetPanel.Render(ctx)`, `FleetPanel.RenderNamingModal()`

```lua
function FleetPanel.OnTextInput(text)
    if not namingActive_ then return end
    -- UTF-8 字符计数
    local charCount = utf8.len(namingText_) or 0

function FleetPanel.OnBackspace()
    if not namingActive_ then return end
    if #namingText_ > 0 then
        -- 移除最后一个 UTF-8 字符
```

#### `FleetPanel_general.lua` — general 相关函数（5 个函数，约 18 行代码）

- **对应原文件行**: `L69-L316` (248 行)
- **区块类型**: `module`
- **包含函数**: `randomFleetName()`, `openNaming(fleetId)`, `closeNaming()`, `confirmNaming()`, `addRow(icon,`

```lua
local function randomFleetName()
    return FLEET_NAME_POOL[math.random(1, #FLEET_NAME_POOL)]
end

local function openNaming(fleetId)
    local fm = UICommon.fm
    if not fm or not fm.fleets[fleetId] then return end
    namingActive_  = true
```

### 重构后主文件预览（骨架）

```lua
--- 编队管理面板模块
--- 负责渲染编队 tab、舰船列表、储备池、移动模式

local UICommon   = require("game.ui.UICommon")
local Systems    = require("game.Systems")
local Commander  = require("game.CommanderSystem")  -- P1-3 V2.4

-- 从拆分后的子模块导入
local Fleetpanelconfig = require("ui.FleetPanel_config")
local Fleetpanelfleetpanel = require("ui.FleetPanel_fleet_panel")
local Fleetpanelgeneral = require("ui.FleetPanel_general")

-- （剩余核心逻辑位于以下子文件：）
--   * FleetPanel_config.lua  (50 行)  -- 配置常量（从原文件拆分独立模块）
--   * FleetPanel_fleet_panel.lua  (1489 行)  -- FleetPanel 相关函数（6 个函数，约 136 行代码）
--   * FleetPanel_general.lua  (248 行)  -- general 相关函数（5 个函数，约 18 行代码）

return FleetPanel
```

---

## 4. BattleScene.lua

- **原文件路径**: `game/BattleScene.lua`
- **原文件大小**: 1,626 行
- **拆分策略**: 检测到原文件 1626 行，超过阈值 600 行。 建议拆分为 7 个文件（1 个主文件 + 6 个子模块），总计 2717 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `BattleScene_config.lua` | 配置常量（从原文件拆分独立模块） | 391 | L11-L401 |
| 2 | `BattleScene_battle_environments.lua` | 数据表模块（BATTLE_ENVIRONMENTS 定义） | 53 | L206-L258 |
| 3 | `BattleScene_formation_config.lua` | 数据表模块（FORMATION_CONFIG 定义） | 85 | L301-L385 |
| 4 | `BattleScene_ship.lua` | 数据表模块（ship 定义） | 44 | L460-L503 |
| 5 | `BattleScene_battle_scene.lua` | BattleScene 相关函数（7 个函数，约 216 行代码） | 893 | L589-L1481 |
| 6 | `BattleScene_general.lua` | general 相关函数（11 个函数，约 209 行代码） | 1201 | L402-L1602 |

### 子模块内容预览

#### `BattleScene_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L11-L401` (391 行)
- **区块类型**: `config`

```lua
local SHIP_MODULES = Systems.SHIP_MODULES                -- P1-1: 模块定义查找
local NemesisSystem = require("game.NemesisSystem")      -- P1-2: 宿敌系统
local AnomalySystem = require("game.AnomalySystem")      -- P2-1: 星域异象系统
local BattleReplaySystem = require("game.BattleReplaySystem") -- P3-1: 战斗回放系统
local
...
```

#### `BattleScene_battle_environments.lua` — 数据表模块（BATTLE_ENVIRONMENTS 定义）

- **对应原文件行**: `L206-L258` (53 行)
- **区块类型**: `data`

```lua
local BATTLE_ENVIRONMENTS = {
    NONE = {
        key   = "NONE",
        label = "无",
        icon  = "",
        desc  = "",
        bgR = 0, bgG = 5, bgB = 16,       -- 背景色调（正常深蓝）
        -- 数值修正（均为乘数，1.0 = 无影响）
        enemyRangeMult   = 1.0,
        shieldAbsorb     = 1.0,
        asteroidDama
...
```

#### `BattleScene_formation_config.lua` — 数据表模块（FORMATION_CONFIG 定义）

- **对应原文件行**: `L301-L385` (85 行)
- **区块类型**: `data`

```lua
local FORMATION_CONFIG = {
    wedge = {
        label = "锋矢阵",
        icon  = "🔺",
        desc  = "前排攻+20% 后排受击-30%",
        color = {255, 110, 80},
        -- 舰船布置：V型前突
        posX       = 140,
        posXSpread = 40,
        posYBase   = 0,
        posYSpread = 50,
        speedMult  = 1.00,
...
```

#### `BattleScene_ship.lua` — 数据表模块（ship 定义）

- **对应原文件行**: `L460-L503` (44 行)
- **区块类型**: `data`

```lua
local ship = {
        x        = x,      y=y,
        vx       = 0,      vy=0,
        team     = team,
        stype    = stype,
        speed    = cfg.speed,
        health   = hp,
        maxHealth= hp,
        range    = cfg.range,
        dmg      = cfg.dmg * dm,
        color    = cfg.col
...
```

#### `BattleScene_battle_scene.lua` — BattleScene 相关函数（7 个函数，约 216 行代码）

- **对应原文件行**: `L589-L1481` (893 行)
- **区块类型**: `module`
- **包含函数**: `BattleScene.Init(opts)`, `BattleScene.Reset()`, `BattleScene.AddProductionShip(shipType)`, `BattleScene.StartNextWave()`, `BattleScene.Update(dt)`, `BattleScene.Render()`, `BattleScene.GetState()`

```lua
function BattleScene.Init(opts)
    vg_          = opts.vg
    notifyFn_    = opts.notifyFn
    onBattleEnd_ = opts.onBattleEnd

function BattleScene.Reset()
    screenW_, screenH_ = UICommon.getVirtualSize()

    -- 基础玩家舰队
```

#### `BattleScene_general.lua` — general 相关函数（11 个函数，约 209 行代码）

- **对应原文件行**: `L402-L1602` (1201 行)
- **区块类型**: `module`
- **包含函数**: `getComboLevel()`, `logBattleEvent(text)`, `makeShip(stype,`, `syncAIVars()`, `syncAIVarsBack()`, `syncAIRefs()`, `selectEnv()`, `pushToCtx()`（共 11 个，其余省略）

```lua
local function getComboLevel()
    for _, lv in ipairs(COMBO_LEVELS) do
        if comboCount_ >= lv.min then return lv end
    end

local function logBattleEvent(text)
    battleLog_[#battleLog_ + 1] = { wave = waveNum_, text = text }
    if #battleLog_ > BATTLE_LOG_MAX then
        table.remove(ba
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: local-limit, assign-type-mismatch
-- ============================================================================
-- game/BattleScene.lua  -- 战术战斗场景
-- ============================================================================

local Audio        = require("game.AudioManager")
local UICommon     = require("game.ui.UICommon")
local BattleSkills = require("game.BattleSkills")
local Achievement  = require("game.AchievementSystem")   -- P2-3: 成就奖励应用
local Systems      = require("game.Systems")

-- 从拆分后的子模块导入
local Battlesceneconfig = require("game.BattleScene_config")
local Battlescenebattleenvironments = require("game.BattleScene_battle_environments")
local Battlesceneformationconfig = require("game.BattleScene_formation_config")
local Battlesceneship = require("game.BattleScene_ship")
local Battlescenebattlescene = require("game.BattleScene_battle_scene")
local Battlescenegeneral = require("game.BattleScene_general")

-- （剩余核心逻辑位于以下子文件：）
--   * BattleScene_config.lua  (391 行)  -- 配置常量（从原文件拆分独立模块）
--   * BattleScene_battle_environments.lua  (53 行)  -- 数据表模块（BATTLE_ENVIRONMENTS 定义）
--   * BattleScene_formation_config.lua  (85 行)  -- 数据表模块（FORMATION_CONFIG 定义）
--   * BattleScene_ship.lua  (44 行)  -- 数据表模块（ship 定义）
--   * BattleScene_battle_scene.lua  (893 行)  -- BattleScene 相关函数（7 个函数，约 216 行代码）
--   * BattleScene_general.lua  (1201 行)  -- general 相关函数（11 个函数，约 209 行代码）

return BattleScene
```

---

## 5. GalaxyEvents.lua

- **原文件路径**: `game/GalaxyEvents.lua`
- **原文件大小**: 1,504 行
- **拆分策略**: 检测到原文件 1504 行，超过阈值 600 行。 建议拆分为 5 个文件（1 个主文件 + 4 个子模块），总计 1651 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `GalaxyEvents_event_types.lua` | 数据表模块（EVENT_TYPES 定义） | 433 | L25-L457 |
| 2 | `GalaxyEvents_disaster_types.lua` | 数据表模块（DISASTER_TYPES 定义） | 72 | L942-L1013 |
| 3 | `GalaxyEvents_endgame_crisis_types.lua` | 数据表模块（ENDGAME_CRISIS_TYPES 定义） | 171 | L1115-L1285 |
| 4 | `GalaxyEvents_galaxy_events.lua` | GalaxyEvents 相关函数（29 个函数，约 139 行代码） | 925 | L578-L1502 |

### 子模块内容预览

#### `GalaxyEvents_event_types.lua` — 数据表模块（EVENT_TYPES 定义）

- **对应原文件行**: `L25-L457` (433 行)
- **区块类型**: `data`

```lua
local EVENT_TYPES = {
    -- ── 原有3种（P1-3: 已添加链式触发字段）──────────────────────────────────
    MINE = {
        id      = "MINE",
        label   = "废弃矿场",
        icon    = "⛏",
        color   = {180, 140, 80},
        desc    = "探测到废弃星际矿场，内含大量原矿残留。",
        choices = {
            -- choiceIdx=1 触发
...
```

#### `GalaxyEvents_disaster_types.lua` — 数据表模块（DISASTER_TYPES 定义）

- **对应原文件行**: `L942-L1013` (72 行)
- **区块类型**: `data`

```lua
local DISASTER_TYPES = {
    QUAKE = {
        id      = "QUAKE",
        label   = "星震预警",
        icon    = "🌋",
        color   = {255, 120, 40},
        desc    = "殖民地探测到强烈地质活动！星球地壳剧烈震动，矿场和能源设施受损，产量下降直到完成加固。",
        isDisaster = true,
        penaltyRes = "minerals",   -- 减少的资源类型（仅描述，不强制修改产量）
...
```

#### `GalaxyEvents_endgame_crisis_types.lua` — 数据表模块（ENDGAME_CRISIS_TYPES 定义）

- **对应原文件行**: `L1115-L1285` (171 行)
- **区块类型**: `data`

```lua
local ENDGAME_CRISIS_TYPES = {
    VOID_SWARM = {
        id    = "VOID_SWARM",
        name  = "虚空虫群",
        icon  = "🕷",
        color = {180, 40, 255},
        desc  = "银河边缘的虚空裂隙中涌出了不计其数的虫群！它们正向殖民地核心区域蔓延。",
        phases = {
            {
                name  = "先驱侦察",
                desc  =
...
```

#### `GalaxyEvents_galaxy_events.lua` — GalaxyEvents 相关函数（29 个函数，约 139 行代码）

- **对应原文件行**: `L578-L1502` (925 行)
- **区块类型**: `module`
- **包含函数**: `GalaxyEvents.ScheduleChain(typeKey,`, `GalaxyEvents.Reset()`, `GalaxyEvents.Update(dt,`, `GalaxyEvents.onCrisisExpired(ev)`, `GalaxyEvents.AddBuff(buffKey,`, `GalaxyEvents.RemoveBuff(buffKey)`, `GalaxyEvents.HasBuff(buffKey)`, `GalaxyEvents.GetActiveBuffs()`（共 29 个，其余省略）

```lua
function GalaxyEvents.ScheduleChain(typeKey, wx, wy)
    local delay = CHAIN_DELAY_MIN + math.random() * (CHAIN_DELAY_MAX - CHAIN_DELAY_MIN)
    chainQueue_[#chainQueue_ + 1] = {
        typeKey = typeKey,

function GalaxyEvents.Reset()
    events_       = {}
    spawnTimer_   = 0
    chainQueue_   
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: param-type-mismatch
-- ============================================================================
-- game/GalaxyEvents.lua  -- 银河星图随机事件系统
-- 负责: 事件类型数据、事件节点生命周期管理（生成/更新/渲染）
-- 不负责: 玩家点击事件节点后的奖励逻辑（由 GalaxyScene.handleClick 处理）
-- ============================================================================

-- 从拆分后的子模块导入
local Galaxyeventseventtypes = require("game.GalaxyEvents_event_types")
local Galaxyeventsdisastertypes = require("game.GalaxyEvents_disaster_types")
local Galaxyeventsendgamecrisistypes = require("game.GalaxyEvents_endgame_crisis_types")
local Galaxyeventsgalaxyevents = require("game.GalaxyEvents_galaxy_events")

-- （剩余核心逻辑位于以下子文件：）
--   * GalaxyEvents_event_types.lua  (433 行)  -- 数据表模块（EVENT_TYPES 定义）
--   * GalaxyEvents_disaster_types.lua  (72 行)  -- 数据表模块（DISASTER_TYPES 定义）
--   * GalaxyEvents_endgame_crisis_types.lua  (171 行)  -- 数据表模块（ENDGAME_CRISIS_TYPES 定义）
--   * GalaxyEvents_galaxy_events.lua  (925 行)  -- GalaxyEvents 相关函数（29 个函数，约 139 行代码）

return GalaxyEvents
```

---

## 6. GameUI.lua

- **原文件路径**: `game/GameUI.lua`
- **原文件大小**: 1,503 行
- **拆分策略**: 检测到原文件 1503 行，超过阈值 600 行。 建议拆分为 5 个文件（1 个主文件 + 4 个子模块），总计 1738 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `GameUI_config.lua` | 配置常量（从原文件拆分独立模块） | 288 | L7-L294 |
| 2 | `GameUI_c.lua` | 数据表模块（C 定义） | 36 | L47-L82 |
| 3 | `GameUI_game_ui.lua` | GameUI 相关函数（43 个函数，约 318 行代码） | 1206 | L298-L1503 |
| 4 | `GameUI_general.lua` | general 相关函数（6 个函数，约 42 行代码） | 158 | L445-L602 |

### 子模块内容预览

#### `GameUI_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L7-L294` (288 行)
- **区块类型**: `config`

```lua
local Audio         = require("game.AudioManager")
local UICommon      = require("game.ui.UICommon")
local NotifyPanel   = require("game.ui.NotifyPanel")
local FleetPanel    = require("game.ui.FleetPanel")
local TechPanel     = require("game.ui.TechPanel")
local PlanetPanel   = require("game.ui.Plan
...
```

#### `GameUI_c.lua` — 数据表模块（C 定义）

- **对应原文件行**: `L47-L82` (36 行)
- **区块类型**: `data`

```lua
local C = {
    -- 面板背景
    panelBg       = {8,  12, 28,  220},
    panelBgDark   = {5,  15, 30,  248},
    panelBorder   = {60, 140, 255, 180},
    panelBorderDim= {60, 120, 220, 80},

    -- 文字
    textPrimary   = {200, 220, 255, 255},
    textSecondary = {120, 160, 200, 140},
    textTitle     =
...
```

#### `GameUI_game_ui.lua` — GameUI 相关函数（43 个函数，约 318 行代码）

- **对应原文件行**: `L298-L1503` (1206 行)
- **区块类型**: `module`
- **包含函数**: `GameUI.Notify(msg,`, `GameUI.RenderNotifications()`, `GameUI.SetPirateWarning(minTime)`, `GameUI.UpdateNotifications(dt)`, `GameUI.TriggerTechComplete(techId)`, `GameUI.OnScroll(mx,`, `GameUI.OnTouchBegin(id,`, `GameUI.OnTouchMove(id,`（共 43 个，其余省略）

```lua
function GameUI.Notify(msg, ntype)
    Audio.PlayNotify(ntype)
    NotifyPanel.Push(msg, ntype)
end

function GameUI.RenderNotifications()
    NotifyPanel.RenderToasts()
end
```

#### `GameUI_general.lua` — general 相关函数（6 个函数，约 42 行代码）

- **对应原文件行**: `L445-L602` (158 行)
- **区块类型**: `module`
- **包含函数**: `clr(r,g,b,a)`, `text(x,`, `addHit(x,`, `addScroll(x,`, `drawButton(x,`, `progressBar(x,`

```lua
local function clr(r,g,b,a) return nvgRGBA(r,g,b,a or 255) end
-- 从颜色常量表生成 nvgColor，例: clrC(C.panelBg)
local function clrC(c) return nvgRGBA(c[1], c[2], c[3], c[4] or 255) end

local function text(x, y, str, size, r,g,b,a, align)
    nvgFontFace(vg_, "sans")
    nvgFontSize(vg_, size)
    nvgTextAli
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: missing-parameter
-- ============================================================================
-- game/GameUI.lua  -- 完整 HUD：纯 NanoVG 绘制，无 UI 库依赖
-- ============================================================================

-- 从拆分后的子模块导入
local Gameuiconfig = require("game.GameUI_config")
local Gameuic = require("game.GameUI_c")
local Gameuigameui = require("game.GameUI_game_ui")
local Gameuigeneral = require("game.GameUI_general")

-- （剩余核心逻辑位于以下子文件：）
--   * GameUI_config.lua  (288 行)  -- 配置常量（从原文件拆分独立模块）
--   * GameUI_c.lua  (36 行)  -- 数据表模块（C 定义）
--   * GameUI_game_ui.lua  (1206 行)  -- GameUI 相关函数（43 个函数，约 318 行代码）
--   * GameUI_general.lua  (158 行)  -- general 相关函数（6 个函数，约 42 行代码）

return GameUI
```

---

## 7. EndGamePanel.lua

- **原文件路径**: `game/ui/EndGamePanel.lua`
- **原文件大小**: 1,486 行
- **拆分策略**: 检测到原文件 1486 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 1035 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `EndGamePanel_config.lua` | 配置常量（从原文件拆分独立模块） | 41 | L11-L51 |
| 2 | `EndGamePanel_general.lua` | general 相关函数（11 个函数，约 135 行代码） | 832 | L52-L883 |
| 3 | `EndGamePanel_end_game_panel.lua` | EndGamePanel 相关函数（12 个函数，约 33 行代码） | 112 | L1373-L1484 |

### 子模块内容预览

#### `EndGamePanel_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L11-L51` (41 行)
- **区块类型**: `config`

```lua
local active_        = false
local gameType_      = nil     -- "win" | "lose"
local stats_         = {}      -- { playTime, colonized, piratesKilled, rank, level, stars, ... }
local onRetry_       = nil     -- 点击"再来一局"回调
local animT_         = 0       -- 进场动画计时器
local adCb_          = nil     -- 广告回
...
```

#### `EndGamePanel_general.lua` — general 相关函数（11 个函数，约 135 行代码）

- **对应原文件行**: `L52-L883` (832 行)
- **区块类型**: `module`
- **包含函数**: `generateBattleReport()`, `renderLeaderboard()`, `renderProfilePopup()`, `divider(dy)`, `statRow(label,`, `renderRadarChart(vg,`, `renderEndGame()`, `easeOutElastic(x)`（共 11 个，其余省略）

```lua
local function generateBattleReport()
    local shipNames = {
        SCOUT="侦察舰", FRIGATE="护卫舰", DESTROYER="驱逐舰",
        BATTLECRUISER="战列舰", CARRIER="航母", INTERCEPTOR="拦截机",

local function renderLeaderboard()
    if not lbVisible_ then return end

    local vg      = UICommon.vg
```

#### `EndGamePanel_end_game_panel.lua` — EndGamePanel 相关函数（12 个函数，约 33 行代码）

- **对应原文件行**: `L1373-L1484` (112 行)
- **区块类型**: `module`
- **包含函数**: `EndGamePanel.Update(dt)`, `EndGamePanel.Render()`, `EndGamePanel.RenderLeaderboard()`, `EndGamePanel.Show(gameType,`, `EndGamePanel.Hide()`, `EndGamePanel.IsActive()`, `EndGamePanel.SetAdCallback(fn)`, `EndGamePanel.SetLeaderboardCallback(fn)`（共 12 个，其余省略）

```lua
function EndGamePanel.Update(dt)
    if active_ and animT_ < 3.0 then
        animT_ = animT_ + dt * 1.5   -- P1-3: 延长到3.0，支持逐行错开动画
    end

function EndGamePanel.Render()
    renderEndGame()
end
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/ui/EndGamePanel.lua  -- 游戏结算面板 + 排行榜子面板
-- ============================================================================
local UICommon = require "game.ui.UICommon"
local LiverySystem = require "game.LiverySystem"  -- P2-3: 排行榜徽章图标
local BlueprintSystem = require "game.BlueprintSystem"  -- P2-3: 蓝图收藏

-- 从拆分后的子模块导入
local Endgamepanelconfig = require("ui.EndGamePanel_config")
local Endgamepanelgeneral = require("ui.EndGamePanel_general")
local Endgamepanelendgamepanel = require("ui.EndGamePanel_end_game_panel")

-- （剩余核心逻辑位于以下子文件：）
--   * EndGamePanel_config.lua  (41 行)  -- 配置常量（从原文件拆分独立模块）
--   * EndGamePanel_general.lua  (832 行)  -- general 相关函数（11 个函数，约 135 行代码）
--   * EndGamePanel_end_game_panel.lua  (112 行)  -- EndGamePanel 相关函数（12 个函数，约 33 行代码）

return EndGamePanel
```

---

## 8. BattleAI.lua

- **原文件路径**: `game/battle/BattleAI.lua`
- **原文件大小**: 1,485 行
- **拆分策略**: 检测到原文件 1485 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 1549 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `BattleAI_config.lua` | 配置常量（从原文件拆分独立模块） | 27 | L11-L37 |
| 2 | `BattleAI_battle_ai.lua` | BattleAI 相关函数（15 个函数，约 189 行代码） | 1354 | L73-L1426 |
| 3 | `BattleAI_general.lua` | general 相关函数（7 个函数，约 60 行代码） | 118 | L120-L237 |

### 子模块内容预览

#### `BattleAI_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L11-L37` (27 行)
- **区块类型**: `config`

```lua
local SHIP_TYPES = Systems.SHIP_TYPES
local NemesisSystem = require("game.NemesisSystem")
local BattleReplaySystem = require("game.BattleReplaySystem")
local Commander = require("game.CommanderSystem")
local FormationEditor = require("game.ui.FormationEditor")
local BattleUtils = require("game.battl
...
```

#### `BattleAI_battle_ai.lua` — BattleAI 相关函数（15 个函数，约 189 行代码）

- **对应原文件行**: `L73-L1426` (1354 行)
- **区块类型**: `module`
- **包含函数**: `BattleAI.Init(refs)`, `BattleAI.SyncRefs(refs)`, `BattleAI.SyncVarsIn(v)`, `BattleAI.GetVarsOut()`, `BattleAI.MakeBossShip(baseType,`, `BattleAI.MakeNemesisShip(captainId,`, `BattleAI.BuildNemesisWave(captainId)`, `BattleAI.BuildEnemyWave(wave)`（共 15 个，其余省略）

```lua
function BattleAI.Init(refs)
    makeShip_        = refs.makeShip
    playerFleet_     = refs.playerFleet
    enemyFleet_      = refs.enemyFleet

function BattleAI.SyncRefs(refs)
    if refs.playerFleet  then playerFleet_  = refs.playerFleet  end
    if refs.enemyFleet   then enemyFleet_   = refs.en
...
```

#### `BattleAI_general.lua` — general 相关函数（7 个函数，约 60 行代码）

- **对应原文件行**: `L120-L237` (118 行)
- **区块类型**: `module`
- **包含函数**: `dist2(x1,`, `clamp(v,`, `getComboLevel()`, `logBattleEvent(text)`, `spawnExplosion(ship)`, `spawnHitSparks(x,`, `spawnShockRing(x,`

```lua
local function dist2(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function findNearest(ship, fleet, skipStealth)
    local best, bd = nil, math.huge
```

### 重构后主文件预览（骨架）

```lua
--- BattleAI.lua
--- 战斗 AI 逻辑模块：工厂函数、波次生成、阵型应用、战斗循环（玩家/敌方/死亡/被动）
--- 从 BattleScene.lua 提取，通过 BattleState (BS) 共享状态。
--- BattleScene 调用前同步 BS，BattleAI 读写 BS 中的表引用（原地修改），
--- 标量变化通过返回值告知 BattleScene 回写。

local BS = require("game.battle.BattleState")
local Audio = require("game.AudioManager")
local BattleSkills = require("game.BattleSkills")
local Systems = require("game.Systems")

-- 从拆分后的子模块导入
local Battleaiconfig = require("battle.BattleAI_config")
local Battleaibattleai = require("battle.BattleAI_battle_ai")
local Battleaigeneral = require("battle.BattleAI_general")

-- （剩余核心逻辑位于以下子文件：）
--   * BattleAI_config.lua  (27 行)  -- 配置常量（从原文件拆分独立模块）
--   * BattleAI_battle_ai.lua  (1354 行)  -- BattleAI 相关函数（15 个函数，约 189 行代码）
--   * BattleAI_general.lua  (118 行)  -- general 相关函数（7 个函数，约 60 行代码）

return BattleAI
```

---

## 9. GalaxyPanels.lua

- **原文件路径**: `game/ui/GalaxyPanels.lua`
- **原文件大小**: 1,394 行
- **拆分策略**: 检测到原文件 1394 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 1287 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `GalaxyPanels_config.lua` | 配置常量（从原文件拆分独立模块） | 52 | L16-L67 |
| 2 | `GalaxyPanels_m.lua` | M 相关函数（9 个函数，约 442 行代码） | 1185 | L69-L1253 |

### 子模块内容预览

#### `GalaxyPanels_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L16-L67` (52 行)
- **区块类型**: `config`

```lua
local statsVisible_        = false
local questVisible_        = false
local signalOpen_          = false
local diploRelVisible_     = false
local marketCollapsed_     = false
local blackMarketCollapsed_= true
local exchangeCollapsed_   = true
local shipyardCollapsed_   = false

local signalCooldown_
...
```

#### `GalaxyPanels_m.lua` — M 相关函数（9 个函数，约 442 行代码）

- **对应原文件行**: `L69-L1253` (1185 行)
- **区块类型**: `module`
- **包含函数**: `M.Init(cfg)`, `M.Update(dt)`, `M.SetSelectedPlanet(p)`, `M.RenderSignal()`, `M.RenderMarket()`, `M.RenderDiploRel()`, `M.RenderBlackMarket()`, `M.RenderExchange(base,`（共 9 个，其余省略）

```lua
function M.Init(cfg)
    onMarketCb_            = cfg.onMarketCb
    onBlackMarketCb_       = cfg.onBlackMarketCb
    onExchangeCb_          = cfg.onExchangeCb

function M.Update(dt)
    if signalCooldown_ > 0 then
        signalCooldown_ = signalCooldown_ - dt
        if signalCooldown_ < 0 then si
...
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- GalaxyPanels.lua
-- 银河星图面板集合：情报/生涯统计/任务/信号/市场/外交/黑市/互换/造船厂
-- 从 GameUI.lua 提取的独立模块 (P3-1b-2)
-- ============================================================================
local UICommon     = require("game.ui.UICommon")
local QuestBoard   = require("game.QuestBoard")
local CareerPanel  = require("game.ui.CareerPanel")
local Commander    = require("game.CommanderSystem")

-- 从拆分后的子模块导入
local Galaxypanelsconfig = require("ui.GalaxyPanels_config")
local Galaxypanelsm = require("ui.GalaxyPanels_m")

-- （剩余核心逻辑位于以下子文件：）
--   * GalaxyPanels_config.lua  (52 行)  -- 配置常量（从原文件拆分独立模块）
--   * GalaxyPanels_m.lua  (1185 行)  -- M 相关函数（9 个函数，约 442 行代码）

return M
```

---

## 10. PlanetPanel.lua

- **原文件路径**: `game/ui/PlanetPanel.lua`
- **原文件大小**: 1,227 行
- **拆分策略**: 检测到原文件 1227 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 1060 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `PlanetPanel_planet_panel.lua` | PlanetPanel 相关函数（5 个函数，约 48 行代码） | 130 | L21-L150 |
| 2 | `PlanetPanel_general.lua` | general 相关函数（7 个函数，约 31 行代码） | 880 | L32-L911 |

### 子模块内容预览

#### `PlanetPanel_planet_panel.lua` — PlanetPanel 相关函数（5 个函数，约 48 行代码）

- **对应原文件行**: `L21-L150` (130 行)
- **区块类型**: `module`
- **包含函数**: `PlanetPanel.Update(dt)`, `PlanetPanel.TriggerHighlight(planetId,`, `PlanetPanel.TriggerGlow(planetId,`, `PlanetPanel.ResetScroll()`, `PlanetPanel.Render(planet,`

```lua
function PlanetPanel.Update(dt)
    lastDt_ = dt
    local toRemove = {}
    for k, anim in pairs(animStates_) do

function PlanetPanel.TriggerHighlight(planetId, bldKey)
    local key = tostring(planetId) .. "_hl_" .. tostring(bldKey)
    animStates_[key] = { type="highlight", timer=0.6, maxTime=0.
...
```

#### `PlanetPanel_general.lua` — general 相关函数（7 个函数，约 31 行代码）

- **对应原文件行**: `L32-L911` (880 行)
- **区块类型**: `module`
- **包含函数**: `triggerPress(key)`, `triggerShake(key)`, `getPressScale(key)`, `getShakeOffset(key)`, `getHighlightAlpha(planetId,`, `getGlowParams(planetId,`, `vy2sy(vy)`

```lua
local function triggerPress(key)
    animStates_[key] = { type="press", timer=0.18, maxTime=0.18 }
end

local function triggerShake(key)
    animStates_[key] = { type="shake", timer=0.30, maxTime=0.30 }
end
```

### 重构后主文件预览（骨架）

```lua
--- 行星面板模块
--- 负责渲染行星建造、已安装模块、殖民状态、建造队列

local UICommon = require("game.ui.UICommon")

-- 从拆分后的子模块导入
local Planetpanelplanetpanel = require("ui.PlanetPanel_planet_panel")
local Planetpanelgeneral = require("ui.PlanetPanel_general")

-- （剩余核心逻辑位于以下子文件：）
--   * PlanetPanel_planet_panel.lua  (130 行)  -- PlanetPanel 相关函数（5 个函数，约 48 行代码）
--   * PlanetPanel_general.lua  (880 行)  -- general 相关函数（7 个函数，约 31 行代码）

return PlanetPanel
```

---

## 11. ClientBattle.lua

- **原文件路径**: `network/ClientBattle.lua`
- **原文件大小**: 1,205 行
- **拆分策略**: 检测到原文件 1205 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 954 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `ClientBattle_explorer_task_templates.lua` | 数据表模块（EXPLORER_TASK_TEMPLATES 定义） | 62 | L25-L86 |
| 2 | `ClientBattle_m.lua` | M 相关函数（21 个函数，约 115 行代码） | 842 | L208-L1049 |

### 子模块内容预览

#### `ClientBattle_explorer_task_templates.lua` — 数据表模块（EXPLORER_TASK_TEMPLATES 定义）

- **对应原文件行**: `L25-L86` (62 行)
- **区块类型**: `data`

```lua
local EXPLORER_TASK_TEMPLATES = {
    { label="扫描异常信号",  minDur=30, maxDur=45,
      rewards={ {res="minerals",amt=300}, {res="esource",amt=200} },
      expGain=60,  icon="📡", eventType="scan" },
    { label="探测矿脉地层",  minDur=40, maxDur=60,
      rewards={ {res="minerals",amt=500}, {res="crystal",a
...
```

#### `ClientBattle_m.lua` — M 相关函数（21 个函数，约 115 行代码）

- **对应原文件行**: `L208-L1049` (842 行)
- **区块类型**: `module`
- **包含函数**: `M.Init(state)`, `M.DrawEndlessCards(count)`, `M.ApplyEndlessCard(cardKey)`, `M.DdaApply()`, `M.DdaEvaluateBattle(isWin,`, `M.DdaPeriodicCheck()`, `M.StartExplorerTask()`, `M.UpdateExplorerTasks(dt)`（共 21 个，其余省略）

```lua
function M.Init(state)
    S = state
end

function M.DrawEndlessCards(count)
    local pool  = {}
    for _, c in ipairs(M.ENDLESS_CARD_POOL) do pool[#pool+1] = c end
    -- Fisher-Yates 洗牌
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-- ============================================================================
-- network/ClientBattle.lua  -- 银河征服 战斗/波次/结算/远征/探索/DDA
-- 从 Client.lua 拆分而来（P3-1b）
-- ============================================================================

local Sys         = require("game.Systems")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local Campaign    = require("game.CampaignSystem")
local Commander   = require("game.CommanderSystem")
local GalaxyScene = require("game.GalaxyScene")
local GameUI      = require("game.GameUI")
local LegacySystem= require("game.LegacySystem")
local NemesisSystem = require("game.NemesisSystem")

-- 从拆分后的子模块导入
local Clientbattleexplorertasktemplates = require("network.ClientBattle_explorer_task_templates")
local Clientbattlem = require("network.ClientBattle_m")

-- （剩余核心逻辑位于以下子文件：）
--   * ClientBattle_explorer_task_templates.lua  (62 行)  -- 数据表模块（EXPLORER_TASK_TEMPLATES 定义）
--   * ClientBattle_m.lua  (842 行)  -- M 相关函数（21 个函数，约 115 行代码）

return M
```

---

## 12. ClientSetup.lua

- **原文件路径**: `network/ClientSetup.lua`
- **原文件大小**: 1,138 行
- **拆分策略**: 检测到原文件 1138 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 108 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `ClientSetup_battle_state_.lua` | 数据表模块（battleState_ 定义） | 58 | L102-L159 |

### 子模块内容预览

#### `ClientSetup_battle_state_.lua` — 数据表模块（battleState_ 定义）

- **对应原文件行**: `L102-L159` (58 行)
- **区块类型**: `data`

```lua
local battleState_ = setmetatable({
        rm = rm_, rs = rs_, spq = spq_, fm = fm_, player = player_, dda = dda_,
        hiddenStats = hiddenStats_, endlessCardBonuses = endlessCardBonuses_,
        pirateAttackInfo = H.pirateAttackInfo_,
        lastExpedition = lastExpedition_,
        expl
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: local-limit, assign-type-mismatch, param-type-mismatch
-----------------------------------------------------------------------
-- ClientSetup.lua  —  setupSceneAndUI 逻辑（从 Client.lua 提取）
-- 负责: 初始化DDA、创建battleState_/galaxyState_代理、
--       pirateAI_创建、GalaxyScene.Init、GameUI.Init (所有回调)、
--       Achievement.Init、广告回调注入、教程触发、BGM启动
-----------------------------------------------------------------------
local Sys         = require("game.Systems")
local GalaxyScene = require("game.GalaxyScene")
local PirateAI    = require("game.PirateAI")
local GameUI      = require("game.GameUI")
local PlanetPanel = require("game.ui.PlanetPanel")
local Audio       = require("game.AudioManager")
local Achievement = require("game.AchievementSystem")
local ClientBattle = require("network.ClientBattle")
local ClientGalaxy = require("network.ClientGalaxy")
local GalaxyEvents = require("game.GalaxyEvents")
local MegastructureSystem = require("game.MegastructureSystem")
local QuestBoard    = require("game.QuestBoard")
local GalactopediaSystem = require("game.GalactopediaSystem")
local LegacySystem = require("game.LegacySystem")
local cjson = require("cjson")

-- 从拆分后的子模块导入
local Clientsetupbattlestate = require("network.ClientSetup_battle_state_")

-- （剩余核心逻辑位于以下子文件：）
--   * ClientSetup_battle_state_.lua  (58 行)  -- 数据表模块（battleState_ 定义）

return M
```

---

## 13. ClientMenus.lua

- **原文件路径**: `network/ClientMenus.lua`
- **原文件大小**: 1,000 行
- **拆分策略**: 检测到原文件 1000 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 735 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `ClientMenus_client_menus.lua` | ClientMenus 相关函数（13 个函数，约 204 行代码） | 685 | L102-L786 |

### 子模块内容预览

#### `ClientMenus_client_menus.lua` — ClientMenus 相关函数（13 个函数，约 204 行代码）

- **对应原文件行**: `L102-L786` (685 行)
- **区块类型**: `module`
- **包含函数**: `ClientMenus.GetMainMenuBtnLayout(sw,`, `ClientMenus.GetMainMenuHit(mx,`, `ClientMenus.RenderMainMenu(vg,`, `ClientMenus.GetDifficultyBtnLayout(sw,`, `ClientMenus.GetCustomPanelVisible(ctx)`, `ClientMenus.GetCustomPanelLayout(sw,`, `ClientMenus.GetCustomSliderRects(sw,`, `ClientMenus.GetEndlessBtnLayout(sw,`（共 13 个，其余省略）

```lua
function ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    local btnW, btnH = 240, 56
    local cx = sw / 2 - btnW / 2
    local baseY = sh * 0.52

function ClientMenus.GetMainMenuHit(mx, my, sw, sh, hasSave)
    local btns = ClientMenus.GetMainMenuBtnLayout(sw, sh, hasSave)
    for _, btn in ip
...
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- network/ClientMenus.lua  -- 主菜单 & 难度选择屏幕：布局/命中/渲染
-- 负责：renderMainMenu, renderDifficultyScreen, 及所有辅助布局/命中函数
-- 不负责：状态变量声明、on*Select 回调（仍在 Client.lua）
-- ============================================================================

-- 从拆分后的子模块导入
local Clientmenusclientmenus = require("network.ClientMenus_client_menus")

-- （剩余核心逻辑位于以下子文件：）
--   * ClientMenus_client_menus.lua  (685 行)  -- ClientMenus 相关函数（13 个函数，约 204 行代码）

return ClientMenus
```

---

## 14. RenderOverlays.lua

- **原文件路径**: `game/battle/RenderOverlays.lua`
- **原文件大小**: 974 行
- **拆分策略**: 检测到原文件 974 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 709 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `RenderOverlays_general.lua` | general 相关函数（11 个函数，约 186 行代码） | 659 | L9-L667 |

### 子模块内容预览

#### `RenderOverlays_general.lua` — general 相关函数（11 个函数，约 186 行代码）

- **对应原文件行**: `L9-L667` (659 行)
- **区块类型**: `module`
- **包含函数**: `drawBossDestroyedEffect()`, `drawFireworks()`, `drawMilestoneBanner()`, `drawBossWarning()`, `drawPincerBanner()`, `drawNemesisOverlay()`, `drawAnomalyBanner()`, `drawAnomalyHUD()`（共 11 个，其余省略）

```lua
local function drawBossDestroyedEffect()
    if BS.bossFlashAlpha > 0 then
        nvgBeginPath(BS.vg)
        nvgRect(BS.vg, 0, 0, BS.screenW, BS.screenH)

local function drawFireworks()
    if #BS.fwParticles == 0 then return end
    for _, p in ipairs(BS.fwParticles) do
        local frac  = p.li
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- RenderOverlays: 覆盖层渲染 — Boss/横幅/特效/结算 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")

-- 从拆分后的子模块导入
local Renderoverlaysgeneral = require("battle.RenderOverlays_general")

-- （剩余核心逻辑位于以下子文件：）
--   * RenderOverlays_general.lua  (659 行)  -- general 相关函数（11 个函数，约 186 行代码）

return RenderOverlays
```

---

## 15. RenderStarmap.lua

- **原文件路径**: `game/galaxy/RenderStarmap.lua`
- **原文件大小**: 948 行
- **拆分策略**: 检测到原文件 948 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 949 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `RenderStarmap_m.lua` | M 相关函数（8 个函数，约 126 行代码） | 899 | L30-L928 |

### 子模块内容预览

#### `RenderStarmap_m.lua` — M 相关函数（8 个函数，约 126 行代码）

- **对应原文件行**: `L30-L928` (899 行)
- **区块类型**: `module`
- **包含函数**: `M.drawBackground()`, `M.drawStarSystem(sys)`, `M.drawDiploRelLines()`, `M.drawTradeRoutes()`, `M.drawExpeditionPaths()`, `M.drawDeepSpaceSystem(sys,`, `M.drawPirateThreatHeatmap()`, `M.drawColonyRipples()`

```lua
function M.drawBackground()
    local vg = GS.vg
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, GS.screenW, GS.screenH)

function M.drawStarSystem(sys)
    local vg   = GS.vg
    local zoom = GS.zoom
    local sx, sy = GS.w2s(sys.x, sys.y)
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/galaxy/RenderStarmap.lua  — 星系/行星/航线渲染
-- 含: drawBackground, drawOrbitRing, drawPlanetDetails, drawPlanet,
--     drawStarSystem, drawDiploRelLines, drawTradeRoutes, drawExpeditionPaths,
--     drawDeepSpaceSystem, drawPirateThreatHeatmap, drawColonyRipples
-- ============================================================================

local GS = require("game.galaxy.GalaxyState")

-- 从拆分后的子模块导入
local Renderstarmapm = require("galaxy.RenderStarmap_m")

-- （剩余核心逻辑位于以下子文件：）
--   * RenderStarmap_m.lua  (899 行)  -- M 相关函数（8 个函数，约 126 行代码）

return M
```

---

## 16. TechPanel.lua

- **原文件路径**: `game/ui/TechPanel.lua`
- **原文件大小**: 856 行
- **拆分策略**: 检测到原文件 856 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 162 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `TechPanel_general.lua` | general 相关函数（4 个函数，约 42 行代码） | 112 | L82-L193 |

### 子模块内容预览

#### `TechPanel_general.lua` — general 相关函数（4 个函数，约 42 行代码）

- **对应原文件行**: `L82-L193` (112 行)
- **区块类型**: `module`
- **包含函数**: `getDownstream(id)`, `getExclusivePeers(id)`, `computeRecommendedPath(rs)`, `drawConnection(vg,`

```lua
local function getDownstream(id)
    if DOWNSTREAM_CACHE[id] then return DOWNSTREAM_CACHE[id] end
    local result = {}
    for _, otherId in ipairs(TECH_ORDER) do

local function getExclusivePeers(id)
    local t = TECHS[id]
    if not t or not t.exclusiveGroup then return {} end
    local peers = 
...
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/ui/TechPanel.lua  -- 科技树可视化面板（节点图，按 Tier 分层展示）
-- P1-1 重构：节点间距扩大、贝塞尔连线、Tier 颜色分组、状态色规范
-- P3-2 可视化2.0：互斥组虚线框+二选一、有向箭头连线、Hover浮窗、推荐路线
-- ============================================================================
local UICommon  = require("game.ui.UICommon")

-- 从拆分后的子模块导入
local Techpanelgeneral = require("ui.TechPanel_general")

-- （剩余核心逻辑位于以下子文件：）
--   * TechPanel_general.lua  (112 行)  -- general 相关函数（4 个函数，约 42 行代码）

return TechPanel
```

---

## 17. AchievementSystem.lua

- **原文件路径**: `game/AchievementSystem.lua`
- **原文件大小**: 814 行
- **拆分策略**: 检测到原文件 814 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 830 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `AchievementSystem_achievements.lua` | 数据表模块（ACHIEVEMENTS 定义） | 502 | L11-L512 |
| 2 | `AchievementSystem_achievement_rewards.lua` | 数据表模块（ACHIEVEMENT_REWARDS 定义） | 75 | L517-L591 |
| 3 | `AchievementSystem_achievement_system.lua` | AchievementSystem 相关函数（15 个函数，约 91 行代码） | 203 | L607-L809 |

### 子模块内容预览

#### `AchievementSystem_achievements.lua` — 数据表模块（ACHIEVEMENTS 定义）

- **对应原文件行**: `L11-L512` (502 行)
- **区块类型**: `data`

```lua
local ACHIEVEMENTS = {
    -- ── 殖民类 ───────────────────────────────────────────────────────────────
    {
        id    = "first_colony",
        name  = "星际拓荒者",
        desc  = "首次殖民一颗星球",
        event = "colonize",
        check = function(s) return (s.totalColonized or 0) >= 1 end,
    },
...
```

#### `AchievementSystem_achievement_rewards.lua` — 数据表模块（ACHIEVEMENT_REWARDS 定义）

- **对应原文件行**: `L517-L591` (75 行)
- **区块类型**: `data`

```lua
local ACHIEVEMENT_REWARDS = {
    -- 殖民类
    first_colony      = { desc = "开局 +100 金属",               type = "resource",    value = { metal = 100 } },
    colony_5          = { desc = "开局 +200 金属",               type = "resource",    value = { metal = 200 } },
    colony_10         = { desc = "开局 +3
...
```

#### `AchievementSystem_achievement_system.lua` — AchievementSystem 相关函数（15 个函数，约 91 行代码）

- **对应原文件行**: `L607-L809` (203 行)
- **区块类型**: `module`
- **包含函数**: `AchievementSystem.Init(opts)`, `AchievementSystem.Check(eventName,`, `AchievementSystem.Update(dt)`, `AchievementSystem.GetUnlocked()`, `AchievementSystem.SetUnlocked(list)`, `AchievementSystem.GetTotal()`, `AchievementSystem.Redeem(id)`, `AchievementSystem.GetRedeemed()`（共 15 个，其余省略）

```lua
function AchievementSystem.Init(opts)
    notifyFn_   = opts.notifyFn  or function() end
    onUnlockFn_ = opts.onUnlock  or function() end
    audioFn_    = opts.onAudio   or nil

function AchievementSystem.Check(eventName, state)
    for _, ach in ipairs(ACHIEVEMENTS) do
        if ach.event == ev
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: assign-type-mismatch
-- ============================================================================
-- game/AchievementSystem.lua  -- 银河征服 成就系统
-- 轻量级成就模块：定义成就 → 触发检查 → Toast 通知
-- ============================================================================

-- 从拆分后的子模块导入
local Achievementsystemachievements = require("game.AchievementSystem_achievements")
local Achievementsystemachievementrewards = require("game.AchievementSystem_achievement_rewards")
local Achievementsystemachievementsystem = require("game.AchievementSystem_achievement_system")

-- （剩余核心逻辑位于以下子文件：）
--   * AchievementSystem_achievements.lua  (502 行)  -- 数据表模块（ACHIEVEMENTS 定义）
--   * AchievementSystem_achievement_rewards.lua  (75 行)  -- 数据表模块（ACHIEVEMENT_REWARDS 定义）
--   * AchievementSystem_achievement_system.lua  (203 行)  -- AchievementSystem 相关函数（15 个函数，约 91 行代码）

return AchievementSystem
```

---

## 18. PirateAI.lua

- **原文件路径**: `game/PirateAI.lua`
- **原文件大小**: 731 行
- **拆分策略**: 检测到原文件 731 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 726 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `PirateAI_config.lua` | 配置常量（从原文件拆分独立模块） | 18 | L12-L29 |
| 2 | `PirateAI_general.lua` | general 相关函数（13 个函数，约 125 行代码） | 658 | L63-L720 |

### 子模块内容预览

#### `PirateAI_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L12-L29` (18 行)
- **区块类型**: `config`

```lua
local PIRATE_BASE_COUNT        = 2       -- 海盗基地数量
local PIRATE_BASE_HP           = 100     -- 基地初始血量
local PIRATE_FLEET_SPEED       = 55      -- 海盗舰队移动速度（世界坐标/秒）
local PIRATE_ARRIVE_RADIUS     = 40      -- 到达玩家目标的判定半径（世界坐标）
local PIRATE_ATTACK_INTERVAL   = 210     -- 进攻间隔基准（秒）；实际 = 基准 × factor × ji
...
```

#### `PirateAI_general.lua` — general 相关函数（13 个函数，约 125 行代码）

- **对应原文件行**: `L63-L720` (658 行)
- **区块类型**: `module`
- **包含函数**: `PirateAI:generateBases(worldRange,`, `PirateAI:generateFixedBases(defs)`, `PirateAI:update(dt)`, `PirateAI:evaluateThreat()`, `PirateAI:launchAttack(base)`, `PirateAI:weakenBase(baseId)`, `PirateAI:strengthenBase(baseId)`, `PirateAI:RevealMostThreateningBase(duration)`（共 13 个，其余省略）

```lua
function PirateAI:generateBases(worldRange, opts)
    self.bases = {}
    -- P2-2: BIPOLAR 模式下海盗基地集中在中线（x≈0，上/下方）
    local baseAngles

function PirateAI:generateFixedBases(defs)
    self.bases = {}
    for i, def in ipairs(defs) do
        self.bases[i] = {
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/PirateAI.lua  -- 海盗势力 AI 系统
-- 负责：基地生成、舰队周期进攻、到达触发战斗、胜负后强度调整
-- ============================================================================

-- 从拆分后的子模块导入
local Pirateaiconfig = require("game.PirateAI_config")
local Pirateaigeneral = require("game.PirateAI_general")

-- （剩余核心逻辑位于以下子文件：）
--   * PirateAI_config.lua  (18 行)  -- 配置常量（从原文件拆分独立模块）
--   * PirateAI_general.lua  (658 行)  -- general 相关函数（13 个函数，约 125 行代码）

return PirateAI
```

---

## 19. RenderHUD.lua

- **原文件路径**: `game/galaxy/RenderHUD.lua`
- **原文件大小**: 712 行
- **拆分策略**: 检测到原文件 712 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 704 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `RenderHUD_m.lua` | M 相关函数（11 个函数，约 315 行代码） | 654 | L56-L709 |

### 子模块内容预览

#### `RenderHUD_m.lua` — M 相关函数（11 个函数，约 315 行代码）

- **对应原文件行**: `L56-L709` (654 行)
- **区块类型**: `module`
- **包含函数**: `M.drawTooltip(planet)`, `M.drawAsteroidTooltip(a)`, `M.drawPirateWarningHUD()`, `M.drawAnomalyIndicator()`, `M.drawWeatherHUD()`, `M.drawSeedLabel()`, `M.drawMinimap()`, `M.drawPirateThreatHeatmap()`（共 11 个，其余省略）

```lua
function M.drawTooltip(planet)
    if not planet then return end
    local px, py = planet._sx, planet._sy
    if not px then return end

function M.drawAsteroidTooltip(a)
    if not a then return end
    local sx, sy = GS.w2s(a.x, a.y)
    local cfg    = GS.ASTEROID_TYPES[a.atype]
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/galaxy/RenderHUD.lua  — 小地图 / Tooltip / 信号 / 指标 HUD 渲染
-- 从 GalaxyScene.lua 提取的纯渲染函数
-- ============================================================================

local GS = require("game.galaxy.GalaxyState")
local AnomalySystem = require("game.AnomalySystem")
local StarWeather   = require("game.StarWeather")

-- 从拆分后的子模块导入
local Renderhudm = require("galaxy.RenderHUD_m")

-- （剩余核心逻辑位于以下子文件：）
--   * RenderHUD_m.lua  (654 行)  -- M 相关函数（11 个函数，约 315 行代码）

return M
```

---

## 20. DiplomacySystem.lua

- **原文件路径**: `game/systems/DiplomacySystem.lua`
- **原文件大小**: 698 行
- **拆分策略**: 检测到原文件 698 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 670 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `DiplomacySystem_config.lua` | 配置常量（从原文件拆分独立模块） | 29 | L20-L48 |
| 2 | `DiplomacySystem_general.lua` | general 相关函数（24 个函数，约 141 行代码） | 591 | L71-L661 |

### 子模块内容预览

#### `DiplomacySystem_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L20-L48` (29 行)
- **区块类型**: `config`

```lua
local GIFT_FAVOR          = 20    -- 每次礼物 +20 好感
local WAR_THRESHOLD       = 0     -- 好感 < 0 → 宣战
local TRADE_THRESHOLD     = 60    -- 好感 ≥ 60 → 商贸协议
local MILITARY_THRESHOLD  = 90    -- 好感 ≥ 90 → 军事合作
-- P2-2: 长期贸易协议
local LONG_TRADE_THRESHOLD   = 60     -- 好感 ≥ 60 才可激活
local LONG_TRADE_BREAK_FAVOR
...
```

#### `DiplomacySystem_general.lua` — general 相关函数（24 个函数，约 141 行代码）

- **对应原文件行**: `L71-L661` (591 行)
- **区块类型**: `module`
- **包含函数**: `DiplomacySystem:initFactions(allPlanets,`, `DiplomacySystem:initTriangleRelations()`, `DiplomacySystem:getRelation(fk1,`, `DiplomacySystem:getAllRelations()`, `DiplomacySystem:getCompetitor(factionKey)`, `DiplomacySystem:applyTrianglePenalty(factionKey,`, `DiplomacySystem:activateIntel(factionKey)`, `DiplomacySystem:activateAlliance(factionKey)`（共 24 个，其余省略）

```lua
function DiplomacySystem:initFactions(allPlanets, ratio)
    ratio = ratio or 0.35
    local keys = { "trade_union", "star_guild", "relic_keeper" }
    for _, p in ipairs(allPlanets) do

function DiplomacySystem:initTriangleRelations()
    local keys = { "trade_union", "star_guild", "relic_keeper" }
...
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- DiplomacySystem: 中立势力外交系统
-- 拆分自 Systems.lua（纯机械迁移，无逻辑修改）
-- ============================================================================

--- 三种中立势力定义

-- 从拆分后的子模块导入
local Diplomacysystemconfig = require("systems.DiplomacySystem_config")
local Diplomacysystemgeneral = require("systems.DiplomacySystem_general")

-- （剩余核心逻辑位于以下子文件：）
--   * DiplomacySystem_config.lua  (29 行)  -- 配置常量（从原文件拆分独立模块）
--   * DiplomacySystem_general.lua  (591 行)  -- general 相关函数（24 个函数，约 141 行代码）

return DiplomacySystem
```

---

## 21. RenderHUD.lua

- **原文件路径**: `game/battle/RenderHUD.lua`
- **原文件大小**: 666 行
- **拆分策略**: 检测到原文件 666 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 682 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `RenderHUD_general.lua` | general 相关函数（9 个函数，约 174 行代码） | 632 | L12-L643 |

### 子模块内容预览

#### `RenderHUD_general.lua` — general 相关函数（9 个函数，约 174 行代码）

- **对应原文件行**: `L12-L643` (632 行)
- **区块类型**: `module`
- **包含函数**: `drawWaveHUD()`, `drawComboHUD()`, `drawShipInfoPanel()`, `statLine(label,`, `drawFocusRing()`, `drawFocusHUD()`, `drawFormationBar()`, `drawRetreatReinforce()`（共 9 个，其余省略）

```lua
local function drawWaveHUD()
    if BS.state ~= "fighting" then return end
    local cx = BS.screenW / 2
    local hw, hh = 140, 48

local function drawComboHUD()
    if BS.state ~= "fighting" then return end
    if BS.comboCount < 2 then return end
    local alpha = 255
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- RenderHUD: HUD层渲染 — 波次/连击/信息面板/阵型/技能 (从 BattleRender.lua 拆分)
-- ============================================================================
local BS = require("game.battle.BattleState")
local FormationEditor = require("game.ui.FormationEditor")

-- 从拆分后的子模块导入
local Renderhudgeneral = require("battle.RenderHUD_general")

-- （剩余核心逻辑位于以下子文件：）
--   * RenderHUD_general.lua  (632 行)  -- general 相关函数（9 个函数，约 174 行代码）

return RenderHUD
```

---

## 22. ReplayPlayer.lua

- **原文件路径**: `game/ui/ReplayPlayer.lua`
- **原文件大小**: 665 行
- **拆分策略**: 检测到原文件 665 行，超过阈值 600 行。 建议拆分为 4 个文件（1 个主文件 + 3 个子模块），总计 663 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `ReplayPlayer_config.lua` | 配置常量（从原文件拆分独立模块） | 31 | L11-L41 |
| 2 | `ReplayPlayer_general.lua` | general 相关函数（11 个函数，约 139 行代码） | 479 | L46-L524 |
| 3 | `ReplayPlayer_replay_player.lua` | ReplayPlayer 相关函数（6 个函数，约 20 行代码） | 103 | L561-L663 |

### 子模块内容预览

#### `ReplayPlayer_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L11-L41` (31 行)
- **区块类型**: `config`

```lua
local active_       = false
local animT_        = 0       -- 进场动画计时器 (0→1)

-- 回放播放状态
local playing_      = false   -- 是否正在播放
local speed_        = 1       -- 倍速 (1/2/4)
local currentTime_  = 0       -- 当前播放时间（秒）
local duration_     = 0       -- 总时长
local dragging_     = false   -- 是否正在拖拽时间轴

-- 缓存数
...
```

#### `ReplayPlayer_general.lua` — general 相关函数（11 个函数，约 139 行代码）

- **对应原文件行**: `L46-L524` (479 行)
- **区块类型**: `module`
- **包含函数**: `easeOutCubic(t)`, `easeOutBack(t)`, `lerp(a,`, `formatTime(seconds)`, `renderBattleMap(vg,`, `worldToMap(wx,`, `renderTimeline(vg,`, `renderEventPopups(vg,`（共 11 个，其余省略）

```lua
local function easeOutCubic(t)
    t = t - 1
    return t * t * t + 1
end

local function easeOutBack(t)
    local c = 1.7
    t = t - 1
    return t * t * ((c + 1) * t + c) + 1
```

#### `ReplayPlayer_replay_player.lua` — ReplayPlayer 相关函数（6 个函数，约 20 行代码）

- **对应原文件行**: `L561-L663` (103 行)
- **区块类型**: `module`
- **包含函数**: `ReplayPlayer.Update(dt)`, `ReplayPlayer.Render()`, `ReplayPlayer.Show()`, `ReplayPlayer.Hide()`, `ReplayPlayer.IsActive()`, `ReplayPlayer.SetOnClose(fn)`

```lua
function ReplayPlayer.Update(dt)
    if not active_ then return end

    -- 进场动画

function ReplayPlayer.Render()
    renderReplayPlayer()
end
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/ui/ReplayPlayer.lua  -- P3-2: 战斗回放播放器面板
-- 全屏回放：时间轴拖拽 / 播放暂停 / 倍速 / 精彩标记 / 迷你战场
-- ============================================================================
local UICommon = require "game.ui.UICommon"
local BattleReplaySystem = require "game.BattleReplaySystem"

-- 从拆分后的子模块导入
local Replayplayerconfig = require("ui.ReplayPlayer_config")
local Replayplayergeneral = require("ui.ReplayPlayer_general")
local Replayplayerreplayplayer = require("ui.ReplayPlayer_replay_player")

-- （剩余核心逻辑位于以下子文件：）
--   * ReplayPlayer_config.lua  (31 行)  -- 配置常量（从原文件拆分独立模块）
--   * ReplayPlayer_general.lua  (479 行)  -- general 相关函数（11 个函数，约 139 行代码）
--   * ReplayPlayer_replay_player.lua  (103 行)  -- ReplayPlayer 相关函数（6 个函数，约 20 行代码）

return ReplayPlayer
```

---

## 23. TutorialSystem.lua

- **原文件路径**: `game/ui/TutorialSystem.lua`
- **原文件大小**: 655 行
- **拆分策略**: 检测到原文件 655 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 651 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `TutorialSystem_phases.lua` | 数据表模块（PHASES 定义） | 122 | L26-L147 |
| 2 | `TutorialSystem_tutorial_system.lua` | TutorialSystem 相关函数（15 个函数，约 76 行代码） | 479 | L175-L653 |

### 子模块内容预览

#### `TutorialSystem_phases.lua` — 数据表模块（PHASES 定义）

- **对应原文件行**: `L26-L147` (122 行)
- **区块类型**: `data`

```lua
local PHASES = {
    -- ── 阶段 1: 初始介绍（进入银河地图即触发） ──
    intro = {
        {
            id       = "welcome",
            anchor   = "center",
            title    = "欢迎来到银河征服！",
            body     = "你是一名星际指挥官，从一艘种子飞船起步，\n建立属于自己的星际帝国。\n\n让我们开始你的征途！",
            btnText  = "出发！",
            high
...
```

#### `TutorialSystem_tutorial_system.lua` — TutorialSystem 相关函数（15 个函数，约 76 行代码）

- **对应原文件行**: `L175-L653` (479 行)
- **区块类型**: `module`
- **包含函数**: `TutorialSystem.SetEnabled(flag)`, `TutorialSystem.IsEnabled()`, `TutorialSystem.Reset()`, `TutorialSystem.TriggerPhase(phaseName)`, `TutorialSystem.TriggerStart()`, `TutorialSystem.TriggerDeployed()`, `TutorialSystem.Skip()`, `TutorialSystem.IsActive()`（共 15 个，其余省略）

```lua
function TutorialSystem.SetEnabled(flag)
    enabled_ = flag ~= false
    if not enabled_ then
        -- 立刻关闭当前弹窗

function TutorialSystem.IsEnabled()
    return enabled_
end
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/ui/TutorialSystem.lua  -- P3-3: 新手引导系统（4阶段渐进+脉冲高亮+跳过开关）
-- 银河征服 MMOSLG 新手引导
-- ============================================================================

local UICommon = require("game.ui.UICommon")

-- 从拆分后的子模块导入
local Tutorialsystemphases = require("ui.TutorialSystem_phases")
local Tutorialsystemtutorialsystem = require("ui.TutorialSystem_tutorial_system")

-- （剩余核心逻辑位于以下子文件：）
--   * TutorialSystem_phases.lua  (122 行)  -- 数据表模块（PHASES 定义）
--   * TutorialSystem_tutorial_system.lua  (479 行)  -- TutorialSystem 相关函数（15 个函数，约 76 行代码）

return TutorialSystem
```

---

## 24. TopBar.lua

- **原文件路径**: `game/ui/TopBar.lua`
- **原文件大小**: 636 行
- **拆分策略**: 检测到原文件 636 行，超过阈值 600 行。 建议拆分为 2 个文件（1 个主文件 + 1 个子模块），总计 86 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `TopBar_part2.lua` | 第 2 部分（通用分段，建议手动分析后改为有意义的命名） | 36 | L601-L636 |

### 子模块内容预览

#### `TopBar_part2.lua` — 第 2 部分（通用分段，建议手动分析后改为有意义的命名）

- **对应原文件行**: `L601-L636` (36 行)
- **区块类型**: `chunk`

```lua
if pirPct > 0.005 then
                local fillW = half * pirPct
                local grad2 = nvgLinearGradient(vg, half, barY, half + fillW, barY,
                    nvgRGBA(220, 80, 30, 220), nvgRGBA(255, 160, 60, 180))
                nvgBeginPath(vg); nvgRect(vg, half, barY, fillW, barH)
                nvgFillPaint(vg, grad2); nvgFill(vg)
            end
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 160, 70, 190))
            local pirLabel = string.format("歼敌 %d/%d", cp.piratesKilled, cp.piratesTotal)
            if cp.pirateThreat and cp.pirateThreat > 0 then
```

### 重构后主文件预览（骨架）

```lua
---@diagnostic disable: missing-parameter, assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/ui/TopBar.lua  -- 顶部资源栏 + 工具按钮行 + 征服进度条
-- 从 GameUI.RenderTopBar (L614-L1211) 完整迁移
-- ============================================================================
local UICommon          = require("game.ui.UICommon")
local NotifyPanel       = require("game.ui.NotifyPanel")
local SettingsPanel     = require("game.ui.SettingsPanel")
local AchievementPanel  = require("game.ui.AchievementPanel")
local LogPanel          = require("game.ui.LogPanel")
local EmpirePanel       = require("game.ui.EmpirePanel")
local NemesisRenderPanel = require("game.ui.NemesisRenderPanel")
local NemesisSystem     = require("game.NemesisSystem")
local QuestBoard        = require("game.QuestBoard")
local MegaPanel         = require("game.ui.MegaPanel")
local LiveryPanel       = require("game.ui.LiveryPanel")
local GalactopediaPanel = require("game.ui.GalactopediaPanel")
local GalaxyScene       = require("game.GalaxyScene")
local LegacyPanel       = require("game.ui.LegacyPanel")

-- 从拆分后的子模块导入
local Topbarpart2 = require("ui.TopBar_part2")

-- （剩余核心逻辑位于以下子文件：）
--   * TopBar_part2.lua  (36 行)  -- 第 2 部分（通用分段，建议手动分析后改为有意义的命名）

return TopBar
```

---

## 25. SettingsPanel.lua

- **原文件路径**: `game/ui/SettingsPanel.lua`
- **原文件大小**: 628 行
- **拆分策略**: 检测到原文件 628 行，超过阈值 600 行。 建议拆分为 3 个文件（1 个主文件 + 2 个子模块），总计 254 行左右代码。

### 建议的子模块文件

| # | 文件名 | 用途 | 行数 | 原位置 |
|---|--------|------|------|--------|
| 1 | `SettingsPanel_config.lua` | 配置常量（从原文件拆分独立模块） | 32 | L12-L43 |
| 2 | `SettingsPanel_settings_panel.lua` | SettingsPanel 相关函数（20 个函数，约 68 行代码） | 172 | L453-L624 |

### 子模块内容预览

#### `SettingsPanel_config.lua` — 配置常量（从原文件拆分独立模块）

- **对应原文件行**: `L12-L43` (32 行)
- **区块类型**: `config`

```lua
local visible_          = false
local bgmVol_           = 0.7
local sfxVol_           = 1.0
local mute_             = false

-- P3-3: 画质档位 1=低 2=中 3=高
local qualityLevel_     = 2
-- P3-3: 色觉辅助模式 "normal" | "protanopia" | "tritanopia"
local colorblindMode_   = "normal"
-- P3-3: FPS 显示开关
local showFPS
...
```

#### `SettingsPanel_settings_panel.lua` — SettingsPanel 相关函数（20 个函数，约 68 行代码）

- **对应原文件行**: `L453-L624` (172 行)
- **区块类型**: `module`
- **包含函数**: `SettingsPanel.SetAudio(audioModule)`, `SettingsPanel.Load()`, `SettingsPanel.Show()`, `SettingsPanel.Hide()`, `SettingsPanel.IsVisible()`, `SettingsPanel.Toggle()`, `SettingsPanel.Render()`, `SettingsPanel.GetSliderRects()`（共 20 个，其余省略）

```lua
function SettingsPanel.SetAudio(audioModule)
    Audio_ = audioModule
end

function SettingsPanel.Load()
    loadSettings()
end
```

### 重构后主文件预览（骨架）

```lua
-- ============================================================================
-- game/ui/SettingsPanel.lua  -- 游戏设置面板（音频 + 画质 + 色觉辅助 + FPS）
-- P3-3 V2.4: 性能优化与辅助功能
-- ============================================================================
local UICommon        = require "game.ui.UICommon"
local Audio           = require "game.Systems"  -- Audio 由 GameUI 通过 SetAudio 注入
local TutorialSystem  = require "game.ui.TutorialSystem"

-- 从拆分后的子模块导入
local Settingspanelconfig = require("ui.SettingsPanel_config")
local Settingspanelsettingspanel = require("ui.SettingsPanel_settings_panel")

-- （剩余核心逻辑位于以下子文件：）
--   * SettingsPanel_config.lua  (32 行)  -- 配置常量（从原文件拆分独立模块）
--   * SettingsPanel_settings_panel.lua  (172 行)  -- SettingsPanel 相关函数（20 个函数，约 68 行代码）

return SettingsPanel
```

---

---
_报告由 `code_health_check.py` 自动生成_
