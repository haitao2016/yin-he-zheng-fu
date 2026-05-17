# Lyric Forge — 完整 Lua 模块实现

> 所有模块的独立可运行 Lua 代码。

---

## 1. CorpusLoader 模块

```lua
-- scripts/lyric-forge/CorpusLoader.lua
local CorpusLoader = {}

--- 从 JSON 文件加载语料库
---@param path string 语料文件路径
---@return table|nil corpus
function CorpusLoader.Load(path)
    local cjson = require("cjson")
    local file = File:new(path, FILE_READ)
    if not file:IsOpen() then
        log:Error("[CorpusLoader] cannot open: " .. path)
        return nil
    end
    local content = file:ReadString()
    file:Close()
    local ok, corpus = pcall(cjson.decode, content)
    if not ok then
        log:Error("[CorpusLoader] JSON parse error: " .. tostring(corpus))
        return nil
    end
    return corpus
end

--- 将语料合并为行数组
---@param corpus table
---@return string[]
function CorpusLoader.Flatten(corpus)
    local allLines = {}
    if corpus.entries then
        for _, entry in ipairs(corpus.entries) do
            if entry.lines then
                for _, line in ipairs(entry.lines) do
                    allLines[#allLines + 1] = line
                end
            end
        end
    end
    return allLines
end

--- 合并多个语料库
---@param paths string[] 语料文件路径数组
---@return string[] allLines
function CorpusLoader.LoadAndMerge(paths)
    local allLines = {}
    for _, path in ipairs(paths) do
        local corpus = CorpusLoader.Load(path)
        if corpus then
            local lines = CorpusLoader.Flatten(corpus)
            for _, line in ipairs(lines) do
                allLines[#allLines + 1] = line
            end
        end
    end
    return allLines
end

--- 创建空语料模板
---@param name string 语料名称
---@param language string 语言代码 "zh"|"en"
---@return table corpus
function CorpusLoader.CreateTemplate(name, language)
    return {
        name = name,
        language = language or "zh",
        entries = {},
    }
end

--- 向语料添加条目
---@param corpus table
---@param title string
---@param lines string[]
function CorpusLoader.AddEntry(corpus, title, lines)
    corpus.entries[#corpus.entries + 1] = {
        title = title,
        lines = lines,
    }
end

--- 保存语料到文件
---@param corpus table
---@param path string
function CorpusLoader.Save(corpus, path)
    local cjson = require("cjson")
    local file = File:new(path, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(corpus))
        file:Close()
    end
end

return CorpusLoader
```

---

## 2. MarkovChain 模块

