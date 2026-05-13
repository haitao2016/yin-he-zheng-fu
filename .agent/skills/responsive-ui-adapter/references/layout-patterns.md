# 12 种响应式布局模式详解

> 覆盖 PC（1920×1080）、平板（1180×820）、手机（867×390）三大设备族的完整布局模式库。

---

## 模式总览

| # | 模式名称 | 适用场景 | 复杂度 |
|---|---------|---------|--------|
| 1 | 单列流式 | 信息流、设置页 | ★ |
| 2 | 侧栏+内容 | 后台管理、导航型 | ★★ |
| 3 | 顶栏+内容 | 轻量展示、游戏主页 | ★ |
| 4 | 自适应网格 | 卡片列表、物品栏 | ★★ |
| 5 | 等分多列 | 仪表盘、统计面板 | ★★ |
| 6 | 黄金比例分割 | 主次内容、编辑器 | ★★★ |
| 7 | 固定+弹性混合 | 聊天窗口、工具面板 | ★★ |
| 8 | 折叠面板 | 设置页、FAQ | ★★ |
| 9 | 标签页切换 | 多功能合一 | ★★ |
| 10 | 悬浮覆盖层 | 弹窗、提示、教程 | ★★ |
| 11 | HUD 四角锚定 | 游戏内 HUD | ★★★ |
| 12 | 安全区域适配 | 刘海屏/异形屏 | ★ |

---

## 模式 1：单列流式布局

**设备表现**：所有设备统一单列，仅调整 padding 和字号。

```lua
local function singleColumnLayout(info)
    return UI.ScrollView {
        width = "100%", height = "100%",
        scrollY = true, bounces = true,
        children = {
            UI.Panel {
                width = "100%",
                maxWidth = 800,       -- 大屏限宽
                alignSelf = "center", -- 居中
                padding = info.layout.padding,
                gap = info.layout.gap,
                children = {
                    UI.Label { text = "标题", fontSize = info.layout.titleSize },
                    UI.Label { text = "正文内容...", fontSize = info.layout.fontSize },
                    -- 更多内容...
                },
            },
        },
    }
end
```

**适配要点**：
- 手机：`padding = 8`，全宽
- 平板：`padding = 16`，`maxWidth = 800`
- 桌面：`padding = 24`，`maxWidth = 800`，内容居中

---

## 模式 2：侧栏+内容布局

**设备表现**：
- 桌面/平板 → 左侧栏 + 右内容
- 手机 → 侧栏隐藏，使用汉堡菜单

```lua
local function sidebarContentLayout(info)
    local menuOpen = false -- 手机菜单状态

    local sidebar = UI.Panel {
        width = info.layout.sidebarW,
        height = "100%",
        backgroundColor = {25, 25, 40, 255},
        padding = 12, gap = 6,
        children = {
            UI.Button { text = "首页", variant = "text", width = "100%" },
            UI.Button { text = "商店", variant = "text", width = "100%" },
            UI.Button { text = "排行", variant = "text", width = "100%" },
        },
    }

    local content = UI.ScrollView {
        flex = 1, flexBasis = 0,
        height = "100%",
        scrollY = true, bounces = true,
        children = {
            UI.Panel {
                width = "100%",
                padding = info.layout.padding,
                gap = info.layout.gap,
                children = {
                    -- ← 主内容
                },
            },
        },
    }

    if info.type == "phone" then
        -- 手机：顶栏 + 全宽内容（汉堡菜单控制侧栏）
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "column",
            children = {
                UI.Panel {
                    width = "100%", height = 48,
                    flexDirection = "row", alignItems = "center",
                    paddingHorizontal = 8,
                    backgroundColor = {30, 30, 45, 255},
                    children = {
                        UI.Button { text = "☰", variant = "text",
                            onClick = function()
                                -- 切换菜单显隐
                            end },
                        UI.Label { text = "标题", flex = 1,
                                   fontColor = {255,255,255,255} },
                    },
                },
                content,
            },
        }
    else
        -- 平板/桌面：侧栏 + 内容
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "row",
            children = { sidebar, content },
        }
    end
end
```

---

## 模式 3：顶栏+内容布局

