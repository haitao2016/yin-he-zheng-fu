---
name: ai-game-tester
description: |
  UrhoX Lua 游戏 AI 自动化测试框架。
  灵感源自 AI-Game-Tester（https://github.com/DreamwalkerSisyphe/AI-Game-Tester），
  将 C++ 桌面 RPG 的 Trie 字典搜索、GameTree 决策树、Dice 骰子模拟、
  Transcript 历史学习等核心 AI 理念迁移到 UrhoX Lua 引擎内，
  为开发者提供无需人工操作的 RPG 行动系统/文本命令/概率平衡自动化测试能力。

  核心能力：
  - Trie 字典树：模糊搜索、字谜重组、编辑距离匹配，测试文本命令解析
  - 决策引擎：基于历史记录评估最佳行动，学习过往测试会话
  - 骰子模拟器：多骰投掷、爆炸骰、成功阈值，批量概率分布分析
  - 行动系统：动词+名词组合法术/技能，等级计算与平衡验证
  - 会话记录器：JSON 序列化测试会话，可回放、可分析、可学习

  Use when: users need to
    (1) 自动化测试 RPG 法术/技能组合系统的平衡性
    (2) 用 Trie 字典树测试文本命令/指令的模糊匹配
    (3) 模拟骰子投掷并分析概率分布（游戏平衡）
    (4) 记录并回放 AI 测试会话（历史学习）
    (5) 用决策树评估 AI 在不同情景下的最优行动
    (6) 批量测试行动组合的成功率与等级分布
    (7) 用户说"RPG测试""法术测试""骰子模拟""概率分析""AI决策"

  MUST trigger when:
    - 用户要求用 AI 自动测试 RPG 技能/法术系统
    - 用户需要模拟骰子概率分析游戏平衡
    - 用户说"文本命令测试"或"行动组合测试"

  trigger-keywords:
    - RPG测试
    - 法术测试
    - 技能测试
    - 骰子模拟
    - 概率分析
    - AI决策
    - 文本命令
    - 模糊匹配
    - 行动组合
    - 游戏平衡
    - 历史学习
    - 会话记录
    - spell test
    - dice simulation
    - trie search
    - decision tree
    - game balance
    - RPG balance
---

# AI Game Tester — UrhoX Lua RPG AI 自动化测试框架

## §1 身份与定位

你是一位 UrhoX Lua 游戏 AI 测试工程师。你的工作是在 UrhoX 引擎中部署
基于 Trie 字典树 + 决策树 + 骰子模拟的 AI 测试智能体，自动测试 RPG
法术/技能系统、文本命令解析、概率平衡，记录测试会话供历史学习。

**原始仓库映射**（C++ → Lua）：

| C++ 原始模块 | Lua 模块 | 映射说明 |
|-------------|----------|---------|
| `Trie.cpp/hpp` | `TrieEngine` | 26 叉字典树 → Lua table 实现，支持模糊搜索 |
| `GameTree.cpp/hpp` | `DecisionEngine` | 历史 Transcript 评估 → JSON 记录学习 |
| `Spell.cpp/hpp` | `ActionSystem` | 动词+名词法术 → 通用行动组合系统 |
| `Transcript.cpp/hpp` | `SessionRecorder` | 二进制 .gts → JSON 序列化 |
| `helpers.cpp/hpp` | `StringUtils`（内联） | 字符差异计算、单词比较 |
| `Scenario.cpp/hpp` | Scenario 结构 | 内嵌于 DecisionEngine |
| `main.cpp` | `TestRunner` | 测试编排入口 |

**与其他 Skill 的关系**：

| Skill | 职责 | 本 Skill 的互补点 |
|-------|------|-------------------|
| `game-balancing` | 数值平衡设计 | 本 Skill 提供**骰子概率数据**支撑平衡决策 |
| `game-bug-checker` | 静态代码扫描 | 本 Skill 做**运行时行为测试** |
| `jrpg-design` | JRPG 系统设计 | 本 Skill **验证** JRPG 技能/法术系统设计 |

---

## §2 核心架构

```
┌──────────────────────────────────────────────────┐
│                  TestRunner                      │
│   (测试编排：配置 → 执行 → 采集 → 报告)            │
└───┬──────┬──────────┬──────────┬──────────┬──────┘
    │      │          │          │          │
┌───▼──┐┌──▼─────┐┌───▼────┐┌───▼─────┐┌───▼──────────┐
│ Trie ││Action  ││ Dice   ││Decision ││  Session     │
│Engine││System  ││Simulator││Engine  ││  Recorder    │
└──────┘└────────┘└────────┘└─────────┘└──────────────┘
```

| 模块 | 文件 | 职责 |
|------|------|------|
| **TrieEngine** | `scripts/test/TrieEngine.lua` | 字典树构建、精确/模糊搜索、字谜重组 |
| **ActionSystem** | `scripts/test/ActionSystem.lua` | 动词+名词行动组合、等级计算、最优行动搜索 |
| **DiceSimulator** | `scripts/test/DiceSimulator.lua` | 多骰投掷、爆炸骰、成功判定、批量概率分布 |
| **DecisionEngine** | `scripts/test/DecisionEngine.lua` | 基于历史记录评估情景、上下文相似度 |
| **SessionRecorder** | `scripts/test/SessionRecorder.lua` | JSON 序列化测试会话、加载历史、回放分析 |
| **TestRunner** | `scripts/test/TestRunner.lua` | 批量测试编排、统计汇总、NanoVG 报告渲染 |

> **完整模块实现代码** → [references/modules-implementation.md](references/modules-implementation.md)

---

## §3 核心模块 API 速查

### TrieEngine（字典树 — 映射自 Trie.cpp）

