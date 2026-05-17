# GitLab Environment Toolkit → Game Environment Toolkit 概念映射

> 本文档详细说明 GitLab Environment Toolkit (GET) 的核心概念如何映射到 UrhoX 游戏关卡构建系统。

---

## 1. 映射总览

| # | GET 概念 | G.E.T. 游戏概念 | 映射理由 |
|---|---------|-----------------|---------|
| 1 | Terraform (基础设施供应) | Scene Provisioner (场景供应器) | 都负责"从无到有"创建底层基础设施/场景结构 |
| 2 | Ansible (配置管理) | Gameplay Configurator (玩法配置器) | 都在基础设施就绪后配置运行时行为 |
| 3 | Reference Architecture (参考架构) | Scene Blueprint (场景蓝图) | 都是预定义的、经过验证的架构模板 |
| 4 | vars.yml (环境变量) | env-config.json (环境配置) | 都用于区分不同运行环境的参数 |
| 5 | Dynamic Inventory (动态清单) | Entity Registry (实体注册表) | 都维护当前环境中所有资源/实体的索引 |
| 6 | Multi-cloud (多云平台) | Multi-platform (多平台适配) | 都抽象底层差异，提供统一接口 |
| 7 | Geo multi-site | Multi-level batch (多关卡批量生成) | 都处理多个独立环境的创建与差异化 |
| 8 | Terraform State | State Persistence (状态持久化) | 都维护环境当前状态的快照，支持恢复 |
| 9 | Terraform Module | Blueprint Section (蓝图段落) | 都是可组合的声明式配置单元 |
| 10 | Ansible Playbook | Configure Pipeline (配置流水线) | 都按顺序执行一系列配置步骤 |
| 11 | Terraform Plan | Dry Run (预演模式) | 都在执行前预览将要发生的变更 |
| 12 | Health Check | Validation (验证) | 都在部署/构建后验证结果正确性 |

---

## 2. 核心概念详解

### 2.1 Terraform → Scene Provisioner

**GET 中的 Terraform**:
- 声明式定义基础设施（VM、网络、存储、负载均衡）
- 通过 `.tf` 文件描述期望状态
- 执行 `terraform apply` 创建资源
- 维护 `terraform.tfstate` 跟踪资源状态

**G.E.T. 中的 Scene Provisioner**:
- 声明式定义场景基础结构（地形、天空、灯光、物理、相机）
- 通过 JSON 蓝图描述期望场景
- 执行 `SceneProvisioner.Apply()` 创建场景节点
- 通过 Entity Registry 跟踪所有已创建的实体

**映射关键点**:

| Terraform 概念 | Scene Provisioner 对应 |
|---------------|----------------------|
| `resource "google_compute_instance"` | `terrain: { type: "heightmap" }` |
| `resource "google_compute_network"` | `zones: [{ name: "spawn_area" }]` |
| `variable "machine_type"` | `env_overrides: { terrain.scale: 2.0 }` |
| `terraform.tfstate` | `EntityRegistry:Serialize()` |
| `terraform plan` | 蓝图验证 + 日志预览 |
| `terraform destroy` | `scene_:Clear()` |

### 2.2 Ansible → Gameplay Configurator

**GET 中的 Ansible**:
- 在 Terraform 创建的 VM 上安装和配置 GitLab 组件
- 通过 Playbook 定义配置步骤序列
- 使用角色（Role）封装可复用的配置逻辑
- 支持变量覆盖和条件执行

**G.E.T. 中的 Gameplay Configurator**:
- 在 Provisioner 创建的场景节点上配置玩法逻辑
- 按顺序执行：敌人波次 → 收集物 → 触发器 → NPC → 计分
- 每个配置步骤封装为独立函数
- 支持环境变量覆盖配置参数

**映射关键点**:

| Ansible 概念 | Gameplay Configurator 对应 |
|-------------|--------------------------|
| Playbook | Configure() 主流程 |
| Role | ConfigureWaves / ConfigureCollectibles 等 |
| Task | 单个 CreateChild + 组件创建 |
| Handler | 事件回调注册 |
| Variable | env-config 参数 |
| Template | 蓝图中的默认值 + 覆盖 |

### 2.3 Reference Architecture → Scene Blueprint

**GET 中的 Reference Architecture**:
- GitLab 官方验证的部署方案（1k/2k/3k/5k/10k/25k/50k 用户）
- 每种方案定义节点数量、角色分配、资源配额
- 用户选择匹配需求的方案，然后定制

