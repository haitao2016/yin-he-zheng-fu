---
name: game-data-annotator
description: |
  游戏数据标注与可视化工具系统。在 UrhoX 引擎中实现完整的游戏开发数据标注工作流，
  覆盖四大标注能力：场景区域标注（2D/3D 碰撞区、AI 路径点、兴趣点）、
  资产分类标注（纹理/音频/关卡分类与标签管理）、
  游戏事件时间轴标注（回放事件流、性能标记、动画关键帧）、
  数据驱动配置导出（标注数据导出为 JSON 供游戏逻辑消费）。
  灵感源自 AI Data Annotation Portfolio（Label Studio/CVAT/LabelImg）的多模态标注理念，
  将其映射为引擎原生的交互式标注工具链。

  Use when users need to (1) 为游戏场景标注碰撞区域或兴趣点,
  (2) 分类管理游戏资产（纹理、音效、关卡难度等）,
  (3) 在时间轴上标注游戏事件或动画关键帧,
  (4) 将标注数据导出为 JSON 配置驱动游戏逻辑,
  (5) 创建可视化的区域编辑器或路径编辑器,
  (6) 为 AI NPC 标注导航路径点或巡逻区域,
  (7) 批量管理和查看游戏资源的元数据标签。

  MUST trigger when:
    - 用户明确说"标注"、"annotation"、"label"与游戏数据相关
    - 用户需要为场景区域添加交互式标记或编辑器
    - 用户需要管理大量游戏资产的分类和标签
    - 用户需要时间轴式的事件编辑工具

  trigger-keywords:
    - 标注
    - 数据标注
    - annotation
    - label
    - 区域标注
    - 碰撞区域编辑
    - 兴趣点
    - POI
    - 路径点
    - waypoint
    - 资产分类
    - 资源标签
    - asset classification
    - 时间轴标注
    - timeline annotation
    - 事件标记
    - 关键帧标注
    - 数据驱动
    - data-driven
    - 标签管理
    - tag management
    - 区域编辑器
    - region editor
    - 路径编辑器
    - path editor
version: 1.0.0
license: MIT
compatibility: UrhoX Lua (全平台)
metadata:
  category: tools
  priority: medium
  requires_mcp: false
  engine_components:
    - UI (urhox-libs/UI)
    - cjson
    - File
    - Input
    - Image (可选)
---

# Game Data Annotator — 游戏数据标注与可视化工具系统

## 设计理念

AI Data Annotation（数据标注）的核心理念是 **原始数据 + 标签 = 结构化训练数据**。
本 Skill 将这一理念映射到 UrhoX 游戏开发工作流：

| AI 数据标注概念 | 游戏开发映射 |
|---------------|-------------|
| 图像标注（BBox/Polygon） | 场景区域标注（碰撞区、触发区、兴趣点） |
| 文本分类（Sentiment/Label） | 资产分类标注（纹理类型、音效类别、关卡难度） |
| 音频/视频时间轴标注 | 游戏事件时间轴（回放标记、动画帧、性能分析点） |
| 标注数据导出（COCO JSON/JSONL） | 数据驱动配置导出（JSON → 游戏逻辑消费） |

**与其他 Skill 的区别**：

| 维度 | @Arning_map-editor（等距地图编辑器） | game-data-annotator |
|------|-------------------------------------|---------------------|
| 目的 | 菱形瓦片地图编辑（关卡设计） | 游戏数据的结构化标注与分类 |
| 输出 | 瓦片地图 JSON（地图布局） | 标注数据 JSON（元数据/标签/区域/时间轴） |
| 交互 | 瓦片放置/图层管理 | 区域绘制/标签管理/时间轴编辑 |
| 适用 | 等距/正交地图游戏 | 任何需要结构化数据管理的游戏 |

---

## 四大核心能力

### 能力一：场景区域标注（Region Annotation）

**对应原始概念**: 图像标注中的 Bounding Box / Polygon 标注

在 2D 或 3D 场景中交互式地标记区域，用于定义碰撞区、触发区、AI 导航路径点等。

#### 标注数据模型

```lua
-- 场景标注数据结构（灵感源自 COCO JSON bbox 格式）
-- 原始 COCO: {"bbox": [x, y, width, height], "category_id": 1}
-- 游戏映射: {"region": {x, y, w, h}, "type": "collision", "label": "safe_zone"}

---@class RegionAnnotation
---@field id number              -- 唯一标识
---@field region table           -- {x, y, w, h} 矩形区域（世界坐标/像素坐标）
---@field type string            -- 区域类型: "collision"|"trigger"|"spawn"|"waypoint"|"poi"
---@field label string           -- 标签名称（如 "safe_zone", "enemy_spawn_01"）
---@field tags string[]          -- 多标签数组
---@field color table            -- 可视化颜色 {r, g, b, a}
---@field metadata table         -- 扩展元数据（自定义键值对）
---@field created_at string      -- 创建时间戳
---@field updated_at string      -- 修改时间戳

-- 示例
local annotation = {
    id = 1,
    region = { x = 100, y = 200, w = 150, h = 80 },
    type = "trigger",
    label = "boss_arena",
    tags = { "combat", "boss", "indoor" },
    color = { r = 1.0, g = 0.2, b = 0.2, a = 0.4 },
    metadata = {
        difficulty = "hard",
        required_level = 10,
        boss_id = "dragon_01",
    },
    created_at = "2026-05-16T10:30:00",
    updated_at = "2026-05-16T10:30:00",
}
```

#### 3D 场景区域标注（扩展）

```lua
---@class Region3DAnnotation
---@field id number
---@field bounds table           -- {min = {x,y,z}, max = {x,y,z}} AABB 包围盒
---@field type string            -- "volume"|"waypoint"|"path"|"area"
---@field label string
---@field points table[]         -- 路径点列表 {{x,y,z}, {x,y,z}, ...}（type="path" 时使用）
---@field radius number          -- 影响半径（type="waypoint" 时使用）
---@field metadata table

local waypoint = {
    id = 1,
    bounds = { min = { x = 0, y = 0, z = 0 }, max = { x = 2, y = 3, z = 2 } },
    type = "waypoint",
    label = "patrol_point_01",
    points = {},
    radius = 1.5,
    metadata = {
        patrol_group = "guard_route_A",
        wait_time = 3.0,
        priority = 1,
    },
}
```

#### 场景标注管理器模板

