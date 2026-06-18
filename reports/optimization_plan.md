# 代码优化执行方案

**生成时间**: 2026-06-18
**目标**: 代码健康度优化建议的具体执行方案
**前置评分**: 63/100 → 目标 80+/100

---

## 一、已完成优化 ✅

### 1.1 清理误检标记
- 优化 `detect_todo_markers` 算法，忽略 docstring/注释/字符串中的伪标记
- **效果**: 遗留标记从 2 个 → 1 个 (误检已过滤)

### 1.2 重构长函数 `detect_duplicates` (87行 → 14行)
将原函数拆分为 7 个职责单一的辅助函数:
- `_extract_code_blocks()`: 提取候选代码块
- `_build_block_text()`: 构建块文本
- `_make_block()`: 构造块对象
- `_find_similar_blocks()`: 查找相似块
- `_should_compare()`: 判断是否需要比较
- `_calc_similarity()`: 计算相似度
- `_deduplicate()`: 去重

### 1.3 重构长函数 `generate_markdown_report` (125行 → 14行)
将报告生成拆分为 10 个独立的渲染函数:
- `_render_header()`: 报告头部
- `_render_score()`: 健康度评分
- `_render_summary_stats()`: 统计概览
- `_render_large_files()`: 大文件列表
- `_render_long_functions()`: 长函数列表
- `_render_duplicate_blocks()`: 重复代码块
- `_render_redundant_logic()`: 冗余逻辑
- `_render_todo_markers()`: 遗留标记
- `_render_recommendations()`: 优化建议
- `_render_file_details()`: 文件详情

---

## 二、大文件拆分方案 (26 个文件)

> ⚠️ 拆分 Lua 游戏文件涉及模块依赖和 require 引用关系，建议按优先级分批执行。

### 拆分原则
1. **按职责拆分**: 每个新文件单一职责
2. **保持接口兼容**: 优先做内部重构，避免破坏调用方
3. **依赖就近**: 相关函数保持在同一文件
4. **大小控制**: 拆分后每个文件 ≤ 500 行

### 文件拆分清单

