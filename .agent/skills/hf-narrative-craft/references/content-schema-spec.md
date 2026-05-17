# Content Schema Spec — JSON/Lua 数据格式完整规范

> 本文档定义 hf-narrative-craft 五大模块的完整数据格式规范。
> AI 生成内容时必须严格遵循这些 Schema，ContentValidator 基于此进行验证。

---

## 1. 通用约定

### 1.1 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 文件名 | `snake_case.json` / `snake_case.lua` | `main_quest_01.json` |
| ID 字段 | `snake_case`，模块前缀 | `dlg_guard_01`、`quest_main_01` |
| 枚举值 | `snake_case` 小写 | `common`、`on_enter_area` |
| 显示文本 | 原始字符串 | `"欢迎来到王城！"` |

### 1.2 ID 前缀约定

| 模块 | 前缀 | 示例 |
|------|------|------|
| DialogueForge | `dlg_` | `dlg_blacksmith_greeting` |
| QuestForge | `quest_` | `quest_main_01` |
| ItemLoreForge | `item_` | `item_iron_sword` |
| NarrativeEvent | `evt_` | `evt_chapter1_intro` |

### 1.3 文件存放路径

```
scripts/
└── data/
    ├── dialogues/          -- 对话数据
    │   ├── npc_guard.lua
    │   └── npc_merchant.lua
    ├── quests/             -- 任务数据
    │   ├── main_chapter1.lua
    │   └── side_quests.lua
    ├── items/              -- 物品数据
    │   ├── weapons.lua
    │   ├── armors.lua
    │   └── consumables.lua
    └── events/             -- 叙事事件数据
        ├── chapter1.lua
        └── chapter2.lua
```

---

## 2. DialogueForge — 对话数据 Schema

### 2.1 JSON 源格式（AI 生成用）

```json
{
  "$schema": "dialogue-v1",
  "id": "dlg_guard_greeting",
  "metadata": {
    "speaker_id": "guard_captain",
    "speaker_name": "卫队长",
    "location": "城门口",
    "context": "玩家首次接近城门时触发"
  },
  "start_node": "node_001",
  "nodes": {
    "node_001": {
      "speaker": "guard_captain",
      "text": "站住！什么人？报上名来。",
      "emotion": "serious",
      "choices": [
        {
          "text": "我是冒险者，前来寻找工作。",
          "next": "node_002",
          "conditions": null
        },
        {
          "text": "（出示通行证）",
          "next": "node_003",
          "conditions": { "has_item": "item_pass" }
        },
        {
          "text": "关你什么事？让开！",
          "next": "node_004",
          "conditions": null
        }
      ],
      "actions": []
    },
    "node_002": {
      "speaker": "guard_captain",
      "text": "冒险者？城里最近确实不太平……去找旅馆老板谈谈吧。",
      "emotion": "thoughtful",
      "choices": [],
      "actions": [
        { "type": "set_flag", "key": "guard_met", "value": true },
        { "type": "unlock_area", "area": "city_inner" }
      ]
    },
    "node_003": {
      "speaker": "guard_captain",
      "text": "通行证确认无误。请进吧，注意安全。",
      "emotion": "neutral",
      "choices": [],
      "actions": [
        { "type": "remove_item", "item": "item_pass" },
        { "type": "unlock_area", "area": "city_inner" },
        { "type": "set_flag", "key": "used_pass", "value": true }
      ]
    },
    "node_004": {
      "speaker": "guard_captain",
      "text": "好大的胆子！给我拿下！",
      "emotion": "angry",
      "choices": [],
      "actions": [
        { "type": "start_combat", "enemy_group": "city_guards" },
        { "type": "set_flag", "key": "hostile_to_city", "value": true }
      ]
    }
  }
}
```

### 2.2 字段定义

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `$schema` | string | 是 | 固定 `"dialogue-v1"` |
| `id` | string | 是 | 唯一标识，`dlg_` 前缀 |
| `metadata.speaker_id` | string | 是 | NPC 标识符 |
| `metadata.speaker_name` | string | 是 | 显示名称 |
| `metadata.location` | string | 否 | 发生地点 |
| `metadata.context` | string | 否 | 触发上下文描述 |
| `start_node` | string | 是 | 起始节点 ID |
| `nodes` | object | 是 | 节点字典 |

**节点字段**：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `speaker` | string | 是 | 说话者 ID |
| `text` | string | 是 | 对话文本，不可为空 |
| `emotion` | string | 否 | 情感标注 |
| `choices` | array | 是 | 选项列表，空数组表示对话结束 |
| `actions` | array | 否 | 触发动作列表 |

