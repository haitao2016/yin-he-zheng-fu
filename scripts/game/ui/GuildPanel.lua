---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
-- ============================================================================
-- game/ui/GuildPanel.lua -- 公会面板
-- V2.8 P0-6 UI
-- ============================================================================

local GuildPanel = {}

local panel = nil

-- ============================================================================
-- 面板打开/关闭
-- ============================================================================

function GuildPanel.open()
    local GS = require("game.systems.GuildSystem")

    panel = {
        visible = true,
        tab = GS.isInGuild() and "INFO" or "LIST",
        w = 550,
        h = 420,
    }

    return panel
end

function GuildPanel.close()
    if panel then
        panel.visible = false
        panel = nil
    end
end

-- ============================================================================
-- 面板绘制
-- ============================================================================

function GuildPanel.draw(vg)
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

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN.CENTER)
    nvgFillColor(vg, nvgRGBA(100, 180, 255, 255))
    nvgText(vg, cx, py + 30, "公会")

    -- 关闭按钮
    local closeBtn = { x = px + pw - 35, y = py + 12, w = 22, h = 22 }
    nvgBeginPath(vg)
    nvgCircle(vg, closeBtn.x, closeBtn.y, 11)
    nvgFillColor(vg, nvgRGBA(80, 80, 100, 200))
    nvgFill(vg)
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, closeBtn.x, closeBtn.y + 5, "×")
    addHit(closeBtn.x - 11, closeBtn.y - 11, 22, 22, function()
        GuildPanel.close()
    end)

    -- 标签页
    local GS = require("game.systems.GuildSystem")
    local inGuild = GS.isInGuild()
    local tabs = inGuild and {
        { id = "INFO", name = "公会信息" },
        { id = "MEMBERS", name = "成员" },
        { id = "TASKS", name = "任务" },
        { id = "SETTINGS", name = "设置" },
    } or {
        { id = "LIST", name = "公会列表" },
        { id = "CREATE", name = "创建公会" },
    }

    local tabY = py + 55
    local tabW = 80
    local totalTabW = #tabs * (tabW + 5) - 5
    local tabStartX = cx - totalTabW / 2

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 5)
        local selected = panel.tab == tab.id

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, tabY, tabW, 28, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(35, 45, 65, 200))
        nvgFill(vg)

        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + tabW / 2, tabY + 14, tab.name)

        addHit(tx, tabY, tabW, 28, function()
            panel.tab = tab.id
        end)
    end

    -- 内容
    local contentY = py + 95
    local contentH = ph - 110

    if inGuild then
        if panel.tab == "INFO" then
            GuildPanel.drawInfo(vg, px + 15, contentY, pw - 30, contentH)
        elseif panel.tab == "MEMBERS" then
            GuildPanel.drawMembers(vg, px + 15, contentY, pw - 30, contentH)
        elseif panel.tab == "TASKS" then
            GuildPanel.drawTasks(vg, px + 15, contentY, pw - 30, contentH)
        elseif panel.tab == "SETTINGS" then
            GuildPanel.drawSettings(vg, px + 15, contentY, pw - 30, contentH)
        end
    else
        if panel.tab == "LIST" then
            GuildPanel.drawGuildList(vg, px + 15, contentY, pw - 30, contentH)
        elseif panel.tab == "CREATE" then
            GuildPanel.drawCreate(vg, px + 15, contentY, pw - 30, contentH)
        end
    end
end

-- ============================================================================
-- 公会信息
-- ============================================================================

function GuildPanel.drawInfo(vg, x, y, w, h)
    local GS = require("game.systems.GuildSystem")
    local guild = GS.getPlayerGuild()

    if not guild then
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + w / 2, y + h / 2, "未加入公会")
        return
    end

    -- 公会名称和标签
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x, y + 25, "[" .. guild.tag .. "] " .. guild.name)

    -- 等级
    nvgFontSize(vg, 14)
    nvgFillColor(vg, nvgRGBA(200, 180, 100, 255))
    nvgText(vg, x, y + 50, "Lv." .. guild.level)

    -- 成员数
    nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
    nvgText(vg, x, y + 70, string.format("成员: %d/%d", guild.memberCount, guild.maxMembers))

    -- 会长
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 90, "会长: " .. guild.leaderName)

    -- 公告
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(150, 150, 180, 255))
    nvgText(vg, x, y + 115, "公告:")
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    local announcement = guild.announcement or "暂无公告"
    if #announcement > 30 then announcement = announcement:sub(1, 30) .. "..." end
    nvgText(vg, x, y + 132, announcement)

    -- 经验条
    local levelReward = GUILD_LEVEL_REWARDS[guild.level + 1]
    local nextExp = levelReward and levelReward.exp or guild.exp
    local progress = nextExp > 0 and guild.exp / nextExp or 1

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + 155, w - 100, 16, 4)
    nvgFillColor(vg, nvgRGBA(40, 50, 70, 200))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + 155, (w - 100) * math.min(1, progress), 16, 4)
    nvgFillColor(vg, nvgRGBA(80, 160, 255, 220))
    nvgFill(vg)

    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 5, y + 163, guild.exp .. "/" .. nextExp)

    -- 离开公会按钮
    local btnX, btnY = x + w - 80, y + 150
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, 70, 26, 4)
    nvgFillColor(vg, nvgRGBA(180, 60, 60, 200))
    nvgFill(vg)
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btnX + 35, btnY + 13, "离开公会")
    addHit(btnX, btnY, 70, 26, function()
        GuildPanel.leaveGuild()
    end)