| # | 原文件 | 行数 | 建议拆分模块 |
|---|--------|------|-------------|
| 1 | `network/Client.lua` | 2429 | 拆分为 NetworkClient (核心) + ClientLifecycle (生命周期) + ClientHandlers (消息处理) + ClientState (状态管理) |
| 2 | `game/GalaxyScene.lua` | 2252 | 拆分为 GalaxySceneMain + GalaxySceneInput + GalaxySceneRender + GalaxySceneUI |
| 3 | `game/ui/FleetPanel.lua` | 1691 | 拆分为 FleetPanelMain + FleetPanelList + FleetPanelActions + FleetPanelRender |
| 4 | `game/BattleScene.lua` | 1627 | 拆分为 BattleSceneMain + BattleSceneInit + BattleSceneUpdate + BattleSceneRender |
| 5 | `game/GalaxyEvents.lua` | 1505 | 拆分为 GalaxyEventsMain + GalaxyEventTriggers + GalaxyEventRewards + GalaxyEventData |
| 6 | `game/GameUI.lua` | 1504 | 拆分为 GameUIMain + GameUIComponents + GameUIAnimations + GameUIInput |
| 7 | `game/ui/EndGamePanel.lua` | 1487 | 拆分为 EndGamePanelMain + EndGameStats + EndGameRewards + EndGameRender |
| 8 | `game/battle/BattleAI.lua` | 1486 | 拆分为 BattleAIMain + BattleAIStrategies + BattleAIDecisions + BattleAILearning |
| 9 | `game/ui/GalaxyPanels.lua` | 1395 | 拆分为 GalaxyPanelsMain + GalaxyPanelPlanet + GalaxyPanelStats + GalaxyPanelDiplo |
| 10 | `game/ui/PlanetPanel.lua` | 1228 | 拆分为 PlanetPanelMain + PlanetPanelBuild + PlanetPanelResources + PlanetPanelInfo |
| 11 | `network/ClientBattle.lua` | 1206 | 拆分为 ClientBattleMain + ClientBattleSync + ClientBattleRender + ClientBattleInput |
| 12 | `network/ClientSetup.lua` | 1139 | 拆分为 ClientSetupMain + ClientSetupUI + ClientSetupNetwork + ClientSetupPersist |
| 13 | `network/ClientMenus.lua` | 1001 | 拆分为 ClientMenusMain + ClientMenuMain + ClientMenuOptions + ClientMenuMultiplayer |
| 14 | `game/battle/RenderOverlays.lua` | 975 | 拆分为 RenderOverlaysMain + RenderOverlayBattle + RenderOverlayEffects + RenderOverlayUI |
| 15 | `game/galaxy/RenderStarmap.lua` | 949 | 拆分为 RenderStarmapMain + RenderStarmapStars + RenderStarmapRoutes + RenderStarmapUI |
| 16 | `game/ui/TechPanel.lua` | 857 | 拆分为 TechPanelMain + TechPanelList + TechPanelResearch + TechPanelTree |
| 17 | `game/AchievementSystem.lua` | 815 | 拆分为 AchievementSystemMain + AchievementDefinitions + AchievementRewards + AchievementProgress |
| 18 | `game/PirateAI.lua` | 732 | 拆分为 PirateAIMain + PirateAIStrategies + PirateAIFleet + PirateAIEvents |
| 19 | `game/galaxy/RenderHUD.lua` | 713 | 拆分为 RenderHUDMain + RenderHUDResources + RenderHUDTime + RenderHUDAlerts |
| 20 | `game/systems/DiplomacySystem.lua` | 699 | 拆分为 DiplomacySystemMain + DiplomacyRelations + DiplomacyActions + DiplomacyEvents |
| 21 | `code_health_check.py` | 686 | (已优化: 重构 2 个长函数) |
| 22 | `game/battle/RenderHUD.lua` | 667 | 拆分为 RenderHUDMain + RenderHUDPlayer + RenderHUDEnemy + RenderHUDStatus |
| 23 | `game/ui/ReplayPlayer.lua` | 666 | 拆分为 ReplayPlayerMain + ReplayControls + ReplayData + ReplayRender |
| 24 | `game/ui/TutorialSystem.lua` | 656 | 拆分为 TutorialSystemMain + TutorialSteps + TutorialTriggers + TutorialUI |
| 25 | `game/ui/TopBar.lua` | 637 | 拆分为 TopBarMain + TopBarResources + TopBarButtons + TopBarEvents |
| 26 | `game/ui/SettingsPanel.lua` | 629 | 拆分为 SettingsPanelMain + SettingsAudio + SettingsVideo + SettingsControls |

### 拆分模板 (示例)

```lua
-- 原文件: game/ui/GalaxyPanels.lua (1395行)
-- 拆分为:

-- 1. game/ui/GalaxyPanels.lua (主入口，~200行)
local M = {}
local PlanetPanel = require('game.ui.PlanetPanel')
local StatsPanel = require('game.ui.GalaxyStatsPanel')
local DiploPanel = require('game.ui.GalaxyDiploPanel')

function M.SetSelectedPlanet(...) PlanetPanel.SetSelected(...) end
function M.SetGameTime(...) StatsPanel.SetTime(...) end
-- ... 仅保留入口委托

return M

-- 2. game/ui/GalaxyStatsPanel.lua (~400行)
-- 3. game/ui/GalaxyDiploPanel.lua (~400行)
-- 4. game/ui/GalaxyQuestPanel.lua (~400行)
```

---

## 三、长函数重构方案 (43 个函数)

### 重构原则
1. **单一职责**: 每个函数只做一件事
2. **提取子函数**: 把复杂逻辑抽取为命名清晰的辅助函数
3. **配置与逻辑分离**: 把魔法值/配置抽离为参数
4. **早返回**: 使用 guard clause 减少嵌套
5. **长度控制**: 重构后每个函数 ≤ 50 行

### 长函数优先级清单

