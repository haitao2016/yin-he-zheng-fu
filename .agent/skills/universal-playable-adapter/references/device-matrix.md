# 设备分辨率矩阵与测试要点

> `universal-playable-adapter` Skill 的补充参考文档
> 包含常见设备分辨率数据和适配测试检查清单

---

## 1. 常见设备分辨率参考

### 手机（竖屏物理分辨率）

| 设备类型 | 典型分辨率 | DPR | 逻辑分辨率 | 宽高比 |
|---------|-----------|-----|-----------|--------|
| iPhone SE / 8 | 750×1334 | 2.0 | 375×667 | 16:9 |
| iPhone 12/13/14 | 1170×2532 | 3.0 | 390×844 | ~19.5:9 |
| iPhone 14 Pro Max | 1290×2796 | 3.0 | 430×932 | ~19.5:9 |
| iPhone 15 Pro | 1179×2556 | 3.0 | 393×852 | ~19.5:9 |
| Pixel 7 | 1080×2400 | 2.625 | 411×914 | 20:9 |
| Samsung S23 | 1080×2340 | 2.625 | 411×891 | ~19.5:9 |
| Redmi Note 12 | 1080×2400 | 2.75 | 393×873 | 20:9 |
| 低端 Android | 720×1280 | 2.0 | 360×640 | 16:9 |

### 手机（横屏 —— 横屏游戏实际使用）

| 设备类型 | 横屏物理 | 横屏逻辑 | 宽高比 |
|---------|---------|---------|--------|
| iPhone SE / 8 | 1334×750 | 667×375 | 16:9 |
| iPhone 12-15 系列 | 2532×1170 | 844×390 | ~19.5:9 |
| 标准 Android | 2400×1080 | 873×393 | 20:9 |
| 低端 Android | 1280×720 | 640×360 | 16:9 |

### 平板

| 设备类型 | 物理分辨率 | DPR | 逻辑分辨率 | 宽高比 |
|---------|-----------|-----|-----------|--------|
| iPad 10.2" | 2160×1620 | 2.0 | 1080×810 | 4:3 |
| iPad Air 10.9" | 2360×1640 | 2.0 | 1180×820 | ~4:3 |
| iPad Pro 11" | 2388×1668 | 2.0 | 1194×834 | ~4:3 |
| iPad Pro 12.9" | 2732×2048 | 2.0 | 1366×1024 | 4:3 |
| Android 平板 10" | 1920×1200 | 1.5 | 1280×800 | 16:10 |
| Android 平板低端 | 1280×800 | 1.0 | 1280×800 | 16:10 |

### 桌面 / Web

| 设备类型 | 物理分辨率 | DPR | 逻辑分辨率 | 宽高比 |
|---------|-----------|-----|-----------|--------|
| 1080p 显示器 | 1920×1080 | 1.0 | 1920×1080 | 16:9 |
| 1440p 显示器 | 2560×1440 | 1.0 | 2560×1440 | 16:9 |
| 4K 显示器 | 3840×2160 | 2.0 | 1920×1080 | 16:9 |
| MacBook Air 13" | 2560×1600 | 2.0 | 1280×800 | 16:10 |
| MacBook Pro 14" | 3024×1964 | 2.0 | 1512×982 | ~3:2 |
| 浏览器窗口（典型） | ~1366×768 | 1.0 | 1366×768 | 16:9 |
| 浏览器窗口（小） | ~1024×600 | 1.0 | 1024×600 | ~16:9 |

---

## 2. 设备类型判断阈值

基于**逻辑分辨率短边**（`min(logicalWidth, logicalHeight)`）判断：

```
短边 < 500   → phone   （375-430 典型）
500 ≤ 短边 < 900 → tablet  （800-834 典型）
短边 ≥ 900   → desktop （1080 典型）
```

### 计算示例

