# AI 工具 Prompt 模板库

各品类 AI 工具的经过验证的 Prompt 模板，确保输出质量稳定。

---

## 1. 图像生成 Prompt 模板

### 1.1 游戏图标

```
{物品名称}图标，游戏风格，简洁清晰，{颜色}色调，白色/透明背景，
居中构图，轻微阴影，高辨识度
```

**示例**：
- `金币图标，游戏风格，简洁清晰，金色色调，透明背景，居中构图，轻微阴影，高辨识度`
- `红色药水瓶图标，游戏风格，简洁清晰，红色色调，透明背景，居中构图，高辨识度`

### 1.2 角色立绘

```
{角色描述}，{风格}风格，全身站立姿势，正面朝向，
{服装描述}，{表情描述}，透明背景，高质量
```

**示例**：
- `女剑士，二次元风格，全身站立姿势，正面朝向，银色铠甲红色披风，坚定表情，透明背景，高质量`

### 1.3 场景背景

```
{场景描述}，{风格}风格，{时间段}，{氛围}氛围，
{光照描述}，宽幅横向构图，游戏场景概念设计
```

**示例**：
- `神秘森林，奇幻风格，黄昏时分，神秘氛围，金色阳光穿透树冠，宽幅横向构图，游戏场景概念设计`

### 1.4 UI 元素

```
{UI元素}，游戏UI设计，{风格}主题，{颜色}配色，
简洁扁平/精致立体，透明背景
```

### 1.5 纹理贴图

```
{材质名称}纹理，无缝贴图，{细节描述}，PBR风格，
正面平铺视角，均匀光照，高分辨率
```

**示例**：
- `红砖墙纹理，无缝贴图，风化旧砖缝隙有青苔，PBR风格，正面平铺视角，均匀光照`

---

## 2. 3D 模型 Prompt 模板

### 2.1 角色模型（带骨骼）

```
{角色描述}，low poly 风格，A-pose 站姿（双臂45度下垂），
游戏角色模型，{服装描述}，干净背景
```

**关键**：`rig=true` 时必须指定 A-pose。

### 2.2 道具/物品模型

```
{物品描述}，low poly game asset，{风格}风格，
细节适中，居中展示，干净背景
```

### 2.3 场景物件

```
{物件描述}，游戏场景道具，{风格}风格，
适合游戏引擎使用的面数，干净背景
```

---

## 3. 音乐 Prompt 模板

### 3.1 Simple 模式

| 场景 | Prompt |
|------|--------|
| 主菜单 | "calm peaceful game menu music, gentle piano melody, ambient pads, warm and inviting" |
| 战斗 | "intense battle music, fast-paced orchestral, drums and brass, heroic and urgent" |
| 探索 | "adventurous exploration music, light orchestral, curious melody, sense of wonder" |
| Boss 战 | "epic boss battle theme, heavy drums, choir, dark orchestral, dramatic tension" |
| 胜利 | "victory celebration fanfare, bright brass, triumphant melody, short and energetic" |
| 悲伤 | "melancholic emotional scene, slow piano, strings, bittersweet feeling" |
| 商店 | "cheerful shop music, playful melody, light percussion, relaxed casual vibe" |
| 夜晚 | "night ambient music, soft synth pads, gentle bells, mysterious and calm" |

### 3.2 Custom 模式

```lua
-- 战斗 BGM 示例
{
    customMode = true,
    style = "orchestral, epic, cinematic, fast tempo, intense drums",
    title = "Battle Theme",
    instrumental = true,  -- 纯器乐
    prompt = "An intense orchestral battle theme for a fantasy RPG game"
}
```

---

## 4. 音效 Prompt 模板

**注意**：音效描述使用英文效果最佳。

### 4.1 按类别分类

| 类别 | Prompt 模板 |
|------|-------------|
| **UI** | |
| 按钮点击 | "Short UI button click, soft and clean, digital" |
| 菜单打开 | "Menu panel sliding open, smooth whoosh, interface sound" |
| 确认 | "Positive confirmation sound, bright ding, satisfying" |
| 错误 | "Error notification, short buzzer, not harsh" |
| **角色动作** | |
| 跳跃 | "Character jump, whoosh and spring, cartoon style" |
| 落地 | "Landing on ground, soft thud, dust settling" |
| 受伤 | "Character taking damage, impact with brief grunt" |
| 死亡 | "Character death, dramatic descending tone, final" |
| **战斗** | |
| 剑斩 | "Sword slash through air, sharp metallic swing" |
| 魔法释放 | "Magic spell cast, mystical energy gathering and release" |
| 爆炸 | "Medium explosion, fiery blast with debris" |
| 护盾 | "Shield activation, energy barrier humming, sci-fi" |
| **物品** | |
| 拾取金币 | "Coin pickup, bright metallic clink, rewarding" |
| 开箱 | "Treasure chest opening, wooden creak with sparkle" |
| 药水使用 | "Potion drinking, liquid gulp with magical shimmer" |
| **环境** | |
| 森林 | "Forest ambient, birds chirping, gentle wind in leaves" |
| 下雨 | "Rain ambient, steady rainfall, occasional thunder" |
| 洞穴 | "Cave ambient, dripping water, distant echoes" |
| 城镇 | "Town ambient, distant chatter, footsteps, wind" |

