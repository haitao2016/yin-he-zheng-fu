# 关系网络设计模式

> World Lore Notebook — 关系类型、设计模式与常见反模式

---

## 概述

关系网络是世界观数据库的核心。良好的关系设计能让世界观自洽、可查询、可扩展。
本文档覆盖 23 种关系类型的使用场景，以及经过验证的设计模式和需要避免的反模式。

---

## 关系类型速查表

### 空间关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `located_in` | 有向 | `contains` | A 位于 B 内 | 角色→城镇, 物品→地下城 |
| `contains` | 有向 | `located_in` | A 包含 B | 城镇→建筑, 大陆→国家 |
| `connected_to` | 对称 | — | A 与 B 相连 | 城镇↔城镇, 房间↔房间 |

### 社会关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `belongs_to` | 有向 | — | A 属于 B | 骑士→骑士团, 市民→城镇 |
| `leads` | 有向 | — | A 领导 B | 国王→王国, 团长→骑士团 |
| `allied_with` | 对称 | — | A 与 B 同盟 | 骑士团↔商会 |
| `hostile_to` | 对称 | — | A 与 B 敌对 | 王国↔暗影教团 |

### 个人关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `knows` | 对称 | — | A 认识 B | 角色↔角色 |
| `friend_of` | 对称 | — | A 与 B 是朋友 | 角色↔角色 |
| `enemy_of` | 对称 | — | A 与 B 是死敌 | 角色↔角色 |
| `family_of` | 对称 | — | A 与 B 是亲属 | 角色↔角色 |
| `mentor_of` | 有向 | — | A 是 B 的导师 | 贤者→学徒 |

### 所有权关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `owns` | 有向 | — | A 拥有 B | 角色→物品, 阵营→领地 |
| `created_by` | 有向 | — | A 由 B 创造 | 物品→角色, 魔法→角色 |
| `guards` | 有向 | — | A 守卫 B | 角色→地点, 生物→宝藏 |

### 事件关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `participates` | 有向 | — | A 参与了 B | 角色→事件 |
| `triggered_by` | 有向 | — | A 由 B 触发 | 事件→事件 |
| `occurs_at` | 有向 | — | A 发生在 B | 事件→地点 |

### 知识关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `knows_spell` | 有向 | — | A 掌握法术 B | 角色→魔法 |
| `uses_tech` | 有向 | — | A 使用科技 B | 阵营→科技 |
| `referenced_in` | 有向 | — | A 在 B 中被提及 | 角色→传说 |

### 通用关系

| 关系 | 方向性 | 反向 | 说明 | 典型用例 |
|------|--------|------|------|---------|
| `related_to` | 对称 | — | 泛用关联 | 任何实体↔任何实体 |

---

## 设计模式

### 模式 1: 空间层级树

**目的**：构建世界地理的层级结构

```lua
-- 大陆 → 国家 → 城市 → 建筑
RelationEngine.Link(db, "continent_01", "contains", "kingdom_01")
RelationEngine.Link(db, "kingdom_01", "contains", "city_01")
RelationEngine.Link(db, "city_01", "contains", "tavern_01")

-- 角色 → 位于某建筑
RelationEngine.Link(db, "npc_bartender", "located_in", "tavern_01")
```

**查询能力**：
```lua
-- 查找某城市中的所有角色
local inCity = RelationEngine.GetRelated(db, "city_01", "contains")
-- 然后过滤 type == "Character"
```

**注意事项**：
- 不要形成循环包含（A contains B, B contains A）
- ConsistencyChecker 的 `circularContainment` 检查会自动检测此类问题

---

### 模式 2: 阵营对立网络

**目的**：建立阵营间的同盟/敌对关系

```lua
-- 同盟关系（对称，自动双向）
RelationEngine.Link(db, "knights", "allied_with", "merchant_guild")

-- 敌对关系（对称，自动双向）
RelationEngine.Link(db, "knights", "hostile_to", "shadow_cult")
RelationEngine.Link(db, "merchant_guild", "hostile_to", "thieves_guild")
```

**查询能力**：
```lua
-- 查找所有与骑士团敌对的阵营
local enemies = RelationEngine.GetRelated(db, "knights", "hostile_to")

-- 查找所有同盟
local allies = RelationEngine.GetRelated(db, "knights", "allied_with")
```

**注意事项**：
- 不要同时设置 `allied_with` 和 `hostile_to`
- ConsistencyChecker 的 `conflictingRelations` 会检测此矛盾

---

### 模式 3: 角色社交图谱

**目的**：描述角色之间的人际关系

```lua
-- 层次关系
RelationEngine.Link(db, "master_mage", "mentor_of", "apprentice")
RelationEngine.Link(db, "king", "leads", "kingdom")

-- 对等关系
RelationEngine.Link(db, "hero", "friend_of", "healer")
RelationEngine.Link(db, "hero", "enemy_of", "dark_lord")
RelationEngine.Link(db, "hero", "family_of", "sister")
```

