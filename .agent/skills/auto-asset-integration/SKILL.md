---
name: auto-asset-integration
description: |
  游戏素材自动生成与代码自动引用集成工具。扫描项目代码中的资源引用，
  检测缺失素材，使用 AI 工具批量生成（图片/音效/音乐/3D模型），
  并自动将生成结果写入正确路径、更新代码引用、同步构建配置。
  覆盖从"发现缺失"到"代码可运行"的完整闭环。
  Use when users need to (1) 自动扫描并生成缺失的游戏素材,
  (2) 批量生成图片/音效/音乐/3D模型并自动引用,
  (3) 生成素材后自动更新 Lua 代码中的资源引用,
  (4) 同步构建配置确保素材被正确打包,
  (5) 素材生成后一键构建验证,
  (6) 用户说"生成素材" "补全资源" "自动生成并引用" "素材集成",
  (7) auto generate assets and integrate references.
  MUST trigger when: 用户要求生成游戏素材并希望自动集成到代码中。
  trigger-keywords:
    - 素材生成
    - 生成素材
    - 补全资源
    - 自动引用
    - 素材集成
    - asset integration
    - generate assets
    - 缺失素材
    - 批量生成
    - 生成并引用
    - auto asset
    - 补全素材
    - 资源生成
    - 生成资源
  file types: .png, .jpg, .ogg, .wav, .mdl, .ttf
version: "1.0.0"
metadata:
  author: "UrhoX-Skill-Creator"
  tags: ["asset", "generation", "integration", "automation", "workflow"]
---

# 游戏素材自动生成与代码自动引用 Skill

## 角色定义

你是一位 **UrhoX 游戏素材集成专家**，负责完成从"发现缺失素材"到"代码可运行"的完整闭环。
你不仅会生成素材，更会确保生成的素材被正确放置、被代码正确引用、被构建系统正确打包。

---

## 核心工作流（6 阶段）

```
┌─────────────────────────────────────────────────────┐
│  Phase 1: SCAN（扫描）                                │
│  扫描 scripts/ 中所有资源引用路径                       │
│  ↓                                                    │
│  Phase 2: CHECK（检测）                                │
│  对照 assets/ 目录检查哪些素材缺失                      │
│  ↓                                                    │
│  Phase 3: CLASSIFY（分类 + 推断描述）                   │
│  按类型分类，根据上下文推断生成描述                      │
│  ↓                                                    │
│  Phase 4: REPORT（报告 + 确认）                        │
│  向用户展示缺失清单，等待确认后执行                      │
│  ↓                                                    │
│  Phase 5: GENERATE（生成 + 放置）                      │
│  调用 AI 工具生成素材，放置到正确路径                    │
│  ↓                                                    │
│  Phase 6: INTEGRATE（集成 + 验证）                     │
│  更新代码引用、同步构建配置、调用 build 验证             │
└─────────────────────────────────────────────────────┘
```

---

## Phase 1: SCAN — 扫描资源引用

### 扫描命令集

使用以下 grep 命令扫描 `scripts/` 目录中的所有资源引用：

```bash
# 1. Texture2D 贴图引用
grep -rn 'cache:GetResource\s*(\s*"Texture2D"\s*,\s*"[^"]*"' scripts/

# 2. Sound 音效引用
grep -rn 'cache:GetResource\s*(\s*"Sound"\s*,\s*"[^"]*"' scripts/

# 3. Model 3D模型引用
grep -rn 'cache:GetResource\s*(\s*"Model"\s*,\s*"[^"]*"' scripts/

# 4. Font 字体引用
grep -rn 'cache:GetResource\s*(\s*"Font"\s*,\s*"[^"]*"' scripts/

# 5. Material 材质引用
grep -rn 'cache:GetResource\s*(\s*"Material"\s*,\s*"[^"]*"' scripts/

# 6. Animation 动画引用
grep -rn 'cache:GetResource\s*(\s*"Animation"\s*,\s*"[^"]*"' scripts/

# 7. NanoVG 图片引用
grep -rn 'nvgCreateImage\s*(\s*vg\s*,\s*"[^"]*"' scripts/

# 8. NanoVG 字体引用
grep -rn 'nvgCreateFont\s*(\s*vg\s*,\s*"[^"]*"\s*,\s*"[^"]*"' scripts/

# 9. Sprite2D / SpriteSheet2D 引用
grep -rn 'cache:GetResource\s*(\s*"Sprite2D"\s*,\s*"[^"]*"' scripts/
grep -rn 'cache:GetResource\s*(\s*"SpriteSheet2D"\s*,\s*"[^"]*"' scripts/

# 10. ParticleEffect 粒子效果引用
grep -rn 'cache:GetResource\s*(\s*"ParticleEffect"\s*,\s*"[^"]*"' scripts/

# 11. XMLFile (可能是UI布局/材质定义)
grep -rn 'cache:GetResource\s*(\s*"XMLFile"\s*,\s*"[^"]*"' scripts/

# 12. 直接路径字符串（补充扫描）
grep -rn '"[A-Z][a-zA-Z]*/[^"]*\.\(png\|jpg\|ogg\|wav\|mdl\|ttf\|otf\|xml\|ani\)"' scripts/
```

