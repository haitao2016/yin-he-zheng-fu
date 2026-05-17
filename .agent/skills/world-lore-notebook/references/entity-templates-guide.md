# 实体模板详细指南

> World Lore Notebook — 9 种实体类型的字段定义、填写建议与最佳实践

---

## 概述

本文档详细说明每种实体类型的字段含义、填写建议和典型数据示例。
所有实体共享 `id`、`type`、`name`、`description`、`tags` 基础字段，
各类型额外定义 `requiredFields` 和 `optionalFields`。

---

## 1. Character（角色）

**适用场景**：NPC、主角、配角、历史人物、传说人物

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `race` | string | 种族 | `"人类"`, `"精灵"`, `"矮人"` |
| `role` | string | 在世界中的角色定位 | `"铁匠"`, `"国王"`, `"流浪商人"` |
| `status` | string | 当前状态 | `"alive"`, `"dead"`, `"missing"`, `"sealed"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `age` | number | 年龄 | `35` |
| `gender` | string | 性别 | `"male"`, `"female"`, `"unknown"` |
| `title` | string | 头衔 | `"暗影之刃"`, `"第一贤者"` |
| `personality` | string | 性格特征 | `"沉稳、正义感强"` |
| `motivation` | string | 行为动机 | `"为家族复仇"` |
| `backstory` | string | 背景故事 | `"曾是皇家骑士..."` |
| `abilities` | string | 能力/技能 | `"剑术、火焰魔法"` |
| `weakness` | string | 弱点 | `"恐高、对暗影魔法无抗性"` |
| `appearance` | string | 外貌描述 | `"高大、银发、左眼有疤"` |
| `faction` | string | 所属阵营 | `"王国骑士团"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Character",
    name = "艾尔温",
    description = "曾经的皇家骑士团长，因一场阴谋被流放",
    tags = { "主线", "骑士", "人类" },
    fields = {
        race = "人类",
        role = "流浪剑客",
        status = "alive",
        age = 42,
        title = "断誓者",
        personality = "沉默寡言但内心正直",
        motivation = "揭露当年阴谋的真相",
        abilities = "圣光剑术、战术指挥",
        weakness = "右臂旧伤导致持久战不利",
        appearance = "高大魁梧、灰发、穿旧骑士甲",
    },
})
```

---

## 2. Location（地点）

**适用场景**：城镇、地下城、区域、建筑、自然地标

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `locationType` | string | 地点类型 | `"城镇"`, `"地下城"`, `"森林"`, `"神殿"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `climate` | string | 气候 | `"温带"`, `"极寒"`, `"沙漠"` |
| `population` | number | 人口数量 | `5000` |
| `capacity` | number | 最大容量 | `100`（用于连续性检查） |
| `dangerLevel` | string | 危险等级 | `"safe"`, `"moderate"`, `"lethal"` |
| `resources` | string | 特产/资源 | `"铁矿、药草"` |
| `history` | string | 历史 | `"建于三百年前..."` |
| `atmosphere` | string | 氛围 | `"压抑、阴暗"` |
| `governance` | string | 治理方式 | `"王政"`, `"自治"`, `"军事管制"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Location",
    name = "灰烬要塞",
    description = "矗立于火山口边缘的古老堡垒",
    tags = { "主线", "危险", "火山" },
    fields = {
        locationType = "要塞",
        climate = "炎热",
        population = 200,
        capacity = 500,
        dangerLevel = "lethal",
        resources = "火晶石、熔岩铁",
        atmosphere = "弥漫硫磺气味，视线被火山灰遮挡",
    },
})
```

---

## 3. Item（物品）