```lua
-- ============================================================
-- SceneAnnotationManager.lua
-- 场景区域标注管理器
-- ============================================================
-- 来源: game-data-annotator Skill
-- 引擎依赖: cjson (全局内置), File API (engine-docs/recipes/file-storage.md)
-- UI 依赖: urhox-libs/UI (engine-docs/recipes/ui.md)
-- ============================================================

local SceneAnnotationManager = {}
SceneAnnotationManager.__index = SceneAnnotationManager

--- 创建标注管理器实例
---@param config table { savePath: string, autoSave: boolean }
---@return table
function SceneAnnotationManager.Create(config)
    local self = setmetatable({}, SceneAnnotationManager)
    self.annotations = {}          -- 所有标注 (id -> annotation)
    self.nextId = 1                -- 自增 ID
    self.selectedId = nil          -- 当前选中标注
    self.savePath = config.savePath or "annotations/scene.json"
    self.autoSave = config.autoSave ~= false
    self.dirty = false             -- 是否有未保存的修改
    self.categories = {}           -- 预定义类别
    self.undoStack = {}            -- 撤销栈
    self.redoStack = {}            -- 重做栈
    self.maxUndoSteps = 50
    return self
end

--- 添加标注
---@param annotation table RegionAnnotation 数据（不含 id）
---@return number id 生成的标注 ID
function SceneAnnotationManager:Add(annotation)
    local id = self.nextId
    self.nextId = self.nextId + 1

    annotation.id = id
    annotation.created_at = os.date("%Y-%m-%dT%H:%M:%S")
    annotation.updated_at = annotation.created_at
    annotation.tags = annotation.tags or {}
    annotation.metadata = annotation.metadata or {}

    -- 记录撤销操作
    self:_pushUndo({
        action = "add",
        id = id,
    })

    self.annotations[id] = annotation
    self.dirty = true

    if self.autoSave then
        self:Save()
    end

    return id
end

--- 更新标注
---@param id number
---@param updates table 要更新的字段
function SceneAnnotationManager:Update(id, updates)
    local annotation = self.annotations[id]
    if not annotation then
        log:Write(LOG_WARNING, "SceneAnnotationManager: annotation " .. id .. " not found")
        return
    end

    -- 记录撤销（保存旧值）
    local oldValues = {}
    for k, _ in pairs(updates) do
        oldValues[k] = annotation[k]
    end
    self:_pushUndo({
        action = "update",
        id = id,
        oldValues = oldValues,
    })

    -- 应用更新
    for k, v in pairs(updates) do
        annotation[k] = v
    end
    annotation.updated_at = os.date("%Y-%m-%dT%H:%M:%S")

    self.dirty = true
    if self.autoSave then
        self:Save()
    end
end

--- 删除标注
---@param id number
function SceneAnnotationManager:Remove(id)
    local annotation = self.annotations[id]
    if not annotation then return end

    self:_pushUndo({
        action = "remove",
        id = id,
        data = annotation,  -- 保存完整数据用于撤销
    })

    self.annotations[id] = nil
    if self.selectedId == id then
        self.selectedId = nil
    end

    self.dirty = true
    if self.autoSave then
        self:Save()
    end
end

--- 按标签查找标注
---@param tag string
---@return table[] 匹配的标注数组
function SceneAnnotationManager:FindByTag(tag)
    local results = {}
    for _, ann in pairs(self.annotations) do
        for _, t in ipairs(ann.tags) do
            if t == tag then
                results[#results + 1] = ann
                break
            end
        end
    end
    return results
end

--- 按类型查找标注
---@param annotationType string
---@return table[]
function SceneAnnotationManager:FindByType(annotationType)
    local results = {}
    for _, ann in pairs(self.annotations) do
        if ann.type == annotationType then
            results[#results + 1] = ann
        end
    end
    return results
end

--- 按区域范围查找（AABB 重叠检测）
---@param x number 查询矩形 x
---@param y number 查询矩形 y
---@param w number 查询矩形 width
---@param h number 查询矩形 height
---@return table[] 与查询区域重叠的标注
function SceneAnnotationManager:FindInRegion(x, y, w, h)
    local results = {}
    for _, ann in pairs(self.annotations) do
        local r = ann.region
        if r then
            -- AABB 重叠检测
            if r.x < x + w and r.x + r.w > x and
               r.y < y + h and r.y + r.h > y then
                results[#results + 1] = ann
            end
        end
    end
    return results
end

--- 获取所有标注（数组形式）
---@return table[]
function SceneAnnotationManager:GetAll()
    local results = {}
    for _, ann in pairs(self.annotations) do
        results[#results + 1] = ann
    end
    -- 按 id 排序保证稳定顺序
    table.sort(results, function(a, b) return a.id < b.id end)
    return results
end

--- 获取统计信息
---@return table { total, byType, byTag }
function SceneAnnotationManager:GetStats()
    local stats = { total = 0, byType = {}, byTag = {} }
    for _, ann in pairs(self.annotations) do
        stats.total = stats.total + 1
        stats.byType[ann.type] = (stats.byType[ann.type] or 0) + 1
        for _, tag in ipairs(ann.tags or {}) do
            stats.byTag[tag] = (stats.byTag[tag] or 0) + 1
        end
    end
    return stats
end

--- 保存到文件
--- 文件 API 来源: engine-docs/recipes/file-storage.md
function SceneAnnotationManager:Save()
    local data = {
        version = "1.0",
        annotation_type = "scene_region",
        next_id = self.nextId,
        categories = self.categories,
        annotations = self:GetAll(),
    }

    local jsonStr = cjson.encode(data)
    local file = File(self.savePath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
        self.dirty = false
        log:Write(LOG_INFO, "SceneAnnotationManager: saved " .. data.version
            .. ", " .. #data.annotations .. " annotations")
    else
        log:Write(LOG_ERROR, "SceneAnnotationManager: failed to save to " .. self.savePath)
    end
end

--- 从文件加载
function SceneAnnotationManager:Load()
    if not fileSystem:FileExists(self.savePath) then
        log:Write(LOG_INFO, "SceneAnnotationManager: no save file found, starting fresh")
        return
    end

    local file = File(self.savePath, FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "SceneAnnotationManager: failed to open " .. self.savePath)
        return
    end

    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then
        log:Write(LOG_ERROR, "SceneAnnotationManager: JSON parse error")
        return
    end

    -- 恢复标注数据
    self.annotations = {}
    self.nextId = data.next_id or 1
    self.categories = data.categories or {}

    for _, ann in ipairs(data.annotations or {}) do
        self.annotations[ann.id] = ann
        if ann.id >= self.nextId then
            self.nextId = ann.id + 1
        end
    end

    self.dirty = false
    self.undoStack = {}
    self.redoStack = {}
    log:Write(LOG_INFO, "SceneAnnotationManager: loaded " .. #(data.annotations or {}) .. " annotations")
end

--- 导出为游戏可消费的精简格式
---@param format string "regions"|"waypoints"|"config"
---@return string JSON 字符串
function SceneAnnotationManager:Export(format)
    local allAnns = self:GetAll()

    if format == "regions" then
        -- 导出区域列表（碰撞/触发检测用）
        local regions = {}
        for _, ann in ipairs(allAnns) do
            if ann.region then
                regions[#regions + 1] = {
                    id = ann.label or ("region_" .. ann.id),
                    type = ann.type,
                    x = ann.region.x,
                    y = ann.region.y,
                    w = ann.region.w,
                    h = ann.region.h,
                    metadata = ann.metadata,
                }
            end
        end
        return cjson.encode({ regions = regions })

    elseif format == "waypoints" then
        -- 导出路径点列表（AI 导航用）
        local waypoints = {}
        for _, ann in ipairs(allAnns) do
            if ann.type == "waypoint" then
                waypoints[#waypoints + 1] = {
                    id = ann.label,
                    position = ann.region and {
                        x = ann.region.x + (ann.region.w or 0) / 2,
                        y = ann.region.y + (ann.region.h or 0) / 2,
                    } or nil,
                    radius = ann.radius or 1.0,
                    metadata = ann.metadata,
                }
            end
        end
        return cjson.encode({ waypoints = waypoints })

    elseif format == "config" then
        -- 导出完整配置（数据驱动游戏逻辑用）
        local config = {}
        for _, ann in ipairs(allAnns) do
            config[ann.label or ("item_" .. ann.id)] = {
                type = ann.type,
                region = ann.region,
                tags = ann.tags,
                metadata = ann.metadata,
            }
        end
        return cjson.encode(config)
    end

    return cjson.encode(allAnns)
end

--- 撤销
function SceneAnnotationManager:Undo()
    if #self.undoStack == 0 then return end
    local op = table.remove(self.undoStack)

    if op.action == "add" then
        local ann = self.annotations[op.id]
        self.redoStack[#self.redoStack + 1] = { action = "redo_add", data = ann }
        self.annotations[op.id] = nil
    elseif op.action == "remove" then
        self.redoStack[#self.redoStack + 1] = { action = "redo_remove", id = op.id }
        self.annotations[op.id] = op.data
    elseif op.action == "update" then
        local ann = self.annotations[op.id]
        if ann then
            local currentValues = {}
            for k, _ in pairs(op.oldValues) do
                currentValues[k] = ann[k]
                ann[k] = op.oldValues[k]
            end
            self.redoStack[#self.redoStack + 1] = {
                action = "redo_update",
                id = op.id,
                oldValues = currentValues,
            }
        end
    end

    self.dirty = true
end

--- 重做
function SceneAnnotationManager:Redo()
    if #self.redoStack == 0 then return end
    local op = table.remove(self.redoStack)

    if op.action == "redo_add" then
        self.annotations[op.data.id] = op.data
        self.undoStack[#self.undoStack + 1] = { action = "add", id = op.data.id }
    elseif op.action == "redo_remove" then
        local ann = self.annotations[op.id]
        self.undoStack[#self.undoStack + 1] = { action = "remove", id = op.id, data = ann }
        self.annotations[op.id] = nil
    elseif op.action == "redo_update" then
        local ann = self.annotations[op.id]
        if ann then
            local currentValues = {}
            for k, _ in pairs(op.oldValues) do
                currentValues[k] = ann[k]
                ann[k] = op.oldValues[k]
            end
            self.undoStack[#self.undoStack + 1] = {
                action = "update",
                id = op.id,
                oldValues = currentValues,
            }
        end
    end

    self.dirty = true
end

--- 内部: 推入撤销栈
function SceneAnnotationManager:_pushUndo(op)
    self.undoStack[#self.undoStack + 1] = op
    if #self.undoStack > self.maxUndoSteps then
        table.remove(self.undoStack, 1)
    end
    -- 新操作清空重做栈
    self.redoStack = {}
end

return SceneAnnotationManager
```

