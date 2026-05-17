# 亲密度系统设计指南

> GAIA NPC AI — 亲密度引擎详细设计参考

---

## 1. 亲密度等级体系

### 1.1 七级亲密度模型

| 等级 | 英文名 | 数值范围 | 颜色标识 | NPC 行为表现 |
|------|--------|---------|---------|-------------|
| 死敌 | sworn_enemy | -100 ~ -60 | 深红 #B71C1C | 主动攻击、拒绝任何互动 |
| 敌对 | hostile | -59 ~ -20 | 红色 #F44336 | 拒绝交易、给出假情报 |
| 冷淡 | unfriendly | -19 ~ -1 | 橙色 #FF9800 | 高价交易、信息有限 |
| 中立 | neutral | 0 ~ 20 | 黄色 #FFC107 | 正常交易、基础对话 |
| 友好 | friendly | 21 ~ 50 | 浅绿 #8BC34A | 折扣交易、分享线索 |
| 亲密 | close_friend | 51 ~ 80 | 绿色 #4CAF50 | 特殊任务、护送请求 |
| 忠诚 | devoted | 81 ~ 100 | 金色 #FFD700 | 可招募、舍命相助 |

### 1.2 等级跃迁事件

当亲密度跨越等级边界时，应触发特殊事件：

```lua
-- 等级变化通知示例
-- 在 AffinitySystem 中，等级变化时可触发自定义事件

---@param agent GaiaAgentDef
---@param oldTier table
---@param newTier table
local function OnTierChanged(agent, oldTier, newTier)
    -- 方式1：使用 UrhoX 事件系统
    local eventData = VariantMap()
    eventData["NpcName"] = Variant(agent.name)
    eventData["OldTier"] = Variant(oldTier.name)
    eventData["NewTier"] = Variant(newTier.name)
    eventData["Affinity"] = Variant(agent.affinity)
    SendEvent("GaiaAffinityTierChanged", eventData)

    -- 方式2：直接回调
    if agent.onTierChanged then
        agent.onTierChanged(agent, oldTier, newTier)
    end
end
```

---

## 2. 亲密度变化规则

### 2.1 正面互动

| 行为 | 基础变化 | 受性格影响 | 说明 |
|------|---------|-----------|------|
| 喂食 | +10/次 | friendliness ×1.5 | 基础正面互动 |
| 赠送礼物 | +5~+25 | 按物品价值 | 稀有物品效果更好 |
| 完成任务 | +15~+30 | 按任务难度 | 高难度任务回报更高 |
| 治疗 | +20 | friendliness ×1.3 | 危机时刻效果加倍 |
| 救命 | +40 | 固定值 | HP < 10% 时救援 |

### 2.2 负面互动

| 行为 | 基础变化 | 受性格影响 | 说明 |
|------|---------|-----------|------|
| 攻击 | -25/次 | aggression ×0.7 | 攻击性 NPC 更能容忍 |
| 偷窃 | -15/次 | — | 被发现时触发 |
| 拒绝帮助 | -5/次 | friendliness ×1.2 | 友善 NPC 更介意 |
| 伤害同伴 | -30 | — | 伤害 NPC 的朋友 |
| 杀死同伴 | -50 | — | 杀死 NPC 的朋友 |

### 2.3 衰减与回归

亲密度不应一成不变，建议实现自然回归机制：

```lua
--- 亲密度自然衰减（每游戏日调用一次）
---@param agent GaiaAgentDef
function AffinityDecay(agent)
    -- 极端值缓慢回归中立
    if agent.affinity > 50 then
        agent.affinity = agent.affinity - 1  -- 高好感缓慢下降
    elseif agent.affinity < -50 then
        agent.affinity = agent.affinity + 1  -- 高仇恨缓慢恢复
    end
    -- 中间范围保持稳定
end
```

---

## 3. 阵营系统扩展

### 3.1 阵营定义

```lua
---@class GaiaFaction
---@field id string         阵营 ID
---@field name string       阵营名称
---@field members string[]  成员 NPC 名称列表
---@field relations table   与其他阵营的基础关系

local Factions = {
    village = {
        id = "village",
        name = "村庄",
        members = { "老王", "小李" },
        relations = { bandits = -50, forest = 20 },
    },
    bandits = {
        id = "bandits",
        name = "山贼",
        members = { "阿强" },
        relations = { village = -50, forest = -30 },
    },
}
```

### 3.2 阵营好感联动

```lua
--- 阵营好感联动：对某成员的行为影响同阵营其他成员
---@param targetAgent GaiaAgentDef
---@param affinityChange number
---@param allAgents table
---@param factionDef table
function FactionAffinitySpread(targetAgent, affinityChange, allAgents, factionDef)
    local targetFaction = nil
    for fId, faction in pairs(factionDef) do
        for _, name in ipairs(faction.members) do
            if name == targetAgent.name then
                targetFaction = fId
                break
            end
        end
        if targetFaction then break end
    end

    if not targetFaction then return end

    -- 同阵营成员受到 50% 的好感变化
    local spreadFactor = 0.5
    local faction = factionDef[targetFaction]
    for _, memberName in ipairs(faction.members) do
        if memberName ~= targetAgent.name then
            local member = allAgents[memberName]
            if member then
                member.affinity = math.max(-100, math.min(100,
                    member.affinity + affinityChange * spreadFactor
                ))
            end
        end
    end
end
```

---

## 4. UI 集成建议

### 4.1 亲密度条

使用 UrhoX UI 组件的 ProgressBar 显示亲密度：

```lua
local UI = require("urhox-libs/UI")

--- 创建亲密度显示条
---@param agent GaiaAgentDef
function CreateAffinityBar(agent)
    local tier = AffinitySystem.GetTier(agent.affinity)
    -- 将 -100~100 映射到 0~100
    local normalizedValue = (agent.affinity + 100) / 2

    return UI.Panel {
        flexDirection = "row", alignItems = "center",
        gap = 8, padding = 4,
        children = {
            UI.Label { text = tier.label, fontSize = 12, width = 40 },
            UI.ProgressBar {
                value = normalizedValue,
                width = 150, height = 8,
                backgroundColor = "#333",
                fillColor = tier.min >= 51 and "#4CAF50"
                    or tier.min >= 0 and "#FFC107"
                    or "#F44336",
            },
            UI.Label {
                text = tostring(agent.affinity),
                fontSize = 12, width = 30,
            },
        }
    }
end
```

---

## 5. 设计最佳实践

1. **渐进式信任**：不要让玩家一次喂食就达到"忠诚"，好感增长应有递减效应
2. **负面行为重罚**：伤害比帮助更容易记住（符合心理学的负面偏见效应）
3. **不可逆后果**：杀死 NPC 应该是永久的，没有"重新刷新"
4. **NPC 记忆**：记录玩家的历史行为，用于对话和任务生成
5. **视觉反馈**：NPC 头顶显示好感图标（笑脸/中性/怒脸），让玩家直观感知