```lua
local function topbarContentLayout(info)
    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 顶栏（固定高度）
            UI.Panel {
                width = "100%",
                height = info.type == "phone" and 48 or 56,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = info.layout.padding,
                backgroundColor = {20, 60, 120, 255},
                children = {
                    UI.Label { text = "游戏名", fontSize = info.layout.titleSize,
                               fontColor = {255,255,255,255} },
                    UI.Panel { flex = 1 },
                    -- 桌面/平板显示完整导航
                    info.type ~= "phone" and
                        UI.Panel {
                            flexDirection = "row", gap = 12,
                            children = {
                                UI.Button { text = "主页", variant = "text" },
                                UI.Button { text = "设置", variant = "text" },
                            },
                        } or nil,
                },
            },
            -- 内容（弹性填充）
            UI.ScrollView {
                flex = 1, flexBasis = 0,
                width = "100%",
                scrollY = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        padding = info.layout.padding,
                        gap = info.layout.gap,
                        children = { --[[ 内容 ]] },
                    },
                },
            },
        },
    }
end
```

---

## 模式 4：自适应网格布局

**设备表现**：列数随屏幕宽度自动调整。

```lua
local function adaptiveGridLayout(info, items)
    return UI.ScrollView {
        width = "100%", height = "100%",
        scrollY = true, bounces = true,
        children = {
            UI.Panel {
                width = "100%",
                padding = info.layout.padding,
                children = {
                    -- 方式 A：固定列数（按设备类型）
                    UI.SimpleGrid {
                        width = "100%",
                        columns = info.layout.columns,
                        gap = info.layout.gap,
                        children = items,
                    },

                    -- 方式 B：最小列宽自适应（推荐）
                    -- UI.SimpleGrid {
                    --     width = "100%",
                    --     minColumnWidth = 200,
                    --     gap = info.layout.gap,
                    --     children = items,
                    -- },
                },
            },
        },
    }
end

-- 创建网格卡片
local function createGridCard(title, desc, info)
    return UI.Card {
        padding = info.layout.padding,
        children = {
            UI.Label { text = title, fontSize = info.layout.fontSize + 2,
                       fontWeight = "bold" },
            UI.Label { text = desc, fontSize = info.layout.fontSize - 1,
                       fontColor = {180,180,180,255}, marginTop = 4 },
        },
    }
end
```

---

## 模式 5：等分多列布局

**设备表现**：
- 桌面 → 3-4 等分
- 平板 → 2 等分
- 手机 → 1 列堆叠

```lua
local function equalColumnsLayout(info, panels)
    local isPhone = info.type == "phone"

    return UI.Panel {
        width = "100%",
        flexDirection = isPhone and "column" or "row",
        gap = info.layout.gap,
        padding = info.layout.padding,
        children = (function()
            local result = {}
            for _, panel in ipairs(panels) do
                -- 非手机：每个面板弹性等分
                -- 手机：每个面板全宽
                panel.flex = isPhone and nil or 1
                panel.flexShrink = 1
                panel.width = isPhone and "100%" or nil
                table.insert(result, panel)
            end
            return result
        end)(),
    }
end
```

---

## 模式 6：黄金比例分割（主次内容）

**设备表现**：
- 桌面 → 左 2/3 + 右 1/3
- 平板 → 左 60% + 右 40%
- 手机 → 主内容在上，次内容折叠或隐藏

```lua
local function goldenRatioLayout(info, mainContent, sideContent)
    if info.type == "phone" then
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "column",
            children = {
                UI.Panel {
                    width = "100%", flex = 1, flexBasis = 0,
                    children = { mainContent },
                },
                -- 手机上次要内容收缩
                UI.Panel {
                    width = "100%", height = 120,
                    children = { sideContent },
                },
            },
        }
    else
        local mainFlex = info.type == "desktop" and 2 or 3
        local sideFlex = info.type == "desktop" and 1 or 2
        return UI.Panel {
            width = "100%", height = "100%",
            flexDirection = "row",
            gap = info.layout.gap,
            padding = info.layout.padding,
            children = {
                UI.Panel {
                    flex = mainFlex, flexShrink = 1, height = "100%",
                    children = { mainContent },
                },
                UI.Panel {
                    flex = sideFlex, flexShrink = 1, height = "100%",
                    children = { sideContent },
                },
            },
        }
    end
end
```

---

## 模式 7：固定+弹性混合布局

**典型用途**：聊天窗口（消息列表弹性 + 输入框固定）

