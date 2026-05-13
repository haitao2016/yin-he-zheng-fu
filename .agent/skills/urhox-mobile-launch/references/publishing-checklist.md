# TapTap 发布检查清单（移动端专项）

## 目录

1. [必要素材要求](#必要素材要求)
2. [技术准入门槛](#技术准入门槛)
3. [移动端专项检查](#移动端专项检查)
4. [QR 测试工作流](#QR-测试工作流)
5. [常见驳回原因](#常见驳回原因)
6. [发布前终检清单](#发布前终检清单)
7. [发布命令参考](#发布命令参考)

---

## 必要素材要求

| 素材 | 规格 | 注意事项 |
|------|------|---------|
| **游戏图标** | 512×512 PNG | 无透明，不含文字，视觉清晰 |
| **截图（≥3张）** | 1920×1080（横屏）或 1080×1920（竖屏）| **必须是真实游戏截图**，不得使用 AI 生成图或示意图 |
| **宣传图（Promo）** | 1920×1080 | 可含文字/Logo，允许 AI 生成 |
| **正方形宣传图** | 1:1 比例 | 竖屏游戏视频封面用 |

### 截图拍摄要求

```
✅ 合规截图：
- 截图必须来自游戏实际运行画面
- 使用预览窗口右上角"截图插入对话"功能获取
- 至少包含 1 张核心玩法画面
- 至少包含 1 张 UI/HUD 可见画面

❌ 驳回常见原因：
- 使用 AI 生成的插画替代截图
- 使用设计稿/线框图
- 截图与发布版本不符
- 截图方向与 screen_orientation 不一致
```

---

## 技术准入门槛

### 冷启动时间（≤5 秒）

在低端设备（1.5 GHz 双核 + 2 GB RAM）上验证：

```lua
-- 在 Start() 开头记录时间戳
local startTime = time:GetElapsedTime()

-- 当玩家可以交互时输出
print(string.format("[LAUNCH] FTUE ready in %.2fs", time:GetElapsedTime() - startTime))
```

目标：日志输出 ≤ 5.0s。超过时使用 `engine-docs/recipes/preload-and-build-refs.md` 中的 DWP 策略延迟加载非必要资源。

### 帧率稳定性

```lua
-- 发布前在目标设备上运行 2 分钟压力测试
-- 观察以下指标（通过 Profiler 或日志）：
-- - 平均帧时间 ≤ 16.7ms（60fps）或 ≤ 33ms（30fps）
-- - 连续帧时间抖动 < ±5ms
-- - 无帧率骤降至 < 15fps
```

### 崩溃率

- 冷启动 10 次无崩溃
- 后台切回无崩溃（验证 `ApplicationResumed` 处理）
- 横竖屏切换无崩溃（若支持）

---

## 移动端专项检查

### 触控输入验证

```lua
-- 检查所有可交互元素的点击区域
-- 最小触控目标：48×48 逻辑像素 / 9mm × 9mm 物理尺寸

-- 使用 TAP_OFFSET_Y 修正拇指遮挡：
local TAP_OFFSET_Y = -20  -- 像素，视觉中心上移修正

-- 验证方法：用手指（非鼠标）测试所有按钮
-- 容易漏测的区域：屏幕底部、左右边缘
```

### 竖/横屏适配

在 `.project/project.json` 中确认 `screen_orientation` 与游戏实际方向一致：

```json
{
  "taptap_publish": {
    "screen_orientation": "portrait"  // 或 "landscape"
  }
}
```

验证：旋转设备，UI 不应出现裁剪或溢出。

### 安全区域（刘海屏/挖孔屏）

```lua
-- 重要 UI 元素避开四角 safe area
-- 建议所有 HUD 元素距屏幕边缘至少 44px（逻辑像素）
-- 顶部状态栏区域：额外留 20-44px
```

### 内存限制

| 设备等级 | 可用内存上限 |
|---------|------------|
| 低端（2GB） | ≤ 128MB 纹理 + ≤ 256MB 总计 |
| 中端（4GB） | ≤ 256MB 纹理 + ≤ 512MB 总计 |

测试方法：运行 10 分钟后通过系统工具查看内存占用趋势（确认无持续增长）。

### 热量测试

```lua
-- 运行 10 分钟全程游戏（含战斗/粒子特效等高负载场景）
-- 设备背面温度应 < 43°C
-- 若温度持续升高，启用自适应质量降级：
-- 参见 references/performance.md → "热量与电池管理"
```

---

## QR 测试工作流

### 步骤一：构建项目

```
使用 UrhoX build 工具（SCE MCP 的 build tool）
不要手动运行 npm/webpack 等
```

### 步骤二：配置发布信息

确保 `.project/project.json` 包含完整的 `taptap_publish` 节：

```json
{
  "project_id": "<auto>",
  "taptap_publish": {
    "title": "游戏名称",
    "category": "casual",
    "screen_orientation": "portrait",
    "description": "游戏简介（可选）",
    "trial_note": "测试说明（可选）"
  },
  "assets": {
    "icon": "./game_material/icon.png",
    "screenshots": [
      "./game_material/screenshot1.png",
      "./game_material/screenshot2.png",
      "./game_material/screenshot3.png"
    ],
    "promotional_image": "./game_material/promo.png"
  }
}
```

### 步骤三：生成测试二维码

使用 `generate_test_qrcode` MCP 工具（前提：已完成 build）。

### 步骤四：设备扫码测试

- 在目标低端设备上扫码安装
- 观察启动时间、帧率、崩溃
- 测试所有触控热区
- 测试后台切换（接电话 → 回到游戏）

### 步骤五：邀请测试用户

```
使用 add_test_whitelist MCP 工具添加 TapTap 用户 ID
最少邀请 3 名不同设备用户验证
```

---

## 常见驳回原因

### 素材问题

| 驳回原因 | 解决方案 |
|---------|---------|
| 截图使用 AI 生成图片 | 用预览窗口截取真实游戏画面 |
| 截图方向与游戏不符 | 核对 `screen_orientation` 字段 |
| 图标含透明背景 | 重新生成，背景设为纯色 |
| 截图少于 3 张 | 补充至 ≥ 3 张 |
| 截图内容与发布版本差异过大 | 更新截图 |

### 技术问题

| 驳回原因 | 解决方案 |
|---------|---------|
| 冷启动超时（> 5s） | 使用 DWP 延迟加载非核心资源 |
| 低端设备崩溃 | 降低初始质量配置；检查内存泄漏 |
| 操作无响应 | 增大触控热区；检查事件订阅 |
| 后台切回后游戏卡死 | 实现 `ApplicationResumed` 正确恢复逻辑 |
| 帧率低于 20fps | 开启自适应质量；减少 Draw Call |

### 内容问题

| 驳回原因 | 解决方案 |
|---------|---------|
| 游戏分类错误 | 修正 `category` 字段（见下方分类表） |
| 描述与游戏内容不符 | 更新 `description` |
| 违规内容（血腥/暴力/版权） | 修改游戏内容 |

### TapTap 游戏分类对照

| category 值 | 对应类型 |
|------------|---------|
| `casual` | 休闲 |
| `action` | 动作 |
| `rpg` | RPG |
| `strategy` | 策略 |
| `puzzle` | 益智 |
| `simulation` | 模拟 |
| `arcade` | 街机 |
| `adventure` | 冒险 |
| `card` | 卡牌 |
| `sports` | 运动 |
| `racing` | 竞速 |
| `board` | 棋盘 |
| `educational` | 教育 |
| `music` | 音乐 |
| `word` | 文字 |
| `trivia` | 问答 |

---

## 发布前终检清单

### 素材 ✅

- [ ] 图标 512×512，无透明，无文字
- [ ] ≥ 3 张真实游戏截图（正确方向）
- [ ] 宣传图已上传
- [ ] 截图与当前版本游戏内容一致

### 技术 ✅

- [ ] 低端设备冷启动 ≤ 5s
- [ ] 低端设备稳定 30fps+（或 60fps+）
- [ ] 10 次冷启动无崩溃
- [ ] 后台切回无崩溃
- [ ] 所有触控按钮可正常响应
- [ ] 无内存持续增长（运行 10 分钟）
- [ ] 10 分钟压力测试无过热降速

### 配置 ✅

- [ ] `screen_orientation` 与游戏一致
- [ ] `category` 分类正确
- [ ] `title` 和 `description` 填写完整
- [ ] 项目已通过 build 工具构建

### 测试 ✅

- [ ] QR 码已生成并在真机验证
- [ ] ≥ 3 名测试用户验证通过
- [ ] 反馈日志（`get_debug_feedbacks`）无严重错误

---

## 发布命令参考

```
# 最终构建
→ 调用 build MCP 工具

# 生成测试二维码
→ 调用 generate_test_qrcode MCP 工具

# 添加测试白名单用户
→ 调用 add_test_whitelist MCP 工具，传入 user_id

# 正式发布到 TapTap（需用户明确确认）
→ 调用 publish_to_taptap MCP 工具

# 参加 GameJam（需用户明确要求）
→ 调用 bind_game_jam MCP 工具，传入 game_jam_event_name

# 查看用户反馈
→ 调用 get_debug_feedbacks MCP 工具
```

> ⚠️ `publish_to_taptap` 是高风险操作，只有用户在当前轮次**明确要求发布**时才调用。