```lua
local TrieEngine = require("test.TrieEngine")
local trie = TrieEngine.new()
trie:insert("fireball")               -- 插入单词
trie:search("fireball")               -- 精确搜索 → true/false
trie:fuzzySearch("firebll", 2)         -- 模糊搜索（最多 2 次编辑）→ {"fireball", ...}
trie:anagramSearch("lerfibal", false)  -- 字谜搜索（字母重组）→ {"fireball", ...}
trie:loadFromList(wordTable)           -- 批量加载单词表
trie:allWords()                        -- 返回所有已插入单词
```

### ActionSystem（行动组合 — 映射自 Spell.cpp + GameTree.getBestSpell）

```lua
local ActionSystem = require("test.ActionSystem")
local sys = ActionSystem.new(verbList, nounList)  -- 传入动词表和名词表
local action = sys:createAction("pull", "rule")   -- 创建行动（动词+名词）
local level = sys:calcLevel(action, origAction)    -- 计算等级（字符差异）
local best = sys:findBestAction(origAction, curAction, context, history, maxChanges)
-- best = { verb="push", noun="wall", score=12.5 }
sys:randomAction()                                -- 随机行动
```

### DiceSimulator（骰子 — 映射自 Transcript 中的 dice 逻辑）

```lua
local DiceSimulator = require("test.DiceSimulator")
local dice = DiceSimulator.new({
    count = 6,            -- 投 6 个骰子
    sides = 6,            -- 6 面骰
    successThreshold = 4, -- 4+ 算成功
    exploding = true,     -- 6 触发爆炸骰（额外再投）
})
local result = dice:roll()
-- result = { rolls={3,5,6,2,4,1,3}, successes=3, total=7, exploded=1 }
local success = dice:check(result, requiredSuccesses)  -- true/false

-- 批量统计
local dist = dice:batchSimulate(10000, requiredLevel)
-- dist = { successRate=0.72, avgSuccesses=3.1, histogram={[0]=5,...,[6]=800,...} }
```

### DecisionEngine（决策 — 映射自 GameTree.cpp）

```lua
local DecisionEngine = require("test.DecisionEngine")
local engine = DecisionEngine.new()
engine:loadHistory(scenarioList)  -- 加载历史场景记录
local best = engine:evaluate(originalAction, currentAction, contextText)
-- best = { verb="pull", noun="ear", score=8.3 } 或 nil
engine:addScenario(scenario)     -- 添加新场景到历史库
```

**评估公式**（映射自 `GameTree::getBestSpell`）：
```
score = contextSimilarity × spellSimilarity × (rating + 3)
其中:
  contextSimilarity = compareWords(历史文本, 当前文本)
  spellSimilarity   = 0.5 ^ countDiff(原始法术, 历史法术)
  rating            = 历史评分 (-2 到 +2) + 3 偏移
```

### SessionRecorder（会话记录 — 映射自 Transcript.cpp）

```lua
local SessionRecorder = require("test.SessionRecorder")
local recorder = SessionRecorder.new(startAction)
recorder:addScenario({
    text = "A wolf lunges at you",
    action = { verb = "pull", noun = "near" },
    success = true,
    rating = 1,  -- -2 到 +2
})
recorder:setEnding("You escaped the forest")
recorder:save("transcripts/session_001.json")   -- JSON 格式保存

-- 加载历史
local sessions = SessionRecorder.loadAll("transcripts/")
```

### TestRunner（一键批量测试）

```lua
local TestRunner = require("test.TestRunner")
local runner = TestRunner.new({
    verbs = verbList,
    nouns = nounList,
    rounds = 200,
    diceConfig = { count = 6, sides = 6, successThreshold = 4, exploding = true },
})
runner:runActionTest(200)     -- 批量测试行动组合
runner:runDiceAnalysis(10000) -- 骰子概率分布分析
runner:runDecisionTest(contextList, historyDir)  -- 决策引擎测试
runner:printReport()          -- 控制台报告
-- NanoVG 渲染报告见 references/integration-examples.md
```

---

## §4 快速开始

```bash
# 1. 创建测试目录
mkdir -p scripts/test

# 2. 将模块代码放入对应文件（见 references/modules-implementation.md）
# scripts/test/TrieEngine.lua
# scripts/test/ActionSystem.lua
# scripts/test/DiceSimulator.lua
# scripts/test/DecisionEngine.lua
# scripts/test/SessionRecorder.lua
# scripts/test/TestRunner.lua

# 3. 在 main.lua 中集成（见 references/integration-examples.md）

# 4. 构建并运行 → 调用 UrhoX MCP build 工具
```

> **完整 main.lua 集成示例** → [references/integration-examples.md](references/integration-examples.md)
> **NanoVG 可视化报告、自定义行动字典、JSON 历史回放** → 同上

---

## §5 关键约束

1. **数组索引从 1 开始** — Lua table 下标从 1 起，Trie 子节点用 `children[char]` 而非数字下标
2. **NanoVG 渲染必须在 NanoVGRender 事件中** — 报告可视化在此事件回调中绘制
3. **nvgCreateFont 只调用一次** — 在 `Start()` 中创建，句柄全局复用
4. **使用枚举常量** — `KEY_R` / `KEY_ESCAPE` 等，不使用数字
5. **代码放 scripts/ 目录** — 测试模块放 `scripts/test/`
6. **文件读写用 File** — JSON 会话保存/加载用 `File()` + `cjson`，不使用 `io` 库
7. **分辨率用 GetWidth/GetHeight/GetDPR** — 不调用 `SetMode()`
8. **构建后测试** — 每次修改代码后必须调用 UrhoX MCP build 工具
9. **Trie 用 Lua table 实现** — 不依赖 C 扩展，`node.children[char] = childNode`
10. **随机数用 math.random** — 已由引擎初始化种子，无需 `math.randomseed`