```lua
local function fixedFlexLayout(info)
    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = {
            -- 弹性区域：消息列表
            UI.ScrollView {
                flex = 1, flexBasis = 0,
                width = "100%",
                scrollY = true, bounces = true,
                children = {
                    UI.Panel {
                        width = "100%",
                        padding = info.layout.padding,
                        gap = 4,
                        children = {
                            -- 消息气泡...
                        },
                    },
                },
            },
            -- 固定区域：输入框
            UI.Panel {
                width = "100%",
                height = info.type == "phone" and 48 or 56,
                flexDirection = "row",
                alignItems = "center",
                paddingHorizontal = info.layout.padding,
                gap = 8,
                backgroundColor = {40, 40, 55, 255},
                children = {
                    UI.TextInput {
                        flex = 1, flexShrink = 1,
                        placeholder = "输入消息...",
                    },
                    UI.Button { text = "发送", variant = "primary" },
                },
            },
        },
    }
end
```

---

## 模式 8：折叠面板布局

```lua
local function createCollapsibleSection(title, contentChildren, info)
    local expanded = true

    local headerPanel = UI.Panel {
        width = "100%", height = 44,
        flexDirection = "row",
        alignItems = "center",
        paddingHorizontal = info.layout.padding,
        backgroundColor = {40, 40, 55, 255},
        borderRadius = 6,
        children = {
            UI.Label { text = title, fontSize = info.layout.fontSize,
                       fontColor = {255,255,255,255}, flex = 1 },
            UI.Label { text = "▼", fontSize = 12,
                       fontColor = {150,150,150,255} },
        },
    }

    local bodyPanel = UI.Panel {
        width = "100%",
        padding = info.layout.padding,
        gap = info.layout.gap,
        children = contentChildren,
    }

    -- 点击切换展开/折叠
    headerPanel.onClick = function()
        expanded = not expanded
        bodyPanel:SetVisible(expanded)
    end

    return UI.Panel {
        width = "100%",
        gap = 2,
        children = { headerPanel, bodyPanel },
    }
end
```

---

## 模式 9：标签页切换布局

```lua
local function tabbedLayout(info, tabs)
    -- tabs = { { title = "主页", content = widget }, ... }
    local currentTab = 1

    local tabBar = UI.Panel {
        width = "100%",
        height = info.type == "phone" and 40 or 44,
        flexDirection = "row",
        backgroundColor = {30, 30, 45, 255},
    }

    local contentContainer = UI.Panel {
        flex = 1, flexBasis = 0,
        width = "100%",
    }

    -- 创建标签按钮
    for i, tab in ipairs(tabs) do
        tabBar:AddChild(UI.Button {
            text = tab.title,
            flex = 1,
            variant = i == currentTab and "primary" or "text",
            onClick = function()
                currentTab = i
                -- 切换内容面板显隐
                for j, t in ipairs(tabs) do
                    t.content:SetVisible(j == i)
                end
            end,
        })
    end

    -- 添加所有内容面板（初始仅显示第一个）
    for i, tab in ipairs(tabs) do
        tab.content:SetVisible(i == 1)
        contentContainer:AddChild(tab.content)
    end

    return UI.Panel {
        width = "100%", height = "100%",
        flexDirection = "column",
        children = { tabBar, contentContainer },
    }
end
```

---

## 模式 10：悬浮覆盖层（弹窗/对话框）

```lua
--- 创建自适应弹窗
local function createResponsiveModal(info, title, bodyChildren)
    -- 手机：全屏弹窗
    -- 平板/桌面：居中卡片弹窗
    local isPhone = info.type == "phone"

    local modalWidth = isPhone and "100%" or 480
    local modalHeight = isPhone and "100%" or "auto"
    local modalMaxH = isPhone and nil or 600
    local modalRadius = isPhone and 0 or 12

    return UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = {0, 0, 0, 128}, -- 半透明遮罩
        children = {
            UI.Card {
                width = modalWidth,
                height = modalHeight,
                maxHeight = modalMaxH,
                borderRadius = modalRadius,
                padding = info.layout.padding,
                gap = info.layout.gap,
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        alignItems = "center",
                        children = {
                            UI.Label { text = title,
                                       fontSize = info.layout.titleSize,
                                       flex = 1 },
                            UI.Button { text = "✕", variant = "text",
                                onClick = function()
                                    -- 关闭弹窗
                                end },
                        },
                    },
                    -- 内容（可滚动）
                    UI.ScrollView {
                        flex = 1, flexBasis = 0,
                        width = "100%",
                        scrollY = true,
                        children = {
                            UI.Panel {
                                width = "100%",
                                gap = info.layout.gap,
                                children = bodyChildren,
                            },
                        },
                    },
                    -- 底部按钮
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        justifyContent = "flex-end",
                        gap = 8,
                        children = {
                            UI.Button { text = "取消", variant = "outline" },
                            UI.Button { text = "确定", variant = "primary" },
                        },
                    },
                },
            },
        },
    }
end
```

