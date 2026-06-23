---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch, type-not-found
--[[
InvestmentSystem.lua - 投资系统
V2.7 P2-6
向星球投资获得长期回报
]]

local InvestmentSystem = {}

-- 投资选项定义（V3.2 P1-4 扩展：新增高级投资）
InvestmentSystem.INVESTMENT_OPTIONS = {
    {
        id = "MINING_BOOST",
        name = "矿业投资",
        desc = "提升该星球矿产产出",
        cost = { metal = 500, esource = 200 },
        duration = 3600,  -- 1小时
        effect = { mineralMult = 1.5 },
        icon = "⛏️",
        tier = 1,
    },
    {
        id = "ENERGY_BOOST",
        name = "能源投资",
        desc = "提升该星球能源产出",
        cost = { metal = 400, esource = 300 },
        duration = 3600,
        effect = { energyMult = 1.5 },
        icon = "⚡",
        tier = 1,
    },
    {
        id = "RESEARCH_BOOST",
        name = "科研投资",
        desc = "提升该星球科研速度",
        cost = { metal = 600, esource = 400, nuclear = 100 },
        duration = 7200,  -- 2小时
        effect = { researchMult = 2.0 },
        icon = "🔬",
        tier = 2,
    },
    {
        id = "TRADE_BOOST",
        name = "贸易投资",
        desc = "提升贸易路线收益",
        cost = { metal = 800, esource = 500 },
        duration = 3600,
        effect = { tradeMult = 1.3 },
        icon = "📦",
        tier = 2,
    },
    {
        id = "DEFENSE_BOOST",
        name = "防御投资",
        desc = "提升该星球防御能力",
        cost = { metal = 1000, esource = 600, nuclear = 200 },
        duration = 7200,
        effect = { defenseMult = 1.5, turretCount = 2 },
        icon = "🛡️",
        tier = 2,
    },
    -- V3.2 新增高级投资（需稀有资源）
    {
        id = "CRYSTAL_MINING",
        name = "晶体矿脉开采",
        desc = "持续产出稀有蓝水晶",
        cost = { metal = 1500, nuclear = 300, blueCrystal = 2 },
        duration = 5400,  -- 1.5h
        effect = { crystalYield = 1.8, blueCrystalPerHour = 3 },
        icon = "💎",
        tier = 3,
    },
    {
        id = "RARE_RESEARCH_CONSORTIUM",
        name = "稀有研究财团",
        desc = "高风险高回报：提升研究速度并产出紫水晶",
        cost = { metal = 2500, esource = 1500, blueCrystal = 5, purpleCrystal = 1 },
        duration = 10800,  -- 3h
        effect = { researchMult = 2.5, purpleCrystalPerHour = 1 },
        icon = "🔭",
        tier = 3,
    },
    {
        id = "GALACTIC_TRADE_HUB",
        name = "银河贸易枢纽",
        desc = "顶级投资：全局贸易收益 +30%，并持续产出彩虹晶",
        cost = { metal = 5000, esource = 3000, nuclear = 800, purpleCrystal = 5 },
        duration = 14400,  -- 4h
        effect = { tradeMult = 1.3, globalResourceMult = 1.1, rainbowCrystalPerHour = 0.5 },
        icon = "🌌",
        tier = 4,
    },
}

-- 开始投资
function InvestmentSystem.startInvestment(planetId, investmentId, playerState, rm)
    local investment = nil
    for _, inv in ipairs(InvestmentSystem.INVESTMENT_OPTIONS) do
        if inv.id == investmentId then investment = inv; break end
    end
    if not investment then return false, "投资选项不存在" end
    
    -- 检查资源
    for res, amount in pairs(investment.cost) do
        if not rm:canAfford(res, amount) then
            return false, "资源不足: " .. (RES_LABELS[res] or res)
        end
    end
    
    -- 消耗资源
    rm:spend(investment.cost)
    
    -- 记录投资
    playerState.investments = playerState.investments or {}
    playerState.investments[planetId] = playerState.investments[planetId] or {}
    
    table.insert(playerState.investments[planetId], {
        id = investmentId,
        name = investment.name,
        effect = investment.effect,
        startTime = os.time(),
        endTime = os.time() + investment.duration,
        duration = investment.duration,
        icon = investment.icon,
    })
    
    return true, "投资成功！将持续 " .. math.floor(investment.duration / 60) .. " 分钟"