### 扫描结果解析

将扫描结果整理为结构化数据：

```lua
-- 解析后的数据结构
{
    {
        file = "scripts/main.lua",     -- 引用所在文件
        line = 42,                     -- 行号
        type = "Texture2D",            -- 资源类型
        path = "Textures/hero.png",    -- 资源路径（相对于 assets/）
        context = "local heroTex = cache:GetResource(...)"  -- 上下文代码
    },
    -- ...
}
```

---

## Phase 2: CHECK — 检测缺失素材

### 存在性检查

```bash
# 对每个扫描到的路径，检查是否存在于 assets/ 目录
# 资源路径直接映射到 assets/ 下
#   代码中: "Textures/hero.png"
#   文件:   assets/Textures/hero.png

for path in "${resource_paths[@]}"; do
    if [ \! -f "assets/$path" ]; then
        echo "MISSING: $path"
    fi
done
```

### 排除内置资源

以下资源由引擎内置提供，**不需要生成**：

| 类别 | 内置资源路径 | 说明 |
|------|------------|------|
| 字体 | `Fonts/MiSans-Regular.ttf` | 引擎默认字体 |
| 字体 | `Fonts/MiSans-Bold.ttf` | 引擎默认粗体 |
| 模型 | `Models/Box.mdl` | 内置立方体 |
| 模型 | `Models/Sphere.mdl` | 内置球体 |
| 模型 | `Models/Cylinder.mdl` | 内置圆柱 |
| 模型 | `Models/Cone.mdl` | 内置圆锥 |
| 模型 | `Models/Plane.mdl` | 内置平面 |
| 模型 | `Models/Torus.mdl` | 内置圆环 |
| Technique | `Techniques/PBR/*.xml` | 内置渲染技术 |
| Technique | `Techniques/*.xml` | 内置渲染技术 |
| RenderPath | `RenderPaths/*.xml` | 内置渲染路径 |
| 着色器 | `Shaders/*.glsl` | 内置着色器 |
| 材质 | `Materials/DefaultGrey.xml` 等 | 引擎默认材质 |
| 纹理 | `Textures/Ramp.png` 等 | 引擎内置纹理 |

**排除规则**：
1. 路径以 `Techniques/`、`RenderPaths/`、`Shaders/`、`CoreData/` 开头 → 跳过
2. 路径匹配上表中的内置资源 → 跳过
3. 查阅 `engine-docs/built-in-models.md` 确认完整内置模型列表

---

## Phase 3: CLASSIFY — 分类与描述推断

### 素材分类规则

| 分类 | 判断条件 | 生成工具 | 默认参数 |
|------|---------|---------|---------|
| **icon** | 路径含 `Icon`/`icon`，或尺寸 ≤256px | `generate_image` | 128×128, 1:1, transparent=true |
| **ui** | 路径在 `UI/`/`Sprites/` 下 | `generate_image` | 256×256, 1:1, transparent=true |
| **texture** | 路径在 `Textures/` 下（非UI） | `generate_image` | 512×512, 1:1, transparent=false |
| **background** | 路径含 `bg`/`background`/`scene` | `generate_image` | 1024×512, 16:9, transparent=false |
| **sfx** | `.ogg`/`.wav` 在 `Sounds/`/`SFX/` 下 | `text_to_sound_effect` | 0.5-3.0s |
| **bgm** | `.ogg` 在 `Music/`/`BGM/` 下 | `text_to_music` | instrumental=true |
| **model_3d** | `.mdl` 在 `Models/` 下（非内置） | `create_3d_model_task` | face_limit=20000 |
| **font** | `.ttf`/`.otf` | 不生成，建议替代方案 | — |
| **material** | `.xml` 在 `Materials/` 下 | 不生成，手动创建 | — |
| **particle** | `.xml` 粒子效果 | 不生成，手动创建 | — |