**适用场景**：武器、防具、消耗品、关键道具、收藏品

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `itemType` | string | 物品类型 | `"weapon"`, `"armor"`, `"consumable"`, `"quest"` |
| `rarity` | string | 稀有度 | `"common"`, `"rare"`, `"epic"`, `"legendary"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `material` | string | 材质 | `"秘银"`, `"龙骨"` |
| `origin` | string | 来源 | `"矮人锻造"`, `"远古遗物"` |
| `effect` | string | 效果 | `"附加火焰伤害"` |
| `lore` | string | 物品传说 | `"据说沾染了龙血..."` |
| `weight` | number | 重量(千克) | `3.5` |
| `value` | number | 价值(金币) | `1500` |

### 数据示例

```lua
LoreDB.Register({
    type = "Item",
    name = "誓约之剑",
    description = "皇家骑士团的象征，只有团长才能持有",
    tags = { "主线", "武器", "传说" },
    fields = {
        itemType = "weapon",
        rarity = "legendary",
        material = "星陨铁",
        effect = "对亡灵类敌人造成双倍伤害",
        lore = "千年前由第一任骑士团长铸造",
        value = 99999,
    },
})
```

---

## 4. Creature（生物）

**适用场景**：怪物、野生动物、召唤兽、BOSS

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `habitat` | string | 栖息地 | `"深林"`, `"地下"`, `"水域"` |
| `threat` | string | 威胁等级 | `"harmless"`, `"moderate"`, `"deadly"`, `"mythical"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `diet` | string | 食性 | `"食肉"`, `"杂食"` |
| `behavior` | string | 行为模式 | `"群居攻击"`, `"独行夜行"` |
| `abilities` | string | 特殊能力 | `"喷火、飞行"` |
| `weakness` | string | 弱点 | `"怕光、冰属性克制"` |
| `drops` | string | 掉落物 | `"龙鳞、龙牙"` |
| `size` | string | 体型 | `"tiny"`, `"medium"`, `"huge"`, `"colossal"` |
| `intelligence` | string | 智慧程度 | `"野兽级"`, `"人类级"`, `"超凡级"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Creature",
    name = "熔岩蠕虫",
    description = "栖息在火山地带的巨型节肢生物",
    tags = { "火山", "BOSS", "虫类" },
    fields = {
        habitat = "火山/熔岩地带",
        threat = "deadly",
        behavior = "伏击型，从地下突袭",
        abilities = "钻地、喷射岩浆、硬化外壳",
        weakness = "腹部柔软，冰属性魔法有效",
        drops = "熔岩核心、坚硬甲壳",
        size = "colossal",
    },
})
```

---

## 5. Event（事件）

**适用场景**：历史事件、当前任务、预言、定期节日

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `eventType` | string | 事件类型 | `"historical"`, `"quest"`, `"prophecy"`, `"festival"` |
| `era` | string | 所属纪元/时期 | `"第一纪"`, `"大灾变后"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `date` | string | 发生日期 | `"第三纪 247年 秋"` |
| `outcome` | string | 结果 | `"王国覆灭"` |
| `significance` | string | 重要性 | `"改变了大陆格局"` |
| `witnesses` | string | 目击者/参与者 | `"第一贤者、龙族长老"` |
| `aftermath` | string | 后续影响 | `"导致了持续百年的寒冬"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Event",
    name = "骑士团叛变",
    description = "皇家骑士团中的暗影派系发动政变",
    tags = { "主线", "历史", "阴谋" },
    fields = {
        eventType = "historical",
        era = "当前纪元",
        date = "十年前的仲夏之夜",
        outcome = "团长被流放，暗影派系掌权",
        significance = "直接导致了王国衰落",
        aftermath = "暗影势力渗透各地",
    },
})
```

---

## 6. Faction（阵营）

**适用场景**：国家、组织、帮派、宗教、商会

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `factionType` | string | 组织类型 | `"kingdom"`, `"guild"`, `"cult"`, `"tribe"` |
| `alignment` | string | 阵营倾向 | `"lawful_good"`, `"neutral"`, `"chaotic_evil"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `motto` | string | 座右铭 | `"以剑为誓"` |
| `goal` | string | 组织目标 | `"恢复古老秩序"` |
| `structure` | string | 组织结构 | `"等级制"`, `"议会制"` |
| `territory` | string | 领土范围 | `"北方三省"` |
| `strength` | string | 军事实力 | `"精锐骑兵 2000"` |
| `relations` | string | 外交关系概述 | `"与商会同盟，与暗影教敌对"` |
| `traditions` | string | 传统/习俗 | `"入团仪式需在火山口宣誓"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Faction",
    name = "暗影教团",
    description = "崇拜深渊力量的秘密组织",
    tags = { "主线", "敌对", "宗教" },
    fields = {
        factionType = "cult",
        alignment = "chaotic_evil",
        motto = "深渊即真理",
        goal = "解放封印在深渊中的古神",
        structure = "三环制（外环信众、中环祭司、内环长老）",
        strength = "数千名狂信徒和数十位暗影法师",
    },
})
```

---

## 7. Magic（魔法/超自然）

