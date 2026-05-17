# G.E.T. 参考架构库

> 6 种预定义场景架构蓝图，对应不同游戏类型和规模需求。
> 灵感来源于 GitLab Environment Toolkit 的 Reference Architecture 体系。

---

## 1. 架构总览

| 编号 | 架构名称 | 适用游戏类型 | 场景规模 | 复杂度 |
|-----|---------|-------------|---------|-------|
| RA-1 | arena (竞技场) | 格斗、射击、塔防 | 小 | 低 |
| RA-2 | linear (线性关卡) | 平台跳跃、跑酷 | 中 | 低 |
| RA-3 | hub_spoke (中枢辐射) | RPG、冒险 | 中 | 中 |
| RA-4 | open_world (开放世界) | 沙盒、探索 | 大 | 高 |
| RA-5 | procedural (程序生成) | Roguelike、无尽模式 | 可变 | 高 |
| RA-6 | multiplayer_arena (多人竞技) | 多人对战、合作 | 中 | 高 |

---

## 2. RA-1: Arena (竞技场)

### 设计理念
封闭空间内的集中式战斗或挑战。所有行动发生在单一区域，边界清晰。

### 场景结构
```
┌─────────────────────────┐
│        天空盒/穹顶        │
│  ┌───────────────────┐  │
│  │                   │  │
│  │   战斗/挑战区域    │  │
│  │                   │  │
│  │   [玩家] [敌人]   │  │
│  │                   │  │
│  └───────────────────┘  │
│     围墙/边界/力场       │
└─────────────────────────┘
```

### 蓝图配置要点

```json
{
  "architecture": "arena",
  "scene": {
    "terrain": {
      "type": "flat",
      "size": [50, 50],
      "material": "Textures/stone_floor.png"
    },
    "skybox": { "material": "Materials/Skybox.xml" },
    "lighting": {
      "ambient": [0.4, 0.4, 0.5],
      "directional": {
        "direction": [-0.5, -1.0, -0.3],
        "color": [1.0, 0.95, 0.9]
      }
    },
    "zones": [
      {
        "name": "arena_center",
        "shape": "circle",
        "radius": 20,
        "position": [0, 0, 0]
      },
      {
        "name": "spawn_player",
        "shape": "box",
        "size": [5, 5],
        "position": [-15, 0, 0]
      },
      {
        "name": "spawn_enemy",
        "shape": "box",
        "size": [5, 5],
        "position": [15, 0, 0]
      }
    ],
    "boundaries": {
      "type": "wall",
      "shape": "circle",
      "radius": 25,
      "height": 5
    }
  },
  "gameplay": {
    "waves": [
      { "enemy_type": "basic", "count": 5, "delay": 0 },
      { "enemy_type": "basic", "count": 8, "delay": 30 },
      { "enemy_type": "elite", "count": 3, "delay": 60 }
    ]
  }
}
```

### 典型应用
- 波次生存挑战
- 1v1 / 多人对战
- Boss 战斗室
- 塔防（固定防御区域）

---

## 3. RA-2: Linear (线性关卡)

### 设计理念
沿一条主线有序推进，分阶段设置挑战。玩家沿固定路径前进。

### 场景结构
```
[起点] ──→ [区域A] ──→ [区域B] ──→ [区域C] ──→ [终点]
  │          │          │          │          │
 出生点     挑战1      挑战2      Boss      完成
           收集物      陷阱      奖励      结算
```

### 蓝图配置要点

```json
{
  "architecture": "linear",
  "scene": {
    "terrain": {
      "type": "segmented",
      "segments": [
        { "name": "start", "length": 20, "width": 10 },
        { "name": "challenge_1", "length": 40, "width": 15 },
        { "name": "challenge_2", "length": 40, "width": 12 },
        { "name": "boss_area", "length": 30, "width": 20 },
        { "name": "finish", "length": 10, "width": 10 }
      ]
    },
    "zones": [
      { "name": "checkpoint_1", "segment": "challenge_1", "offset": 0.8 },
      { "name": "checkpoint_2", "segment": "challenge_2", "offset": 0.8 }
    ]
  },
  "gameplay": {
    "collectibles": [
      { "type": "coin", "segment": "challenge_1", "count": 15 },
      { "type": "coin", "segment": "challenge_2", "count": 20 },
      { "type": "powerup", "segment": "boss_area", "count": 2 }
    ],
    "triggers": [
      { "segment": "boss_area", "offset": 0.1, "action": "spawn_boss" }
    ]
  }
}
```

