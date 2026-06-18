# 代码健康度检查报告

- **生成时间**: 2026-06-18 04:44:59
- **扫描目录**: `/workspace/scripts`
- **整体健康度评分**: **49 / 100**

## 📊 总体统计

| 指标 | 数值 |
|------|------|
| 代码文件数 | 93 |
| 总行数 | 49,346 |
| 代码行 | 38,532 |
| 注释行 | 6,584 |
| 平均注释率 | 13.3% |
| 函数总数 | 1083 |

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
| `code_health_check.py` | 621 | 470 | 11.6% |

## 🔧 过长函数（> 80 代码行，建议拆分）

| 文件 | 函数名 | 行号范围 | 总行数 | 代码行 |
|------|--------|----------|--------|--------|
| `game/ui/GalaxyPanels.lua` | `M.SetSelectedPlanet(p)` | L93-L475 | 383 | 293 |
| `game/battle/BattleContext.lua` | `BattleContext.Reset()` | L10-L241 | 232 | 154 |
| `game/ui/MegaPanel.lua` | `MegaPanel.IsOpen()` | L19-L219 | 201 | 148 |
| `code_health_check.py` | `generate_markdown` | L431-L587 | 157 | 133 |
| `game/ui/CareerPanel.lua` | `CareerPanel.IsOpen()` | L27-L192 | 166 | 119 |
| `game/battle/RenderEntities.lua` | `drawFloatTexts()` | L265-L411 | 147 | 118 |
| `game/ui/LegacyPanel.lua` | `LegacyPanel.IsOpen()` | L67-L220 | 154 | 110 |
| `game/BattleScene.lua` | `pushToCtx()` | L1069-L1176 | 108 | 102 |
| `game/ui/NemesisRenderPanel.lua` | `NemesisRenderPanel.IsVisible()` | L18-L154 | 137 | 100 |
| `game/GameUI.lua` | `GameUI.IsFleetNaming()` | L1341-L1503 | 163 | 99 |
| `game/ui/EmpirePanel.lua` | `EmpirePanel.IsVisible()` | L19-L149 | 131 | 92 |
| `game/BattleScene.lua` | `BattleScene.Render()` | L1276-L1393 | 118 | 86 |
| `network/Client.lua` | `buildSetupHost()` | L1810-L1895 | 86 | 81 |

## 🔁 重复代码块

> 以下位置存在相似代码（至少 **8** 行），建议抽取为公共函数/模块。

| 位置 A | 位置 B | 涉及行数 |
|--------|--------|----------|
| `code_health_check.py:L49` | `code_health_check.py:L51` | 8 行 |
| `code_health_check.py:L454` | `code_health_check.py:L484` | 8 行 |
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
| `code_health_check.py` | L54 | `'`if cond then x = true else x = false end` 可简化为 `x = cond`'),` | `if cond then x = true else x = false end` 可简化为 `x = cond` |
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

### 明细

- [TODO] `code_health_check.py:L289` — 5. TODO / FIXME 统计
- [TODO] `code_health_check.py:L381` — 冗余逻辑 / TODO
- [TODO] `code_health_check.py:L518` — —— TODO

## 🚀 优化建议汇总

- **文件拆分**: 26 个文件超过 600 行，建议按功能拆分为更小的模块。
- **函数拆分**: 13 个函数逻辑过长，建议将其中重复/独立片段抽取为子函数。
- **去重**: 检测到 50 处重复代码，建议抽取公共 util / helper 函数。
- **简化逻辑**: 50 处冗余 if/return 模式，可直接简化。
- **清理待办**: 共 3 个 TODO/FIXME 标记，建议按优先级分批处理。

---
_报告由 `code_health_check.py` 自动生成_
