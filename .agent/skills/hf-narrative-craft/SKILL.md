---
name: hf-narrative-craft
version: "1.0.0"
description: >
  HF-Narrative-Craft — AI 驱动的游戏叙事内容锻造管线。
  灵感来源于 Hugging Face 社区的游戏 AI 研究（Gemma3NPC、npcLM、TextQuests、
  Procedural Quest Generation 等项目），将 LLM 驱动的叙事生成理念
  适配为 UrhoX Lua 游戏的构建时内容生产工具链。
  提供 5 大内容锻造模块：DialogueForge（对话树批量生成）、
  QuestForge（任务链/支线剧情生成）、ItemLoreForge（物品/技能描述文案工厂）、
  NarrativeEventBinder（叙事事件与 Lua 回调绑定器）、
  ContentValidator（内容一致性校验与统计）。
  所有生成内容输出为结构化 JSON → Lua 数据表，可直接在游戏中 require 加载。
  支持与引擎 i18n 框架联动实现多语言叙事内容。
  Use when users need to batch-generate game narrative content including
  NPC dialogues, quest chains, item descriptions, and lore entries.
author: "UrhoX Skill Builder"
source: "https://huggingface.co/ (Game AI Research Collection)"
tags:
  - narrative
  - dialogue
  - quest
  - lore
  - procedural-content
  - AI-generation
  - NPC
  - i18n
  - text-generation
triggers:
  - "生成对话"
  - "对话树"
  - "NPC 台词"
  - "任务链"
  - "支线任务"
  - "物品描述"
  - "装备文案"
  - "技能描述"
  - "世界观文案"
  - "叙事内容"
  - "批量生成剧情"
  - "dialogue tree"
  - "quest chain"
  - "item lore"
  - "narrative content"
  - "NPC dialogue generation"
---

# HF-Narrative-Craft — AI 驱动的游戏叙事内容锻造管线

> 灵感来源：Hugging Face 社区游戏 AI 研究（Gemma3NPC、npcLM、TextQuests、
> Procedural Quest Generation、Amaydle NPC Dialogue 等项目）。
> 将 LLM 驱动的叙事生成理念适配为 UrhoX Lua 的构建时内容生产方案。

---

## 1. Use When — 何时触发

### 触发场景

| 场景 | 说明 |
|------|------|
| 用户需要为 NPC 批量生成对话内容 | 商人/村民/守卫等大量 NPC 台词 |
| 用户设计对话树/分支对话系统 | 多选项、条件跳转、好感度影响 |
| 用户需要生成任务/支线剧情 | 主线任务、支线任务链、随机任务 |
| 用户需要批量创建物品/技能描述 | 武器、防具、道具、消耗品文案 |
| 用户说"生成对话"、"对话树"、"NPC台词" | 关键词触发 |
| 用户说"任务链"、"支线任务"、"quest" | 关键词触发 |
| 用户说"物品描述"、"装备文案"、"技能描述" | 关键词触发 |
| 用户说"叙事内容"、"批量生成剧情"、"lore" | 关键词触发 |

### 不触发场景

| 场景 | 应使用的 Skill |
|------|--------------|
| NPC 运行时 AI 行为（FSM、决策树） | `gaia-npc-ai` / `behavior-tree-ai` |
| 世界观实体管理和知识图谱 | `world-lore-notebook` |
| 地形/关卡程序化生成（算法） | `procedural-generation` |
| 游戏发布文案（GDD、商店描述） | `game-content-factory` |
| 角色配音和语音合成 | `cinematic-dub-pipeline` |

---

## 2. 概念映射 — HF 研究 → UrhoX 实现

### 2.1 HF 社区游戏 AI 研究成果

| HF 项目/模型 | 核心能力 | 本 Skill 的映射 |
|-------------|---------|----------------|
| Gemma3NPC / npcLM | 实时 NPC 对话生成 | DialogueForge — 构建时批量生成对话树 |
| TextQuests Benchmark | LLM 文字冒险游戏 | QuestForge — 任务链与分支剧情生成 |
| Amaydle NPC Dialogue Dataset | 1724 条结构化 NPC 对话 | JSON 对话格式标准 |
| Procedural Quest (PCG Papers) | 程序化任务生成 | QuestForge — 模板 + 变量替换 |
| Game Items Generator Space | 物品属性与描述生成 | ItemLoreForge — 物品/技能文案工厂 |
| Narrative-to-Scene Pipeline | 叙事转场景 | NarrativeEventBinder — 文本触发游戏事件 |

### 2.2 关键设计决策

| 决策 | HF 方案 | 本 Skill 方案 | 原因 |
|------|---------|-------------|------|
| 生成时机 | 运行时 API 调用 | **构建时**批量生成 | 游戏不依赖网络，零延迟 |
| 模型依赖 | 需要 GPU 推理 | **AI 辅助**（Claude 生成） | 沙箱无 GPU，利用现有 AI 能力 |
| 数据格式 | 自定义 JSON | **标准化 JSON** → Lua 表 | 引擎原生支持 require 加载 |
| 多语言 | 单语言为主 | **i18n 框架联动** | 利用引擎 i18n_extract 工具 |
| 内容校验 | 人工审核 | **自动化校验器** | ContentValidator 检查完整性 |

### 2.3 数据流全景

```
世界观设定 (用户提供)
  ↓
AI 生成结构化内容 (Claude 根据模板和约束生成)
  ↓
┌─────────────────────────────────────────────┐
│ scripts/data/                               │
│  ├── dialogues/     → DialogueForge 输出    │
│  ├── quests/        → QuestForge 输出       │
│  ├── items/         → ItemLoreForge 输出    │
│  └── narrative/     → NarrativeEvent 输出   │
└─────────────────────────────────────────────┘
  ↓
Lua require("data.dialogues.blacksmith")  -- 游戏代码直接加载
  ↓
UI 组件渲染 (UI.Label / 对话框组件)
```

---

## 3. DialogueForge — 对话树锻造器

### 3.1 对话节点 JSON 格式

