# Generation Templates — AI 内容生成 Prompt 模板库

> 本文档提供标准化的 prompt 模板，用于指导 Claude 生成符合 hf-narrative-craft
> Schema 规范的游戏叙事内容。每个模板都经过优化，确保输出格式一致、质量可控。

---

## 1. 使用方法

### 1.1 模板调用流程

```
1. 用户描述需求（"帮我生成一组武器物品"）
2. AI 选择对应模板（ItemLoreForge 批量模板）
3. AI 根据用户描述填充模板变量
4. AI 执行模板生成 JSON 内容
5. AI 运行 ContentValidator 验证
6. AI 转换为 Lua data table
7. AI 保存到 scripts/data/ 目录
8. 调用构建工具
```

### 1.2 模板变量标记

- `{VARIABLE}` — 必填变量，由 AI 根据上下文填充
- `[OPTIONAL]` — 可选部分，可省略
- `<\!-- 注释 -->` — 模板使用说明，不输出到结果

---

## 2. DialogueForge 模板

### 2.1 单 NPC 对话树模板

**适用场景**：为单个 NPC 创建完整对话树

**模板变量**：

| 变量 | 说明 | 示例 |
|------|------|------|
| `{NPC_ID}` | NPC 标识符 | `blacksmith` |
| `{NPC_NAME}` | NPC 显示名称 | `铁匠老张` |
| `{NPC_PERSONALITY}` | 性格描述 | `老实憨厚，热心肠` |
| `{LOCATION}` | 所在地点 | `城镇铁匠铺` |
| `{CONTEXT}` | 对话情境 | `玩家首次拜访` |
| `{BRANCH_COUNT}` | 分支数量 | `3` |
| `{GAME_WORLD}` | 世界观背景 | `中世纪奇幻` |

**生成指导**：

```
请为以下 NPC 创建对话树，输出标准 JSON 格式：

NPC 信息：
- ID：{NPC_ID}
- 名称：{NPC_NAME}
- 性格：{NPC_PERSONALITY}
- 地点：{LOCATION}
- 对话情境：{CONTEXT}

要求：
1. 对话树至少 {BRANCH_COUNT} 个分支路径
2. 每个分支 3-5 个对话节点
3. 包含至少 1 个条件分支（基于玩家状态）
4. 包含至少 2 个游戏动作（set_flag、give_item 等）
5. 情感标注与对话内容匹配
6. 对话文本符合 {GAME_WORLD} 世界观
7. 所有分支最终有明确的结束节点（choices 为空数组）

JSON 格式要求：
- $schema: "dialogue-v1"
- id 前缀: "dlg_"
- 节点 ID 格式: "node_XXX"
```

### 2.2 多 NPC 批量对话模板

**适用场景**：同时为多个 NPC 创建对话

**生成指导**：

```
请为以下 NPC 批量创建对话树，每个 NPC 输出独立的 JSON：

NPC 列表：
1. {NPC_1_NAME}（{NPC_1_PERSONALITY}）— {NPC_1_CONTEXT}
2. {NPC_2_NAME}（{NPC_2_PERSONALITY}）— {NPC_2_CONTEXT}
3. {NPC_3_NAME}（{NPC_3_PERSONALITY}）— {NPC_3_CONTEXT}

共同约束：
- 世界观：{GAME_WORLD}
- 地点：{LOCATION}
- NPC 之间可以相互引用（如"去找铁匠谈谈"）
- 保持语言风格一致但性格差异明显
- 每个对话树 2-3 个分支，3-4 个节点/分支

输出格式：每个 NPC 一个完整的 dialogue-v1 JSON 对象。
```

---

## 3. QuestForge 模板

### 3.1 主线任务链模板

**适用场景**：创建一组串联的主线任务

**模板变量**：

| 变量 | 说明 | 示例 |
|------|------|------|
| `{CHAPTER_NAME}` | 章节名称 | `第一章：风暴前夕` |
| `{QUEST_COUNT}` | 任务数量 | `5` |
| `{DIFFICULTY_CURVE}` | 难度曲线 | `逐步递增` |
| `{STORY_SUMMARY}` | 章节故事梗概 | `主角抵达城镇，发现异变` |
| `{REWARD_SCALE}` | 奖励规模 | `初期低，后期高` |

**生成指导**：

