---
skill_name: "world-lore-notebook"
version: "1.0.0"
description: "World Lore Notebook — 游戏世界观数据库与知识图谱管理系统，为 UrhoX Lua 游戏提供结构化的世界观实体（角色/地点/物品/生物/事件/阵营/魔法/科技/传说）管理、关系网络、连续性检查和运行时查询能力"
author: "UrhoX Skill Builder"
tags: ["worldbuilding", "lore", "database", "knowledge-graph", "narrative", "game-design", "encyclopedia"]
triggers:
  - "世界观"
  - "世界设定"
  - "lore"
  - "worldbuilding"
  - "游戏百科"
  - "角色档案"
  - "地点设定"
  - "物品图鉴"
  - "生物图鉴"
  - "设定集"
  - "知识图谱"
  - "lore database"
  - "notebook"
  - "世界观笔记本"
---

# World Lore Notebook — 游戏世界观数据库

> **结构化世界观管理系统 for UrhoX Lua Games**
>
> 灵感来源：[indentlabs/notebook](https://github.com/indentlabs/notebook)
>
> 为游戏开发者提供一套完整的世界观数据管理方案——从角色档案到地点百科，
> 从物品图鉴到阵营关系网，一切设定数据结构化存储、关系可追溯、运行时可查询。

---

## §1 Use When 触发条件

**Use when:** 用户需要
(1) 为游戏建立结构化的世界观设定数据库（角色/地点/物品/生物/事件/阵营等），
(2) 管理游戏实体之间的关系网络（谁住在哪里、谁拥有什么、谁与谁敌对），
(3) 在游戏运行时查询世界观数据（NPC 对话引用、物品描述、百科系统），
(4) 检查世界观的连续性/一致性（发现自相矛盾的设定），
(5) 用户说"世界观"、"世界设定"、"lore"、"设定集"、"百科"、"图鉴"，
(6) 需要一个可序列化的世界观数据层供多个游戏系统共享，
(7) 用户说"notebook"、"知识图谱"、"角色档案"、"地点设定"，
(8) 需要为 RPG/冒险/叙事驱动游戏构建内容数据库。

**不适用于：**
- 游戏设计文档生成 → 使用 `game-forge-design`
- NPC AI 行为/状态机 → 使用 `gaia-npc-ai` 或 `behavior-tree-ai`
- 纯美术资源生成 → 使用 `game-cog` 或 `auto-game-assets`
- 引导式游戏创意讨论 → 使用 `interactive-game-designer`

---

## §2 系统概览

### 2.1 核心架构

```
┌─────────────────────────────────────────────────┐
│              World Lore Notebook                │
│                                                 │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐ │
│  │ Entity   │  │ Relation  │  │ Consistency  │ │
│  │ Registry │←→│ Engine    │←→│ Checker      │ │
│  └────┬─────┘  └─────┬─────┘  └──────┬───────┘ │
│       │              │               │          │
│  ┌────┴─────┐  ┌─────┴─────┐  ┌─────┴───────┐ │
│  │ Query    │  │ Lore      │  │ Persistence │ │
│  │ Engine   │  │ Prompter  │  │ Manager     │ │
│  └──────────┘  └───────────┘  └─────────────┘ │
│                                                 │
│  9 Entity Types × N Relations × M Tags          │
└─────────────────────────────────────────────────┘
```

### 2.2 六大核心模块

| 模块 | 职责 | 关键 API |
|------|------|----------|
| **Entity Registry** | 注册/存储/检索 9 种类型实体 | `register()`, `get()`, `find()` |
| **Relation Engine** | 管理实体间双向关系 | `link()`, `unlink()`, `getRelated()` |
| **Query Engine** | 多条件组合查询 | `query()`, `search()`, `filter()` |
| **Consistency Checker** | 检测矛盾/缺失 | `check()`, `validate()` |
| **Lore Prompter** | AI 辅助世界观补全 | `suggest()`, `askQuestions()` |
| **Persistence Manager** | JSON 序列化/反序列化 | `save()`, `load()`, `export()` |

---

## §3 实体类型系统

### 3.1 九种核心实体类型

Notebook.ai 的核心理念是"一切皆页面（Page）"。在游戏开发中，我们将其映射为 9 种实体类型：

```lua
------------------------------------------------------------
-- scripts/lore/EntityTypes.lua
-- 实体类型枚举与元数据定义
------------------------------------------------------------

local EntityTypes = {
    CHARACTER = "character",   -- 角色：NPC、玩家角色、历史人物
    LOCATION  = "location",    -- 地点：城市、地标、区域、国家
    ITEM      = "item",        -- 物品：武器、道具、关键物品
    CREATURE  = "creature",    -- 生物：野兽、魔物、宠物
    EVENT     = "event",       -- 事件：历史事件、剧情节点
    FACTION   = "faction",     -- 阵营：组织、国家、势力
    MAGIC     = "magic",       -- 魔法/超自然：法术、技能体系
    TECHNOLOGY = "technology", -- 科技：发明、技术体系
    LORE      = "lore",        -- 传说：神话、预言、传闻
}

-- 每种类型的默认字段模板
local TypeTemplates = {
    [EntityTypes.CHARACTER] = {
        required = { "name", "description" },
        optional = {
            "age", "gender", "race", "occupation",
            "appearance", "personality", "backstory",
            "abilities", "weaknesses", "goals", "secrets",
            "dialogueStyle", "voiceNotes",
        },
    },
    [EntityTypes.LOCATION] = {
        required = { "name", "description" },
        optional = {
            "region", "climate", "population", "government",
            "culture", "economy", "landmarks", "dangers",
            "history", "connectedLocations",
        },
    },
    [EntityTypes.ITEM] = {
        required = { "name", "description" },
        optional = {
            "type", "rarity", "value", "weight",
            "effects", "loreText", "origin", "materials",
            "requirements", "craftRecipe",
        },
    },
    [EntityTypes.CREATURE] = {
        required = { "name", "description" },
        optional = {
            "species", "habitat", "diet", "behavior",
            "abilities", "weaknesses", "drops",
            "tameable", "dangerLevel",
        },
    },
    [EntityTypes.EVENT] = {
        required = { "name", "description" },
        optional = {
            "date", "duration", "participants",
            "location", "consequences", "prerequisites",
            "triggerCondition",
        },
    },
    [EntityTypes.FACTION] = {
        required = { "name", "description" },
        optional = {
            "leader", "headquarters", "ideology",
            "members", "allies", "enemies",
            "resources", "territory", "ranks",
        },
    },
    [EntityTypes.MAGIC] = {
        required = { "name", "description" },
        optional = {
            "school", "element", "cost", "range",
            "castTime", "cooldown", "effects",
            "prerequisites", "loreOrigin",
        },
    },
    [EntityTypes.TECHNOLOGY] = {
        required = { "name", "description" },
        optional = {
            "era", "inventor", "materials",
            "applications", "limitations",
            "prerequisites", "socialImpact",
        },
    },
    [EntityTypes.LORE] = {
        required = { "name", "description" },
        optional = {
            "category", "source", "reliability",
            "relatedEvents", "prophecy",
            "culturalSignificance", "contradictions",
        },
    },
}

return {
    Types = EntityTypes,
    Templates = TypeTemplates,
}
```

### 3.2 实体数据结构

每个实体共享统一的基础结构：

```lua
------------------------------------------------------------
-- 实体基础数据结构
------------------------------------------------------------

---@class LoreEntity
---@field id string             唯一标识符（自动生成）
---@field type string           实体类型（EntityTypes 枚举值）
---@field name string           实体名称
---@field description string    实体描述
---@field tags string[]         标签列表（用于分类检索）
---@field fields table          类型特有字段（key-value）
---@field meta table            元数据（创建时间、修改时间、版本）
---@field notes string          开发者备注（不进入游戏运行时）

-- 示例：创建一个角色实体
local heroEntity = {
    id = "char_001",
    type = "character",
    name = "艾琳·暮光",
    description = "最后一位暮光骑士团的传承者，背负着终结永夜的使命。",
    tags = { "主角", "骑士", "暮光骑士团", "人类" },
    fields = {
        age = 24,
        gender = "female",
        race = "人类",
        occupation = "暮光骑士",
        appearance = "银白色长发，琥珀色眼瞳，左眼下有月牙形疤痕",
        personality = "表面冷静内心温柔，责任感极强，不善表达情感",
        backstory = "幼年时暮光骑士团被永夜军团覆灭，被老骑士收养训练",
        abilities = { "暮光斩", "月光盾", "黎明之眼" },
        weaknesses = { "惧怕完全黑暗", "过度信任同伴" },
        goals = { "找到永夜之源", "重建暮光骑士团" },
        secrets = { "她的左眼能看到灵魂" },
        dialogueStyle = "简短精练，偶尔露出温暖",
        voiceNotes = "低沉但清晰，战斗时语速加快",
    },
    meta = {
        createdAt = "2025-01-15",
        modifiedAt = "2025-01-20",
        version = 3,
    },
    notes = "主线角色，第三章解锁左眼能力",
}
```

---

## §4 世界观数据库核心（LoreDB）

### 4.1 数据库初始化与基本操作

```lua
------------------------------------------------------------
-- scripts/lore/LoreDB.lua
-- 世界观数据库核心模块
------------------------------------------------------------

local json = require("cjson")
local EntityTypes = require("lore.EntityTypes")

local LoreDB = {}
LoreDB.__index = LoreDB

--- 创建新的世界观数据库
---@param config table|nil 可选配置
---@return table LoreDB 实例
function LoreDB.New(config)
    local db = setmetatable({}, LoreDB)

    db.config = config or {}
    db.config.name = db.config.name or "Untitled World"
    db.config.autoId = db.config.autoId ~= false  -- 默认自动生成 ID

    -- 实体存储：entities[id] = entity
    db.entities = {}
    -- 类型索引：typeIndex[type][id] = true
    db.typeIndex = {}
    -- 标签索引：tagIndex[tag][id] = true
    db.tagIndex = {}
    -- 名称索引：nameIndex[lowercase_name] = id
    db.nameIndex = {}
    -- 关系存储：relations[id] = { {targetId, relationType, data}, ... }
    db.relations = {}

    -- 初始化类型索引
    for _, typeName in pairs(EntityTypes.Types) do
        db.typeIndex[typeName] = {}
    end

    -- 版本与元数据
    db.meta = {
        version = 1,
        createdAt = "",
        modifiedAt = "",
        entityCount = 0,
        relationCount = 0,
    }

    return db
end

--- 生成唯一 ID
---@param entityType string 实体类型
---@return string id
function LoreDB:_generateId(entityType)
    local prefix = string.sub(entityType, 1, 4)
    local count = 0
    for _ in pairs(self.typeIndex[entityType] or {}) do
        count = count + 1
    end
    return prefix .. "_" .. string.format("%03d", count + 1)
end

--- 注册新实体
---@param entityType string 实体类型
---@param data table 实体数据
---@return table entity 完整实体对象
function LoreDB:Register(entityType, data)
    -- 验证类型
    local validType = false
    for _, v in pairs(EntityTypes.Types) do
        if v == entityType then validType = true; break end
    end
    if not validType then
        log:Write(LOG_ERROR, "LoreDB: unknown entity type '" .. tostring(entityType) .. "'")
        return nil
    end

    -- 验证必填字段
    local template = EntityTypes.Templates[entityType]
    if template then
        for _, field in ipairs(template.required) do
            if not data[field] then
                log:Write(LOG_ERROR, "LoreDB: missing required field '" .. field .. "' for " .. entityType)
                return nil
            end
        end
    end

    -- 构建实体
    local id = data.id or (self.config.autoId and self:_generateId(entityType))
    if not id then
        log:Write(LOG_ERROR, "LoreDB: entity must have an id")
        return nil
    end

    -- 检查 ID 唯一性
    if self.entities[id] then
        log:Write(LOG_WARNING, "LoreDB: id '" .. id .. "' already exists, overwriting")
    end

    local entity = {
        id = id,
        type = entityType,
        name = data.name,
        description = data.description or "",
        tags = data.tags or {},
        fields = {},
        meta = {
            createdAt = data.createdAt or "",
            modifiedAt = "",
            version = 1,
        },
        notes = data.notes or "",
    }

    -- 填充类型特有字段
    if template then
        for _, field in ipairs(template.optional or {}) do
            if data[field] ~= nil then
                entity.fields[field] = data[field]
            end
        end
    end
    -- 也允许自定义字段
    for k, v in pairs(data) do
        if k ~= "id" and k ~= "name" and k ~= "description"
           and k ~= "tags" and k ~= "notes" and k ~= "createdAt"
           and not entity.fields[k] then
            -- 检查是否是自定义字段（不在 required/optional 中）
            local isStandard = false
            if template then
                for _, f in ipairs(template.required) do
                    if f == k then isStandard = true; break end
                end
                if not isStandard then
                    for _, f in ipairs(template.optional or {}) do
                        if f == k then isStandard = true; break end
                    end
                end
            end
            if not isStandard then
                entity.fields[k] = v  -- 自定义扩展字段
            end
        end
    end

    -- 存储实体
    self.entities[id] = entity

    -- 更新索引
    self.typeIndex[entityType] = self.typeIndex[entityType] or {}
    self.typeIndex[entityType][id] = true

    for _, tag in ipairs(entity.tags) do
        self.tagIndex[tag] = self.tagIndex[tag] or {}
        self.tagIndex[tag][id] = true
    end

    local lowerName = string.lower(entity.name)
    self.nameIndex[lowerName] = id

    -- 初始化关系列表
    self.relations[id] = self.relations[id] or {}

    -- 更新元数据
    self.meta.entityCount = self.meta.entityCount + 1

    log:Write(LOG_INFO, "LoreDB: registered " .. entityType .. " '" .. entity.name .. "' (id=" .. id .. ")")
    return entity
end

--- 获取实体
---@param id string 实体 ID
---@return table|nil entity
function LoreDB:Get(id)
    return self.entities[id]
end

--- 按名称查找实体
---@param name string 实体名称（不区分大小写）
---@return table|nil entity
function LoreDB:FindByName(name)
    local id = self.nameIndex[string.lower(name)]
    if id then return self.entities[id] end
    return nil
end

--- 按类型列出所有实体
---@param entityType string 实体类型
---@return table[] entities
function LoreDB:ListByType(entityType)
    local result = {}
    for id in pairs(self.typeIndex[entityType] or {}) do
        result[#result + 1] = self.entities[id]
    end
    return result
end

--- 按标签查找实体
---@param tag string 标签
---@return table[] entities
function LoreDB:FindByTag(tag)
    local result = {}
    for id in pairs(self.tagIndex[tag] or {}) do
        result[#result + 1] = self.entities[id]
    end
    return result
end

--- 更新实体字段
---@param id string 实体 ID
---@param updates table 要更新的字段
---@return boolean success
function LoreDB:Update(id, updates)
    local entity = self.entities[id]
    if not entity then
        log:Write(LOG_ERROR, "LoreDB: entity '" .. id .. "' not found")
        return false
    end

    for k, v in pairs(updates) do
        if k == "name" then
            -- 更新名称索引
            local oldLower = string.lower(entity.name)
            self.nameIndex[oldLower] = nil
            entity.name = v
            self.nameIndex[string.lower(v)] = id
        elseif k == "description" then
            entity.description = v
        elseif k == "tags" then
            -- 清除旧标签索引
            for _, oldTag in ipairs(entity.tags) do
                if self.tagIndex[oldTag] then
                    self.tagIndex[oldTag][id] = nil
                end
            end
            entity.tags = v
            for _, newTag in ipairs(v) do
                self.tagIndex[newTag] = self.tagIndex[newTag] or {}
                self.tagIndex[newTag][id] = true
            end
        elseif k == "notes" then
            entity.notes = v
        else
            entity.fields[k] = v
        end
    end

    entity.meta.modifiedAt = ""
    entity.meta.version = entity.meta.version + 1

    return true
end

--- 删除实体
---@param id string 实体 ID
---@return boolean success
function LoreDB:Remove(id)
    local entity = self.entities[id]
    if not entity then return false end

    -- 清除索引
    if self.typeIndex[entity.type] then
        self.typeIndex[entity.type][id] = nil
    end

    for _, tag in ipairs(entity.tags) do
        if self.tagIndex[tag] then
            self.tagIndex[tag][id] = nil
        end
    end

    local lowerName = string.lower(entity.name)
    if self.nameIndex[lowerName] == id then
        self.nameIndex[lowerName] = nil
    end

    -- 清除关系
    self:_removeAllRelations(id)

    -- 删除实体
    self.entities[id] = nil
    self.meta.entityCount = self.meta.entityCount - 1

    log:Write(LOG_INFO, "LoreDB: removed entity '" .. id .. "'")
    return true
end

return LoreDB
```

---

## §5 关系引擎

### 5.1 关系类型定义

实体间的关系是世界观的骨架。notebook.ai 的核心优势就是关系管理。

```lua
------------------------------------------------------------
-- scripts/lore/RelationTypes.lua
-- 关系类型枚举
------------------------------------------------------------

local RelationTypes = {
    -- 空间关系
    LOCATED_IN     = "located_in",       -- A 位于 B（角色→地点）
    CONTAINS       = "contains",         -- A 包含 B（地点→地点）
    CONNECTED_TO   = "connected_to",     -- A 连通 B（地点↔地点）

    -- 社会关系
    BELONGS_TO     = "belongs_to",       -- A 属于 B（角色→阵营）
    LEADS          = "leads",            -- A 领导 B（角色→阵营）
    ALLIED_WITH    = "allied_with",      -- A 与 B 结盟（阵营↔阵营）
    HOSTILE_TO     = "hostile_to",       -- A 与 B 敌对（阵营↔阵营）

    -- 人物关系
    KNOWS          = "knows",            -- A 认识 B（角色↔角色）
    FRIEND_OF      = "friend_of",        -- A 是 B 的朋友（角色↔角色）
    ENEMY_OF       = "enemy_of",         -- A 是 B 的敌人（角色↔角色）
    FAMILY_OF      = "family_of",        -- A 是 B 的亲属（角色↔角色）
    MENTOR_OF      = "mentor_of",        -- A 是 B 的导师（角色→角色）

    -- 所有权/创造
    OWNS           = "owns",             -- A 拥有 B（角色→物品）
    CREATED_BY     = "created_by",       -- A 由 B 创造（物品→角色）
    GUARDS         = "guards",           -- A 守护 B（生物→地点/物品）

    -- 事件关系
    PARTICIPATES   = "participates",     -- A 参与 B（角色→事件）
    TRIGGERED_BY   = "triggered_by",     -- A 由 B 触发（事件→事件）
    OCCURS_AT      = "occurs_at",        -- A 发生在 B（事件→地点）

    -- 知识关系
    KNOWS_SPELL    = "knows_spell",      -- A 掌握 B（角色→魔法）
    USES_TECH      = "uses_tech",        -- A 使用 B（阵营→科技）
    REFERENCED_IN  = "referenced_in",    -- A 被 B 提及（任意→传说）

    -- 通用
    RELATED_TO     = "related_to",       -- 通用关联（任意↔任意）
}

-- 关系对称性定义（双向关系会自动创建反向）
local SymmetricRelations = {
    [RelationTypes.CONNECTED_TO] = true,
    [RelationTypes.ALLIED_WITH]  = true,
    [RelationTypes.HOSTILE_TO]   = true,
    [RelationTypes.KNOWS]        = true,
    [RelationTypes.FRIEND_OF]    = true,
    [RelationTypes.ENEMY_OF]     = true,
    [RelationTypes.FAMILY_OF]    = true,
    [RelationTypes.RELATED_TO]   = true,
}

-- 关系反义定义（创建 A→B 时自动创建 B→A 的反义关系）
local InverseRelations = {
    [RelationTypes.LOCATED_IN]   = RelationTypes.CONTAINS,
    [RelationTypes.CONTAINS]     = RelationTypes.LOCATED_IN,
    [RelationTypes.BELONGS_TO]   = RelationTypes.LEADS,   -- 近似反义
    [RelationTypes.OWNS]         = RelationTypes.CREATED_BY, -- 近似
    [RelationTypes.MENTOR_OF]    = "student_of",          -- 自定义反义
}

return {
    Types = RelationTypes,
    Symmetric = SymmetricRelations,
    Inverse = InverseRelations,
}
```

### 5.2 关系管理 API

```lua
------------------------------------------------------------
-- 关系管理（集成到 LoreDB 中）
------------------------------------------------------------

--- 建立实体关系
---@param sourceId string 源实体 ID
---@param targetId string 目标实体 ID
---@param relationType string 关系类型
---@param data table|nil 关系附加数据（如权重、描述）
---@return boolean success
function LoreDB:Link(sourceId, targetId, relationType, data)
    if not self.entities[sourceId] then
        log:Write(LOG_ERROR, "LoreDB: source entity '" .. sourceId .. "' not found")
        return false
    end
    if not self.entities[targetId] then
        log:Write(LOG_ERROR, "LoreDB: target entity '" .. targetId .. "' not found")
        return false
    end

    local relation = {
        targetId = targetId,
        type = relationType,
        data = data or {},
    }

    -- 检查重复
    self.relations[sourceId] = self.relations[sourceId] or {}
    for _, existing in ipairs(self.relations[sourceId]) do
        if existing.targetId == targetId and existing.type == relationType then
            log:Write(LOG_WARNING, "LoreDB: relation already exists, skipping")
            return false
        end
    end

    table.insert(self.relations[sourceId], relation)
    self.meta.relationCount = self.meta.relationCount + 1

    -- 对称关系：自动创建反向
    local RelTypes = require("lore.RelationTypes")
    if RelTypes.Symmetric[relationType] then
        self.relations[targetId] = self.relations[targetId] or {}
        local reverse = {
            targetId = sourceId,
            type = relationType,
            data = data or {},
        }
        table.insert(self.relations[targetId], reverse)
        self.meta.relationCount = self.meta.relationCount + 1
    end

    local srcName = self.entities[sourceId].name
    local tgtName = self.entities[targetId].name
    log:Write(LOG_INFO, "LoreDB: linked " .. srcName .. " --[" .. relationType .. "]--> " .. tgtName)
    return true
end

--- 解除实体关系
---@param sourceId string 源实体 ID
---@param targetId string 目标实体 ID
---@param relationType string|nil 关系类型（nil 则解除所有）
---@return number removedCount
function LoreDB:Unlink(sourceId, targetId, relationType)
    local count = 0
    local rels = self.relations[sourceId]
    if not rels then return 0 end

    for i = #rels, 1, -1 do
        if rels[i].targetId == targetId then
            if relationType == nil or rels[i].type == relationType then
                table.remove(rels, i)
                count = count + 1
            end
        end
    end

    self.meta.relationCount = self.meta.relationCount - count
    return count
end

--- 获取实体的所有关系
---@param id string 实体 ID
---@param relationType string|nil 过滤关系类型
---@return table[] relations
function LoreDB:GetRelations(id, relationType)
    local rels = self.relations[id] or {}
    if not relationType then return rels end

    local filtered = {}
    for _, rel in ipairs(rels) do
        if rel.type == relationType then
            filtered[#filtered + 1] = rel
        end
    end
    return filtered
end

--- 获取实体的关联实体
---@param id string 实体 ID
---@param relationType string|nil 过滤关系类型
---@return table[] entities
function LoreDB:GetRelated(id, relationType)
    local rels = self:GetRelations(id, relationType)
    local result = {}
    for _, rel in ipairs(rels) do
        local entity = self.entities[rel.targetId]
        if entity then
            result[#result + 1] = entity
        end
    end
    return result
end

--- 清除实体的所有关系（内部方法）
function LoreDB:_removeAllRelations(id)
    -- 删除以 id 为源的关系
    local rels = self.relations[id] or {}
    self.meta.relationCount = self.meta.relationCount - #rels
    self.relations[id] = nil

    -- 删除以 id 为目标的关系
    for otherId, otherRels in pairs(self.relations) do
        for i = #otherRels, 1, -1 do
            if otherRels[i].targetId == id then
                table.remove(otherRels, i)
                self.meta.relationCount = self.meta.relationCount - 1
            end
        end
    end
end

--- 查找两个实体之间的关系路径（BFS）
---@param fromId string 起始实体 ID
---@param toId string 目标实体 ID
---@param maxDepth number|nil 最大搜索深度（默认 5）
---@return table|nil path 路径数组 [{id, relation}, ...]
function LoreDB:FindPath(fromId, toId, maxDepth)
    maxDepth = maxDepth or 5
    if fromId == toId then return {} end

    local visited = { [fromId] = true }
    local queue = { { id = fromId, path = {} } }
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        if #current.path >= maxDepth then break end

        for _, rel in ipairs(self.relations[current.id] or {}) do
            if not visited[rel.targetId] then
                local newPath = {}
                for _, p in ipairs(current.path) do
                    newPath[#newPath + 1] = p
                end
                newPath[#newPath + 1] = {
                    id = rel.targetId,
                    name = (self.entities[rel.targetId] or {}).name or "?",
                    relation = rel.type,
                }

                if rel.targetId == toId then
                    return newPath
                end

                visited[rel.targetId] = true
                queue[#queue + 1] = { id = rel.targetId, path = newPath }
            end
        end
    end

    return nil  -- 未找到路径
end
```

---

## §6 高级查询引擎

### 6.1 多条件组合查询

```lua
------------------------------------------------------------
-- 查询引擎（集成到 LoreDB 中）
------------------------------------------------------------

--- 组合查询
---@param criteria table 查询条件
---@return table[] entities 匹配的实体列表
function LoreDB:Query(criteria)
    --[[
    criteria 结构:
    {
        type = "character",              -- 按类型过滤
        tags = { "骑士", "主角" },        -- 必须包含所有这些标签
        tagsAny = { "人类", "精灵" },     -- 包含任一标签即可
        nameContains = "艾琳",           -- 名称包含
        descContains = "骑士团",          -- 描述包含
        fieldEquals = { race = "人类" },  -- 字段精确匹配
        fieldContains = { backstory = "覆灭" }, -- 字段包含
        hasRelation = "belongs_to",       -- 拥有某种关系
        relatedTo = "fac_001",           -- 与某实体有关系
        limit = 10,                      -- 结果数量限制
    }
    ]]

    local results = {}

    for id, entity in pairs(self.entities) do
        local match = true

        -- 类型过滤
        if criteria.type and entity.type ~= criteria.type then
            match = false
        end

        -- 标签过滤（全部匹配）
        if match and criteria.tags then
            for _, reqTag in ipairs(criteria.tags) do
                local found = false
                for _, tag in ipairs(entity.tags) do
                    if tag == reqTag then found = true; break end
                end
                if not found then match = false; break end
            end
        end

        -- 标签过滤（任一匹配）
        if match and criteria.tagsAny then
            local anyMatch = false
            for _, reqTag in ipairs(criteria.tagsAny) do
                for _, tag in ipairs(entity.tags) do
                    if tag == reqTag then anyMatch = true; break end
                end
                if anyMatch then break end
            end
            if not anyMatch then match = false end
        end

        -- 名称包含
        if match and criteria.nameContains then
            if not string.find(string.lower(entity.name), string.lower(criteria.nameContains), 1, true) then
                match = false
            end
        end

        -- 描述包含
        if match and criteria.descContains then
            if not string.find(string.lower(entity.description), string.lower(criteria.descContains), 1, true) then
                match = false
            end
        end

        -- 字段精确匹配
        if match and criteria.fieldEquals then
            for k, v in pairs(criteria.fieldEquals) do
                if entity.fields[k] ~= v then
                    match = false; break
                end
            end
        end

        -- 字段包含
        if match and criteria.fieldContains then
            for k, v in pairs(criteria.fieldContains) do
                local fieldVal = entity.fields[k]
                if type(fieldVal) ~= "string" or
                   not string.find(string.lower(fieldVal), string.lower(v), 1, true) then
                    match = false; break
                end
            end
        end

        -- 关系过滤
        if match and criteria.hasRelation then
            local rels = self:GetRelations(id, criteria.hasRelation)
            if #rels == 0 then match = false end
        end

        if match and criteria.relatedTo then
            local rels = self:GetRelations(id)
            local relFound = false
            for _, rel in ipairs(rels) do
                if rel.targetId == criteria.relatedTo then
                    relFound = true; break
                end
            end
            if not relFound then match = false end
        end

        if match then
            results[#results + 1] = entity
        end

        -- 数量限制
        if criteria.limit and #results >= criteria.limit then
            break
        end
    end

    return results
end

--- 全文搜索
---@param keyword string 搜索关键词
---@param entityType string|nil 限制搜索类型
---@return table[] results { entity, matchField, matchContext }
function LoreDB:Search(keyword, entityType)
    local results = {}
    local lowerKey = string.lower(keyword)

    for id, entity in pairs(self.entities) do
        if not entityType or entity.type == entityType then
            -- 搜索名称
            if string.find(string.lower(entity.name), lowerKey, 1, true) then
                results[#results + 1] = {
                    entity = entity,
                    matchField = "name",
                    matchContext = entity.name,
                }
            end
            -- 搜索描述
            if string.find(string.lower(entity.description), lowerKey, 1, true) then
                results[#results + 1] = {
                    entity = entity,
                    matchField = "description",
                    matchContext = entity.description,
                }
            end
            -- 搜索字段
            for k, v in pairs(entity.fields) do
                if type(v) == "string" and string.find(string.lower(v), lowerKey, 1, true) then
                    results[#results + 1] = {
                        entity = entity,
                        matchField = k,
                        matchContext = v,
                    }
                end
            end
        end
    end

    return results
end
```

---

## §7 连续性检查器

### 7.1 世界观一致性验证

notebook.ai 的核心特色之一是防止设定自相矛盾。

```lua
------------------------------------------------------------
-- scripts/lore/ConsistencyChecker.lua
-- 世界观连续性/一致性检查器
------------------------------------------------------------

local ConsistencyChecker = {}

--- 运行所有一致性检查
---@param db table LoreDB 实例
---@return table report { errors = {}, warnings = {}, info = {} }
function ConsistencyChecker.Check(db)
    local report = {
        errors = {},    -- 严重矛盾
        warnings = {},  -- 潜在问题
        info = {},      -- 信息提示
    }

    ConsistencyChecker._checkOrphanEntities(db, report)
    ConsistencyChecker._checkBrokenRelations(db, report)
    ConsistencyChecker._checkCircularContainment(db, report)
    ConsistencyChecker._checkConflictingRelations(db, report)
    ConsistencyChecker._checkMissingFields(db, report)
    ConsistencyChecker._checkDeadCharacters(db, report)
    ConsistencyChecker._checkLocationCapacity(db, report)

    return report
end

--- 检查孤立实体（无任何关系的实体）
function ConsistencyChecker._checkOrphanEntities(db, report)
    for id, entity in pairs(db.entities) do
        local hasOutgoing = db.relations[id] and #db.relations[id] > 0
        local hasIncoming = false

        if not hasOutgoing then
            for _, rels in pairs(db.relations) do
                for _, rel in ipairs(rels) do
                    if rel.targetId == id then
                        hasIncoming = true; break
                    end
                end
                if hasIncoming then break end
            end
        end

        if not hasOutgoing and not hasIncoming then
            report.warnings[#report.warnings + 1] = {
                type = "orphan_entity",
                entityId = id,
                message = entity.type .. " '" .. entity.name .. "' has no relations to any other entity",
            }
        end
    end
end

--- 检查断裂关系（指向不存在实体的关系）
function ConsistencyChecker._checkBrokenRelations(db, report)
    for sourceId, rels in pairs(db.relations) do
        if not db.entities[sourceId] then
            report.errors[#report.errors + 1] = {
                type = "broken_source",
                entityId = sourceId,
                message = "relations exist for deleted entity '" .. sourceId .. "'",
            }
        else
            for _, rel in ipairs(rels) do
                if not db.entities[rel.targetId] then
                    report.errors[#report.errors + 1] = {
                        type = "broken_target",
                        entityId = sourceId,
                        targetId = rel.targetId,
                        message = db.entities[sourceId].name .. " has relation to deleted entity '" .. rel.targetId .. "'",
                    }
                end
            end
        end
    end
end

--- 检查循环包含关系（A 包含 B，B 包含 A）
function ConsistencyChecker._checkCircularContainment(db, report)
    local RT = require("lore.RelationTypes")

    for id, rels in pairs(db.relations) do
        for _, rel in ipairs(rels) do
            if rel.type == RT.Types.CONTAINS then
                -- 检查目标是否反向包含源
                local targetRels = db.relations[rel.targetId] or {}
                for _, tRel in ipairs(targetRels) do
                    if tRel.type == RT.Types.CONTAINS and tRel.targetId == id then
                        local nameA = (db.entities[id] or {}).name or id
                        local nameB = (db.entities[rel.targetId] or {}).name or rel.targetId
                        report.errors[#report.errors + 1] = {
                            type = "circular_containment",
                            entityId = id,
                            targetId = rel.targetId,
                            message = nameA .. " contains " .. nameB .. " AND " .. nameB .. " contains " .. nameA,
                        }
                    end
                end
            end
        end
    end
end

--- 检查矛盾关系（同时是友好和敌对）
function ConsistencyChecker._checkConflictingRelations(db, report)
    local RT = require("lore.RelationTypes")
    local conflicts = {
        { RT.Types.FRIEND_OF, RT.Types.ENEMY_OF },
        { RT.Types.ALLIED_WITH, RT.Types.HOSTILE_TO },
        { RT.Types.MENTOR_OF, RT.Types.ENEMY_OF },
    }

    for id, rels in pairs(db.relations) do
        for _, conflictPair in ipairs(conflicts) do
            local typeA, typeB = conflictPair[1], conflictPair[2]
            local targetsA, targetsB = {}, {}

            for _, rel in ipairs(rels) do
                if rel.type == typeA then targetsA[rel.targetId] = true end
                if rel.type == typeB then targetsB[rel.targetId] = true end
            end

            for targetId in pairs(targetsA) do
                if targetsB[targetId] then
                    local nameA = (db.entities[id] or {}).name or id
                    local nameB = (db.entities[targetId] or {}).name or targetId
                    report.errors[#report.errors + 1] = {
                        type = "conflicting_relation",
                        entityId = id,
                        targetId = targetId,
                        message = nameA .. " is both " .. typeA .. " and " .. typeB .. " with " .. nameB,
                    }
                end
            end
        end
    end
end

--- 检查必填字段缺失
function ConsistencyChecker._checkMissingFields(db, report)
    local ET = require("lore.EntityTypes")
    for id, entity in pairs(db.entities) do
        local template = ET.Templates[entity.type]
        if template then
            for _, field in ipairs(template.required) do
                local val = entity[field] or entity.fields[field]
                if val == nil or val == "" then
                    report.warnings[#report.warnings + 1] = {
                        type = "missing_field",
                        entityId = id,
                        field = field,
                        message = entity.type .. " '" .. entity.name .. "' is missing required field '" .. field .. "'",
                    }
                end
            end
        end
    end
end

--- 检查已死亡角色是否仍有活跃关系
function ConsistencyChecker._checkDeadCharacters(db, report)
    local RT = require("lore.RelationTypes")
    for id, entity in pairs(db.entities) do
        if entity.type == "character" and entity.fields.status == "dead" then
            local activeRels = { RT.Types.LEADS, RT.Types.GUARDS, RT.Types.OWNS }
            for _, rel in ipairs(db.relations[id] or {}) do
                for _, activeType in ipairs(activeRels) do
                    if rel.type == activeType then
                        local targetName = (db.entities[rel.targetId] or {}).name or rel.targetId
                        report.warnings[#report.warnings + 1] = {
                            type = "dead_active_relation",
                            entityId = id,
                            message = "Dead character '" .. entity.name .. "' still " .. rel.type .. " '" .. targetName .. "'",
                        }
                    end
                end
            end
        end
    end
end

--- 检查地点容量（如果定义了 population）
function ConsistencyChecker._checkLocationCapacity(db, report)
    local RT = require("lore.RelationTypes")
    for id, entity in pairs(db.entities) do
        if entity.type == "location" and entity.fields.population then
            local maxPop = tonumber(entity.fields.population) or 0
            if maxPop > 0 then
                local locatedHere = 0
                for _, rels in pairs(db.relations) do
                    for _, rel in ipairs(rels) do
                        if rel.type == RT.Types.LOCATED_IN and rel.targetId == id then
                            locatedHere = locatedHere + 1
                        end
                    end
                end
                -- 仅作信息提示
                if locatedHere > 0 then
                    report.info[#report.info + 1] = {
                        type = "location_population",
                        entityId = id,
                        message = entity.name .. ": " .. locatedHere .. " named entities located here (population: " .. maxPop .. ")",
                    }
                end
            end
        end
    end
end

return ConsistencyChecker
```

---

## §8 Lore 辅助提问器

### 8.1 世界观补全建议

notebook.ai 的"促进创造力"功能——根据已有数据向开发者提出问题。

```lua
------------------------------------------------------------
-- scripts/lore/LorePrompter.lua
-- 世界观辅助提问/建议生成器
------------------------------------------------------------

local LorePrompter = {}

--- 为实体生成补全建议
---@param db table LoreDB 实例
---@param entityId string 实体 ID
---@return string[] questions 建议列表
function LorePrompter.SuggestForEntity(db, entityId)
    local entity = db:Get(entityId)
    if not entity then return {} end

    local questions = {}
    local ET = require("lore.EntityTypes")
    local template = ET.Templates[entity.type]

    -- 检查未填写的可选字段
    if template then
        for _, field in ipairs(template.optional or {}) do
            if entity.fields[field] == nil then
                local q = LorePrompter._fieldQuestion(entity.type, field, entity.name)
                if q then questions[#questions + 1] = q end
            end
        end
    end

    -- 检查关系缺失
    local rels = db:GetRelations(entityId)
    local relTypes = {}
    for _, rel in ipairs(rels) do
        relTypes[rel.type] = true
    end

    local suggestedRels = LorePrompter._suggestedRelations(entity.type)
    for _, sr in ipairs(suggestedRels) do
        if not relTypes[sr.type] then
            questions[#questions + 1] = sr.question(entity.name)
        end
    end

    return questions
end

--- 为整个世界观生成建议
---@param db table LoreDB 实例
---@return table suggestions { category, items }
function LorePrompter.SuggestForWorld(db)
    local suggestions = {}

    -- 检查实体类型覆盖
    local ET = require("lore.EntityTypes")
    local typeCounts = {}
    for _, typeName in pairs(ET.Types) do
        typeCounts[typeName] = 0
    end
    for _, entity in pairs(db.entities) do
        typeCounts[entity.type] = (typeCounts[entity.type] or 0) + 1
    end

    local missingTypes = {}
    local typeNames = {
        character = "角色", location = "地点", item = "物品",
        creature = "生物", event = "事件", faction = "阵营",
        magic = "魔法/超自然", technology = "科技", lore = "传说/神话",
    }
    for typeName, count in pairs(typeCounts) do
        if count == 0 then
            missingTypes[#missingTypes + 1] = (typeNames[typeName] or typeName)
        end
    end

    if #missingTypes > 0 then
        suggestions[#suggestions + 1] = {
            category = "missing_types",
            message = "以下实体类型尚未创建：" .. table.concat(missingTypes, "、"),
        }
    end

    -- 检查实体密度
    local totalEntities = db.meta.entityCount
    local totalRelations = db.meta.relationCount
    if totalEntities > 5 and totalRelations < totalEntities then
        suggestions[#suggestions + 1] = {
            category = "low_connectivity",
            message = "世界观中有 " .. totalEntities .. " 个实体但只有 " .. totalRelations .. " 条关系，建议补充实体间的关联",
        }
    end

    return suggestions
end

--- 根据字段生成提问
function LorePrompter._fieldQuestion(entityType, field, name)
    local questions = {
        -- 角色字段
        backstory   = name .. " 的过去经历了什么？是什么塑造了现在的他/她？",
        personality = name .. " 的性格特点是什么？在压力下会如何表现？",
        goals       = name .. " 最想实现的目标是什么？",
        secrets     = name .. " 有什么不为人知的秘密？",
        weaknesses  = name .. " 的弱点是什么？什么会让他/她犯错？",
        abilities   = name .. " 拥有什么特殊能力或技能？",

        -- 地点字段
        history     = name .. " 这个地方有什么历史故事？",
        dangers     = name .. " 存在哪些危险？",
        culture     = name .. " 的居民有什么独特文化？",
        landmarks   = name .. " 有哪些标志性地标？",

        -- 物品字段
        origin      = name .. " 是从哪里来的？由谁制作？",
        loreText    = name .. " 背后有什么传说故事？",

        -- 生物字段
        habitat     = name .. " 通常栖息在什么环境？",
        behavior    = name .. " 的习性是什么？如何与人类互动？",

        -- 阵营字段
        ideology    = name .. " 的核心理念/信条是什么？",

        -- 事件字段
        consequences = name .. " 事件带来了什么后果？改变了什么？",
    }

    return questions[field]
end

--- 建议的关系类型
function LorePrompter._suggestedRelations(entityType)
    local RT = require("lore.RelationTypes")
    local suggestions = {
        character = {
            { type = RT.Types.LOCATED_IN,  question = function(n) return n .. " 目前在哪个地点？" end },
            { type = RT.Types.BELONGS_TO,  question = function(n) return n .. " 属于哪个组织/阵营？" end },
            { type = RT.Types.KNOWS,       question = function(n) return n .. " 认识哪些其他角色？" end },
            { type = RT.Types.OWNS,        question = function(n) return n .. " 携带或拥有什么重要物品？" end },
        },
        location = {
            { type = RT.Types.CONTAINS,    question = function(n) return n .. " 包含哪些子区域或地标？" end },
            { type = RT.Types.CONNECTED_TO, question = function(n) return n .. " 与哪些地点相连？" end },
        },
        item = {
            { type = RT.Types.CREATED_BY,  question = function(n) return n .. " 是由谁创造/制作的？" end },
        },
        faction = {
            { type = RT.Types.ALLIED_WITH, question = function(n) return n .. " 与哪些阵营结盟？" end },
            { type = RT.Types.HOSTILE_TO,  question = function(n) return n .. " 与哪些阵营敌对？" end },
        },
    }
    return suggestions[entityType] or {}
end

return LorePrompter
```

---

## §9 持久化管理

### 9.1 JSON 序列化/反序列化

```lua
------------------------------------------------------------
-- scripts/lore/LorePersistence.lua
-- 世界观数据持久化（JSON 文件读写）
------------------------------------------------------------

local json = require("cjson")

local LorePersistence = {}

--- 保存世界观数据库到 JSON 文件
---@param db table LoreDB 实例
---@param filename string 文件名（如 "lore_data.json"）
---@return boolean success
function LorePersistence.Save(db, filename)
    local saveData = {
        _format = "world-lore-notebook",
        _version = "1.0",
        config = db.config,
        meta = db.meta,
        entities = {},
        relations = {},
    }

    -- 序列化实体
    for id, entity in pairs(db.entities) do
        saveData.entities[#saveData.entities + 1] = entity
    end

    -- 序列化关系
    for sourceId, rels in pairs(db.relations) do
        for _, rel in ipairs(rels) do
            saveData.relations[#saveData.relations + 1] = {
                sourceId = sourceId,
                targetId = rel.targetId,
                type = rel.type,
                data = rel.data,
            }
        end
    end

    -- 写入文件
    local jsonStr = json.encode(saveData)

    local file = File:new(filename, FILE_WRITE)
    if not file then
        log:Write(LOG_ERROR, "LorePersistence: failed to open file for writing: " .. filename)
        return false
    end

    file:WriteString(jsonStr)
    file:Close()

    log:Write(LOG_INFO, "LorePersistence: saved " .. #saveData.entities .. " entities and "
              .. #saveData.relations .. " relations to " .. filename)
    return true
end

--- 从 JSON 文件加载世界观数据库
---@param filename string 文件名
---@return table|nil db LoreDB 实例，失败返回 nil
function LorePersistence.Load(filename)
    local file = File:new(filename, FILE_READ)
    if not file then
        log:Write(LOG_WARNING, "LorePersistence: file not found: " .. filename)
        return nil
    end

    local content = file:ReadString()
    file:Close()

    if not content or content == "" then
        log:Write(LOG_ERROR, "LorePersistence: empty file: " .. filename)
        return nil
    end

    local ok, saveData = pcall(json.decode, content)
    if not ok then
        log:Write(LOG_ERROR, "LorePersistence: JSON parse error in " .. filename)
        return nil
    end

    -- 验证格式
    if saveData._format ~= "world-lore-notebook" then
        log:Write(LOG_ERROR, "LorePersistence: invalid format in " .. filename)
        return nil
    end

    -- 创建新数据库并导入数据
    local LoreDB = require("lore.LoreDB")
    local db = LoreDB.New(saveData.config)

    -- 导入实体
    for _, entityData in ipairs(saveData.entities or {}) do
        local regData = {
            id = entityData.id,
            name = entityData.name,
            description = entityData.description,
            tags = entityData.tags,
            notes = entityData.notes,
            createdAt = entityData.meta and entityData.meta.createdAt or "",
        }
        -- 合并字段
        for k, v in pairs(entityData.fields or {}) do
            regData[k] = v
        end
        db:Register(entityData.type, regData)
    end

    -- 导入关系（跳过对称关系的自动副本）
    local importedPairs = {}
    for _, relData in ipairs(saveData.relations or {}) do
        local pairKey = relData.sourceId .. "|" .. relData.targetId .. "|" .. relData.type
        local reversePairKey = relData.targetId .. "|" .. relData.sourceId .. "|" .. relData.type
        if not importedPairs[pairKey] and not importedPairs[reversePairKey] then
            db:Link(relData.sourceId, relData.targetId, relData.type, relData.data)
            importedPairs[pairKey] = true
        end
    end

    log:Write(LOG_INFO, "LorePersistence: loaded from " .. filename)
    return db
end

--- 导出为可读文本格式
---@param db table LoreDB 实例
---@return string text 格式化文本
function LorePersistence.ExportText(db)
    local lines = {}
    lines[#lines + 1] = "═══════════════════════════════════"
    lines[#lines + 1] = "  " .. (db.config.name or "World Lore")
    lines[#lines + 1] = "═══════════════════════════════════"
    lines[#lines + 1] = ""

    local ET = require("lore.EntityTypes")
    local typeOrder = {
        "character", "location", "item", "creature",
        "event", "faction", "magic", "technology", "lore",
    }
    local typeLabels = {
        character = "CHARACTERS", location = "LOCATIONS",
        item = "ITEMS", creature = "CREATURES",
        event = "EVENTS", faction = "FACTIONS",
        magic = "MAGIC/SUPERNATURAL", technology = "TECHNOLOGY",
        lore = "LORE/LEGENDS",
    }

    for _, typeName in ipairs(typeOrder) do
        local entities = db:ListByType(typeName)
        if #entities > 0 then
            lines[#lines + 1] = "── " .. (typeLabels[typeName] or typeName:upper()) .. " ──"
            lines[#lines + 1] = ""

            for _, entity in ipairs(entities) do
                lines[#lines + 1] = "  [" .. entity.id .. "] " .. entity.name
                lines[#lines + 1] = "  " .. entity.description
                if #entity.tags > 0 then
                    lines[#lines + 1] = "  Tags: " .. table.concat(entity.tags, ", ")
                end

                -- 关系
                local rels = db:GetRelations(entity.id)
                if #rels > 0 then
                    for _, rel in ipairs(rels) do
                        local target = db:Get(rel.targetId)
                        local targetName = target and target.name or rel.targetId
                        lines[#lines + 1] = "    → " .. rel.type .. " → " .. targetName
                    end
                end
                lines[#lines + 1] = ""
            end
        end
    end

    return table.concat(lines, "\n")
end

return LorePersistence
```

---

## §10 运行时游戏集成

### 10.1 在游戏中查询 Lore 数据

将世界观数据库作为游戏运行时的数据层，为对话、百科、物品描述等系统提供数据。

```lua
------------------------------------------------------------
-- scripts/lore/LoreRuntime.lua
-- 运行时 Lore 查询接口（供游戏系统调用）
------------------------------------------------------------

local LoreRuntime = {}
LoreRuntime.__index = LoreRuntime

--- 初始化运行时 Lore 查询器
---@param db table LoreDB 实例
---@return table runtime
function LoreRuntime.New(db)
    local rt = setmetatable({}, LoreRuntime)
    rt.db = db
    return rt
end

--- 获取 NPC 对话可引用的信息
---@param npcId string NPC 实体 ID
---@return table info { name, description, faction, location, relationships }
function LoreRuntime:GetNPCInfo(npcId)
    local entity = self.db:Get(npcId)
    if not entity then return nil end

    local RT = require("lore.RelationTypes")

    local info = {
        name = entity.name,
        description = entity.description,
        personality = entity.fields.personality,
        dialogueStyle = entity.fields.dialogueStyle,
        occupation = entity.fields.occupation,
    }

    -- 获取所属阵营
    local factions = self.db:GetRelated(npcId, RT.Types.BELONGS_TO)
    if #factions > 0 then
        info.faction = factions[1].name
    end

    -- 获取所在地点
    local locations = self.db:GetRelated(npcId, RT.Types.LOCATED_IN)
    if #locations > 0 then
        info.location = locations[1].name
    end

    -- 获取认识的人
    info.knownCharacters = {}
    local knows = self.db:GetRelated(npcId, RT.Types.KNOWS)
    for _, char in ipairs(knows) do
        info.knownCharacters[#info.knownCharacters + 1] = char.name
    end

    return info
end

--- 获取物品百科描述
---@param itemId string 物品实体 ID
---@return table info
function LoreRuntime:GetItemInfo(itemId)
    local entity = self.db:Get(itemId)
    if not entity then return nil end

    local RT = require("lore.RelationTypes")

    local info = {
        name = entity.name,
        description = entity.description,
        type = entity.fields.type,
        rarity = entity.fields.rarity,
        effects = entity.fields.effects,
        loreText = entity.fields.loreText,
    }

    -- 获取制作者
    local creators = self.db:GetRelated(itemId, RT.Types.CREATED_BY)
    if #creators > 0 then
        info.creator = creators[1].name
    end

    return info
end

--- 获取地点信息（用于加载屏幕、地图提示等）
---@param locId string 地点实体 ID
---@return table info
function LoreRuntime:GetLocationInfo(locId)
    local entity = self.db:Get(locId)
    if not entity then return nil end

    local RT = require("lore.RelationTypes")

    local info = {
        name = entity.name,
        description = entity.description,
        climate = entity.fields.climate,
        dangers = entity.fields.dangers,
    }

    -- 获取子区域
    info.subLocations = {}
    local contained = self.db:GetRelated(locId, RT.Types.CONTAINS)
    for _, loc in ipairs(contained) do
        info.subLocations[#info.subLocations + 1] = { name = loc.name, id = loc.id }
    end

    -- 获取连通地点
    info.connectedTo = {}
    local connected = self.db:GetRelated(locId, RT.Types.CONNECTED_TO)
    for _, loc in ipairs(connected) do
        info.connectedTo[#info.connectedTo + 1] = { name = loc.name, id = loc.id }
    end

    -- 获取驻扎角色
    info.residents = {}
    for _, rels in pairs(self.db.relations) do
        for _, rel in ipairs(rels) do
            if rel.type == RT.Types.LOCATED_IN and rel.targetId == locId then
                -- 找到源实体
                for srcId, srcRels in pairs(self.db.relations) do
                    if srcRels == rels then
                        local srcEntity = self.db:Get(srcId)
                        if srcEntity and srcEntity.type == "character" then
                            info.residents[#info.residents + 1] = { name = srcEntity.name, id = srcId }
                        end
                    end
                end
            end
        end
    end

    return info
end

--- 搜索百科词条（用于游戏内百科系统）
---@param keyword string 搜索关键词
---@return table[] results { id, name, type, preview }
function LoreRuntime:SearchEncyclopedia(keyword)
    local searchResults = self.db:Search(keyword)
    local seen = {}
    local results = {}

    for _, sr in ipairs(searchResults) do
        if not seen[sr.entity.id] then
            seen[sr.entity.id] = true
            results[#results + 1] = {
                id = sr.entity.id,
                name = sr.entity.name,
                type = sr.entity.type,
                preview = string.sub(sr.entity.description, 1, 80),
            }
        end
    end

    return results
end

return LoreRuntime
```

---

## §11 完整集成示例

### 11.1 RPG 世界观构建与游戏集成

```lua
------------------------------------------------------------
-- scripts/main.lua
-- 完整的 RPG 世界观数据库 + 游戏内百科系统
-- 脚手架: scaffold-3d-scene.lua
------------------------------------------------------------

require "LuaScripts/Utilities/Sample"

-- Lore 模块
local LoreDB = require("lore.LoreDB")
local ET = require("lore.EntityTypes")
local RT = require("lore.RelationTypes")
local Checker = require("lore.ConsistencyChecker")
local Prompter = require("lore.LorePrompter")
local Persistence = require("lore.LorePersistence")
local LoreRuntime = require("lore.LoreRuntime")

-- UI 模块
local UI = require("urhox-libs/UI")

---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local loreDB = nil
local runtime = nil

function Start()
    SampleStart()

    -- 初始化 UI
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- 创建相机
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    cameraNode_.position = Vector3(0, 5, -10)
    cameraNode_:LookAt(Vector3(0, 0, 0))
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- 初始化世界观数据库
    InitializeLoreDatabase()

    -- 构建百科 UI
    BuildEncyclopediaUI()

    log:Write(LOG_INFO, "[Main] World Lore Notebook demo started")
    SubscribeToEvent("Update", "HandleUpdate")
end

function InitializeLoreDatabase()
    -- 尝试从存档加载
    loreDB = Persistence.Load("world_lore.json")

    if not loreDB then
        -- 首次运行：创建新数据库并填充示例数据
        loreDB = LoreDB.New({ name = "暮光纪元" })

        -- ── 注册角色 ──
        loreDB:Register(ET.Types.CHARACTER, {
            name = "艾琳·暮光",
            description = "最后一位暮光骑士团的传承者",
            tags = { "主角", "骑士", "人类" },
            age = 24, gender = "female", race = "人类",
            occupation = "暮光骑士",
            personality = "表面冷静内心温柔",
            abilities = { "暮光斩", "月光盾" },
            goals = { "终结永夜" },
        })

        loreDB:Register(ET.Types.CHARACTER, {
            name = "老铁匠格兰特",
            description = "晨星镇最有名的铁匠，暗中是暮光骑士团的支持者",
            tags = { "NPC", "铁匠", "人类" },
            age = 58, gender = "male", race = "人类",
            occupation = "铁匠",
            secrets = { "年轻时是暮光骑士团后勤官" },
        })

        -- ── 注册地点 ──
        loreDB:Register(ET.Types.LOCATION, {
            name = "晨星镇",
            description = "位于暮光大陆东部的贸易小镇",
            tags = { "城镇", "安全区" },
            climate = "温带", population = "约2000人",
        })

        loreDB:Register(ET.Types.LOCATION, {
            name = "永夜森林",
            description = "被永夜诅咒笼罩的禁忌之森",
            tags = { "危险区域", "森林" },
            climate = "永夜", dangers = { "暗影生物", "迷路诅咒" },
        })

        -- ── 注册阵营 ──
        loreDB:Register(ET.Types.FACTION, {
            name = "暮光骑士团",
            description = "守护世界免受永夜侵蚀的古老骑士团",
            tags = { "骑士团", "正义" },
            ideology = "以光明驱散黑暗",
        })

        loreDB:Register(ET.Types.FACTION, {
            name = "永夜军团",
            description = "渴望将世界笼罩在永恒黑暗中的邪恶势力",
            tags = { "反派", "邪恶" },
            ideology = "黑暗即是真理",
        })

        -- ── 注册物品 ──
        loreDB:Register(ET.Types.ITEM, {
            name = "暮光之剑",
            description = "暮光骑士团代代相传的圣剑，能斩断黑暗",
            tags = { "武器", "圣物", "传说" },
            rarity = "传说",
            loreText = "据说此剑锻造于第一缕暮光之中",
        })

        -- ── 注册生物 ──
        loreDB:Register(ET.Types.CREATURE, {
            name = "暗影狼",
            description = "永夜森林中出没的被黑暗腐化的巨狼",
            tags = { "敌人", "暗影" },
            habitat = "永夜森林",
            dangerLevel = "中等",
            behavior = "群体狩猎，惧怕光明",
            drops = { "暗影牙", "黑狼皮" },
        })

        -- ── 注册事件 ──
        loreDB:Register(ET.Types.EVENT, {
            name = "骑士团覆灭之夜",
            description = "永夜军团突袭暮光骑士团总部，几乎将其团灭",
            tags = { "历史", "悲剧" },
            date = "暮光历 487 年",
            consequences = { "骑士团几乎覆灭", "艾琳成为幸存者" },
        })

        -- ── 注册传说 ──
        loreDB:Register(ET.Types.LORE, {
            name = "永夜预言",
            description = "古老预言：当最后一位暮光骑士找到黎明之心，永夜将终结",
            tags = { "预言", "主线" },
            reliability = "未知",
            prophecy = "暮光尽处，黎明重生。持剑者寻心，夜幕终散。",
        })

        -- ── 建立关系 ──
        local erin = loreDB:FindByName("艾琳·暮光")
        local grant = loreDB:FindByName("老铁匠格兰特")
        local town = loreDB:FindByName("晨星镇")
        local forest = loreDB:FindByName("永夜森林")
        local knights = loreDB:FindByName("暮光骑士团")
        local darkForce = loreDB:FindByName("永夜军团")
        local sword = loreDB:FindByName("暮光之剑")
        local wolf = loreDB:FindByName("暗影狼")

        if erin and town then
            loreDB:Link(erin.id, town.id, RT.Types.LOCATED_IN)
        end
        if grant and town then
            loreDB:Link(grant.id, town.id, RT.Types.LOCATED_IN)
        end
        if erin and knights then
            loreDB:Link(erin.id, knights.id, RT.Types.BELONGS_TO)
        end
        if erin and sword then
            loreDB:Link(erin.id, sword.id, RT.Types.OWNS)
        end
        if erin and grant then
            loreDB:Link(erin.id, grant.id, RT.Types.KNOWS, { trust = "high" })
        end
        if knights and darkForce then
            loreDB:Link(knights.id, darkForce.id, RT.Types.HOSTILE_TO)
        end
        if town and forest then
            loreDB:Link(town.id, forest.id, RT.Types.CONNECTED_TO)
        end
        if wolf and forest then
            loreDB:Link(wolf.id, forest.id, RT.Types.LOCATED_IN)
        end

        -- 保存初始数据
        Persistence.Save(loreDB, "world_lore.json")
        log:Write(LOG_INFO, "[Main] Created new lore database with sample data")
    end

    -- 初始化运行时查询器
    runtime = LoreRuntime.New(loreDB)

    -- 运行一致性检查
    local report = Checker.Check(loreDB)
    if #report.errors > 0 then
        for _, err in ipairs(report.errors) do
            log:Write(LOG_ERROR, "[Consistency] " .. err.message)
        end
    end
    if #report.warnings > 0 then
        for _, warn in ipairs(report.warnings) do
            log:Write(LOG_WARNING, "[Consistency] " .. warn.message)
        end
    end

    -- 生成补全建议
    local suggestions = Prompter.SuggestForWorld(loreDB)
    for _, s in ipairs(suggestions) do
        log:Write(LOG_INFO, "[Prompter] " .. s.message)
    end
end

function BuildEncyclopediaUI()
    local ET_local = require("lore.EntityTypes")
    -- 获取所有实体并按类型分组
    local typeLabels = {
        { type = "character", label = "角色" },
        { type = "location",  label = "地点" },
        { type = "item",      label = "物品" },
        { type = "creature",  label = "生物" },
        { type = "faction",   label = "阵营" },
        { type = "event",     label = "事件" },
        { type = "magic",     label = "魔法" },
        { type = "technology", label = "科技" },
        { type = "lore",      label = "传说" },
    }

    local tabButtons = {}
    local contentPanel = nil

    -- 构建标签按钮
    for _, tl in ipairs(typeLabels) do
        local entities = loreDB:ListByType(tl.type)
        if #entities > 0 then
            tabButtons[#tabButtons + 1] = UI.Button {
                text = tl.label .. " (" .. #entities .. ")",
                variant = "outline",
                size = "sm",
                onClick = function()
                    ShowEntityList(tl.type, tl.label, contentPanel)
                end,
            }
        end
    end

    -- 主界面
    local root = UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 标题栏
            UI.Panel {
                width = "100%", height = 50,
                justifyContent = "center", alignItems = "center",
                backgroundColor = "#1a1a2e",
                children = {
                    UI.Label {
                        text = "[ " .. (loreDB.config.name or "World Lore") .. " — Encyclopedia ]",
                        fontSize = 20, color = "#e0e0ff",
                    },
                },
            },
            -- 标签栏
            UI.Panel {
                width = "100%", height = 44,
                flexDirection = "row", gap = 6,
                paddingLeft = 10, paddingTop = 4,
                backgroundColor = "#16213e",
                children = tabButtons,
            },
            -- 内容区
            UI.Panel {
                id = "content_area",
                width = "100%", flexGrow = 1,
                padding = 10,
                backgroundColor = "#0f3460",
                overflow = "scroll",
                children = {
                    UI.Label {
                        text = "选择一个分类查看世界观百科",
                        fontSize = 16, color = "#8888aa",
                    },
                },
            },
        },
    }

    contentPanel = root:findById("content_area")
    UI.SetRoot(root)
end

function ShowEntityList(entityType, label, contentPanel)
    if not contentPanel then return end

    local entities = loreDB:ListByType(entityType)
    local children = {}

    children[#children + 1] = UI.Label {
        text = "── " .. label .. " ──",
        fontSize = 18, color = "#e0e0ff",
        marginBottom = 10,
    }

    for _, entity in ipairs(entities) do
        local tags = #entity.tags > 0 and table.concat(entity.tags, " | ") or ""
        local rels = loreDB:GetRelations(entity.id)
        local relTexts = {}
        for _, rel in ipairs(rels) do
            local target = loreDB:Get(rel.targetId)
            if target then
                relTexts[#relTexts + 1] = rel.type .. " → " .. target.name
            end
        end

        children[#children + 1] = UI.Panel {
            width = "100%",
            padding = 10, marginBottom = 8,
            borderRadius = 6,
            backgroundColor = "#1a1a3e",
            flexDirection = "column", gap = 4,
            children = {
                UI.Label { text = entity.name, fontSize = 16, fontWeight = "bold", color = "#ffcc66" },
                UI.Label { text = entity.description, fontSize = 13, color = "#ccccdd" },
                (#tags > 0) and UI.Label { text = "Tags: " .. tags, fontSize = 11, color = "#8888aa" } or nil,
                (#relTexts > 0) and UI.Label {
                    text = "Relations: " .. table.concat(relTexts, " ; "),
                    fontSize = 11, color = "#66aaff",
                } or nil,
            },
        }
    end

    contentPanel:replaceChildren(children)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    -- 运行时查询示例（按需调用）
    -- local npcInfo = runtime:GetNPCInfo("char_002")
    -- local searchResults = runtime:SearchEncyclopedia("暮光")
end

function Stop()
    -- 退出时保存
    if loreDB then
        Persistence.Save(loreDB, "world_lore.json")
        log:Write(LOG_INFO, "[Main] Lore database saved on exit")
    end
end
```

---

## §12 批量构建世界观

### 12.1 快速数据导入模式

对于有大量设定的项目，提供批量注册模式：

```lua
------------------------------------------------------------
-- scripts/lore/LoreBatchImport.lua
-- 批量导入世界观数据
------------------------------------------------------------

local LoreBatchImport = {}

--- 从定义表批量注册实体
---@param db table LoreDB 实例
---@param definitions table[] 实体定义列表
---@return number count 成功注册数
function LoreBatchImport.RegisterAll(db, definitions)
    local count = 0
    for _, def in ipairs(definitions) do
        local entity = db:Register(def.type, def)
        if entity then count = count + 1 end
    end
    log:Write(LOG_INFO, "LoreBatchImport: registered " .. count .. "/" .. #definitions .. " entities")
    return count
end

--- 从关系表批量建立关系
---@param db table LoreDB 实例
---@param links table[] 关系定义 { sourceName, targetName, relType, data }
---@return number count 成功建立数
function LoreBatchImport.LinkAll(db, links)
    local count = 0
    for _, link in ipairs(links) do
        local source = db:FindByName(link.sourceName) or db:Get(link.sourceId or "")
        local target = db:FindByName(link.targetName) or db:Get(link.targetId or "")
        if source and target then
            if db:Link(source.id, target.id, link.relType, link.data) then
                count = count + 1
            end
        else
            log:Write(LOG_WARNING, "LoreBatchImport: could not find entity for link: "
                      .. tostring(link.sourceName or link.sourceId) .. " → " .. tostring(link.targetName or link.targetId))
        end
    end
    log:Write(LOG_INFO, "LoreBatchImport: linked " .. count .. "/" .. #links .. " relations")
    return count
end

return LoreBatchImport
```

### 12.2 使用示例

```lua
local Batch = require("lore.LoreBatchImport")
local ET = require("lore.EntityTypes")
local RT = require("lore.RelationTypes")

-- 批量注册角色
Batch.RegisterAll(loreDB, {
    { type = ET.Types.CHARACTER, name = "商人马库斯", description = "走遍大陆的旅行商人",
      tags = { "NPC", "商人" }, occupation = "旅行商人" },
    { type = ET.Types.CHARACTER, name = "女祭司莉娜", description = "晨星镇神殿的首席祭司",
      tags = { "NPC", "祭司" }, occupation = "祭司" },
    { type = ET.Types.CHARACTER, name = "暗影将军塔洛斯", description = "永夜军团的先锋大将",
      tags = { "BOSS", "敌人" }, occupation = "将军" },
})

-- 批量建立关系
Batch.LinkAll(loreDB, {
    { sourceName = "商人马库斯", targetName = "晨星镇", relType = RT.Types.LOCATED_IN },
    { sourceName = "女祭司莉娜", targetName = "晨星镇", relType = RT.Types.LOCATED_IN },
    { sourceName = "暗影将军塔洛斯", targetName = "永夜军团", relType = RT.Types.BELONGS_TO },
    { sourceName = "暗影将军塔洛斯", targetName = "永夜森林", relType = RT.Types.LOCATED_IN },
    { sourceName = "商人马库斯", targetName = "艾琳·暮光", relType = RT.Types.KNOWS },
})
```

---

## §13 与其他 Skill 的协作

| 场景 | 本 Skill 职责 | 协作 Skill |
|------|-------------|-----------|
| 游戏设计 → 世界观 | 存储和管理所有实体设定 | `game-forge-design` 输出设定 → 本 skill 结构化存储 |
| NPC 行为 | 提供 NPC 背景数据 | `gaia-npc-ai` 读取角色性格/关系驱动 AI 行为 |
| 游戏对话 | 提供对话上下文 | `gaia-npc-ai` 的对话系统引用 Lore 数据 |
| UI 展示 | 提供百科内容 | UI 组件 (`urhox-libs/UI`) 渲染百科界面 |
| 存档 | JSON 序列化到本地 | `game-save-system` 统一管理存档 |
| 内容工厂 | 提供世界观素材 | `game-content-factory` 引用设定生成文案 |

---

## §14 构建与调试

### 14.1 项目结构

```
scripts/
├── main.lua                  # 入口文件（含 Start 函数）
└── lore/
    ├── LoreDB.lua            # 核心数据库
    ├── EntityTypes.lua        # 实体类型枚举
    ├── RelationTypes.lua      # 关系类型枚举
    ├── ConsistencyChecker.lua # 一致性检查器
    ├── LorePrompter.lua       # 辅助提问器
    ├── LorePersistence.lua    # 持久化管理
    ├── LoreRuntime.lua        # 运行时查询
    └── LoreBatchImport.lua    # 批量导入
```

### 14.2 构建步骤

1. 将所有 `scripts/lore/*.lua` 文件放入 `scripts/lore/` 目录
2. 在 `scripts/main.lua` 中 require 所需模块
3. 调用 MCP 构建工具进行构建
4. 首次运行会自动创建示例数据并保存到 `world_lore.json`

### 14.3 调试技巧

```lua
-- 输出世界观摘要
log:Write(LOG_INFO, "Entities: " .. loreDB.meta.entityCount)
log:Write(LOG_INFO, "Relations: " .. loreDB.meta.relationCount)

-- 输出可读文本
local text = Persistence.ExportText(loreDB)
log:Write(LOG_INFO, text)

-- 运行一致性检查
local report = Checker.Check(loreDB)
for _, err in ipairs(report.errors) do
    log:Write(LOG_ERROR, "[CHECK] " .. err.message)
end

-- 测试搜索
local results = loreDB:Search("暮光")
for _, r in ipairs(results) do
    log:Write(LOG_INFO, "[SEARCH] " .. r.entity.name .. " (" .. r.matchField .. ")")
end
```

---

## §15 设计原则

### 15.1 notebook.ai 核心理念在游戏中的映射

| notebook.ai 特性 | 游戏开发映射 |
|-----------------|------------|
| 一切皆页面 | 一切皆 LoreEntity（统一数据结构） |
| 关系追踪 | RelationEngine（双向/对称/反义关系） |
| 促进创造力 | LorePrompter（自动提问补全） |
| 连续性检查 | ConsistencyChecker（7 项自动检测） |
| 可搜索 | Query/Search 多条件组合检索 |
| 云备份 | JSON 持久化 + 可选 clientCloud 同步 |
| 分类过滤 | 标签系统 + 类型索引 |
| 无限扩展 | 自定义字段 + 自定义实体类型 |

### 15.2 扩展建议

- **自定义实体类型**：在 `EntityTypes.lua` 中添加新类型即可
- **关系权重**：在 `Link()` 的 `data` 参数中传递 `{ weight = 0.8 }`
- **时间线排序**：为事件实体添加 `sortOrder` 字段，查询时排序
- **多语言支持**：实体字段支持 `{ zh = "...", en = "..." }` 结构
- **可视化**：使用 NanoVG 绘制关系图（节点+连线）

---

## §16 API 速查

### LoreDB

| 方法 | 参数 | 返回 | 说明 |
|------|------|------|------|
| `New(config)` | `{ name }` | LoreDB | 创建数据库 |
| `Register(type, data)` | 类型, 实体数据 | entity | 注册实体 |
| `Get(id)` | ID | entity/nil | 获取实体 |
| `FindByName(name)` | 名称 | entity/nil | 按名称查找 |
| `ListByType(type)` | 类型 | entity[] | 列出同类型 |
| `FindByTag(tag)` | 标签 | entity[] | 按标签查找 |
| `Update(id, updates)` | ID, 更新字段 | bool | 更新实体 |
| `Remove(id)` | ID | bool | 删除实体 |
| `Link(src, tgt, type, data)` | 源ID, 目标ID, 关系类型, 附加数据 | bool | 建立关系 |
| `Unlink(src, tgt, type)` | 源ID, 目标ID, 关系类型 | count | 解除关系 |
| `GetRelations(id, type)` | ID, 关系类型 | relation[] | 获取关系 |
| `GetRelated(id, type)` | ID, 关系类型 | entity[] | 获取关联实体 |
| `FindPath(from, to, depth)` | 源ID, 目标ID, 最大深度 | path/nil | 关系路径搜索 |
| `Query(criteria)` | 查询条件 | entity[] | 组合查询 |
| `Search(keyword, type)` | 关键词, 类型 | result[] | 全文搜索 |

### Persistence

| 方法 | 说明 |
|------|------|
| `Save(db, filename)` | 保存到 JSON |
| `Load(filename)` | 从 JSON 加载 |
| `ExportText(db)` | 导出可读文本 |

### ConsistencyChecker

| 检查项 | 检测内容 |
|--------|---------|
| 孤立实体 | 无任何关系的实体 |
| 断裂关系 | 指向已删除实体 |
| 循环包含 | A 包含 B 且 B 包含 A |
| 矛盾关系 | 同时友好和敌对 |
| 缺失字段 | 必填字段为空 |
| 死亡活跃 | 已死角色仍有活跃关系 |
| 地点容量 | 命名实体数 vs 人口 |