```json
{
  "dialogue_id": "blacksmith_greeting",
  "character": "铁匠老王",
  "trigger": { "type": "interact", "target": "npc_blacksmith" },
  "nodes": [
    {
      "id": "start",
      "speaker": "铁匠老王",
      "text": "哟，冒险者！需要打造点什么吗？",
      "emotion": "friendly",
      "choices": [
        {
          "text": "我想看看你的商品",
          "next": "show_shop",
          "condition": null
        },
        {
          "text": "能帮我修理装备吗？",
          "next": "repair_check",
          "condition": null
        },
        {
          "text": "你知道北边洞穴的事吗？",
          "next": "cave_rumor",
          "condition": { "quest_active": "explore_north_cave" }
        },
        {
          "text": "没什么，告辞",
          "next": "end",
          "condition": null
        }
      ]
    },
    {
      "id": "show_shop",
      "speaker": "铁匠老王",
      "text": "尽管挑！都是我亲手打造的好货。",
      "emotion": "proud",
      "action": { "type": "open_shop", "shop_id": "blacksmith_shop" },
      "choices": []
    },
    {
      "id": "repair_check",
      "speaker": "铁匠老王",
      "text": "让我看看... 嗯，这把剑还有救。修理费50金币，行吗？",
      "emotion": "thoughtful",
      "choices": [
        { "text": "好的，请修理", "next": "repair_yes", "condition": { "gold_gte": 50 } },
        { "text": "太贵了，算了", "next": "repair_no", "condition": null }
      ]
    },
    {
      "id": "cave_rumor",
      "speaker": "铁匠老王",
      "text": "[whispering] 听说那洞穴里有远古矮人的锻造炉... 如果你能带回一块陨铁，我可以打造传说级武器。",
      "emotion": "mysterious",
      "action": { "type": "update_quest", "quest_id": "explore_north_cave", "objective": "find_meteorite" },
      "choices": [
        { "text": "一定带回来！", "next": "end", "condition": null }
      ]
    },
    {
      "id": "end",
      "speaker": "铁匠老王",
      "text": "有空常来！",
      "emotion": "friendly",
      "choices": []
    }
  ]
}
```

### 3.2 Lua 数据表格式

```lua
-- scripts/data/dialogues/blacksmith.lua
-- 由 HF-Narrative-Craft 生成，请勿手动修改
-- 生成时间: 2026-05-15

return {
    dialogue_id = "blacksmith_greeting",
    character = "铁匠老王",
    trigger = { type = "interact", target = "npc_blacksmith" },
    nodes = {
        start = {
            speaker = "铁匠老王",
            text = "哟，冒险者！需要打造点什么吗？",
            emotion = "friendly",
            choices = {
                { text = "我想看看你的商品", next = "show_shop" },
                { text = "能帮我修理装备吗？", next = "repair_check" },
                {
                    text = "你知道北边洞穴的事吗？",
                    next = "cave_rumor",
                    condition = { quest_active = "explore_north_cave" },
                },
                { text = "没什么，告辞", next = "end" },
            },
        },
        show_shop = {
            speaker = "铁匠老王",
            text = "尽管挑！都是我亲手打造的好货。",
            emotion = "proud",
            action = { type = "open_shop", shop_id = "blacksmith_shop" },
        },
        -- ... 其余节点
    },
}
```

### 3.3 DialogueRunner — 对话运行器

```lua
-- scripts/systems/DialogueRunner.lua
local DialogueRunner = {}

--- 加载对话数据
---@param path string 数据路径，如 "data.dialogues.blacksmith"
---@return table dialogueData
function DialogueRunner.Load(path)
    local data = require(path)
    return data
end

--- 获取当前节点
---@param data table 对话数据
---@param nodeId string 节点ID
---@return table|nil node
function DialogueRunner.GetNode(data, nodeId)
    return data.nodes[nodeId]
end

--- 过滤可用选项（检查条件）
---@param node table 当前节点
---@param gameState table 游戏状态
---@return table availableChoices
function DialogueRunner.GetAvailableChoices(node, gameState)
    if not node.choices or #node.choices == 0 then
        return {}
    end

    local available = {}
    for i = 1, #node.choices do
        local choice = node.choices[i]
        if DialogueRunner._CheckCondition(choice.condition, gameState) then
            available[#available + 1] = {
                index = i,
                text = choice.text,
                next = choice.next,
            }
        end
    end
    return available
end

--- 执行节点动作
---@param node table 当前节点
---@param actionHandler function 动作处理回调
function DialogueRunner.ExecuteAction(node, actionHandler)
    if node.action and actionHandler then
        actionHandler(node.action)
    end
end

--- 检查条件是否满足
---@param condition table|nil
---@param gameState table
---@return boolean
function DialogueRunner._CheckCondition(condition, gameState)
    if not condition then return true end

    -- 任务激活检查
    if condition.quest_active then
        if not gameState.activeQuests or not gameState.activeQuests[condition.quest_active] then
            return false
        end
    end

    -- 金币检查
    if condition.gold_gte then
        if not gameState.gold or gameState.gold < condition.gold_gte then
            return false
        end
    end

    -- 好感度检查
    if condition.affinity_gte then
        local charAffinity = gameState.affinity and gameState.affinity[condition.affinity_char] or 0
        if charAffinity < condition.affinity_gte then
            return false
        end
    end

    -- 物品持有检查
    if condition.has_item then
        if not gameState.inventory or not gameState.inventory[condition.has_item] then
            return false
        end
    end

    return true
end

return DialogueRunner
```

### 3.4 对话 UI 集成示例

