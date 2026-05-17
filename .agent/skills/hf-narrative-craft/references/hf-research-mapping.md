# HF Research Mapping — Hugging Face 社区项目与 hf-narrative-craft 模块映射

> 本文档记录 Hugging Face 社区中与游戏叙事内容生成相关的研究项目、数据集和模型，
> 以及它们如何映射到本 Skill 的五大模块。供 AI 理解设计背景时参考。

---

## 1. DialogueForge 模块的研究基础

### 1.1 NPC 对话模型

| HF 项目 | 类型 | 与本模块的关系 |
|---------|------|---------------|
| `Gemma3NPC` | Fine-tuned LLM | 专为游戏 NPC 对话微调的模型，证明结构化对话树生成的可行性 |
| `npcLM` | Language Model | NPC 语言模型研究，展示了角色一致性对话的技术路线 |
| `Amaydle/npc-dialogue-dataset` | Dataset (1724条) | 结构化 NPC 对话数据集，提供了 JSON 对话格式的行业参考 |

### 1.2 关键设计决策来源

**从 HF 研究中提取的设计原则**：

1. **对话树 vs 自由对话**
   - HF 上的 NPC 对话模型多采用自由对话（runtime LLM inference）
   - 本 Skill 选择**对话树**（build-time 生成），原因：
     - UrhoX 运行时无 LLM 推理能力
     - 对话树可完全离线验证
     - 游戏设计师需要精确控制叙事流向
     - 构建时用 Claude 生成高质量对话树，运行时纯 Lua 驱动

2. **对话节点格式**
   - Amaydle 数据集格式：`{ speaker, text, emotion, choices[] }`
   - 本 Skill 扩展为：`{ id, speaker, text, emotion, choices[], conditions, actions }`
   - 增加了 `conditions`（条件分支）和 `actions`（触发游戏事件）

3. **情感标注**
   - HF 对话数据集普遍包含情感标注（neutral/happy/angry/sad 等）
   - 本 Skill 保留此设计，并映射到 UrhoX 动画状态：
     - `neutral` → idle 动画
     - `happy` → smile 表情 + 轻微点头
     - `angry` → frown 表情 + 手势动画

### 1.3 数据集格式对比

```
HF Amaydle 格式:           本 Skill 格式:
{                          {
  "speaker": "Guard",        "id": "node_001",
  "text": "Halt\!",           "speaker": "guard_captain",
  "emotion": "angry",        "text": "站住！报上名来！",
  "choices": [...]           "emotion": "angry",
}                            "choices": [...],
                             "conditions": { "quest_active": "main_01" },
                             "actions": [{ "type": "set_flag", ... }]
                           }
```

---

## 2. QuestForge 模块的研究基础

### 2.1 任务生成研究

| HF 项目 | 类型 | 与本模块的关系 |
|---------|------|---------------|
| `TextQuests Benchmark` | Benchmark | 文本冒险游戏任务基准测试，定义了任务复杂度评估维度 |
| `game-quest-generator` | Space/Demo | 基于 LLM 的任务生成演示，展示了任务链生成的 prompt 工程 |
| `RPG-datasets` | Dataset | RPG 游戏数据集，包含任务-奖励-前置条件的结构化数据 |

### 2.2 关键设计决策来源

1. **任务结构模型**
   - TextQuests 定义了任务的核心要素：目标、障碍、奖励、前置条件
   - 本 Skill 采用类似结构，增加了 UrhoX 特有的：
     - `objectives[]` 带进度追踪（`current`/`required` 计数器）
     - `rewards[]` 映射到游戏系统（经验值、物品、解锁）
     - `prerequisites[]` 支持复合条件（任务完成 AND 等级达标 AND 物品持有）

2. **任务链 vs 独立任务**
   - HF 研究显示任务链（quest chain）能显著提升玩家留存
   - 本 Skill 通过 `prerequisites` 字段实现任务链：
     - 主线任务串联：`main_01` → `main_02` → `main_03`
     - 支线任务分支：完成 `main_01` 后解锁 `side_01a` 和 `side_01b`
     - 汇聚节点：`side_01a` + `side_01b` 共同解锁 `main_02`

3. **目标类型分类**
   - 基于 RPG 数据集分析，常见目标类型：
     - `kill` — 击败指定数量的敌人
     - `collect` — 收集指定物品
     - `talk` — 与 NPC 对话
     - `explore` — 到达指定地点
     - `escort` — 护送 NPC
   - 本 Skill 将这些作为 `type` 枚举值内置

---

## 3. ItemLoreForge 模块的研究基础

### 3.1 物品描述生成研究