**情感枚举值**：

```
neutral, happy, sad, angry, surprised, scared,
thoughtful, serious, excited, embarrassed,
sarcastic, mysterious, tired, determined
```

**动作类型枚举**：

| type | 必填参数 | 说明 |
|------|---------|------|
| `set_flag` | `key`, `value` | 设置游戏标志位 |
| `remove_item` | `item` | 移除玩家物品 |
| `give_item` | `item`, `count` | 给予玩家物品 |
| `unlock_area` | `area` | 解锁区域 |
| `start_combat` | `enemy_group` | 开始战斗 |
| `start_quest` | `quest_id` | 激活任务 |
| `play_sound` | `sound` | 播放音效 |
| `camera_shake` | `intensity`, `duration` | 相机震动 |

### 2.3 Lua Data Table 格式（运行时）

```lua
-- scripts/data/dialogues/npc_guard.lua
local M = {}

M.dlg_guard_greeting = {
    id = "dlg_guard_greeting",
    metadata = {
        speaker_id = "guard_captain",
        speaker_name = "卫队长",
    },
    start_node = "node_001",
    nodes = {
        node_001 = {
            speaker = "guard_captain",
            text = "站住！什么人？报上名来。",
            emotion = "serious",
            choices = {
                { text = "我是冒险者，前来寻找工作。", next = "node_002" },
                { text = "（出示通行证）", next = "node_003",
                  conditions = { has_item = "item_pass" } },
                { text = "关你什么事？让开！", next = "node_004" },
            },
            actions = {},
        },
        -- ... 其他节点
    },
}

return M
```

---

## 3. QuestForge — 任务数据 Schema

### 3.1 JSON 源格式

```json
{
  "$schema": "quest-v1",
  "id": "quest_main_01",
  "title": "初来乍到",
  "description": "前往城内旅馆，与老板交谈了解当地情况。",
  "type": "main",
  "level_requirement": 1,
  "prerequisites": [],
  "objectives": [
    {
      "id": "obj_talk_innkeeper",
      "type": "talk",
      "description": "与旅馆老板交谈",
      "target": "npc_innkeeper",
      "required": 1
    },
    {
      "id": "obj_explore_market",
      "type": "explore",
      "description": "探索市场区域",
      "target": "area_market",
      "required": 1
    }
  ],
  "rewards": [
    { "type": "exp", "amount": 100 },
    { "type": "gold", "amount": 50 },
    { "type": "item", "item_id": "item_basic_sword", "count": 1 }
  ],
  "on_complete_dialogue": "dlg_innkeeper_quest_done",
  "next_quests": ["quest_main_02"],
  "time_limit": null,
  "repeatable": false
}
```

### 3.2 字段定义

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `$schema` | string | 是 | 固定 `"quest-v1"` |
| `id` | string | 是 | 唯一标识，`quest_` 前缀 |
| `title` | string | 是 | 任务标题 |
| `description` | string | 是 | 任务描述 |
| `type` | enum | 是 | `main` / `side` / `daily` / `hidden` |
| `level_requirement` | number | 否 | 最低等级要求，默认 1 |
| `prerequisites` | array | 是 | 前置任务 ID 列表，空数组表示无前置 |
| `objectives` | array | 是 | 目标列表，至少 1 个 |
| `rewards` | array | 是 | 奖励列表 |
| `on_complete_dialogue` | string | 否 | 完成时触发的对话 ID |
| `next_quests` | array | 否 | 后续解锁的任务 ID 列表 |
| `time_limit` | number | 否 | 时间限制（秒），null 表示无限制 |
| `repeatable` | boolean | 否 | 是否可重复，默认 false |

**目标类型枚举**：

| type | target 含义 | 说明 |
|------|------------|------|
| `kill` | 敌人 ID | 击败指定敌人 |
| `collect` | 物品 ID | 收集指定物品 |
| `talk` | NPC ID | 与 NPC 对话 |
| `explore` | 区域 ID | 到达指定区域 |
| `escort` | NPC ID | 护送 NPC |
| `interact` | 对象 ID | 与场景对象交互 |
| `survive` | 无 | 存活指定时间 |

**奖励类型枚举**：

| type | 必填参数 | 说明 |
|------|---------|------|
| `exp` | `amount` | 经验值 |
| `gold` | `amount` | 金币 |
| `item` | `item_id`, `count` | 物品 |
| `unlock` | `target` | 解锁功能/区域 |
| `reputation` | `faction`, `amount` | 声望值 |