### 4.2 批量生成示例

```lua
-- 适合一次性生成的常用音效套装
{
    sounds = {
        { name = "btn_click",     text = "Short UI button click, soft and clean" },
        { name = "btn_hover",     text = "Subtle UI hover sound, gentle soft blip" },
        { name = "coin_pickup",   text = "Coin pickup, bright metallic clink, rewarding" },
        { name = "jump",          text = "Character jump, whoosh and spring, cartoon style" },
        { name = "land",          text = "Landing on ground, soft thud" },
        { name = "hit_damage",    text = "Character hit, impact with brief grunt" },
        { name = "level_complete", text = "Level complete fanfare, short triumphant jingle" },
        { name = "game_over",     text = "Game over sound, descending sad tone, final" },
    }
}
```

---

## 5. 语音生成 Prompt 模板

### 5.1 角色声音描述（六维度）

**模板**：
```
[年龄/性别] {年龄段}{性别}，
[音色] {音质形容词}的声音，
[语速] {语速描述}，
[情感] {性格/情绪}，
[风格] {配音风格}，
[质量] studio-quality recording
```

**示例库**：

| 角色类型 | 描述 |
|---------|------|
| 年轻男主角 | "Young adult male in his 20s, warm and clear voice, moderate pace, confident and friendly, anime protagonist style. Studio-quality recording." |
| 冷酷女王 | "Young adult female in her late 20s, deep and cool tone, slow and deliberate, icy and authoritative, regal quality. Studio-quality recording." |
| 智慧老者 | "Elderly wise man in his 70s, deep gravelly voice, slow with dramatic pauses, calm and mysterious, storyteller quality. Studio-quality recording." |
| 萌系吉祥物 | "High-pitched female anime voice, fantasy mascot character, fairy-like, energetic and bubbly, chibi style. Studio-quality recording." |
| 热血少年 | "Young adult male, energetic and passionate, fast-paced, enthusiastic with slight breathiness, anime style. Studio-quality recording." |
| 温柔治愈 | "Young adult female, soft warm voice, gentle pace, kind and soothing, ASMR-like quality. Studio-quality recording." |

### 5.2 台词情感标记

在台词中插入英文情感标签控制语音表现：

| 标签 | 效果 | 示例 |
|------|------|------|
| [laughing] | 笑声 | "[laughing] 太有趣了！" |
| [sad] | 悲伤 | "[sad] 我们…再也回不去了。" |
| [angry] | 愤怒 | "[angry] 你怎么敢！" |
| [whispering] | 低语 | "[whispering] 小声点，有人来了。" |
| [shouting] | 呐喊 | "[shouting] 冲啊！" |
| [sighs] | 叹气 | "[sighs] 算了吧……" |
| [excited] | 兴奋 | "[excited] 我们找到宝藏了！" |

---

## 6. NPC System Prompt 模板

```
你是 {NPC名称}，{角色身份}。

## 背景
{背景故事，100-200字}

## 性格特征
- {特征1}
- {特征2}
- {特征3}

## 知识范围
了解：{NPC了解的话题列表}
不了解：{NPC不知道的话题}

## 说话风格
- 口头禅："{口头禅}"
- 语气：{语气描述}
- 句式偏好：{长句/短句/反问}

## 规则
1. 始终保持角色设定
2. 回复不超过50字
3. 不了解的话题用角色方式回避
4. 根据对话上下文调整情绪
```

---

## Prompt 编写通用原则

1. **具体 > 抽象**：用具体描述词（"bright metallic clink"）而非抽象词（"好听的声音"）
2. **风格锚定**：始终指定风格关键词（"cartoon style"、"PBR风格"、"anime style"）
3. **否定约束**：必要时说明不要什么（"no background"、"clean background"）
4. **长度控制**：图像 prompt 控制在 50-100 字，音效 prompt 控制在 10-30 词
5. **一致性参考**：批量生成时使用 reference_images 保持风格一致
