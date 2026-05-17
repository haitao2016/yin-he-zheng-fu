# Markov Chain 算法详解与优化

> Lyric Forge 的核心算法参考文档。

---

## 1. N-gram Markov Chain 基础

### 1.1 数学定义

Markov Chain 文本生成基于条件概率：

```
P(w_t | w_{t-n+1}, ..., w_{t-1})
```

给定前 n-1 个 token，预测第 n 个 token 的概率。

### 1.2 阶数选择

| 阶数 | 上下文长度 | 输出特征 | 适用场景 |
|------|-----------|---------|---------|
| 1 (unigram) | 0 字符 | 完全随机，不可读 | 不推荐 |
| 2 (bigram) | 1 字符 | 有基本连贯性 | 咒语、短语 |
| 3 (trigram) | 2 字符 | 较好可读性 | 歌词、诗歌（推荐） |
| 4 (4-gram) | 3 字符 | 接近原文 | 大语料库 |
| 5+ | 4+ 字符 | 过拟合，大量复制原文 | 仅限超大语料 |

**推荐**：中文使用 trigram (阶数=3)，英文使用 bigram 或 trigram。

### 1.3 转移矩阵存储

```lua
-- 稀疏表示（推荐）
transitions = {
    ["风|暴"] = { ["之"] = 3, ["中"] = 2, ["来"] = 1 },
    ["暴|之"] = { ["中"] = 2, ["后"] = 1 },
}

-- 内存估算
-- 1000 行语料 ≈ 5000 个唯一 N-gram ≈ 200KB JSON
```

---

## 2. 采样策略

### 2.1 温度采样

温度参数 T 控制输出的随机性：

```
weight(w) = count(w) ^ (1/T)
P(w) = weight(w) / sum(all_weights)
```

| 温度 T | 效果 | 适用 |
|--------|------|------|
| 0.1-0.3 | 几乎确定性，选概率最高的 | 正式文本、叙事 |
| 0.5-0.8 | 平衡创意与连贯 | 歌词、诗歌（推荐） |
| 1.0 | 原始概率分布 | 通用 |
| 1.2-1.5 | 高随机性 | 咒语、预言 |
| 2.0+ | 接近均匀随机 | 实验用途 |

### 2.2 Top-K 采样

只从概率最高的 K 个候选中采样：

```lua
function TopKSample(candidates, k, temperature)
    -- 按频次排序
    local sorted = {}
    for word, count in pairs(candidates) do
        sorted[#sorted + 1] = { word = word, count = count }
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- 只保留 top-k
    local topK = {}
    local totalWeight = 0
    for i = 1, math.min(k, #sorted) do
        local w = math.pow(sorted[i].count, 1.0 / temperature)
        topK[#topK + 1] = { word = sorted[i].word, weight = w }
        totalWeight = totalWeight + w
    end

    -- 加权采样
    local roll = math.random() * totalWeight
    local cum = 0
    for _, e in ipairs(topK) do
        cum = cum + e.weight
        if cum >= roll then return e.word end
    end
    return topK[#topK].word
end
```

### 2.3 Nucleus (Top-P) 采样

动态选择累计概率达到 P 的最小候选集：

```lua
function NucleusSample(candidates, p, temperature)
    local sorted = {}
    local totalCount = 0
    for word, count in pairs(candidates) do
        sorted[#sorted + 1] = { word = word, count = count }
        totalCount = totalCount + count
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    -- 找到累计概率 >= p 的最小集合
    local nucleus = {}
    local cumProb = 0
    local totalWeight = 0
    for _, entry in ipairs(sorted) do
        local prob = entry.count / totalCount
        cumProb = cumProb + prob
        local w = math.pow(entry.count, 1.0 / temperature)
        nucleus[#nucleus + 1] = { word = entry.word, weight = w }
        totalWeight = totalWeight + w
        if cumProb >= p then break end
    end

    local roll = math.random() * totalWeight
    local cum = 0
    for _, e in ipairs(nucleus) do
        cum = cum + e.weight
        if cum >= roll then return e.word end
    end
    return nucleus[#nucleus].word
end
```

---

## 3. 中文分词策略

### 3.1 字符级 vs 词级

| 粒度 | 优点 | 缺点 |
|------|------|------|
| 字符级 | 无需分词库，覆盖所有汉字 | 语义连贯性较低 |
| 词级 | 输出更连贯 | 需要分词，OOV 问题 |
| 混合级 | 兼顾两者 | 实现复杂 |

**推荐**：歌词/诗歌使用字符级（与 encore.ai 一致），散文/对话使用词级。

### 3.2 UTF-8 字符遍历

```lua
-- 正确的中文字符遍历
function Tokenize(text)
    local tokens = {}
    for _, codepoint in utf8.codes(text) do
        tokens[#tokens + 1] = utf8.char(codepoint)
    end
    return tokens
end

-- 错误方式（会拆断多字节字符）
-- for i = 1, #text do ... end  -- 不要这样做
```