### 3.3 Lua Data Table 格式

```lua
-- scripts/data/quests/main_chapter1.lua
local M = {}

M.quest_main_01 = {
    id = "quest_main_01",
    title = "初来乍到",
    description = "前往城内旅馆，与老板交谈了解当地情况。",
    type = "main",
    prerequisites = {},
    objectives = {
        { id = "obj_talk_innkeeper", type = "talk",
          description = "与旅馆老板交谈", target = "npc_innkeeper", required = 1 },
        { id = "obj_explore_market", type = "explore",
          description = "探索市场区域", target = "area_market", required = 1 },
    },
    rewards = {
        { type = "exp", amount = 100 },
        { type = "gold", amount = 50 },
        { type = "item", item_id = "item_basic_sword", count = 1 },
    },
    on_complete_dialogue = "dlg_innkeeper_quest_done",
    next_quests = { "quest_main_02" },
    repeatable = false,
}

return M
```

---

## 4. ItemLoreForge — 物品数据 Schema

### 4.1 JSON 源格式

```json
{
  "$schema": "item-v1",
  "id": "item_iron_sword",
  "name": "铁剑",
  "category": "weapon",
  "sub_category": "sword",
  "rarity": "common",
  "level": 1,
  "description": "一把标准的铁制长剑，刃口锋利，适合初出茅庐的冒险者。",
  "lore": "铁匠铺最畅销的武器，几乎每个踏上冒险之路的新人都会买上一把。",
  "flavor_text": "\"千里之行，始于足下。\" —— 城门口的老铁匠",
  "stats": {
    "attack": 10,
    "durability": 100
  },
  "tags": ["melee", "one_handed", "metal"],
  "sell_price": 25,
  "stackable": false,
  "max_stack": 1
}
```

### 4.2 字段定义

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `$schema` | string | 是 | 固定 `"item-v1"` |
| `id` | string | 是 | 唯一标识，`item_` 前缀 |
| `name` | string | 是 | 物品名称 |
| `category` | enum | 是 | 主类别 |
| `sub_category` | string | 否 | 子类别 |
| `rarity` | enum | 是 | 稀有度（见下方） |
| `level` | number | 否 | 最低使用等级，默认 1 |
| `description` | string | 是 | 简短描述（50 字以内） |
| `lore` | string | 否 | 背景故事（100 字以内） |
| `flavor_text` | string | 否 | 风味文字（引用格式） |
| `stats` | object | 否 | 属性键值对 |
| `tags` | array | 否 | 标签列表 |
| `sell_price` | number | 否 | 售卖价格 |
| `stackable` | boolean | 否 | 是否可堆叠 |
| `max_stack` | number | 否 | 最大堆叠数 |

**稀有度枚举**：

| 值 | 显示颜色 | 说明 |
|----|---------|------|
| `common` | 白色 (255,255,255) | 普通 |
| `uncommon` | 绿色 (30,255,30) | 优秀 |
| `rare` | 蓝色 (30,144,255) | 稀有 |
| `epic` | 紫色 (163,53,238) | 史诗 |
| `legendary` | 橙色 (255,165,0) | 传说 |

**主类别枚举**：

```
weapon, armor, accessory, consumable, material, quest_item, misc
```

### 4.3 Lua Data Table 格式

```lua
-- scripts/data/items/weapons.lua
local M = {}

M.item_iron_sword = {
    id = "item_iron_sword",
    name = "铁剑",
    category = "weapon",
    sub_category = "sword",
    rarity = "common",
    level = 1,
    description = "一把标准的铁制长剑，刃口锋利。",
    lore = "铁匠铺最畅销的武器。",
    flavor_text = "\"千里之行，始于足下。\"",
    stats = { attack = 10, durability = 100 },
    tags = { "melee", "one_handed", "metal" },
    sell_price = 25,
    stackable = false,
    max_stack = 1,
}

return M
```

### 4.4 批量索引文件

当物品数量较多时，使用索引文件统一加载：

```lua
-- scripts/data/items/index.lua
local M = {}

local weapons = require("data.items.weapons")
local armors = require("data.items.armors")
local consumables = require("data.items.consumables")

-- 合并所有物品到统一字典
for k, v in pairs(weapons) do M[k] = v end
for k, v in pairs(armors) do M[k] = v end
for k, v in pairs(consumables) do M[k] = v end

return M
```

---

## 5. NarrativeEventBinder — 叙事事件 Schema