---

### 能力二：资产分类标注（Asset Classification）

**对应原始概念**: 文本分类中的 Sentiment / Category 标注

对游戏资产进行结构化分类和标签管理，类似 NLP 中对文本数据的标签化处理。

#### 标注数据模型

```lua
-- 资产分类数据结构（灵感源自 JSONL 文本分类格式）
-- 原始格式: {"text": "Great product\!", "label": "positive", "confidence": 0.95}
-- 游戏映射: {"asset_path": "Textures/grass.png", "category": "ground", "tags": [...]}

---@class AssetAnnotation
---@field id number
---@field asset_path string      -- 资源路径
---@field asset_type string      -- "texture"|"sound"|"model"|"level"|"script"|"prefab"
---@field category string        -- 主分类
---@field subcategory string     -- 子分类（可选）
---@field tags string[]          -- 标签列表
---@field quality_rating number  -- 质量评分 1-5（可选）
---@field notes string           -- 备注
---@field metadata table         -- 扩展元数据

-- 示例：纹理分类
local textureAnnotation = {
    id = 1,
    asset_path = "Textures/stone_wall_01.png",
    asset_type = "texture",
    category = "environment",
    subcategory = "wall",
    tags = { "stone", "medieval", "tileable", "1024x1024" },
    quality_rating = 4,
    notes = "适合中世纪城堡场景，可无缝平铺",
    metadata = {
        resolution = "1024x1024",
        format = "png",
        has_normal_map = true,
        ppi = 72,
    },
}

-- 示例：关卡难度分类
local levelAnnotation = {
    id = 10,
    asset_path = "Levels/forest_01.json",
    asset_type = "level",
    category = "adventure",
    subcategory = "forest",
    tags = { "easy", "tutorial", "nature", "outdoor" },
    quality_rating = 5,
    notes = "新手教程关卡，敌人较少",
    metadata = {
        difficulty = "easy",
        estimated_time = 180,  -- 预计通关时间（秒）
        enemy_count = 5,
        has_boss = false,
    },
}
```

#### 资产分类管理器模板

