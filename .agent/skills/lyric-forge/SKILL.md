---
name: lyric-forge
version: "1.0.0"
description: |
  游戏文本风格化生成引擎 for UrhoX Lua。
  基于 Markov Chain + N-gram 统计实现纯 Lua 文本风格学习与生成，
  将 encore.ai（LSTM 歌词生成器）的核心理念——风格模仿、种子驱动、韵律结构——
  适配为游戏内可用的文本生成系统。
  覆盖语料分析、风格建模、约束采样、韵脚匹配、模板拼接，
  用于 NPC 台词、游戏歌词、咒语/诗歌、任务描述等文本内容的风格化批量生成。
  Use when users need to (1) 为游戏角色生成风格化台词或对话,
  (2) 生成游戏内歌词/诗歌/咒语, (3) 模仿特定文本风格批量生成内容,
  (4) 实现节奏游戏的歌词系统, (5) 用种子文本驱动文本生成,
  (6) 构建 NPC 台词库或任务描述库, (7) 用户说"歌词生成""文本生成""风格模仿""lyric forge"。
author: "UrhoX Skill Builder"
source: "https://github.com/dyelax/encore.ai"
tags:
  - text-generation
  - lyrics
  - markov-chain
  - style-transfer
  - npc-dialogue
  - procedural-text
  - game-writing
triggers:
  - 歌词生成
  - 文本生成
  - 台词生成
  - 风格模仿
  - 诗歌生成
  - 咒语生成
  - lyric forge
  - 文本风格
  - NPC 台词
  - 对话生成
  - markov
---

# Lyric Forge — 游戏文本风格化生成引擎