### 5.1 JSON 源格式

```json
{
  "$schema": "narrative-event-v1",
  "chapter_id": "chapter_1",
  "chapter_title": "风暴前夕",
  "events": [
    {
      "id": "evt_chapter1_intro",
      "trigger": {
        "type": "on_enter_area",
        "area": "city_gate"
      },
      "conditions": {
        "flags": { "chapter1_started": false }
      },
      "actions": [
        { "type": "dialogue", "dialogue_id": "dlg_guard_greeting" },
        { "type": "set_flag", "key": "chapter1_started", "value": true },
        { "type": "activate_quest", "quest_id": "quest_main_01" }
      ],
      "once": true
    },
    {
      "id": "evt_chapter1_market_ambush",
      "trigger": {
        "type": "on_quest_objective",
        "quest_id": "quest_main_01",
        "objective_id": "obj_explore_market"
      },
      "conditions": {},
      "actions": [
        { "type": "spawn_enemies", "group": "bandits_small", "position": "market_center" },
        { "type": "dialogue", "dialogue_id": "dlg_bandit_ambush" },
        { "type": "play_bgm", "track": "Sounds/battle_theme.ogg" }
      ],
      "once": true
    }
  ]
}
```

### 5.2 触发器类型

| type | 必填参数 | 说明 |
|------|---------|------|
| `on_enter_area` | `area` | 玩家进入指定区域 |
| `on_exit_area` | `area` | 玩家离开指定区域 |
| `on_quest_complete` | `quest_id` | 完成指定任务 |
| `on_quest_objective` | `quest_id`, `objective_id` | 完成任务的特定目标 |
| `on_item_acquire` | `item_id` | 获得指定物品 |
| `on_item_use` | `item_id` | 使用指定物品 |
| `on_npc_talk` | `npc_id` | 与指定 NPC 对话 |
| `on_combat_end` | `result` | 战斗结束（win/lose） |
| `on_level_up` | `level` | 达到指定等级 |
| `on_flag_set` | `key`, `value` | 标志位变化 |
| `on_time_elapsed` | `seconds` | 游戏内经过时间 |

### 5.3 动作类型

| type | 必填参数 | 说明 |
|------|---------|------|
| `dialogue` | `dialogue_id` | 触发对话 |
| `set_flag` | `key`, `value` | 设置标志位 |
| `activate_quest` | `quest_id` | 激活任务 |
| `complete_objective` | `quest_id`, `objective_id` | 完成任务目标 |
| `give_item` | `item_id`, `count` | 给予物品 |
| `remove_item` | `item_id`, `count` | 移除物品 |
| `spawn_enemies` | `group`, `position` | 生成敌人 |
| `play_bgm` | `track` | 播放背景音乐 |
| `play_sfx` | `sound` | 播放音效 |
| `camera_pan` | `target`, `duration` | 相机平移 |
| `screen_fade` | `color`, `duration` | 屏幕渐变 |
| `teleport_player` | `position` | 传送玩家 |
| `show_tutorial` | `text`, `highlight` | 显示教程提示 |

---

## 6. 验证规则汇总

### 6.1 通用规则

| 规则 | 检查内容 |
|------|---------|
| ID 唯一性 | 同类型数据中 ID 不重复 |
| ID 格式 | 符合前缀约定 (`dlg_`/`quest_`/`item_`/`evt_`) |
| 必填字段 | 所有标记为「必填」的字段存在且非空 |
| 枚举值 | 枚举字段值在允许范围内 |
| 文本长度 | description ≤ 50 字，lore ≤ 100 字 |

### 6.2 交叉引用规则

| 规则 | 检查内容 |
|------|---------|
| 对话节点可达 | 从 `start_node` 可达所有节点（无孤立节点） |
| 选项目标存在 | `choices[].next` 指向存在的节点 ID |
| 前置任务存在 | `prerequisites[]` 中的任务 ID 已定义 |
| 奖励物品存在 | `rewards[].item_id` 在物品数据中已定义 |
| 对话引用存在 | `on_complete_dialogue` 在对话数据中已定义 |
| 事件引用存在 | 动作中的 `dialogue_id`/`quest_id` 已定义 |

### 6.3 性能规则

| 规则 | 限制 |
|------|------|
| 单个对话树节点数 | ≤ 50 |
| 单个任务目标数 | ≤ 10 |
| 单章节事件数 | ≤ 30 |
| 物品批次数量 | ≤ 100 |
| 单次加载数据量 | ≤ 500 条记录 |
