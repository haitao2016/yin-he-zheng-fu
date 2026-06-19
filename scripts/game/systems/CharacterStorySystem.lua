---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/systems/CharacterStorySystem.lua -- 角色故事系统
-- V2.8 P1-1
-- ============================================================================

local CharacterStorySystem = {}

-- ============================================================================
-- 角色定义
-- ============================================================================

CHARACTERS = {
    {
        id = "COMM",
        name = "指挥官",
        title = "抵抗军临时指挥官",
        faction = "REBEL",
        portrait = "commander_default",
        stories = {
            {
                id = "ORIGIN",
                title = "星火起源",
                desc = "讲述你如何从普通公民成为抵抗军指挥官的故事",
                unlockCondition = { type = "WAVE_REACH", value = 5 },
                chapters = {
                    { id = "ORIGIN_1", title = "平凡的一天",
                      dialogues = {
                          { speaker = "旁白", text = "在银河边缘的殖民地，生活着一群普通的太空居民..." },
                          { speaker = "你", text = "今天的矿场工作终于结束了。" },
                      }
                    },
                    { id = "ORIGIN_2", title = "警报响起",
                      dialogues = {
                          { speaker = "警报", text = "警告！帝国舰队已进入大气层！" },
                          { speaker = "你", text = "什么？！" },
                      }
                    },
                },
            },
            {
                id = "FIRST_BATTLE",
                title = "初战告捷",
                desc = "你第一次指挥战斗的故事",
                unlockCondition = { type = "CAMPAIGN_STAGE", value = "STAGE_P1" },
                chapters = {
                    { id = "FIRST_1", title = "临时征召",
                      dialogues = {
                          { speaker = "军官", text = "我们需要志愿者来指挥我们的防御舰队！" },
                          { speaker = "你", text = "让我试试。" },
                      }
                    },
                },
            },
        },
    },
    {
        id = "OFFICER",
        name = "副官",
        title = "情报官",
        faction = "REBEL",
        portrait = "officer_default",
        stories = {
            {
                id = "BACKSTORY",
                title = "帝国的阴影",
                desc = "副官的身世之谜",
                unlockCondition = { type = "BATTLE_COUNT", value = 20 },
                chapters = {
                    { id = "BACKSTORY_1", title = "旧日的伤疤",
                      dialogues = {
                          { speaker = "副官", text = "指挥官，有些事情我一直没告诉你..." },
                          { speaker = "你", text = "什么事？" },
                          { speaker = "副官", text = "我曾是帝国情报部门的一员..." },
                      }
                    },
                },
            },
        },
    },
    {
        id = "ADMIRAL_CHEN",
        name = "陈将军",
        title = "帝国舰队指挥官",
        faction = "EMPIRE",
        portrait = "commander_admiral_chen",
        stories = {
            {
                id = "FALL",
                title = "将军的陨落",
                desc = "帝国最杰出将领的崛起与陨落",
                unlockCondition = { type = "WAVE_REACH", value = 30 },
                chapters = {
                    { id = "FALL_1", title = "帝国的骄傲",
                      dialogues = {
                          { speaker = "旁白", text = "陈将军曾是帝国最年轻的舰队指挥官..." },
                          { speaker = "陈将军", text = "帝国给了我一切。" },
                      }
                    },
                    { id = "FALL_2", title = "转折点",
                      dialogues = {
                          { speaker = "陈将军", text = "这一切值得吗？" },
                          { speaker = "旁白", text = "在一次任务中，陈将军开始质疑帝国的做法..." },
                      }
                    },
                },
            },
        },
    },
    {
        id = "REBEL_LEADER",
        name = "艾琳·诺克斯",
        title = "自由联盟领袖",
        faction = "REBEL",
        portrait = "commander_rebel_leader",
        stories = {
            {
                id = "REVOLUTION",
                title = "科学家的叛逆",
                desc = "从帝国天才到叛军领袖的转变",
                unlockCondition = { type = "WAVE_REACH", value = 50 },
                chapters = {
                    { id = "REV_1", title = "象牙塔",
                      dialogues = {
                          { speaker = "旁白", text = "艾琳曾是帝国科学院最年轻的天才科学家..." },
                          { speaker = "艾琳", text = "科学应该造福所有人，而非服务于帝国的野心。" },
                      }
                    },
                    { id = "REV_2", title = "觉醒",
                      dialogues = {
                          { speaker = "艾琳", text = "我看到了他们的所作所为，无法再沉默。" },
                          { speaker = "艾琳", text = "是时候站出来了。" },
                      }
                    },
                },
            },
        },
    },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

local StoryState = {
    unlockedCharacters = { "COMM" },
    unlockedStories = {},
    readChapters = {},
    favorites = {},
}

-- ============================================================================
-- 查询接口
-- ============================================================================

-- 获取所有角色
function CharacterStorySystem.getCharacters()
    local chars = {}
    for _, char in ipairs(CHARACTERS) do
        local isUnlocked = StoryState.unlockedCharacters[char.id] == true
        local unreadCount = CharacterStorySystem.getUnreadCount(char.id)

        table.insert(chars, {
            id = char.id,
            name = char.name,
            title = char.title,
            faction = char.faction,
            portrait = char.portrait,
            unlocked = isUnlocked,
            unreadCount = unreadCount,
        })
    end
    return chars
end

-- 获取角色故事
function CharacterStorySystem.getCharacterStories(charId)
    local char = nil
    for _, c in ipairs(CHARACTERS) do
        if c.id == charId then char = c; break end
    end
    if not char then return {} end

    local stories = {}
    for _, story in ipairs(char.stories) do
        local isUnlocked = StoryState.unlockedStories[story.id] == true
        local isRead = StoryState.readChapters[story.id] == true

        table.insert(stories, {
            id = story.id,
            title = story.title,
            desc = story.desc,
            unlocked = isUnlocked,
            read = isRead,
            chapterCount = #story.chapters,
        })
    end
    return stories
end

-- 获取故事章节
function CharacterStorySystem.getStoryChapters(storyId)
    for _, char in ipairs(CHARACTERS) do
        for _, story in ipairs(char.stories) do
            if story.id == storyId then
                local chapters = {}
                for _, chapter in ipairs(story.chapters) do
                    table.insert(chapters, {
                        id = chapter.id,
                        title = chapter.title,
                        dialogues = chapter.dialogues,
                        read = StoryState.readChapters[chapter.id] == true,
                    })
                end
                return chapters
            end
        end
    end
    return {}
end

-- 获取未读数量
function CharacterStorySystem.getUnreadCount(charId)
    local char = nil
    for _, c in ipairs(CHARACTERS) do
        if c.id == charId then char = c; break end
    end
    if not char then return 0 end

    local count = 0
    for _, story in ipairs(char.stories) do
        if StoryState.unlockedStories[story.id] and not StoryState.readChapters[story.id] then
            count = count + #story.chapters
        end
    end
    return count
end

-- ============================================================================
-- 解锁检查
-- ============================================================================

-- 检查并更新解锁状态
function CharacterStorySystem.checkUnlocks()
    -- 检查角色解锁
    for _, char in ipairs(CHARACTERS) do
        if not StoryState.unlockedCharacters[char.id] then
            for _, story in ipairs(char.stories) do
                if CharacterStorySystem.checkCondition(story.unlockCondition) then
                    StoryState.unlockedCharacters[char.id] = true
                    StoryState.unlockedStories[story.id] = true

                    if NotifyPanel then
                        NotifyPanel.push({
                            type = "STORY",
                            title = "角色故事解锁",
                            message = char.name .. " 的故事已解锁",
                        })
                    end
                    break
                end
            end
        end
    end

    -- 检查故事解锁
    for _, char in ipairs(CHARACTERS) do
        for _, story in ipairs(char.stories) do
            if not StoryState.unlockedStories[story.id] then
                if CharacterStorySystem.checkCondition(story.unlockCondition) then
                    StoryState.unlockedStories[story.id] = true

                    if NotifyPanel then
                        NotifyPanel.push({
                            type = "STORY",
                            title = "新故事",
                            message = story.title .. " 已解锁",
                        })
                    end
                end
            end
        end
    end

    CharacterStorySystem.saveState()
end

-- 检查条件
function CharacterStorySystem.checkCondition(condition)
    if not condition then return true end

    if condition.type == "WAVE_REACH" then
        return playerState and playerState.currentWave and playerState.currentWave >= condition.value
    elseif condition.type == "CAMPAIGN_STAGE" then
        local CS = require("game.systems.CampaignSystem")
        local progress = CS.getProgress()
        return progress and progress.completedStages and progress.completedStages[condition.value] == true
    elseif condition.type == "BATTLE_COUNT" then
        return playerState and playerState.battleCount and playerState.battleCount >= condition.value
    elseif condition.type == "BOSS_DEFEATED" then
        return playerState and playerState.bossesDefeated and playerState.bossesDefeated >= condition.value
    end

    return false
end

-- ============================================================================
-- 阅读功能
-- ============================================================================

-- 阅读章节
function CharacterStorySystem.readChapter(storyId, chapterId)
    -- 标记为已读
    StoryState.readChapters[storyId] = true
    StoryState.readChapters[chapterId] = true
    CharacterStorySystem.saveState()
end

-- 添加收藏
function CharacterStorySystem.addFavorite(storyId)
    StoryState.favorites[storyId] = true
    CharacterStorySystem.saveState()
end

-- 移除收藏
function CharacterStorySystem.removeFavorite(storyId)
    StoryState.favorites[storyId] = nil
    CharacterStorySystem.saveState()
end

-- 是否收藏
function CharacterStorySystem.isFavorite(storyId)
    return StoryState.favorites[storyId] == true
end

-- ============================================================================
-- 剧情回顾
-- ============================================================================

-- 获取已读章节列表
function CharacterStorySystem.getReadChapters()
    local chapters = {}
    for id, _ in pairs(StoryState.readChapters) do
        table.insert(chapters, id)
    end
    return chapters
end

-- 检查是否有新内容
function CharacterStorySystem.hasNewContent()
    for _, char in ipairs(CHARACTERS) do
        if CharacterStorySystem.getUnreadCount(char.id) > 0 then
            return true
        end
    end
    return false
end

-- ============================================================================
-- 存档
-- ============================================================================

function CharacterStorySystem.saveState()
    if playerState then
        playerState.characterStoryState = StoryState
    end
end

function CharacterStorySystem.loadState(data)
    if data then
        StoryState.unlockedCharacters = data.unlockedCharacters or { "COMM" }
        StoryState.unlockedStories = data.unlockedStories or {}
        StoryState.readChapters = data.readChapters or {}
        StoryState.favorites = data.favorites or {}
    end
end

-- ============================================================================
-- 导出
-- ============================================================================

return CharacterStorySystem
