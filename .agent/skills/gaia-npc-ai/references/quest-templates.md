# 程序化任务模板库

> GAIA NPC AI — 任务生成参考模板

---

## 1. 任务类型定义

| 类型 ID | 名称 | 描述 | 典型触发条件 |
|---------|------|------|-------------|
| `deliver` | 递送 | 将物品交给 NPC | NPC 缺乏特定资源 |
| `kill` | 击杀 | 消灭指定目标 | NPC 受到威胁 |
| `escort` | 护送 | 保护 NPC 到达目的地 | 亲密度 ≥ 51 |
| `talk` | 对话 | 与 NPC 交谈获取信息 | 亲密度 ≥ 21 |
| `gather` | 采集 | 收集指定资源 | NPC 需要原材料 |
| `defend` | 防守 | 保卫 NPC 或区域 | NPC 处于危险 |
| `trade` | 交易 | 完成特定交易条件 | NPC 处于交易状态 |

---

## 2. 状态驱动任务模板

### 2.1 饥饿系列

```lua
-- 模板: NPC 饥饿 → 送食物
{
    condition = function(agent)
        return agent.hunger > 50 and agent.food <= 0
    end,
    template = {
        type = "deliver",
        titleFormat = "帮助饥饿的%s",
        descFormat = "%s（%s）非常饥饿，需要 %d 份食物。",
        requirements = { item = "food", amount = 3 },
        rewards = { affinity = 15, gold = 20 },
    },
}

-- 模板: NPC 饥饿且年老 → 代为狩猎
{
    condition = function(agent)
        return agent.hunger > 50 and agent.food <= 0
            and (agent.age < 10 or agent.age > 50)
    end,
    template = {
        type = "kill",
        titleFormat = "为%s代猎",
        descFormat = "%s 年事已高（%d岁），无力狩猎。帮他猎取猎物吧。",
        requirements = { target = "prey", amount = 2 },
        rewards = { affinity = 25, food = 5 },
    },
}
```

### 2.2 受伤系列

```lua
-- 模板: NPC 重伤 → 送草药
{
    condition = function(agent)
        return agent.hp < agent.maxHp * 0.5 and agent.currentState ~= "dead"
    end,
    template = {
        type = "deliver",
        titleFormat = "治疗受伤的%s",
        descFormat = "%s 受了重伤（HP: %d/%d），急需草药。",
        requirements = { item = "herb", amount = 2 },
        rewards = { affinity = 20, gold = 30 },
    },
}

-- 模板: NPC 逃跑中 → 护送到安全地带
{
    condition = function(agent)
        return agent.currentState == "fleeing"
    end,
    template = {
        type = "escort",
        titleFormat = "护送%s逃离危险",
        descFormat = "%s 正在逃跑，需要你的保护。",
        requirements = { destination = "safe_zone" },
        rewards = { affinity = 30, gold = 50 },
    },
}
```

### 2.3 亲密度解锁系列

```lua
-- 友好级别: 信息分享
{
    condition = function(agent)
        return agent.affinity >= 21
    end,
    template = {
        type = "talk",
        titleFormat = "%s的秘密消息",
        descFormat = "%s 信任你，愿意分享一条重要线索。",
        requirements = {},
        rewards = { clue = true, mapMarker = true },
    },
}

-- 亲密级别: 特殊委托
{
    condition = function(agent)
        return agent.affinity >= 51
    end,
    template = {
        type = "escort",
        titleFormat = "护送%s",
        descFormat = "%s 需要你护送到安全地带。作为回报，将给你一件珍贵物品。",
        requirements = { destination = "safe_zone" },
        rewards = { affinity = 30, gold = 100, specialItem = true },
    },
}

-- 忠诚级别: 招募同伴
{
    condition = function(agent)
        return agent.affinity >= 81
    end,
    template = {
        type = "talk",
        titleFormat = "%s愿意追随你",
        descFormat = "%s 对你忠心耿耿，愿意成为你的同伴。",
        requirements = {},
        rewards = { companion = true },
    },
}
```

---

## 3. 任务模板引擎

### 3.1 通用任务生成器