end

function GuildPanel.leaveGuild()
    local GS = require("game.systems.GuildSystem")
    local success, msg = GS.leaveGuild(playerState and playerState.id)

    if NotifyPanel then
        NotifyPanel.push({
            type = success and "INFO" or "ERROR",
            title = success and "离开公会" or "离开失败",
            message = msg,
        })
    end

    if success then
        panel.tab = "LIST"
    end
end

-- ============================================================================
-- 成员列表
-- ============================================================================

function GuildPanel.drawMembers(vg, x, y, w, h)
    local GS = require("game.systems.GuildSystem")
    local guild = GS.getPlayerGuild()

    if not guild then return end

    local members = guild.members
    local rowH = 35

    for i, member in ipairs(members) do
        local rowY = y + (i - 1) * (rowH + 2)
        if rowY + rowH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, rowH, 4)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 180))
        nvgFill(vg)

        -- 角色标记
        local roleColor = member.role == "LEADER" and nvgRGBA(255, 200, 50, 255)
                      or member.role == "OFFICER" and nvgRGBA(150, 150, 255, 255)
                      or nvgRGBA(180, 180, 200, 255)
        nvgFontSize(vg, 10)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, roleColor)
        nvgText(vg, x + 10, rowY + 12, "[" .. member.roleName .. "]")

        -- 名称
        nvgFontSize(vg, 12)
        nvgFillColor(vg, member.isOnline and nvgRGBA(100, 255, 100, 255) or nvgRGBA(200, 200, 220, 255))
        nvgText(vg, x + 80, rowY + 12, member.name)

        -- 在线状态
        if member.isOnline then
            nvgFontSize(vg, 10)
            nvgFillColor(vg, nvgRGBA(100, 255, 100, 200))
            nvgText(vg, x + 80, rowY + 25, "在线")
        end

        -- 贡献
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.RIGHT)
        nvgFillColor(vg, nvgRGBA(200, 180, 100, 255))
        nvgText(vg, x + w - 10, rowY + rowH / 2, "贡献: " .. member.contribution)
    end
end

-- ============================================================================
-- 任务
-- ============================================================================

function GuildPanel.drawTasks(vg, x, y, w, h)
    local GS = require("game.systems.GuildSystem")
    local tasks = GS.getDailyTasks()

    for i, task in ipairs(tasks) do
        local rowY = y + (i - 1) * 55
        if rowY + 50 > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, 50, 6)
        nvgFillColor(vg, task.completed and nvgRGBA(30, 60, 40, 200) or nvgRGBA(30, 40, 60, 180))
        nvgFill(vg)

        -- 任务名称
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, task.completed and nvgRGBA(100, 255, 100, 255) or nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 15, rowY + 18, task.name)

        -- 描述
        nvgFontSize(vg, 10)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 15, rowY + 35, string.format("%s (%d/%d)", task.desc, task.progress, task.target))

        -- 领取按钮
        if task.completed then
            local btnX, btnY = x + w - 70, rowY + 13
            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, btnY, 60, 24, 4)
            nvgFillColor(vg, nvgRGBA(80, 150, 80, 220))
            nvgFill(vg)
            nvgFontSize(vg, 11)
            nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, btnX + 30, btnY + 12, "领取")
            addHit(btnX, btnY, 60, 24, function()
                GS.claimTaskReward(task.id)
            end)
        end
    end
end

-- ============================================================================
-- 设置
-- ============================================================================

function GuildPanel.drawSettings(vg, x, y, w, h)
    local GS = require("game.systems.GuildSystem")
    local guild = GS.getPlayerGuild()

    if not guild then return end

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 25, "加入方式:")

    -- 加入方式选项
    local joinTypes = { "OPEN", "APPROVAL", "INVITE" }
    local btnW = 90
    local startX = x

    for i, jt in ipairs(joinTypes) do
        local jtDef = GUILD_JOIN_TYPES[jt]
        local tx = startX + (i - 1) * (btnW + 8)
        local selected = guild.joinType == jt

        nvgBeginPath(vg)
        nvgRoundedRect(vg, tx, y + 40, btnW, 26, 4)
        nvgFillColor(vg, selected and nvgRGBA(60, 100, 180, 220) or nvgRGBA(40, 50, 70, 200))
        nvgFill(vg)

        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, tx + btnW / 2, y + 53, jtDef.name)

        addHit(tx, y + 40, btnW, 26, function()
            GS.setJoinType(jt)
        end)
    end

    -- 解散公会按钮（会长专用）
    if GuildState.playerRole == "LEADER" then
        local btnX, btnY = x, y + 90
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY, 100, 28, 4)
        nvgFillColor(vg, nvgRGBA(200, 50, 50, 200))
        nvgFill(vg)
        nvgFontSize(vg, 12)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + 50, btnY + 14, "解散公会")
        addHit(btnX, btnY, 100, 28, function()
            GS.disbandGuild()
            panel.tab = "LIST"
        end)
    end