---

## 模式 11：HUD 四角锚定布局

**游戏内 HUD 典型布局**：四角固定元素 + 中央信息。

```lua
local function createHUDLayout(info)
    local p = info.layout.padding

    return UI.Panel {
        width = "100%", height = "100%",
        children = {
            -- 左上：血量/等级
            UI.Panel {
                position = "absolute",
                left = p, top = p,
                flexDirection = "row", gap = 8, alignItems = "center",
                children = {
                    UI.Label { text = "HP: 100/100",
                               fontSize = info.layout.fontSize,
                               fontColor = {255, 80, 80, 255} },
                },
            },

            -- 右上：金币/道具
            UI.Panel {
                position = "absolute",
                right = p, top = p,
                flexDirection = "row", gap = 8, alignItems = "center",
                children = {
                    UI.Label { text = "💰 1234",
                               fontSize = info.layout.fontSize,
                               fontColor = {255, 215, 0, 255} },
                },
            },

            -- 左下：技能栏
            UI.Panel {
                position = "absolute",
                left = p, bottom = p,
                flexDirection = "row", gap = 6,
                children = {
                    createSkillButton("Q", info),
                    createSkillButton("W", info),
                    createSkillButton("E", info),
                    createSkillButton("R", info),
                },
            },

            -- 右下：小地图/菜单
            UI.Panel {
                position = "absolute",
                right = p, bottom = p,
                children = {
                    UI.Button { text = "≡", variant = "outline",
                                width = info.type == "phone" and 40 or 48,
                                height = info.type == "phone" and 40 or 48 },
                },
            },

            -- 顶部居中：提示/倒计时
            UI.Panel {
                position = "absolute",
                top = p,
                left = "50%",  -- 需手动居中
                children = {
                    UI.Label { text = "01:30",
                               fontSize = info.layout.titleSize,
                               fontColor = {255,255,255,255} },
                },
            },
        },
    }
end

local function createSkillButton(key, info)
    local size = info.type == "phone" and 40 or 52
    return UI.Button {
        text = key,
        width = size, height = size,
        variant = "outline",
    }
end
```

---

## 模式 12：安全区域适配

**使用 SafeAreaView 自动处理刘海屏/圆角/状态栏**：

```lua
local function safeAreaLayout(info)
    return UI.SafeAreaView {
        width = "100%", height = "100%",
        children = {
            -- 所有内容放在 SafeAreaView 内
            -- 自动避开刘海、状态栏、Home 指示器
            UI.Panel {
                width = "100%", height = "100%",
                padding = info.layout.padding,
                children = {
                    -- 正常布局...
                },
            },
        },
    }
end
```

**最佳实践**：SafeAreaView 作为最外层容器，内部嵌套其他布局模式。

---

## 模式组合速查表

| 游戏类型 | 推荐组合 |
|---------|---------|
| RPG 背包/商店 | 模式 4(网格) + 模式 10(弹窗) + 模式 12(安全区) |
| 聊天/社交 | 模式 7(固定弹性) + 模式 12(安全区) |
| 设置页面 | 模式 1(单列) + 模式 8(折叠) |
| 游戏大厅 | 模式 9(标签页) + 模式 4(网格) |
| 游戏内 HUD | 模式 11(四角锚定) + 模式 12(安全区) |
| 管理后台 | 模式 2(侧栏) + 模式 5(等分列) |

---

## 适配数值速查

### 触摸目标最小尺寸

| 设备 | 最小按钮 | 推荐按钮 | 最小间距 |
|------|---------|---------|---------|
| phone | 40px | 44px | 8px |
| tablet | 40px | 44px | 8px |
| desktop | 32px | 36px | 4px |

### 字号标准

| 角色 | phone | tablet | desktop |
|------|-------|--------|---------|
| 大标题 | 20 | 24 | 28 |
| 小标题 | 16 | 18 | 20 |
| 正文 | 13 | 14 | 16 |
| 辅助 | 10 | 11 | 12 |
| 标签 | 9 | 10 | 11 |

### 间距标准

| 级别 | phone | tablet | desktop |
|------|-------|--------|---------|
| xs | 2 | 4 | 4 |
| sm | 4 | 8 | 8 |
| md | 8 | 12 | 16 |
| lg | 12 | 16 | 24 |
| xl | 16 | 24 | 32 |

---

*本文档与 SKILL.md §5 布局策略配合使用。*
