# Voice Design Guide — ElevenLabs 角色配音完整指南

> cinematic-dub-pipeline 参考文档：角色声音设计、试听、批量合成的详细规范

---

## 1. 六维声音描述模型

ElevenLabs Voice Design 基于 AI 从文本描述生成声音，prompt 必须覆盖以下六个维度：

### 1.1 维度定义

| # | 维度 | 英文 | 说明 | 示例值 |
|---|------|------|------|--------|
| 1 | 年龄/性别 | Age/Gender | 年龄段 + 性别 | "young adult male in his 20s" |
| 2 | 音色/质感 | Tone/Timbre | 声音质地和纹理 | warm, magnetic, husky, raspy, smooth |
| 3 | 语速/节奏 | Pacing | 说话速度和停顿风格 | fast-paced, slow and deliberate, measured |
| 4 | 情感/气质 | Emotion/Vibe | 性格和情绪特质 | energetic, aloof, confident, gentle |
| 5 | 风格 | Style | 配音风格或参考 | anime style, movie trailer, professional |
| 6 | 音质 | Quality | 录音质量（必须包含） | "studio-quality recording" |

### 1.2 Prompt 构造模板

```
"{Age/Gender}, {Tone/Timbre}, {Emotion/Vibe}, {Pacing}, {Style}. Studio-quality recording."
```

**示例**：
```
"Young adult male in his 20s, professional Chinese voice actor, clear and magnetic tone,
elegant, confident, crisp articulation, prince-like quality. Studio-quality recording."
```

---

## 2. 八大角色原型模板

### TYPE A: 华丽公子 / 温暖男主

```
prompt: "Young adult male in his 20s, professional Chinese voice actor, clear and
magnetic tone, elegant, confident, crisp articulation, prince-like quality.
Studio-quality recording."

试听台词: "自古英雄多磨难,但请相信,黎明终将到来。让我陪你走过这段路,
无论前方有多少荆棘,我都会为你披荆斩棘。"
```

### TYPE B: 动漫萌系 / 吉祥物

```
prompt: "High-pitched female anime voice, fantasy mascot character, fairy-like,
energetic and bubbly, hyper-enthusiastic, professional voice acting, chibi style.
Studio-quality recording."

试听台词: "哇\!这里好漂亮啊\!快看快看,那边有好多闪闪发光的东西\!
我们去探险吧,说不定能找到超级厉害的宝藏呢\!"
```

> ⚠️ ElevenLabs 禁止儿童声音。用 "high-pitched female anime voice" + "fantasy mascot"
> 替代 "child" / "young girl" / "kid" 等关键词。

### TYPE C: 高冷御姐 / 女王

```
prompt: "Young adult female in her late 20s, deep and cool tone, icy, aloof,
authoritative, slow and deliberate pacing, low emotional variation, mysterious,
regal. Studio-quality recording."

试听台词: "在我登上王座的那一刻,所有臣服于我的人,都将明白真正的权力来自掌控。
不要试图揣测我的心思,那只会让你更快地走向毁灭。"
```

### TYPE D: 智慧老者 / 导师

```
prompt: "Elderly wise man in his 70s, voice deep and gravelly, speaking slowly
with dramatic pauses, mysterious and calm tone, warm undertone, storyteller
quality. Studio-quality recording."

试听台词: "年轻人,你可知道,真正的智慧并非来自书本,而是来自岁月的沉淀。
当你经历过足够多的风雨,自然会明白这个道理。"
```

### TYPE E: 热血少年 / 冒险者

```
prompt: "Young adult male, energetic and passionate, fast-paced speaking,
enthusiastic, slight breathiness from excitement, adventurous spirit, anime
protagonist style. Studio-quality recording."

试听台词: "我绝对不会放弃的\!就算前面有一百个敌人,一千个困难,我也要冲过去\!
因为这是我的梦想,是我必须守护的东西\!"
```

### TYPE F: 沉稳旁白 / 叙事者

```
prompt: "Middle-aged male in his 40s, deep baritone, calm and authoritative,
measured pacing with deliberate pauses, documentary narrator style, gravitas,
professional Chinese voice actor. Studio-quality recording."

试听台词: "在这片被遗忘的大陆上,曾经存在着一个伟大的文明。他们建造了通天的高塔,
驯服了狂暴的龙兽。然而,繁荣的背后,一场浩劫正在悄然降临。"
```

### TYPE G: 反派 Boss / 黑暗领主

```
prompt: "Middle-aged male, deep resonant voice, menacing and commanding,
slow deliberate speech, dark undertone, villainous charisma, slight echo quality,
theatrical. Studio-quality recording."

试听台词: "愚蠢的凡人,你们以为凭借那微弱的光芒就能抵抗黑暗的力量吗?
看看这片被我征服的土地,这就是反抗我的代价。跪下,或者消亡。"
```