```lua
-- scripts/lyric-forge/MarkovChain.lua
local MarkovChain = {}
MarkovChain.__index = MarkovChain

--- 创建新的 Markov 链
---@param order number N-gram 阶数
---@return table
function MarkovChain.New(order)
    local self = setmetatable({}, MarkovChain)
    self.order = order or 3
    self.transitions = {}
    self.starters = {}
    self.totalTokens = 0
    return self
end

--- 中文/通用分词
---@param text string
---@return string[]
function MarkovChain:_Tokenize(text)
    local tokens = {}
    for _, cp in utf8.codes(text) do
        tokens[#tokens + 1] = utf8.char(cp)
    end
    return tokens
end

--- 构建 N-gram 键
---@param words string[]
---@param start number
---@return string
function MarkovChain:_MakeKey(words, start)
    local parts = {}
    for i = start, start + self.order - 1 do
        parts[#parts + 1] = words[i]
    end
    return table.concat(parts, "|")
end

--- 从行数组训练
---@param lines string[]
function MarkovChain:Train(lines)
    for _, line in ipairs(lines) do
        local words = self:_Tokenize(line)
        if #words >= self.order then
            local starterKey = self:_MakeKey(words, 1)
            self.starters[#self.starters + 1] = starterKey

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

--- 带温度的加权采样
---@param candidates table
---@param temperature number
---@return string
function MarkovChain:_WeightedSample(candidates, temperature)
    local entries = {}
    local totalWeight = 0
    for word, count in pairs(candidates) do
        local weight = math.pow(count, 1.0 / temperature)
        entries[#entries + 1] = { word = word, weight = weight }
        totalWeight = totalWeight + weight
    end

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

--- 生成文本
---@param seed string|nil
---@param maxLen number
---@param temperature number
---@return string
function MarkovChain:Generate(seed, maxLen, temperature)
    maxLen = maxLen or 100
    temperature = temperature or 1.0

    local currentKey
    if seed and #seed > 0 then
        local seedTokens = self:_Tokenize(seed)
        if #seedTokens >= self.order then
            currentKey = self:_MakeKey(seedTokens, #seedTokens - self.order + 1)
        end
    end
    if not currentKey or not self.transitions[currentKey] then
        if #self.starters == 0 then return "" end
        currentKey = self.starters[math.random(#self.starters)]
    end

    local result = {}
    for part in string.gmatch(currentKey, "[^|]+") do
        result[#result + 1] = part
    end

    for _ = 1, maxLen do
        local candidates = self.transitions[currentKey]
        if not candidates then break end

        local nextWord = self:_WeightedSample(candidates, temperature)
        result[#result + 1] = nextWord

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

--- 获取模型统计信息
---@return table stats
function MarkovChain:GetStats()
    local uniqueNgrams = 0
    local totalTransitions = 0
    for _, nexts in pairs(self.transitions) do
        uniqueNgrams = uniqueNgrams + 1
        for _, count in pairs(nexts) do
            totalTransitions = totalTransitions + count
        end
    end
    return {
        order = self.order,
        uniqueNgrams = uniqueNgrams,
        totalTransitions = totalTransitions,
        starterCount = #self.starters,
        totalTokens = self.totalTokens,
    }
end

return MarkovChain
```

---

## 3. StyleProfile 模块

```lua
-- scripts/lyric-forge/StyleProfile.lua
local StyleProfile = {}
StyleProfile.__index = StyleProfile

--- 从语料行分析风格
---@param lines string[]
---@return table profile
function StyleProfile.Analyze(lines)
    local profile = {
        avgLineLength = 0,
        lineLengthVariance = 0,
        stanzaSize = 4,
        wordFrequency = {},
        totalLines = #lines,
        punctuationRate = 0,
        charCount = 0,
        punctCount = 0,
    }

    local totalLen = 0
    local lengths = {}

    for _, line in ipairs(lines) do
        local len = utf8.len(line) or 0
        totalLen = totalLen + len
        lengths[#lengths + 1] = len

        for _, cp in utf8.codes(line) do
            local c = utf8.char(cp)
            profile.charCount = profile.charCount + 1
            if string.match(c, "[，。！？、；：""''…—]") then
                profile.punctCount = profile.punctCount + 1
            end
            profile.wordFrequency[c] = (profile.wordFrequency[c] or 0) + 1
        end
    end

    profile.avgLineLength = totalLen / math.max(#lines, 1)
    profile.punctuationRate = profile.punctCount / math.max(profile.charCount, 1)

    local sumSqDiff = 0
    for _, len in ipairs(lengths) do
        sumSqDiff = sumSqDiff + (len - profile.avgLineLength) ^ 2
    end
    profile.lineLengthVariance = sumSqDiff / math.max(#lines, 1)

    return profile
end

--- 获取 Top-N 高频字
---@param profile table
---@param n number
---@return table[] {char, count}
function StyleProfile.TopChars(profile, n)
    local sorted = {}
    for char, count in pairs(profile.wordFrequency) do
        if not string.match(char, "[，。！？、；：""''…—\n\r\t ]") then
            sorted[#sorted + 1] = { char = char, count = count }
        end
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    local top = {}
    for i = 1, math.min(n, #sorted) do
        top[i] = sorted[i]
    end
    return top
end

return StyleProfile
```

---

## 4. RhymeEngine 模块

