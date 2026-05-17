---
name: web-api-integration
version: "1.0"
trigger:
  keyword:
    - 天气API
    - 翻译API
    - 新闻API
    - 地图API
    - 支付API
    - 汇率API
    - 短信API
    - 图像处理API
    - 搜索API
    - 语音API
    - 体育API
    - 社交API
    - 外部API
    - 第三方API
    - Web API
    - REST API
    - HTTP接口
    - 接入接口
    - API集成
  auto_detect: true
description: |
  在 UrhoX 多人游戏中集成第三方 Web API（天气、翻译、新闻、地图、支付、汇率等 12 大类）。
  Use when:
  (1) 用户要在游戏中接入天气/翻译/新闻/地图/支付/汇率等非 LLM 类外部 API,
  (2) 用户需要服务端调用第三方 REST API 并将结果同步到客户端,
  (3) 用户想实现游戏内实时数据展示（天气系统、新闻滚动、排行榜同步等）,
  (4) 用户需要处理 API Key 安全存储、请求缓存、频率限制等工程问题,
  (5) 用户提到任何第三方 Web 服务/REST 接口/HTTP 接口的游戏集成。
context:
  - engine-docs/recipes/server-cloud-score.md
  - engine-docs/lua-scripting-guide.md
---

# Web API 集成指南（非 LLM 类）

> 覆盖天气、翻译、新闻、地图、支付、汇率等 12 大类 100+ 外部 API 的 UrhoX 服务端集成方案。

## 与 llm-server-http Skill 的关系

| Skill | 覆盖范围 | 典型场景 |
|-------|---------|---------|
| **llm-server-http** | 大语言模型 API（豆包/通义/百炼等） | AI NPC 对话、智能问答 |
| **web-api-integration**（本 Skill） | 非 LLM 类 Web API（12 大类） | 天气系统、实时翻译、支付、地图 |

两者共享相同的服务端 HTTP 架构，但本 Skill 专注于结构化数据 API 的集成模式。

---

## 1. 核心架构

```
客户端 Lua                 服务端 Lua                  第三方 API
  │                          │                           │
  │── callFunction ─────────>│                           │
  │   (请求参数)              │── http:Create() ─────────>│
  │                          │                           │
  │                          │<── JSON Response ─────────│
  │<── callback ─────────────│                           │
  │   (结构化数据)            │                           │
```

**核心约束**：客户端 HTTP 完全被封禁，所有外部请求必须经服务端中转。

### 两种通信模式

| 模式 | API | 适用场景 |
|------|-----|---------|
| **请求-响应** | `serverCloud.registerFunction` / `clientCloud.callFunction` | 客户端主动请求数据（推荐） |
| **服务端推送** | `RemoteEvent` | 服务端定时推送、广播通知 |

---

## 2. 服务端 HTTP 调用模板

### GET 请求

```lua
-- scripts/network/Server.lua
local API_KEY = serverCloud.getSecret("WEATHER_API_KEY")

serverCloud.registerFunction("getWeather", function(args, caller)
    local city = args.city or "beijing"
    local url = "https://api.example.com/weather?city=" .. city .. "&key=" .. API_KEY

    http:Create()
        :SetUrl(url)
        :SetMethod(HTTP_GET)
        :OnSuccess(function(client, response)
            if response.success then
                local ok, data = pcall(cjson.decode, response.dataAsString)
                if ok then
                    caller:Return({ success = true, data = data })
                else
                    caller:Return({ success = false, error = "JSON 解析失败" })
                end
            else
                caller:Return({ success = false, error = "HTTP " .. response.statusCode })
            end
        end)
        :OnError(function(client, statusCode, error)
            caller:Return({ success = false, error = error })
        end)
        :Send()
end)
```

### POST 请求

```lua
serverCloud.registerFunction("translateText", function(args, caller)
    local API_KEY = serverCloud.getSecret("TRANSLATE_API_KEY")
    local body = cjson.encode({
        text = args.text,
        from = args.from or "auto",
        to = args.to or "en"
    })

    http:Create()
        :SetUrl("https://api.example.com/translate")
        :SetMethod(HTTP_POST)
        :SetContentType("application/json")
        :AddHeader("Authorization", "Bearer " .. API_KEY)
        :SetBody(body)
        :OnSuccess(function(client, response)
            if response.success then
                local ok, data = pcall(cjson.decode, response.dataAsString)
                if ok then
                    caller:Return({ success = true, result = data.translated })
                else
                    caller:Return({ success = false, error = "JSON 解析失败" })
                end
            else
                caller:Return({ success = false, error = "HTTP " .. response.statusCode })
            end
        end)
        :OnError(function(client, statusCode, error)
            caller:Return({ success = false, error = error })
        end)
        :Send()
end)
```

---

## 3. 客户端调用

```lua
-- scripts/network/Client.lua

-- 请求天气数据
clientCloud.callFunction("getWeather", { city = "shanghai" }, function(result)
    if result.success then
        updateWeatherUI(result.data)
    else
        log:Write(LOG_ERROR, "天气获取失败: " .. (result.error or "unknown"))
    end
end)

-- 请求翻译
clientCloud.callFunction("translateText", {
    text = "你好世界",
    to = "en"
}, function(result)
    if result.success then
        chatLabel.text = result.result
    end
end)
```

