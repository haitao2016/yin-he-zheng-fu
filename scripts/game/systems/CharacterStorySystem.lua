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

-- ============================================================================
-- V3.0 P2-1: 角色故事扩展
-- 羁绊系统/立绘/传记
-- ============================================================================

local CharacterStoryV2 = {}

-- ============================================================================
-- 羁绊系统常量
-- ============================================================================
BOND_SYSTEM = {
    MAX_LEVEL = 10,
    LEVEL_THRESHOLDS = { 0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500 },
    BATTLE_ACTIONS = {
        WIN_BATTLE = 10,           -- 战斗胜利
        LOSE_BATTLE = 5,           -- 战斗失败
        USE_COMMANDER_SKILL = 3,   -- 使用指挥官技能
        KILL_BOSS = 20,            -- 击杀Boss
        PROTECT_ALLY = 5,          -- 保护友军
    },
    TITLES = {
        { level = 2, title = "初识", color = {0.5, 0.5, 0.5} },
        { level = 4, title = "战友", color = {0.3, 0.7, 0.3} },
        { level = 6, title = "挚友", color = {0.3, 0.5, 0.9} },
        { level = 8, title = "知己", color = {0.7, 0.5, 0.9} },
        { level = 10, title = "灵魂伴侣", color = {1.0, 0.8, 0.2} },
    },
}

-- 角色立绘定义
CHARACTER_PORTRAITS = {
    -- 使用 ASCII art 风格
    COMM = {
        name = "指挥官",
        ascii = {
            [[
    ╔═══════════╗
    ║  ◉     ◉  ║
    ║     ▽     ║
    ║  ╰─────╯  ║
    ║   ╱   ╲   ║
    ║  ╱ ═══ ╲  ║
    ║    ║║     ║
    ╚═══════════╝
            ]],
            -- 受伤状态
            [[
    ╔═══════════╗
    ║  ◉  ✕  ◉  ║
    ║     ▽     ║
    ║  ╰─────╯  ║
    ║   ╱   ╲   ║
    ║  ╱ ═══ ╲  ║
    ║    ║║     ║
    ╚═══════════╝
            ]],
            -- 喜悦状态
            [[
    ╔═══════════╗
    ║  ◉     ◉  ║
    ║    ═══    ║
    ║  ╰─────╯  ║
    ║   ╱   ╲   ║
    ║  ╱ ═══ ╲  ║
    ║    ║║     ║
    ╚═══════════╝
            ]],
        },
        defaultEmotion = 1,
        emotionMap = { normal = 1, hurt = 2, happy = 3 },
    },
    OFFICER = {
        name = "副官",
        ascii = {
            [[
    ╔═══════════╗
    ║  ◉     ◉  ║
    ║     ▽     ║
    ║  ╰──┬──╯  ║
    ║   ╱   ╲   ║
    ║  ╱ ═══ ╲  ║
    ║    ║║     ║
    ╚═══════════╝
            ]],
        },
        defaultEmotion = 1,
    },
}

-- 传记定义
CHARACTER_BIOGRAPHIES = {
    COMM = {
        title = "指挥官的崛起",
        unlockLevel = 10,
        content = [[
【早年经历】
出生于银河边缘殖民地的普通矿工家庭。从小就对星空充满向往，常常在夜晚仰望天空。

【加入抵抗军】
帝国入侵那天，你的家园被毁。在混乱中，你展现出了惊人的领导才能，组织幸存者进行抵抗。

【成为指挥官】
在多次成功防守后，你被推举为抵抗军的临时指挥官。从那一刻起，你的命运与整个银河紧紧相连。

【核心信念】
"无论敌人多么强大，只要我们团结一心，就没有什么是不可能的。"
        ]],
    },
    OFFICER = {
        title = "情报官的秘密",
        unlockLevel = 10,
        content = [[
【帝国的阴影】
曾是帝国情报部门的精英特工，掌握着大量机密信息。

【觉醒与逃离】
在一次任务中，你发现了帝国的真正目的——毁灭银河系中所有的智慧生命。你选择背叛帝国，带着机密档案逃离。

【加入抵抗军】
你的情报为抵抗军带来了巨大帮助，但你始终背负着过去的罪孽。

【核心信念】
"过去无法改变，但未来由我们书写。"
        ]],
    },
}

