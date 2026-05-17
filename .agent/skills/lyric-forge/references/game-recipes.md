# Lyric Forge — 游戏场景实战方案

> 将文本生成系统集成到各类游戏场景的完整方案。

---

## Recipe 1: 酒馆吟游诗人系统

### 场景描述

RPG 酒馆中，吟游诗人 NPC 每次交互时唱不同的歌谣。

### 实现

```lua
-- scripts/tavern/BardSystem.lua
local BardSystem = {}

local CorpusLoader = require("scripts.lyric-forge.CorpusLoader")
local MarkovChain = require("scripts.lyric-forge.MarkovChain")
local StyleProfile = require("scripts.lyric-forge.StyleProfile")
local StructureTemplate = require("scripts.lyric-forge.StructureTemplate")
local TextGenerator = require("scripts.lyric-forge.TextGenerator")
local ProfileStore = require("scripts.lyric-forge.ProfileStore")

local bardChain = nil
local bardProfile = nil
local songHistory = {}      -- 已唱过的歌（避免重复）
local MAX_HISTORY = 20

--- 初始化诗人系统
function BardSystem.Init()
    -- 优先加载已训练模型
    bardChain, bardProfile = ProfileStore.Load("tavern_bard")

    if not bardChain then
        -- 首次运行：从语料训练
        local corpus = CorpusLoader.Load("Texts/corpus/tavern_songs.json")
        if corpus then
            local lines = CorpusLoader.Flatten(corpus)
            bardProfile = StyleProfile.Analyze(lines)
            bardChain = MarkovChain.New(3)
            bardChain:Train(lines)
            ProfileStore.Save("tavern_bard", bardChain, bardProfile)
            log:Info("[BardSystem] trained and saved model")
        end
    end
end

--- NPC 唱歌
---@param topic string|nil 话题关键词
---@return string song
function BardSystem.Sing(topic)
    if not bardChain then
        return "（诗人清了清嗓子，但似乎忘了歌词...）"
    end

    local template = StructureTemplate.Get("tavern_ballad")
    local generator = TextGenerator.New(bardChain, bardProfile)

    -- 尝试生成不重复的歌
    for attempt = 1, 3 do
        local song = generator:GenerateFromTemplate(template, topic, {
            temperature = 0.8 + attempt * 0.1,
        })

        -- 检查是否唱过
        local isDuplicate = false
        for _, prev in ipairs(songHistory) do
            if prev == song then isDuplicate = true; break end
        end

        if not isDuplicate then
            songHistory[#songHistory + 1] = song
            if #songHistory > MAX_HISTORY then
                table.remove(songHistory, 1)
            end
            return song
        end
    end

    -- 兜底
    return generator:GenerateFromTemplate(template, topic, {
        temperature = 1.5,
    })
end

return BardSystem
```

### 与游戏集成

```lua
-- 在 NPC 对话系统中调用
function OnBardInteraction(npcNode, playerNode)
    local BardSystem = require("scripts.tavern.BardSystem")
    local song = BardSystem.Sing("英雄")
    ShowDialogueUI("吟游诗人", "♪ " .. song .. " ♪")
end
```

---

## Recipe 2: 预言卷轴生成器

### 场景描述

RPG 中玩家找到卷轴时，生成神秘的预言文本。

### 实现

