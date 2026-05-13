--[[
    ReactiveUI 示例
    演示框架的核心功能: bind / computed / batch / bindList / watch / effect
]]

local UI = require "urhox-libs/UI"
local ReactiveUI = require "ReactiveUI"

local Example = {}

local store
local comboTimer = 0

-- ═══════════════════════════════════════════════════════════════
-- 辅助
-- ═══════════════════════════════════════════════════════════════

local function addMessage(msg)
    local msgs = store.messages
    msgs[#msgs + 1] = msg
    store.messages = msgs
end

-- ═══════════════════════════════════════════════════════════════
-- 初始化
-- ═══════════════════════════════════════════════════════════════

function Example.Init()
    -- 创建 Store
    store = ReactiveUI.new({
        score    = 0,
        hp       = 100,
        maxHp    = 100,
        combo    = 0,
        gold     = 500,
        messages = {},
        items    = {
            { id = 1, name = "Sword",  count = 1 },
            { id = 2, name = "Shield", count = 2 },
            { id = 3, name = "Potion", count = 5 },
        },
        shopItems = {
            { id = 101, name = "Ring",   cost = 100 },
            { id = 102, name = "Amulet", cost = 300 },
            { id = 103, name = "Crown",  cost = 800 },
        },
    })

    -- 派生值
    store:computed("hpPercent", { "hp", "maxHp" }, function(hp, maxHp)
        return math.floor(hp / maxHp * 100)
    end)

    store:computed("hpColor", { "hpPercent" }, function(pct)
        if pct < 30 then return { 220, 50, 50, 255 }
        elseif pct < 60 then return { 220, 160, 40, 255 }
        else return { 60, 180, 80, 255 } end
    end)

    -- 构建 UI & 绑定
    Example.CreateUI()
end

-- ═══════════════════════════════════════════════════════════════
-- UI（只构建一次，后续通过 bind 自动更新）
-- ═══════════════════════════════════════════════════════════════

function Example.CreateUI()
    -- ── HUD 控件 ──
    local scoreLabel = UI.Label {
        text = "0", fontSize = 28, fontColor = "#FFD700",
    }
    local comboLabel = UI.Label {
        text = "", fontSize = 20, fontColor = "#FF6347",
    }
    local goldLabel = UI.Label {
        text = "500", fontSize = 18, fontColor = "#FFD700",
    }
    local hpBar = UI.ProgressBar {
        value = 100, max = 100,
        width = 180, height = 16,
        transition = "value 0.3s easeOut",
    }
    local hpText = UI.Label {
        text = "100%", fontSize = 14,
    }

    -- ── 列表 & 日志容器 ──
    local itemListContainer = UI.Panel { width = "100%", gap = 4 }
    local shopContainer = UI.Panel { width = "100%", gap = 4 }
    local msgContainer = UI.Panel {
        width = "100%", gap = 2, maxHeight = 120, overflow = "scroll",
    }

    -- ── 按钮行 ──
    local buttonRow = UI.Row {
        gap = 8, flexWrap = "wrap",
        children = {
            UI.Button {
                text = "+100 Score", variant = "primary", fontSize = 13,
                onClick = function()
                    store:batch(function()
                        store.score = store.score + 100
                        store.combo = store.combo + 1
                    end)
                    comboTimer = 0
                    addMessage("Score +100, Combo " .. store.combo)
                end,
            },
            UI.Button {
                text = "-20 HP", variant = "danger", fontSize = 13,
                onClick = function()
                    store.hp = math.max(0, store.hp - 20)
                    addMessage("HP -20 → " .. store.hp)
                end,
            },
            UI.Button {
                text = "Heal +30", variant = "success", fontSize = 13,
                onClick = function()
                    store.hp = math.min(store.maxHp, store.hp + 30)
                    addMessage("Heal +30 → " .. store.hp)
                end,
            },
            UI.Button {
                text = "+200 Gold", fontSize = 13,
                onClick = function()
                    store.gold = store.gold + 200
                    addMessage("Gold +200 → " .. store.gold)
                end,
            },
            UI.Button {
                text = "Reset", fontSize = 13,
                onClick = function()
                    store:batch(function()
                        store.score = 0
                        store.combo = 0
                        store.hp    = 100
                        store.gold  = 500
                    end)
                    addMessage("Reset\!")
                end,
            },
        }
    }

    -- ── 根布局 ──
    local root = UI.Panel {
        width = "100%", height = "100%",
        padding = 16, gap = 12,
        backgroundColor = { 25, 25, 35, 255 },
        children = {
            UI.Label { text = "ReactiveUI Demo", fontSize = 22, fontColor = "#FFFFFF" },

            -- HUD
            UI.Row {
                width = "100%", justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Row {
                        gap = 8, alignItems = "center",
                        children = {
                            UI.Label { text = "Score:", fontSize = 16, fontColor = "#AAAAAA" },
                            scoreLabel,
                        }
                    },
                    UI.Row {
                        gap = 8, alignItems = "center",
                        children = {
                            UI.Label { text = "Gold:", fontSize = 16, fontColor = "#AAAAAA" },
                            goldLabel,
                        }
                    },
                    comboLabel,
                }
            },

            -- HP
            UI.Row {
                gap = 8, alignItems = "center",
                children = {
                    UI.Label { text = "HP:", fontSize = 14, fontColor = "#AAAAAA" },
                    hpBar,
                    hpText,
                }
            },

            UI.Divider {},
            buttonRow,
            UI.Divider {},

            UI.Label { text = "Inventory (bindList)", fontSize = 14, fontColor = "#888888" },
            itemListContainer,

            UI.Divider {},

            UI.Label { text = "Shop (effect + bindList remove)", fontSize = 14, fontColor = "#888888" },
            shopContainer,

            UI.Divider {},

            UI.Label { text = "Messages (watch)", fontSize = 14, fontColor = "#888888" },
            msgContainer,
        }
    }

    UI.SetRoot(root)

    -- ═══════════════════════════════════════════════════════════
    -- 绑定（只做一次）
    -- ═══════════════════════════════════════════════════════════

    store:bind(scoreLabel, "text", "score", function(v)
        return tostring(v)
    end)
    store:bind(goldLabel, "text", "gold", function(v)
        return tostring(v)
    end)

    store:bind(comboLabel, "text", "combo", function(v)
        return v > 0 and (v .. "x COMBO\!") or ""
    end)
    store:bind(comboLabel, "visible", "combo", function(v)
        return v > 0
    end)

    store:bind(hpBar, "value", "hp")
    store:bind(hpText, "text", "hpPercent", function(v) return v .. "%" end)
    store:bind(hpBar, "fillColor", "hpColor")

    -- ── 物品列表 (bindList 基本用法) ──
    store:bindList(itemListContainer, "items", {
        key = function(item) return item.id end,
        render = function(item)
            return UI.Row {
                width = "100%", padding = 6, gap = 8,
                backgroundColor = { 40, 40, 55, 255 }, borderRadius = 4,
                children = {
                    UI.Label {
                        id = "name", text = item.name,
                        fontSize = 14, fontColor = "#DDDDDD", flex = 1,
                    },
                    UI.Label {
                        id = "count", text = "x" .. item.count,
                        fontSize = 14, fontColor = "#AAAAAA",
                    },
                }
            }
        end,
        update = function(widget, item)
            local countLabel = widget:FindById("count")
            if countLabel then countLabel.text = "x" .. item.count end
        end,
    })

    -- ── 商店列表 (effect + bindList remove 联合用法) ──
    local effectDisposers = {}

    store:bindList(shopContainer, "shopItems", {
        key = function(item) return item.id end,

        render = function(item)
            local buyBtn = UI.Button {
                id = "buy", text = "Buy " .. item.cost .. "g",
                fontSize = 12, width = 90, height = 28,
                onClick = function()
                    if store.gold >= item.cost then
                        store.gold = store.gold - item.cost
                        store:listAppend("items", {
                            id = math.random(1000, 9999),
                            name = item.name,
                            count = 1,
                        })
                        addMessage("Bought " .. item.name .. " for " .. item.cost .. "g")
                    end
                end,
            }

            local row = UI.Row {
                width = "100%", padding = 6, gap = 8, alignItems = "center",
                backgroundColor = { 35, 40, 50, 255 }, borderRadius = 4,
                children = {
                    UI.Label { text = item.name, fontSize = 14, fontColor = "#DDDDDD", flex = 1 },
                    buyBtn,
                },
            }

            effectDisposers[row] = store:effect(function(s)
                local canAfford = s.gold >= item.cost
                buyBtn:SetDisabled(not canAfford)
                buyBtn:SetStyle({
                    variant = canAfford and "primary" or "secondary",
                })
                row:SetStyle({
                    borderColor = canAfford and { 100, 200, 80, 160 } or { 40, 45, 65, 80 },
                })
            end)

            return row
        end,

        remove = function(widget)
            local dispose = effectDisposers[widget]
            if dispose then
                dispose()
                effectDisposers[widget] = nil
            end
        end,
    })

    -- ── 消息日志 (watch 基本用法) ──
    store:watch("messages", function(newVal)
        msgContainer:ClearChildren()
        local start = math.max(1, #newVal - 9)
        for i = start, #newVal do
            msgContainer:AddChild(UI.Label {
                text = newVal[i], fontSize = 12, fontColor = "#999999",
            })
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- 每帧更新
-- ═══════════════════════════════════════════════════════════════

function Example.Update(dt)
    if store.combo > 0 then
        comboTimer = comboTimer + dt
        if comboTimer > 3.0 then
            store.combo = 0
            comboTimer = 0
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- 清理
-- ═══════════════════════════════════════════════════════════════

function Example.Shutdown()
    if store then
        store:unbindAll()
    end
end

return Example