```lua
-- scripts/ui/DialogueBox.lua
local UI = require("urhox-libs/UI")

local DialogueBox = {}

--- 创建对话框 UI
---@param options table { width, onChoice }
---@return table component
function DialogueBox.Create(options)
    local width = options.width or "80%"
    local onChoice = options.onChoice

    local state = {
        visible = false,
        speakerLabel = nil,
        textLabel = nil,
        choiceContainer = nil,
        root = nil,
    }

    state.root = UI.Panel {
        width = width,
        height = "auto",
        position = "absolute",
        bottom = 20,
        left = "10%",
        backgroundColor = "rgba(0,0,0,0.85)",
        borderRadius = 12,
        padding = 16,
        display = "none",
        children = {
            -- 说话人名字
            UI.Label {
                text = "",
                fontSize = 18,
                fontWeight = "bold",
                color = "#FFD700",
                marginBottom = 8,
                ref = function(self) state.speakerLabel = self end,
            },
            -- 对话文本
            UI.Label {
                text = "",
                fontSize = 16,
                color = "#FFFFFF",
                lineHeight = 1.5,
                marginBottom = 12,
                ref = function(self) state.textLabel = self end,
            },
            -- 选项容器
            UI.Panel {
                width = "100%",
                flexDirection = "column",
                gap = 6,
                ref = function(self) state.choiceContainer = self end,
            },
        },
    }

    --- 显示对话节点
    ---@param node table 对话节点
    ---@param choices table 可用选项列表
    function state.Show(node, choices)
        state.visible = true
        state.root:SetStyle("display", "flex")
        state.speakerLabel:SetText(node.speaker or "")
        state.textLabel:SetText(node.text or "")

        -- 清空旧选项
        state.choiceContainer:RemoveAllChildren()

        -- 添加新选项
        if choices and #choices > 0 then
            for i = 1, #choices do
                local c = choices[i]
                local btn = UI.Button {
                    text = c.text,
                    variant = "ghost",
                    textColor = "#AADDFF",
                    fontSize = 15,
                    width = "100%",
                    textAlign = "left",
                    onClick = function()
                        if onChoice then onChoice(c) end
                    end,
                }
                state.choiceContainer:AddChild(btn)
            end
        else
            -- 无选项时显示"继续"
            local btn = UI.Button {
                text = "[点击继续]",
                variant = "ghost",
                textColor = "#888888",
                fontSize = 14,
                onClick = function()
                    state.Hide()
                    if onChoice then onChoice(nil) end
                end,
            }
            state.choiceContainer:AddChild(btn)
        end
    end

    --- 隐藏对话框
    function state.Hide()
        state.visible = false
        state.root:SetStyle("display", "none")
    end

    return state
end

return DialogueBox
```

---

## 4. QuestForge — 任务链锻造器

### 4.1 任务 JSON 格式

```json
{
  "quest_id": "explore_north_cave",
  "title": "北方洞穴探险",
  "type": "main",
  "description": "铁匠老王提到北方洞穴中藏有远古矮人的锻造炉和珍贵的陨铁矿石。前去探索，为老王带回陨铁。",
  "giver": "npc_blacksmith",
  "level_requirement": 5,
  "prerequisites": [],
  "objectives": [
    {
      "id": "reach_cave",
      "type": "reach_location",
      "description": "前往北方洞穴入口",
      "target": "north_cave_entrance",
      "required": true
    },
    {
      "id": "defeat_guardian",
      "type": "defeat_enemy",
      "description": "击败洞穴守卫（石像鬼 x3）",
      "target": "stone_gargoyle",
      "count": 3,
      "required": true
    },
    {
      "id": "find_meteorite",
      "type": "collect_item",
      "description": "在锻造炉旁找到陨铁矿石",
      "target": "meteorite_ore",
      "count": 1,
      "required": true
    },
    {
      "id": "find_blueprint",
      "type": "collect_item",
      "description": "（可选）找到矮人锻造图纸",
      "target": "dwarf_blueprint",
      "count": 1,
      "required": false
    }
  ],
  "rewards": {
    "experience": 500,
    "gold": 200,
    "items": [
      { "id": "legendary_sword", "condition": "find_blueprint_completed" },
      { "id": "epic_sword", "condition": "find_blueprint_not_completed" }
    ]
  },
  "on_complete": {
    "unlock_quests": ["forge_legendary_weapon"],
    "dialogue_unlock": "blacksmith_post_cave"
  },
  "failure_conditions": [
    { "type": "player_death", "action": "reset_to_checkpoint" }
  ]
}
```

### 4.2 Lua 数据表格式

```lua
-- scripts/data/quests/explore_north_cave.lua
return {
    quest_id = "explore_north_cave",
    title = "北方洞穴探险",
    type = "main",
    description = "铁匠老王提到北方洞穴中藏有远古矮人的锻造炉...",
    giver = "npc_blacksmith",
    level_requirement = 5,
    prerequisites = {},
    objectives = {
        {
            id = "reach_cave",
            type = "reach_location",
            description = "前往北方洞穴入口",
            target = "north_cave_entrance",
            required = true,
        },
        {
            id = "defeat_guardian",
            type = "defeat_enemy",
            description = "击败洞穴守卫（石像鬼 x3）",
            target = "stone_gargoyle",
            count = 3,
            required = true,
        },
        {
            id = "find_meteorite",
            type = "collect_item",
            description = "在锻造炉旁找到陨铁矿石",
            target = "meteorite_ore",
            count = 1,
            required = true,
        },
        {
            id = "find_blueprint",
            type = "collect_item",
            description = "（可选）找到矮人锻造图纸",
            target = "dwarf_blueprint",
            count = 1,
            required = false,
        },
    },
    rewards = {
        experience = 500,
        gold = 200,
        items = {
            { id = "legendary_sword", condition = "find_blueprint_completed" },
            { id = "epic_sword", condition = "find_blueprint_not_completed" },
        },
    },
    on_complete = {
        unlock_quests = { "forge_legendary_weapon" },
        dialogue_unlock = "blacksmith_post_cave",
    },
}
```

### 4.3 QuestManager — 任务管理器