**G.E.T. 中的 Scene Blueprint**:
- 6 种预定义场景架构模板
- 每种模板定义场景结构、实体配置、玩法规则
- 开发者选择匹配游戏类型的模板，然后定制

**架构对应关系**:

| GET Reference Architecture | G.E.T. Scene Blueprint | 场景特征 |
|---------------------------|----------------------|---------|
| 1k (单节点) | arena (竞技场) | 封闭空间，集中战斗 |
| 3k (小规模 HA) | linear (线性关卡) | 有序推进，阶段分明 |
| 5k (中规模) | hub_spoke (中枢辐射) | 中心安全区 + 周围区域 |
| 10k (大规模) | open_world (开放世界) | 自由探索，区域划分 |
| 25k (超大规模 HA) | procedural (程序生成) | 种子驱动，无限变化 |
| 50k (Geo 多站) | multiplayer_arena (多人竞技) | 网络同步，多实例 |

### 2.4 Environment Variables → env-config.json

**GET 中的变量系统**:
```yaml
# GET 的 vars.yml
cloud_provider: "gcp"
machine_type: "n1-standard-4"
gitlab_version: "16.0"
external_url: "https://gitlab.example.com"
```

**G.E.T. 中的环境配置**:
```json
{
  "format": "env-config-v1",
  "environments": {
    "dev": {
      "physics": { "gravity": -5.0 },
      "gameplay": { "enemy_speed": 1.0 }
    },
    "production": {
      "physics": { "gravity": -9.81 },
      "gameplay": { "enemy_speed": 3.0 }
    }
  }
}
```

**变量覆盖优先级（与 GET 一致）**:
1. 蓝图默认值（最低优先级）
2. env-config.json 环境配置
3. env_overrides 运行时覆盖（最高优先级）

### 2.5 Dynamic Inventory → Entity Registry

**GET 中的 Dynamic Inventory**:
- Terraform 输出自动生成 Ansible 清单
- 按角色分组（web、db、redis、gitaly）
- 运行时查询特定角色的主机列表

**G.E.T. 中的 Entity Registry**:
- Provisioner/Configurator 自动注册创建的实体
- 按标签分组（enemy、collectible、trigger、npc）
- 运行时查询特定标签的实体列表

```lua
-- 类似 Ansible 的 groups['web'] 查询
local enemies = EntityRegistry:GetByTag("enemy")
local bosses = EntityRegistry:GetByAllTags({"enemy", "boss"})
local inZone = EntityRegistry:GetInZone("spawn_area")
```

---

## 3. 两阶段工作流对比

### GET 工作流

```
Phase 1: Terraform
  terraform init → terraform plan → terraform apply
  输出: 基础设施 + 状态文件 + 动态清单

Phase 2: Ansible
  ansible-playbook → configure → verify
  输出: 运行中的 GitLab 实例
```

### G.E.T. 工作流

```
Phase 1: Scene Provisioner
  LoadBlueprint → Validate → Apply
  输出: 场景节点 + Entity Registry

Phase 2: Gameplay Configurator
  Configure → RegisterEntities → InitGameState
  输出: 可玩的游戏关卡
```

**工作流映射要点**:
- 两者都严格分离"创建"和"配置"阶段
- 两者的第二阶段都依赖第一阶段的输出
- 两者都支持独立重新执行某个阶段
- 两者都维护状态以支持增量更新

---

## 4. 设计原则映射

| GET 设计原则 | G.E.T. 游戏化表达 | 实际意义 |
|-------------|------------------|---------|
| Infrastructure as Code | Level as Data | 关卡用 JSON 声明，不硬编码 |
| Immutable Infrastructure | Stateless Provision | 每次重建场景从零开始，保证一致性 |
| Separation of Concerns | Provision vs Configure | 场景结构和玩法逻辑分离 |
| Environment Parity | Config-driven Difficulty | 同一蓝图通过不同配置生成不同难度 |
| Idempotent Operations | Safe Re-apply | 重复执行配置不产生副作用 |

---

## 5. 适用场景

### 最佳适用场景
- 需要大量关卡且共享基础结构的游戏
- 需要在不同难度/平台间复用关卡设计的项目
- 团队协作中需要标准化关卡构建流程的情况
- 需要支持运行时关卡切换和状态保存的游戏

### 不太适合的场景
- 单关卡的简单小游戏（直接编码更快）
- 完全程序化生成的世界（不需要蓝图模板）
- 关卡之间没有任何共同结构的游戏

---

*最后更新: 2026-05-15*
