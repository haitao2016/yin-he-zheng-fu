# AI Game Tester — 模块实现参考

> 本文件包含 6 个 Lua 模块的完整实现代码，供 AI 直接生成到 `scripts/test/` 目录。

---

## 1. TrieEngine — 字典树引擎

映射自 C++ `Trie.cpp/hpp`。使用 Lua table 实现 26 叉字典树，
支持精确搜索、模糊搜索（编辑距离）和字谜搜索（字母重组）。

```lua
-- scripts/test/TrieEngine.lua
local TrieEngine = {}
TrieEngine.__index = TrieEngine

-- 创建 Trie 节点
local function createNode(word)
    return {
        children = {},  -- children[char] = node
        word = word or "",
        isEnd = false,
    }
end

--- 创建新的字典树
function TrieEngine.new()
    local self = setmetatable({}, TrieEngine)
    self.root = createNode("")
    return self
end

--- 插入单词
function TrieEngine:insert(word)
    word = string.lower(word)
    local node = self.root
    for i = 1, #word do
        local c = word:sub(i, i)
        if not node.children[c] then
            node.children[c] = createNode(word:sub(1, i))
        end
        node = node.children[c]
    end
    node.isEnd = true
end

--- 精确搜索
function TrieEngine:search(word)
    word = string.lower(word)
    local node = self.root
    for i = 1, #word do
        local c = word:sub(i, i)
        if not node.children[c] then
            return false
        end
        node = node.children[c]
    end
    return node.isEnd
end

--- 模糊搜索（编辑距离 ≤ maxChanges）
--- 映射自 Trie::Node::getWords 的 additions/removals 逻辑
function TrieEngine:fuzzySearch(query, maxChanges)
    query = string.lower(query)
    local results = {}
    local seen = {}

    local function dfs(node, remaining, changesLeft)
        -- 如果是完整单词且剩余字符用完或在允许范围内
        if node.isEnd and #remaining <= changesLeft then
            if not seen[node.word] then
                seen[node.word] = true
                results[#results + 1] = node.word
            end
        end

        -- 尝试匹配当前字符（字谜式：从 remaining 中任选）
        for i = 1, #remaining do
            local c = remaining:sub(i, i)
            if node.children[c] then
                local newRemaining = remaining:sub(1, i - 1) .. remaining:sub(i + 1)
                dfs(node.children[c], newRemaining, changesLeft)
            end
        end

        if changesLeft > 0 then
            -- 添加操作：在 Trie 中前进但不消耗 remaining 字符
            for c, child in pairs(node.children) do
                dfs(child, remaining, changesLeft - 1)
            end
            -- 删除操作：跳过 remaining 中的字符
            for i = 1, #remaining do
                local newRemaining = remaining:sub(1, i - 1) .. remaining:sub(i + 1)
                dfs(node, newRemaining, changesLeft - 1)
            end
        end
    end

    dfs(self.root, query, maxChanges)
    return results
end

--- 字谜搜索（纯字母重组，映射自 Trie::Node::getWords 的 anagram 部分）
--- complete=true 时要求用完所有字母，false 时允许部分匹配
function TrieEngine:anagramSearch(letters, complete)
    letters = string.lower(letters)
    local results = {}
    local seen = {}

    local function dfs(node, remaining)
        if node.isEnd then
            if not complete or #remaining == 0 then
                if not seen[node.word] then
                    seen[node.word] = true
                    results[#results + 1] = node.word
                end
            end
        end
        for i = 1, #remaining do
            local c = remaining:sub(i, i)
            if node.children[c] then
                local newRemaining = remaining:sub(1, i - 1) .. remaining:sub(i + 1)
                dfs(node.children[c], newRemaining)
            end
        end
    end

    dfs(self.root, letters)
    return results
end

--- 批量加载单词列表
function TrieEngine:loadFromList(wordTable)
    for i = 1, #wordTable do
        self:insert(wordTable[i])
    end
end

--- 获取所有已插入单词
function TrieEngine:allWords()
    local words = {}
    local function collect(node)
        if node.isEnd then
            words[#words + 1] = node.word
        end
        for _, child in pairs(node.children) do
            collect(child)
        end
    end
    collect(self.root)
    return words
end

return TrieEngine
```