-- ============================================================================
-- 羁绊运行时状态
-- ============================================================================
local BondState = {
    bonds = {},          -- { [characterId] = { level = 1, exp = 0, lastBattle = 0 } }
    portraits = {},      -- { [characterId] = currentEmotion }
    biographyUnlocked = {}, -- { [characterId] = true }
}

-- ============================================================================
-- 羁绊系统
-- ============================================================================

--- 获取羁绊信息
function CharacterStoryV2.getBond(characterId)
    local bond = BondState.bonds[characterId]
    if not bond then
        bond = { level = 0, exp = 0, totalExp = 0 }
        BondState.bonds[characterId] = bond
    end
    return bond
end

--- 增加羁绊经验
function CharacterStoryV2.addBondExp(characterId, amount, source)
    local bond = CharacterStoryV2.getBond(characterId)
    bond.exp = bond.exp + amount
    bond.totalExp = bond.totalExp + amount
    
    -- 检查升级
    while bond.level < BOND_SYSTEM.MAX_LEVEL do
        local nextThreshold = BOND_SYSTEM.LEVEL_THRESHOLDS[bond.level + 1] or 99999
        if bond.totalExp >= nextThreshold then
            bond.level = bond.level + 1
            CharacterStoryV2.onLevelUp(characterId, bond.level)
        else
            break
        end
    end
    
    -- 触发羁绊对话
    if source and math.random() < 0.3 then
        CharacterStoryV2.triggerBondDialogue(characterId, source)
    end
    
    return bond.level, bond.exp
end

--- 升级时触发
function CharacterStoryV2.onLevelUp(characterId, newLevel)
    local character = nil
    for _, char in ipairs(CHARACTERS) do
        if char.id == characterId then
            character = char
            break
        end
    end
    
    -- 查找对应的称号
    local title = "初识"
    for _, t in ipairs(BOND_SYSTEM.TITLES) do
        if newLevel >= t.level then
            title = t.title
        end
    end
    
    -- 通知
    if NotifyPanel then
        NotifyPanel.push({
            type = "BOND_LEVEL_UP",
            title = "羁绊升级",
            message = string.format("%s 与「%s」的羁绊达到 Lv.%d「%s」！", 
                playerState and playerState.name or "指挥官",
                character and character.name or characterId,
                newLevel, title),
        })
    end
    
    -- 解锁传记
    if newLevel >= BOND_SYSTEM.MAX_LEVEL then
        BondState.biographyUnlocked[characterId] = true
    end
end

--- 获取羁绊称号
function CharacterStoryV2.getBondTitle(characterId)
    local bond = CharacterStoryV2.getBond(characterId)
    local title = "陌生人"
    
    for _, t in ipairs(BOND_SYSTEM.TITLES) do
        if bond.level >= t.level then
            title = t.title
        end
    end
    
    return title, bond.level
end

--- 获取羁绊加成
function CharacterStoryV2.getBondBonus(characterId)
    local bond = CharacterStoryV2.getBond(characterId)
    local bonus = 0
    
    -- 羁绊等级越高，加成越高
    bonus = bond.level * 0.02  -- 每级2%加成
    
    return bonus
end

--- 获取所有羁绊加成总和
function CharacterStoryV2.getTotalBondBonus()
    local total = 0
    for charId, _ in pairs(BondState.bonds) do
        total = total + CharacterStoryV2.getBondBonus(charId)
    end
    return math.min(total, 0.5)  -- 最多50%加成
end

--- 触发羁绊对话
function CharacterStoryV2.triggerBondDialogue(characterId, source)
    local bondLevel = CharacterStoryV2.getBond(characterId).level
    if bondLevel < 1 then return nil end
    
    -- 根据羁绊等级和来源选择对话
    local dialogues = {
        BATTLE_WIN = {
            { minLevel = 1, text = "干得漂亮，指挥官！" },
            { minLevel = 3, text = "又有敌人倒下了呢~" },
            { minLevel = 6, text = "我们真是绝佳的搭档。" },
            { minLevel = 8, text = "只要有你在，我什么都不怕。" },
        },
        BATTLE_LOSE = {
            { minLevel = 1, text = "别灰心，下次一定赢！" },
            { minLevel = 4, text = "失败是成功之母嘛~" },
            { minLevel = 7, text = "我会一直陪着你。" },
        },
    }
    
    local dialogSet = dialogues[source]
    if not dialogSet then return nil end
    
    -- 找到符合条件的对话
    local selectedDialog = nil
    for i = #dialogSet, 1, -1 do
        if bondLevel >= dialogSet[i].minLevel then
            selectedDialog = dialogSet[i]
            break
        end
    end
    
    return selectedDialog and selectedDialog.text or nil