```lua
-- scripts/npc/QuestTemplateEngine.lua
-- 基于模板的任务生成引擎

local QuestTemplateEngine = {}

-- 任务模板注册表
QuestTemplateEngine.templates = {}

--- 注册任务模板
---@param template table 包含 condition 和 template 字段
function QuestTemplateEngine.Register(template)
    table.insert(QuestTemplateEngine.templates, template)
end

--- 为指定 NPC 生成所有符合条件的任务
---@param agent GaiaAgentDef
---@return GaiaQuest[]
function QuestTemplateEngine.GenerateAll(agent)
    local quests = {}

    for _, tmpl in ipairs(QuestTemplateEngine.templates) do
        if tmpl.condition(agent) then
            local quest = {
                id = tmpl.template.type .. "_" .. agent.name .. "_" .. #quests,
                title = string.format(tmpl.template.titleFormat, agent.name),
                description = string.format(
                    tmpl.template.descFormat,
                    agent.name,
                    agent.title or "",
                    agent.age or 0
                ),
                npcName = agent.name,
                type = tmpl.template.type,
                requirements = tmpl.template.requirements,
                rewards = tmpl.template.rewards,
            }
            table.insert(quests, quest)
        end
    end

    return quests
end

return QuestTemplateEngine
```

### 3.2 使用方式

```lua
local QuestTemplateEngine = require "npc.QuestTemplateEngine"

-- 注册默认模板
QuestTemplateEngine.Register({
    condition = function(a) return a.hunger > 50 and a.food <= 0 end,
    template = {
        type = "deliver",
        titleFormat = "帮助饥饿的%s",
        descFormat = "%s 非常饥饿，需要食物。",
        requirements = { item = "food", amount = 3 },
        rewards = { affinity = 15, gold = 20 },
    },
})

-- 开发者可以注册自定义模板
QuestTemplateEngine.Register({
    condition = function(a)
        return a.currentState == "guarding" and a.hunger > 60
    end,
    template = {
        type = "deliver",
        titleFormat = "给守卫%s送饭",
        descFormat = "%s 在守卫岗位无法离开，需要有人送餐。",
        requirements = { item = "meal", amount = 1 },
        rewards = { affinity = 10, gold = 15 },
    },
})

-- 使用
local quests = QuestTemplateEngine.GenerateAll(someAgent)
for _, q in ipairs(quests) do
    print(q.title .. ": " .. q.description)
end
```

---

## 4. GAIA 经典场景详解

### 场景 A: 商人忙于狩猎

```
NPC: 李商人（title="商人", currentState="hunting", hunger=75）
玩家需要购买物品，但商人正在狩猎

选项1: 等待狩猎结束 → 商人回到 idle → 可正常交易
选项2: 帮助狩猎 → 喂食商人 → 好感 +10，商人感激切换到 trading
选项3: 攻击商人 → 获得商人物品 → 好感 -25，商人死亡/逃跑
```

### 场景 B: 船夫在钓鱼

```
NPC: 张船夫（title="船夫", currentState="hunting(fishing)", hunger=60）
玩家需要过河，但船夫在钓鱼

选项1: 等待钓鱼结束 → 船夫回到 idle → 提供摆渡服务
选项2: 提供鱼（喂食） → 船夫不再需要钓鱼 → 直接进入 trading 提供服务
选项3: 强迫 → 攻击降低好感 → 船夫可能逃跑，失去渡河机会
```

### 场景 C: 饥饿的流浪者

```
NPC: 流浪者（title="流浪者", hunger=90, food=0, affinity=0）
一个饥饿的流浪者倒在路边

选项1: 喂食 → 好感 +10 → 流浪者感激 → 未来可能回报（高亲密度任务）
选项2: 忽视 → 流浪者最终饿死 → 无后续
选项3: 攻击 → 好感 -25 → 流浪者死亡 → 可能引发阵营连锁反应
```

---

## 5. 任务状态管理

任务完成后需要更新 NPC 状态：

```lua
--- 完成任务回调
---@param quest GaiaQuest
---@param agent GaiaAgentDef
function OnQuestComplete(quest, agent)
    -- 应用亲密度奖励
    if quest.rewards.affinity then
        AffinitySystem.PositiveInteraction(
            agent, quest.rewards.affinity, "quest_complete"
        )
    end

    -- 更新 NPC 状态
    if quest.type == "deliver" and quest.requirements.item == "food" then
        agent.food = agent.food + quest.requirements.amount
        agent.hunger = math.max(0, agent.hunger - 30)
    end

    if quest.type == "deliver" and quest.requirements.item == "herb" then
        agent.hp = math.min(agent.maxHp, agent.hp + 30)
    end

    -- 标记任务完成
    quest.completed = true
    quest.completedTime = time:GetElapsedTime()

    log:Write(LOG_INFO, "Quest completed: " .. quest.title)
end
```

---

## 6. 存档与持久化

任务状态可以随 NPC 状态一起保存：

```lua
-- 在 AgentManager.SaveState 中追加任务数据
-- 使用 File API 写入 scripts/ 目录下的相对路径
-- 详见 engine-docs/recipes/file-storage.md

-- 保存路径示例
local savePath = "saves/quest_state.json"
```

构建时确保存档目录可访问。使用 UrhoX MCP `build` 工具验证文件结构。