```lua
-- scripts/systems/QuestManager.lua
local cjson = require("cjson")

local QuestManager = {}
QuestManager.__index = QuestManager

--- 创建任务管理器
---@return table manager
function QuestManager.New()
    local self = setmetatable({}, QuestManager)
    self.quests = {}          -- quest_id → quest data
    self.activeQuests = {}    -- quest_id → progress
    self.completedQuests = {} -- quest_id → true
    return self
end

--- 注册任务数据
---@param path string Lua 数据路径
function QuestManager:Register(path)
    local data = require(path)
    self.quests[data.quest_id] = data
end

--- 批量注册
---@param paths table 路径列表
function QuestManager:RegisterBatch(paths)
    for i = 1, #paths do
        self:Register(paths[i])
    end
end

--- 激活任务
---@param questId string
---@param gameState table
---@return boolean success
---@return string|nil errorMsg
function QuestManager:Activate(questId, gameState)
    local quest = self.quests[questId]
    if not quest then return false, "Quest not found: " .. questId end
    if self.activeQuests[questId] then return false, "Quest already active" end
    if self.completedQuests[questId] then return false, "Quest already completed" end

    -- 检查前置条件
    for _, prereq in ipairs(quest.prerequisites or {}) do
        if not self.completedQuests[prereq] then
            return false, "Prerequisite not met: " .. prereq
        end
    end

    -- 检查等级
    if quest.level_requirement and (gameState.level or 1) < quest.level_requirement then
        return false, "Level too low"
    end

    -- 初始化进度
    local progress = {}
    for _, obj in ipairs(quest.objectives) do
        progress[obj.id] = { current = 0, target = obj.count or 1, completed = false }
    end
    self.activeQuests[questId] = { progress = progress, started_at = os.clock() }
    return true
end

--- 更新任务目标进度
---@param questId string
---@param objectiveId string
---@param amount number 增加量
---@return boolean objectiveCompleted
function QuestManager:UpdateObjective(questId, objectiveId, amount)
    local active = self.activeQuests[questId]
    if not active then return false end

    local prog = active.progress[objectiveId]
    if not prog or prog.completed then return false end

    prog.current = math.min(prog.current + (amount or 1), prog.target)
    if prog.current >= prog.target then
        prog.completed = true
        return true
    end
    return false
end

--- 检查任务是否可完成
---@param questId string
---@return boolean
function QuestManager:CanComplete(questId)
    local active = self.activeQuests[questId]
    if not active then return false end
    local quest = self.quests[questId]

    for _, obj in ipairs(quest.objectives) do
        if obj.required and not active.progress[obj.id].completed then
            return false
        end
    end
    return true
end

--- 完成任务
---@param questId string
---@return table|nil rewards
function QuestManager:Complete(questId)
    if not self:CanComplete(questId) then return nil end

    local quest = self.quests[questId]
    self.completedQuests[questId] = true
    self.activeQuests[questId] = nil

    -- 解锁后续任务
    if quest.on_complete and quest.on_complete.unlock_quests then
        -- 由调用方处理解锁逻辑
    end

    return quest.rewards
end

--- 获取所有活跃任务摘要
---@return table summaries
function QuestManager:GetActiveSummaries()
    local result = {}
    for qid, active in pairs(self.activeQuests) do
        local quest = self.quests[qid]
        local objectives = {}
        for _, obj in ipairs(quest.objectives) do
            local prog = active.progress[obj.id]
            objectives[#objectives + 1] = {
                description = obj.description,
                current = prog.current,
                target = prog.target,
                completed = prog.completed,
                required = obj.required,
            }
        end
        result[#result + 1] = {
            quest_id = qid,
            title = quest.title,
            type = quest.type,
            objectives = objectives,
        }
    end
    return result
end

--- 保存进度为 JSON 字符串
---@return string jsonStr
function QuestManager:SaveToJSON()
    local saveData = {
        active = {},
        completed = {},
    }
    for qid, data in pairs(self.activeQuests) do
        saveData.active[qid] = data
    end
    for qid, _ in pairs(self.completedQuests) do
        saveData.completed[#saveData.completed + 1] = qid
    end
    return cjson.encode(saveData)
end

--- 从 JSON 字符串恢复进度
---@param jsonStr string
function QuestManager:LoadFromJSON(jsonStr)
    local saveData = cjson.decode(jsonStr)
    self.activeQuests = saveData.active or {}
    self.completedQuests = {}
    for _, qid in ipairs(saveData.completed or {}) do
        self.completedQuests[qid] = true
    end
end

return QuestManager
```

---

## 5. ItemLoreForge — 物品/技能文案工厂

### 5.1 物品 JSON 格式

```json
{
  "item_id": "legendary_sword_stormbreaker",
  "name": "碎风者",
  "rarity": "legendary",
  "type": "weapon",
  "subtype": "sword",
  "level": 30,
  "description": "由陨铁锻造的传说之剑，剑身环绕着不息的风暴之力。据说这把剑的前任主人是风暴巨人的国王。",
  "flavor_text": "「当碎风者出鞘，连天空都会颤抖。」—— 矮人锻造师格林的笔记",
  "stats": {
    "attack": 450,
    "attack_speed": 1.2,
    "critical_rate": 0.15
  },
  "special_effects": [
    {
      "name": "风暴之怒",
      "description": "攻击时有20%概率释放风暴斩击，对周围3米内的敌人造成150%攻击力的范围伤害。",
      "trigger": "on_hit",
      "chance": 0.2,
      "damage_multiplier": 1.5,
      "aoe_radius": 3.0
    }
  ],
  "lore_category": "ancient_dwarf",
  "obtain_method": "complete_quest:forge_legendary_weapon"
}
```

### 5.2 Lua 数据表格式

```lua
-- scripts/data/items/legendary_sword_stormbreaker.lua
return {
    item_id = "legendary_sword_stormbreaker",
    name = "碎风者",
    rarity = "legendary",
    type = "weapon",
    subtype = "sword",
    level = 30,
    description = "由陨铁锻造的传说之剑，剑身环绕着不息的风暴之力。"
        .. "据说这把剑的前任主人是风暴巨人的国王。",
    flavor_text = "「当碎风者出鞘，连天空都会颤抖。」—— 矮人锻造师格林的笔记",
    stats = {
        attack = 450,
        attack_speed = 1.2,
        critical_rate = 0.15,
    },
    special_effects = {
        {
            name = "风暴之怒",
            description = "攻击时有20%概率释放风暴斩击，"
                .. "对周围3米内的敌人造成150%攻击力的范围伤害。",
            trigger = "on_hit",
            chance = 0.2,
            damage_multiplier = 1.5,
            aoe_radius = 3.0,
        },
    },
    lore_category = "ancient_dwarf",
    obtain_method = "complete_quest:forge_legendary_weapon",
}
```