end

-- 更新投资状态（每帧调用）
function InvestmentSystem.updateInvestments(dt, playerState)
    if not playerState.investments then return end
    
    local currentTime = os.time()
    for planetId, investments in pairs(playerState.investments) do
        for i = #investments, 1, -1 do
            local inv = investments[i]
            if currentTime > inv.endTime then
                table.remove(investments, i)
            end
        end
        -- 如果星球投资列表为空，清理
        if #investments == 0 then
            playerState.investments[planetId] = nil
        end
    end
end

-- 获取星球投资效果（聚合所有活跃投资）
function InvestmentSystem.getPlanetEffects(planetId, playerState)
    local effects = {}
    
    if playerState.investments and playerState.investments[planetId] then
        for _, inv in ipairs(playerState.investments[planetId]) do
            if os.time() <= inv.endTime then
                for k, v in pairs(inv.effect) do
                    -- 效果累乘
                    if effects[k] then
                        effects[k] = effects[k] * v
                    else
                        effects[k] = v
                    end
                end
            end
        end
    end
    
    return effects
end

-- 获取星球活跃投资列表
function InvestmentSystem.getActiveInvestments(planetId, playerState)
    local active = {}
    
    if playerState.investments and playerState.investments[planetId] then
        for _, inv in ipairs(playerState.investments[planetId]) do
            if os.time() <= inv.endTime then
                table.insert(active, {
                    id = inv.id,
                    name = inv.name,
                    icon = inv.icon,
                    remaining = inv.endTime - os.time(),
                    duration = inv.duration,
                    progress = (inv.endTime - os.time()) / inv.duration,
                })
            end
        end
    end
    
    return active
end

-- 获取投资选项详情
function InvestmentSystem.getInvestmentOption(investmentId)
    for _, inv in ipairs(InvestmentSystem.INVESTMENT_OPTIONS) do
        if inv.id == investmentId then return inv end
    end
    return nil
end

-- 获取所有投资选项列表
function InvestmentSystem.getAllOptions()
    local list = {}
    for _, inv in ipairs(InvestmentSystem.INVESTMENT_OPTIONS) do
        list[#list + 1] = {
            id = inv.id,
            name = inv.name,
            desc = inv.desc,
            cost = inv.cost,
            duration = inv.duration,
            effect = inv.effect,
            icon = inv.icon,
            durationMinutes = math.floor(inv.duration / 60),
        }
    end
    return list
end

-- 检查是否可以投资
function InvestmentSystem.canInvest(planetId, investmentId, playerState, rm)
    local investment = InvestmentSystem.getInvestmentOption(investmentId)
    if not investment then return false, "投资选项不存在" end
    
    -- 检查资源
    for res, amount in pairs(investment.cost) do
        if not rm:canAfford(res, amount) then
            return false, "资源不足: " .. (RES_LABELS[res] or res)
        end
    end
    
    return true, "可以投资"
end

-- 获取星球投资总数
function InvestmentSystem.getPlanetInvestmentCount(planetId, playerState)
    if not playerState.investments or not playerState.investments[planetId] then
        return 0
    end
    return #playerState.investments[planetId]
end

-- 序列化投资数据
function InvestmentSystem.serialize(playerState)
    if not playerState.investments then return nil end
    
    local data = {}
    for planetId, investments in pairs(playerState.investments) do
        data[planetId] = {}
        for _, inv in ipairs(investments) do
            data[planetId][#data[planetId] + 1] = {
                id = inv.id,
                name = inv.name,
                effect = inv.effect,
                startTime = inv.startTime,
                endTime = inv.endTime,
                duration = inv.duration,
                icon = inv.icon,
            }
        end
    end
    return data
end