### 3.3 标点符号处理

```lua
local PUNCTUATION = {
    "，", "。", "！", "？", "、", "；", "：",
    """, """, "'", "'",
    "…", "—", "～",
    "\n",
}

function IsPunctuation(char)
    for _, p in ipairs(PUNCTUATION) do
        if char == p then return true end
    end
    return false
end
```

---

## 4. 韵脚匹配算法

### 4.1 汉字韵母分类

中文押韵基于**韵母**（vowel final）匹配。常见韵母分组：

| 韵部 | 韵母 | 代表字 |
|------|------|--------|
| 一麻 | a, ia, ua | 花 下 家 大 |
| 二波 | o, uo | 多 国 火 落 |
| 三歌 | e, ie, ue | 月 雪 夜 别 |
| 四齐 | i | 你 地 里 起 |
| 五微 | ei, ui | 飞 回 追 泪 |
| 六鱼 | u, v | 路 出 书 绿 |
| 七尤 | ou, iu | 走 手 头 流 |
| 八真 | en, in, un | 人 心 门 春 |
| 九文 | eng, ing | 风 情 明 声 |
| 十东 | ong, iong | 中 空 龙 红 |
| 十一庚 | ang, iang, uang | 光 方 王 长 |
| 十二侵 | an, ian, uan | 天 前 年 间 |
| 十三豪 | ao, iao | 高 好 少 要 |
| 十四寒 | ai, uai | 来 开 海 白 |

### 4.2 近似韵（宽韵）

某些韵部可以通押（近似韵），增加押韵灵活性：

```lua
APPROXIMATE_RHYMES = {
    { "en", "eng" },      -- 真/文 通押
    { "an", "ang" },      -- 寒/庚 通押
    { "in", "ing" },      -- 侵/文 通押
}
```

### 4.3 多音字处理

对于多音字，取任一读音押韵即算匹配：

```lua
-- 简化策略：维护常见多音字表
POLYPHONIC = {
    ["行"] = { "xing", "hang" },
    ["长"] = { "chang", "zhang" },
    ["重"] = { "chong", "zhong" },
}
```

---

## 5. 性能优化

### 5.1 预计算词频索引

```lua
-- 训练时建立反向索引，加速韵脚查询
function BuildRhymeIndex(transitions)
    local index = {}  -- { [lastChar] = { key1, key2, ... } }
    for key, nexts in pairs(transitions) do
        for word, _ in pairs(nexts) do
            if not index[word] then
                index[word] = {}
            end
            index[word][#index[word] + 1] = key
        end
    end
    return index
end
```

### 5.2 惰性加载

```lua
-- 大语料库：按需加载段落
function LazyCorpusLoader(corpusPath)
    local loaded = {}
    return {
        GetEntry = function(idx)
            if not loaded[idx] then
                -- 从文件加载指定条目
                loaded[idx] = LoadSingleEntry(corpusPath, idx)
            end
            return loaded[idx]
        end
    }
end
```

### 5.3 生成缓存

```lua
-- 缓存已生成的文本，避免重复生成
local generationCache = {}
local CACHE_SIZE = 50

function CachedGenerate(generator, template, cacheKey)
    if generationCache[cacheKey] then
        return generationCache[cacheKey]
    end
    local text = generator:GenerateFromTemplate(template)
    generationCache[cacheKey] = text
    -- 简单 LRU
    if #generationCache > CACHE_SIZE then
        -- 清理最旧的条目
    end
    return text
end
```

---

## 6. 质量评估指标

### 6.1 重复率

```lua
-- 计算生成文本中与原始语料完全匹配的行占比
function MeasureRepetition(generated, originalLines)
    local originalSet = {}
    for _, line in ipairs(originalLines) do
        originalSet[line] = true
    end
    local genLines = {}
    for line in generated:gmatch("[^\n]+") do
        genLines[#genLines + 1] = line
    end
    local matches = 0
    for _, line in ipairs(genLines) do
        if originalSet[line] then matches = matches + 1 end
    end
    return matches / math.max(#genLines, 1)
end
```

### 6.2 韵脚成功率

```lua
-- 计算押韵约束的满足率
function MeasureRhymeSuccess(generated, template)
    -- 解析生成文本的行
    -- 按 rhymeScheme 检查对应行的行尾是否押韵
    -- 返回 成功数 / 总约束数
end
```

### 6.3 多样性评分

```lua
-- 唯一 N-gram 占总 N-gram 的比例
function MeasureDiversity(text, n)
    local tokens = Tokenize(text)
    local ngrams = {}
    local total = 0
    for i = 1, #tokens - n + 1 do
        local key = table.concat(tokens, "", i, i + n - 1)
        ngrams[key] = true
        total = total + 1
    end
    local unique = 0
    for _ in pairs(ngrams) do unique = unique + 1 end
    return unique / math.max(total, 1)
end
```