```lua
-- ============================================================
-- AssetClassifier.lua
-- 资产分类标注管理器
-- ============================================================
-- 来源: game-data-annotator Skill
-- 引擎依赖: cjson (全局内置), File API (engine-docs/recipes/file-storage.md)
-- ============================================================

local AssetClassifier = {}
AssetClassifier.__index = AssetClassifier

--- 创建分类器实例
---@param config table
---@return table
function AssetClassifier.Create(config)
    local self = setmetatable({}, AssetClassifier)
    self.assets = {}                -- id -> AssetAnnotation
    self.nextId = 1
    self.savePath = config.savePath or "annotations/assets.json"
    self.autoSave = config.autoSave ~= false

    -- 预定义分类体系
    self.categoryTree = config.categoryTree or {
        texture = {
            name = "纹理",
            subcategories = { "ground", "wall", "sky", "character", "effect", "ui" },
        },
        sound = {
            name = "音频",
            subcategories = { "bgm", "sfx", "voice", "ambient" },
        },
        model = {
            name = "模型",
            subcategories = { "character", "prop", "environment", "vehicle", "weapon" },
        },
        level = {
            name = "关卡",
            subcategories = { "tutorial", "adventure", "boss", "arena", "puzzle" },
        },
    }

    -- 标签词库（快速选择）
    self.tagLibrary = config.tagLibrary or {
        "tileable", "animated", "particle", "outdoor", "indoor",
        "medieval", "scifi", "cartoon", "realistic",
        "easy", "medium", "hard", "boss",
        "looping", "one-shot", "stereo", "mono",
    }

    return self
end

--- 添加资产标注
---@param annotation table AssetAnnotation 数据（不含 id）
---@return number
function AssetClassifier:Add(annotation)
    local id = self.nextId
    self.nextId = self.nextId + 1

    annotation.id = id
    annotation.tags = annotation.tags or {}
    annotation.metadata = annotation.metadata or {}

    self.assets[id] = annotation

    if self.autoSave then self:Save() end
    return id
end

--- 按分类查找
---@param category string 主分类
---@param subcategory string|nil 子分类（可选）
---@return table[]
function AssetClassifier:FindByCategory(category, subcategory)
    local results = {}
    for _, asset in pairs(self.assets) do
        if asset.category == category then
            if not subcategory or asset.subcategory == subcategory then
                results[#results + 1] = asset
            end
        end
    end
    return results
end

--- 按标签查找（支持多标签 AND 查询）
---@param tags string[] 标签列表（必须全部匹配）
---@return table[]
function AssetClassifier:FindByTags(tags)
    local results = {}
    for _, asset in pairs(self.assets) do
        local allMatch = true
        for _, requiredTag in ipairs(tags) do
            local found = false
            for _, assetTag in ipairs(asset.tags) do
                if assetTag == requiredTag then
                    found = true
                    break
                end
            end
            if not found then
                allMatch = false
                break
            end
        end
        if allMatch then
            results[#results + 1] = asset
        end
    end
    return results
end

--- 按质量评分筛选
---@param minRating number 最低评分（1-5）
---@return table[]
function AssetClassifier:FindByRating(minRating)
    local results = {}
    for _, asset in pairs(self.assets) do
        if (asset.quality_rating or 0) >= minRating then
            results[#results + 1] = asset
        end
    end
    return results
end

--- 获取分类统计
---@return table
function AssetClassifier:GetStats()
    local stats = { total = 0, byCategory = {}, byType = {}, tagCloud = {} }
    for _, asset in pairs(self.assets) do
        stats.total = stats.total + 1
        stats.byCategory[asset.category] = (stats.byCategory[asset.category] or 0) + 1
        stats.byType[asset.asset_type] = (stats.byType[asset.asset_type] or 0) + 1
        for _, tag in ipairs(asset.tags) do
            stats.tagCloud[tag] = (stats.tagCloud[tag] or 0) + 1
        end
    end
    return stats
end

--- 保存 / 加载 (与 SceneAnnotationManager 相同模式)
function AssetClassifier:Save()
    local data = {
        version = "1.0",
        annotation_type = "asset_classification",
        next_id = self.nextId,
        category_tree = self.categoryTree,
        tag_library = self.tagLibrary,
        assets = {},
    }
    for _, asset in pairs(self.assets) do
        data.assets[#data.assets + 1] = asset
    end
    table.sort(data.assets, function(a, b) return a.id < b.id end)

    local jsonStr = cjson.encode(data)
    local file = File(self.savePath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
    end
end

function AssetClassifier:Load()
    if not fileSystem:FileExists(self.savePath) then return end
    local file = File(self.savePath, FILE_READ)
    if not file:IsOpen() then return end
    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then return end

    self.assets = {}
    self.nextId = data.next_id or 1
    self.categoryTree = data.category_tree or self.categoryTree
    self.tagLibrary = data.tag_library or self.tagLibrary
    for _, asset in ipairs(data.assets or {}) do
        self.assets[asset.id] = asset
    end
end

--- 导出为精简配置
---@return string JSON
function AssetClassifier:Export()
    local catalog = {}
    for _, asset in pairs(self.assets) do
        catalog[#catalog + 1] = {
            path = asset.asset_path,
            type = asset.asset_type,
            category = asset.category,
            subcategory = asset.subcategory,
            tags = asset.tags,
            rating = asset.quality_rating,
        }
    end
    table.sort(catalog, function(a, b) return a.path < b.path end)
    return cjson.encode({ asset_catalog = catalog })
end

return AssetClassifier
```

---

### 能力三：游戏事件时间轴标注（Timeline Annotation）

**对应原始概念**: 音频/视频标注中的时间戳标注

在时间轴上标注游戏事件，用于回放分析、动画关键帧标记、性能标记等。

#### 标注数据模型

```lua
-- 时间轴标注数据结构（灵感源自视频时间戳标注格式）
-- 原始格式: {"start_time": 0.0, "end_time": 2.5, "label": "walking", "type": "activity"}
-- 游戏映射: {"time": 12.5, "duration": 3.0, "event": "boss_phase_2", "track": "gameplay"}

---@class TimelineAnnotation
---@field id number
---@field time number            -- 事件开始时间（秒）
---@field duration number        -- 持续时间（秒），0 表示瞬时事件
---@field event string           -- 事件名称
---@field track string           -- 所属轨道（分组）
---@field label string           -- 显示标签
---@field color table            -- 可视化颜色
---@field tags string[]
---@field metadata table

-- 示例：游戏回放标注
local gameplayEvent = {
    id = 1,
    time = 45.2,
    duration = 8.5,
    event = "boss_fight_phase_2",
    track = "gameplay",
    label = "Boss 第二阶段",
    color = { r = 1.0, g = 0.0, b = 0.0, a = 0.8 },
    tags = { "combat", "boss", "critical" },
    metadata = {
        player_hp = 350,
        boss_hp_percent = 0.6,
        active_skills = { "shield", "heal" },
    },
}

-- 示例：动画关键帧标注
local animEvent = {
    id = 2,
    time = 0.5,
    duration = 0,  -- 瞬时
    event = "footstep_left",
    track = "animation",
    label = "左脚着地",
    tags = { "sound_trigger", "particle_trigger" },
    metadata = {
        sound_asset = "Sounds/footstep_stone.ogg",
        particle_asset = "Effects/dust_puff.xml",
    },
}

-- 示例：性能标记
local perfEvent = {
    id = 3,
    time = 120.0,
    duration = 5.3,
    event = "fps_drop",
    track = "performance",
    label = "帧率下降",
    tags = { "perf", "warning" },
    metadata = {
        avg_fps = 18,
        min_fps = 12,
        draw_calls = 450,
        triangle_count = 125000,
    },
}
```

#### 时间轴管理器模板

