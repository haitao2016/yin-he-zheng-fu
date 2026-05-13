# 测试方法论与数据分析

> 如何通过系统化测试验证游戏平衡，以及如何解读测试数据。

---

## 1. 四种测试类型

| 类型 | 人数 | 目的 | 时机 |
|------|------|------|------|
| **内部测试** | 1–3 | 发现严重BUG、基础可玩性 | 每次改动后 |
| **焦点测试** | 5–8 | 深入测试特定系统（经济/难度） | 功能完成后 |
| **开放Beta** | 30+ | 统计显著性、长期平衡 | 发布前 |
| **A/B测试** | 100+（各组50+） | 比较两套数值方案 | 上线后持续优化 |

---

## 2. 测试前准备清单

- [ ] **明确测试目标**：这次测试要验证什么？（如"第5-10关难度是否合理"）
- [ ] **准备观察表**：记录哪些数据？（通关时间、死亡次数、资源使用）
- [ ] **设置埋点代码**：关键行为自动记录
- [ ] **准备不同版本**（A/B测试时）
- [ ] **准备问卷**：测试后让玩家回答的问题

---

## 3. 埋点框架

```lua
-- scripts/balance/analytics.lua

local Analytics = {
    events = {},
}

--- 记录事件
---@param event_name string 事件名
---@param data table 事件数据
function Analytics:log(event_name, data)
    data = data or {}
    data._timestamp = os.time()
    data._event = event_name
    table.insert(self.events, data)
end

--- 常用事件快捷方法

-- 关卡开始
function Analytics:level_start(level_id)
    self:log("level_start", { level = level_id })
end

-- 关卡通过
function Analytics:level_complete(level_id, time_spent, deaths, items_used)
    self:log("level_complete", {
        level = level_id,
        time = time_spent,
        deaths = deaths,
        items = items_used,
    })
end

-- 关卡失败
function Analytics:level_fail(level_id, cause, progress_pct)
    self:log("level_fail", {
        level = level_id,
        cause = cause,
        progress = progress_pct,
    })
end

-- 资源获取
function Analytics:resource_earn(resource_type, amount, source)
    self:log("resource_earn", {
        type = resource_type,
        amount = amount,
        source = source,
    })
end

-- 资源消耗
function Analytics:resource_spend(resource_type, amount, target)
    self:log("resource_spend", {
        type = resource_type,
        amount = amount,
        target = target,
    })
end

-- 玩家退出/流失点
function Analytics:player_quit(level_id, session_time)
    self:log("player_quit", {
        level = level_id,
        session_time = session_time,
    })
end

--- 导出为 JSON 供分析（配合 cjson）
function Analytics:export()
    local ok, cjson = pcall(require, "cjson")
    if ok then
        return cjson.encode(self.events)
    end
    -- 简易序列化
    local lines = {}
    for _, evt in ipairs(self.events) do
        local parts = {}
        for k, v in pairs(evt) do
            table.insert(parts, k .. "=" .. tostring(v))
        end
        table.insert(lines, table.concat(parts, ", "))
    end
    return table.concat(lines, "\n")
end

return Analytics
```

---

## 4. 指标计算模块

```lua
-- scripts/balance/metrics_calculator.lua

local MetricsCalc = {}

--- 计算通关率
---@param attempts integer 总尝试次数
---@param completions integer 成功次数
---@return number completion_rate (0~1)
function MetricsCalc.completion_rate(attempts, completions)
    if attempts == 0 then return 0 end
    return completions / attempts
end

--- 难度指数
---@param completion_rate number 通关率 (0~1)
---@return number difficulty (0~1, 越高越难)
function MetricsCalc.difficulty_index(completion_rate)
    return 1 - completion_rate
end

--- 经济流速
---@param total_spent number 总消耗
---@param total_earned number 总产出
---@return number velocity (健康范围 0.6~0.85)
function MetricsCalc.economy_velocity(total_spent, total_earned)
    if total_earned == 0 then return 0 end
    return total_spent / total_earned
end

--- 参与度斜率（周对比）
---@param this_week_playtime number 本周总游戏时间
---@param last_week_playtime number 上周总游戏时间
---@return number slope (>1 增长, <1 衰减)
function MetricsCalc.engagement_slope(this_week_playtime, last_week_playtime)
    if last_week_playtime == 0 then return 1 end
    return this_week_playtime / last_week_playtime
end

--- 能力-内容比（玩家能力增长 vs 内容难度增长）
---@param power_growth_rate number 玩家能力增长率
---@param content_difficulty_rate number 内容难度增长率
---@return number ratio (理想值 0.9~1.1)
function MetricsCalc.power_to_content_ratio(power_growth_rate, content_difficulty_rate)
    if content_difficulty_rate == 0 then return 1 end
    return power_growth_rate / content_difficulty_rate
end

return MetricsCalc
```

