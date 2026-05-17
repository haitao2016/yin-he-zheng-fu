# G.E.T. 环境配置指南

> 环境变量系统、覆盖策略与多平台适配完整指南。
> 灵感来源于 GitLab Environment Toolkit 的 vars.yml 环境变量体系。

---

## 1. 环境配置概述

### 1.1 什么是环境配置？

环境配置（Environment Config）是一套参数化系统，允许同一份场景蓝图在不同环境下表现不同。这直接映射了 GitLab Environment Toolkit 中 `vars.yml` 的设计理念：同一套 Terraform/Ansible 配置通过不同变量文件部署到不同环境。

### 1.2 核心场景

| 场景 | GET 对应 | G.E.T. 实现 |
|------|---------|-------------|
| 开发环境快速迭代 | `vars.yml` (dev) | `env-config.json` → `"dev"` |
| 预发布环境测试 | `vars.yml` (staging) | `env-config.json` → `"staging"` |
| 正式发布版本 | `vars.yml` (production) | `env-config.json` → `"production"` |
| 不同目标平台 | Multi-cloud | `"platform_overrides"` |
| 难度变化 | 不同规模的 Reference Architecture | `"difficulty_presets"` |

---

## 2. env-config.json 格式规范

### 2.1 完整格式

```json
{
  "format": "env-config-v1",
  "default_env": "dev",
  "common": {
    "game_title": "My Game",
    "version": "1.0.0",
    "debug_overlay": false,
    "log_level": "warn"
  },
  "environments": {
    "dev": {
      "physics": {
        "gravity": -5.0,
        "debug_draw": true
      },
      "gameplay": {
        "enemy_speed": 1.0,
        "enemy_health_multiplier": 0.5,
        "player_invincible": true,
        "skip_tutorial": true
      },
      "rendering": {
        "shadow_quality": "low",
        "particle_density": 0.3
      },
      "debug": {
        "show_fps": true,
        "show_entity_count": true,
        "show_zones": true,
        "enable_fly_camera": true
      }
    },
    "staging": {
      "physics": {
        "gravity": -9.81,
        "debug_draw": false
      },
      "gameplay": {
        "enemy_speed": 2.5,
        "enemy_health_multiplier": 0.8,
        "player_invincible": false,
        "skip_tutorial": false
      },
      "rendering": {
        "shadow_quality": "medium",
        "particle_density": 0.7
      },
      "debug": {
        "show_fps": true,
        "show_entity_count": false,
        "show_zones": false,
        "enable_fly_camera": false
      }
    },
    "production": {
      "physics": {
        "gravity": -9.81,
        "debug_draw": false
      },
      "gameplay": {
        "enemy_speed": 3.0,
        "enemy_health_multiplier": 1.0,
        "player_invincible": false,
        "skip_tutorial": false
      },
      "rendering": {
        "shadow_quality": "high",
        "particle_density": 1.0
      },
      "debug": {
        "show_fps": false,
        "show_entity_count": false,
        "show_zones": false,
        "enable_fly_camera": false
      }
    }
  },
  "difficulty_presets": {
    "easy": {
      "gameplay.enemy_speed": 1.5,
      "gameplay.enemy_health_multiplier": 0.6,
      "gameplay.player_damage_multiplier": 1.5
    },
    "normal": {
      "gameplay.enemy_speed": 3.0,
      "gameplay.enemy_health_multiplier": 1.0,
      "gameplay.player_damage_multiplier": 1.0
    },
    "hard": {
      "gameplay.enemy_speed": 4.5,
      "gameplay.enemy_health_multiplier": 1.5,
      "gameplay.player_damage_multiplier": 0.7
    }
  },
  "platform_overrides": {
    "mobile": {
      "rendering.shadow_quality": "low",
      "rendering.particle_density": 0.5,
      "gameplay.touch_controls": true
    },
    "pc": {
      "rendering.shadow_quality": "high",
      "rendering.particle_density": 1.0,
      "gameplay.touch_controls": false
    }
  }
}
```

### 2.2 字段说明