---

## 4. API Key 安全管理

**绝对禁止在代码中硬编码 API Key**。

```lua
-- 正确：使用 serverCloud.getSecret()
local API_KEY = serverCloud.getSecret("MY_API_KEY")
```

API Key 通过项目配置面板设置，存储在服务端安全环境中，客户端永远无法访问。

---

## 5. 缓存策略

对于不需要实时更新的数据，使用缓存减少 API 调用次数和费用。

### 内存缓存（单次会话）

```lua
-- scripts/network/Server.lua
local cache = {}

serverCloud.registerFunction("getWeatherCached", function(args, caller)
    local city = args.city or "beijing"
    local cacheKey = "weather_" .. city
    local now = os.time()

    if cache[cacheKey] and (now - cache[cacheKey].time) < 300 then
        caller:Return({ success = true, data = cache[cacheKey].data, cached = true })
        return
    end

    local API_KEY = serverCloud.getSecret("WEATHER_API_KEY")
    http:Create()
        :SetUrl("https://api.example.com/weather?city=" .. city .. "&key=" .. API_KEY)
        :SetMethod(HTTP_GET)
        :OnSuccess(function(client, response)
            if response.success then
                local ok, data = pcall(cjson.decode, response.dataAsString)
                if ok then
                    cache[cacheKey] = { data = data, time = now }
                    caller:Return({ success = true, data = data, cached = false })
                else
                    caller:Return({ success = false, error = "JSON 解析失败" })
                end
            else
                caller:Return({ success = false, error = "HTTP " .. response.statusCode })
            end
        end)
        :OnError(function(client, statusCode, error)
            caller:Return({ success = false, error = error })
        end)
        :Send()
end)
```

### 持久缓存（跨会话）

```lua
serverCloud.setCache("weather_beijing", cjson.encode(weatherData))

local cached = serverCloud.getCache("weather_beijing")
if cached then
    local data = cjson.decode(cached)
end
```

### 推荐缓存时间

| API 类型 | 推荐 TTL | 说明 |
|---------|---------|------|
| 天气 | 5-15 分钟 | 数据更新频率低 |
| 汇率 | 1-6 小时 | 交易时段变化 |
| 新闻 | 10-30 分钟 | 内容更新适中 |
| 翻译 | 永久缓存 | 相同输入结果不变 |
| 地图/地理 | 24 小时+ | 地理数据极少变化 |
| 体育赛事 | 1-5 分钟 | 比赛期间需实时 |

---

## 6. 支持的 API 类别

本 Skill 覆盖以下 12 大类 API，详细服务商列表和代码模板见 `references/api-catalog.md`。

| # | 类别 | 游戏应用场景 | 代表服务 |
|---|------|-------------|---------|
| 1 | 天气 | 动态天气系统、环境氛围 | OpenWeatherMap, 和风天气 |
| 2 | 翻译 | 多语言聊天、本地化 | 百度翻译, DeepL |
| 3 | 新闻/内容 | 游戏内新闻滚动、公告 | NewsAPI, 聚合数据 |
| 4 | 地图/地理 | LBS 玩法、地图显示 | 高德, 百度地图 |
| 5 | 支付 | 内购、打赏、虚拟货币 | 支付宝, 微信支付 |
| 6 | 汇率/金融 | 模拟经营、交易系统 | ExchangeRate-API |
| 7 | 体育/赛事 | 竞猜、实时比分 | Football-Data |
| 8 | 图像处理 | 头像处理、截图美化 | 阿里云 OSS, TinyPNG |
| 9 | 短信/推送 | 验证码、活动通知 | 阿里云短信, 极光推送 |
| 10 | 音频/语音 | 语音转文字、TTS | 讯飞语音, 百度语音 |
| 11 | 搜索 | 游戏内搜索、知识查询 | Bing Search |
| 12 | 社交/通信 | 好友系统、邮件通知 | SendGrid |

---

## 7. 错误处理（三层防御）

```lua
serverCloud.registerFunction("safeApiCall", function(args, caller)
    http:Create()
        :SetUrl(args.url)
        :SetMethod(HTTP_GET)
        :OnSuccess(function(client, response)
            -- 第一层：HTTP 状态码检查
            if not response.success then
                caller:Return({ success = false, error = "HTTP " .. response.statusCode })
                return
            end

            -- 第二层：JSON 解析保护
            local ok, data = pcall(cjson.decode, response.dataAsString)
            if not ok then
                caller:Return({ success = false, error = "JSON 解析失败" })
                return
            end

            -- 第三层：业务逻辑校验
            if data.error then
                caller:Return({ success = false, error = data.error.message or "API 业务错误" })
                return
            end

            caller:Return({ success = true, data = data })
        end)
        :OnError(function(client, statusCode, error)
            caller:Return({ success = false, error = "网络错误: " .. (error or "unknown") })
        end)
        :Send()
end)
```

---