### TYPE H: 商人 / NPC 路人

```
prompt: "Middle-aged male in his 50s, slightly nasal and shrewd tone,
medium pacing, friendly but calculating, merchant-like persuasiveness,
casual conversational style. Studio-quality recording."

试听台词: "嘿,冒险者\!你来得正好\!我这儿刚到了一批上等的装备,都是从远东运来的好货。
看看这把剑,削铁如泥\!今天给你打个八折,怎么样?"
```

---

## 3. 试听台词编写规范

### 3.1 基本要求

| 规则 | 说明 |
|------|------|
| 最低字数 | **100 字符以上**（ElevenLabs API 硬性要求） |
| 情感匹配 | 台词情感必须与 prompt 描述的语气一致 |
| 完整句子 | 使用完整句子展示角色声音特点 |
| 角色特征 | 台词应体现角色的性格和说话方式 |

### 3.2 错误示范

```
❌ "你好"                          -- 太短，< 100 字符
❌ "Hello world"                   -- 太短且无角色特征
❌ 温柔角色说 "杀了他们\!"           -- 情感不匹配
❌ 老者角色说 "哇塞超级棒呀\!"       -- 风格不匹配
```

### 3.3 情感标签嵌入

在台词中嵌入英文情感标签，控制语音表现：

**情感标签**：

| 标签 | 效果 |
|------|------|
| `[laughing]` / `[chuckling]` | 笑声 |
| `[sad]` / `[crying]` | 悲伤/哭泣 |
| `[excited]` / `[enthusiastic]` | 兴奋 |
| `[angry]` / `[furious]` | 愤怒 |
| `[nervous]` / `[anxious]` | 紧张 |
| `[whispering]` / `[softly]` | 低语/轻声 |
| `[shouting]` / `[yelling]` | 喊叫 |
| `[sighs]` | 叹气 |
| `[gasps]` | 倒吸气 |
| `[clears throat]` | 清嗓子 |
| `[pause]` | 停顿 |

**示例台词**：
```
"[sighs] 唉,真是累了... [softly] 不过,一切都会好起来的。[pause] 我相信。"
```

### 3.4 标点符号节奏控制

| 标点 | 效果 |
|------|------|
| `...` | 停顿，表示思考或犹豫 |
| `—` | 语气转折或中断 |
| `\!` | 强调语气 |
| `?` | 疑问语调上扬 |
| `,` | 短暂停顿 |
| `。` | 正常停顿 |

---

## 4. Stability 参数调优

### 4.1 参数范围

| 范围 | 效果 | 适用场景 |
|------|------|---------|
| 0.1 - 0.3 | 高度情感化，变化大 | 战斗呐喊、惊恐尖叫、大笑 |
| 0.3 - 0.5 | 情感丰富，自然变化 | 戏剧性台词、感人对白 |
| 0.5 - 0.7 | 平衡，适度变化 | 日常对话、一般叙事 |
| 0.7 - 0.9 | 稳定一致 | 旁白、正式场合、教程 |
| 0.9 - 1.0 | 极度稳定，几乎无变化 | 机器人、AI 语音、系统提示 |

### 4.2 EMOTION_STABILITY 映射表（Lua）

```lua
--- 情感类型到 stability 参数的映射
local EMOTION_STABILITY = {
    -- 高情感变化（低 stability）
    scream      = 0.2,   -- 尖叫/呐喊
    cry         = 0.25,  -- 哭泣
    laugh       = 0.3,   -- 大笑
    rage        = 0.3,   -- 暴怒

    -- 中等情感变化
    excited     = 0.4,   -- 兴奋
    sad         = 0.4,   -- 悲伤
    tender      = 0.45,  -- 温柔
    dramatic    = 0.45,  -- 戏剧性

    -- 平衡
    normal      = 0.5,   -- 普通对话
    friendly    = 0.55,  -- 友好
    curious     = 0.55,  -- 好奇

    -- 高稳定性
    calm        = 0.7,   -- 冷静
    serious     = 0.75,  -- 严肃
    narration   = 0.8,   -- 旁白
    formal      = 0.85,  -- 正式

    -- 极高稳定性
    robotic     = 0.95,  -- 机器人
    system      = 1.0,   -- 系统提示
}
```

**用法**：
```lua
local stability = EMOTION_STABILITY[emotion] or 0.5
-- 传递给 text_to_dialogue 的 stability 参数
```

---

## 5. 多语言声音一致性

### 5.1 核心原则

**同一角色在不同语言中必须使用相同的 ElevenLabs voice**。ElevenLabs 的 voice 本身是语言无关的，通过 `language_code` 参数切换输出语言。

### 5.2 支持的语言代码

