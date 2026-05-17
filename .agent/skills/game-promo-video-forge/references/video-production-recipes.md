# 游戏宣传视频制作配方大全

> 按游戏类型提供完整的宣传视频制作配方，包括 promo-script-v1 JSON 模板、
> 推荐时长、场景编排、BGM 风格、旁白调性和文案范例。
> 每个配方可直接用于 game-promo-video-forge 管线。

---

## 目录

1. [RPG/JRPG — 史诗预告配方](#1-rpgjrpg--史诗预告配方)
2. [休闲/益智 — 轻快展示配方](#2-休闲益智--轻快展示配方)
3. [动作/射击 — 肾上腺素配方](#3-动作射击--肾上腺素配方)
4. [模拟/经营 — 温馨治愈配方](#4-模拟经营--温馨治愈配方)
5. [策略/塔防 — 运筹帷幄配方](#5-策略塔防--运筹帷幄配方)
6. [多人/社交 — 欢乐互动配方](#6-多人社交--欢乐互动配方)
7. [恐怖/悬疑 — 氛围渲染配方](#7-恐怖悬疑--氛围渲染配方)
8. [通用配方要素](#8-通用配方要素)

---

## 1. RPG/JRPG — 史诗预告配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 45-60s |
| 风格 | `epic` |
| BGM | orchestral, cinematic, epic, strings |
| 旁白 | 深沉磁性男声 / 空灵女声 |
| 节奏 | 慢→渐快→高潮→收束 |

### 场景编排

```
s01 (5s)  黑幕 + 世界观引入文字          ← title_card
s02 (7s)  世界全景/地图概览展示          ← gameplay (screenshot)
s03 (7s)  角色特写 + 角色介绍            ← gameplay (screenshot)
s04 (8s)  战斗系统展示/Boss 战          ← gameplay (screenshot)
s05 (7s)  装备/技能树/养成系统           ← feature_showcase (montage)
s06 (6s)  剧情高潮截图 + 悬念文案        ← gameplay (screenshot)
s07 (5s)  Logo + "即刻启程" CTA          ← call_to_action
```

### promo-script-v1 模板片段

```json
{
  "$schema": "promo-script-v1",
  "id": "rpg_epic_trailer",
  "title": "《游戏名》— 官方史诗预告",
  "target_duration": 45,
  "orientation": "landscape",
  "style": "epic",
  "scenes": [
    {
      "scene_id": "s01_opening",
      "duration": 5,
      "type": "title_card",
      "visual": {
        "source": "generated",
        "prompt": "黑暗空间中古老符文逐一亮起，金色光芒汇聚成游戏Logo，史诗奇幻风格"
      },
      "narration": { "text": "", "emotion": "none" },
      "text_overlay": { "content": "千年封印，即将解除", "position": "center", "style": "fade_in" },
      "bgm_mood": "suspense_building",
      "transition_to_next": "dissolve"
    },
    {
      "scene_id": "s02_world",
      "duration": 7,
      "type": "gameplay",
      "visual": {
        "source": "screenshot",
        "screenshot_index": 0
      },
      "narration": { "text": "在这片被神遗忘的大陆上，命运的齿轮再次转动", "emotion": "mysterious" },
      "text_overlay": { "content": "", "position": "bottom", "style": "none" },
      "bgm_mood": "adventure_rising",
      "transition_to_next": "swipe_left"
    }
  ],
  "bgm": {
    "style": "orchestral, cinematic, epic, strings, choir",
    "tempo": "starts slow and mysterious, builds gradually, reaches epic climax at 70%, resolves warmly"
  },
  "narrator": {
    "voice_type": "male_deep_confident",
    "language": "cmn",
    "six_dimension_prompt": "Young adult male in his late 20s, deep and magnetic voice, measured pacing with dramatic pauses, mysterious undertone, cinematic trailer narration style. Studio-quality recording."
  }
}
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 世界观 | "在这片被神遗忘的大陆上，命运的齿轮再次转动" |
| 角色 | "他背负着整个王国的命运，踏上了不归路" |
| 战斗 | "当黑暗降临，唯有勇者之剑能斩破一切" |
| 养成 | "千锤百炼的装备，独一无二的战斗风格" |
| CTA | "现在加入，书写属于你的传说" |

---

## 2. 休闲/益智 — 轻快展示配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 15-30s |
| 风格 | `fast_cut` |
| BGM | upbeat, electronic, pop, cheerful |
| 旁白 | 活泼女声 / 可不要旁白（纯字幕） |
| 节奏 | 快→更快→最快→CTA |

### 场景编排

```
s01 (3s)  游戏Logo + 核心画面闪现       ← title_card
s02 (5s)  核心玩法展示（最吸引人的操作）  ← gameplay (screenshot)
s03 (5s)  进阶玩法/连击/高分场景        ← gameplay (screenshot)
s04 (5s)  丰富内容速览（多截图快切）     ← feature_showcase (montage)
s05 (4s)  "超解压！""停不下来！"         ← call_to_action
```

### promo-script-v1 模板片段

```json
{
  "$schema": "promo-script-v1",
  "id": "casual_fast_cut",
  "title": "《游戏名》— 你停不下来的解压神器",
  "target_duration": 22,
  "orientation": "portrait",
  "style": "fast_cut",
  "scenes": [
    {
      "scene_id": "s01_hook",
      "duration": 3,
      "type": "title_card",
      "visual": {
        "source": "generated",
        "prompt": "彩色糖果爆炸效果，游戏Logo从糖果中弹出，明亮欢快卡通风格"
      },
      "narration": { "text": "", "emotion": "none" },
      "text_overlay": { "content": "你能坚持多久？", "position": "center", "style": "bounce" },
      "bgm_mood": "upbeat_intro",
      "transition_to_next": "flash"
    }
  ],
  "bgm": {
    "style": "electronic, upbeat, pop, cheerful, catchy",
    "tempo": "fast and energetic throughout, brief pause before CTA"
  },
  "narrator": {
    "voice_type": "female_cheerful",
    "language": "cmn",
    "six_dimension_prompt": "Young adult female in her early 20s, bright and energetic voice, fast-paced speaking, enthusiastic and playful, anime-style cheerfulness. Studio-quality recording."
  }
}
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "三秒上手，根本停不下来！" |
| 玩法 | "滑动、消除、连击——就是这么简单！" |
| 高分 | "你的最高纪录是多少？" |
| CTA | "现在下载，挑战排行榜！" |

---

## 3. 动作/射击 — 肾上腺素配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 30-45s |
| 风格 | `epic` 或 `fast_cut` |
| BGM | aggressive, electronic, dubstep, metal |
| 旁白 | 硬朗男声 / 可选无旁白 |
| 节奏 | 爆裂→间歇→更爆裂→CTA |

### 场景编排

```
s01 (3s)  爆炸/枪声中 Logo 闪现         ← title_card
s02 (7s)  第三人称/第一人称战斗实况      ← gameplay (screenshot)
s03 (6s)  技能释放/大招特效              ← gameplay (screenshot)
s04 (6s)  武器库/角色选择                ← feature_showcase (montage)
s05 (5s)  多人对战场景                   ← gameplay (screenshot)
s06 (4s)  Logo + 战斗口号 CTA            ← call_to_action
```

### BGM 参考 prompt

```
"aggressive electronic dubstep with heavy bass drops, 
intense percussion, builds tension then releases with 
massive impact, cinematic game trailer energy"
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "战场没有退路" |
| 战斗 | "每一颗子弹都决定胜负" |
| 技能 | "释放你的终极力量" |
| 多人 | "组队出击，统治战场" |
| CTA | "加入战斗！" |

---

## 4. 模拟/经营 — 温馨治愈配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 30-45s |
| 风格 | `story` |
| BGM | acoustic, piano, warm, gentle, lo-fi |
| 旁白 | 温柔女声/治愈系男声 |
| 节奏 | 缓慢→展开→满足→CTA |

### 场景编排

```
s01 (5s)  日出/清晨场景，游戏世界苏醒    ← title_card
s02 (7s)  建造/种植/装饰核心循环          ← gameplay (screenshot)
s03 (7s)  角色互动/NPC 对话              ← gameplay (screenshot)
s04 (7s)  成果展示（完成的农场/城镇）     ← gameplay (screenshot)
s05 (6s)  四季变换/时间流逝蒙太奇         ← feature_showcase (montage)
s06 (5s)  "你的专属世界" CTA             ← call_to_action
```

### BGM 参考 prompt

```
"gentle acoustic guitar with soft piano accompaniment, 
warm and cozy atmosphere, lo-fi vibes, peaceful and 
relaxing, suitable for a heartwarming simulation game"
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "在这个小小世界里，每一天都值得期待" |
| 经营 | "一砖一瓦，建起属于你的梦想家园" |
| 互动 | "这里的每个人，都有自己的故事" |
| 成果 | "春种秋收，看着一切慢慢变好" |
| CTA | "来这里，找到你的慢生活" |

---

## 5. 策略/塔防 — 运筹帷幄配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 30-45s |
| 风格 | `epic` |
| BGM | strategic, orchestral, tension, war drums |
| 旁白 | 沉稳男声（指挥官调性） |
| 节奏 | 沉思→布局→冲锋→胜利 |

### 场景编排

```
s01 (4s)  战略地图鸟瞰                   ← title_card
s02 (7s)  布阵/建塔过程                  ← gameplay (screenshot)
s03 (7s)  敌军来袭/波次战斗              ← gameplay (screenshot)
s04 (7s)  防御体系全览/连锁反应           ← gameplay (screenshot)
s05 (5s)  胜利画面 + 战报                 ← feature_showcase
s06 (4s)  "你的策略决定一切" CTA          ← call_to_action
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "战争的胜负，在出兵前已经决定" |
| 布阵 | "每一座塔，都是你智慧的延伸" |
| 战斗 | "百万敌军压境，你的防线能否坚守？" |
| 胜利 | "运筹帷幄之中，决胜千里之外" |
| CTA | "用你的策略，改写战局" |

---

## 6. 多人/社交 — 欢乐互动配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 20-30s |
| 风格 | `fast_cut` |
| BGM | party, fun, electronic, upbeat |
| 旁白 | 活泼男声/双人对话 |
| 节奏 | 欢乐→互动→混乱→笑点→CTA |

### 场景编排

```
s01 (3s)  多个角色同屏欢乐场景           ← title_card
s02 (6s)  多人同屏竞技/合作画面          ← gameplay (screenshot)
s03 (5s)  搞笑/混乱/意外瞬间            ← gameplay (screenshot)
s04 (5s)  胜负揭晓/排行榜               ← gameplay (screenshot)
s05 (4s)  "叫上朋友一起玩" CTA           ← call_to_action
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "一个人玩？不，叫上朋友！" |
| 竞技 | "四人混战，谁能笑到最后？" |
| 搞笑 | "队友坑你？这才是快乐源泉！" |
| CTA | "现在开房间，等你来闹！" |

---

## 7. 恐怖/悬疑 — 氛围渲染配方

### 概要

| 属性 | 推荐值 |
|------|--------|
| 时长 | 30-45s |
| 风格 | `story` |
| BGM | dark ambient, horror, tension, minimal |
| 旁白 | 低沉耳语/无旁白（纯环境音+字幕） |
| 节奏 | 安静→不安→恐惧→Jump Scare→黑幕 |

### 场景编排

```
s01 (5s)  安静的场景（看似正常）          ← title_card
s02 (7s)  探索/发现异常                  ← gameplay (screenshot)
s03 (7s)  危险逼近/画面扭曲              ← gameplay (screenshot)
s04 (5s)  高潮惊吓（快速闪现+声效）      ← gameplay (screenshot)
s05 (4s)  黑幕 + "你敢来吗？"            ← call_to_action
```

### BGM 参考 prompt

```
"dark ambient soundscape with deep drones, occasional 
metallic scraping, unsettling whispers, building tension 
with sudden silence before impact, horror game atmosphere"
```

### 旁白文案范例

| 场景 | 文案示例 |
|------|---------|
| 开场 | "（耳语）你听到了吗……" |
| 探索 | "这扇门后面，是什么？" |
| 惊吓 | "（无旁白，只有尖叫音效）" |
| CTA | "你敢直面恐惧吗？" |

---

## 8. 通用配方要素

### 8.1 时长推荐表

| 平台/用途 | 推荐时长 | 适用风格 |
|----------|---------|---------|
| TapTap 商店页 | 30-60s | 所有风格 |
| 社交媒体推广 | 15-30s | `fast_cut` / `teaser` |
| 首曝/预热 | 10-15s | `teaser` |
| 深度展示 | 45-90s | `story` / `gameplay` |
| 竖屏短视频 | 15-30s | `fast_cut`（portrait） |

### 8.2 CTA（行动号召）最佳实践

| 规则 | 说明 |
|------|------|
| **文案简短** | ≤8 个中文字符（"立即下载""加入战斗""开始冒险"） |
| **时机** | 放在最后 4-6 秒 |
| **视觉** | Logo 居中 + 平台标志（TapTap） |
| **旁白** | 用最有力的语气说出 CTA |
| **停顿** | CTA 前留 0.5-1s 静默，制造期待感 |

### 8.3 文件组织（所有配方通用）

```
scripts/
├── data/
│   └── promo/
│       ├── rpg_epic.json              # RPG 史诗配方脚本
│       ├── casual_fast.json           # 休闲快切配方脚本
│       ├── action_intense.json        # 动作肾上腺素配方脚本
│       └── state.json                 # 生产状态（JSON 持久化存档）
├── systems/
│   ├── PromoVideoPlayer.lua           # 视频播放器模块
│   └── PromoScriptLoader.lua          # 脚本加载器模块
└── main.lua                           # 入口

game_material/promo/                   # 视频产物目录
```

### 8.4 截图采集规则

| 规则 | 说明 |
|------|------|
| 使用真实截图 | 预览窗口右上角"截图插入对话"功能 |
| 选择多样性 | 不同关卡/场景/功能的截图 |
| 画质优先 | 选择画面效果最好的瞬间 |
| 数量建议 | 准备 5-8 张截图供 AI 选择 |
| 横竖屏分别准备 | 16:9 和 9:16 各一套 |

### 8.5 配方选择决策树

```
你的游戏是什么类型？
├── RPG/JRPG/开放世界 → §1 史诗预告配方
├── 休闲/益智/三消/跑酷 → §2 轻快展示配方
├── 动作/射击/格斗/ACT → §3 肾上腺素配方
├── 模拟/经营/种田/建造 → §4 温馨治愈配方
├── 策略/塔防/SLG → §5 运筹帷幄配方
├── 多人/派对/社交 → §6 欢乐互动配方
├── 恐怖/悬疑/解谜 → §7 氛围渲染配方
└── 混合类型 → 选择主导玩法对应的配方，融入次要元素
```

### 8.6 多版本输出矩阵

| 版本 | orientation | ratio | duration | 用途 |
|------|------------|-------|----------|------|
| 主版本 | landscape | 16:9 | 30-60s | TapTap 商店页 / PC |
| 竖屏版 | portrait | 9:16 | 15-30s | 短视频平台 |
| 超宽版 | landscape | 21:9 | 30-60s | 电影级展示 |
| 预热版 | landscape | 16:9 | 10-15s | 社交媒体预热 |
| 方形版 | - | 1:1 | 15-30s | 社交媒体封面 |

每个版本使用相同的 promo-script-v1 脚本，修改 `orientation` 和 `target_duration`，
然后通过构建管线重新生成即可。状态通过 promo-state-v1 JSON 持久化跟踪。

---

## 交叉引用

- **管线执行流程** → `../SKILL.md` §2-§9
- **MCP 工具映射** → `moneyprinter-mapping.md` §5 快速查找索引
- **Seedance prompt 优化** → `prompt-engineering-guide.md`
- **数据格式定义** → `../SKILL.md` §11
- **Lua 模块代码** → `../SKILL.md` §12