```lua
-- scripts/items/ProphecyScroll.lua
local ProphecyScroll = {}

local ProfileStore = require("scripts.lyric-forge.ProfileStore")
local StructureTemplate = require("scripts.lyric-forge.StructureTemplate")
local TextGenerator = require("scripts.lyric-forge.TextGenerator")

--- 生成预言
---@param context table { heroName, questName, location }
---@return string prophecy
function ProphecyScroll.Generate(context)
    local chain, profile = ProfileStore.Load("mystic_oracle")
    if not chain then
        return "此卷轴的文字已褪色，无法辨认..."
    end

    local template = StructureTemplate.Get("prophecy")
    local generator = TextGenerator.New(chain, profile)

    -- 用上下文关键词作为种子
    local seed = context.heroName or context.location or nil
    local prophecy = generator:GenerateFromTemplate(template, seed, {
        temperature = 1.3,  -- 高随机性 = 更神秘
    })

    -- 添加装饰
    local header = "—— 古老的预言 ——\n\n"
    local footer = "\n\n—— 卷轴末端模糊不清 ——"

    return header .. prophecy .. footer
end

--- 生成不同等级的预言
---@param rarity string "common"|"rare"|"legendary"
---@return string
function ProphecyScroll.GenerateByRarity(rarity)
    local templateMap = {
        common = "couplet",        -- 普通：两行
        rare = "quatrain_abab",    -- 稀有：四行
        legendary = "prophecy",    -- 传说：五行预言体
    }
    local chain, profile = ProfileStore.Load("mystic_oracle")
    if not chain then return "..." end

    local template = StructureTemplate.Get(templateMap[rarity] or "couplet")
    local generator = TextGenerator.New(chain, profile)
    return generator:GenerateFromTemplate(template, nil, {
        temperature = rarity == "legendary" and 1.5 or 0.9,
    })
end

return ProphecyScroll
```

---

## Recipe 3: 节奏游戏歌词系统

### 场景描述

节奏游戏中根据 BPM 和音乐风格动态生成歌词。

### 实现

```lua
-- scripts/rhythm/LyricsSystem.lua
local LyricsSystem = {}

local ProfileStore = require("scripts.lyric-forge.ProfileStore")
local StructureTemplate = require("scripts.lyric-forge.StructureTemplate")
local TextGenerator = require("scripts.lyric-forge.TextGenerator")

--- 按 BPM 计算每行字符数
---@param bpm number
---@return number charsPerLine
local function BpmToCharsPerLine(bpm)
    -- 低 BPM = 长句，高 BPM = 短句
    if bpm < 80 then return 12
    elseif bpm < 120 then return 9
    elseif bpm < 160 then return 7
    else return 5
    end
end

--- 生成歌词
---@param style string 风格名（对应已训练的模型）
---@param bpm number 每分钟节拍数
---@param verseCount number 段落数
---@return table lyrics { verses = string[], perLineChars = number }
function LyricsSystem.Generate(style, bpm, verseCount)
    local chain, profile = ProfileStore.Load(style)
    if not chain then
        return { verses = { "..." }, perLineChars = 7 }
    end

    local charsPerLine = BpmToCharsPerLine(bpm)
    local template = StructureTemplate.Custom({
        name = "rhythm_" .. bpm,
        stanzas = verseCount or 2,
        linesPerStanza = 4,
        charsPerLine = { charsPerLine, charsPerLine, charsPerLine, charsPerLine },
        rhymeScheme = "AABB",
        separator = "\n\n",
    })

    local generator = TextGenerator.New(chain, profile)
    local fullText = generator:GenerateFromTemplate(template, nil, {
        temperature = 0.7,
    })

    -- 拆分为段落
    local verses = {}
    for verse in fullText:gmatch("[^\n\n]+") do
        verses[#verses + 1] = verse
    end

    return {
        verses = verses,
        perLineChars = charsPerLine,
        bpm = bpm,
        style = style,
    }
end

--- 按时间轴分配歌词行
---@param lyrics table LyricsSystem.Generate 的输出
---@param songDuration number 歌曲时长（秒）
---@return table[] timeline { {time, text}, ... }
function LyricsSystem.CreateTimeline(lyrics, songDuration)
    local allLines = {}
    for _, verse in ipairs(lyrics.verses) do
        for line in verse:gmatch("[^\n]+") do
            allLines[#allLines + 1] = line
        end
    end

    local interval = songDuration / math.max(#allLines, 1)
    local timeline = {}
    for i, line in ipairs(allLines) do
        timeline[i] = {
            time = (i - 1) * interval,
            text = line,
        }
    end
    return timeline
end

return LyricsSystem
```