| 字段 | 类型 | 必须 | 说明 |
|-----|------|------|------|
| `format` | string | 是 | 固定为 `"env-config-v1"` |
| `default_env` | string | 是 | 默认使用的环境名称 |
| `common` | object | 否 | 所有环境共享的基础配置 |
| `environments` | object | 是 | 各环境的完整配置 |
| `difficulty_presets` | object | 否 | 难度预设覆盖（点号路径格式） |
| `platform_overrides` | object | 否 | 平台特定覆盖（点号路径格式） |

---

## 3. 变量覆盖策略

### 3.1 覆盖优先级（从低到高）

```
Level 1: 蓝图默认值（scene-blueprint.json 中的值）
    ↓ 被覆盖
Level 2: common 通用配置（env-config.json → common）
    ↓ 被覆盖
Level 3: 环境配置（env-config.json → environments.{env}）
    ↓ 被覆盖
Level 4: 难度预设（env-config.json → difficulty_presets.{preset}）
    ↓ 被覆盖
Level 5: 平台覆盖（env-config.json → platform_overrides.{platform}）
    ↓ 被覆盖
Level 6: 运行时覆盖（蓝图中的 env_overrides 或代码直接设置）
```

### 3.2 覆盖示例

假设蓝图中设置了 `enemy_speed = 2.0`:

```
蓝图默认:      enemy_speed = 2.0
环境 (dev):     enemy_speed = 1.0    → 结果: 1.0
难度 (hard):    enemy_speed = 4.5    → 结果: 4.5
平台 (mobile):  (未设置)              → 结果: 4.5 (保持)
运行时覆盖:     enemy_speed = 10.0   → 最终: 10.0
```

### 3.3 点号路径格式

难度预设和平台覆盖使用点号分隔的路径格式：

```json
{
  "gameplay.enemy_speed": 4.5,
  "physics.gravity": -15.0,
  "rendering.shadow_quality": "low"
}
```

等价于：

```json
{
  "gameplay": { "enemy_speed": 4.5 },
  "physics": { "gravity": -15.0 },
  "rendering": { "shadow_quality": "low" }
}
```

---

## 4. EnvConfig Lua 模块

### 4.1 基本用法

```lua
local EnvConfig = require("scripts/get/EnvConfig")

-- 加载配置文件
local config = EnvConfig.Load("scripts/data/env-config.json")

-- 读取当前环境的值
local gravity = config:Get("physics.gravity")          -- -9.81
local speed = config:Get("gameplay.enemy_speed")        -- 3.0
local title = config:Get("game_title")                  -- "My Game" (from common)

-- 读取带默认值
local custom = config:Get("gameplay.custom_feature", false)  -- false (不存在时)

-- 检查调试模式
if config:IsDebug() then
    print("Debug mode is ON")
end
```

### 4.2 切换环境

```lua
-- 切换到开发环境
config:SwitchEnvironment("dev")

-- 此后所有 Get() 调用返回 dev 环境的值
local gravity = config:Get("physics.gravity")  -- -5.0 (dev 的值)
```

### 4.3 应用难度预设

```lua
-- 在当前环境基础上叠加难度覆盖
config:ApplyDifficultyPreset("hard")

-- hard 预设中定义的值将覆盖环境值
local speed = config:Get("gameplay.enemy_speed")  -- 4.5 (hard 预设)
```

### 4.4 应用平台覆盖

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

-- 根据当前平台自动应用覆盖
local platform = PlatformUtils.isMobile() and "mobile" or "pc"
config:ApplyPlatformOverride(platform)
```

### 4.5 与 SceneProvisioner 集成

```lua
-- 将环境配置传递给场景供应器
local blueprint = BlueprintLoader.Load("scripts/data/level1.json")

-- EnvConfig 的值会通过 env_overrides 传入蓝图
blueprint.scene.physics.gravity = config:Get("physics.gravity")
blueprint.scene.lighting.ambient = config:Get("rendering.ambient_light", {0.4, 0.4, 0.5})

-- 然后正常供应场景
local inventory = SceneProvisioner.Apply(scene_, blueprint.scene)
```

---

## 5. 多平台适配策略

### 5.1 平台差异矩阵

| 配置项 | Mobile | PC | 说明 |
|-------|--------|-----|------|
| `shadow_quality` | low | high | 移动端性能优先 |
| `particle_density` | 0.5 | 1.0 | 减少粒子数量 |
| `draw_distance` | 100 | 300 | 缩短绘制距离 |
| `touch_controls` | true | false | 输入方式切换 |
| `ui_scale` | 1.2 | 1.0 | 移动端 UI 放大 |
| `texture_quality` | medium | high | 贴图分辨率 |

### 5.2 自动平台检测

```lua
local PlatformUtils = require("urhox-libs.Platform.PlatformUtils")

