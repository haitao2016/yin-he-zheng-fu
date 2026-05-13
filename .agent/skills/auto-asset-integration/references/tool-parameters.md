# AI 生成工具完整参数规格

> 本文档列出所有可用的 AI 素材生成工具及其参数，供 Skill 执行时快速查阅。

---

## 1. generate_image — 单张图片生成

### 必填参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `prompt` | string | 中文描述（max 50KB） |
| `name` | string | 文件名（不含扩展名，max 100字符） |
| `target_size` | string | 最终尺寸，格式 "宽x高" |

### 常用可选参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `aspect_ratio` | enum | "1:1" | 生成比例，影响 AI 构图 |
| `transparent` | boolean | false | 透明背景（自动检测关键词） |
| `reference_images` | string[] | — | 参考图（最多14张） |
| `seed` | number | — | 随机种子（可复现） |
| `resolution` | enum | "1K" | 生成分辨率 "0.5K"/"1K"/"2K"/"4K" |
| `thinking_level` | enum | — | "minimal"（快）/ "high"（精） |

### aspect_ratio 与 AI 生成尺寸对照

| 比例 | AI 生成尺寸 | 适用场景 |
|------|-----------|---------|
| 1:1 | 1024×1024 | 图标、头像、方形素材 |
| 2:3 | 832×1248 | 竖版海报、角色立绘 |
| 3:2 | 1248×832 | 横版场景 |
| 3:4 | 864×1184 | 竖版卡牌 |
| 4:3 | 1184×864 | 传统横版 |
| 9:16 | 768×1344 | 全屏竖版 |
| 16:9 | 1344×768 | 宽屏横版、游戏场景 |
| 21:9 | 1536×672 | 超宽屏 |

### 游戏素材推荐尺寸

| 素材类型 | target_size | aspect_ratio | transparent |
|---------|------------|-------------|------------|
| 小图标 | 64×64 | 1:1 | true |
| 标准图标 | 128×128 | 1:1 | true |
| 大图标 | 256×256 | 1:1 | true |
| UI 元素 | 256×256 | 1:1 | true |
| 角色精灵 | 256×512 | 2:3 | true |
| 贴图纹理 | 512×512 | 1:1 | false |
| 场景背景 | 1024×512 | 16:9 | false |
| 大背景 | 1024×1024 | 1:1 | false |
| 平铺瓦片 | 128×128 | 1:1 | false |

### 输出

- 文件名: `{name}_{timestamp}.png`
- 保存在: `assets/` 目录下

---

## 2. batch_generate_images — 批量图片生成（并行）

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `images` | array | 图片生成请求数组（2-10张推荐） |

每个元素的参数与 `generate_image` 相同。

### 示例

```json
{
  "images": [
    { "prompt": "金色硬币图标，扁平化风格", "name": "coin", "target_size": "128x128", "transparent": true },
    { "prompt": "红色爱心图标，生命值", "name": "heart", "target_size": "128x128", "transparent": true },
    { "prompt": "蓝色宝石图标，闪光效果", "name": "gem", "target_size": "128x128", "transparent": true }
  ]
}
```

### 优势

- 所有图片并行生成，总耗时约等于单张
- 单次调用，减少交互轮次

---

## 3. text_to_sound_effect — 单个音效生成

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `text` | string | 是 | **英文**描述（必须英文） |
| `output_name` | string | 否 | 输出文件名（不含扩展名） |
| `duration_seconds` | number | 否 | 时长 0.5-30 秒 |
| `prompt_influence` | number | 否 | 提示影响度 0-1（默认 0.3） |
| `loop` | boolean | 否 | 是否生成无缝循环音效 |

### 描述编写技巧

```
Good: "Futuristic sci-fi laser gun shot, bright and sharp"
Good: "Gentle healing magic sound, soft chimes and warm glow"
Good: "Massive cinematic explosion with deep bass impact"

Bad:  "laser"         ← 太简短
Bad:  "激光枪声音"     ← 应该用英文
```

### 音效类型与参数推荐

| 音效类型 | duration | loop | prompt_influence |
|---------|----------|------|-----------------|
| UI 点击 | 0.3-0.5 | false | 0.3 |
| 拾取/收集 | 0.5-0.8 | false | 0.3 |
| 跳跃/弹跳 | 0.5-1.0 | false | 0.3 |
| 攻击/命中 | 0.5-1.5 | false | 0.4 |
| 爆炸 | 1.5-3.0 | false | 0.4 |
| 环境氛围 | 5-10 | true | 0.3 |
| 脚步声 | 0.3-0.5 | false | 0.5 |

### 输出

- 格式: OGG 音频
- 保存在: `assets/` 目录下

---

## 4. batch_sound_effects — 批量音效生成

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `sounds` | array | 音效定义数组 |

每个元素：

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `name` | string | 是 | 输出文件名 |
| `text` | string | 是 | 英文描述 |
| `duration` | number | 否 | 时长 |
| `loop` | boolean | 否 | 循环 |