**适用场景**：法术体系、魔法规则、附魔、诅咒

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `magicType` | string | 魔法类型 | `"elemental"`, `"divine"`, `"arcane"`, `"dark"` |
| `element` | string | 元素/属性 | `"fire"`, `"ice"`, `"light"`, `"shadow"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `cost` | string | 消耗 | `"大量魔力"`, `"生命值"` |
| `range` | string | 范围 | `"self"`, `"30 meters"`, `"area"` |
| `duration` | string | 持续时间 | `"instant"`, `"10 seconds"`, `"permanent"` |
| `prerequisites` | string | 前提条件 | `"需学会基础火焰术"` |
| `sideEffects` | string | 副作用 | `"施法后短暂失明"` |
| `origin` | string | 起源 | `"远古精灵传承"` |
| `restrictions` | string | 限制 | `"满月时无法施放"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Magic",
    name = "圣光审判",
    description = "召唤神圣光柱净化一切邪恶",
    tags = { "神术", "光明", "AOE" },
    fields = {
        magicType = "divine",
        element = "light",
        cost = "大量神力值",
        range = "area（半径 15 米）",
        duration = "instant",
        prerequisites = "需获得光明神殿的祝福",
        sideEffects = "施法者会暂时失去所有魔力",
    },
})
```

---

## 8. Technology（科技）

**适用场景**：发明、工程、炼金术、魔导科技

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `techLevel` | string | 科技水平 | `"primitive"`, `"medieval"`, `"industrial"`, `"magitek"` |
| `field` | string | 所属领域 | `"冶金"`, `"炼金"`, `"魔导工程"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `inventor` | string | 发明者 | `"矮人工匠大师"` |
| `materials` | string | 所需材料 | `"魔力水晶、精钢"` |
| `applications` | string | 应用场景 | `"武器强化、城防系统"` |
| `limitations` | string | 局限性 | `"需要魔力核心驱动"` |
| `availability` | string | 普及程度 | `"仅限皇家工坊"` |

### 数据示例

```lua
LoreDB.Register({
    type = "Technology",
    name = "魔导通讯仪",
    description = "利用魔力水晶进行远距离通讯的装置",
    tags = { "矮人", "通讯", "魔导" },
    fields = {
        techLevel = "magitek",
        field = "魔导工程",
        inventor = "矮人工匠协会",
        materials = "通讯水晶、银线路",
        applications = "军事指挥、商业通讯",
        limitations = "距离超过 100 公里信号衰减",
        availability = "贵族和军方专用",
    },
})
```

---

## 9. Lore（传说/知识条目）

**适用场景**：世界规则、传说故事、百科条目、预言

### 必填字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `category` | string | 知识分类 | `"myth"`, `"history"`, `"rule"`, `"prophecy"` |

### 可选字段

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `source` | string | 信息来源 | `"古老手稿"`, `"口口相传"` |
| `reliability` | string | 可信度 | `"confirmed"`, `"rumor"`, `"legend"` |
| `relatedEra` | string | 相关时代 | `"创世纪"` |
| `content` | string | 详细内容 | `"据说在第一纪末期..."` |

### 数据示例

```lua
LoreDB.Register({
    type = "Lore",
    name = "深渊封印之谜",
    description = "关于大陆中央裂隙下封印的古老记载",
    tags = { "主线", "预言", "深渊" },
    fields = {
        category = "prophecy",
        source = "第一贤者的手稿",
        reliability = "legend",
        content = "七星归位之日，封印将被打破，深渊之主将重临世间",
    },
})
```

---

## 字段设计原则

1. **必填字段应尽量少**：只保留真正不可缺少的分类信息
2. **可选字段应尽量丰富**：覆盖各种世界观设定需求
3. **字段值使用字符串优先**：灵活性最高，适配各种世界观
4. **标签系统补充分类**：`tags` 数组提供多维标签，支持灵活查询
5. **描述字段存放叙事内容**：`description` 用于一两句话概括，详细内容放专用字段

---

## 与 ConsistencyChecker 的关联

- `Character.status = "dead"` → 检查是否仍有活跃关系
- `Location.capacity` → 检查 `located_in` 数量是否超限
- 所有类型的 `requiredFields` → `missingFields` 检查会标记未填的必填字段
- 实体 `id` → 关系引用的唯一标识，删除实体前需处理关联关系

---

## 保存与加载注意事项

使用 `LorePersistence.Save()` 时，所有字段会被序列化为 JSON。
加载后通过 `LorePersistence.Load()` 恢复，字段类型保持一致。

```lua
-- 持久化到 scripts/ 目录下的存档文件
LorePersistence.Save(db, "lore_data.json")

-- 从存档加载
local db = LorePersistence.Load("lore_data.json")
```

详细持久化方案参见 SKILL.md §9。