```lua
-- ============================================================
-- TimelineAnnotationManager.lua
-- 时间轴事件标注管理器
-- ============================================================
-- 来源: game-data-annotator Skill
-- 引擎依赖: cjson (全局内置), File API (engine-docs/recipes/file-storage.md)
-- ============================================================

local TimelineAnnotationManager = {}
TimelineAnnotationManager.__index = TimelineAnnotationManager

--- 创建时间轴管理器实例
---@param config table
---@return table
function TimelineAnnotationManager.Create(config)
    local self = setmetatable({}, TimelineAnnotationManager)
    self.events = {}              -- id -> TimelineAnnotation
    self.nextId = 1
    self.tracks = config.tracks or { "gameplay", "animation", "audio", "performance" }
    self.savePath = config.savePath or "annotations/timeline.json"
    self.totalDuration = config.totalDuration or 300  -- 总时长（秒），默认5分钟
    return self
end

--- 添加时间轴事件
---@param event table TimelineAnnotation 数据（不含 id）
---@return number
function TimelineAnnotationManager:Add(event)
    local id = self.nextId
    self.nextId = self.nextId + 1

    event.id = id
    event.duration = event.duration or 0
    event.tags = event.tags or {}
    event.metadata = event.metadata or {}
    event.color = event.color or { r = 0.4, g = 0.6, b = 1.0, a = 0.8 }

    -- 确保 track 存在
    if event.track then
        local found = false
        for _, t in ipairs(self.tracks) do
            if t == event.track then found = true; break end
        end
        if not found then
            self.tracks[#self.tracks + 1] = event.track
        end
    end

    self.events[id] = event
    return id
end

--- 按时间范围查找事件
---@param startTime number
---@param endTime number
---@param track string|nil 限定轨道（可选）
---@return table[]
function TimelineAnnotationManager:FindInRange(startTime, endTime, track)
    local results = {}
    for _, evt in pairs(self.events) do
        if (not track or evt.track == track) then
            local evtEnd = evt.time + (evt.duration or 0)
            -- 事件与查询范围有交集
            if evt.time < endTime and evtEnd > startTime then
                results[#results + 1] = evt
            end
        end
    end
    table.sort(results, function(a, b) return a.time < b.time end)
    return results
end

--- 按轨道获取所有事件
---@param track string
---@return table[]
function TimelineAnnotationManager:GetTrackEvents(track)
    local results = {}
    for _, evt in pairs(self.events) do
        if evt.track == track then
            results[#results + 1] = evt
        end
    end
    table.sort(results, function(a, b) return a.time < b.time end)
    return results
end

--- 获取所有事件（按时间排序）
---@return table[]
function TimelineAnnotationManager:GetAll()
    local results = {}
    for _, evt in pairs(self.events) do
        results[#results + 1] = evt
    end
    table.sort(results, function(a, b) return a.time < b.time end)
    return results
end

--- 删除事件
---@param id number
function TimelineAnnotationManager:Remove(id)
    self.events[id] = nil
end

--- 保存
function TimelineAnnotationManager:Save()
    local data = {
        version = "1.0",
        annotation_type = "timeline",
        total_duration = self.totalDuration,
        tracks = self.tracks,
        next_id = self.nextId,
        events = self:GetAll(),
    }

    local jsonStr = cjson.encode(data)
    local file = File(self.savePath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
    end
end

--- 加载
function TimelineAnnotationManager:Load()
    if not fileSystem:FileExists(self.savePath) then return end
    local file = File(self.savePath, FILE_READ)
    if not file:IsOpen() then return end
    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok then return end

    self.events = {}
    self.nextId = data.next_id or 1
    self.tracks = data.tracks or self.tracks
    self.totalDuration = data.total_duration or self.totalDuration
    for _, evt in ipairs(data.events or {}) do
        self.events[evt.id] = evt
    end
end

--- 导出为游戏可消费格式
---@return string JSON
function TimelineAnnotationManager:Export()
    local exported = { tracks = {} }
    for _, track in ipairs(self.tracks) do
        local trackEvents = self:GetTrackEvents(track)
        local events = {}
        for _, evt in ipairs(trackEvents) do
            events[#events + 1] = {
                time = evt.time,
                duration = evt.duration,
                event = evt.event,
                label = evt.label,
                metadata = evt.metadata,
            }
        end
        exported.tracks[track] = events
    end
    return cjson.encode(exported)
end

return TimelineAnnotationManager
```

---

### 能力四：数据驱动配置导出（Data-Driven Export）

**对应原始概念**: 标注数据集的导出格式（COCO JSON / JSONL / XML）

将标注数据导出为游戏逻辑可直接消费的 JSON 配置。

#### 导出格式规范

```lua
-- ============================================================
-- AnnotationExporter.lua
-- 标注数据统一导出器
-- ============================================================
-- 来源: game-data-annotator Skill
-- 引擎依赖: cjson (全局内置), File API
-- ============================================================

local AnnotationExporter = {}

--- 统一导出接口
---@param managers table { scene?: SceneAnnotationManager, assets?: AssetClassifier, timeline?: TimelineAnnotationManager }
---@param outputPath string 输出文件路径
---@param options table { format?: "full"|"compact", includeMetadata?: boolean }
function AnnotationExporter.ExportAll(managers, outputPath, options)
    options = options or {}
    local format = options.format or "full"
    local includeMetadata = options.includeMetadata ~= false

    local output = {
        version = "1.0",
        exported_at = os.date("%Y-%m-%dT%H:%M:%S"),
        format = format,
    }

    -- 导出场景标注
    if managers.scene then
        local allAnns = managers.scene:GetAll()
        output.scene_annotations = {}
        for _, ann in ipairs(allAnns) do
            local entry = {
                id = ann.label or ("region_" .. ann.id),
                type = ann.type,
                region = ann.region,
                tags = ann.tags,
            }
            if includeMetadata then
                entry.metadata = ann.metadata
            end
            output.scene_annotations[#output.scene_annotations + 1] = entry
        end
    end

    -- 导出资产分类
    if managers.assets then
        local stats = managers.assets:GetStats()
        output.asset_catalog = {
            total = stats.total,
            categories = stats.byCategory,
        }
        if format == "full" then
            output.asset_catalog.items = {}
            for _, asset in pairs(managers.assets.assets) do
                output.asset_catalog.items[#output.asset_catalog.items + 1] = {
                    path = asset.asset_path,
                    category = asset.category,
                    tags = asset.tags,
                }
            end
        end
    end

    -- 导出时间轴
    if managers.timeline then
        output.timeline = cjson.decode(managers.timeline:Export())
    end

    -- 写入文件
    local jsonStr = cjson.encode(output)
    local file = File(outputPath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "AnnotationExporter: exported to " .. outputPath)
    end
end

--- 导出为 Lua 表文件（可直接 require 使用）
---@param data table 要导出的数据
---@param outputPath string 输出路径（不含 .lua 后缀）
function AnnotationExporter.ExportAsLuaTable(data, outputPath)
    local lines = { "-- Auto-generated by game-data-annotator", "return " }
    lines[#lines + 1] = cjson.encode(data)

    -- 使用 cjson 生成 JSON 字符串，在 Lua 中可通过 cjson.decode 读取
    -- 或直接使用 JSON 文件配合 cjson.decode 加载
    local file = File(outputPath .. ".json", FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(data))
        file:Close()
    end
end

return AnnotationExporter
```

