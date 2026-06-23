---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/FriendPanel.lua -- 好友面板
-- V2.8 P1-4 UI
-- ============================================================================

local FriendPanel = {}

local panel = nil

function FriendPanel.open()
    panel = {
        visible = true,
        tab = "FRIENDS",
        w = 450,
        h = 400,
    }
    return panel
end

function FriendPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

function FriendPanel.draw(vg)
    if not panel or not panel.visible then return end

    local BS = _G.BS
    local cx, cy = (BS and BS.screenW or 800) / 2, (BS and BS.screenH or 600) / 2
    local pw, ph = panel.w, panel.h
    local px, py = cx - pw / 2, cy - ph / 2

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, ph, 12)
    nvgFillColor(vg, nvgRGBA(15, 18, 30, 245))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 120, 200, 180))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 标题栏
    nvgBeginPath(vg)
    nvgRoundedRect(vg, px, py, pw, 45, 12)
    nvgRect(vg, px, py + 20, pw, 25)
    nvgFillColor(vg, nvgRGBA(25, 35, 55, 240))
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "好友")

    -- 关闭
    local closeBtn = { x = px + pw - 35, y = py + 12 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        FriendPanel.close()
    end)

    -- 标签
    local tabs = { 
        { id = "FRIENDS", name = "好友" }, 
        { id = "REQUESTS", name = "请求" }, 
        { id = "SEARCH", name = "搜索" },
        { id = "GIFTS", name = "礼物" },       -- V3.0 P1-1
        { id = "MATCHES", name = "友谊赛" },   -- V3.0 P1-1
        { id = "REPORTS", name = "战报" },     -- V3.0 P1-1
    }
    local tabY = py + 55
    local tabW = 65
    local tabStartX = px + 10

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 3)
        local selected = panel.tab == tab.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW, 26, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)

        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + tabW / 2, tabY + 13, tab.name)

        addHit(tx, tabY, tabW, 26, function()
            panel.tab = tab.id
        end)
    end

    local contentY = py + 95
    local contentH = ph - 110

    if panel.tab == "FRIENDS" then
        FriendPanel.drawFriends(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "REQUESTS" then
        FriendPanel.drawRequests(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "SEARCH" then
        FriendPanel.drawSearch(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "GIFTS" then
        FriendPanel.drawGifts(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "MATCHES" then
        FriendPanel.drawMatches(vg, px + 15, contentY, pw - 30, contentH)
    elseif panel.tab == "REPORTS" then
        FriendPanel.drawReports(vg, px + 15, contentY, pw - 30, contentH)
    end
end

function FriendPanel.drawFriends(vg, x, y, w, h)
    local FS = require("game.systems.FriendSystem")
    local friends = FS.getFriends()

    if #friends == 0 then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + w / 2, y + h / 2, "暂无好友，去搜索添加吧！")
        return
    end

    local itemH = 55

    for i, friend in ipairs(friends) do
        local itemY = y + (i - 1) * (itemH + 5)
        if itemY + itemH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, w, itemH, 6)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
        nvgFill(vg)

        -- 在线状态
        nvgBeginPath(vg)
        nvgCircle(vg, x + 15, itemY + 20, 6)
        nvgFillColor(vg, friend.online and nvgRGBA(100, 255, 100, 255) or nvgRGBA(150, 150, 150, 255))
        nvgFill(vg)

        -- 名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, friend.online and nvgRGBA(255, 255, 255, 255) or nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 30, itemY + 18, friend.name)

        -- 等级
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 30, itemY + 35, "Lv." .. (friend.level or 1))

        -- 支援状态
        if friend.isHelping then
            nvgFillColor(vg, nvgRGBA(100, 200, 100, 255))
            nvgText(vg, x + 80, itemY + 35, "支援中 +" .. math.floor((friend.helpingBonus or 0) * 100) .. "%")
        end

        -- 按钮
        if friend.online then
            -- 邀请战斗
            local btnX = x + w - 100
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, itemY + 15, 45, 24, 4)
            nvgFillColor(vg, nvgRGBA(60, 120, 180, 220))
            nvgFill(vg)
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, btnX + 22, itemY + 27, "邀请")
            addHit(btnX, itemY + 15, 45, 24, function()
                FS.inviteToBattle(friend.id)
            end)
        end

        -- 删除按钮
        local delX = x + w - 45
        nvgBeginPath(vg)
        nvgRoundedRect(vg, delX, itemY + 15, 35, 24, 4)
        nvgFillColor(vg, nvgRGBA(180, 60, 60, 200))
        nvgFill(vg)
        nvgFontSize(vg, 9)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, delX + 17, itemY + 27, "删除")
        addHit(delX, itemY + 15, 35, 24, function()
            FS.removeFriend(friend.id)
        end)
    end
end