## 8. 频率限制

防止客户端滥用造成 API 配额耗尽：

```lua
-- scripts/network/Server.lua
local rateLimiter = {}

local function checkRateLimit(playerId, apiName, maxPerMinute)
    local key = playerId .. "_" .. apiName
    local now = os.time()

    if not rateLimiter[key] then
        rateLimiter[key] = { count = 0, resetTime = now + 60 }
    end

    local limiter = rateLimiter[key]
    if now > limiter.resetTime then
        limiter.count = 0
        limiter.resetTime = now + 60
    end

    limiter.count = limiter.count + 1
    return limiter.count <= maxPerMinute
end

serverCloud.registerFunction("getWeatherLimited", function(args, caller)
    local playerId = args._callerId or "unknown"

    if not checkRateLimit(playerId, "weather", 10) then
        caller:Return({ success = false, error = "请求过于频繁，请稍后再试" })
        return
    end

    -- 正常处理请求...
end)
```

---

## 9. 完整示例：动态天气系统

### 服务端

```lua
-- scripts/network/Server.lua
local weatherCache = {}

serverCloud.registerFunction("getGameWeather", function(args, caller)
    local city = args.city or "beijing"
    local cacheKey = "weather_" .. city
    local now = os.time()

    if weatherCache[cacheKey] and (now - weatherCache[cacheKey].time) < 600 then
        caller:Return({ success = true, weather = weatherCache[cacheKey].data })
        return
    end

    local API_KEY = serverCloud.getSecret("WEATHER_KEY")
    local url = "https://api.openweathermap.org/data/2.5/weather?q=" .. city
        .. "&appid=" .. API_KEY .. "&units=metric&lang=zh_cn"

    http:Create()
        :SetUrl(url)
        :SetMethod(HTTP_GET)
        :OnSuccess(function(client, response)
            if response.success then
                local ok, raw = pcall(cjson.decode, response.dataAsString)
                if ok then
                    local weather = {
                        temp = raw.main and raw.main.temp or 20,
                        desc = raw.weather and raw.weather[1] and raw.weather[1].description or "晴",
                        humidity = raw.main and raw.main.humidity or 50,
                        wind = raw.wind and raw.wind.speed or 0,
                    }
                    weatherCache[cacheKey] = { data = weather, time = now }
                    caller:Return({ success = true, weather = weather })
                else
                    caller:Return({ success = false, error = "数据解析失败" })
                end
            else
                caller:Return({ success = false, error = "HTTP " .. response.statusCode })
            end
        end)
        :OnError(function(client, statusCode, error)
            caller:Return({ success = false, error = "网络错误" })
        end)
        :Send()
end)
```

### 客户端

```lua
-- scripts/network/Client.lua
function requestWeather(city)
    clientCloud.callFunction("getGameWeather", { city = city }, function(result)
        if result.success then
            local w = result.weather
            log:Write(LOG_INFO, string.format("天气: %s, 温度: %.1f°C, 湿度: %d%%",
                w.desc, w.temp, w.humidity))
            applyWeatherToScene(w)
        else
            log:Write(LOG_ERROR, "天气获取失败: " .. (result.error or ""))
        end
    end)
end
```

---

## 10. 排查清单

| 现象 | 原因 | 解决 |
|------|------|------|
| 客户端直接 HTTP 请求失败 | 客户端 HTTP 被封禁 | 改用服务端中转 |
| `Module not found: cjson` | 使用了 `require("cjson")` | 去掉 require，cjson 是全局变量 |
| API Key 泄露风险 | 在代码中硬编码了密钥 | 改用 `serverCloud.getSecret()` |
| API 配额快速耗尽 | 未做缓存和频率限制 | 添加缓存层 + 频率限制 |
| JSON 解析报错 | API 返回非 JSON 内容 | 用 `pcall(cjson.decode, ...)` 保护 |
| 请求超时无响应 | API 服务器不可达 | 检查 URL 和网络，添加 OnError 处理 |
| 中文参数乱码 | URL 未编码 | 使用 URL 编码函数处理中文参数 |

---

## 11. 项目结构

```
scripts/
├── main.lua                    # 游戏主入口
├── config/
│   └── api_registry.lua        # API 配置注册表
└── network/
    ├── Shared.lua              # 共享常量
    ├── Server.lua              # 服务端 API 调用
    └── Client.lua              # 客户端请求发起
```

### API 注册表示例

```lua
-- scripts/config/api_registry.lua
local ApiRegistry = {
    weather = {
        secretKey = "WEATHER_API_KEY",
        baseUrl = "https://api.openweathermap.org/data/2.5",
        cacheTTL = 600,
        rateLimit = 10,
    },
    translate = {
        secretKey = "TRANSLATE_API_KEY",
        baseUrl = "https://api.example.com",
        cacheTTL = 86400,
        rateLimit = 30,
    },
}
return ApiRegistry
```

### 构建配置

多人模式必须开启（`.project/settings.json` 中 `@runtime.multiplayer.enabled = true`）。

使用 MCP build 工具构建项目，确保服务端和客户端代码均被正确打包。