---

## 5. 数据解读框架

### 5.1 三步解读法

对每项指标数据，依次回答三个问题：

1. **是否偏离健康范围？** → 对照下表
2. **影响了多少玩家？** → 看百分比而非绝对数
3. **影响严重程度？** → 影响核心循环 > 影响辅助系统

### 5.2 健康范围参考表

| 指标 | 健康范围 | 偏低含义 | 偏高含义 |
|------|---------|---------|---------|
| 通关率 | 0.40 – 0.85 | 太难，降低难度 | 太简单，增加挑战 |
| 首次通关时间方差 | < 均值×1.5 | 玩家水平接近（好） | 差异大，需要难度分层 |
| 经济流速 | 0.60 – 0.85 | 没消耗项，增加水槽 | 太缺钱，增加水龙头 |
| 参与度斜率 | 0.90 – 1.20 | 流失加速，找原因 | 增长中（好） |
| 能力-内容比 | 0.90 – 1.10 | 玩家被内容超越 | 玩家碾压内容 |
| 每关卡平均死亡数 | 1 – 5 | 太简单 | 太难（教学关除外） |
| 平均会话时长 | 10 – 40 分钟 | 无聊/不吸引 | 上瘾风险（考虑防沉迷） |

### 5.3 常见发现与应对

| 发现 | 诊断 | 应对 |
|------|------|------|
| 通关率从第7关骤降 | 难度跳跃 | 在6-7关间插入过渡关 |
| 90%玩家不买X物品 | 定价过高或无用 | 降价30%或增强效果 |
| 硬核玩家30天后流失 | 内容耗尽 | 增加 endgame 内容或转生循环 |
| 新手2分钟内退出 | 教学失败 | 简化前3个操作步骤 |
| 经济流速逐周下降 | 通胀/资源囤积 | 增加新的消耗项 |
| 同一Boss死亡50+次 | Boss过难 | 提供可选的简单模式或降低10%数值 |

---

## 6. 平衡调整流程（7步法）

```
1. 收集数据
   ↓
2. 识别异常指标（偏离健康范围）
   ↓
3. 分析根因（为什么偏离？）
   ↓
4. 设计调整方案（单次变动 ≤ 15%）
   ↓
5. 在测试环境验证
   ↓
6. 小范围推送（A/B测试或灰度）
   ↓
7. 监控调整后指标（至少观察3天）
```

### 调整幅度参考

| 偏离程度 | 建议调整幅度 | 示例 |
|---------|------------|------|
| 轻微（指标偏离 5-15%） | ±5% | 敌人HP从1000改为950 |
| 中等（指标偏离 15-30%） | ±10% | 掉落率从5%改为5.5% |
| 严重（指标偏离 > 30%） | ±15% | 关卡时间限制从60秒改为70秒 |

**核心原则**：每次只改一个变量，否则无法确定哪个改动起了作用。

---

## 7. 测试后问卷模板

### 通用问题（每次必问）

1. **你觉得游戏整体难度如何？**（1=太简单 ~ 5=太难）
2. **你在哪个位置感到最沮丧？**（开放性回答）
3. **你觉得获得奖励的速度如何？**（1=太慢 ~ 5=太快）
4. **你最想在游戏中买什么？**（开放性回答）
5. **如果要给这个游戏打分（1-10），你打几分？**

### 特定系统问题（按需添加）

**经济系统**：
- 你是否觉得金币够用？
- 你买过最贵的物品是什么？感觉值吗？

**难度曲线**：
- 哪一关让你重试了3次以上？
- 你觉得游戏变难的速度合理吗？

**掉落系统**：
- 你是否获得了想要的物品？等了多久？
- 你觉得稀有物品出现频率合理吗？