```
请创建一条主线任务链，输出 JSON 数组：

章节信息：
- 章节名：{CHAPTER_NAME}
- 任务数量：{QUEST_COUNT}
- 故事梗概：{STORY_SUMMARY}

设计约束：
1. 任务按顺序串联（前一个是后一个的 prerequisite）
2. 难度曲线：{DIFFICULTY_CURVE}
3. 奖励规模：{REWARD_SCALE}
4. 每个任务 2-3 个目标
5. 至少 1 个任务包含战斗目标（kill 类型）
6. 至少 1 个任务包含探索目标（explore 类型）
7. 最后一个任务的奖励最丰厚
8. 每个任务的 on_complete_dialogue 引用对应 NPC 的对话

输出格式：quest-v1 JSON 数组，按顺序排列。
ID 格式：quest_main_{章节号}_{序号}，如 quest_main_01_01
```

### 3.2 支线任务批量模板

**适用场景**：创建一组独立或松散关联的支线任务

**生成指导**：

```
请创建一组支线任务，输出 JSON 数组：

支线信息：
- 数量：{QUEST_COUNT}
- 解锁条件：完成 {PREREQUISITE_QUEST}
- 主题：{THEME}（如"帮助城镇居民"/"探索废墟"/"猎人委托"）

设计约束：
1. 支线之间相互独立（无互相依赖）
2. 每个支线 1-2 个目标（比主线简短）
3. 奖励多样化（经验/金币/物品/声望混合）
4. 至少包含 1 个可重复任务（repeatable: true）
5. 故事与主线世界观一致但不干扰主线进程

输出格式：quest-v1 JSON 数组。
ID 格式：quest_side_{主题缩写}_{序号}
```

---

## 4. ItemLoreForge 模板

### 4.1 武器批量模板

**适用场景**：创建一系列武器，覆盖不同稀有度

**生成指导**：

```
请创建一组武器物品数据，输出 JSON 数组：

武器组信息：
- 武器类型：{WEAPON_TYPE}（如 sword/bow/staff/axe）
- 数量：{COUNT}
- 稀有度分布：common ×{N1}, uncommon ×{N2}, rare ×{N3}, epic ×{N4}, legendary ×{N5}
- 世界观：{GAME_WORLD}

设计约束：
1. 攻击力随稀有度递增（common: 8-12, uncommon: 15-20, rare: 25-35, epic: 40-55, legendary: 60-80）
2. 稀有度越高，背景故事越详尽
3. legendary 物品必须有独特的 flavor_text（引用格式）
4. 名称风格统一（{NAMING_STYLE}，如"中式武侠"/"西式奇幻"/"日式RPG"）
5. 每件武器 2-3 个标签（tags）
6. 售价与稀有度正相关

输出格式：item-v1 JSON 数组。
```

### 4.2 消耗品批量模板

**生成指导**：

```
请创建一组消耗品物品数据，输出 JSON 数组：

消耗品信息：
- 类型：{CONSUMABLE_TYPES}（如 potion/food/scroll/bomb）
- 数量：{COUNT}
- 最高稀有度：{MAX_RARITY}

设计约束：
1. 所有消耗品 stackable: true，max_stack: 99
2. category 固定为 "consumable"
3. stats 包含效果值（如 hp_restore, mp_restore, buff_duration）
4. 低稀有度消耗品描述简洁（20 字内）
5. 高稀有度消耗品有背景故事
6. 售价范围：common 5-20, uncommon 30-80, rare 100-300

输出格式：item-v1 JSON 数组。
```

---

## 5. NarrativeEventBinder 模板

### 5.1 章节事件模板

**适用场景**：为一个叙事章节创建完整的事件绑定

**生成指导**：

```
请为以下章节创建叙事事件数据，输出 JSON：

章节信息：
- 章节 ID：{CHAPTER_ID}
- 章节标题：{CHAPTER_TITLE}
- 包含的任务：{QUEST_IDS}（逗号分隔）
- 包含的对话：{DIALOGUE_IDS}（逗号分隔）
- 关键地点：{LOCATIONS}

设计约束：
1. 为每个任务的开始和完成创建事件
2. 至少 1 个区域进入触发事件
3. 至少 1 个伏击/突发事件
4. 事件按叙事逻辑排序
5. 使用 once: true 防止重复触发
6. 包含氛围动作（play_bgm、screen_fade 等）

输出格式：narrative-event-v1 JSON。
```