---

## UI 集成模板

以下模板展示如何使用 `urhox-libs/UI` 组件构建标注工具界面。

> UI 系统选择依据: CLAUDE.md 规则 #10（urhox-libs/UI 推荐，原生 UI 已废弃）
> 组件参考: engine-docs/recipes/ui.md、examples/14-ui-widgets-gallery.lua

### 场景标注编辑器 UI

```lua
-- ============================================================
-- AnnotationEditorUI.lua
-- 标注编辑器界面模板
-- ============================================================
-- 来源: game-data-annotator Skill
-- UI 依赖: urhox-libs/UI (engine-docs/recipes/ui.md)
-- 输入 API: engine-docs/api/input.md
-- ============================================================

local UI = require("urhox-libs/UI")

--- 创建标注工具栏
---@param manager table SceneAnnotationManager 实例
---@param callbacks table { onToolChange, onSave, onLoad, onExport }
---@return table UI 根节点
local function CreateToolbar(manager, callbacks)
    return UI.Panel {
        width = "100%", height = 48,
        flexDirection = "row",
        alignItems = "center",
        paddingLeft = 8, paddingRight = 8, gap = 8,
        backgroundColor = "#2B2D30",
        children = {
            -- 工具选择
            UI.Label { text = "工具:", fontSize = 14, color = "#CCCCCC" },
            UI.Dropdown {
                width = 120,
                items = { "选择", "矩形", "路径点", "删除" },
                selectedIndex = 1,
                onChange = function(self, index)
                    local tools = { "select", "rect", "waypoint", "delete" }
                    if callbacks.onToolChange then
                        callbacks.onToolChange(tools[index])
                    end
                end,
            },

            -- 类型选择
            UI.Label { text = "类型:", fontSize = 14, color = "#CCCCCC" },
            UI.Dropdown {
                width = 120,
                items = { "碰撞区", "触发区", "出生点", "路径点", "兴趣点" },
                selectedIndex = 1,
                onChange = function(self, index)
                    local types = { "collision", "trigger", "spawn", "waypoint", "poi" }
                    if callbacks.onTypeChange then
                        callbacks.onTypeChange(types[index])
                    end
                end,
            },

            -- 间隔
            UI.Panel { flexGrow = 1 },

            -- 操作按钮
            UI.Button {
                text = "撤销", variant = "outline", size = "sm",
                onClick = function(self) manager:Undo() end,
            },
            UI.Button {
                text = "重做", variant = "outline", size = "sm",
                onClick = function(self) manager:Redo() end,
            },
            UI.Button {
                text = "保存", variant = "primary", size = "sm",
                onClick = function(self)
                    manager:Save()
                    if callbacks.onSave then callbacks.onSave() end
                end,
            },
            UI.Button {
                text = "导出", variant = "outline", size = "sm",
                onClick = function(self)
                    if callbacks.onExport then callbacks.onExport() end
                end,
            },
        },
    }
end

--- 创建标注属性面板
---@param manager table SceneAnnotationManager 实例
---@param onUpdate function 更新回调
---@return table UI 面板, function 刷新函数
local function CreatePropertyPanel(manager, onUpdate)
    local labelRef = {}
    local tagRef = {}
    local notesRef = {}

    local panel = UI.Panel {
        width = 260, height = "100%",
        backgroundColor = "#1E1F22",
        padding = 12, gap = 8,
        children = {
            UI.Label {
                text = "属性面板",
                fontSize = 16, fontWeight = "bold", color = "#FFFFFF",
            },

            UI.Label { text = "标签名称", fontSize = 12, color = "#999999" },
            UI.TextField {
                ref = labelRef,
                placeholder = "输入标签名称...",
                width = "100%",
                onChange = function(self, text)
                    if manager.selectedId then
                        manager:Update(manager.selectedId, { label = text })
                    end
                end,
            },

            UI.Label { text = "标签 (逗号分隔)", fontSize = 12, color = "#999999" },
            UI.TextField {
                ref = tagRef,
                placeholder = "tag1, tag2, tag3",
                width = "100%",
                onChange = function(self, text)
                    if manager.selectedId then
                        local tags = {}
                        for tag in text:gmatch("[^,]+") do
                            local trimmed = tag:match("^%s*(.-)%s*$")
                            if trimmed and #trimmed > 0 then
                                tags[#tags + 1] = trimmed
                            end
                        end
                        manager:Update(manager.selectedId, { tags = tags })
                    end
                end,
            },

            UI.Label { text = "备注", fontSize = 12, color = "#999999" },
            UI.TextField {
                ref = notesRef,
                placeholder = "备注信息...",
                width = "100%",
                multiline = true,
                height = 80,
                onChange = function(self, text)
                    if manager.selectedId then
                        manager:Update(manager.selectedId, {
                            metadata = { notes = text },
                        })
                    end
                end,
            },

            -- 统计信息
            UI.Panel {
                width = "100%", marginTop = 16,
                padding = 8, borderRadius = 4,
                backgroundColor = "#2B2D30",
                children = {
                    UI.Label {
                        text = "统计",
                        fontSize = 14, fontWeight = "bold", color = "#CCCCCC",
                    },
                },
            },
        },
    }

    -- 刷新函数：当选中标注改变时调用
    local function refresh(annotation)
        if annotation then
            if labelRef.current then
                labelRef.current:SetText(annotation.label or "")
            end
            if tagRef.current then
                tagRef.current:SetText(table.concat(annotation.tags or {}, ", "))
            end
        end
    end

    return panel, refresh
end

--- 创建标注列表面板
---@param manager table SceneAnnotationManager 实例
---@param onSelect function 选中回调
---@return table UI 面板, function 刷新函数
local function CreateAnnotationList(manager, onSelect)
    local listContainer = { children = {} }

    local function refreshList()
        local annotations = manager:GetAll()
        local items = {}
        for _, ann in ipairs(annotations) do
            items[#items + 1] = UI.Panel {
                width = "100%", height = 36,
                flexDirection = "row", alignItems = "center",
                paddingLeft = 8, gap = 8,
                backgroundColor = (ann.id == manager.selectedId) and "#3574F0" or "transparent",
                borderRadius = 4,
                onClick = function(self)
                    manager.selectedId = ann.id
                    if onSelect then onSelect(ann) end
                end,
                children = {
                    UI.Panel {
                        width = 12, height = 12, borderRadius = 2,
                        backgroundColor = ann.color and
                            string.format("#%02X%02X%02X",
                                math.floor((ann.color.r or 0.5) * 255),
                                math.floor((ann.color.g or 0.5) * 255),
                                math.floor((ann.color.b or 0.5) * 255))
                            or "#808080",
                    },
                    UI.Label {
                        text = ann.label or ("标注 #" .. ann.id),
                        fontSize = 13, color = "#CCCCCC",
                        flexGrow = 1,
                    },
                    UI.Badge { text = ann.type, size = "sm" },
                },
            }
        end

        -- 返回列表 UI
        return items
    end

    local panel = UI.Panel {
        width = 240, height = "100%",
        backgroundColor = "#1E1F22",
        children = {
            UI.Panel {
                width = "100%", height = 36,
                flexDirection = "row", alignItems = "center",
                paddingLeft = 12,
                children = {
                    UI.Label {
                        text = "标注列表",
                        fontSize = 14, fontWeight = "bold", color = "#FFFFFF",
                    },
                },
            },
            UI.ScrollView {
                width = "100%", flexGrow = 1,
                padding = 4, gap = 2,
                children = refreshList(),
            },
        },
    }

    return panel, refreshList
end

return {
    CreateToolbar = CreateToolbar,
    CreatePropertyPanel = CreatePropertyPanel,
    CreateAnnotationList = CreateAnnotationList,
}
```