---

## 2. ActionSystem — 行动组合系统

映射自 C++ `Spell.cpp/hpp` + `GameTree::getBestSpell` 的行动搜索逻辑。

```lua
-- scripts/test/ActionSystem.lua
local ActionSystem = {}
ActionSystem.__index = ActionSystem

--- 计算两个字符串的字符频率差异（映射自 helpers.cpp countDiff）
local function countDiff(a, b)
    local countA = {}
    local countB = {}
    for i = 1, #a do
        local c = a:sub(i, i):lower()
        if c:match("%a") then
            countA[c] = (countA[c] or 0) + 1
        end
    end
    for i = 1, #b do
        local c = b:sub(i, i):lower()
        if c:match("%a") then
            countB[c] = (countB[c] or 0) + 1
        end
    end
    -- 合并所有出现的字符
    local allChars = {}
    for c in pairs(countA) do allChars[c] = true end
    for c in pairs(countB) do allChars[c] = true end
    local diff = 0
    for c in pairs(allChars) do
        diff = diff + math.abs((countA[c] or 0) - (countB[c] or 0))
    end
    return diff
end

--- 比较两段文本的单词差异（映射自 helpers.cpp compareWords）
local function compareWords(textA, textB)
    local wordsA = {}
    local wordsB = {}
    for w in textA:lower():gmatch("%a+") do
        wordsA[w] = (wordsA[w] or 0) + 1
    end
    for w in textB:lower():gmatch("%a+") do
        wordsB[w] = (wordsB[w] or 0) + 1
    end
    local allWords = {}
    for w in pairs(wordsA) do allWords[w] = true end
    for w in pairs(wordsB) do allWords[w] = true end
    local diff = 0
    for w in pairs(allWords) do
        diff = diff + math.abs((wordsA[w] or 0) - (wordsB[w] or 0))
    end
    return diff
end

--- 创建行动系统
--- @param verbs string[] 动词列表
--- @param nouns string[] 名词列表
function ActionSystem.new(verbs, nouns)
    local self = setmetatable({}, ActionSystem)
    self.verbs = verbs or {}
    self.nouns = nouns or {}
    return self
end

--- 创建行动（动词+名词）
function ActionSystem:createAction(verb, noun)
    return { verb = verb:lower(), noun = noun:lower() }
end

--- 获取行动名称
function ActionSystem.actionName(action)
    return action.verb .. " " .. action.noun
end

--- 计算行动等级（映射自 Spell::updateLevel）
--- 基于当前行动与原始行动的字符频率差异
function ActionSystem:calcLevel(action, originalAction)
    local startStr = originalAction.verb .. " " .. originalAction.noun
    local curStr = action.verb .. " " .. action.noun
    return 1 + countDiff(startStr, curStr)
end

--- 随机行动
function ActionSystem:randomAction()
    local v = self.verbs[math.random(#self.verbs)]
    local n = self.nouns[math.random(#self.nouns)]
    return self:createAction(v, n)
end

--- 基于历史记录寻找最佳行动
--- 映射自 GameTree::getBestSpell 的评分逻辑
--- @param origAction table 原始行动
--- @param curAction table 当前行动
--- @param context string 当前情景文本
--- @param history table[] 历史场景列表 { {text, action, success, rating}, ... }
--- @param maxChanges number 最大编辑次数（默认 3）
--- @return table|nil 最佳行动 { verb, noun, score }
function ActionSystem:findBestAction(origAction, curAction, context, history, maxChanges)
    maxChanges = maxChanges or 3
    local THRESHOLD = 2
    local maxScore = -math.huge
    local best = nil

    -- 第一阶段：从历史记录中搜索（映射自 GameTree::getBestSpell 前半段）
    for _, scene in ipairs(history) do
        local contextDiff = compareWords(scene.text, context)
        local origName = origAction.verb .. " " .. origAction.noun
        local sceneName = scene.action.verb .. " " .. scene.action.noun
        local chance = math.pow(0.5, countDiff(origName, sceneName))
        local rating = (scene.rating or 0) + 3
        local score = contextDiff * chance * rating

        -- 排除与当前行动相同的选项
        local isSame = (scene.action.verb == curAction.verb and scene.action.noun == curAction.noun)
        if score > maxScore and not isSame then
            maxScore = score
            best = { verb = scene.action.verb, noun = scene.action.noun, score = score }
        end
    end

    -- 如果历史评分超过阈值，使用历史结果
    if best and maxScore > THRESHOLD then
        return best
    end

    -- 第二阶段：随机生成候选行动（映射自 GameTree::getBestSpell 后半段 Trie 搜索）
    local candidates = {}
    local origStr = origAction.verb .. origAction.noun
    local OPTION_LIMIT = 100

    for _ = 1, math.min(OPTION_LIMIT, #self.verbs * #self.nouns) do
        local v = self.verbs[math.random(#self.verbs)]
        local n = self.nouns[math.random(#self.nouns)]
        local candidateStr = v .. n
        local diff = countDiff(origStr, candidateStr)
        if diff <= maxChanges then
            candidates[#candidates + 1] = { verb = v, noun = n, diff = diff }
        end
    end

    if #candidates == 0 then
        -- 最后兜底：返回随机行动
        local r = self:randomAction()
        r.score = 0
        return r
    end

    -- 选择编辑距离最小的候选
    table.sort(candidates, function(a, b) return a.diff < b.diff end)
    local chosen = candidates[math.random(math.min(3, #candidates))]
    return { verb = chosen.verb, noun = chosen.noun, score = chosen.diff }
end

-- 导出工具函数供外部使用
ActionSystem.countDiff = countDiff
ActionSystem.compareWords = compareWords

return ActionSystem
```