### 描述推断策略

根据以下信息推断素材的生成描述：

**1. 文件名推断**：
```
coin_icon.png     → "金色硬币图标，游戏内货币，像素风格"
explosion.ogg     → "Explosion sound effect, bright and impactful"
hero_idle.png     → "游戏主角待机姿态，正面视角"
forest_bg.png     → "森林场景背景，绿色树木，阳光透射"
```

**2. 代码上下文推断**：
```lua
-- 扫描引用点前后 10 行的代码
-- 提取变量名、注释、函数调用等信息

-- 示例：如果代码中有
local coinIcon = cache:GetResource("Texture2D", "UI/coin.png")
-- → 推断描述: "金色硬币图标，游戏货币，扁平化设计风格，透明背景"

-- 示例：如果代码中有
-- 播放跳跃音效
local jumpSound = cache:GetResource("Sound", "Sounds/jump.ogg")
-- → 推断描述: "Character jump sound effect, soft bouncy landing"
```

**3. 目录层级推断**：
```
Textures/UI/      → 可能是 UI 元素（透明背景）
Textures/Env/     → 可能是环境贴图（不透明）
Textures/Char/    → 可能是角色贴图
Sounds/SFX/       → 短音效
Sounds/BGM/       → 背景音乐
Sounds/UI/        → UI 交互音效（短促）
```

**语言规则**：
- 图片描述使用**中文**（`generate_image` prompt 参数要求中文）
- 音效描述使用**英文**（`text_to_sound_effect` text 参数要求英文）
- 音乐描述使用**英文**（`text_to_music` prompt 参数支持英文更佳）

---

## Phase 4: REPORT — 报告与确认

### 报告格式

向用户展示以下格式的报告：

```
══════════════════════════════════════════
  素材扫描报告
══════════════════════════════════════════
扫描范围: scripts/ (XX 个文件, XXXX 行代码)
引用总数: XX 个资源引用
缺失数量: XX 个素材需要生成
已存在:   XX 个素材已就位
已排除:   XX 个内置资源（无需生成）

────────────────────────────────────────
  缺失素材清单
────────────────────────────────────────

📷 图片素材 (X 个)
┌──────┬───────────────────────┬──────────┬────────────────────────┐
│ 序号 │ 路径                  │ 尺寸     │ 推断描述               │
├──────┼───────────────────────┼──────────┼────────────────────────┤
│  1   │ Textures/hero.png     │ 256×256  │ 游戏主角正面全身像     │
│  2   │ UI/coin.png           │ 128×128  │ 金色硬币图标，透明背景 │
│  3   │ Textures/bg_forest.png│ 1024×512 │ 森林场景背景           │
└──────┴───────────────────────┴──────────┴────────────────────────┘

🔊 音效素材 (X 个)
┌──────┬───────────────────────┬──────────┬──────────────────────────────┐
│ 序号 │ 路径                  │ 时长     │ 推断描述                     │
├──────┼───────────────────────┼──────────┼──────────────────────────────┤
│  1   │ Sounds/jump.ogg       │ 0.8s     │ Soft jump with bouncy feel   │
│  2   │ Sounds/coin.ogg       │ 0.5s     │ Coin pickup, bright chime    │
└──────┴───────────────────────┴──────────┴──────────────────────────────┘

🎵 背景音乐 (X 个)
┌──────┬───────────────────────┬────────────────────────────────────────┐
│ 序号 │ 路径                  │ 推断描述                               │
├──────┼───────────────────────┼────────────────────────────────────────┤
│  1   │ Music/main_theme.ogg  │ Upbeat adventure game theme, orchestral│
└──────┴───────────────────────┴────────────────────────────────────────┘

🧊 3D 模型 (X 个)
┌──────┬───────────────────────┬────────────────────────────────────────┐
│ 序号 │ 路径                  │ 推断描述                               │
├──────┼───────────────────────┼────────────────────────────────────────┤
│  1   │ Models/enemy.mdl      │ Low-poly cartoon enemy character       │
└──────┴───────────────────────┴────────────────────────────────────────┘

⚠️ 无法自动生成 (X 个)
  - Materials/custom.xml  → 需手动创建材质定义
  - Fonts/custom.ttf      → 建议使用内置字体 Fonts/MiSans-Regular.ttf

══════════════════════════════════════════
  请确认是否开始生成？(可修改描述后再确认)
══════════════════════════════════════════
```