| HF 项目 | 类型 | 与本模块的关系 |
|---------|------|---------------|
| `Game-Items-Generator` | Space | 游戏物品生成器，展示了 AI 生成物品属性+描述的流程 |
| `dnd-items-dataset` | Dataset | D&D 物品数据集，提供了稀有度-属性-背景故事的关联模式 |
| `weapon-description-gen` | Model | 武器描述生成模型，展示了风格一致性控制技术 |

### 3.2 关键设计决策来源

1. **稀有度系统**
   - D&D 数据集的稀有度分级（Common → Legendary）被广泛采用
   - 本 Skill 使用五级制：`common` / `uncommon` / `rare` / `epic` / `legendary`
   - 每个级别关联不同的描述风格指导词：
     - common: 朴素、实用、日常
     - legendary: 史诗、神秘、传奇色彩

2. **描述模板化**
   - Game-Items-Generator 展示了模板+变量的生成方式
   - 本 Skill 提供 prompt 模板，让 Claude 生成时保持风格一致
   - 每个物品包含：`name`、`description`（短描述）、`lore`（背景故事）、`flavor_text`（风味文字）

3. **批量生成与一致性**
   - HF 社区经验：单次生成多个物品比逐个生成更能保持风格一致
   - 本 Skill 推荐批量生成（8-12 个/批次），并在 prompt 中明确风格锚点

---

## 4. NarrativeEventBinder 模块的研究基础

### 4.1 叙事-场景绑定研究

| HF 项目 | 类型 | 与本模块的关系 |
|---------|------|---------------|
| `narrative-to-scene` | Pipeline | 叙事到场景的转换管线，展示了文本事件触发视觉变化的架构 |
| `interactive-fiction` | Dataset | 互动小说数据集，展示了事件触发条件的多样性 |
| `story-graph` | Research | 故事图谱研究，展示了叙事事件的有向图建模 |

### 4.2 关键设计决策来源

1. **事件触发模型**
   - 基于 interactive-fiction 数据集的触发条件分类：
     - `on_enter_area` — 进入区域触发
     - `on_quest_complete` — 完成任务触发
     - `on_item_acquire` — 获得物品触发
     - `on_npc_talk` — 与 NPC 对话触发
     - `on_time_elapsed` — 时间流逝触发
     - `on_flag_set` — 标志位设置触发

2. **叙事层次**
   - story-graph 研究将叙事分为章节（chapter）→ 事件（event）→ 动作（action）
   - 本 Skill 采用类似层次：
     - `chapters[]` — 叙事章节，包含多个事件
     - `events[]` — 具体事件，包含触发条件和动作列表
     - `actions[]` — 原子动作（对话、过场、奖励、传送等）

---

## 5. ContentValidator 模块的设计理据

### 5.1 为什么需要验证

HF 社区经验表明，AI 生成的游戏内容常见以下问题：

| 问题类型 | 发生频率 | 验证方法 |
|---------|---------|---------|
| 对话节点引用不存在的 ID | 高 | 检查所有 `next`/`choices[].next` 指向有效节点 |
| 孤立节点（不可达） | 中 | 从 `start` 遍历可达节点，报告不可达节点 |
| 空文本或占位符残留 | 中 | 检查 `text` 字段非空且不含 `[TODO]`/`[PLACEHOLDER]` |
| 任务目标 ID 重复 | 低 | 检查同一任务内 `objectives[].id` 唯一 |
| 物品稀有度不在枚举范围 | 低 | 检查 `rarity` 在五级制范围内 |
| 奖励引用不存在的物品 | 中 | 交叉验证物品 ID 存在性 |

### 5.2 验证时机

```
AI 生成 JSON → ContentValidator 验证 → 修复问题 → 转换为 Lua data table → 构建
```

验证在**构建前**执行，确保数据完整性。

---

## 6. 未采纳的 HF 研究方向

以下 HF 研究方向经评估后未纳入本 Skill，记录原因供参考：

| 研究方向 | 未采纳原因 |
|---------|-----------|
| Runtime LLM NPC 对话 | UrhoX 运行时无 LLM 推理能力；已有 `llm-server-http` skill 覆盖 |
| AI 语音合成（TTS） | 已有 `cinematic-dub-pipeline` skill 完整覆盖 |
| 程序化关卡生成 | 已有 `procedural-generation` skill 覆盖几何/地形生成 |
| AI 图像生成 | 引擎内置 `generate_image` MCP 工具已覆盖 |
| 情感分析/NLP | 运行时复杂度过高，不适合游戏客户端 |

---

## 7. 参考链接说明

> **注意**：本文档中提到的 HF 项目名称基于 2024-2025 年的 Hugging Face 社区调研。
> 具体项目可能已更新、迁移或下线。本 Skill 提取的是**设计模式和数据格式标准**，
> 而非依赖特定模型或数据集的运行时调用。
>
> 所有内容生成均通过 Claude（构建时 AI 辅助）完成，不需要访问 HF 模型。