-- 自动检测并应用平台覆盖
function ApplyPlatformConfig(config)
    if PlatformUtils.isMobile() then
        config:ApplyPlatformOverride("mobile")
    else
        config:ApplyPlatformOverride("pc")
    end
end
```

### 5.3 平台特定逻辑

```lua
-- 根据配置决定输入方式
if config:Get("gameplay.touch_controls") then
    -- 初始化触屏控制
    SetupTouchControls()
else
    -- 初始化键鼠控制
    SetupKeyboardMouseControls()
end
```

---

## 6. 常见配置模板

### 6.1 开发环境 (dev)

开发环境的核心目标：**快速迭代、容易调试**

```json
{
  "physics": { "gravity": -5.0, "debug_draw": true },
  "gameplay": {
    "enemy_speed": 1.0,
    "player_invincible": true,
    "skip_tutorial": true,
    "unlock_all_levels": true
  },
  "debug": {
    "show_fps": true,
    "show_entity_count": true,
    "show_zones": true,
    "enable_fly_camera": true,
    "log_level": "debug"
  }
}
```

### 6.2 预发布环境 (staging)

预发布环境的核心目标：**接近正式环境，但保留诊断能力**

```json
{
  "physics": { "gravity": -9.81, "debug_draw": false },
  "gameplay": {
    "enemy_speed": 2.5,
    "player_invincible": false,
    "skip_tutorial": false
  },
  "debug": {
    "show_fps": true,
    "log_level": "warn"
  }
}
```

### 6.3 正式环境 (production)

正式环境的核心目标：**最佳体验，无调试痕迹**

```json
{
  "physics": { "gravity": -9.81, "debug_draw": false },
  "gameplay": {
    "enemy_speed": 3.0,
    "player_invincible": false,
    "skip_tutorial": false
  },
  "debug": {
    "show_fps": false,
    "log_level": "error"
  }
}
```

---

## 7. 与 GET vars.yml 的对比

| 维度 | GET vars.yml | G.E.T. env-config.json |
|------|-------------|----------------------|
| 格式 | YAML | JSON |
| 环境切换 | 不同文件 | 同一文件内不同段落 |
| 变量引用 | Jinja2 模板 | 点号路径 + Lua 代码 |
| 覆盖机制 | Ansible 变量优先级 | 6 级覆盖优先级 |
| 加密敏感值 | Ansible Vault | 不适用（游戏不涉及） |
| 运行时修改 | 不支持 | 支持（Lua 直接修改） |
| 平台适配 | Multi-cloud provider | platform_overrides |

---

## 8. 最佳实践

### 8.1 配置命名规范

```
✅ 推荐：语义化、层级化命名
  gameplay.enemy_speed
  physics.gravity
  rendering.shadow_quality

❌ 避免：扁平化、含糊命名
  speed
  g
  quality
```

### 8.2 默认值策略

- **common 层**：放置所有环境共享的值
- **production 环境**：作为"标准"配置
- **dev 环境**：在 production 基础上放宽限制
- **难度预设**：只覆盖与难度相关的值

### 8.3 配置文件组织

```
scripts/
└── data/
    ├── env-config.json          # 环境配置
    ├── levels/
    │   ├── level1.json          # 关卡蓝图
    │   ├── level2.json
    │   └── level-series.json    # 批量生成配置
    └── save/                    # 运行时状态（自动生成）
        └── state.json
```

### 8.4 调试技巧

```lua
-- 打印当前生效的所有配置
function DebugPrintConfig(config)
    print("=== Current Environment: " .. config.currentEnv .. " ===")
    print("Gravity: " .. tostring(config:Get("physics.gravity")))
    print("Enemy Speed: " .. tostring(config:Get("gameplay.enemy_speed")))
    print("Debug Mode: " .. tostring(config:IsDebug()))
end
```

---

*最后更新: 2026-05-15*
