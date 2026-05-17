# AI 工具完整目录与参数速查

灵感源自 [awesome-ai-tools-for-game-dev](https://github.com/simoninithomas/awesome-ai-tools-for-game-dev)，
仅收录 UrhoX MCP 工具链中实际可用的工具。

---

## 1. 图像生成工具

### generate_image

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| prompt | string | ✅ | 图像描述（中文，≤50KB） |
| name | string | ✅ | 文件名（不含扩展名） |
| target_size | string | ✅ | 最终尺寸（如 "256x256"） |
| aspect_ratio | enum | 可选 | 1:1/2:3/3:2/16:9 等 |
| transparent | bool | 可选 | 透明背景 |
| reference_images | array | 可选 | 参考图（≤14张） |
| resolution | enum | 可选 | 0.5K/1K/2K/4K |

**最佳实践**：
- 图标/道具：`target_size="128x128"`, `aspect_ratio="1:1"`, `transparent=true`
- 场景背景：`target_size="1024x512"`, `aspect_ratio="16:9"`
- 角色立绘：`target_size="512x1024"`, `aspect_ratio="2:3"`, `transparent=true`

### batch_generate_images

同 `generate_image`，但接受 `images` 数组（2-10 张并行生成）。
适用于风格一致的系列素材。

### edit_image

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| image | string | ✅ | 源图片路径 |
| prompt | string | ✅ | 编辑指令 |
| name | string | ✅ | 输出文件名 |
| target_size | string | ✅ | 输出尺寸 |

---

## 2. 3D 模型工具

### create_3d_model_task

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mode | enum | ✅ | text_to_model / image_to_model / multiview_to_model |
| prompt | string | 文生3D时 | 模型描述（≤1024字） |
| image | string | 图生3D时 | 正面照参考图 |
| rig | bool | 可选 | 自动绑骨骼（仅双足人形） |
| subject_type | enum | 文生3D时 | biped/quadruped/scenery/other |
| face_limit | int | 可选 | 面数上限（48-20000） |

**两阶段流程**：
1. Phase 1：生成多视图预览 → 等待用户确认
2. Phase 2：用确认的图片生成 3D 模型

### search_game_resource

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| wanted_resource | string | ✅ | 资源描述（中文/英文） |

返回预制件 XML 或动画片段。465+ 预制件，1700+ 动画片段。

---

## 3. 音频工具

### text_to_music

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| prompt | string | ✅ | 音乐描述（≤500字） |
| customMode | bool | 可选 | 精细控制模式 |
| style | string | 自定义时 | 音乐风格 |
| title | string | 自定义时 | 曲名 |
| instrumental | bool | 可选 | 纯器乐（无人声） |
| model | enum | 可选 | V3_5/V4/V4_5/V4_5PLUS/V5 |

### text_to_sound_effect

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| text | string | ✅ | 音效描述（英文效果最佳） |
| duration_seconds | float | 可选 | 时长 0.5-30 秒 |
| loop | bool | 可选 | 循环音效（环境音） |
| output_name | string | 可选 | 输出文件名 |

### batch_sound_effects

批量版 `text_to_sound_effect`。接受 `sounds` 数组。

---

## 4. 语音工具

### audition_voices_for_character

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| character_name | string | ✅ | 角色名 |
| character_description | string | ✅ | 六维度声音描述 |
| audition_line | string | ✅ | 试听台词（≥100字） |
| candidate_count | int | 可选 | 候选数 1-3 |

**六维度描述模板**：
```
[年龄/性别] + [音色] + [语速] + [情感] + [风格] + [录音质量]
```

### confirm_character_voice

确认声音选择，消耗 1 个 Voice Slot。

### text_to_dialogue

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| inputs | array | ✅ | [{character_name, text}] |
| language_code | string | 可选 | 默认 "cmn"（普通话） |
| stability | float | 可选 | 0-1，越低越有情感 |

---

## 5. 视频工具

### create_video_task

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mode | enum | ✅ | text_to_video/first_frame/first_last_frame/multi_modal_reference |
| prompt | string | 文生视频时 | 视频描述 |
| duration | int | 可选 | 4-15 秒 |

适用于游戏宣传视频、过场动画预览。

---

## 6. 游戏发布工具

### generate_game_material

生成图标、截图、宣传图等发布素材。

| material_type | 说明 | 需要输入 |
|--------------|------|---------|
| ICON | 游戏图标 | 不需要 |
| SCREENSHOT | 截图优化 | 需要真实截图 |
| PROMO | 宣传图 | 需要真实截图 |
| ALL_IN_ONE | 一键全部 | 需要真实截图 |

---

## 工具选型速查表

| 需求 | 推荐工具 | 备注 |
|------|---------|------|
| 游戏图标 | generate_image (128×128, transparent) | |
| 角色纹理 | generate_image (512×512) | |
| 批量道具图标 | batch_generate_images | 风格一致 |
| 3D 角色 | create_3d_model_task (rig=true) | 带骨骼 |
| 3D 道具 | create_3d_model_task | 不带骨骼 |
| 预制角色/场景 | search_game_resource | 465+ 资产 |
| 动画片段 | search_game_resource | 1700+ 动画 |
| 背景音乐 | text_to_music | |
| 单个音效 | text_to_sound_effect | 英文描述 |
| 批量音效 | batch_sound_effects | |
| NPC 语音 | audition → confirm → text_to_dialogue | |
| 宣传视频 | create_video_task | |
| 发布素材 | generate_game_material | |