---

## 交互式绘制：鼠标拖拽创建矩形区域

> 输入 API 来源: engine-docs/api/input.md
> 枚举值来源: engine-docs/api/enums.md（规则 #12：使用枚举值而非数字）

```lua
-- ============================================================
-- 交互绘制逻辑模板
-- 将此代码集成到标注编辑器的 HandleUpdate 函数中
-- ============================================================

-- 绘制状态
local drawState = {
    isDrawing = false,
    startX = 0,
    startY = 0,
    currentX = 0,
    currentY = 0,
    currentTool = "select",     -- "select"|"rect"|"waypoint"|"delete"
    currentType = "collision",  -- 标注类型
}

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    -- 获取鼠标位置
    -- 来源: engine-docs/api/input.md → GetMousePosition
    local mousePos = input:GetMousePosition()
    local mx, my = mousePos.x, mousePos.y

    if drawState.currentTool == "rect" then
        -- 鼠标按下：开始绘制矩形
        -- 来源: engine-docs/api/enums.md → MOUSEB_LEFT
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            drawState.isDrawing = true
            drawState.startX = mx
            drawState.startY = my
        end

        -- 鼠标拖动：更新矩形大小
        if drawState.isDrawing then
            drawState.currentX = mx
            drawState.currentY = my
        end

        -- 鼠标释放：完成绘制
        if drawState.isDrawing and not input:GetMouseButtonDown(MOUSEB_LEFT) then
            drawState.isDrawing = false

            -- 计算矩形区域（确保正数 w/h）
            local x = math.min(drawState.startX, drawState.currentX)
            local y = math.min(drawState.startY, drawState.currentY)
            local w = math.abs(drawState.currentX - drawState.startX)
            local h = math.abs(drawState.currentY - drawState.startY)

            -- 最小尺寸过滤（避免误点击）
            if w > 5 and h > 5 then
                -- 添加标注（假设 annotationManager 已初始化）
                annotationManager:Add({
                    region = { x = x, y = y, w = w, h = h },
                    type = drawState.currentType,
                    label = drawState.currentType .. "_" .. os.time(),
                    color = { r = 0.2, g = 0.6, b = 1.0, a = 0.3 },
                })
            end
        end

    elseif drawState.currentTool == "waypoint" then
        -- 点击放置路径点
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            annotationManager:Add({
                region = { x = mx - 8, y = my - 8, w = 16, h = 16 },
                type = "waypoint",
                label = "wp_" .. os.time(),
                radius = 1.5,
                color = { r = 0.2, g = 1.0, b = 0.2, a = 0.6 },
            })
        end

    elseif drawState.currentTool == "select" then
        -- 点击选中标注
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local hits = annotationManager:FindInRegion(mx - 2, my - 2, 4, 4)
            if #hits > 0 then
                annotationManager.selectedId = hits[1].id
            else
                annotationManager.selectedId = nil
            end
        end

    elseif drawState.currentTool == "delete" then
        -- 点击删除标注
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            local hits = annotationManager:FindInRegion(mx - 2, my - 2, 4, 4)
            if #hits > 0 then
                annotationManager:Remove(hits[1].id)
            end
        end
    end

    -- 快捷键支持
    -- 来源: engine-docs/api/input.md、engine-docs/api/enums.md
    if input:GetKeyPress(KEY_DELETE) or input:GetKeyPress(KEY_BACKSPACE) then
        if annotationManager.selectedId then
            annotationManager:Remove(annotationManager.selectedId)
        end
    end

    -- Ctrl+Z 撤销 / Ctrl+Y 重做
    if input:GetQualifierDown(QUAL_CTRL) then
        if input:GetKeyPress(KEY_Z) then
            annotationManager:Undo()
        elseif input:GetKeyPress(KEY_Y) then
            annotationManager:Redo()
        elseif input:GetKeyPress(KEY_S) then
            annotationManager:Save()
        end
    end
end
```

---

## 完整集成示例

以下展示如何将所有组件整合为一个完整的标注工具。

```lua
-- ============================================================
-- main.lua (标注工具入口)
-- 完整集成示例：场景标注 + 资产分类 + 时间轴 + 导出
-- ============================================================
-- 来源: game-data-annotator Skill
-- 脚手架: 基于 templates/scaffold-2d.lua 模式
-- ============================================================

-- 引入模块
local SceneAnnotationManager = require("scripts.SceneAnnotationManager")
local AssetClassifier = require("scripts.AssetClassifier")
local TimelineAnnotationManager = require("scripts.TimelineAnnotationManager")
local AnnotationExporter = require("scripts.AnnotationExporter")

-- 全局管理器实例
local sceneManager
local assetManager
local timelineManager

function Start()
    -- 初始化场景标注管理器
    sceneManager = SceneAnnotationManager.Create({
        savePath = "annotations/scene.json",
        autoSave = true,
    })
    sceneManager:Load()

    -- 初始化资产分类器
    assetManager = AssetClassifier.Create({
        savePath = "annotations/assets.json",
        categoryTree = {
            texture = { name = "纹理", subcategories = { "ground", "wall", "character" } },
            sound = { name = "音频", subcategories = { "bgm", "sfx", "voice" } },
            level = { name = "关卡", subcategories = { "tutorial", "normal", "boss" } },
        },
    })
    assetManager:Load()

    -- 初始化时间轴管理器
    timelineManager = TimelineAnnotationManager.Create({
        savePath = "annotations/timeline.json",
        tracks = { "gameplay", "animation", "audio", "performance" },
        totalDuration = 600,  -- 10 分钟
    })
    timelineManager:Load()

    -- 设置更新事件
    SubscribeToEvent("Update", "HandleUpdate")

    log:Write(LOG_INFO, "Game Data Annotator initialized")
    log:Write(LOG_INFO, "Scene annotations: " .. #sceneManager:GetAll())
    log:Write(LOG_INFO, "Asset entries: " .. assetManager:GetStats().total)
    log:Write(LOG_INFO, "Timeline events: " .. #timelineManager:GetAll())
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    -- 交互绘制逻辑（参见"交互式绘制"章节）
    -- ...

    -- 快捷导出：Ctrl+E
    if input:GetQualifierDown(QUAL_CTRL) and input:GetKeyPress(KEY_E) then
        AnnotationExporter.ExportAll(
            {
                scene = sceneManager,
                assets = assetManager,
                timeline = timelineManager,
            },
            "annotations/export.json",
            { format = "full", includeMetadata = true }
        )
        log:Write(LOG_INFO, "All annotations exported to annotations/export.json")
    end
end

function Stop()
    -- 退出时保存所有数据
    if sceneManager then sceneManager:Save() end
    if assetManager then assetManager:Save() end
    if timelineManager then timelineManager:Save() end
    log:Write(LOG_INFO, "Game Data Annotator: all data saved on exit")
end
```

