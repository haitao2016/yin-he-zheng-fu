# 示例世界数据集

> World Lore Notebook — 三种常见游戏类型的完整世界观数据示例

---

## 概述

本文档提供三种游戏类型的完整世界观数据集，可直接用于项目原型或作为参考。
每个示例包含实体注册和关系链接的完整 Lua 代码。

---

## 示例 1: 中世纪奇幻 RPG

**游戏类型**：经典剑与魔法 RPG
**适用模板**：3D 角色游戏（scaffold-3d-character）

### 实体数据

```lua
local worldData = {
    entities = {
        -- ===== 角色 =====
        {
            type = "Character", name = "莱昂哈特",
            description = "失忆的流浪剑士，身上有神秘的纹章印记",
            tags = { "主角", "人类", "剑士" },
            fields = {
                race = "人类", role = "流浪剑客", status = "alive",
                age = 28, personality = "沉默但善良",
                motivation = "找回失去的记忆",
                abilities = "双手剑术、微弱的光明魔力",
            },
        },
        {
            type = "Character", name = "艾琳娜",
            description = "森林精灵族的治疗师，被族人派出调查异变",
            tags = { "队友", "精灵", "治疗师" },
            fields = {
                race = "精灵", role = "治疗师", status = "alive",
                age = 156, personality = "温和、好奇心强",
                motivation = "调查森林枯萎的原因",
                abilities = "自然魔法、草药学、弓术",
            },
        },
        {
            type = "Character", name = "黑铁·格罗姆",
            description = "矮人王国的锻造大师，被放逐后开设武器店",
            tags = { "商人", "矮人", "锻造" },
            fields = {
                race = "矮人", role = "武器商人", status = "alive",
                age = 180, personality = "暴躁但讲义气",
                abilities = "大师级锻造、矮人战斧术",
            },
        },
        {
            type = "Character", name = "暗影主教·维克多",
            description = "暗影教团的最高领袖，真实身份不明",
            tags = { "BOSS", "反派", "暗影" },
            fields = {
                race = "未知", role = "暗影教团首领", status = "alive",
                personality = "冷酷、有极强的魅力",
                motivation = "解放深渊古神",
                abilities = "暗影魔法、精神操控、不老之身",
            },
        },

        -- ===== 地点 =====
        {
            type = "Location", name = "银月城",
            description = "王国的首都，繁华的贸易中心",
            tags = { "城市", "安全", "主城" },
            fields = {
                locationType = "城市", climate = "温带",
                population = 50000, dangerLevel = "safe",
                governance = "王政",
            },
        },
        {
            type = "Location", name = "枯萎森林",
            description = "曾经翠绿的精灵森林，如今正在不明原因地枯死",
            tags = { "野外", "危险", "主线" },
            fields = {
                locationType = "森林", climate = "温带",
                dangerLevel = "moderate",
                atmosphere = "死寂、偶尔有不自然的雾气",
            },
        },
        {
            type = "Location", name = "深渊裂隙",
            description = "大陆中央的巨大裂缝，通向未知深处",
            tags = { "地下城", "最终", "危险" },
            fields = {
                locationType = "地下城", climate = "异常",
                dangerLevel = "lethal",
                atmosphere = "黑暗、压迫感、低语声",
            },
        },

        -- ===== 物品 =====
        {
            type = "Item", name = "黎明之刃",
            description = "传说中能驱散一切黑暗的圣剑",
            tags = { "主线", "武器", "传说" },
            fields = {
                itemType = "weapon", rarity = "legendary",
                material = "晨光金属",
                effect = "对暗影系敌人造成三倍伤害，驱散黑暗领域",
                lore = "由初代光明骑士用陨石铸造",
            },
        },

        -- ===== 生物 =====
        {
            type = "Creature", name = "暗影狼",
            description = "被暗影侵蚀的狼群，双眼发出紫色光芒",
            tags = { "怪物", "暗影", "群体" },
            fields = {
                habitat = "枯萎森林",
                threat = "moderate",
                behavior = "群体狩猎，夜间活动",
                weakness = "光明魔法",
                drops = "暗影精华、狼皮",
                size = "medium",
            },
        },

        -- ===== 阵营 =====
        {
            type = "Faction", name = "光明骑士团",
            description = "守护王国的精锐骑士组织",
            tags = { "正义", "军事", "骑士" },
            fields = {
                factionType = "guild", alignment = "lawful_good",
                motto = "黎明终将到来",
                goal = "保卫王国、抵御暗影",
                strength = "300 名精锐骑士",
            },
        },
        {
            type = "Faction", name = "暗影教团",
            description = "崇拜深渊力量的秘密组织",
            tags = { "邪恶", "宗教", "反派" },
            fields = {
                factionType = "cult", alignment = "chaotic_evil",
                motto = "拥抱虚无",
                goal = "解放深渊古神，重塑世界",
            },
        },

        -- ===== 魔法 =====
        {
            type = "Magic", name = "暗影侵蚀",
            description = "暗影教团的核心术式，能腐蚀一切生命",
            tags = { "暗影", "诅咒", "主线" },
            fields = {
                magicType = "dark", element = "shadow",
                cost = "施法者生命力",
                sideEffects = "长期使用会失去人性",
            },
        },

        -- ===== 事件 =====
        {
            type = "Event", name = "森林枯萎事件",
            description = "精灵森林突然开始大面积枯死",
            tags = { "主线", "当前" },
            fields = {
                eventType = "quest", era = "当前",
                date = "三个月前开始",
                significance = "预示着封印正在减弱",
            },
        },

        -- ===== 传说 =====
        {
            type = "Lore", name = "深渊封印传说",
            description = "关于大陆创世和深渊封印的古老传说",
            tags = { "主线", "核心", "预言" },
            fields = {
                category = "prophecy",
                source = "光明神殿的古老壁画",
                reliability = "legend",
                content = "当暗影侵蚀扩散到第七片森林时，封印将彻底崩溃",
            },
        },
    },

    -- 关系链接
    relations = {
        -- 空间关系
        { "silver_city", "contains", "grom_shop" },
        { "elina", "located_in", "withered_forest" },

        -- 社会关系
        { "leonhart", "belongs_to", "light_knights" },
        { "victor", "leads", "shadow_cult" },
        { "light_knights", "hostile_to", "shadow_cult" },

        -- 个人关系
        { "leonhart", "friend_of", "elina" },
        { "leonhart", "enemy_of", "victor" },
        { "leonhart", "knows", "grom" },

        -- 所有权
        { "leonhart", "owns", "dawn_blade" },
        { "grom", "created_by", "dawn_blade" },

        -- 事件关系
        { "forest_wither", "occurs_at", "withered_forest" },
        { "elina", "participates", "forest_wither" },
        { "forest_wither", "triggered_by", "shadow_erosion_spread" },

        -- 知识关系
        { "victor", "knows_spell", "shadow_erosion" },
        { "leonhart", "referenced_in", "abyss_prophecy" },
    },
}
```