```lua
-- scripts/lyric-forge/RhymeEngine.lua
local RhymeEngine = {}

RhymeEngine.RHYME_GROUPS = {
    a   = { "大", "下", "花", "家", "他", "拿", "杀", "发", "达", "沙", "话", "画", "夏", "马", "怕" },
    ang = { "方", "光", "强", "王", "长", "让", "忘", "望", "乡", "航", "狂", "霜", "苍", "茫", "浪" },
    an  = { "天", "间", "前", "年", "边", "眼", "见", "远", "连", "剑", "关", "山", "船", "烟", "弦" },
    i   = { "你", "地", "里", "起", "去", "力", "气", "意", "西", "笔", "极", "一", "期", "奇", "迹" },
    ing = { "情", "明", "行", "星", "声", "灵", "命", "平", "生", "城", "经", "青", "冰", "精", "影" },
    u   = { "路", "出", "入", "呼", "虎", "故", "苦", "度", "护", "雾", "步", "舞", "木", "处", "顾" },
    ong = { "中", "空", "风", "龙", "红", "梦", "同", "功", "动", "痛", "英", "勇", "通", "鸿", "终" },
    en  = { "人", "门", "真", "深", "分", "文", "心", "神", "魂", "春", "根", "恨", "尘", "痕", "存" },
    ou  = { "走", "手", "头", "有", "后", "口", "斗", "流", "秋", "求", "守", "收", "愁", "酒", "久" },
    ai  = { "来", "开", "海", "在", "外", "白", "败", "爱", "带", "快", "台", "彩", "怀", "猜", "材" },
    ao  = { "高", "少", "好", "要", "到", "早", "老", "找", "宝", "刀", "遥", "笑", "傲", "跑", "号" },
    ei  = { "飞", "回", "追", "泪", "水", "美", "雷", "谁", "醉", "北", "辉", "归", "悲", "灰", "碎" },
    ue  = { "月", "雪", "夜", "别", "铁", "血", "绝", "灭", "切", "叶", "谢", "街", "界", "结", "节" },
}

--- 查找字符所属韵组
---@param char string
---@return string|nil groupKey
function RhymeEngine.FindGroup(char)
    for key, group in pairs(RhymeEngine.RHYME_GROUPS) do
        for _, c in ipairs(group) do
            if c == char then return key end
        end
    end
    return nil
end

--- 判断两个字符是否押韵
---@param char1 string
---@param char2 string
---@return boolean
function RhymeEngine.DoRhyme(char1, char2)
    if char1 == char2 then return true end
    local g1 = RhymeEngine.FindGroup(char1)
    local g2 = RhymeEngine.FindGroup(char2)
    if g1 and g2 and g1 == g2 then return true end
    return false
end

--- 从韵组中随机选择一个押韵字
---@param targetChar string
---@return string|nil
function RhymeEngine.FindRhyme(targetChar)
    local groupKey = RhymeEngine.FindGroup(targetChar)
    if not groupKey then return nil end
    local group = RhymeEngine.RHYME_GROUPS[groupKey]
    local candidates = {}
    for _, c in ipairs(group) do
        if c ~= targetChar then
            candidates[#candidates + 1] = c
        end
    end
    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    end
    return nil
end

--- 获取所有与目标押韵的字符
---@param targetChar string
---@return string[]
function RhymeEngine.FindAllRhymes(targetChar)
    local groupKey = RhymeEngine.FindGroup(targetChar)
    if not groupKey then return {} end
    local group = RhymeEngine.RHYME_GROUPS[groupKey]
    local results = {}
    for _, c in ipairs(group) do
        if c ~= targetChar then
            results[#results + 1] = c
        end
    end
    return results
end

return RhymeEngine
```

---

## 5. StructureTemplate 模块