### 示例

```json
{
  "sounds": [
    { "name": "jump", "text": "Soft bouncy character jump with slight spring", "duration": 0.8 },
    { "name": "coin", "text": "Bright coin pickup chime, satisfying ding", "duration": 0.5 },
    { "name": "explosion", "text": "Medium explosion with fire crackle", "duration": 2.0 }
  ]
}
```

---

## 5. text_to_music — 音乐生成

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `prompt` | string | 是 | 音乐描述（英文推荐，max 500字符） |
| `instrumental` | boolean | 否 | 纯器乐（默认 false，游戏BGM建议 true） |
| `model` | enum | 否 | "V3_5"/"V4"/"V4_5"/"V4_5PLUS"/"V5"（推荐 V4_5） |
| `customMode` | boolean | 否 | 自定义模式（需要 style + title） |
| `style` | string | 条件 | 音乐风格（customMode=true 时必填） |
| `title` | string | 条件 | 曲目标题（customMode=true 时必填） |
| `negativeTags` | string | 否 | 排除风格，逗号分隔 |

### 游戏BGM风格推荐

| 游戏类型 | prompt 示例 |
|---------|-----------|
| 休闲益智 | "Light upbeat casual game music, playful and cheerful" |
| 冒险RPG | "Epic orchestral adventure theme, heroic and inspiring" |
| 恐怖 | "Dark ambient horror soundtrack, eerie and unsettling" |
| 科幻 | "Futuristic synthwave electronic, cyberpunk atmosphere" |
| 战斗 | "Intense battle music, fast-paced drums and brass" |
| 菜单界面 | "Calm menu music, gentle piano and soft strings" |
| 像素复古 | "8-bit chiptune retro game music, upbeat pixel adventure" |

### 注意

- 生成耗时较长（1-5分钟）
- 工具会自动轮询直到完成（最长10分钟）
- 返回音频 URL，需下载到本地

---

## 6. create_3d_model_task — 3D 模型生成

### 模式

| 模式 | 说明 | 流程 |
|------|------|------|
| `text_to_model` | 文字生成模型 | 两阶段（预览→确认→生成） |
| `image_to_model` | 图片生成模型 | 两阶段（多视图→确认→生成） |
| `multiview_to_model` | 多视图直接生成 | 一阶段 |

### text_to_model 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `mode` | enum | 是 | "text_to_model" |
| `prompt` | string | 是 | 模型描述（max 1024字符） |
| `subject_type` | enum | 是 | "biped"/"quadruped"/"scenery"/"other" |
| `rig` | boolean | 否 | 自动骨骼绑定（仅 biped） |
| `face_limit` | integer | 否 | 面数上限（48-20000，默认20000） |
| `texture_quality` | enum | 否 | "standard"/"detailed" |

### 重要流程

```
Phase 1: 调用 create_3d_model_task（不传 confirmed_image_paths）
  → 返回预览图路径，等待用户确认
  
Phase 2: 用户确认后，再次调用并传入 confirmed_image_paths
  → 返回 task_id

轮询: query_3d_model_task（至少间隔 30 秒）
  → status: "queued" | "running" | "success" | "failed"
  → 成功后获取模型文件路径
```

### 模型导入

生成的模型是 .glb 格式，需要通过 `import-glb` skill 导入为引擎可用的 .mdl 格式。

---

## 7. search_game_resource — 搜索引擎资源库

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `wanted_resource` | string | 是 | 描述所需资源 |

### 说明

- 搜索 465+ prefab 资产和 1700+ 动画剪辑
- 返回相关性过滤后的结果
- 如果找不到合适资源，可改用 `create_3d_model_task` 生成

### prefab 类别

奇幻幻想生物、卡通萌宠、怪物战斗单位、野生动物、人形角色、
植被植物、岩石地貌、建筑构件、生活道具、工业机械科技、
武器装备、载具、几何基础体

---

## 8. edit_image — 编辑已有图片

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `image` | string | 是 | 源图片路径 |
| `prompt` | string | 是 | 编辑指令 |
| `name` | string | 是 | 输出文件名 |
| `target_size` | string | 是 | 最终尺寸 |

### 适用场景

- 修改已生成素材的颜色/风格
- 添加/移除元素
- 调整背景

---

## 工具调用优先级

```
需要生成素材时的选择顺序：

1. 搜索引擎资源库 (search_game_resource)
   → 如果有现成 prefab 则直接使用

2. 批量生成 (batch_generate_images / batch_sound_effects)
   → 同类型多个素材并行生成

3. 单个生成 (generate_image / text_to_sound_effect / text_to_music)
   → 单个素材或需要特殊参数时

4. 3D 模型生成 (create_3d_model_task)
   → 耗时最长，单独处理

5. 编辑修改 (edit_image)
   → 对已生成的素材做调整
```