---

## Recipe 4: 墓碑/纪念碑铭文系统

### 场景描述

开放世界游戏中，墓碑和纪念碑显示程序化生成的铭文。

### 实现

```lua
-- scripts/world/EpitaphSystem.lua
local EpitaphSystem = {}

local ProfileStore = require("scripts.lyric-forge.ProfileStore")
local StructureTemplate = require("scripts.lyric-forge.StructureTemplate")
local TextGenerator = require("scripts.lyric-forge.TextGenerator")

-- 名字种子确保同一墓碑总是生成相同铭文
local epitaphCache = {}

--- 为指定角色生成墓碑铭文
---@param characterName string 角色名
---@param deathCause string|nil 死因
---@return string epitaph
function EpitaphSystem.Generate(characterName, deathCause)
    -- 基于名字的确定性种子
    local cacheKey = characterName .. (deathCause or "")
    if epitaphCache[cacheKey] then
        return epitaphCache[cacheKey]
    end

    -- 设置确定性随机种子
    local seed = 0
    for _, cp in utf8.codes(characterName) do
        seed = seed + cp
    end
    math.randomseed(seed)

    local chain, profile = ProfileStore.Load("epitaph_ancient")
    if not chain then
        local fallback = characterName .. "\n于此长眠"
        epitaphCache[cacheKey] = fallback
        return fallback
    end

    local template = StructureTemplate.Get("epitaph")
    local generator = TextGenerator.New(chain, profile)
    local text = generator:GenerateFromTemplate(template, characterName, {
        temperature = 0.6,
    })

    local epitaph = "◆ " .. characterName .. " 之墓 ◆\n\n" .. text
    epitaphCache[cacheKey] = epitaph

    -- 恢复随机种子
    math.randomseed(os.time())

    return epitaph
end

return EpitaphSystem
```

---

## Recipe 5: NPC 对话风格化系统

### 场景描述

不同 NPC 有不同的说话风格，由 Lyric Forge 驱动。

### 实现

```lua
-- scripts/npc/DialogueStyler.lua
local DialogueStyler = {}

local ProfileStore = require("scripts.lyric-forge.ProfileStore")
local TextGenerator = require("scripts.lyric-forge.TextGenerator")
local StructureTemplate = require("scripts.lyric-forge.StructureTemplate")

--- NPC 风格配置
local NPC_STYLES = {
    pirate = {
        profile = "pirate_speech",
        temperature = 1.0,
        prefix = "嘿！",
        suffix = "，懂了吗？",
    },
    noble = {
        profile = "noble_speech",
        temperature = 0.6,
        prefix = "",
        suffix = "。",
    },
    mystic = {
        profile = "mystic_speech",
        temperature = 1.2,
        prefix = "吾观天象...",
        suffix = "。",
    },
    merchant = {
        profile = "merchant_speech",
        temperature = 0.8,
        prefix = "客官！",
        suffix = "，怎么样？",
    },
}

--- 生成风格化台词
---@param npcStyle string 风格名
---@param topic string|nil 话题
---@param lineCount number|nil 行数
---@return string dialogue
function DialogueStyler.Generate(npcStyle, topic, lineCount)
    local config = NPC_STYLES[npcStyle]
    if not config then
        return "......"
    end

    local chain, profile = ProfileStore.Load(config.profile)
    if not chain then
        return config.prefix .. "（无话可说）" .. config.suffix
    end

    local generator = TextGenerator.New(chain, profile)
    local text = generator:GenerateFreeform(topic, lineCount or 2, {
        temperature = config.temperature,
    })

    return config.prefix .. text .. config.suffix
end

--- 批量为所有 NPC 生成待用台词
---@param npcStyle string
---@param count number
---@return string[]
function DialogueStyler.PreGenerate(npcStyle, count)
    local results = {}
    for i = 1, count do
        results[i] = DialogueStyler.Generate(npcStyle, nil, 1)
    end
    return results
end

return DialogueStyler
```