### 用户交互

- **用户确认后**：进入 Phase 5 执行生成
- **用户修改描述**：更新对应条目的描述后重新确认
- **用户排除某些条目**：从生成列表中移除
- **用户补充新条目**：手动添加需要的素材

---

## Phase 5: GENERATE — 生成与放置

### 生成策略

**并行优先**：同类型素材尽量批量并行生成。

#### 5.1 图片生成

```
使用工具: batch_generate_images（多张）或 generate_image（单张）

参数映射:
  prompt     ← 推断的中文描述
  name       ← 文件名（不含扩展名）
  target_size ← 根据分类确定（见 Phase 3 表格）
  aspect_ratio ← 根据分类确定
  transparent  ← icon/ui 类型为 true，其他为 false
```

**尺寸参考表**：

| 分类 | target_size | aspect_ratio | transparent |
|------|------------|-------------|------------|
| icon | 64×64 / 128×128 | 1:1 | true |
| ui | 256×256 | 1:1 | true |
| texture | 512×512 | 1:1 | false |
| background | 1024×512 | 16:9 | false |
| sprite | 256×256 / 512×512 | 1:1 | true |
| tile | 128×128 / 256×256 | 1:1 | false |

#### 5.2 音效生成

```
使用工具: batch_sound_effects（多个）或 text_to_sound_effect（单个）

参数映射:
  text          ← 推断的英文描述
  output_name   ← 文件名（不含扩展名和路径）
  duration_seconds ← 根据类型推断
  loop          ← 环境音/氛围音为 true
```

**时长参考表**：

| 音效类型 | 典型时长 | loop |
|---------|---------|------|
| UI 点击/交互 | 0.3-0.5s | false |
| 短促音效（跳跃/拾取） | 0.5-1.0s | false |
| 中等音效（爆炸/技能） | 1.5-3.0s | false |
| 环境音/氛围 | 5-10s | true |

#### 5.3 音乐生成

```
使用工具: text_to_music

参数映射:
  prompt       ← 英文描述
  instrumental ← 通常为 true（游戏BGM无人声）
  model        ← "V4_5"（推荐最佳质量）
```

#### 5.4 3D 模型生成

```
使用工具: create_3d_model_task + query_3d_model_task

流程:
  1. 调用 create_3d_model_task (mode="text_to_model")
     → Phase 1 返回预览图片，等待用户确认
  2. 用户确认后，传入 confirmed_image_paths 创建模型
  3. 轮询 query_3d_model_task 直到完成
  4. 模型文件 (.glb) 需要通过 import-glb skill 导入为 .mdl

注意: 3D 模型生成较慢（1-5 分钟），与其他素材分开处理
```

### 文件放置规则

生成的文件必须放到 `assets/` 目录下的正确路径：

```
代码引用路径               → 文件存放位置
─────────────────────────────────────────
Textures/hero.png         → assets/Textures/hero.png
UI/coin.png               → assets/UI/coin.png
Sounds/jump.ogg           → assets/Sounds/jump.ogg
Music/theme.ogg           → assets/Music/theme.ogg
Models/enemy.mdl          → assets/Models/enemy.mdl
```

**目录创建**：生成前自动创建所需子目录：
```bash
mkdir -p assets/Textures assets/UI assets/Sounds assets/Music assets/Models
```

**文件移动**：AI 工具生成的文件通常在 `assets/` 根目录或 `game_material/` 下，
需要移动到代码引用的正确路径：
```bash
# 示例: 生成的图片在 assets/hero_20250101120000.png
# 需要移动到 assets/Textures/hero.png
mv assets/hero_*.png assets/Textures/hero.png
```

---

## Phase 6: INTEGRATE — 集成与验证

### 6.1 代码引用验证

检查生成的素材是否被代码正确引用：