| 语言 | ISO 代码 | language_code |
|------|---------|---------------|
| 中文（普通话） | cmn | `"cmn"` |
| 英语 | en | `"en"` |
| 日语 | ja | `"ja"` |
| 韩语 | ko | `"ko"` |
| 法语 | fr | `"fr"` |
| 德语 | de | `"de"` |
| 西班牙语 | es | `"es"` |
| 葡萄牙语 | pt | `"pt"` |
| 俄语 | ru | `"ru"` |
| 阿拉伯语 | ar | `"ar"` |
| 印地语 | hi | `"hi"` |
| 意大利语 | it | `"it"` |

### 5.3 多语言配音工作流

```
Step 1: 为角色设计并确认声音（audition_voices → confirm_character_voice）
         ↓ （仅执行一次，声音与语言无关）
Step 2: 生成中文配音
         text_to_dialogue(character, 中文台词, language_code="cmn")
         ↓
Step 3: 生成英文配音
         text_to_dialogue(character, 英文台词, language_code="en")
         ↓
Step 4: 生成日文配音
         text_to_dialogue(character, 日文台词, language_code="ja")
```

### 5.4 注意事项

- 声音设计 prompt 始终用英文，与输出语言无关
- 同一 voice 可输出任意语言，无需为每种语言创建单独 voice
- 不同语言的台词长度可能差异较大，需调整字幕时间轴

---

## 6. Voice Slot 管理

### 6.1 订阅限制

| 订阅等级 | Voice Slot 数量 |
|---------|----------------|
| Free | 3 |
| Starter | 10 |
| Creator | 30 |
| Pro | 160 |

### 6.2 省 Slot 策略

| 策略 | 说明 |
|------|------|
| 角色分类 | 主角/重要NPC 用独立 voice，路人NPC 共用 voice |
| 声音复用 | 同类型角色（如多个士兵）共用一个 voice |
| 情感标签 | 用 `[angry]` `[sad]` 等标签区分情感，而非创建多个 voice |
| 规划优先 | 先确定所有需要独立 voice 的角色，再批量创建 |

### 6.3 Voice Slot 分配建议

```
游戏类型        推荐 Slot 分配
──────────────────────────────
短篇 RPG        主角1 + 同伴2 + Boss1 + 旁白1 = 5
视觉小说        主角1 + 可攻略角色4 + 配角3 = 8
大型 RPG        主角2 + 主要NPC6 + Boss3 + 旁白1 + 通用NPC2 = 14
```

---

## 7. 批量合成优化

### 7.1 合成顺序建议

```
推荐顺序:
1. 先合成一个角色的全部台词 → 验证声音质量
2. 再合成下一个角色
3. 最后合成次要角色和路人

不推荐:
- 逐场景合成（频繁切换角色，效率低）
- 一次性全部合成（发现问题时已浪费大量配额）
```

### 7.2 验证检查清单

在批量合成前，确认以下事项：

```
□ 所有角色的 voice 已通过 confirm_character_voice 确认
□ 台词 JSON 格式正确，包含 character/text/emotion 字段
□ 每条台词的情感标签与 stability 参数匹配
□ 多语言台词已翻译完成且格式一致
□ 输出目录结构已规划（assets/Audio/Dialogue/{lang}/{scene}/）
□ 文件命名规范已确认（{scene}_{line_id}_{lang}.ogg）
```

### 7.3 输出目录结构

```
assets/
└── Audio/
    └── Dialogue/
        ├── cmn/                    # 中文
        │   ├── opening/
        │   │   ├── opening_001_cmn.ogg
        │   │   └── opening_002_cmn.ogg
        │   └── chapter1/
        │       └── ch1_001_cmn.ogg
        ├── en/                     # 英文
        │   ├── opening/
        │   │   ├── opening_001_en.ogg
        │   │   └── opening_002_en.ogg
        │   └── chapter1/
        │       └── ch1_001_en.ogg
        └── ja/                     # 日文
            └── ...
```

---

## 8. 与 SKILL.md 模块的对应关系

| 本文档章节 | SKILL.md 模块 | 说明 |
|-----------|-------------|------|
| §2 角色原型模板 | §4 VoiceSynthesizer | 声音设计阶段的 prompt 参考 |
| §3 试听台词规范 | §4 VoiceSynthesizer | audition_line 编写标准 |
| §4 Stability 参数 | §4 VoiceConfig | EMOTION_STABILITY 映射 |
| §5 多语言一致性 | §11 批量合成 | 多语言工作流 |
| §6 Voice Slot 管理 | §4 VoiceSynthesizer | Slot 分配策略 |
| §7 批量合成优化 | §11 批量合成 | AI 执行指令 |

---

*本文档为 cinematic-dub-pipeline skill 的配套参考，详细用法请见 SKILL.md §4 VoiceSynthesizer。*