> **灵感来源**: [dyelax/encore.ai](https://github.com/dyelax/encore.ai)
> — LSTM 歌词生成器，学习艺术家风格并生成新歌词。
>
> **UrhoX 适配**: 将深度学习方案替换为纯 Lua Markov Chain + N-gram 统计，
> 在游戏运行时实时生成风格化文本，无需外部 Python/TensorFlow 依赖。

---

## §1 Use When 触发条件

### 触发

| 场景 | 示例 |
|------|------|
| 生成游戏歌词 | 节奏游戏需要原创歌词、酒馆 NPC 唱歌 |
| NPC 台词风格化 | 海盗风格台词、古风角色对话、赛博朋克俚语 |
| 诗歌/咒语/预言 | RPG 中的预言诗、魔法咒语、墓碑铭文 |
| 任务描述生成 | 批量生成风格统一的任务描述文本 |
| 文本风格模仿 | 给定样本文本，生成相同风格的新内容 |
| 种子驱动创作 | 给定关键词/开头，续写完整文本 |

### 不触发

| 场景 | 应使用 |
|------|--------|
| BGM/音频生成 | `@Huiyu-Skill_music-producer` |
| 世界观设定管理 | `world-lore-notebook` |
| NPC 行为 AI | `gaia-npc-ai` / `behavior-tree-ai` |
| 程序化地图/地形 | `procedural-generation` |
| AI 大模型对话 | `@tianyi_llm-server-http` |

### 关键词

`歌词生成` `文本生成` `台词生成` `风格模仿` `诗歌` `咒语` `lyric` `markov` `NPC台词` `对话风格`

---

## §2 概念映射：encore.ai → UrhoX Lua

| encore.ai 原始 | UrhoX 模块 | 设计决策 |
|---|---|---|
| LSTM 神经网络 | **MarkovChain** | 纯 Lua N-gram Markov Chain（无 TensorFlow 依赖） |
| 歌词语料读取 | **CorpusLoader** | JSON 语料库 + File API 加载 |
| 风格学习（词频/押韵/行结构） | **StyleProfile** | 词频统计 + 韵脚分类 + 句长分布 |
| 种子文本驱动 | **SeedGenerator** | Markov 采样 + 种子约束 |
| 押韵模式 | **RhymeEngine** | 拼音/音节尾部匹配 + 韵脚表 |
| 行/节结构 | **StructureTemplate** | 模板系统（诗节/行数/音节数约束） |
| .ckpt 模型存档 | **ProfileStore** | cjson 序列化 JSON + File API |

### 为什么用 Markov Chain 替代 LSTM

| 考量 | LSTM (encore.ai) | Markov Chain (本 Skill) |
|------|---|---|
| 运行时依赖 | TensorFlow + Python | 纯 Lua，零依赖 |
| 内存占用 | 数十 MB 模型权重 | 数 KB 转移矩阵 |
| 训练时间 | 30,000 步 GPU 训练 | 语料扫描即完成 |
| 生成质量 | 高（长程依赖） | 中（局部上下文） |
| 游戏适用性 | 需离线预生成 | 可运行时实时生成 |
| 可控性 | 黑盒 | 可调节参数（阶数、温度、约束） |

**补偿策略**：用模板约束 + 韵脚引擎 + 后处理来弥补 Markov 的局部性限制。

---

## §3 CorpusLoader — 语料加载器

### 语料格式

```json
{
    "name": "pirate",
    "language": "zh",
    "entries": [
        {
            "title": "海盗之歌",
            "lines": [
                "扬帆起航向远方",
                "风暴之中不退让",
                "宝藏深埋在海底",
                "勇者方能得辉煌"
            ]
        },
        {
            "title": "船长誓言",
            "lines": [
                "大海是我的归宿",
                "星辰指引我航路"
            ]
        }
    ]
}
```

### 加载 API

```lua
local CorpusLoader = {}

--- 从 JSON 文件加载语料库
---@param path string 语料文件路径（相对于资源目录）
---@return table corpus 解析后的语料数据
function CorpusLoader.Load(path)
    local cjson = require("cjson")
    local file = File:new(path, FILE_READ)
    if not file:IsOpen() then
        log:Error("CorpusLoader: cannot open " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    local corpus = cjson.decode(content)
    return corpus
end

--- 将语料合并为单一文本流（用于 Markov 训练）
---@param corpus table 语料数据
---@return string[] allLines 所有行的数组
function CorpusLoader.Flatten(corpus)
    local allLines = {}
    for _, entry in ipairs(corpus.entries) do
        for _, line in ipairs(entry.lines) do
            allLines[#allLines + 1] = line
        end
    end
    return allLines
end

return CorpusLoader
```

### 语料存放规范

```
scripts/
  lyric-forge/
    corpus/
      pirate.json         -- 海盗风格语料
      ancient.json         -- 古风语料
      cyberpunk.json       -- 赛博朋克语料
      custom.json          -- 用户自定义语料
```

---

## §4 MarkovChain — Markov 链文本模型

### 核心数据结构

```lua
local MarkovChain = {}
MarkovChain.__index = MarkovChain

--- 创建新的 Markov 链
---@param order number N-gram 阶数（2=bigram, 3=trigram）
---@return table chain
function MarkovChain.New(order)
    local self = setmetatable({}, MarkovChain)
    self.order = order or 2
    self.transitions = {}   -- { [ngram_key] = { [next_word] = count } }
    self.starters = {}       -- 句首 N-gram 列表
    self.totalTokens = 0
    return self
end
```

### 训练（语料分析）

```lua
--- 从文本行数组训练 Markov 链
---@param lines string[] 文本行数组
function MarkovChain:Train(lines)
    for _, line in ipairs(lines) do
        local words = self:_Tokenize(line)
        if #words >= self.order then
            -- 记录句首
            local starterKey = self:_MakeKey(words, 1)
            self.starters[#self.starters + 1] = starterKey

            -- 记录转移
            for i = 1, #words - self.order do
                local key = self:_MakeKey(words, i)
                local nextWord = words[i + self.order]
                if not self.transitions[key] then
                    self.transitions[key] = {}
                end
                local t = self.transitions[key]
                t[nextWord] = (t[nextWord] or 0) + 1
            end
            self.totalTokens = self.totalTokens + #words
        end
    end
end

--- 中文分词（按字符拆分，支持标点）
---@param text string
---@return string[] tokens
function MarkovChain:_Tokenize(text)
    local tokens = {}
    for _, codepoint in utf8.codes(text) do
        tokens[#tokens + 1] = utf8.char(codepoint)
    end
    return tokens
end

--- 构造 N-gram 键
---@param words string[]
---@param startIdx number
---@return string key
function MarkovChain:_MakeKey(words, startIdx)
    local parts = {}
    for i = startIdx, startIdx + self.order - 1 do
        parts[#parts + 1] = words[i]
    end
    return table.concat(parts, "|")
end
```

### 生成（采样）

```lua
--- 从训练好的模型生成文本
---@param seed string|nil 种子文本（可选）
---@param maxLen number 最大生成字符数
---@param temperature number 采样温度 (0.1-2.0, 越高越随机)
---@return string generated
function MarkovChain:Generate(seed, maxLen, temperature)
    maxLen = maxLen or 100
    temperature = temperature or 1.0

    -- 选择起始 N-gram
    local currentKey
    if seed and #seed > 0 then
        local seedTokens = self:_Tokenize(seed)
        if #seedTokens >= self.order then
            currentKey = self:_MakeKey(seedTokens, #seedTokens - self.order + 1)
        end
    end
    if not currentKey or not self.transitions[currentKey] then
        -- 随机选择句首
        if #self.starters == 0 then return "" end
        currentKey = self.starters[math.random(#self.starters)]
    end

    -- 逐字符生成
    local result = {}
    -- 添加初始 N-gram 的字符
    for part in string.gmatch(currentKey, "[^|]+") do
        result[#result + 1] = part
    end

    for _ = 1, maxLen do
        local candidates = self.transitions[currentKey]
        if not candidates then break end

        local nextWord = self:_WeightedSample(candidates, temperature)
        result[#result + 1] = nextWord

        -- 滑动窗口更新 key
        local keyParts = {}
        for part in string.gmatch(currentKey, "[^|]+") do
            keyParts[#keyParts + 1] = part
        end
        table.remove(keyParts, 1)
        keyParts[#keyParts + 1] = nextWord
        currentKey = table.concat(keyParts, "|")
    end

    return table.concat(result)
end

--- 带温度的加权采样
---@param candidates table { [word] = count }
---@param temperature number
---@return string word
function MarkovChain:_WeightedSample(candidates, temperature)
    -- 计算温度调整后的权重
    local entries = {}
    local totalWeight = 0
    for word, count in pairs(candidates) do
        local weight = math.pow(count, 1.0 / temperature)
        entries[#entries + 1] = { word = word, weight = weight }
        totalWeight = totalWeight + weight
    end

    -- 轮盘赌选择
    local roll = math.random() * totalWeight
    local cumulative = 0
    for _, e in ipairs(entries) do
        cumulative = cumulative + e.weight
        if cumulative >= roll then
            return e.word
        end
    end
    return entries[#entries].word
end
```

---

## §5 StyleProfile — 风格档案

### 风格特征提取

```lua
local StyleProfile = {}
StyleProfile.__index = StyleProfile

--- 从语料行分析风格特征
---@param lines string[] 语料行
---@return table profile
function StyleProfile.Analyze(lines)
    local profile = {
        avgLineLength = 0,       -- 平均行长度（字符数）
        lineLengthVariance = 0,  -- 行长度方差
        stanzaSize = 4,          -- 每节行数（默认4行）
        wordFrequency = {},      -- 词频统计 { [word] = count }
        rhymeGroups = {},        -- 韵脚分组 { [rhymeKey] = {word1, word2, ...} }
        punctuationRate = 0,     -- 标点符号频率
        totalLines = #lines,
    }

    local totalLen = 0
    local lengths = {}
    for _, line in ipairs(lines) do
        local len = utf8.len(line)
        totalLen = totalLen + len
        lengths[#lengths + 1] = len

        -- 统计行尾字符（用于韵脚分组）
        local lastChar = StyleProfile._GetLastChar(line)
        if lastChar then
            local rhymeKey = StyleProfile._GetRhymeKey(lastChar)
            if not profile.rhymeGroups[rhymeKey] then
                profile.rhymeGroups[rhymeKey] = {}
            end
            local group = profile.rhymeGroups[rhymeKey]
            group[#group + 1] = lastChar
        end
    end

    profile.avgLineLength = totalLen / math.max(#lines, 1)

    -- 计算方差
    local sumSqDiff = 0
    for _, len in ipairs(lengths) do
        sumSqDiff = sumSqDiff + (len - profile.avgLineLength) ^ 2
    end
    profile.lineLengthVariance = sumSqDiff / math.max(#lines, 1)

    return profile
end

--- 获取字符串最后一个非标点字符
---@param text string
---@return string|nil
function StyleProfile._GetLastChar(text)
    local chars = {}
    for _, cp in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(cp)
    end
    -- 跳过末尾标点
    for i = #chars, 1, -1 do
        local c = chars[i]
        if not string.match(c, "[，。！？、；：""''…—\n\r\t ]") then
            return c
        end
    end
    return nil
end

--- 获取韵脚键（简化：使用字符本身作为键）
--- 生产中可接入拼音库做韵母匹配
---@param char string
---@return string
function StyleProfile._GetRhymeKey(char)
    return char
end

return StyleProfile
```

---

## §6 RhymeEngine — 韵脚引擎

### 韵脚匹配与约束

```lua
local RhymeEngine = {}

--- 内置韵脚分组表（简化版，按中文常见韵母分组）
RhymeEngine.RHYME_GROUPS = {
    -- a 韵
    a  = { "大", "下", "花", "家", "他", "拿", "杀", "发", "达", "沙" },
    -- ang 韵
    ang = { "方", "光", "强", "王", "长", "让", "忘", "望", "乡", "航" },
    -- an 韵
    an = { "天", "间", "前", "年", "边", "眼", "见", "远", "连", "剑" },
    -- i 韵
    i  = { "你", "地", "里", "起", "去", "力", "气", "意", "西", "笔" },
    -- ing 韵
    ing = { "情", "明", "行", "星", "声", "灵", "命", "平", "生", "城" },
    -- u 韵
    u  = { "路", "出", "入", "呼", "虎", "故", "苦", "度", "护", "雾" },
    -- ong 韵
    ong = { "中", "空", "风", "龙", "红", "梦", "同", "功", "动", "痛" },
    -- en 韵
    en = { "人", "门", "真", "深", "分", "文", "心", "神", "魂", "春" },
    -- ou 韵
    ou = { "走", "手", "头", "有", "后", "口", "斗", "流", "秋", "求" },
    -- ai 韵
    ai = { "来", "开", "海", "在", "外", "白", "败", "爱", "带", "快" },
}

--- 判断两个字符是否押韵
---@param char1 string
---@param char2 string
---@return boolean
function RhymeEngine.DoRhyme(char1, char2)
    if char1 == char2 then return true end
    for _, group in pairs(RhymeEngine.RHYME_GROUPS) do
        local has1, has2 = false, false
        for _, c in ipairs(group) do
            if c == char1 then has1 = true end
            if c == char2 then has2 = true end
        end
        if has1 and has2 then return true end
    end
    return false
end

--- 从韵脚组中随机选择一个押韵字
---@param targetChar string 需要押韵的目标字
---@return string|nil rhymingChar
function RhymeEngine.FindRhyme(targetChar)
    for _, group in pairs(RhymeEngine.RHYME_GROUPS) do
        for _, c in ipairs(group) do
            if c == targetChar then
                -- 从同组中随机选一个不同的字
                local candidates = {}
                for _, other in ipairs(group) do
                    if other ~= targetChar then
                        candidates[#candidates + 1] = other
                    end
                end
                if #candidates > 0 then
                    return candidates[math.random(#candidates)]
                end
            end
        end
    end
    return nil
end

return RhymeEngine
```

---

## §7 StructureTemplate — 结构模板

### 预定义文本结构

```lua
local StructureTemplate = {}

--- 模板定义
---@class TextTemplate
---@field name string 模板名称
---@field stanzas number 节数
---@field linesPerStanza number 每节行数
---@field charsPerLine number[] 每行目标字符数
---@field rhymeScheme string 押韵方案（A=相同韵, B=不同韵）
---@field separator string 节间分隔符

--- 内置模板库
StructureTemplate.TEMPLATES = {
    -- 四行诗（AABB 押韵）
    quatrain_aabb = {
        name = "四行诗 (AABB)",
        stanzas = 1,
        linesPerStanza = 4,
        charsPerLine = { 7, 7, 7, 7 },
        rhymeScheme = "AABB",
        separator = "\n",
    },
    -- 四行诗（ABAB 交叉韵）
    quatrain_abab = {
        name = "四行诗 (ABAB)",
        stanzas = 1,
        linesPerStanza = 4,
        charsPerLine = { 7, 7, 7, 7 },
        rhymeScheme = "ABAB",
        separator = "\n",
    },
    -- 歌词段落（主歌 + 副歌）
    song_verse_chorus = {
        name = "歌词 (主歌+副歌)",
        stanzas = 2,
        linesPerStanza = 4,
        charsPerLine = { 10, 10, 10, 10 },
        rhymeScheme = "ABCB",
        separator = "\n\n",
    },
    -- 对联（两行）
    couplet = {
        name = "对联",
        stanzas = 1,
        linesPerStanza = 2,
        charsPerLine = { 7, 7 },
        rhymeScheme = "AA",
        separator = "\n",
    },
    -- 咒语（短句，重复结构）
    incantation = {
        name = "咒语",
        stanzas = 1,
        linesPerStanza = 3,
        charsPerLine = { 5, 5, 7 },
        rhymeScheme = "AAB",
        separator = "\n",
    },
    -- 墓碑铭文（短诗）
    epitaph = {
        name = "墓碑铭文",
        stanzas = 1,
        linesPerStanza = 4,
        charsPerLine = { 6, 6, 8, 6 },
        rhymeScheme = "ABCB",
        separator = "\n",
    },
    -- 酒馆歌谣（长节，叙事体）
    tavern_ballad = {
        name = "酒馆歌谣",
        stanzas = 3,
        linesPerStanza = 4,
        charsPerLine = { 9, 9, 9, 9 },
        rhymeScheme = "ABCB",
        separator = "\n\n",
    },
    -- 预言诗（神秘、不规则）
    prophecy = {
        name = "预言诗",
        stanzas = 1,
        linesPerStanza = 5,
        charsPerLine = { 12, 8, 10, 8, 14 },
        rhymeScheme = "ABCDB",
        separator = "\n",
    },
    -- 自由体（无韵律约束）
    free_verse = {
        name = "自由体",
        stanzas = 1,
        linesPerStanza = 6,
        charsPerLine = { 0, 0, 0, 0, 0, 0 },  -- 0=不约束长度
        rhymeScheme = "XXXXXX",                 -- X=不约束韵脚
        separator = "\n",
    },
}

--- 获取模板
---@param templateName string
---@return TextTemplate|nil
function StructureTemplate.Get(templateName)
    return StructureTemplate.TEMPLATES[templateName]
end

--- 列出所有模板名称
---@return string[]
function StructureTemplate.List()
    local names = {}
    for k, v in pairs(StructureTemplate.TEMPLATES) do
        names[#names + 1] = k .. " (" .. v.name .. ")"
    end
    table.sort(names)
    return names
end

return StructureTemplate
```

---

## §8 TextGenerator — 文本生成器（核心引擎）

### 完整生成管线

```lua
local TextGenerator = {}
TextGenerator.__index = TextGenerator

--- 创建文本生成器
---@param chain table MarkovChain 实例
---@param profile table StyleProfile 分析结果
---@return table generator
function TextGenerator.New(chain, profile)
    local self = setmetatable({}, TextGenerator)
    self.chain = chain
    self.profile = profile
    return self
end

--- 按模板生成完整文本
---@param template table StructureTemplate 模板
---@param seed string|nil 种子文本
---@param opts table|nil 选项 { temperature, maxRetries }
---@return string text 生成的完整文本
function TextGenerator:GenerateFromTemplate(template, seed, opts)
    opts = opts or {}
    local temperature = opts.temperature or 1.0
    local maxRetries = opts.maxRetries or 5

    local stanzas = {}

    for s = 1, template.stanzas do
        local lines = {}
        local rhymeTargets = {}  -- 记录每个韵脚字母对应的行尾字符

        for l = 1, template.linesPerStanza do
            local targetLen = template.charsPerLine[l]
            if targetLen == 0 then
                targetLen = math.floor(self.profile.avgLineLength + 0.5)
            end

            local line = nil
            for attempt = 1, maxRetries do
                local raw = self.chain:Generate(seed, targetLen + 10, temperature)
                line = self:_TrimToLength(raw, targetLen)

                -- 检查韵脚约束
                local schemeIdx = ((s - 1) * template.linesPerStanza + l)
                local rhymeLetter = template.rhymeScheme:sub(
                    ((l - 1) % #template.rhymeScheme) + 1,
                    ((l - 1) % #template.rhymeScheme) + 1
                )

                if rhymeLetter ~= "X" then
                    local lineEnd = self:_GetLastMeaningfulChar(line)
                    if rhymeTargets[rhymeLetter] then
                        -- 需要与之前的行押韵
                        local RhymeEngine = require("scripts.lyric-forge.RhymeEngine")
                        if RhymeEngine.DoRhyme(lineEnd, rhymeTargets[rhymeLetter]) then
                            break -- 押韵成功
                        end
                        -- 重试
                    else
                        rhymeTargets[rhymeLetter] = lineEnd
                        break -- 第一次出现该韵，直接通过
                    end
                else
                    break -- 无韵脚约束
                end

                if attempt == maxRetries then
                    -- 最终兜底：接受当前行
                    break
                end
            end

            lines[#lines + 1] = line or ""
            -- 清除种子，后续行用自然延续
            seed = nil
        end

        stanzas[#stanzas + 1] = table.concat(lines, "\n")
    end

    return table.concat(stanzas, template.separator)
end

--- 裁剪文本到目标长度（在标点或词边界处截断）
---@param text string
---@param targetLen number
---@return string
function TextGenerator:_TrimToLength(text, targetLen)
    local chars = {}
    for _, cp in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(cp)
        if #chars >= targetLen then break end
    end
    return table.concat(chars)
end

--- 获取最后一个有意义的字符
---@param text string
---@return string
function TextGenerator:_GetLastMeaningfulChar(text)
    local chars = {}
    for _, cp in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(cp)
    end
    for i = #chars, 1, -1 do
        local c = chars[i]
        if not string.match(c, "[，。！？、；：""''…—\n\r\t ]") then
            return c
        end
    end
    return chars[#chars] or ""
end

return TextGenerator
```

---

## §9 ProfileStore — 风格存档

### 持久化（使用 File API，不使用被沙箱移除的库）

```lua
local ProfileStore = {}

--- 保存训练好的 Markov 模型和风格档案
---@param name string 存档名称
---@param chain table MarkovChain 实例
---@param profile table StyleProfile 实例
function ProfileStore.Save(name, chain, profile)
    local cjson = require("cjson")
    local data = {
        version = 1,
        name = name,
        order = chain.order,
        transitions = chain.transitions,
        starters = chain.starters,
        totalTokens = chain.totalTokens,
        profile = {
            avgLineLength = profile.avgLineLength,
            lineLengthVariance = profile.lineLengthVariance,
            stanzaSize = profile.stanzaSize,
            totalLines = profile.totalLines,
            punctuationRate = profile.punctuationRate,
        },
    }

    local jsonStr = cjson.encode(data)
    local filePath = "lyric-forge-profiles/" .. name .. ".json"
    local file = File:new(filePath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
        log:Info("ProfileStore: saved profile '" .. name .. "'")
    else
        log:Error("ProfileStore: cannot write " .. filePath)
    end
end

--- 加载已保存的模型
---@param name string 存档名称
---@return table|nil chain, table|nil profile
function ProfileStore.Load(name)
    local cjson = require("cjson")
    local filePath = "lyric-forge-profiles/" .. name .. ".json"
    local file = File:new(filePath, FILE_READ)
    if not file:IsOpen() then
        log:Warning("ProfileStore: profile '" .. name .. "' not found")
        return nil, nil
    end

    local jsonStr = file:ReadString()
    file:Close()

    local data = cjson.decode(jsonStr)

    -- 重建 MarkovChain
    local MarkovChain = require("scripts.lyric-forge.MarkovChain")
    local chain = MarkovChain.New(data.order)
    chain.transitions = data.transitions
    chain.starters = data.starters
    chain.totalTokens = data.totalTokens

    return chain, data.profile
end

return ProfileStore
```

---

## §10 完整集成示例

### main.lua — 游戏内歌词生成系统

```lua
-- scripts/main.lua
-- Lyric Forge 完整集成示例

require "LuaScripts/Utilities/Sample"

-- 模块引用
local CorpusLoader   -- 语料加载
local MarkovChain    -- Markov 链
local StyleProfile   -- 风格分析
local RhymeEngine    -- 韵脚引擎
local StructureTemplate  -- 结构模板
local TextGenerator  -- 文本生成器
local ProfileStore   -- 存档管理

---@type Scene
local scene_ = nil
---@type NVGcontext
local vg = nil
local fontNormal = -1

-- 生成结果
local generatedText = ""
local currentStyle = "pirate"
local currentTemplate = "tavern_ballad"

function Start()
    SampleStart()

    -- 初始化场景（最小化 3D 场景）
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    local cameraNode = scene_:CreateChild("Camera")
    local camera = cameraNode:CreateComponent("Camera")
    camera.farClip = 100.0
    renderer:SetViewport(0, Viewport:new(scene_, camera))

    -- 初始化 NanoVG
    vg = nvgCreate(0)
    fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")

    -- 加载模块
    CorpusLoader = require("scripts.lyric-forge.CorpusLoader")
    MarkovChain = require("scripts.lyric-forge.MarkovChain")
    StyleProfile = require("scripts.lyric-forge.StyleProfile")
    RhymeEngine = require("scripts.lyric-forge.RhymeEngine")
    StructureTemplate = require("scripts.lyric-forge.StructureTemplate")
    TextGenerator = require("scripts.lyric-forge.TextGenerator")
    ProfileStore = require("scripts.lyric-forge.ProfileStore")

    -- 训练并生成
    TrainAndGenerate()

    -- 注册渲染事件
    SubscribeToEvent("NanoVGRender", "HandleNanoVGRender")

    log:Info("Lyric Forge initialized")
end

function TrainAndGenerate()
    -- 1. 加载语料
    local corpus = CorpusLoader.Load("Texts/corpus/" .. currentStyle .. ".json")
    if not corpus then
        generatedText = "[错误] 无法加载语料: " .. currentStyle
        return
    end

    -- 2. 展平语料
    local lines = CorpusLoader.Flatten(corpus)

    -- 3. 分析风格
    local profile = StyleProfile.Analyze(lines)

    -- 4. 训练 Markov 链
    local chain = MarkovChain.New(3)  -- trigram
    chain:Train(lines)

    -- 5. 保存模型
    ProfileStore.Save(currentStyle, chain, profile)

    -- 6. 获取模板
    local template = StructureTemplate.Get(currentTemplate)

    -- 7. 生成文本
    local generator = TextGenerator.New(chain, profile)
    generatedText = generator:GenerateFromTemplate(template, nil, {
        temperature = 0.8,
    })

    log:Info("Generated text:\n" .. generatedText)
end

---@param eventType string
---@param eventData NanoVGRenderEventData
function HandleNanoVGRender(eventType, eventData)
    local w = graphics:GetWidth() / graphics:GetDPR()
    local h = graphics:GetHeight() / graphics:GetDPR()

    nvgBeginFrame(vg, w, h, graphics:GetDPR())

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 28)
    nvgFillColor(vg, nvgRGBA(255, 220, 100, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgText(vg, w * 0.5, 30, "Lyric Forge - " .. currentStyle)

    -- 生成的文本
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(230, 230, 230, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

    local y = 80
    for line in generatedText:gmatch("[^\n]+") do
        nvgText(vg, w * 0.5, y, line)
        y = y + 30
    end

    -- 操作提示
    nvgFontSize(vg, 16)
    nvgFillColor(vg, nvgRGBA(150, 150, 150, 255))
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgText(vg, w * 0.5, h - 20, "[Space] 重新生成  |  [1-3] 切换模板")

    nvgEndFrame(vg)
end

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    if input:GetKeyPress(KEY_SPACE) then
        TrainAndGenerate()
    end
    if input:GetKeyPress(KEY_1) then
        currentTemplate = "quatrain_aabb"
        TrainAndGenerate()
    end
    if input:GetKeyPress(KEY_2) then
        currentTemplate = "tavern_ballad"
        TrainAndGenerate()
    end
    if input:GetKeyPress(KEY_3) then
        currentTemplate = "prophecy"
        TrainAndGenerate()
    end
end

function Stop()
    if vg then nvgDelete(vg) end
end
```

构建并运行：使用 UrhoX MCP build 工具构建项目。

---

## §11 批量生成 API

### 批量生成多条文本

```lua
--- 批量生成指定数量的文本
---@param chain table MarkovChain 实例
---@param profile table StyleProfile 实例
---@param template table StructureTemplate 模板
---@param count number 生成数量
---@param opts table|nil 选项
---@return string[] results
function BatchGenerate(chain, profile, template, count, opts)
    local generator = TextGenerator.New(chain, profile)
    local results = {}
    for i = 1, count do
        results[i] = generator:GenerateFromTemplate(template, nil, opts)
    end
    return results
end

--- 批量生成并保存到 JSON 文件
---@param results string[] 生成的文本数组
---@param outputPath string 输出路径
function SaveBatchResults(results, outputPath)
    local cjson = require("cjson")
    local data = {
        generated_at = os.time(),
        count = #results,
        texts = results,
    }
    local file = File:new(outputPath, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(data))
        file:Close()
    end
end
```

---

## §12 游戏应用场景

### 场景 1: 酒馆 NPC 唱歌

```lua
-- NPC 说话时调用
function OnTavernBardSpeak()
    local chain, profile = ProfileStore.Load("tavern_bard")
    if chain then
        local template = StructureTemplate.Get("tavern_ballad")
        local generator = TextGenerator.New(chain, profile)
        local song = generator:GenerateFromTemplate(template, nil, {
            temperature = 0.9,
        })
        ShowDialogue("吟游诗人", song)
    end
end
```

### 场景 2: RPG 预言/卷轴

```lua
function GenerateProphecy(seedWord)
    local chain, profile = ProfileStore.Load("mystic")
    if chain then
        local template = StructureTemplate.Get("prophecy")
        local generator = TextGenerator.New(chain, profile)
        return generator:GenerateFromTemplate(template, seedWord, {
            temperature = 1.2,  -- 更高随机性 = 更神秘
        })
    end
    return "预言模糊不清..."
end
```

### 场景 3: 节奏游戏歌词

```lua
function GenerateGameLyrics(style, bpm)
    local chain, profile = ProfileStore.Load(style)
    if chain then
        -- 根据 BPM 调整行长度
        local charsPerBeat = math.floor(bpm / 30)
        local template = {
            name = "dynamic",
            stanzas = 2,
            linesPerStanza = 4,
            charsPerLine = { charsPerBeat, charsPerBeat, charsPerBeat, charsPerBeat },
            rhymeScheme = "ABCB",
            separator = "\n\n",
        }
        local generator = TextGenerator.New(chain, profile)
        return generator:GenerateFromTemplate(template, nil, {
            temperature = 0.7,
        })
    end
end
```

### 场景 4: 墓碑铭文

```lua
function GenerateEpitaph(heroName)
    local chain, profile = ProfileStore.Load("ancient")
    if chain then
        local template = StructureTemplate.Get("epitaph")
        local generator = TextGenerator.New(chain, profile)
        return heroName .. "之墓\n\n" ..
               generator:GenerateFromTemplate(template, heroName, {
                   temperature = 0.6,
               })
    end
end
```

---

## §13 规则与约束

### 引擎规则遵循

| 规则 | 遵循方式 |
|------|---------|
| 代码放 `scripts/` | 所有模块放 `scripts/lyric-forge/` |
| File API 持久化 | ProfileStore 使用 `File:new()` + cjson |
| NanoVGRender 事件 | 渲染在 NanoVGRender 回调中 |
| 字体先创建 | `nvgCreateFont()` 在 `Start()` 中调用一次 |
| 枚举值不猜测 | 使用 `KEY_SPACE` 等枚举 |
| 数组从 1 开始 | 所有循环 `for i = 1, n` |
| 分辨率模式 B | `graphics:GetWidth()/GetDPR()` 获取逻辑尺寸 |
| 构建后预览 | 使用 UrhoX MCP build 工具 |

### 性能预算

| 操作 | 预算 |
|------|------|
| 语料训练（1000 行） | < 100ms（一次性） |
| 单次文本生成 | < 10ms |
| 批量生成 100 条 | < 1s |
| 模型 JSON 大小 | < 500KB |

### 语料库建议

| 规模 | 行数 | 效果 |
|------|------|------|
| 最小 | 50+ 行 | 基本可用，重复率高 |
| 推荐 | 200-500 行 | 较好多样性 |
| 理想 | 1000+ 行 | 优质输出 |

---

## §14 FAQ

### Q1: 与引擎原生 Scene/Node 系统有什么关系？

Lyric Forge 是纯 Lua 文本处理系统，不涉及场景图。它生成的文本可以通过 NanoVG 或 UI 组件显示在任何游戏中。

### Q2: 支持英文吗？

支持。MarkovChain 的分词对英文改用空格分词即可（检测语料的 `language` 字段）。韵脚引擎需要对应的英文韵脚表。

### Q3: 如何提高生成质量？

1. 增大语料量（500+ 行）
2. 提高 Markov 阶数（3-4）
3. 降低温度（0.6-0.8）获得更连贯的文本
4. 使用模板约束行长和韵脚

### Q4: 能用于多人游戏吗？

可以。在服务端训练并生成，通过网络同步结果文本到客户端显示。ProfileStore 的 JSON 格式便于服务端操作。

### Q5: 与 procedural-generation Skill 的 Markov 部分有何区别？

procedural-generation 的 Markov 用于**名称/物品描述**生成（短文本、无韵律）。Lyric Forge 专注于**歌词/诗歌**（多行结构、押韵约束、风格档案、模板系统）。两者互补。

### Q6: 如何自定义韵脚表？

扩展 `RhymeEngine.RHYME_GROUPS` 表即可。生产环境推荐接入拼音库（如 pinyin.lua）做韵母级别的精确匹配。

---

## §15 References

- `references/markov-algorithms.md` — Markov Chain 算法详解与优化
- `references/lua-text-modules.md` — 全部 Lua 模块完整实现
- `references/game-recipes.md` — 游戏场景实战方案