---

## 3. DiceSimulator — 骰子模拟器

映射自 C++ `Transcript::getScenario` 中的骰子投掷逻辑。

```lua
-- scripts/test/DiceSimulator.lua
local DiceSimulator = {}
DiceSimulator.__index = DiceSimulator

--- 创建骰子模拟器
--- @param config table { count, sides, successThreshold, exploding }
function DiceSimulator.new(config)
    local self = setmetatable({}, DiceSimulator)
    self.count = config.count or 6
    self.sides = config.sides or 6
    self.successThreshold = config.successThreshold or 4
    self.exploding = config.exploding ~= false  -- 默认开启
    return self
end

--- 投掷一次（映射自 C++ dice roll 逻辑）
--- @return table { rolls, successes, total, exploded }
function DiceSimulator:roll()
    local rolls = {}
    local successes = 0
    local exploded = 0

    -- 初始投掷
    for i = 1, self.count do
        rolls[#rolls + 1] = math.random(1, self.sides)
    end

    -- 判定成功 + 爆炸骰（映射自 C++ 的 exploding die 逻辑）
    local idx = 1
    while idx <= #rolls do
        if rolls[idx] >= self.successThreshold then
            successes = successes + 1
            -- 最大值触发爆炸骰
            if self.exploding and rolls[idx] == self.sides then
                rolls[#rolls + 1] = math.random(1, self.sides)
                exploded = exploded + 1
            end
        end
        idx = idx + 1
    end

    return {
        rolls = rolls,
        successes = successes,
        total = #rolls,
        exploded = exploded,
    }
end

--- 检查是否成功
--- @param result table roll() 的返回值
--- @param requiredSuccesses number 需要的成功数
--- @return boolean
function DiceSimulator:check(result, requiredSuccesses)
    return result.successes >= requiredSuccesses
end

--- 批量模拟并统计（概率分析核心）
--- @param times number 模拟次数
--- @param requiredLevel number 目标等级（需要的成功骰数）
--- @return table { successRate, avgSuccesses, minSuccesses, maxSuccesses, histogram }
function DiceSimulator:batchSimulate(times, requiredLevel)
    local totalSuccesses = 0
    local successCount = 0
    local minS = math.huge
    local maxS = 0
    local histogram = {}  -- histogram[successes] = count

    for _ = 1, times do
        local result = self:roll()
        local s = result.successes
        totalSuccesses = totalSuccesses + s
        if s >= requiredLevel then
            successCount = successCount + 1
        end
        minS = math.min(minS, s)
        maxS = math.max(maxS, s)
        histogram[s] = (histogram[s] or 0) + 1
    end

    return {
        successRate = successCount / times,
        avgSuccesses = totalSuccesses / times,
        minSuccesses = minS,
        maxSuccesses = maxS,
        histogram = histogram,
        totalRuns = times,
        requiredLevel = requiredLevel,
    }
end

--- 为多个等级批量分析（生成等级-成功率曲线数据）
--- @param times number 每个等级的模拟次数
--- @param maxLevel number 最大等级
--- @return table[] { {level, successRate, avgSuccesses}, ... }
function DiceSimulator:levelCurve(times, maxLevel)
    local curve = {}
    for level = 1, maxLevel do
        local dist = self:batchSimulate(times, level)
        curve[#curve + 1] = {
            level = level,
            successRate = dist.successRate,
            avgSuccesses = dist.avgSuccesses,
        }
    end
    return curve
end

return DiceSimulator
```