function FriendPanel.drawRequests(vg, x, y, w, h)
    local FS = require("game.systems.FriendSystem")
    local requests = FS.getPendingRequests()

    if #requests == 0 then
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + w / 2, y + h / 2, "暂无好友请求")
        return
    end

    local itemH = 55

    for i, request in ipairs(requests) do
        local itemY = y + (i - 1) * (itemH + 5)
        if itemY + itemH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, w, itemH, 6)
        nvgFillColor(vg, nvgRGBA(35, 50, 70, 200))
        nvgFill(vg)

        -- 名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 15, itemY + 20, request.fromName or "玩家")
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 15, itemY + 38, "Lv." .. (request.fromLevel or 1))

        -- 接受按钮
        local accX = x + w - 95
        nvgBeginPath(vg)
        nvgRoundedRect(vg, accX, itemY + 15, 40, 24, 4)
        nvgFillColor(vg, nvgRGBA(80, 150, 80, 220))
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, accX + 20, itemY + 27, "接受")
        addHit(accX, itemY + 15, 40, 24, function()
            FS.acceptRequest(request.fromId)
        end)

        -- 拒绝按钮
        local rejX = x + w - 50
        nvgBeginPath(vg)
        nvgRoundedRect(vg, rejX, itemY + 15, 40, 24, 4)
        nvgFillColor(vg, nvgRGBA(180, 60, 60, 200))
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, rejX + 20, itemY + 27, "拒绝")
        addHit(rejX, itemY + 15, 40, 24, function()
            FS.rejectRequest(request.fromId)
        end)
    end
end

function FriendPanel.drawSearch(vg, x, y, w, h)
    panel.searchQuery = panel.searchQuery or ""

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 15, "搜索玩家:")

    -- 搜索框
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + 25, w - 100, 30, 4)
    nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 100, 150, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 10, y + 46, panel.searchQuery)

    -- 搜索按钮
    local btnX = x + w - 90
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, y + 25, 80, 30, 4)
    nvgFillColor(vg, nvgRGBA(60, 100, 180, 220))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btnX + 40, y + 40, "搜索")
    addHit(btnX, y + 25, 80, 30, function()
        FriendPanel.doSearch()
    end)

    -- 搜索结果
    if panel.searchResults then
        local resultY = y + 70
        local itemH = 50

        for i, result in ipairs(panel.searchResults) do
            local itemY = resultY + (i - 1) * (itemH + 5)
            if itemY + itemH > y + h then break end

            -- 背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, itemY, w, itemH, 5)
            nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
            nvgFill(vg)

            -- 名称
            nvgFontSize(vg, 12)
            nvgTextAlign(vg, NVG_ALIGN.LEFT)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, x + 10, itemY + 18, result.name)
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
            nvgText(vg, x + 10, itemY + 35, "Lv." .. (result.level or 1))

            -- 添加按钮
            local addX = x + w - 70
            if result.isFriend then
                nvgFillColor(vg, nvgRGBA(100, 150, 100, 200))
                nvgText(vg, addX, itemY + 25, "已添加")
            else
                nvgBeginPath(vg)
                nvgRoundedRect(vg, addX, itemY + 13, 60, 24, 4)
                nvgFillColor(vg, nvgRGBA(60, 120, 180, 220))
                nvgFill(vg)
                nvgFontSize(vg, 10)
                nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                nvgText(vg, addX + 30, itemY + 25, "添加")
                addHit(addX, itemY + 13, 60, 24, function()
                    local FS = require("game.systems.FriendSystem")
                    FS.addFriend(result.id, result.name, result.level)
                    if NotifyPanel then
                        NotifyPanel.push({ type = "SUCCESS", title = "请求已发送", message = "已向 " .. result.name .. " 发送好友请求" })
                    end
                end)
            end
        end
    end
end

function FriendPanel.doSearch()
    local FS = require("game.systems.FriendSystem")
    panel.searchResults = FS.searchPlayers(panel.searchQuery or "")
end

-- ============================================================================
-- V3.0 P1-1: 好友系统 2.0 UI
-- ============================================================================

--- 礼物标签页
function FriendPanel.drawGifts(vg, x, y, w, h)
    local FS = require("game.systems.FriendSystem")
    local FSV2 = require("game.systems.FriendSystem")
    
    local friends = FS.getFriends()
    
    -- 顶部提示
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
    nvgText(vg, x + w/2, y + 15, "每日可向好友赠送礼物，增加友谊值（无消耗）")
    
    if #friends == 0 then
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w/2, y + h/2 + 20, "暂无好友")
        return
    end
    
    local itemH = 50
    local startY = y + 40
    
    for i, friend in ipairs(friends) do
        local itemY = startY + (i - 1) * (itemH + 5)
        if itemY + itemH > y + h then break end
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, w, itemH, 5)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
        nvgFill(vg)
        
        -- 名称
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 10, itemY + 18, friend.name)
        
        -- 友谊值
        local friendship = FSV2.getFriendship(friend.id)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
        nvgText(vg, x + 10, itemY + 35, "友谊值: " .. friendship .. "/100")
        
        -- 友谊进度条
        local barW = 80
        local barX = x + 100
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, itemY + 30, barW, 8, 3)
        nvgFillColor(vg, nvgRGBA(50, 50, 80, 200))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, itemY + 30, barW * (friendship / 100), 8, 3)
        local barColor = friendship >= 80 and nvgRGBA(255, 180, 80, 255) 
            or friendship >= 50 and nvgRGBA(100, 200, 100, 255)
            or nvgRGBA(80, 150, 255, 255)
        nvgFillColor(vg, barColor)
        nvgFill(vg)
        
        -- 称号
        local title = FSV2.getFriendTitle(friend.id)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
        nvgText(vg, x + 190, itemY + 35, title)
        
        -- 送礼按钮
        local canGift, _ = FSV2.canSendGift(friend.id)
        local btnX = x + w - 70
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, itemY + 12, 60, 26, 4)
        nvgFillColor(vg, canGift and nvgRGBA(255, 180, 80, 220) or nvgRGBA(100, 100, 120, 200))
        nvgFill(vg)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + 30, itemY + 25, canGift and "送礼" or "冷却中")
        addHit(btnX, itemY + 12, 60, 26, function()
            if canGift then
                local ok, msg = FSV2.sendGift(friend.id)
                if ok and NotifyPanel then
                    NotifyPanel.push({ type = "SUCCESS", title = "礼物已送达", message = msg })
                end
            end
        end)
    end