### 5.3 批量物品索引

```lua
-- scripts/data/items/index.lua
-- 物品索引：统一注册所有物品数据
return {
    -- 武器
    weapons = {
        require("data.items.legendary_sword_stormbreaker"),
        require("data.items.epic_bow_windwalker"),
        require("data.items.rare_staff_frostbite"),
    },
    -- 防具
    armor = {
        require("data.items.epic_chestplate_ironwall"),
        require("data.items.rare_helmet_hawkeye"),
    },
    -- 消耗品
    consumables = {
        require("data.items.common_potion_health_small"),
        require("data.items.uncommon_potion_mana_medium"),
        require("data.items.rare_elixir_phoenix"),
    },
}
```

---

## 6. NarrativeEventBinder — 叙事事件绑定器

### 6.1 叙事事件格式

```lua
-- scripts/data/narrative/chapter1_events.lua
return {
    chapter = "chapter_1",
    title = "风暴前夕",
    events = {
        {
            id = "cave_entrance_reveal",
            trigger = {
                type = "quest_objective_complete",
                quest_id = "explore_north_cave",
                objective_id = "reach_cave",
            },
            actions = {
                { type = "camera_shake", intensity = 0.3, duration = 1.0 },
                { type = "play_sfx", path = "Audio/SFX/cave_rumble.ogg" },
                {
                    type = "show_dialogue",
                    dialogue_path = "data.dialogues.cave_entrance_narration",
                },
                { type = "set_flag", key = "cave_entered", value = true },
            },
        },
        {
            id = "guardian_defeated_cutscene",
            trigger = {
                type = "quest_objective_complete",
                quest_id = "explore_north_cave",
                objective_id = "defeat_guardian",
            },
            actions = {
                { type = "play_bgm", path = "Audio/BGM/victory_fanfare.ogg", fade_in = 1.0 },
                {
                    type = "show_dialogue",
                    dialogue_path = "data.dialogues.guardian_defeated",
                },
                { type = "spawn_item", item_id = "meteorite_ore", position = { 0, 0.5, 10 } },
            },
        },
    },
}
```

### 6.2 NarrativeEventSystem — Lua 运行时

```lua
-- scripts/systems/NarrativeEventSystem.lua
local NarrativeEventSystem = {}
NarrativeEventSystem.__index = NarrativeEventSystem

function NarrativeEventSystem.New()
    local self = setmetatable({}, NarrativeEventSystem)
    self.events = {}         -- 所有已注册事件
    self.firedEvents = {}    -- 已触发事件（防重复）
    self.actionHandlers = {} -- 动作处理器注册表
    return self
end

--- 注册叙事章节数据
function NarrativeEventSystem:RegisterChapter(path)
    local chapter = require(path)
    for _, event in ipairs(chapter.events) do
        self.events[event.id] = event
    end
end

--- 注册动作处理器
---@param actionType string 如 "camera_shake", "play_sfx"
---@param handler function(action) 处理函数
function NarrativeEventSystem:RegisterActionHandler(actionType, handler)
    self.actionHandlers[actionType] = handler
end

--- 检查并触发事件
---@param triggerType string 触发类型
---@param triggerData table 触发数据
function NarrativeEventSystem:CheckTriggers(triggerType, triggerData)
    for eventId, event in pairs(self.events) do
        if not self.firedEvents[eventId] then
            if self:_MatchTrigger(event.trigger, triggerType, triggerData) then
                self:_FireEvent(eventId, event)
            end
        end
    end
end

function NarrativeEventSystem:_MatchTrigger(trigger, triggerType, triggerData)
    if trigger.type ~= triggerType then return false end

    if triggerType == "quest_objective_complete" then
        return trigger.quest_id == triggerData.quest_id
            and trigger.objective_id == triggerData.objective_id
    elseif triggerType == "enter_area" then
        return trigger.area_id == triggerData.area_id
    elseif triggerType == "flag_set" then
        return trigger.key == triggerData.key
    end

    return false
end

function NarrativeEventSystem:_FireEvent(eventId, event)
    self.firedEvents[eventId] = true
    for _, action in ipairs(event.actions) do
        local handler = self.actionHandlers[action.type]
        if handler then
            handler(action)
        else
            log:Write(LOG_WARNING,
                "NarrativeEvent: No handler for action type: " .. action.type)
        end
    end
end

--- 保存已触发事件状态
---@return table stateData
function NarrativeEventSystem:SaveState()
    local fired = {}
    for k, _ in pairs(self.firedEvents) do
        fired[#fired + 1] = k
    end
    return { firedEvents = fired }
end

--- 恢复已触发事件状态
---@param stateData table
function NarrativeEventSystem:LoadState(stateData)
    self.firedEvents = {}
    if stateData and stateData.firedEvents then
        for _, k in ipairs(stateData.firedEvents) do
            self.firedEvents[k] = true
        end
    end
end

return NarrativeEventSystem
```

---

## 7. ContentValidator — 内容校验器

### 7.1 校验规则