end

-- ============================================================================
-- 公会列表
-- ============================================================================

function GuildPanel.drawGuildList(vg, x, y, w, h)
    local GS = require("game.systems.GuildSystem")
    local guilds = GS.getGuildList()

    if #guilds == 0 then
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.CENTER)
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + w / 2, y + h / 2, "暂无公会，创建第一个公会吧！")
        return
    end

    local rowH = 55

    for i, guild in ipairs(guilds) do
        local rowY = y + (i - 1) * (rowH + 5)
        if rowY + rowH > y + h then break end

        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, rowY, w, rowH, 6)
        nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
        nvgFill(vg)

        -- 公会名
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN.LEFT)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, x + 15, rowY + 20, "[" .. guild.tag .. "] " .. guild.name)

        -- 等级和成员
        nvgFontSize(vg, 11)
        nvgFillColor(vg, nvgRGBA(200, 180, 100, 255))
        nvgText(vg, x + 15, rowY + 38, string.format("Lv.%d | %d/%d 成员", guild.level, guild.memberCount, guild.maxMembers))

        -- 会长
        nvgFillColor(vg, nvgRGBA(180, 180, 200, 255))
        nvgText(vg, x + 200, rowY + 38, "会长: " .. guild.leaderName)

        -- 加入按钮
        local btnX, btnY = x + w - 70, rowY + rowH / 2 - 12
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY, 60, 24, 4)
        nvgFillColor(vg, nvgRGBA(60, 120, 180, 220))
        nvgFill(vg)
        nvgFontSize(vg, 11)
        nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + 30, btnY + 12, "加入")
        addHit(btnX, btnY, 60, 24, function()
            GS.joinGuild(guild.id, playerState and playerState.id, playerState and playerState.name)
            panel.tab = "INFO"
        end)
    end
end

-- ============================================================================
-- 创建公会
-- ============================================================================

function GuildPanel.drawCreate(vg, x, y, w, h)
    panel.createName = panel.createName or ""
    panel.createTag = panel.createTag or ""

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))

    -- 公会名称
    nvgText(vg, x, y + 25, "公会名称 (2-16字符):")
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + 35, w - 120, 30, 4)
    nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 100, 150, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 10, y + 55, panel.createName)

    -- 公会标签
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(200, 200, 220, 255))
    nvgText(vg, x, y + 85, "公会标签 (2-5字符):")
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + 95, 100, 30, 4)
    nvgFillColor(vg, nvgRGBA(30, 40, 60, 200))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(80, 100, 150, 150))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 12)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, x + 10, y + 115, panel.createTag)

    -- 创建按钮
    local btnX, btnY = x + w - 100, y + 130
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY, 90, 30, 4)
    nvgFillColor(vg, nvgRGBA(80, 150, 80, 220))
    nvgFill(vg)
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN.CENTER + NVG_ALIGN.MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, btnX + 45, btnY + 15, "创建公会")
    addHit(btnX, btnY, 90, 30, function()
        GuildPanel.doCreate()
    end)

    -- 输入提示
    nvgFontSize(vg, 10)
    nvgTextAlign(vg, NVG_ALIGN.LEFT)
    nvgFillColor(vg, nvgRGBA(150, 150, 170, 255))
    nvgText(vg, x, y + 180, "提示: 输入公会名称和标签后点击创建按钮")
end

function GuildPanel.doCreate()
    local GS = require("game.systems.GuildSystem")
    local name = panel.createName or ""
    local tag = panel.createTag or ""

    if #name < 2 or #name > 16 then
        if NotifyPanel then
            NotifyPanel.push({ type = "ERROR", title = "创建失败", message = "公会名称长度需在 2-16 字符之间" })
        end
        return
    end

    if #tag < 2 or #tag > 5 then
        if NotifyPanel then
            NotifyPanel.push({ type = "ERROR", title = "创建失败", message = "公会标签长度需在 2-5 字符之间" })
        end
        return
    end

    local success, msg = GS.createGuild(name, tag, playerState and playerState.id, playerState and playerState.name)

    if NotifyPanel then
        NotifyPanel.push({
            type = success and "SUCCESS" or "ERROR",
            title = success and "创建成功" or "创建失败",
            message = msg,
        })
    end

    if success then
        panel.tab = "INFO"
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return GuildPanel