### 典型应用
- 平台跳跃关卡
- 跑酷赛道
- 横版闯关
- 教学引导关

---

## 4. RA-3: Hub-Spoke (中枢辐射)

### 设计理念
一个安全的中心区域连接多个挑战区域。玩家从中枢出发探索各分支。

### 场景结构
```
         [区域 North]
              │
              │
[区域 West]──[中枢]──[区域 East]
              │
              │
         [区域 South]
```

### 蓝图配置要点

```json
{
  "architecture": "hub_spoke",
  "scene": {
    "hub": {
      "size": [30, 30],
      "features": ["shop", "save_point", "npc_quest_giver"]
    },
    "spokes": [
      {
        "name": "forest",
        "direction": "north",
        "difficulty": 1,
        "theme": "nature",
        "length": 60
      },
      {
        "name": "cave",
        "direction": "east",
        "difficulty": 2,
        "theme": "underground",
        "length": 50
      },
      {
        "name": "castle",
        "direction": "south",
        "difficulty": 3,
        "theme": "gothic",
        "length": 70
      },
      {
        "name": "volcano",
        "direction": "west",
        "difficulty": 4,
        "theme": "fire",
        "length": 55,
        "requires": ["forest", "cave"]
      }
    ],
    "corridors": {
      "width": 8,
      "type": "path"
    }
  },
  "gameplay": {
    "progression": "unlock_by_completion",
    "npcs": [
      { "zone": "hub", "type": "merchant", "position": [5, 0, 5] },
      { "zone": "hub", "type": "quest_giver", "position": [-5, 0, 3] }
    ]
  }
}
```

### 典型应用
- RPG 城镇 + 副本
- 冒险解谜游戏
- Metroidvania 风格
- 教学 + 自由探索混合

---

## 5. RA-4: Open World (开放世界)

### 设计理念
大面积自由探索空间，划分为多个功能区域，玩家可以按任意顺序访问。

### 场景结构
```
┌──────────────────────────────────┐
│  [山地]    [森林]    [雪原]      │
│                                  │
│  [湖泊]    [平原]    [沙漠]      │
│            (出生点)              │
│  [沼泽]    [丘陵]    [海岸]      │
└──────────────────────────────────┘
```

### 蓝图配置要点

```json
{
  "architecture": "open_world",
  "scene": {
    "terrain": {
      "type": "heightmap",
      "size": [500, 500],
      "heightmap": "Textures/world_height.png",
      "scale": [1.0, 50.0, 1.0]
    },
    "regions": [
      {
        "name": "plains",
        "center": [0, 0, 0],
        "radius": 80,
        "biome": "grassland"
      },
      {
        "name": "mountains",
        "center": [-150, 0, 150],
        "radius": 100,
        "biome": "alpine"
      },
      {
        "name": "forest",
        "center": [0, 0, 150],
        "radius": 90,
        "biome": "deciduous"
      }
    ],
    "points_of_interest": [
      { "name": "village", "position": [10, 0, -20], "type": "settlement" },
      { "name": "dungeon_entrance", "position": [-80, 0, 60], "type": "dungeon" },
      { "name": "ancient_ruins", "position": [120, 0, 100], "type": "landmark" }
    ]
  },
  "gameplay": {
    "day_night_cycle": true,
    "weather_system": true,
    "enemy_density_per_region": {
      "plains": 0.3,
      "mountains": 0.6,
      "forest": 0.5
    }
  }
}
```

### 典型应用
- 开放世界探索
- 生存建造
- 沙盒游戏
- 大型 RPG

---

## 6. RA-5: Procedural (程序生成)

### 设计理念
基于种子和规则动态生成关卡内容，每次体验不同。

### 场景结构
```
Seed: 42
  ↓
[生成规则] → [房间A] → [走廊] → [房间B] → [Boss房] → ...
              随机敌人    随机宝箱   随机布局   固定Boss
```

### 蓝图配置要点