```lua
-- scripts/tools/ContentValidator.lua
local ContentValidator = {}

--- 校验对话数据
---@param data table 对话数据
---@return table results { valid, errors, warnings }
function ContentValidator.ValidateDialogue(data)
    local errors = {}
    local warnings = {}

    -- 必须有 dialogue_id
    if not data.dialogue_id then
        errors[#errors + 1] = "缺少 dialogue_id"
    end

    -- 必须有 nodes
    if not data.nodes then
        errors[#errors + 1] = "缺少 nodes"
        return { valid = false, errors = errors, warnings = warnings }
    end

    -- 必须有 start 节点
    if not data.nodes.start then
        errors[#errors + 1] = "缺少 start 节点"
    end

    -- 检查所有引用的 next 节点是否存在
    local allNodeIds = {}
    for nodeId, _ in pairs(data.nodes) do
        allNodeIds[nodeId] = true
    end

    for nodeId, node in pairs(data.nodes) do
        if node.choices then
            for i, choice in ipairs(node.choices) do
                if choice.next and not allNodeIds[choice.next] then
                    errors[#errors + 1] = string.format(
                        "节点 '%s' 选项 %d 引用了不存在的节点 '%s'",
                        nodeId, i, choice.next
                    )
                end
            end
        end

        -- 文本不能为空
        if not node.text or #node.text == 0 then
            warnings[#warnings + 1] = string.format(
                "节点 '%s' 文本为空", nodeId
            )
        end
    end

    -- 检查是否有孤立节点（无法从 start 到达）
    local reachable = {}
    ContentValidator._TraverseNodes(data.nodes, "start", reachable)
    for nodeId, _ in pairs(data.nodes) do
        if not reachable[nodeId] then
            warnings[#warnings + 1] = string.format(
                "节点 '%s' 无法从 start 到达（孤立节点）", nodeId
            )
        end
    end

    return {
        valid = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

--- 递归遍历可达节点
function ContentValidator._TraverseNodes(nodes, currentId, visited)
    if visited[currentId] then return end
    visited[currentId] = true

    local node = nodes[currentId]
    if not node then return end

    if node.choices then
        for _, choice in ipairs(node.choices) do
            if choice.next then
                ContentValidator._TraverseNodes(nodes, choice.next, visited)
            end
        end
    end
end

--- 校验任务数据
---@param data table 任务数据
---@return table results
function ContentValidator.ValidateQuest(data)
    local errors = {}
    local warnings = {}

    if not data.quest_id then errors[#errors + 1] = "缺少 quest_id" end
    if not data.title then errors[#errors + 1] = "缺少 title" end
    if not data.objectives or #data.objectives == 0 then
        errors[#errors + 1] = "缺少 objectives"
    end

    -- 检查目标 ID 唯一性
    if data.objectives then
        local ids = {}
        for _, obj in ipairs(data.objectives) do
            if ids[obj.id] then
                errors[#errors + 1] = "重复的目标 ID: " .. obj.id
            end
            ids[obj.id] = true

            if not obj.description then
                warnings[#warnings + 1] = "目标 " .. obj.id .. " 缺少描述"
            end
        end
    end

    -- 检查奖励
    if not data.rewards then
        warnings[#warnings + 1] = "任务没有定义奖励"
    end

    return {
        valid = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

--- 校验物品数据
---@param data table 物品数据
---@return table results
function ContentValidator.ValidateItem(data)
    local errors = {}
    local warnings = {}

    if not data.item_id then errors[#errors + 1] = "缺少 item_id" end
    if not data.name then errors[#errors + 1] = "缺少 name" end
    if not data.type then errors[#errors + 1] = "缺少 type" end

    local validRarities = {
        common = true, uncommon = true, rare = true,
        epic = true, legendary = true, mythic = true,
    }
    if data.rarity and not validRarities[data.rarity] then
        warnings[#warnings + 1] = "未知的稀有度: " .. data.rarity
    end

    if not data.description or #data.description < 10 then
        warnings[#warnings + 1] = "物品描述太短或缺失"
    end

    return {
        valid = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

--- 批量校验并输出报告
---@param items table { dialogues, quests, items }
---@return table report
function ContentValidator.ValidateAll(items)
    local report = {
        total = 0,
        passed = 0,
        failed = 0,
        totalWarnings = 0,
        details = {},
    }

    -- 校验对话
    for _, d in ipairs(items.dialogues or {}) do
        report.total = report.total + 1
        local r = ContentValidator.ValidateDialogue(d)
        if r.valid then report.passed = report.passed + 1
        else report.failed = report.failed + 1 end
        report.totalWarnings = report.totalWarnings + #r.warnings
        report.details[#report.details + 1] = {
            type = "dialogue", id = d.dialogue_id, result = r,
        }
    end

    -- 校验任务
    for _, q in ipairs(items.quests or {}) do
        report.total = report.total + 1
        local r = ContentValidator.ValidateQuest(q)
        if r.valid then report.passed = report.passed + 1
        else report.failed = report.failed + 1 end
        report.totalWarnings = report.totalWarnings + #r.warnings
        report.details[#report.details + 1] = {
            type = "quest", id = q.quest_id, result = r,
        }
    end

    -- 校验物品
    for _, item in ipairs(items.items or {}) do
        report.total = report.total + 1
        local r = ContentValidator.ValidateItem(item)
        if r.valid then report.passed = report.passed + 1
        else report.failed = report.failed + 1 end
        report.totalWarnings = report.totalWarnings + #r.warnings
        report.details[#report.details + 1] = {
            type = "item", id = item.item_id, result = r,
        }
    end

    return report
end

return ContentValidator
```

---

## 8. AI 生成工作流指令

### 8.1 对话批量生成

当用户请求批量生成 NPC 对话时，AI 应遵循以下步骤：

**Step 1: 收集世界观信息**
```
需要用户提供:
- 游戏类型和背景设定
- NPC 列表（名字、职业、性格特征）
- 对话触发场景
- 是否有好感度/条件分支
```

**Step 2: 生成结构化对话**
```
对每个 NPC:
1. 根据性格特征确定说话风格
2. 生成 greeting 对话树（首次交互）
3. 生成 repeat 对话（重复交互）
4. 生成 quest 相关对话（如有关联任务）
5. 输出为标准 JSON → Lua 数据表
6. 保存到 scripts/data/dialogues/{npc_id}.lua
```

**Step 3: 校验**
```
使用 ContentValidator.ValidateDialogue 校验:
- 所有 next 引用有效
- 无孤立节点
- 文本非空
```

### 8.2 任务链生成