```bash
# 验证每个生成的素材都有对应的代码引用
for asset in $(find assets/ -type f -name "*.png" -o -name "*.ogg" -o -name "*.mdl"); do
    relative_path=${asset#assets/}
    if \! grep -r "\"$relative_path\"" scripts/ > /dev/null 2>&1; then
        echo "WARNING: $relative_path 已生成但代码中没有引用"
    fi
done
```

### 6.2 代码引用自动补全

当素材已生成但代码中**尚未写入引用代码**时（例如用户预先规划了素材但还没写加载逻辑），
提供引用代码模板：

```lua
-- 图片加载模板
local tex = cache:GetResource("Texture2D", "Textures/hero.png")

-- 音效加载与播放模板
local sound = cache:GetResource("Sound", "Sounds/jump.ogg")
sound.looped = false  -- 或 true（循环播放）
local source = node:CreateComponent("SoundSource")
source:Play(sound)

-- 背景音乐模板
local bgm = cache:GetResource("Sound", "Music/theme.ogg")
bgm.looped = true
local musicSource = scene_:CreateChild("BGM"):CreateComponent("SoundSource")
musicSource.soundType = SOUND_MUSIC
musicSource:Play(bgm)

-- 3D 模型加载模板
local model = node:CreateComponent("StaticModel")
model:SetModel(cache:GetResource("Model", "Models/enemy.mdl"))
model:SetMaterial(cache:GetResource("Material", "Materials/DefaultGrey.xml"))

-- NanoVG 图片加载模板（在 HandleNanoVGRender 外初始化）
local img = nvgCreateImage(vg, "UI/background.png", 0)

-- Sprite2D 加载模板
local sprite = node:CreateComponent("StaticSprite2D")
sprite:SetSprite(cache:GetResource("Sprite2D", "Sprites/player.png"))
```

### 6.3 构建配置检查

检查 `resources.json` 确保素材被构建系统包含：

```bash
# 读取当前构建配置
cat .project/resources.json 2>/dev/null || echo "无 resources.json（使用默认全量引用）"
```

**构建模式处理**：

| 构建模式 | resources.json 内容 | 素材处理 |
|---------|-------------------|---------|
| 全量引用（默认） | `{"groups":{"default":["**"]}}` | 无需额外操作 |
| 增强引用 | `{"groups":{"default":["scripts/**"]}}` | ⚠️ 需确保素材被代码引用 |
| 无 resources.json | 不存在此文件 | 无需额外操作（默认全量） |

**增强引用模式警告**：
如果检测到增强引用模式（`groups` 中不包含 `**`），需要：
1. 提醒用户：未被代码引用的素材会在构建时被裁剪
2. 确认所有生成的素材都有 `cache:GetResource()` 调用
3. 或者建议临时切换为全量引用模式

### 6.4 调用构建验证

**生成完成后，必须调用 build 工具验证**：

```
调用 MCP build 工具
  ↓
检查构建结果
  ↓
├─ 成功 → 报告完成，列出所有生成和集成的素材
└─ 失败 → 分析错误，通常是路径不匹配或文件格式问题
```

### 6.5 变更日志

生成完成后，输出变更摘要：

```
══════════════════════════════════════════
  素材生成与集成报告
══════════════════════════════════════════
生成时间: 2025-XX-XX XX:XX

📷 图片素材 (X 个已生成)
  ✅ assets/Textures/hero.png      ← 256×256
  ✅ assets/UI/coin.png            ← 128×128, 透明背景
  ✅ assets/Textures/bg_forest.png ← 1024×512

🔊 音效素材 (X 个已生成)
  ✅ assets/Sounds/jump.ogg        ← 0.8s
  ✅ assets/Sounds/coin.ogg        ← 0.5s

🎵 背景音乐 (X 个已生成)
  ✅ assets/Music/main_theme.ogg   ← instrumental

🔧 代码引用状态
  ✅ 所有素材均有对应代码引用
  ⚠️ X 个素材需要手动添加引用代码（已提供模板）

🏗️ 构建验证
  ✅ build 成功，所有资源已正确打包
══════════════════════════════════════════
```

---

## 素材描述推断详细规则

### 文件名 → 描述映射（常见模式）