---

## 4. DecisionEngine — 决策引擎

映射自 C++ `GameTree.cpp/hpp`。基于历史场景记录评估当前情景的最优行动。

```lua
-- scripts/test/DecisionEngine.lua
local ActionSystem = require("test.ActionSystem")

local DecisionEngine = {}
DecisionEngine.__index = DecisionEngine

--- 创建决策引擎
function DecisionEngine.new()
    local self = setmetatable({}, DecisionEngine)
    self.history = {}  -- 历史场景列表
    return self
end

--- 加载历史场景列表
--- @param scenarios table[] { {text, action={verb,noun}, success, rating}, ... }
function DecisionEngine:loadHistory(scenarios)
    for _, s in ipairs(scenarios) do
        self.history[#self.history + 1] = s
    end
end

--- 添加单个场景到历史
function DecisionEngine:addScenario(scenario)
    self.history[#self.history + 1] = scenario
end

--- 评估最优行动（映射自 GameTree::getBestSpell 的评分逻辑）
--- @param originalAction table 原始行动 {verb, noun}
--- @param currentAction table 当前行动 {verb, noun}
--- @param contextText string 当前情景文本
--- @return table|nil { verb, noun, score }
function DecisionEngine:evaluate(originalAction, currentAction, contextText)
    local THRESHOLD = 2
    local maxScore = -math.huge
    local best = nil

    for _, scene in ipairs(self.history) do
        -- 上下文相似度（单词差异数量越大 → 差异越大）
        local contextSim = ActionSystem.compareWords(scene.text, contextText)
        -- 法术相似度（字符差异越小 → 越相似 → chance 越大）
        local origName = originalAction.verb .. " " .. originalAction.noun
        local sceneName = scene.action.verb .. " " .. scene.action.noun
        local chance = math.pow(0.5, ActionSystem.countDiff(origName, sceneName))
        -- 评分（-2 到 +2，偏移 +3 确保正值）
        local rating = (scene.rating or 0) + 3
        -- 综合得分
        local score = contextSim * chance * rating

        -- 排除当前行动
        local isSame = (scene.action.verb == currentAction.verb
                    and scene.action.noun == currentAction.noun)
        if score > maxScore and not isSame then
            maxScore = score
            best = {
                verb = scene.action.verb,
                noun = scene.action.noun,
                score = score,
            }
        end
    end

    if best and maxScore > THRESHOLD then
        return best
    end
    return nil  -- 没有足够好的历史匹配
end

--- 获取历史数量
function DecisionEngine:historyCount()
    return #self.history
end

--- 清空历史
function DecisionEngine:clearHistory()
    self.history = {}
end

return DecisionEngine
```

---

## 5. SessionRecorder — 会话记录器

映射自 C++ `Transcript.cpp/hpp`。将二进制 `.gts` 格式替换为 JSON 序列化。