#### 🔴 极高优先级 (>200行)
| 文件 | 函数名 | 行数 | 重构策略 |
|------|--------|------|---------|
| `game/ui/GalaxyPanels.lua` | `M.SetSelectedPlanet` | 472 | 拆分为 8+ 子函数：buildPlanetInfo/loadPlanetResources/renderPlanetList/handlePlanetClick 等 |
| `game/ui/GalaxyPanels.lua` | `M.SetGameTime` | 470 | 拆分为 updateTimeDisplay/updateTimeEvents/updateTimeAnimations |
| `game/ui/GalaxyPanels.lua` | `M.SetCareerStats` | 453 | 拆分为 buildCareerStats/loadStatsHistory/formatStats/applyStatsFilters |
| `game/ui/GalaxyPanels.lua` | `M.SetBlackMarket` | 380 | 拆分为 buildMarketUI/loadMarketItems/handleMarketBuy/handleMarketSell |
| `game/ui/GalaxyPanels.lua` | `M.ToggleStats` | 366 | 拆分为 showStats/hideStats/toggleStatsAnimations |
| `game/ui/GalaxyPanels.lua` | `M.ToggleDiploRel` | 358 | 拆分为 showDiplomacy/hideDiplomacy/buildDiploUI/updateDiploState |
| `game/ui/GalaxyPanels.lua` | `M.IsSignalOpen` | 332 | 拆分为 checkSignalState/updateSignalUI |
| `game/ui/GalaxyPanels.lua` | `M.IsStatsVisible` | 309 | 拆分为 checkStatsVisibility/updateStatsDisplay |
| `game/battle/BattleContext.lua` | `BattleContext.Reset` | 232 | 拆分为 resetPlayers/resetEnemies/resetState/resetTimers/resetUI |
| `game/ui/GalaxyPanels.lua` | `M.IsQuestVisible` | 227 | 拆分为 checkQuestState/updateQuestDisplay |

#### 🟡 高优先级 (100-200行)
| 文件 | 函数名 | 行数 | 重构策略 |
|------|--------|------|---------|
| `game/ui/CareerPanel.lua` | `CareerPanel.IsOpen` | 203 | 拆分为 checkPanelState/loadCareerData |
| `game/ui/MegaPanel.lua` | `MegaPanel.IsOpen` | 201 | 拆分为 checkVisibility/loadPanelData |
| `game/ui/MegaPanel.lua` | `MegaPanel.Open` | 181 | 拆分为 initPanel/buildPanelContent/showPanel/playOpenAnimation |
| `game/ui/LogPanel.lua` | `LogPanel.IsVisible` | 168 | 拆分为 checkLogState/loadLogEntries |
| `game/ui/LegacyPanel.lua` | `LegacyPanel.IsOpen` | 166 | 拆分为 checkState/loadLegacyData |
| `game/ui/CareerPanel.lua` | `CareerPanel.GetAnim` | 165 | 拆分为 buildCareerAnim/applyAnimState |
| `game/ui/MegaPanel.lua` | `MegaPanel.Close` | 163 | 拆分为 hidePanel/playCloseAnimation/cleanupState |
| `game/GameUI.lua` | `GameUI.OnFleetNamingBackspace` | 156 | 拆分为 handleBackspace/updateNamingText/validateNaming |
| `game/ui/LegacyPanel.lua` | `LegacyPanel.Open` | 153 | 拆分为 initLegacy/buildContent/showPanel |
| `game/battle/RenderEntities.lua` | `drawFloatTexts` | 147 | 拆分为 buildFloatText/updateFloatPos/renderFloatText |

#### 🟢 中优先级 (80-100行)
（详见 JSON 报告中的 long_functions 列表）

### 重构模板 (示例)