```lua
-- scripts/lyric-forge/StructureTemplate.lua
local StructureTemplate = {}

StructureTemplate.TEMPLATES = {
    quatrain_aabb = {
        name = "四行诗 (AABB)",
        stanzas = 1, linesPerStanza = 4,
        charsPerLine = { 7, 7, 7, 7 },
        rhymeScheme = "AABB", separator = "\n",
    },
    quatrain_abab = {
        name = "四行诗 (ABAB)",
        stanzas = 1, linesPerStanza = 4,
        charsPerLine = { 7, 7, 7, 7 },
        rhymeScheme = "ABAB", separator = "\n",
    },
    song_verse_chorus = {
        name = "歌词 (主歌+副歌)",
        stanzas = 2, linesPerStanza = 4,
        charsPerLine = { 10, 10, 10, 10 },
        rhymeScheme = "ABCB", separator = "\n\n",
    },
    couplet = {
        name = "对联",
        stanzas = 1, linesPerStanza = 2,
        charsPerLine = { 7, 7 },
        rhymeScheme = "AA", separator = "\n",
    },
    incantation = {
        name = "咒语",
        stanzas = 1, linesPerStanza = 3,
        charsPerLine = { 5, 5, 7 },
        rhymeScheme = "AAB", separator = "\n",
    },
    epitaph = {
        name = "墓碑铭文",
        stanzas = 1, linesPerStanza = 4,
        charsPerLine = { 6, 6, 8, 6 },
        rhymeScheme = "ABCB", separator = "\n",
    },
    tavern_ballad = {
        name = "酒馆歌谣",
        stanzas = 3, linesPerStanza = 4,
        charsPerLine = { 9, 9, 9, 9 },
        rhymeScheme = "ABCB", separator = "\n\n",
    },
    prophecy = {
        name = "预言诗",
        stanzas = 1, linesPerStanza = 5,
        charsPerLine = { 12, 8, 10, 8, 14 },
        rhymeScheme = "ABCDB", separator = "\n",
    },
    haiku = {
        name = "俳句",
        stanzas = 1, linesPerStanza = 3,
        charsPerLine = { 5, 7, 5 },
        rhymeScheme = "XXX", separator = "\n",
    },
    free_verse = {
        name = "自由体",
        stanzas = 1, linesPerStanza = 6,
        charsPerLine = { 0, 0, 0, 0, 0, 0 },
        rhymeScheme = "XXXXXX", separator = "\n",
    },
}

---@param name string
---@return table|nil
function StructureTemplate.Get(name)
    return StructureTemplate.TEMPLATES[name]
end

---@return string[]
function StructureTemplate.List()
    local names = {}
    for k, v in pairs(StructureTemplate.TEMPLATES) do
        names[#names + 1] = k .. " - " .. v.name
    end
    table.sort(names)
    return names
end

--- 创建自定义模板
---@param config table
---@return table
function StructureTemplate.Custom(config)
    return {
        name = config.name or "custom",
        stanzas = config.stanzas or 1,
        linesPerStanza = config.linesPerStanza or 4,
        charsPerLine = config.charsPerLine or { 7, 7, 7, 7 },
        rhymeScheme = config.rhymeScheme or "ABCB",
        separator = config.separator or "\n",
    }
end

return StructureTemplate
```

---

## 6. TextGenerator 模块