### 使用方式

```lua
-- 在游戏 scripts/ 中加载数据
local LoreDB = require("scripts.LoreDB")
local LoreBatchImport = require("scripts.LoreBatchImport")

local db = LoreDB.Create()
LoreBatchImport.RegisterAll(db, worldData.entities)
LoreBatchImport.LinkAll(db, worldData.relations)

-- 保存到存档文件
local LorePersistence = require("scripts.LorePersistence")
LorePersistence.Save(db, "world_data.json")
```

---

## 示例 2: 科幻太空探索

**游戏类型**：太空探索 / 星际贸易
**适用模板**：3D 场景展示（scaffold-3d-scene）

### 实体数据

```lua
local spaceWorldData = {
    entities = {
        -- ===== 角色 =====
        {
            type = "Character", name = "雷克斯船长",
            description = "独立货运船 '北极星号' 的船长",
            tags = { "主角", "人类", "船长" },
            fields = {
                race = "人类", role = "货运船长", status = "alive",
                age = 38, personality = "务实、有幽默感",
                motivation = "偿还飞船贷款，探索未知星域",
            },
        },
        {
            type = "Character", name = "ARIA",
            description = "北极星号的 AI 助手，有独立人格",
            tags = { "队友", "AI", "导航" },
            fields = {
                race = "人工智能", role = "飞船 AI", status = "alive",
                personality = "理性但偶尔展现幽默",
                abilities = "导航计算、系统管理、数据分析",
            },
        },

        -- ===== 地点 =====
        {
            type = "Location", name = "新伊甸空间站",
            description = "银河系边缘最大的自由贸易站",
            tags = { "空间站", "贸易", "中立" },
            fields = {
                locationType = "空间站", population = 120000,
                dangerLevel = "safe", governance = "商会自治",
                resources = "各类商品集散地",
            },
        },
        {
            type = "Location", name = "虫洞 Omega-7",
            description = "连接已知空间与未探索区域的不稳定虫洞",
            tags = { "虫洞", "危险", "探索" },
            fields = {
                locationType = "天体",
                dangerLevel = "lethal",
                atmosphere = "时空扭曲，通讯中断",
            },
        },

        -- ===== 阵营 =====
        {
            type = "Faction", name = "星际贸易联盟",
            description = "控制主要航线的商业联合体",
            tags = { "商业", "中立", "势力" },
            fields = {
                factionType = "guild", alignment = "neutral",
                goal = "垄断星际贸易路线",
            },
        },

        -- ===== 科技 =====
        {
            type = "Technology", name = "曲率引擎 Mk.III",
            description = "第三代超光速推进系统",
            tags = { "引擎", "核心", "科技" },
            fields = {
                techLevel = "industrial",
                field = "推进工程",
                applications = "星际旅行",
                limitations = "需要稀有的暗物质燃料",
            },
        },

        -- ===== 传说 =====
        {
            type = "Lore", name = "先驱者遗迹",
            description = "散布在银河各处的远古文明遗迹",
            tags = { "主线", "远古", "谜团" },
            fields = {
                category = "myth",
                reliability = "confirmed",
                content = "先驱者在百万年前消失，留下了超越当前科技水平的遗迹",
            },
        },
    },

    relations = {
        { "rex_captain", "owns", "polaris_ship" },
        { "aria_ai", "located_in", "polaris_ship" },
        { "rex_captain", "friend_of", "aria_ai" },
        { "trade_alliance", "uses_tech", "warp_drive_mk3" },
        { "rex_captain", "referenced_in", "pioneer_ruins" },
    },
}
```