---

## 6. 综合模板

### 6.1 完整章节生成模板

**适用场景**：一次性生成一个章节的所有内容

**生成指导**：

```
请为以下游戏章节生成完整的叙事内容包：

游戏信息：
- 游戏类型：{GAME_GENRE}（如 RPG/ARPG/冒险）
- 世界观：{GAME_WORLD}
- 章节名：{CHAPTER_NAME}
- 故事梗概：{STORY_SUMMARY}

生成内容（按顺序）：
1. NPC 对话树 ×{NPC_COUNT}（dialogue-v1 JSON）
2. 主线任务 ×{MAIN_QUEST_COUNT}（quest-v1 JSON）
3. 支线任务 ×{SIDE_QUEST_COUNT}（quest-v1 JSON）
4. 物品数据 ×{ITEM_COUNT}（item-v1 JSON）
5. 叙事事件绑定 ×1（narrative-event-v1 JSON）

质量要求：
- 所有 ID 引用必须相互一致（对话引用存在的节点，任务奖励存在的物品）
- 对话风格符合 NPC 性格
- 任务难度和奖励符合章节进度
- 叙事事件串联所有内容为完整流程

输出格式：每种类型的数据用 --- 分隔，标注类型标题。
```

---

## 7. JSON → Lua 转换规则

AI 生成 JSON 后，按以下规则转换为 Lua data table：

### 7.1 转换对照表

| JSON | Lua |
|------|-----|
| `{ "key": value }` | `{ key = value }` |
| `[ item1, item2 ]` | `{ item1, item2 }` |
| `"string"` | `"string"` |
| `123` / `45.6` | `123` / `45.6` |
| `true` / `false` | `true` / `false` |
| `null` | `nil`（或省略该字段） |

### 7.2 文件模板

```lua
-- scripts/data/{category}/{filename}.lua
-- 由 hf-narrative-craft 生成
-- 生成时间：{TIMESTAMP}

local M = {}

M.{item_id} = {
    -- ... data fields
}

return M
```

### 7.3 索引文件模板

```lua
-- scripts/data/{category}/index.lua
-- 由 hf-narrative-craft 生成

local M = {}

local files = {
    require("data.{category}.{file1}"),
    require("data.{category}.{file2}"),
}

for _, fileData in ipairs(files) do
    for k, v in pairs(fileData) do
        M[k] = v
    end
end

return M
```

---

## 8. 验证与修复流程

### 8.1 生成后验证清单

```
生成 JSON 后，AI 必须执行以下检查：

□ 所有 ID 唯一且符合前缀约定
□ 所有必填字段已填写
□ 所有枚举值在合法范围内
□ 对话树无孤立节点
□ 选项的 next 指向存在的节点
□ 任务的 prerequisites 引用存在的任务
□ 奖励的 item_id 引用存在的物品
□ 事件的 dialogue_id/quest_id 引用存在的数据
□ 文本无占位符残留（[TODO]、[PLACEHOLDER]、{VARIABLE}）
□ Lua 转换后文件可被 require 正确加载
```

### 8.2 常见修复模式

| 问题 | 修复方法 |
|------|---------|
| 对话节点引用不存在的 ID | 创建缺失节点或修正引用 |
| 孤立节点 | 从最近的分支添加选项指向该节点 |
| 物品 ID 不存在 | 创建缺失物品或更换为已存在的物品 |
| 枚举值拼写错误 | 修正为最接近的合法枚举值 |
| 重复 ID | 给后出现的 ID 添加数字后缀 |

---

## 9. 文件保存与构建

### 9.1 保存规范

```lua
-- 生成的 Lua 数据文件保存到：
scripts/data/dialogues/   -- 对话数据
scripts/data/quests/       -- 任务数据
scripts/data/items/        -- 物品数据
scripts/data/events/       -- 叙事事件

-- 运行时模块保存到：
scripts/systems/           -- DialogueRunner, QuestManager 等
```

### 9.2 构建流程

生成数据文件后，必须调用构建工具确保文件被正确打包：

```
1. 保存 Lua 文件到 scripts/data/
2. 保存运行时模块到 scripts/systems/
3. 调用 MCP build 工具构建项目
4. 验证构建成功
```

> **重要**：所有数据文件和运行时模块都放在 `scripts/` 目录下，
> 构建工具会自动包含。不需要修改任何构建配置。