```lua
-- scripts/test/SessionRecorder.lua
local cjson = require("cjson")

local SessionRecorder = {}
SessionRecorder.__index = SessionRecorder

--- 创建会话记录器
--- @param startAction table 起始行动 {verb, noun}
function SessionRecorder.new(startAction)
    local self = setmetatable({}, SessionRecorder)
    self.startAction = startAction
    self.scenarios = {}
    self.ending = ""
    self.timestamp = os.date("%Y-%m-%d %H:%M:%S")
    return self
end

--- 添加场景记录
--- @param scenario table { text, action={verb,noun}, success, rating }
function SessionRecorder:addScenario(scenario)
    self.scenarios[#self.scenarios + 1] = {
        text = scenario.text,
        action = {
            verb = scenario.action.verb,
            noun = scenario.action.noun,
        },
        success = scenario.success,
        rating = scenario.rating or 0,  -- -2 到 +2
    }
end

--- 设置结局文本
function SessionRecorder:setEnding(ending)
    self.ending = ending
end

--- 序列化为 JSON 字符串
function SessionRecorder:toJSON()
    return cjson.encode({
        version = 1,
        timestamp = self.timestamp,
        startAction = self.startAction,
        scenarios = self.scenarios,
        ending = self.ending,
        totalScenarios = #self.scenarios,
    })
end

--- 保存到文件（使用 UrhoX File API）
--- @param filepath string 相对路径，如 "transcripts/session_001.json"
function SessionRecorder:save(filepath)
    local jsonStr = self:toJSON()
    local file = File(filepath, FILE_WRITE)
    if file then
        file:WriteLine(jsonStr)
        file:Close()
        log:Write(LOG_INFO, "[SessionRecorder] Saved: " .. filepath)
        return true
    else
        log:Write(LOG_ERROR, "[SessionRecorder] Failed to save: " .. filepath)
        return false
    end
end

--- 从 JSON 文件加载单个会话
--- @param filepath string 文件路径
--- @return table|nil 会话数据
function SessionRecorder.load(filepath)
    local file = File(filepath, FILE_READ)
    if not file then
        log:Write(LOG_WARNING, "[SessionRecorder] File not found: " .. filepath)
        return nil
    end
    local content = file:ReadLine()
    file:Close()
    local ok, data = pcall(cjson.decode, content)
    if ok then
        return data
    else
        log:Write(LOG_ERROR, "[SessionRecorder] JSON parse error: " .. filepath)
        return nil
    end
end

--- 加载目录下所有会话文件
--- @param dirPath string 目录路径，如 "transcripts/"
--- @return table[] 会话数据列表
function SessionRecorder.loadAll(dirPath)
    local sessions = {}
    -- 使用 FileSystem 扫描目录
    local fs = fileSystem
    if not fs then
        log:Write(LOG_ERROR, "[SessionRecorder] FileSystem not available")
        return sessions
    end
    local files = fs:ScanDir(dirPath, "*.json", SCAN_FILES, false)
    if files then
        for i = 0, files:GetSize() - 1 do
            local filename = files:At(i)
            local data = SessionRecorder.load(dirPath .. "/" .. filename)
            if data then
                sessions[#sessions + 1] = data
            end
        end
    end
    return sessions
end

--- 从会话数据中提取场景列表（用于 DecisionEngine）
--- @param sessionData table 从 load() 返回的数据
--- @return table[] 场景列表
function SessionRecorder.extractScenarios(sessionData)
    return sessionData.scenarios or {}
end

return SessionRecorder
```

---

## 6. TestRunner — 测试编排引擎

整合所有模块，提供一键批量测试能力。