**查询能力**：
```lua
-- 查找角色的所有关系（社交网络）
local allRelations = RelationEngine.GetRelations(db, "hero")

-- 查找两个角色之间的关系链
local path = RelationEngine.FindPath(db, "hero", "dark_lord")
```

---

### 模式 4: 事件因果链

**目的**：描述事件之间的因果和时间关系

```lua
-- 事件发生地点
RelationEngine.Link(db, "battle_01", "occurs_at", "plains_01")

-- 事件参与者
RelationEngine.Link(db, "hero", "participates", "battle_01")
RelationEngine.Link(db, "dark_lord", "participates", "battle_01")

-- 事件因果
RelationEngine.Link(db, "peace_treaty", "triggered_by", "battle_01")
```

**查询能力**：
```lua
-- 查找某地发生过的所有事件
local events = QueryEngine.Query(db, {
    type = "Event",
    hasRelation = "occurs_at",
    relatedTo = "plains_01",
})
```

---

### 模式 5: 物品溯源链

**目的**：追踪物品的创造、归属和守护关系

```lua
-- 物品创造者
RelationEngine.Link(db, "legendary_sword", "created_by", "master_smith")

-- 物品当前持有者
RelationEngine.Link(db, "hero", "owns", "legendary_sword")

-- 物品守护者
RelationEngine.Link(db, "dragon", "guards", "ancient_treasure")
```

---

### 模式 6: 知识与能力网络

**目的**：描述角色掌握的魔法和科技

```lua
-- 角色掌握的法术
RelationEngine.Link(db, "archmage", "knows_spell", "meteor_storm")
RelationEngine.Link(db, "archmage", "knows_spell", "ice_wall")

-- 阵营使用的科技
RelationEngine.Link(db, "dwarves", "uses_tech", "steam_engine")

-- 传说中提及的实体
RelationEngine.Link(db, "hero", "referenced_in", "prophecy_01")
```

---

## 反模式（需要避免）

### 反模式 1: 循环包含

```lua
-- A contains B, B contains A → 逻辑矛盾
RelationEngine.Link(db, "room_a", "contains", "room_b")
RelationEngine.Link(db, "room_b", "contains", "room_a")  -- 不要这样做
```

**解决方案**：使用 `connected_to`（对称连接）代替双向包含。

---

### 反模式 2: 同时同盟又敌对

```lua
-- allied_with + hostile_to 矛盾
RelationEngine.Link(db, "faction_a", "allied_with", "faction_b")
RelationEngine.Link(db, "faction_a", "hostile_to", "faction_b")  -- 矛盾
```

**解决方案**：如果关系变化，先 `Unlink` 旧关系再 `Link` 新关系。

---

### 反模式 3: 关系类型滥用

```lua
-- 用 related_to 代替所有精确关系 → 失去语义信息
RelationEngine.Link(db, "hero", "related_to", "tavern")     -- 应该用 located_in
RelationEngine.Link(db, "hero", "related_to", "sword")      -- 应该用 owns
```

**解决方案**：优先使用精确的关系类型，只在没有合适类型时使用 `related_to`。

---

### 反模式 4: 死角色仍有活跃关系

```lua
-- 角色已死，但仍然 "located_in" 某地、"leads" 某组织
local char = LoreDB.Get(db, "dead_npc")
-- char.fields.status == "dead"
-- 但仍然有 "leads" 关系 → 逻辑矛盾
```

**解决方案**：角色死亡时清理活跃关系，或使用 ConsistencyChecker 定期扫描。

---

## 关系数据在游戏运行时的使用

在游戏运行时，关系数据可用于多种游戏系统：

```lua
-- NPC 对话中引用关系
local npcInfo = LoreRuntime.GetNPCInfo(db, npcId)
-- npcInfo.relations 包含该 NPC 的所有关系

-- 地点描述中列出内容
local locInfo = LoreRuntime.GetLocationInfo(db, locId)
-- locInfo.characters, locInfo.items 等

-- 百科全书搜索
local results = LoreRuntime.SearchEncyclopedia(db, "骑士")
```

将关系数据持久化到 `scripts/` 目录下的 JSON 存档文件，
确保项目构建时包含所需数据。

---

## 最佳实践总结

1. **先规划层级再填充细节**：先建立空间层级树，再添加角色和物品
2. **优先使用精确关系类型**：避免大量使用 `related_to`
3. **定期运行一致性检查**：`ConsistencyChecker.CheckAll()` 可发现潜在问题
4. **关系变化要同步**：角色死亡/阵营变更时及时更新关系
5. **利用 FindPath 发现隐藏联系**：BFS 路径搜索可以发现意料之外的关联
6. **批量导入用 LinkAll**：大量关系数据使用 `LoreBatchImport.LinkAll()` 一次性导入