```lua
local physW, physH = graphics:GetWidth(), graphics:GetHeight()
local dpr = graphics:GetDPR()
local logW, logH = physW / dpr, physH / dpr
local shortSide = math.min(logW, logH)

-- iPhone 14: physW=2532, physH=1170(横屏), dpr=3
-- logW=844, logH=390, shortSide=390 → phone ✓

-- iPad Air: physW=2360, physH=1640(横屏), dpr=2
-- logW=1180, logH=820, shortSide=820 → tablet ✓

-- 1080p 显示器: physW=1920, physH=1080, dpr=1
-- logW=1920, logH=1080, shortSide=1080 → desktop ✓

-- 4K 显示器: physW=3840, physH=2160, dpr=2
-- logW=1920, logH=1080, shortSide=1080 → desktop ✓
```

---

## 3. 安全区域参考

### 有刘海/挖孔的设备

| 设备 | 顶部安全区 | 底部安全区 | 左右安全区 |
|------|-----------|-----------|-----------|
| iPhone X-15（竖屏） | 44pt | 34pt (Home Indicator) | 0 |
| iPhone X-15（横屏） | 0 | 21pt | 44pt 左右 |
| iPhone 14 Pro（竖屏） | 59pt (灵动岛) | 34pt | 0 |
| Android 挖孔屏（竖屏） | ~30dp | 0 | 0 |
| Android 挖孔屏（横屏） | 0 | 0 | ~30dp 一侧 |
| iPad | 20pt | 0 | 0 |
| 桌面浏览器 | 0 | 0 | 0 |

### 安全区获取方式

```lua
-- 引擎 API（返回物理像素值）
local rect = GetSafeAreaInsets(false)
-- rect.min.x = 左, rect.min.y = 上
-- rect.max.x = 右, rect.max.y = 下

-- 转换为逻辑像素
local dpr = graphics:GetDPR()
local safeTop    = rect.min.y / dpr
local safeBottom = rect.max.y / dpr
local safeLeft   = rect.min.x / dpr
local safeRight  = rect.max.x / dpr

-- 或使用 UI.SafeAreaView 自动处理
local root = UI.SafeAreaView({
    edges = "all",
    children = { ... }
})
```

---

## 4. UI.Scale 缩放行为参考

### UI.Scale.DEFAULT（DPR_DENSITY_ADAPTIVE）

算法：`scale = dpr * clamp(sqrt(shortSide / 720), 0.625, 1.0)`

| 设备 | DPR | shortSide | sqrt(s/720) | clamp | 最终 scale |
|------|-----|-----------|-------------|-------|-----------|
| iPhone SE (横屏) | 2.0 | 375 | 0.722 | 0.722 | 1.44 |
| iPhone 14 (横屏) | 3.0 | 390 | 0.736 | 0.736 | 2.21 |
| iPad Air (横屏) | 2.0 | 820 | 1.067 | 1.0 | 2.0 |
| 1080p 桌面 | 1.0 | 1080 | 1.225 | 1.0 | 1.0 |
| 4K 桌面 | 2.0 | 1080 | 1.225 | 1.0 | 2.0 |
| 低端 Android (横屏) | 2.0 | 360 | 0.707 | 0.707 | 1.41 |

**效果**：小屏手机上 UI 自动缩小以显示更多内容，大屏设备保持 1:1 物理像素。

---

## 5. 适配测试检查清单

### Phase 1: 基础可运行

- [ ] **手机横屏**：游戏正常运行，UI 不超出屏幕
- [ ] **手机竖屏**（如适用）：布局正确切换
- [ ] **平板横屏**：不拉伸变形，UI 比例合理
- [ ] **PC 浏览器 1920×1080**：正常运行
- [ ] **PC 浏览器窗口缩小到 1024×600**：仍可操作
- [ ] **刘海屏 iPhone**：关键 UI 不被刘海/Home Indicator 遮挡

### Phase 2: 输入完整

