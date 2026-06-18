---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- game/systems/SeasonExpansionSystem.lua -- V3.0 赛季内容扩展
-- SEASON_VARIANTS: THEME_PIRATE / THEME_TECH / THEME_CRISIS / THEME_ALLIANCE
-- LIMITED_SEASONS: WEEKLY_BLITZ / FORTNIGHT_CHALLENGE / MONTHLY_MARATHON
-- ============================================================================

local SeasonExpansionSystem = {}

-- ============================================================================
-- 赛季变体全局表
-- ============================================================================

SEASON_VARIANTS = {
    {
        id = "THEME_PIRATE",
        name = "海盗时代",
        nameEn = "Pirate Age",
        description = "敌舰数量激增 30%，海盗事件频率加倍，但击败奖励 +50%。适合追求高风险高回报的指挥官。",
        duration = 14,
        effectMods = {
            enemyShipCountMult = 1.30,
            pirateEventFreqMult = 2.0,
            battleRewardMult    = 1.50,
        },
        exclusiveRewards = {
            pirateFlagshipSkin = true,
            goldBountyCache    = 5,
        },
    },

    {
        id = "THEME_TECH",
        name = "科技革命",
        nameEn = "Tech Revolution",
        description = "研究速度 +50%，新科技解锁加速，科技奖励加倍。适合专注科研发展的指挥官。",
        duration = 14,
        effectMods = {
            researchSpeedMult  = 1.50,
            techUnlockSpeedMult = 1.50,
            techRewardMult     = 2.0,
        },
        exclusiveRewards = {
            quantumCoreBlueprint = true,
            techDataCache        = 10,
        },
    },

    {
        id = "THEME_CRISIS",
        name = "资源危机",
        nameEn = "Resource Crisis",
        description = "资源产出 -25%，但所有交易价值 +30%，挑战任务奖励加倍。适合贸易与挑战型指挥官。",
        duration = 14,
        effectMods = {
            resourceProductionMult = 0.75,
            tradeValueMult         = 1.30,
            challengeRewardMult    = 2.0,
        },
        exclusiveRewards = {
            crisisMerchantLicense = true,
            rareResourceCache     = 8,
        },
    },

    {
        id = "THEME_ALLIANCE",
        name = "联盟纪元",
        nameEn = "Alliance Era",
        description = "公会贡献 +50%，好友支援冷却减半，社交类任务奖励加倍。适合合作与公会活动指挥官。",
        duration = 14,
        effectMods = {
            guildContributionMult = 1.50,
            friendSupportCooldownMult = 0.5,
            socialRewardMult      = 2.0,
        },
        exclusiveRewards = {
            allianceMedal       = true,
            guildSupplyCache    = 12,
        },
    },
}

-- ============================================================================
-- 限时赛季全局表
-- ============================================================================

LIMITED_SEASONS = {
    {
        id = "WEEKLY_BLITZ",
        name = "每周闪电战",
        nameEn = "Weekly Blitz",
        description = "为期 3 天的限时挑战，在限定时间内击败尽可能多的敌舰获取丰厚奖励。",
        duration = 3,
        effectMods = {
            enemySpawnRateMult = 1.8,
            blitzPointsMult    = 2.0,
        },
        exclusiveRewards = { blitzBadge = true },
        schedule = { type = "WEEKLY", days = { 5, 6, 7 } },
    },
    {
        id = "FORTNIGHT_CHALLENGE",
        name = "双周挑战",
        nameEn = "Fortnight Challenge",
        description = "为期 14 天的中等长度赛季，包含主线目标与每日任务，奖励紫晶与彩虹晶。",
        duration = 14,
        effectMods = {
            missionRewardMult   = 1.5,
            dailyObjectiveMult = 2.0,
        },
        exclusiveRewards = { fortnightBanner = true },
        schedule = { type = "FORTNIGHT", startDayOfMonth = 1 },
    },
    {
        id = "MONTHLY_MARATHON",
        name = "月度马拉松",
        nameEn = "Monthly Marathon",
        description = "为期 30 天的超长赛季，目标是积累大量赛季积分，完成后解锁独特称号与外观。",
        duration = 30,
        effectMods = {
            pointsGainMult     = 1.2,
            longTermRewardMult = 2.5,
        },
        exclusiveRewards = { marathonTitle = true, marathonAvatarFrame = true },
        schedule = { type = "MONTHLY", startDayOfMonth = 1 },
    },
}

-- ============================================================================
-- 索引表
-- ============================================================================

local VARIANT_BY_ID = {}
for _, v in ipairs(SEASON_VARIANTS) do VARIANT_BY_ID[v.id] = v end

local LIMITED_BY_ID = {}
for _, v in ipairs(LIMITED_SEASONS) do LIMITED_BY_ID[v.id] = v end

-- ============================================================================
-- 运行时状态
-- ============================================================================

local RuntimeState = {
    currentVariantId = nil,
    startedAt = 0,
    endsAt = 0,
    seasonPoints = 0,
    claimedMilestones = {},
}

-- ============================================================================
-- 主题操作
-- ============================================================================