end

--- 友谊赛标签页
function FriendPanel.drawMatches(vg, x, y, w, h)
    local FSV2 = require("game.systems.FriendSystem")
    local FS = require("game.systems.FriendSystem")
    
    -- 顶部提示
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
    nvgText(vg, x + w/2, y + 15, "与好友进行友谊赛，胜负不计入排名")
    
    -- 挑战按钮
    local btnY = y + 35
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, btnY, w, 30, 5)
    nvgFillColor(vg, nvgRGBA(80, 140, 200, 220))
    nvgFill(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + w/2, btnY + 15, "发起友谊赛挑战")
    addHit(x, btnY, w, 30, function()
        panel.tab = "FRIENDS"  -- 切换到好友列表选择对手
        panel.selectingChallenge = true
    end)
    
    -- 友谊赛历史
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
    nvgText(vg, x, y + 85, "历史记录:")
    
    local history = FSV2.getMatchHistory()
    if #history == 0 then
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w/2, y + h/2, "暂无友谊赛记录")
        return
    end
    
    local itemH = 40
    local startY = y + 100
    
    for i, match in ipairs(history) do
        local itemY = startY + (i - 1) * (itemH + 3)
        if itemY + itemH > y + h then break end
        
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, w, itemH, 4)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
        nvgFill(vg)
        
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 10, itemY + 15, match.challengerName .. " vs " .. match.challengedName)
        
        nvgFontSize(vg, 10)
        local resultColor = match.result == "DRAW" and nvgRGBA(200, 200, 200, 255)
            or (match.result == "CHALLENGER_WIN" and match.challengerId == (playerState and playerState.id)) and nvgRGBA(100, 255, 100, 255)
            or nvgRGBA(255, 100, 100, 255)
        nvgFillColor(vg, resultColor)
        local resultText = match.result == "CHALLENGER_WIN" and "挑战者胜"
            or match.result == "CHALLENGED_WIN" and "应战者胜"
            or "平局"
        nvgText(vg, x + 10, itemY + 30, resultText .. " (" .. (match.challengerScore or 0) .. "-" .. (match.challengedScore or 0) .. ")")
    end
end

--- 战报标签页
function FriendPanel.drawReports(vg, x, y, w, h)
    local FSV2 = require("game.systems.FriendSystem")
    local FS = require("game.systems.FriendSystem")
    
    local friends = FS.getFriends()
    
    -- 顶部提示
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
    nvgText(vg, x + w/2, y + 15, "查看好友最近战绩")
    
    if #friends == 0 then
        nvgFontSize(vg, 14)
        nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
        nvgText(vg, x + w/2, y + h/2, "暂无好友")
        return
    end
    
    local itemH = 60
    local startY = y + 40
    
    for i, friend in ipairs(friends) do
        local itemY = startY + (i - 1) * (itemH + 5)
        if itemY + itemH > y + h then break end
        
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, itemY, w, itemH, 5)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
        nvgFill(vg)
        
        -- 名称
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 10, itemY + 18, friend.name)
        
        -- 战报摘要
        local summary = FSV2.getFriendBattleSummary(friend.id)
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 200, 220, 255))
        nvgText(vg, x + 10, itemY + 38, 
            string.format("战绩: %d场 | 胜: %d | 平均波次: %d", 
                summary.totalBattles, summary.victories, summary.avgWaves))
        
        -- 友谊加成
        local friendship = FSV2.getFriendship(friend.id)
        local bonus = 0
        for _, reward in ipairs(FSV2.FRIENDSHIP_REWARD_THRESHOLD or {}) do
            if friendship >= reward.threshold then
                bonus = reward.bonus
            end
        end
        if bonus > 0 then
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
            nvgText(vg, x + w - 80, itemY + 38, "+" .. math.floor(bonus * 100) .. "%")
        end
    end
end

return FriendPanel