| 文件名关键词 | 推断类型 | 中文描述模板 | 英文描述模板（音效） |
|-------------|---------|------------|-------------------|
| hero/player/character | 角色 | "游戏主角，{风格}" | — |
| enemy/monster/boss | 敌人 | "敌方角色，{类型}" | — |
| coin/gold/gem | 货币 | "金色{物品}图标，透明背景" | "Coin/gold pickup, bright chime" |
| heart/hp/life | 生命值 | "红色爱心图标，生命值" | — |
| sword/weapon/shield | 装备 | "{装备}图标，游戏道具" | — |
| bg/background/scene | 背景 | "{场景}背景画面" | — |
| button/btn | 按钮 | "{颜色}圆角按钮" | — |
| explosion/boom | 爆炸 | — | "Explosion, {intensity}" |
| jump/bounce | 跳跃 | — | "Jump sound, {style}" |
| click/tap/select | 点击 | — | "UI click, soft and clean" |
| hit/damage/hurt | 受击 | — | "Impact hit, {weight}" |
| victory/win/success | 胜利 | — | "Victory fanfare, triumphant" |
| defeat/lose/fail | 失败 | — | "Defeat sound, melancholic" |
| door/open/close | 开关 | — | "Door {action}, wooden creak" |
| footstep/walk/step | 脚步 | — | "Footstep on {surface}" |

### 游戏风格推断

从代码整体风格推断素材描述的美术方向：

```
检查指标:
  - NanoVG 大量使用 → 可能是 2D 矢量风格
  - Box2D 物理 → 2D 平台跳跃/物理游戏
  - 3D 场景 + PBR 材质 → 写实/卡通 3D
  - 像素风/pixel 关键词 → 像素美术风格
  - 等距/isometric 关键词 → 等距视角
```

---

## 错误处理

### 常见问题与解决方案

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 生成的图片路径不匹配 | AI 工具输出文件名含时间戳 | 使用 `mv` 重命名到目标路径 |
| 音效格式不是 .ogg | 工具默认输出 .ogg | 通常已是 .ogg，无需转换 |
| 3D 模型是 .glb 不是 .mdl | 需要导入转换 | 使用 import-glb skill |
| 构建时素材被裁剪 | 增强引用模式下无代码引用 | 添加代码引用或切换全量模式 |
| 字体文件无法生成 | AI 不能生成字体 | 建议使用引擎内置字体 |
| 材质 XML 无法生成 | 需要手动编写 | 使用 materials skill |

### 降级策略

当 AI 生成工具暂时不可用时：

1. **图片** → 建议使用纯色占位图，或使用 `game-assets-finder` skill 搜索免费素材
2. **音效** → 建议使用 `game-assets-finder` skill 搜索免费音效
3. **音乐** → 同上
4. **3D 模型** → 使用 `search_game_resource` 搜索引擎资源库

---

## 与其他 Skill 的协作

| Skill | 协作方式 |
|-------|---------|
| `auto-game-assets` | 本 Skill 覆盖其功能并增加"自动引用"环节 |
| `materials` | 材质类素材委托给 materials skill 处理 |
| `game-assets-finder` | 作为 AI 生成不可用时的降级方案 |
| `ai-asset-pipeline` | 用于设计批量生成的工作流 |
| `game-bug-checker` | 生成完成后可运行检查是否引入新问题 |
| `import-glb` | 3D 模型生成后的导入转换 |
| `import-fbx` | FBX 格式模型的导入转换 |

---

## 交付前检查清单

- [ ] Phase 1: 所有扫描模式都已执行
- [ ] Phase 2: 正确排除了内置资源
- [ ] Phase 3: 每个素材都有合理的分类和描述
- [ ] Phase 4: 报告已展示给用户并获得确认
- [ ] Phase 5: 所有素材已生成并放置到正确路径
- [ ] Phase 6: 代码引用已验证/补全
- [ ] Phase 6: 已调用 build 工具验证构建成功
- [ ] Phase 6: 变更日志已输出

---

## 参考文档

- `references/tool-parameters.md` — AI 生成工具完整参数规格
- `references/resource-path-rules.md` — 引擎资源路径规则与格式对照表
- `engine-docs/recipes/preload-and-build-refs.md` — 构建引用策略
- `engine-docs/recipes/download-while-playing.md` — DWP 边玩边下
- `engine-docs/built-in-models.md` — 内置模型列表
- CLAUDE.md Rule #1.5 — 资源路径引用规则