-- 反序列化投资数据
function InvestmentSystem.deserialize(data, playerState)
    if not data then return end
    
    playerState.investments = {}
    for planetId, investments in pairs(data) do
        playerState.investments[planetId] = {}
        for _, inv in ipairs(investments) do
            playerState.investments[planetId][#playerState.investments[planetId] + 1] = {
                id = inv.id,
                name = inv.name,
                effect = inv.effect,
                startTime = inv.startTime,
                endTime = inv.endTime,
                duration = inv.duration,
                icon = inv.icon,
            }
        end
    end
end

-- ============================================================================
-- V3.2 P1-4: 投资总览与统计
-- ============================================================================

-- 获取全局投资状态总览（用于 UI 面板显示）
function InvestmentSystem.getOverview(playerState)
    local overview = {
        totalInvestments = 0,
        activePlanets = 0,
        globalEffects = {},
        nextExpiringAt = nil,
        nextExpiringName = nil,
        highestTierActive = 0,
    }

    if not playerState.investments then
        return overview
    end

    local now = os.time()
    for planetId, investments in pairs(playerState.investments) do
        local planetActive = false
        for _, inv in ipairs(investments) do
            if now <= inv.endTime then
                overview.totalInvestments = overview.totalInvestments + 1
                planetActive = true

                -- 聚合全局效果
                for effectKey, value in pairs(inv.effect or {}) do
                    if type(value) == "number" then
                        -- 倍数类效果累乘
                        if string.find(effectKey, "Mult") or string.find(effectKey, "Bonus") then
                            overview.globalEffects[effectKey] = (overview.globalEffects[effectKey] or 1.0) * value
                        else
                            -- 其他效果累加
                            overview.globalEffects[effectKey] = (overview.globalEffects[effectKey] or 0) + value
                        end
                    end
                end

                -- 跟踪最高 tier
                local option = InvestmentSystem.getInvestmentOption(inv.id)
                if option and option.tier and option.tier > overview.highestTierActive then
                    overview.highestTierActive = option.tier
                end

                -- 跟踪最近到期的投资
                if overview.nextExpiringAt == nil or inv.endTime < overview.nextExpiringAt then
                    overview.nextExpiringAt = inv.endTime
                    overview.nextExpiringName = inv.name
                end
            end
        end
        if planetActive then
            overview.activePlanets = overview.activePlanets + 1
        end
    end

    return overview
end

-- 获取指定 tier 的投资选项（用于 UI 分层展示）
function InvestmentSystem.getOptionsByTier(tier)
    local list = {}
    for _, inv in ipairs(InvestmentSystem.INVESTMENT_OPTIONS) do
        if inv.tier == tier then
            table.insert(list, {
                id = inv.id,
                name = inv.name,
                desc = inv.desc,
                cost = inv.cost,
                duration = inv.duration,
                durationMinutes = math.floor(inv.duration / 60),
                effect = inv.effect,
                icon = inv.icon,
                tier = inv.tier,
            })
        end
    end
    return list
end

-- 取消某个投资（返还一部分资源）
function InvestmentSystem.cancelInvestment(planetId, index, playerState, rm)
    if not playerState.investments or not playerState.investments[planetId] then
        return false, "无此投资"
    end
    local list = playerState.investments[planetId]
    if index < 1 or index > #list then
        return false, "序号越界"
    end
    local inv = list[index]
    local option = InvestmentSystem.getInvestmentOption(inv.id)
    if not option then return false, "投资类型不存在" end

    -- 按剩余时间比例返还资源（至少 30%）
    local ratio = math.max(0.3, (inv.endTime - os.time()) / inv.duration)
    for res, amount in pairs(option.cost) do
        local refund = math.floor(amount * ratio)
        if rm.addResource then rm:addResource(res, refund)
        elseif rm.addRare and (res == "blueCrystal" or res == "purpleCrystal" or res == "rainbowCrystal") then
            rm:addRare(res, refund)
        end
    end

    table.remove(list, index)
    if #list == 0 then playerState.investments[planetId] = nil end

    return true, "已取消，返还约 " .. math.floor(ratio * 100) .. "% 资源"
end

return InvestmentSystem