```lua
-- scripts/lyric-forge/TextGenerator.lua
local TextGenerator = {}
TextGenerator.__index = TextGenerator

---@param chain table MarkovChain
---@param profile table StyleProfile
---@return table
function TextGenerator.New(chain, profile)
    local self = setmetatable({}, TextGenerator)
    self.chain = chain
    self.profile = profile
    return self
end

--- 按模板生成完整文本
---@param template table
---@param seed string|nil
---@param opts table|nil
---@return string
function TextGenerator:GenerateFromTemplate(template, seed, opts)
    opts = opts or {}
    local temperature = opts.temperature or 1.0
    local maxRetries = opts.maxRetries or 5

    local stanzas = {}
    for s = 1, template.stanzas do
        local lines = {}
        local rhymeTargets = {}

        for l = 1, template.linesPerStanza do
            local targetLen = template.charsPerLine[l]
            if targetLen == 0 then
                targetLen = math.floor(self.profile.avgLineLength + 0.5)
            end

            local bestLine = nil
            for attempt = 1, maxRetries do
                local raw = self.chain:Generate(seed, targetLen + 10, temperature)
                local line = self:_TrimToLength(raw, targetLen)

                local rhymeLetter = template.rhymeScheme:sub(
                    ((l - 1) % #template.rhymeScheme) + 1,
                    ((l - 1) % #template.rhymeScheme) + 1
                )

                if rhymeLetter == "X" then
                    bestLine = line
                    break
                end

                local lineEnd = self:_GetLastMeaningfulChar(line)
                if not rhymeTargets[rhymeLetter] then
                    rhymeTargets[rhymeLetter] = lineEnd
                    bestLine = line
                    break
                else
                    local RhymeEngine = require("scripts.lyric-forge.RhymeEngine")
                    if RhymeEngine.DoRhyme(lineEnd, rhymeTargets[rhymeLetter]) then
                        bestLine = line
                        break
                    end
                end

                bestLine = line
            end

            lines[#lines + 1] = bestLine or ""
            seed = nil
        end

        stanzas[#stanzas + 1] = table.concat(lines, "\n")
    end

    return table.concat(stanzas, template.separator)
end

--- 简单生成（无模板约束）
---@param seed string|nil
---@param lineCount number
---@param opts table|nil
---@return string
function TextGenerator:GenerateFreeform(seed, lineCount, opts)
    opts = opts or {}
    local temperature = opts.temperature or 1.0
    local lines = {}

    for i = 1, lineCount do
        local targetLen = math.floor(self.profile.avgLineLength + 0.5)
        local raw = self.chain:Generate(seed, targetLen + 10, temperature)
        lines[i] = self:_TrimToLength(raw, targetLen)
        seed = nil
    end

    return table.concat(lines, "\n")
end

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

---@param text string
---@return string
function TextGenerator:_GetLastMeaningfulChar(text)
    local chars = {}
    for _, cp in utf8.codes(text) do
        chars[#chars + 1] = utf8.char(cp)
    end
    for i = #chars, 1, -1 do
        if not string.match(chars[i], "[，。！？、；：""''…—\n\r\t ]") then
            return chars[i]
        end
    end
    return chars[#chars] or ""
end

return TextGenerator
```

---

## 7. ProfileStore 模块

```lua
-- scripts/lyric-forge/ProfileStore.lua
local ProfileStore = {}

--- 保存模型和风格
---@param name string
---@param chain table
---@param profile table
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
    local path = "lyric-forge-profiles/" .. name .. ".json"
    local file = File:new(path, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(jsonStr)
        file:Close()
        log:Info("[ProfileStore] saved: " .. name)
    else
        log:Error("[ProfileStore] write failed: " .. path)
    end
end

--- 加载模型和风格
---@param name string
---@return table|nil chain, table|nil profile
function ProfileStore.Load(name)
    local cjson = require("cjson")
    local path = "lyric-forge-profiles/" .. name .. ".json"
    local file = File:new(path, FILE_READ)
    if not file:IsOpen() then
        log:Warning("[ProfileStore] not found: " .. name)
        return nil, nil
    end
    local jsonStr = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Error("[ProfileStore] parse error: " .. tostring(data))
        return nil, nil
    end

    local MarkovChain = require("scripts.lyric-forge.MarkovChain")
    local chain = MarkovChain.New(data.order)
    chain.transitions = data.transitions
    chain.starters = data.starters
    chain.totalTokens = data.totalTokens

    return chain, data.profile
end

--- 列出所有已保存的风格档案
---@return string[]
function ProfileStore.ListProfiles()
    local names = {}
    -- 尝试读取目录（通过预定义列表或文件索引）
    local indexPath = "lyric-forge-profiles/index.json"
    local file = File:new(indexPath, FILE_READ)
    if file:IsOpen() then
        local cjson = require("cjson")
        local content = file:ReadString()
        file:Close()
        local ok, data = pcall(cjson.decode, content)
        if ok and data.profiles then
            return data.profiles
        end
    end
    return names
end

--- 删除风格档案
---@param name string
function ProfileStore.Delete(name)
    local path = "lyric-forge-profiles/" .. name .. ".json"
    if fileSystem:FileExists(path) then
        fileSystem:Delete(path)
        log:Info("[ProfileStore] deleted: " .. name)
    end
end

return ProfileStore
```