--- 设置当前赛季主题
---@param themeId string @ SEASON_VARIANTS 中的 id
---@param seasonState table|nil @ 可选，用于覆盖默认状态
---@return boolean, string
function SeasonExpansionSystem.setTheme(themeId, seasonState)
    local variant = VARIANT_BY_ID[themeId]
    if not variant then return false, "未知主题: " .. tostring(themeId) end

    if seasonState and type(seasonState) == "table" then
        for k, v in pairs(seasonState) do RuntimeState[k] = v end
    end

    RuntimeState.currentVariantId = themeId
    RuntimeState.startedAt = os.time()
    RuntimeState.endsAt = os.time() + (variant.duration or 14) * 86400
    RuntimeState.seasonPoints = RuntimeState.seasonPoints or 0
    RuntimeState.claimedMilestones = RuntimeState.claimedMilestones or {}

    print(string.format("[SeasonExpansion] 激活主题: %s (持续 %d 天)", variant.name, variant.duration))
    return true, "主题已激活"
end

--- 获取当前生效的效果修正表
---@param seasonState table|nil
---@return table
function SeasonExpansionSystem.getThemeMods(seasonState)
    local variant = nil
    if seasonState and seasonState.currentVariantId then
        variant = VARIANT_BY_ID[seasonState.currentVariantId]
    elseif RuntimeState.currentVariantId then
        variant = VARIANT_BY_ID[RuntimeState.currentVariantId]
    end
    if not variant then return {} end
    return variant.effectMods or {}
end

--- 获取所有可用的赛季主题定义
---@return table
function SeasonExpansionSystem.getAvailableThemes()
    return SEASON_VARIANTS
end

--- 根据当前日期返回应激活的限时赛季
---@param today table|nil @ os.date("*t") 格式；不提供则使用当前时间
---@return table|nil @ 匹配的 LIMITED_SEASONS 条目
function SeasonExpansionSystem.getLimitedSeason(today)
    today = today or os.date("*t")
    local wday = today.wday or 1
    local dayOfMonth = today.day or 1

    for _, ls in ipairs(LIMITED_SEASONS) do
        local s = ls.schedule or {}
        if s.type == "WEEKLY" and s.days then
            for _, d in ipairs(s.days) do
                if wday == d then return ls end
            end
        elseif s.type == "FORTNIGHT" then
            if dayOfMonth == (s.startDayOfMonth or 1) or dayOfMonth == (s.startDayOfMonth or 1) + 14 then
                return ls
            end
        elseif s.type == "MONTHLY" then
            if dayOfMonth == (s.startDayOfMonth or 1) then
                return ls
            end
        end
    end
    return nil
end

-- ============================================================================
-- 奖励曲线
-- ============================================================================

--- 平滑奖励曲线：根据赛季积分返回预期奖励倍率（使用 Sigmoid 平滑）
---@param seasonPoints number
---@return number @ 0.0 ~ 3.0 的奖励倍率
function SeasonExpansionSystem.calculateRewardCurve(seasonPoints)
    seasonPoints = tonumber(seasonPoints) or 0
    if seasonPoints <= 0 then return 0.5 end

    -- Sigmoid 函数: 1 / (1 + exp(-x)) -> 平滑 S 形曲线
    -- 归一化: 每 5000 分提升一个档位，封顶 ~3.0
    local x = (seasonPoints / 5000) - 2
    local sigmoid = 1 / (1 + math.exp(-x))
    local curve = 0.5 + sigmoid * 2.5

    return math.max(0.5, math.min(3.0, curve))
end

-- ============================================================================
-- 当前变体
-- ============================================================================

--- 获取当前激活的变体完整信息
---@param seasonState table|nil
---@return table|nil, string
function SeasonExpansionSystem.getCurrentVariant(seasonState)
    local variantId = nil
    if seasonState and seasonState.currentVariantId then
        variantId = seasonState.currentVariantId
    else
        variantId = RuntimeState.currentVariantId
    end

    if not variantId then return nil, "当前无激活主题" end

    local variant = VARIANT_BY_ID[variantId] or LIMITED_BY_ID[variantId]
    return variant, variant and "" or "变体定义不存在"
end

-- ============================================================================
-- 积分 / 里程碑
-- ============================================================================

--- 增加赛季积分
---@param amount number
function SeasonExpansionSystem.addPoints(amount)
    amount = tonumber(amount) or 0
    RuntimeState.seasonPoints = (RuntimeState.seasonPoints or 0) + amount
    return RuntimeState.seasonPoints
end

--- 获取当前赛季积分
function SeasonExpansionSystem.getPoints()
    return RuntimeState.seasonPoints or 0
end

-- ============================================================================
-- 序列化 / 反序列化
-- ============================================================================

function SeasonExpansionSystem.serialize()
    return {
        currentVariantId = RuntimeState.currentVariantId,
        startedAt = RuntimeState.startedAt,
        endsAt = RuntimeState.endsAt,
        seasonPoints = RuntimeState.seasonPoints,
        claimedMilestones = RuntimeState.claimedMilestones,
    }
end

function SeasonExpansionSystem.deserialize(data)
    if not data or type(data) ~= "table" then return end
    RuntimeState.currentVariantId = data.currentVariantId
    RuntimeState.startedAt = data.startedAt or 0
    RuntimeState.endsAt = data.endsAt or 0
    RuntimeState.seasonPoints = data.seasonPoints or 0
    RuntimeState.claimedMilestones = data.claimedMilestones or {}
end

return SeasonExpansionSystem