**Step 1: 确定任务结构**
```
用户提供:
- 主线/支线
- 任务链长度
- 难度曲线
- 奖励规模
```

**Step 2: 生成任务数据**
```
1. 规划任务链的前后依赖关系
2. 为每个任务生成目标列表
3. 设置奖励梯度（随任务难度递增）
4. 生成关联对话（任务接取/完成/失败）
5. 输出到 scripts/data/quests/{quest_id}.lua
```

**Step 3: 一致性检查**
```
- 前置任务链无环
- 物品奖励在物品库中存在
- 解锁的后续任务已定义
```

### 8.3 物品批量生成

**Step 1: 确定物品体系**
```
用户提供:
- 物品类别（武器/防具/道具/消耗品）
- 稀有度分布
- 等级范围
- 命名风格和世界观主题
```

**Step 2: 生成物品数据**
```
1. 按稀有度分配数值范围
2. 生成符合世界观的名称和描述
3. 为高稀有度物品添加特殊效果和风味文本
4. 输出到 scripts/data/items/{item_id}.lua
5. 更新 scripts/data/items/index.lua 索引
```

---

## 9. 多语言集成

### 9.1 与 i18n 框架联动

生成的叙事内容支持通过引擎 i18n 系统实现多语言：

```lua
-- scripts/data/dialogues/blacksmith.lua (中文原文)
return {
    dialogue_id = "blacksmith_greeting",
    nodes = {
        start = {
            speaker = "铁匠老王",                      -- 可翻译
            text = "哟，冒险者！需要打造点什么吗？",    -- 可翻译
            choices = {
                { text = "我想看看你的商品", next = "show_shop" },  -- 可翻译
            },
        },
    },
}
```

**使用 i18n_extract MCP 工具**可自动提取所有可翻译字符串，生成待翻译的 `.pending.json` 文件。

### 9.2 多语言对话文件组织

```
scripts/data/dialogues/
├── blacksmith.lua           # 中文（源语言）
└── [通过 i18n 框架自动翻译覆盖]

-- 或者手动维护多语言版本:
scripts/data/dialogues/
├── cmn/
│   └── blacksmith.lua       # 中文
├── en/
│   └── blacksmith.lua       # English
└── ja/
    └── blacksmith.lua       # 日本語
```

---

## 10. 完整集成示例

```lua
-- scripts/main.lua
-- 使用 HF-Narrative-Craft 生成的内容驱动的 RPG 游戏

require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")
local DialogueRunner = require("systems.DialogueRunner")
local QuestManager = require("systems.QuestManager")
local NarrativeEventSystem = require("systems.NarrativeEventSystem")
local DialogueBox = require("ui.DialogueBox")
local cjson = require("cjson")

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil

-- 游戏系统
local questMgr = QuestManager.New()
local narrativeSystem = NarrativeEventSystem.New()
local dialogueBox = nil
local currentDialogue = nil
local currentNodeId = nil

-- 游戏状态
local gameState = {
    level = 5,
    gold = 100,
    activeQuests = {},
    inventory = {},
    flags = {},
    affinity = {},
}

function Start()
    SampleInitMouseMode(MM_ABSOLUTE)

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("PhysicsWorld")

    -- 灯光
    local lightNode = scene_:CreateChild("Light")
    lightNode.direction = Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.brightness = 1.0

    -- 相机
    cameraNode_ = scene_:CreateChild("Camera")
    cameraNode_.position = Vector3(0, 5, -10)
    cameraNode_:LookAt(Vector3(0, 0, 0))
    local camera = cameraNode_:CreateComponent("Camera")
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- 注册任务数据
    questMgr:RegisterBatch({
        "data.quests.explore_north_cave",
    })

    -- 注册叙事事件
    narrativeSystem:RegisterChapter("data.narrative.chapter1_events")

    -- 注册叙事动作处理器
    narrativeSystem:RegisterActionHandler("show_dialogue", function(action)
        StartDialogue(action.dialogue_path)
    end)
    narrativeSystem:RegisterActionHandler("play_sfx", function(action)
        log:Write(LOG_INFO, "SFX: " .. action.path)
    end)
    narrativeSystem:RegisterActionHandler("set_flag", function(action)
        gameState.flags[action.key] = action.value
    end)

    -- 初始化 UI
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 创建对话框
    dialogueBox = DialogueBox.Create({
        width = "80%",
        onChoice = function(choice)
            if choice then
                AdvanceDialogue(choice.next)
            else
                EndDialogue()
            end
        end,
    })

    -- 创建主 UI
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        children = {
            -- 顶部状态栏
            UI.Panel {
                width = "100%",
                height = 40,
                flexDirection = "row",
                backgroundColor = "rgba(0,0,0,0.7)",
                padding = 8,
                children = {
                    UI.Label { text = "Lv.5", color = "#FFD700", fontSize = 16 },
                    UI.Label { text = "  |  ", color = "#666", fontSize = 16 },
                    UI.Label { text = "Gold: 100", color = "#FFD700", fontSize = 16 },
                },
            },
            -- NPC 交互按钮
            UI.Panel {
                width = "100%",
                flex = 1,
                justifyContent = "center",
                alignItems = "center",
                children = {
                    UI.Button {
                        text = "与铁匠老王交谈",
                        variant = "primary",
                        onClick = function()
                            StartDialogue("data.dialogues.blacksmith")
                        end,
                    },
                },
            },
            -- 对话框（底部）
            dialogueBox.root,
        },
    }
    UI.SetRoot(root)

    -- 激活初始任务
    local ok, err = questMgr:Activate("explore_north_cave", gameState)
    if ok then
        gameState.activeQuests["explore_north_cave"] = true
        log:Write(LOG_INFO, "Quest activated: explore_north_cave")
    end

    SubscribeToEvent("Update", "HandleUpdate")
end

--- 开始对话
function StartDialogue(path)
    currentDialogue = DialogueRunner.Load(path)
    currentNodeId = "start"
    ShowCurrentNode()
end

--- 显示当前节点
function ShowCurrentNode()
    if not currentDialogue then return end

    local node = DialogueRunner.GetNode(currentDialogue, currentNodeId)
    if not node then
        EndDialogue()
        return
    end

    -- 执行节点动作
    DialogueRunner.ExecuteAction(node, function(action)
        if action.type == "open_shop" then
            log:Write(LOG_INFO, "Opening shop: " .. action.shop_id)
        elseif action.type == "update_quest" then
            log:Write(LOG_INFO, "Quest updated: " .. action.quest_id)
        end
    end)

    -- 获取可用选项
    local choices = DialogueRunner.GetAvailableChoices(node, gameState)

    -- 显示对话框
    dialogueBox.Show(node, choices)
end

--- 推进对话
function AdvanceDialogue(nextNodeId)
    if nextNodeId == "end" or not nextNodeId then
        EndDialogue()
        return
    end
    currentNodeId = nextNodeId
    ShowCurrentNode()
end

--- 结束对话
function EndDialogue()
    currentDialogue = nil
    currentNodeId = nil
    dialogueBox.Hide()
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    -- 游戏逻辑更新
end

function Stop()
    -- 保存任务进度
    local saveJson = questMgr:SaveToJSON()
    local narrativeState = narrativeSystem:SaveState()
    log:Write(LOG_INFO, "Game state saved")
end
```