- [ ] **手机触摸**：所有操作都可通过触摸完成
- [ ] **PC 键鼠**：所有操作都可通过键鼠完成
- [ ] **手柄**（如适用）：基本移动和操作可用
- [ ] **触摸按钮尺寸**：不小于 44×44 逻辑像素
- [ ] **无悬停依赖**：触摸设备没有 hover 状态，不依赖 hover 提示

### Phase 3: 体验优化

- [ ] **Web Pointer Lock**：ESC 退出后可点击恢复
- [ ] **设备旋转**：横竖屏切换后 UI 重新布局
- [ ] **多点触控**：同时移动+按按钮不冲突
- [ ] **安全区**：刘海/圆角区域无重要 UI
- [ ] **文字可读**：最小字号在手机上 ≥ 12px 逻辑像素
- [ ] **性能**：低端设备帧率 ≥ 30fps

### Phase 4: 边界情况

- [ ] **超宽屏 21:9**：不出现 UI 错位
- [ ] **折叠屏**（如适用）：展开/折叠后正常
- [ ] **4K 高 DPI**：UI 不模糊也不过大
- [ ] **极小窗口 800×480**：核心功能仍可用
- [ ] **无鼠标笔记本触控板**：右键等操作有替代方案

---

## 6. 常见宽高比与游戏布局策略

| 宽高比 | 代表设备 | 横屏特点 | 布局建议 |
|-------|---------|---------|---------|
| 16:9 | 老 iPhone/Android, 1080p 桌面 | 标准宽屏 | 基准设计比例 |
| ~19.5:9 (≈20:9) | 现代手机 | 比 16:9 更宽 | 左右留出安全区/操控区 |
| 4:3 | iPad | 接近正方形 | 上下有更多空间 |
| 16:10 | MacBook, Android 平板 | 略高于 16:9 | 与 16:9 布局兼容 |
| 21:9 | 超宽显示器 | 极宽 | 居中主游戏区，两侧留白或 UI |

### 自适应策略

```lua
local physW, physH = graphics:GetWidth(), graphics:GetHeight()
local aspect = physW / physH

if aspect >= 2.0 then
    -- 超宽屏（20:9+）：缩小游戏视野或两侧放 UI
    gameAreaPadding = { left = 60, right = 60 }
elseif aspect >= 1.6 then
    -- 标准宽屏（16:9~16:10）：基准布局
    gameAreaPadding = { left = 0, right = 0 }
elseif aspect >= 1.2 then
    -- 接近 4:3：上下有更多空间
    gameAreaPadding = { left = 0, right = 0, top = 20, bottom = 20 }
else
    -- 竖屏：完全不同的布局
    usePortraitLayout = true
end
```

---

## 7. 性能分级参考

### 设备性能等级判断（启发式）

```lua
local function getPerformanceTier()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local totalPixels = physW * physH

    if totalPixels <= 921600 then       -- ≤ 720p (1280×720)
        return "low"
    elseif totalPixels <= 2073600 then  -- ≤ 1080p (1920×1080)
        return "medium"
    else
        return "high"                    -- > 1080p
    end
end
```

### 按性能等级调整

| 设置项 | Low | Medium | High |
|-------|-----|--------|------|
| 阴影 | 关闭 | 简单 | 高质量 |
| 粒子数量 | ×0.3 | ×0.6 | ×1.0 |
| 后处理 | 关闭 | 基础 | 全部 |
| 视距 | 50m | 100m | 200m |
| LOD 偏移 | 2.0 | 1.0 | 0.5 |

```lua
local tier = getPerformanceTier()

-- 阴影
if tier == "low" then
    renderer.drawShadows = false
elseif tier == "medium" then
    renderer.shadowMapSize = 1024
else
    renderer.shadowMapSize = 2048
end

-- 粒子倍率
local particleMultiplier = ({ low = 0.3, medium = 0.6, high = 1.0 })[tier]
```

