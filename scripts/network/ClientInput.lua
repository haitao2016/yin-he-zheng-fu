-- ============================================================================
-- network/ClientInput.lua  -- 鼠标/键盘输入处理
-- 通过 Host 代理表读写 Client.lua 的 upvalue
-- ============================================================================
local ClientInput = {}

local GalaxyScene  = require("game.GalaxyScene")
local GameUI       = require("game.GameUI")
local BattleScene  = require("game.BattleScene")
local ClientMenus  = require("network.ClientMenus")
local DragManager  = require("game.ui.DragManager")
local ClientGalaxy = require("network.ClientGalaxy")
local Achievement  = require("game.AchievementSystem")

---@type table  -- Host 代理表，由 Client.lua 注入
local H

-- ============================================================================
-- Init: 接收 Host 代理表
-- ============================================================================
function ClientInput.Init(host)
    H = host
end

-- ============================================================================
-- handleMouseButtonDown
-- ============================================================================
function ClientInput.OnMouseButtonDown(eventType, eventData)
    if H.mainMenuActive then return end
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = H.getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / H.uiScale
    local my  = eventData["Y"]:GetInt() / dpr / H.uiScale

    -- P2-3: 统计面板打开时，点击任意位置关闭
    if H.statsOpen then
        local PW, PH = 620, 430
        local px = (H.screenW - PW) * 0.5
        local py = (H.screenH - PH) * 0.5
        local closeX = px + PW - 20
        local closeY = py + 18
        local insidePanel = mx >= px and mx <= px+PW and my >= py and my <= py+PH
        local onCloseBtn  = math.sqrt((mx-closeX)^2 + (my-closeY)^2) < 14
        if not insidePanel or onCloseBtn then
            H.statsOpen = false
        end
        return
    end

    -- P1-1: 难度选择屏幕 - 昵称输入框点击激活/失活
    if not H.difficultyChosen then
        local ni = ClientMenus.GetNicknameInputLayout(H.screenW, H.screenH)
        if mx >= ni.x and mx <= ni.x + ni.w and my >= ni.y and my <= ni.y + ni.h then
            H.nicknameInputActive = true
            input.textInputEnabled = true
            return
        else
            H.nicknameInputActive = false
            input.textInputEnabled = false
        end
    end

    -- P1-2: 难度选择屏幕 - 自定义滑块拖拽检测
    if not H.difficultyChosen and H.getCustomPanelVisible() then
        local sliders = H.getCustomSliderRects(H.screenW, H.screenH)
        for _, sl in ipairs(sliders) do
            local rawVal = H.customDiff[sl.name]
            local norm   = (rawVal - sl.vmin) / (sl.vmax - sl.vmin)
            norm = math.max(0, math.min(1, norm))
            local handleX = sl.x + norm * sl.w
            local handleY = sl.y + sl.h / 2
            if math.abs(my - handleY) <= 12 and mx >= sl.x - 10 and mx <= sl.x + sl.w + 10 then
                H.customDiffSlider.name = sl.name
                H.customDiffSlider.x0   = sl.x
                H.customDiffSlider.w    = sl.w
                local newNorm = math.max(0, math.min(1, (mx - sl.x) / sl.w))
                if sl.name == "maxThreat" then
                    H.customDiff.maxThreat = math.floor(sl.vmin + newNorm * (sl.vmax - sl.vmin) + 0.5)
                elseif sl.name == "initResBonus" then
                    local raw = sl.vmin + newNorm * (sl.vmax - sl.vmin)
                    H.customDiff.initResBonus = math.floor(raw / 50 + 0.5) * 50
                else
                    H.customDiff.attackFactor = sl.vmin + newNorm * (sl.vmax - sl.vmin)
                    H.customDiff.attackFactor = math.floor(H.customDiff.attackFactor * 10 + 0.5) / 10
                end
                return
            end
        end
        return
    end

    if not H.difficultyChosen then return end
    -- 面板拖拽（鼠标按下开始拖拽）
    if DragManager.OnTouchBegin(mx, my) then return end
    if H.currentScene == "galaxy" then GalaxyScene.OnMouseDown(mx, my) end
end