end

-- ============================================================================
-- 表情系统
-- ============================================================================

--- 设置角色表情
function CharacterStoryV2.setEmotion(characterId, emotion)
    local portrait = CHARACTER_PORTRAITS[characterId]
    if not portrait then return false end
    
    local emotionIndex = portrait.emotionMap and portrait.emotionMap[emotion]
    if emotionIndex then
        BondState.portraits[characterId] = emotionIndex
        return true
    end
    
    return false
end

--- 获取角色当前表情
function CharacterStoryV2.getEmotion(characterId)
    return BondState.portraits[characterId] or 
        (CHARACTER_PORTRAITS[characterId] and CHARACTER_PORTRAITS[characterId].defaultEmotion) or 1
end

--- 获取角色立绘
function CharacterStoryV2.getPortrait(characterId)
    local portrait = CHARACTER_PORTRAITS[characterId]
    if not portrait then return nil end
    
    local emotionIndex = CharacterStoryV2.getEmotion(characterId)
    local asciiArt = portrait.ascii[emotionIndex] or portrait.ascii[1]
    
    return {
        characterId = characterId,
        name = portrait.name,
        ascii = asciiArt,
        emotionIndex = emotionIndex,
    }
end

-- ============================================================================
-- 传记系统
-- ============================================================================

--- 检查传记是否解锁
function CharacterStoryV2.isBiographyUnlocked(characterId)
    return BondState.biographyUnlocked[characterId] == true
end

--- 获取角色传记
function CharacterStoryV2.getBiography(characterId)
    if not CharacterStoryV2.isBiographyUnlocked(characterId) then
        return nil
    end
    
    return CHARACTER_BIOGRAPHIES[characterId]
end

--- 获取所有已解锁传记的角色列表
function CharacterStoryV2.getUnlockedBiographies()
    local unlocked = {}
    for charId, _ in pairs(BondState.biographyUnlocked) do
        if BondState.biographyUnlocked[charId] then
            table.insert(unlocked, {
                characterId = charId,
                biography = CHARACTER_BIOGRAPHIES[charId],
            })
        end
    end
    return unlocked
end

-- ============================================================================
-- 完整角色信息
-- ============================================================================

--- 获取完整角色信息（包含羁绊和传记）
function CharacterStoryV2.getFullCharacterInfo(characterId)
    local character = nil
    for _, char in ipairs(CHARACTERS) do
        if char.id == characterId then
            character = char
            break
        end
    end
    
    if not character then return nil end
    
    local bond = CharacterStoryV2.getBond(characterId)
    local title, titleLevel = CharacterStoryV2.getBondTitle(characterId)
    local portrait = CharacterStoryV2.getPortrait(characterId)
    local biography = CharacterStoryV2.getBiography(characterId)
    local bonus = CharacterStoryV2.getBondBonus(characterId)
    
    return {
        id = character.id,
        name = character.name,
        title = character.title,
        faction = character.faction,
        bond = {
            level = bond.level,
            exp = bond.exp,
            totalExp = bond.totalExp,
            title = title,
            bonus = bonus,
        },
        portrait = portrait,
        biography = biography,
        biographyUnlocked = CharacterStoryV2.isBiographyUnlocked(characterId),
    }
end

-- ============================================================================
-- 存档
-- ============================================================================

function CharacterStoryV2.saveState()
    if playerState then
        playerState.characterStoryV2 = {
            bonds = BondState.bonds,
            portraits = BondState.portraits,
            biographyUnlocked = BondState.biographyUnlocked,
        }
    end
end

function CharacterStoryV2.loadState(data)
    if data then
        BondState.bonds = data.bonds or {}
        BondState.portraits = data.portraits or {}
        BondState.biographyUnlocked = data.biographyUnlocked or {}
    end
end

return CharacterStoryV2