---

## 示例 3: 校园悬疑解谜

**游戏类型**：悬疑推理 / 视觉小说
**适用模板**：2D 游戏（scaffold-2d）

### 实体数据

```lua
local mysteryWorldData = {
    entities = {
        -- ===== 角色 =====
        {
            type = "Character", name = "林晓",
            description = "新转来的高二学生，具有敏锐的观察力",
            tags = { "主角", "学生", "侦探" },
            fields = {
                race = "人类", role = "学生/侦探", status = "alive",
                age = 17, personality = "安静、观察力强、正义感",
                motivation = "调查学校里的怪事",
            },
        },
        {
            type = "Character", name = "赵老师",
            description = "化学老师，总是在实验室待到很晚",
            tags = { "嫌疑人", "老师" },
            fields = {
                race = "人类", role = "化学老师", status = "alive",
                age = 45, personality = "严厉但关心学生",
            },
        },
        {
            type = "Character", name = "陈月",
            description = "失踪的学生会长",
            tags = { "失踪", "关键人物" },
            fields = {
                race = "人类", role = "学生会长", status = "missing",
                age = 18, personality = "开朗、受欢迎",
            },
        },

        -- ===== 地点 =====
        {
            type = "Location", name = "明德中学",
            description = "有百年历史的重点中学",
            tags = { "学校", "主场景" },
            fields = {
                locationType = "学校", population = 2000,
                dangerLevel = "safe",
                history = "建于一百年前，曾多次翻修",
            },
        },
        {
            type = "Location", name = "旧化学实验室",
            description = "位于教学楼地下，已被封锁多年",
            tags = { "密室", "线索", "危险" },
            fields = {
                locationType = "实验室",
                dangerLevel = "moderate",
                atmosphere = "阴暗、有奇怪的化学气味",
            },
        },

        -- ===== 物品 =====
        {
            type = "Item", name = "陈月的日记",
            description = "在陈月书桌抽屉里发现的加密日记本",
            tags = { "线索", "关键", "文档" },
            fields = {
                itemType = "quest", rarity = "rare",
                lore = "最后一页写着一个奇怪的化学公式",
            },
        },
        {
            type = "Item", name = "生锈的钥匙",
            description = "在花坛里发现的一把旧钥匙",
            tags = { "线索", "钥匙" },
            fields = {
                itemType = "quest", rarity = "common",
                lore = "似乎能打开某扇很久没开过的门",
            },
        },

        -- ===== 事件 =====
        {
            type = "Event", name = "陈月失踪事件",
            description = "学生会长陈月在期末考试前突然失踪",
            tags = { "主线", "核心", "悬疑" },
            fields = {
                eventType = "quest", era = "当前",
                date = "两周前",
                significance = "引发了一系列连锁反应",
            },
        },

        -- ===== 传说 =====
        {
            type = "Lore", name = "学校七不思议",
            description = "在学生中流传的七个校园怪谈",
            tags = { "怪谈", "校园", "线索" },
            fields = {
                category = "rumor",
                source = "学生口耳相传",
                reliability = "rumor",
                content = "第七个怪谈：地下实验室里住着一个不老的人",
            },
        },
    },

    relations = {
        -- 空间
        { "old_lab", "located_in", "mingde_school" },

        -- 角色关系
        { "lin_xiao", "knows", "chen_yue" },
        { "zhao_teacher", "located_in", "old_lab" },

        -- 物品关系
        { "chen_yue", "owns", "chen_diary" },
        { "rusty_key", "located_in", "mingde_school" },

        -- 事件
        { "chen_missing", "occurs_at", "mingde_school" },
        { "chen_yue", "participates", "chen_missing" },
        { "chen_yue", "referenced_in", "school_mysteries" },
    },
}
```

---

## 数据组织建议

### 项目文件结构

```
scripts/
  main.lua              -- 游戏入口
  lore/
    LoreDB.lua          -- 核心数据库模块
    RelationEngine.lua   -- 关系引擎
    QueryEngine.lua      -- 查询引擎
    ConsistencyChecker.lua -- 一致性检查
    LorePrompter.lua     -- AI 提示器
    LorePersistence.lua  -- 持久化管理
    LoreRuntime.lua      -- 运行时查询
    LoreBatchImport.lua  -- 批量导入
    data/
      world_data.lua     -- 世界观数据定义
```

### 持久化到 JSON 存档

```lua
-- 保存世界数据到 JSON 文件（scripts/ 目录下）
LorePersistence.Save(db, "lore_save.json")

-- 从 JSON 文件加载
local db = LorePersistence.Load("lore_save.json")
```

### 构建与调试

1. 将所有 Lua 模块放在 `scripts/` 目录下
2. 调用 UrhoX 构建工具进行构建
3. 使用 `ConsistencyChecker.CheckAll()` 验证数据完整性
4. 通过 `LorePrompter.SuggestForWorld()` 发现缺失内容