-- ============================================================================
-- handleMouseButtonUp
-- ============================================================================
function ClientInput.OnMouseButtonUp(eventType, eventData)
    local btn = eventData["Button"]:GetInt()
    if btn ~= MOUSEB_LEFT then return end
    local dpr = H.getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / H.uiScale
    local my  = eventData["Y"]:GetInt() / dpr / H.uiScale
    -- 面板拖拽结束
    if DragManager.OnTouchEnd() then return end
    -- 主菜单点击
    if H.mainMenuActive then
        -- P1-1: 传承树面板打开时
        if H.heritageOpen then
            local hit = ClientMenus.GetHeritagePanelHit(mx, my, H.screenW, H.screenH, {
                evolutionTree     = H.EVOLUTION_TREE,
                evolutionPoints   = H.evolutionPoints,
                evolutionUnlocked = H.evolutionUnlocked,
            })
            if hit == "close" then
                H.heritageOpen  = false
                H.heritageHover = nil
            elseif hit then
                -- 尝试解锁节点
                for _, node in ipairs(H.EVOLUTION_TREE) do
                    if node.id == hit and not H.evolutionUnlocked[hit] then
                        if H.evolutionPoints >= node.unlockCost then
                            local prereqOk = true
                            if node.tier > 1 then
                                for _, n2 in ipairs(H.EVOLUTION_TREE) do
                                    if n2.line == node.line and n2.tier == node.tier - 1 then
                                        prereqOk = H.evolutionUnlocked[n2.id] == true
                                        break
                                    end
                                end
                            end
                            if prereqOk then
                                H.evolutionPoints = H.evolutionPoints - node.unlockCost
                                H.evolutionUnlocked[hit] = true
                                print(string.format("[Heritage] 解锁 %s，剩余积分=%d",
                                    node.name, H.evolutionPoints))
                                GameUI.Notify(string.format(
                                    "✨ 传承解锁：%s — %s", node.name, node.desc), "success")
                                -- 写盘
                                pcall(function()
                                    local cFile = File("galaxy_career.json", FILE_WRITE)
                                    if cFile:IsOpen() then
                                        local sd = {}
                                        for k, v in pairs(H.careerStats) do sd[k] = v end
                                        sd.evolutionPoints = H.evolutionPoints
                                        local ul = {}
                                        for nid in pairs(H.evolutionUnlocked) do ul[#ul+1]=nid end
                                        sd.evolutionUnlocked = ul
                                        sd.redeemed = Achievement.GetRedeemed()
                                        cFile:WriteString(cjson.encode(sd))
                                        cFile:Close()
                                    end
                                end)
                                Achievement.Check("heritage_points", {
                                    evolutionPoints = H.evolutionPoints,
                                    unlockedCount   = H.getEvolutionUnlockedCount(),
                                })
                            end
                        end
                    end
                end
            end
            return
        end
        -- 普通主菜单点击
        local hit = H.getMainMenuHit(mx, my, H.screenW, H.screenH)
        print(string.format("[Mouse] mainMenu click: mx=%.1f my=%.1f hit=%s", mx, my, tostring(hit)))
        if hit == "heritage" then
            H.heritageOpen  = true
            H.heritageHover = nil
        elseif hit then
            H.onMainMenuSelect(hit)
        end
        return
    end
    -- 难度选择屏幕点击
    if not H.difficultyChosen then
        if H.customDiffSlider.name then
            H.customDiffSlider.name = nil
            return
        end
        local hit = H.getDifficultyHit(mx, my, H.screenW, H.screenH)
        if hit == "endless" then
            H.onEndlessModeSelect()
        elseif hit then
            H.onDifficultySelect(hit)
        end
        return
    end
    -- 战斗战败/胜利时优先让 BattleScene 处理（避免面板 hitArea 遮挡战败按钮）
    if H.currentScene == "battle" and BattleScene.GetState and BattleScene.GetState() == "lose" then
        BattleScene.OnClick(mx, my)
        return
    end
    if GameUI.OnClick(mx, my) then return end
    if H.currentScene == "battle" then
        BattleScene.OnClick(mx, my)
    else
        GalaxyScene.OnMouseUp(mx, my)
    end
end

-- ============================================================================
-- handleMouseMove
-- ============================================================================
function ClientInput.OnMouseMove(eventType, eventData)
    local dpr = H.getDpr()
    local mx  = eventData["X"]:GetInt() / dpr / H.uiScale
    local my  = eventData["Y"]:GetInt() / dpr / H.uiScale
    -- P2-3: 更新统计面板鼠标坐标
    H.statsMouse[1], H.statsMouse[2] = mx, my
    -- 主菜单悬停
    if H.mainMenuActive then
        if H.heritageOpen then
            H.heritageHover = ClientMenus.GetHeritagePanelHit(mx, my, H.screenW, H.screenH, {
                evolutionTree     = H.EVOLUTION_TREE,
                evolutionPoints   = H.evolutionPoints,
                evolutionUnlocked = H.evolutionUnlocked,
            })
        else
            H.mainMenuHover = H.getMainMenuHit(mx, my, H.screenW, H.screenH)
        end
        return
    end
    -- 难度选择屏幕悬停
    if not H.difficultyChosen then
        if H.customDiffSlider.name then
            local norm = math.max(0, math.min(1, (mx - H.customDiffSlider.x0) / H.customDiffSlider.w))
            local sliders = H.getCustomSliderRects(H.screenW, H.screenH)
            for _, sl in ipairs(sliders) do
                if sl.name == H.customDiffSlider.name then
                    if sl.name == "maxThreat" then
                        H.customDiff.maxThreat = math.floor(sl.vmin + norm * (sl.vmax - sl.vmin) + 0.5)
                    elseif sl.name == "initResBonus" then
                        local raw = sl.vmin + norm * (sl.vmax - sl.vmin)
                        H.customDiff.initResBonus = math.floor(raw / 50 + 0.5) * 50
                    else
                        local raw = sl.vmin + norm * (sl.vmax - sl.vmin)
                        H.customDiff.attackFactor = math.floor(raw * 10 + 0.5) / 10
                    end
                    break
                end
            end
            return
        end
        H.diffHoverBtn = H.getDifficultyHit(mx, my, H.screenW, H.screenH)
        return
    end
    -- 面板拖拽移动
    if DragManager.OnTouchMove(mx, my) then return end
    if H.currentScene == "galaxy" then GalaxyScene.OnMouseMove(mx, my) end
end

-- ============================================================================
-- handleMouseWheel
-- ============================================================================
function ClientInput.OnMouseWheel(eventType, eventData)
    if not H.difficultyChosen then return end
    if H.currentScene ~= "galaxy" then return end
    local dpr   = H.getDpr()
    local wheel = eventData["Wheel"]:GetInt()
    local pos   = input:GetMousePosition()
    local mx    = pos.x / dpr / H.uiScale
    local my    = pos.y / dpr / H.uiScale
    if GameUI.OnScroll(mx, my, wheel) then return end
    GalaxyScene.OnMouseWheel(mx, my, wheel)
end

-- ============================================================================
-- handleKeyDown
-- ============================================================================
function ClientInput.OnKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    -- P2-2a: 舰队命名模态
    if GameUI.IsFleetNaming() then
        if key == KEY_BACKSPACE then
            GameUI.OnFleetNamingBackspace()
        elseif key == KEY_RETURN then
            GameUI.OnFleetNamingEnter()
        elseif key == KEY_ESCAPE then
            GameUI.OnFleetNamingEnter()
        end
        return
    end
    -- P1-1: 昵称输入框激活时
    if H.nicknameInputActive then
        if key == KEY_BACKSPACE then
            local s = H.playerName
            if #s > 0 then
                local lastStart = 1
                local i = 1
                while i <= #s do
                    lastStart = i
                    local b = s:byte(i)
                    if b < 0x80 then i = i + 1
                    elseif b < 0xE0 then i = i + 2
                    elseif b < 0xF0 then i = i + 3
                    else i = i + 4 end
                end
                H.playerName = s:sub(1, lastStart - 1)
            end
            return
        elseif key == KEY_RETURN or key == KEY_ESCAPE then
            H.nicknameInputActive = false
            return
        end
        return
    end
    if not H.difficultyChosen then return end
    -- 飞船展开前转发给 GalaxyScene
    if H.currentScene == "galaxy" and not GalaxyScene.IsDeployed() then
        GalaxyScene.OnKeyDown(key)
        return
    end
    -- Tab 键
    if key == KEY_TAB then
        if H.currentScene == "galaxy" then
            H.fleetOverviewHeld = true
            GameUI.SetFleetOverview(true, H.fm)
        elseif H.currentScene == "battle" then
            H.statsOpen = not H.statsOpen
        end
        return
    end
    -- G 键打开生涯
    if key == KEY_G then
        if H.currentScene == "galaxy" and H.difficultyChosen and not H.mainMenuActive then
            GameUI.ShowCareerPage()
        end
        return
    end
    -- E 键打开帝国面板
    if key == KEY_E then
        if H.currentScene == "galaxy" and H.difficultyChosen and not H.mainMenuActive then
            GameUI.ToggleEmpirePanel()
        end
        return
    end
    -- 数字键 1-5 快速造舰
    if H.currentScene == "galaxy" and not H.mainMenuActive then
        local shipIdx = nil
        if     key == KEY_1 then shipIdx = 1
        elseif key == KEY_2 then shipIdx = 2
        elseif key == KEY_3 then shipIdx = 3
        elseif key == KEY_4 then shipIdx = 4
        elseif key == KEY_5 then shipIdx = 5
        end
        if shipIdx then
            local shipType = H.SHIP_QUEUE_ORDER[shipIdx]
            if shipType then ClientGalaxy.OnShipQueue(shipType) end
            return
        end
    end
    -- Escape
    if key == KEY_ESCAPE then
        if H.statsOpen then
            H.statsOpen = false
            return
        end
        if H.explorerColonizeMode then
            H.explorerColonizeMode = false
            GameUI.SetExplorerColonizeMode(false)
            GameUI.Notify("已取消探索模式", "info")
            return
        end
    end
end

-- ============================================================================
-- handleKeyUp
-- ============================================================================
function ClientInput.OnKeyUp(eventType, eventData)
    if not H.difficultyChosen then return end
    local key = eventData["Key"]:GetInt()
    if key == KEY_TAB and H.fleetOverviewHeld then
        H.fleetOverviewHeld = false
        GameUI.SetFleetOverview(false, nil)
        return
    end
    GalaxyScene.OnKeyUp(key)
end

return ClientInput