```lua
-- scripts/test/TestRunner.lua
local TrieEngine = require("test.TrieEngine")
local ActionSystem = require("test.ActionSystem")
local DiceSimulator = require("test.DiceSimulator")
local DecisionEngine = require("test.DecisionEngine")
local SessionRecorder = require("test.SessionRecorder")

local TestRunner = {}
TestRunner.__index = TestRunner

--- 创建测试运行器
--- @param config table { verbs, nouns, rounds, diceConfig }
function TestRunner.new(config)
    local self = setmetatable({}, TestRunner)
    self.verbs = config.verbs or {"cast", "pull", "push", "make", "turn", "break"}
    self.nouns = config.nouns or {"fire", "ice", "wall", "door", "key", "shield"}
    self.rounds = config.rounds or 100
    self.diceConfig = config.diceConfig or {
        count = 6, sides = 6, successThreshold = 4, exploding = true,
    }
    self.actionSys = ActionSystem.new(self.verbs, self.nouns)
    self.dice = DiceSimulator.new(self.diceConfig)
    self.decision = DecisionEngine.new()
    self.report = {}
    return self
end

--- 运行行动组合测试
--- 测试随机行动组合的等级分布和成功率
function TestRunner:runActionTest(rounds)
    rounds = rounds or self.rounds
    local levelDist = {}   -- level → count
    local totalLevel = 0
    local minLevel = math.huge
    local maxLevel = 0
    local origAction = self.actionSys:randomAction()

    for _ = 1, rounds do
        local action = self.actionSys:randomAction()
        local level = self.actionSys:calcLevel(action, origAction)
        levelDist[level] = (levelDist[level] or 0) + 1
        totalLevel = totalLevel + level
        minLevel = math.min(minLevel, level)
        maxLevel = math.max(maxLevel, level)
    end

    local result = {
        type = "action_test",
        rounds = rounds,
        originalAction = origAction,
        avgLevel = totalLevel / rounds,
        minLevel = minLevel,
        maxLevel = maxLevel,
        levelDistribution = levelDist,
    }
    self.report.actionTest = result
    return result
end

--- 运行骰子概率分析
function TestRunner:runDiceAnalysis(times)
    times = times or 10000
    local maxLevel = math.max(self.diceConfig.count + 2, 10)
    local curve = self.dice:levelCurve(times, maxLevel)

    local result = {
        type = "dice_analysis",
        totalSimulations = times,
        diceConfig = self.diceConfig,
        levelCurve = curve,
    }
    self.report.diceAnalysis = result
    return result
end

--- 运行决策引擎测试
--- @param contextList string[] 测试情景文本列表
--- @param historyDir string|nil 历史记录目录
function TestRunner:runDecisionTest(contextList, historyDir)
    -- 加载历史记录
    if historyDir then
        local sessions = SessionRecorder.loadAll(historyDir)
        for _, session in ipairs(sessions) do
            local scenarios = SessionRecorder.extractScenarios(session)
            self.decision:loadHistory(scenarios)
        end
    end

    local origAction = self.actionSys:randomAction()
    local curAction = self.actionSys:randomAction()
    local decisions = {}
    local foundCount = 0

    for _, context in ipairs(contextList) do
        local best = self.decision:evaluate(origAction, curAction, context)
        decisions[#decisions + 1] = {
            context = context,
            decision = best,
            found = best ~= nil,
        }
        if best then foundCount = foundCount + 1 end
    end

    local result = {
        type = "decision_test",
        totalContexts = #contextList,
        decisionsFound = foundCount,
        historySize = self.decision:historyCount(),
        decisions = decisions,
    }
    self.report.decisionTest = result
    return result
end

--- 打印测试报告到控制台
function TestRunner:printReport()
    log:Write(LOG_INFO, "========== AI GAME TESTER REPORT ==========")

    if self.report.actionTest then
        local r = self.report.actionTest
        log:Write(LOG_INFO, string.format(
            "[Action Test] rounds=%d avgLevel=%.2f min=%d max=%d",
            r.rounds, r.avgLevel, r.minLevel, r.maxLevel
        ))
        log:Write(LOG_INFO, "  Original: " .. r.originalAction.verb .. " " .. r.originalAction.noun)
    end

    if self.report.diceAnalysis then
        local r = self.report.diceAnalysis
        log:Write(LOG_INFO, string.format(
            "[Dice Analysis] simulations=%d dice=%dx d%d threshold=%d+ exploding=%s",
            r.totalSimulations, r.diceConfig.count, r.diceConfig.sides,
            r.diceConfig.successThreshold, tostring(r.diceConfig.exploding)
        ))
        for _, entry in ipairs(r.levelCurve) do
            log:Write(LOG_INFO, string.format(
                "  Level %2d: successRate=%.1f%% avgSuccesses=%.2f",
                entry.level, entry.successRate * 100, entry.avgSuccesses
            ))
        end
    end

    if self.report.decisionTest then
        local r = self.report.decisionTest
        log:Write(LOG_INFO, string.format(
            "[Decision Test] contexts=%d found=%d history=%d",
            r.totalContexts, r.decisionsFound, r.historySize
        ))
    end

    log:Write(LOG_INFO, "=============================================")
end

--- 获取完整报告数据
function TestRunner:getReport()
    return self.report
end

return TestRunner
```