```json
{
  "architecture": "procedural",
  "scene": {
    "generation": {
      "algorithm": "bsp_tree",
      "seed_source": "random",
      "room_count": { "min": 8, "max": 15 },
      "room_size": { "min": [10, 10], "max": [25, 25] },
      "corridor_width": 4
    },
    "room_templates": [
      { "type": "combat", "weight": 0.4 },
      { "type": "treasure", "weight": 0.2 },
      { "type": "puzzle", "weight": 0.15 },
      { "type": "rest", "weight": 0.1 },
      { "type": "shop", "weight": 0.1 },
      { "type": "boss", "weight": 0.05, "max_count": 1 }
    ],
    "difficulty_curve": "exponential",
    "floor_scaling": 1.2
  },
  "gameplay": {
    "permadeath": true,
    "meta_progression": {
      "unlock_items": true,
      "upgrade_start_stats": true
    }
  }
}
```

### 典型应用
- Roguelike / Roguelite
- 无尽跑酷
- 随机地牢
- 每日挑战模式

---

## 7. RA-6: Multiplayer Arena (多人竞技)

### 设计理念
支持多玩家同时参与的对称或非对称竞技场，需要网络同步。

### 场景结构
```
┌─────────────────────────┐
│  [队伍A出生] ← 对称 → [队伍B出生]  │
│       │                    │       │
│       ↓                    ↓       │
│  [A侧区域]   [中央]   [B侧区域]   │
│              争夺点               │
│  [A侧掩体]          [B侧掩体]    │
│                                   │
│        [资源点]   [资源点]         │
└─────────────────────────────────────┘
```

### 蓝图配置要点

```json
{
  "architecture": "multiplayer_arena",
  "scene": {
    "symmetry": "mirror_x",
    "terrain": {
      "type": "flat",
      "size": [80, 80]
    },
    "spawn_points": {
      "team_a": [
        [-30, 0, 0], [-32, 0, 3], [-32, 0, -3], [-28, 0, 5]
      ],
      "team_b": [
        [30, 0, 0], [32, 0, 3], [32, 0, -3], [28, 0, 5]
      ]
    },
    "objectives": [
      { "name": "center_control", "position": [0, 0, 0], "type": "control_point" },
      { "name": "resource_a", "position": [-15, 0, 15], "type": "resource" },
      { "name": "resource_b", "position": [15, 0, -15], "type": "resource" }
    ],
    "cover_objects": [
      { "position": [-10, 0, 5], "type": "wall_low" },
      { "position": [10, 0, 5], "type": "wall_low" },
      { "position": [0, 0, 12], "type": "pillar" }
    ]
  },
  "gameplay": {
    "mode": "team_deathmatch",
    "teams": 2,
    "players_per_team": 4,
    "respawn_time": 5,
    "match_duration": 300,
    "scoring": {
      "kill": 100,
      "objective_capture": 500
    }
  },
  "network": {
    "sync_rate": 20,
    "interpolation": true,
    "server_authoritative": true
  }
}
```

### 典型应用
- 团队对战射击
- MOBA 风格竞技
- 合作 PvE 挑战
- 竞速对决

---

## 8. 架构选择决策树

```
你的游戏需要多人联网吗？
├── 是 → multiplayer_arena (RA-6)
└── 否 → 游戏世界有多大？
    ├── 小（单个封闭区域）→ arena (RA-1)
    ├── 中 → 关卡是线性还是分支？
    │   ├── 线性 → linear (RA-2)
    │   └── 分支（有中心区域）→ hub_spoke (RA-3)
    ├── 大（开放探索）→ open_world (RA-4)
    └── 可变（每次不同）→ procedural (RA-5)
```

---

## 9. 架构组合建议

多数成熟游戏会组合使用多种架构：

| 组合 | 示例 |
|------|------|
| hub_spoke + arena | RPG 城镇 + Boss 战斗室 |
| open_world + linear | 开放世界 + 线性主线任务 |
| hub_spoke + procedural | 城镇中枢 + 随机地牢 |
| linear + arena | 关卡推进 + 最终竞技场 |
| multiplayer_arena + procedural | 每局随机生成的多人地图 |

实现方式：主蓝图选择一种基础架构，子区域使用另一种架构的蓝图段落。

---

*最后更新: 2026-05-15*