---

## Recipe 6: 多语料混合风格

### 场景描述

混合多种语料创建独特的融合风格。

### 实现

```lua
-- scripts/lyric-forge/StyleMixer.lua
local StyleMixer = {}

local CorpusLoader = require("scripts.lyric-forge.CorpusLoader")
local MarkovChain = require("scripts.lyric-forge.MarkovChain")
local StyleProfile = require("scripts.lyric-forge.StyleProfile")
local ProfileStore = require("scripts.lyric-forge.ProfileStore")

--- 混合多个语料创建新风格
---@param corpusPaths string[] 语料文件路径数组
---@param weights number[]|nil 各语料权重（默认均等）
---@param outputName string 输出风格名称
function StyleMixer.Mix(corpusPaths, weights, outputName)
    local allLines = {}

    for idx, path in ipairs(corpusPaths) do
        local corpus = CorpusLoader.Load(path)
        if corpus then
            local lines = CorpusLoader.Flatten(corpus)
            local weight = (weights and weights[idx]) or 1
            -- 按权重重复行
            for _ = 1, weight do
                for _, line in ipairs(lines) do
                    allLines[#allLines + 1] = line
                end
            end
        end
    end

    if #allLines == 0 then
        log:Error("[StyleMixer] no lines loaded")
        return
    end

    local profile = StyleProfile.Analyze(allLines)
    local chain = MarkovChain.New(3)
    chain:Train(allLines)

    ProfileStore.Save(outputName, chain, profile)
    log:Info("[StyleMixer] created mixed style: " .. outputName ..
             " from " .. #corpusPaths .. " corpora, " .. #allLines .. " lines")
end

return StyleMixer
```

### 用法

```lua
local StyleMixer = require("scripts.lyric-forge.StyleMixer")

-- 70% 海盗风 + 30% 古风 = "幽灵海盗"
StyleMixer.Mix(
    { "Texts/corpus/pirate.json", "Texts/corpus/ancient.json" },
    { 7, 3 },
    "ghost_pirate"
)
```

---

## 通用工具

### 语料创建辅助

```lua
--- 从游戏内文本快速创建语料
---@param styleName string
---@param texts string[] 文本数组（每条为一行）
function QuickCreateCorpus(styleName, texts)
    local CorpusLoader = require("scripts.lyric-forge.CorpusLoader")
    local MarkovChain = require("scripts.lyric-forge.MarkovChain")
    local StyleProfile = require("scripts.lyric-forge.StyleProfile")
    local ProfileStore = require("scripts.lyric-forge.ProfileStore")

    local profile = StyleProfile.Analyze(texts)
    local chain = MarkovChain.New(3)
    chain:Train(texts)
    ProfileStore.Save(styleName, chain, profile)
end

-- 快速创建海盗风格
QuickCreateCorpus("pirate_quick", {
    "扬帆起航向远方",
    "风暴之中不退让",
    "宝藏深埋在海底",
    "勇者方能得辉煌",
    "大海是我的归宿",
    "星辰指引我航路",
    -- ...更多行
})
```

### 调试输出

```lua
--- 打印模型统计信息
function DebugPrintStats(chain, profile)
    local stats = chain:GetStats()
    log:Info(string.format(
        "[LyricForge] Model: order=%d, ngrams=%d, transitions=%d, starters=%d",
        stats.order, stats.uniqueNgrams,
        stats.totalTransitions, stats.starterCount
    ))
    log:Info(string.format(
        "[LyricForge] Style: avgLen=%.1f, variance=%.1f, lines=%d, punct=%.2f%%",
        profile.avgLineLength, profile.lineLengthVariance,
        profile.totalLines, (profile.punctuationRate or 0) * 100
    ))
end
```