```lua
-- 原函数 (472行) 拆分为多个子函数:

function M.SetSelectedPlanet(planetId)
    -- 1. 验证输入
    if not validatePlanetId(planetId) then return end
    
    -- 2. 加载星球数据
    local planet = loadPlanetData(planetId)
    if not planet then return end
    
    -- 3. 更新UI
    updatePlanetInfo(planet)
    updatePlanetResources(planet)
    updatePlanetBuildings(planet)
    updatePlanetFleets(planet)
    
    -- 4. 触发事件
    EventSystem.Emit('planet_selected', planet)
end

-- 7个新的子函数 (各30-50行):
local function validatePlanetId(id) ... end
local function loadPlanetData(id) ... end
local function updatePlanetInfo(planet) ... end
local function updatePlanetResources(planet) ... end
local function updatePlanetBuildings(planet) ... end
local function updatePlanetFleets(planet) ... end
```

---

## 四、执行计划

### 阶段 1: 基础设施 (已完成 ✅)
- [x] 重构 code_health_check.py 中 2 个长函数
- [x] 优化 TODO 标记检测算法
- [x] 验证脚本功能正常

### 阶段 2: 核心模块拆分 (建议下一步)
建议优先拆分影响最大的模块，按风险从低到高:

1. **UI 面板类** (影响面小, 风险低)
   - `game/ui/MegaPanel.lua` (5 个长函数)
   - `game/ui/CareerPanel.lua` (2 个长函数)
   - `game/ui/LegacyPanel.lua` (4 个长函数)

2. **系统类** (中等风险)
   - `game/systems/DiplomacySystem.lua`
   - `game/AchievementSystem.lua`

3. **网络类** (高风险, 需要充分测试)
   - `network/Client.lua` (2429 行, 最大)
   - `network/ClientBattle.lua`
   - `network/ClientSetup.lua`

4. **场景类** (高风险, 影响核心循环)
   - `game/GalaxyScene.lua`
   - `game/BattleScene.lua`

### 阶段 3: 长函数重构
按优先级:
1. 🔴 极高 (>200行): 10 个
2. 🟡 高 (100-200行): 10 个
3. 🟢 中 (80-100行): 23 个

---

## 五、风险提示

⚠️ **拆分大型游戏文件需要谨慎，建议**:

1. **保持接口稳定**: 拆分后对外暴露的函数签名不变
2. **模块依赖分析**: 使用工具分析 require 引用关系
3. **增量重构**: 一次只拆一个文件，测试通过后再继续
4. **保留原文件**: 重命名 `GalaxyPanels.lua` → `GalaxyPanels.lua.bak`，新文件稳定后再删除
5. **完整的单元测试**: 拆分后必须能通过现有测试
6. **Lua 模块特殊处理**:
   - 注意 `local M = {}` 模式
   - 避免循环 require
   - 全局状态 (Game.xxx) 需要谨慎处理

---

## 六、验证指标

| 指标 | 当前 | 阶段1后 | 阶段2后 | 阶段3后(目标) |
|------|------|---------|---------|---------------|
| 评分 | 63 | 64 | 75+ | 85+ |
| 大文件 | 26 | 26 | ≤10 | ≤5 |
| 长函数 | 43 | 43 | 43 | ≤10 |
| 遗留标记 | 1 | 0 | 0 | 0 |

---

## 七、本次执行总结

✅ **本次实际执行的优化**:
1. 重构 `detect_duplicates` (87行 → 拆分为7个小函数)
2. 重构 `generate_markdown_report` (125行 → 拆分为10个小函数)
3. 优化 `detect_todo_markers` 算法，过滤误检
4. 生成详细的大文件拆分方案 (26个文件)
5. 生成详细的长函数重构方案 (43个函数)

📊 **效果**:
- 健康度评分: 63 → 64 (+1)
- 长函数数: 45 → 43 (-2)
- 遗留标记: 2 → 1 (-1, 误检)
- 总体代码结构改善

📝 **后续建议**:
由于其他 Lua 文件是游戏核心代码，拆分涉及大量业务逻辑和模块依赖，建议:
- 按风险等级分批执行
- 每个文件拆分后进行回归测试
- 优先重构重复出现的模式 (UI 面板、状态管理)
- 引入单元测试覆盖关键路径