---

## 11. 目录结构规范

生成内容必须遵循以下目录结构：

```
scripts/
├── main.lua                        # 游戏入口
├── data/                           # 📦 叙事内容数据（由本 Skill 生成）
│   ├── dialogues/                  # 对话数据
│   │   ├── blacksmith.lua
│   │   ├── village_elder.lua
│   │   └── guard_captain.lua
│   ├── quests/                     # 任务数据
│   │   ├── explore_north_cave.lua
│   │   ├── village_defense.lua
│   │   └── index.lua              # 任务索引
│   ├── items/                      # 物品数据
│   │   ├── legendary_sword_stormbreaker.lua
│   │   ├── common_potion_health_small.lua
│   │   └── index.lua              # 物品索引
│   └── narrative/                  # 叙事事件数据
│       └── chapter1_events.lua
├── systems/                        # 🔧 运行时系统
│   ├── DialogueRunner.lua
│   ├── QuestManager.lua
│   └── NarrativeEventSystem.lua
├── ui/                             # 🎨 UI 组件
│   └── DialogueBox.lua
└── tools/                          # 🔍 开发工具
    └── ContentValidator.lua
```

---

## 12. 引擎规则遵守

| 规则 | 遵守方式 |
|------|---------|
| 代码放 scripts/ | 所有生成内容存入 `scripts/data/` |
| 不使用 io 库 | 文件操作使用 File API 或 cjson |
| 数组索引从 1 | 所有 Lua 循环从 1 开始 |
| UI 用新系统 | DialogueBox 使用 urhox-libs/UI |
| 构建后预览 | 内容生成完毕后必须调用构建工具 |
| 资源路径不加前缀 | 音频路径直接从 Audio/ 开始 |
| 存档用 JSON | QuestManager 使用 cjson 序列化 |
| 枚举值不猜数字 | 使用 MM_ABSOLUTE 等枚举常量 |
| 类型标注 | 关键变量添加 @type 注解 |

---

## 13. 性能预算

| 指标 | 限制 |
|------|------|
| 单个对话文件 | < 500 行 Lua |
| 单个任务文件 | < 200 行 Lua |
| 单个物品文件 | < 100 行 Lua |
| 物品索引文件 | < 1000 行（超过则分类拆分） |
| 运行时内存 | 按需 require，不预加载所有数据 |

---

## 14. FAQ

**Q1: 和 world-lore-notebook 有什么区别？**
A: world-lore-notebook 管理世界观**实体关系**（知识图谱），本 Skill 生成可直接在游戏中使用的**结构化叙事数据**（对话树、任务、物品）。两者互补：先用 world-lore-notebook 建立世界观，再用本 Skill 基于世界观批量锻造游戏内容。

**Q2: 和 gaia-npc-ai 有什么区别？**
A: gaia-npc-ai 处理 NPC **运行时 AI 行为**（状态机、决策树、亲密度系统），本 Skill 处理 NPC **台词内容**（预先生成的对话数据）。gaia-npc-ai 决定 NPC "做什么"，本 Skill 决定 NPC "说什么"。

**Q3: 生成的内容支持运行时动态修改吗？**
A: 生成的是标准 Lua 表，游戏可以在运行时读取并修改。例如，可以根据好感度动态解锁对话分支。

**Q4: 如何与 cinematic-dub-pipeline 配合？**
A: 本 Skill 生成对话文本数据 → cinematic-dub-pipeline 为这些文本生成语音配音。工作流：DialogueForge 输出对话 → VoiceSynthesizer 合成语音 → CutscenePlayer 播放。

**Q5: 大量物品数据会影响加载速度吗？**
A: 使用 Lua require 按需加载，只在需要时加载对应数据文件。物品索引文件只包含 require 引用，不会一次性加载所有物品详情。

**Q6: 如何保存和恢复任务进度？**
A: QuestManager 提供 SaveToJSON/LoadFromJSON 方法，使用 cjson 将进度序列化为 JSON 字符串，可存入本地文件（File API）或云变量（clientCloud）。

**Q7: 支持随机任务生成吗？**
A: 可以通过模板 + 变量替换实现。定义任务模板（如"消灭 {count} 只 {enemy}"），运行时随机填充变量生成任务实例。

---

## 15. References

- [references/hf-research-mapping.md](references/hf-research-mapping.md) — HF 社区项目与本 Skill 的详细映射
- [references/content-schema-spec.md](references/content-schema-spec.md) — JSON/Lua 数据格式完整规范
- [references/generation-templates.md](references/generation-templates.md) — AI 内容生成 prompt 模板库

---

*灵感来源: Hugging Face 社区游戏 AI 研究 (https://huggingface.co/)*
*Gemma3NPC, npcLM, TextQuests, Amaydle NPC Dialogue, Game Items Generator*