---

## 数据格式参考

### 导出 JSON 格式（完整示例）

```json
{
    "version": "1.0",
    "exported_at": "2026-05-16T10:30:00",
    "format": "full",
    "scene_annotations": [
        {
            "id": "safe_zone",
            "type": "trigger",
            "region": { "x": 100, "y": 200, "w": 150, "h": 80 },
            "tags": ["safe", "rest"],
            "metadata": { "heal_rate": 5.0 }
        },
        {
            "id": "patrol_point_01",
            "type": "waypoint",
            "region": { "x": 300, "y": 150, "w": 16, "h": 16 },
            "tags": ["guard", "patrol"],
            "metadata": { "patrol_group": "route_A", "wait_time": 3.0 }
        }
    ],
    "asset_catalog": {
        "total": 25,
        "categories": { "texture": 12, "sound": 8, "level": 5 },
        "items": [
            {
                "path": "Textures/stone_wall.png",
                "category": "texture",
                "tags": ["medieval", "tileable"]
            }
        ]
    },
    "timeline": {
        "tracks": {
            "gameplay": [
                {
                    "time": 45.2,
                    "duration": 8.5,
                    "event": "boss_phase_2",
                    "label": "Boss 第二阶段",
                    "metadata": { "boss_hp_percent": 0.6 }
                }
            ],
            "performance": [
                {
                    "time": 120.0,
                    "duration": 5.3,
                    "event": "fps_drop",
                    "label": "帧率下降",
                    "metadata": { "avg_fps": 18, "draw_calls": 450 }
                }
            ]
        }
    }
}
```

### 与原始 AI 标注格式的对应关系

| AI 标注格式 | 游戏标注格式 | 用途 |
|------------|------------|------|
| COCO JSON `{"bbox":[x,y,w,h]}` | `{"region":{x,y,w,h}}` | 场景区域定义 |
| JSONL `{"text":"...", "label":"pos"}` | `{"asset_path":"...", "category":"..."}` | 资产分类 |
| 时间戳 `{"start":0.0, "end":2.5}` | `{"time":0.0, "duration":2.5}` | 事件时间轴 |
| Label Studio 百分比坐标 | 相对坐标（可选） | 跨分辨率兼容 |

---

## 引擎 API 依赖速查

本 Skill 使用的所有引擎 API 来源：

| API | 用途 | 文档来源 |
|-----|------|---------|
| `cjson.encode()` / `cjson.decode()` | JSON 序列化/反序列化 | engine-docs/recipes/json.md |
| `File(path, FILE_WRITE)` | 文件写入 | engine-docs/recipes/file-storage.md |
| `File(path, FILE_READ)` | 文件读取 | engine-docs/recipes/file-storage.md |
| `file:WriteString()` / `file:ReadString()` | 字符串读写 | engine-docs/recipes/file-storage.md |
| `file:IsOpen()` / `file:Close()` | 文件状态管理 | engine-docs/recipes/file-storage.md |
| `fileSystem:FileExists()` | 文件存在检查 | engine-docs/recipes/file-storage.md |
| `fileSystem:CreateDir()` | 创建目录 | engine-docs/recipes/file-storage.md |
| `input:GetMousePosition()` | 鼠标位置获取 | engine-docs/api/input.md |
| `input:GetMouseButtonPress()` | 鼠标按钮按下检测 | engine-docs/api/input.md |
| `input:GetMouseButtonDown()` | 鼠标按钮持续按下检测 | engine-docs/api/input.md |
| `input:GetKeyPress()` | 键盘按键按下检测 | engine-docs/api/input.md |
| `input:GetQualifierDown()` | 修饰键检测 (Ctrl/Shift) | engine-docs/api/input.md |
| `MOUSEB_LEFT` | 鼠标左键枚举 | engine-docs/api/enums.md |
| `KEY_DELETE` / `KEY_Z` / `KEY_S` 等 | 键盘枚举 | engine-docs/api/enums.md |
| `QUAL_CTRL` | Ctrl 修饰键枚举 | engine-docs/api/enums.md |
| `UI.Panel` / `UI.Button` / 等 | UI 组件 | engine-docs/recipes/ui.md |
| `log:Write()` | 日志输出 | engine-docs/api/core.md |
| `os.date()` | 时间戳生成 | Lua 5.4 标准库 |
| `os.time()` | Unix 时间戳 | Lua 5.4 标准库 |

---

## 安全声明

- 所有文件操作使用引擎沙箱 File API，路径自动隔离（engine-docs/recipes/file-storage.md）
- 不使用 `eval`、`exec`、`subprocess` 等危险函数
- 不包含 base64 编码内容
- 不请求外部网络资源
- 所有数据仅存储在项目沙箱内
- 遵循最小权限原则：仅读写标注数据文件

---

## 适用场景

| 场景 | 使用的能力 | 示例 |
|------|-----------|------|
| 关卡设计辅助 | 场景区域标注 | 标记碰撞区、出生点、安全区 |
| AI NPC 路径规划 | 场景区域标注（路径点） | 标注巡逻路线、兴趣点 |
| 资源库管理 | 资产分类标注 | 分类纹理/音效/关卡，添加质量评分 |
| 游戏回放分析 | 时间轴标注 | 标记关键事件、战斗阶段、性能瓶颈 |
| 动画制作辅助 | 时间轴标注 | 标记脚步声触发点、粒子触发帧 |
| 数据驱动关卡 | 配置导出 | 导出 JSON 驱动关卡加载逻辑 |
| 测试覆盖标记 | 场景区域 + 资产分类 | 标记已测试/未测试的区域和资产 |

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0.0 | 2026-05-16 | 初始版本：四大核心能力完整实现 |
