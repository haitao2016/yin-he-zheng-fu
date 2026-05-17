# Web API 分类目录

> 12 大类 API 的服务商推荐、免费额度和服务端代码模板。

---

## 1. 天气 API

**游戏应用**：动态天气系统、环境氛围切换、天气影响玩法

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| OpenWeatherMap | 1000 次/天 | 全球覆盖，英文为主 |
| 和风天气 | 1000 次/天 | 中国城市精准，中文 |
| 心知天气 | 400 次/小时 | 分钟级预报 |

```lua
-- scripts/network/Server.lua
serverCloud.registerFunction("getWeather", function(args, caller)
    local API_KEY = serverCloud.getSecret("WEATHER_KEY")
    local city = args.city or "beijing"
    http:Create()
        :SetUrl("https://api.openweathermap.org/data/2.5/weather?q=" .. city
            .. "&appid=" .. API_KEY .. "&units=metric&lang=zh_cn")
        :SetMethod(HTTP_GET)
        :OnSuccess(function(client, response)
            if response.success then
                local ok, data = pcall(cjson.decode, response.dataAsString)
                if ok then
                    caller:Return({ success = true, data = data })
                else
                    caller:Return({ success = false, error = "解析失败" })
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

**推荐缓存**: 5-15 分钟

---

## 2. 翻译 API

**游戏应用**：多语言聊天实时翻译、游戏内容本地化、NPC 对话翻译

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| 百度翻译 | 标准版免费 | 200+ 语种，中文优化 |
| DeepL | 50 万字符/月 | 翻译质量高 |
| 有道翻译 | 限量免费 | 中文生态好 |

```lua
serverCloud.registerFunction("translate", function(args, caller)
    local API_KEY = serverCloud.getSecret("TRANSLATE_KEY")
    local body = cjson.encode({
        q = args.text, from = args.from or "auto", to = args.to or "en"
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
                    caller:Return({ success = true, result = data.translation })
                else
                    caller:Return({ success = false, error = "解析失败" })
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

**推荐缓存**: 永久（相同输入输出不变）

---

## 3. 新闻/内容 API

**游戏应用**：游戏内新闻公告、世界事件驱动剧情、信息滚动条

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| NewsAPI | 100 次/天 | 全球新闻聚合 |
| 聚合数据 | 限量免费 | 国内综合数据 |
| 天行数据 | 部分免费 | 中文内容丰富 |

**推荐缓存**: 10-30 分钟

---

## 4. 地图/地理 API

**游戏应用**：LBS 地理围栏玩法、POI 搜索、路线规划、AR 定位

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| 高德地图 | 5000 次/天 | 国内定位精准 |
| 百度地图 | 限量免费 | 生态完善 |
| Mapbox | 100K 次/月 | 自定义地图样式 |

**推荐缓存**: 24 小时+（地理数据极少变化）

---

## 5. 支付 API

**游戏应用**：虚拟物品购买、会员充值、打赏系统

| 服务商 | 费率 | 特点 |
|--------|------|------|
| 支付宝 | 0.6% | 国内主流 |
| 微信支付 | 0.6% | 社交支付 |

> 支付涉及资金安全，必须严格服务端校验，不可信任客户端数据。

**推荐缓存**: 不缓存（每次校验）

---

## 6. 汇率/金融 API

**游戏应用**：模拟经营汇率波动、虚拟股票交易、经济系统

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| ExchangeRate-API | 1500 次/月 | 160+ 货币 |
| Fixer.io | 100 次/月 | 欧洲央行数据 |
| Open Exchange Rates | 1000 次/月 | 美元基准 |

**推荐缓存**: 1-6 小时

---

## 7. 体育/赛事 API

**游戏应用**：赛事竞猜、实时比分、赛季数据

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| Football-Data | 10 次/分钟 | 欧洲足球联赛 |
| API-Football | 100 次/天 | 全球足球数据 |

**推荐缓存**: 1-5 分钟（比赛中实时）

---

## 8. 图像处理 API

**游戏应用**：玩家头像美化、游戏截图处理、图片压缩

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| TinyPNG | 500 张/月 | 无损压缩 |
| 阿里云 OSS 图片处理 | 按量计费 | 功能全面 |
| Remove.bg | 50 张/月 | 背景移除 |

**推荐缓存**: 永久（处理结果不变）

---

## 9. 短信/推送 API

**游戏应用**：验证码登录、活动推送、好友邀请

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| 阿里云短信 | 按量计费 | 国内三网覆盖 |
| 极光推送 | 免费版可用 | 推送 + 短信 |

**推荐缓存**: 不缓存

---

## 10. 音频/语音 API

**游戏应用**：语音转文字指令、TTS 播报、语音消息

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| 讯飞语音 | 限量免费 | 中文识别率高 |
| 百度语音 | 限量免费 | 实时转写 |

**推荐缓存**: TTS 结果永久缓存，识别结果不缓存

---

## 11. 搜索 API

**游戏应用**：游戏内百科查询、物品搜索、知识问答

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| Bing Search | 1000 次/月 | 全球搜索 |

**推荐缓存**: 1-24 小时

---

## 12. 社交/通信 API

**游戏应用**：好友系统、邮件通知、社区互动

| 服务商 | 免费额度 | 特点 |
|--------|---------|------|
| SendGrid | 100 封/天 | 邮件服务 |

**推荐缓存**: 不缓存

---

## 通用工具函数

### URL 编码

```lua
-- scripts/network/Server.lua
local function urlEncode(str)
    str = string.gsub(str, "([^%w%-%.%_%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

-- 使用示例
local city = urlEncode("北京")
local url = "https://api.example.com/weather?city=" .. city
```

### 超时处理建议

大部分外部 API 的响应时间在 200ms-2s 之间。如果超过 5 秒无响应，通常是网络问题。
建议在客户端添加超时提示，避免用户等待过久。

### 费用控制

1. **缓存优先**：参考各类别推荐的缓存 TTL
2. **频率限制**：参考 SKILL.md 第 8 节的 rateLimiter 实现
3. **监控用量**：定期检查 API 服务商控制台的调用量
4. **降级方案**：API 不可用时使用默认数据
