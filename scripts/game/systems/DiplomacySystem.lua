---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
-- ============================================================================
-- DiplomacySystem: 中立势力外交系统
-- 拆分自 Systems.lua（纯机械迁移，无逻辑修改）
-- ============================================================================

--- 三种中立势力定义
local NEUTRAL_FACTIONS = {
    trade_union   = { name = "商业联盟", icon = "💰", giftCost = { metal = 80, esource = 50 },
                      tradeInterval = 60, tradeGain = { metal = 30, esource = 20 },
                      color = { 255, 200, 80 } },
    star_guild    = { name = "星际工会", icon = "⚙️",  giftCost = { metal = 60, esource = 80 },
                      tradeInterval = 60, tradeGain = { metal = 20, esource = 35 },
                      color = { 100, 200, 255 } },
    relic_keeper  = { name = "遗迹守护者", icon = "🏛️", giftCost = { metal = 100, esource = 30 },
                      tradeInterval = 60, tradeGain = { metal = 50, esource = 10 },
                      color = { 180, 120, 255 } },
}

local GIFT_FAVOR          = 20    -- 每次礼物 +20 好感
local WAR_THRESHOLD       = 0     -- 好感 < 0 → 宣战
local TRADE_THRESHOLD     = 60    -- 好感 ≥ 60 → 商贸协议
local MILITARY_THRESHOLD  = 90    -- 好感 ≥ 90 → 军事合作
-- P2-2: 长期贸易协议
local LONG_TRADE_THRESHOLD   = 60     -- 好感 ≥ 60 才可激活
local LONG_TRADE_BREAK_FAVOR = 40     -- 好感 < 40 时协议中断
local LONG_TRADE_COST        = { crystal = 100 }  -- 激活费用
local LONG_TRADE_INTERVAL    = 60     -- 每 60s 自动购入一次特产
local LONG_TRADE_DISCOUNT    = 0.20   -- 低于市价 20%
local MAX_LONG_TRADES        = 3      -- 同时最多 3 个协议

-- P1-1 V2.4: 三角博弈 & 新协议常量
local INTEL_THRESHOLD     = 40   -- 情报共享解锁
local ALLIANCE_THRESHOLD  = 75   -- 军事同盟解锁
local BLOCKADE_THRESHOLD  = 50   -- 封锁禁令解锁
local MEDIATE_THRESHOLD   = 60   -- 调停斡旋解锁
local TRIANGLE_PENALTY    = 5    -- 好感>70时竞争对手每次 -5
local TRIANGLE_TRIGGER    = 70   -- 触发三角博弈的好感阈值
local BLOCKADE_COST       = { crystal = 300 }
local MEDIATE_COST        = { metal = 500 }
local BLOCKADE_DURATION   = 180  -- 封锁持续 180s
local DIPLO_EVENT_INTERVAL = 180 -- 外交事件间隔 180s

-- 三角关系类型
local REL_COMPETE  = "compete"
local REL_NEUTRAL  = "neutral"
local REL_COOPERATE = "cooperate"

local DiplomacySystem = {}
DiplomacySystem.__index = DiplomacySystem

--- 创建外交系统（每局游戏一个实例）
function DiplomacySystem.new()
    local self = setmetatable({}, DiplomacySystem)
    -- planetId → { factionKey, favor(0-100), tradeTimer, atWar, military }
    self.planets = {}
    -- P1-1: 三角关系（两两之间：compete/neutral/cooperate）
    self.triangleRels = {}  -- { "trade_union:star_guild" = "compete", ... }
    -- P1-1: 新协议状态
    self.alliances   = {}   -- { factionKey = true } 军事同盟
    self.blockades   = {}   -- { factionKey = remainTime } 封锁中
    self.intelShares = {}   -- { factionKey = true } 情报共享
    -- P1-1: 外交事件计时器
    self.diploEventTimer = 0
    return self
end

--- 随机为未殖民星球分配中立势力标签（开局时调用）
---@param allPlanets table  GalaxyScene.GetAllPlanets() 结果
---@param ratio      number  0-1，随机标记比例（默认 0.35）
function DiplomacySystem:initFactions(allPlanets, ratio)
    ratio = ratio or 0.35
    local keys = { "trade_union", "star_guild", "relic_keeper" }
    for _, p in ipairs(allPlanets) do
        if not p.isBase and not p.colonized then
            if math.random() < ratio then
                local fk = keys[math.random(1, #keys)]
                self.planets[p.id] = {
                    factionKey      = fk,
                    favor           = 40,    -- 初始好感度 40（中立）
                    tradeTimer      = 0,
                    atWar           = false,
                    military        = false,
                    longTrade       = false, -- P2-2: 长期贸易协议是否激活
                    longTradeTimer  = 0,     -- P2-2: 协议自动购入计时
                }
                p.neutralFaction = fk    -- 在行星对象上打标记，渲染用
            end
        end
    end
    -- P1-1: 初始化三角关系
    self:initTriangleRelations()
end

-- P1-1: 生成两两派系间的随机关系
function DiplomacySystem:initTriangleRelations()
    local keys = { "trade_union", "star_guild", "relic_keeper" }
    local rels = { REL_COMPETE, REL_NEUTRAL, REL_COOPERATE }
    -- 随机打乱关系分配（保证每种关系恰好出现一次）
    for i = #rels, 2, -1 do
        local j = math.random(1, i)
        rels[i], rels[j] = rels[j], rels[i]
    end
    local idx = 1
    for i = 1, #keys do
        for j = i + 1, #keys do
            local pairKey = keys[i] .. ":" .. keys[j]
            self.triangleRels[pairKey] = rels[idx]
            idx = idx + 1
        end
    end
end

--- P1-1: 获取两派系间关系
---@param fk1 string
---@param fk2 string
---@return string  "compete"|"neutral"|"cooperate"
function DiplomacySystem:getRelation(fk1, fk2)
    if fk1 == fk2 then return REL_COOPERATE end
    local k1 = fk1 .. ":" .. fk2
    local k2 = fk2 .. ":" .. fk1
    return self.triangleRels[k1] or self.triangleRels[k2] or REL_NEUTRAL
end

--- P1-1: 获取所有三角关系（UI用）
---@return table { {fk1, fk2, rel}, ... }
function DiplomacySystem:getAllRelations()
    local list = {}
    for pairKey, rel in pairs(self.triangleRels) do
        local fk1, fk2 = pairKey:match("^(.+):(.+)$")
        if fk1 then
            list[#list+1] = { fk1 = fk1, fk2 = fk2, rel = rel }
        end
    end
    return list
end

--- P1-1: 获取指定势力的竞争对手（compete关系）
---@param factionKey string
---@return string|nil  竞争对手factionKey
function DiplomacySystem:getCompetitor(factionKey)
    local keys = { "trade_union", "star_guild", "relic_keeper" }
    for _, fk in ipairs(keys) do
        if fk ~= factionKey and self:getRelation(factionKey, fk) == REL_COMPETE then
            return fk
        end
    end
    return nil
end

--- P1-1: 三角博弈——好感>70时自动降低竞争对手好感
---@param factionKey string  刚提升好感的势力
---@param newFavor   number  提升后的好感值
function DiplomacySystem:applyTrianglePenalty(factionKey, newFavor)
    if newFavor <= TRIANGLE_TRIGGER then return end
    local competitor = self:getCompetitor(factionKey)
    if not competitor then return end
    -- 降低竞争对手在所有星球的好感
    for _, st in pairs(self.planets) do
        if st.factionKey == competitor and not st.atWar then
            st.favor = math.max(0, st.favor - TRIANGLE_PENALTY)
        end
    end
end

-- P1-1: 新协议 API ============================================================

--- 情报共享（好感≥40）：揭示下一波海盗方向
---@param factionKey string
---@return boolean, string
function DiplomacySystem:activateIntel(factionKey)
    if self.intelShares[factionKey] then return false, "情报共享已激活" end
    -- 检查好感（任意该势力星球达标即可）
    local maxFavor = 0
    for _, st in pairs(self.planets) do
        if st.factionKey == factionKey and not st.atWar then
            maxFavor = math.max(maxFavor, st.favor)
        end
    end
    if maxFavor < INTEL_THRESHOLD then
        return false, string.format("好感不足（需%d，当前最高%d）", INTEL_THRESHOLD, maxFavor)
    end
    self.intelShares[factionKey] = true
    local fd = NEUTRAL_FACTIONS[factionKey]
    return true, string.format("🔍 与 %s 签订情报共享！可预知海盗进攻方向", fd and fd.name or "?")
end

--- 军事同盟（好感≥75）：Boss波派援军，其他势力-10
---@param factionKey string
---@return boolean, string
function DiplomacySystem:activateAlliance(factionKey)
    if self.alliances[factionKey] then return false, "军事同盟已建立" end
    local maxFavor = 0
    for _, st in pairs(self.planets) do
        if st.factionKey == factionKey and not st.atWar then
            maxFavor = math.max(maxFavor, st.favor)
        end
    end
    if maxFavor < ALLIANCE_THRESHOLD then
        return false, string.format("好感不足（需%d，当前最高%d）", ALLIANCE_THRESHOLD, maxFavor)
    end
    self.alliances[factionKey] = true
    -- 其他势力好感-10
    for _, st in pairs(self.planets) do
        if st.factionKey ~= factionKey and not st.atWar then
            st.favor = math.max(0, st.favor - 10)
        end
    end
    local fd = NEUTRAL_FACTIONS[factionKey]
    return true, string.format("⚔ 与 %s 结成军事同盟！Boss战将获援军，但其他势力好感-10", fd and fd.name or "?")
end

--- 封锁禁令（好感≥50，花费300晶体）：目标势力黑市货物消失180s
---@param factionKey string  发起封锁的己方盟友势力
---@param targetKey  string  被封锁的目标势力
---@param rm         table   ResourceManager
---@return boolean, string
function DiplomacySystem:activateBlockade(factionKey, targetKey, rm)
    if self.blockades[targetKey] and self.blockades[targetKey] > 0 then
        return false, "该势力已在封锁中"
    end
    local maxFavor = 0
    for _, st in pairs(self.planets) do
        if st.factionKey == factionKey and not st.atWar then
            maxFavor = math.max(maxFavor, st.favor)
        end
    end
    if maxFavor < BLOCKADE_THRESHOLD then
        return false, string.format("好感不足（需%d，当前最高%d）", BLOCKADE_THRESHOLD, maxFavor)
    end
    if not rm:canAfford(BLOCKADE_COST) then
        return false, string.format("晶体不足（需%d）", BLOCKADE_COST.crystal)
    end
    rm:spend(BLOCKADE_COST)
    self.blockades[targetKey] = BLOCKADE_DURATION
    local fd = NEUTRAL_FACTIONS[targetKey]
    return true, string.format("🚫 对 %s 发起贸易封锁！黑市该势力货物消失%ds", fd and fd.name or "?", BLOCKADE_DURATION)
end

--- 调停斡旋（好感≥60，花费500金属）：修复两势力关系，双方+5
---@param fk1 string
---@param fk2 string
---@param rm  table
---@return boolean, string
function DiplomacySystem:activateMediation(fk1, fk2, rm)
    local rel = self:getRelation(fk1, fk2)
    if rel ~= REL_COMPETE then return false, "只能调停竞争关系的势力" end
    -- 检查发起方好感
    local maxFavor = 0
    for _, st in pairs(self.planets) do
        if (st.factionKey == fk1 or st.factionKey == fk2) and not st.atWar then
            maxFavor = math.max(maxFavor, st.favor)
        end
    end
    if maxFavor < MEDIATE_THRESHOLD then
        return false, string.format("好感不足（需%d，当前最高%d）", MEDIATE_THRESHOLD, maxFavor)
    end
    if not rm:canAfford(MEDIATE_COST) then
        return false, string.format("金属不足（需%d）", MEDIATE_COST.metal)
    end
    rm:spend(MEDIATE_COST)
    -- 修改关系为中立
    local k1 = fk1 .. ":" .. fk2
    local k2 = fk2 .. ":" .. fk1
    if self.triangleRels[k1] then self.triangleRels[k1] = REL_NEUTRAL
    elseif self.triangleRels[k2] then self.triangleRels[k2] = REL_NEUTRAL end
    -- 双方好感+5
    for _, st in pairs(self.planets) do
        if st.factionKey == fk1 or st.factionKey == fk2 then
            st.favor = math.min(100, st.favor + 5)
        end
    end
    local fd1 = NEUTRAL_FACTIONS[fk1]
    local fd2 = NEUTRAL_FACTIONS[fk2]
    return true, string.format("🕊 调停成功！%s 与 %s 关系缓和→中立，双方好感+5",
        fd1 and fd1.name or "?", fd2 and fd2.name or "?")
end

--- P1-1: 检查某势力是否被封锁中
---@param factionKey string
---@return boolean
function DiplomacySystem:isBlockaded(factionKey)
    return self.blockades[factionKey] and self.blockades[factionKey] > 0
end

--- P1-1: 是否有与某势力的军事同盟
---@param factionKey string
---@return boolean
function DiplomacySystem:hasAlliance(factionKey)
    return self.alliances[factionKey] == true
end

--- P1-1: 是否有与某势力的情报共享
---@param factionKey string
---@return boolean
function DiplomacySystem:hasIntel(factionKey)
    return self.intelShares[factionKey] == true
end

--- P1-1: 获取所有新协议状态（UI展示用）
---@return table
function DiplomacySystem:getAgreements()
    return {
        alliances   = self.alliances,
        blockades   = self.blockades,
        intelShares = self.intelShares,
    }
end

--- 获取某行星的外交状态，无则返回 nil
---@param planetId number
---@return table|nil
function DiplomacySystem:getState(planetId)
    return self.planets[planetId]
end

--- 获取势力定义
---@param factionKey string
---@return table
function DiplomacySystem.getFactionDef(factionKey)
    return NEUTRAL_FACTIONS[factionKey]
end

--- 玩家送出外交礼物：扣资源、增好感
---@param planetId number
---@param rm       table
---@return boolean success, string msg
function DiplomacySystem:sendGift(planetId, rm)
    local st = self.planets[planetId]
    if not st then return false, "该星球无中立势力" end
    if st.atWar  then return false, "宣战中，无法外交" end
    local fd = NEUTRAL_FACTIONS[st.factionKey]
    if not fd then return false, "未知势力" end
    -- 扣除资源
    local cost = fd.giftCost
    if rm:get("metal") < cost.metal or rm:get("esource") < cost.esource then
        return false, string.format("资源不足（需金属%d 能源%d）", cost.metal, cost.esource)
    end
    rm:add("metal",   -cost.metal)
    rm:add("esource", -cost.esource)
    -- 增加好感
    st.favor = math.min(100, st.favor + GIFT_FAVOR)
    -- P1-1: 三角博弈——好感超过阈值时惩罚竞争对手
    self:applyTrianglePenalty(st.factionKey, st.favor)
    -- 检查新解锁
    if st.favor >= MILITARY_THRESHOLD then
        st.military = true
    end
    local msg = string.format("%s好感 +%d → %d", fd.name, GIFT_FAVOR, st.favor)
    if st.favor >= MILITARY_THRESHOLD and not st.military then
        msg = msg .. "  🤝军事合作已解锁！"
    elseif st.favor >= TRADE_THRESHOLD then
        msg = msg .. "  📦商贸协议已激活"
    end
    return true, msg
end

--- 每秒 tick：处理商贸自动收益 + 宣战衰减
---@param dt     number  时间步长（秒）
---@param rm     table
---@param allPlanets table
---@return table events  { {type="trade"|"war", planetId, factionKey, gain} }
function DiplomacySystem:tick(dt, rm, allPlanets)
    local events = {}
    -- 行星 id → 对象 快查
    local pmap = {}
    for _, p in ipairs(allPlanets or {}) do pmap[p.id] = p end

    for pid, st in pairs(self.planets) do
        if st.atWar then
            -- 宣战中好感持续衰减（每5s -1）
            st.tradeTimer = (st.tradeTimer or 0) + dt
            if st.tradeTimer >= 5 then
                st.tradeTimer = 0
                st.favor = math.max(-20, st.favor - 1)
            end
        else
            if st.favor >= TRADE_THRESHOLD then
                -- 商贸协议自动收益
                local fd = NEUTRAL_FACTIONS[st.factionKey]
                if fd then
                    st.tradeTimer = (st.tradeTimer or 0) + dt
                    if st.tradeTimer >= fd.tradeInterval then
                        st.tradeTimer = 0
                        rm:add("metal",   fd.tradeGain.metal)
                        rm:add("esource", fd.tradeGain.esource)
                        events[#events+1] = {
                            type = "trade", planetId = pid,
                            factionKey = st.factionKey,
                            gain = fd.tradeGain,
                        }
                    end
                end
            end
            -- P2-2: 长期贸易协议自动购入
            if st.longTrade then
                -- 好感 < 40 时协议中断
                if st.favor < LONG_TRADE_BREAK_FAVOR then
                    st.longTrade      = false
                    st.longTradeTimer = 0
                    local fd = NEUTRAL_FACTIONS[st.factionKey]
                    events[#events+1] = {
                        type       = "long_trade_break",
                        planetId   = pid,
                        factionKey = st.factionKey,
                        factionName = fd and fd.name or "?",
                    }
                else
                    st.longTradeTimer = (st.longTradeTimer or 0) + dt
                    if st.longTradeTimer >= LONG_TRADE_INTERVAL then
                        st.longTradeTimer = 0
                        local fd = NEUTRAL_FACTIONS[st.factionKey]
                        if fd then
                            -- 以低于市价 20% 的价格购入该势力的特产资源
                            local gain = {}
                            for res, amt in pairs(fd.tradeGain) do
                                local discounted = math.floor(amt * (1 + LONG_TRADE_DISCOUNT))
                                rm:add(res, discounted)
                                gain[res] = discounted
                            end
                            events[#events+1] = {
                                type       = "long_trade",
                                planetId   = pid,
                                factionKey = st.factionKey,
                                factionName = fd.name,
                                icon       = fd.icon,
                                gain       = gain,
                            }
                        end
                    end
                end
            end
        end
        -- 已殖民的星球移除外交状态
        local p = pmap[pid]
        if p and p.colonized then
            if p.neutralFaction then p.neutralFaction = nil end
            self.planets[pid] = nil
        end
    end

    -- P1-1 V2.4: 封锁倒计时
    for fk, remain in pairs(self.blockades) do
        remain = remain - dt
        if remain <= 0 then
            self.blockades[fk] = nil
            events[#events+1] = { type = "blockade_end", factionKey = fk }
        else
            self.blockades[fk] = remain
        end
    end

    -- P1-1 V2.4: 外交事件定时器（V2.5 外交L2: CD减少）
    local cdReduction = self._legacyAgreementCdReduction or 0
    local effectiveInterval = DIPLO_EVENT_INTERVAL * (1 - cdReduction)
    self.diploEventTimer = (self.diploEventTimer or 0) + dt
    if self.diploEventTimer >= effectiveInterval then
        self.diploEventTimer = 0
        local evt = self:_generateDiploEvent(rm, allPlanets)
        if evt then
            events[#events+1] = evt
        end
    end

    return events
end

--- P1-1 V2.4: 生成随机外交事件
---@return table|nil
function DiplomacySystem:_generateDiploEvent(rm, allPlanets)
    -- 收集当前有外交关系的派系
    local factions = {}
    local seen = {}
    for _, st in pairs(self.planets) do
        if not seen[st.factionKey] and not st.atWar then
            seen[st.factionKey] = true
            factions[#factions+1] = st.factionKey
        end
    end
    if #factions == 0 then return nil end

    local pick = factions[math.random(#factions)]
    local fd = NEUTRAL_FACTIONS[pick]
    if not fd then return nil end

    -- 计算该派系最高好感
    local maxFavor = 0
    for _, st in pairs(self.planets) do
        if st.factionKey == pick and st.favor > maxFavor then
            maxFavor = st.favor
        end
    end

    -- V2.5 外交L3: 正面事件概率加成（将正面阈值下限降低）
    local positiveBonus = self._legacyDiploPositiveBonus or 0
    local roll = math.random(100)
    if roll <= 40 then
        -- 派系请求（二选一）：同意+15，拒绝-10
        return {
            type = "diplo_request",
            factionKey = pick,
            factionName = fd.name,
            icon = fd.icon,
            desc = string.format("%s 请求资源援助", fd.name),
            choiceA = { label = "同意 (+15好感)", favorDelta = 15 },
            choiceB = { label = "拒绝 (-10好感)", favorDelta = -10 },
        }
    elseif roll <= 65 then
        -- 贸易纠纷：选择站队
        local competitor = self:getCompetitor(pick)
        if competitor then
            local cfd = NEUTRAL_FACTIONS[competitor]
            return {
                type = "diplo_dispute",
                factionKey = pick,
                factionName = fd.name,
                icon = fd.icon,
                competitorKey = competitor,
                competitorName = cfd and cfd.name or "?",
                desc = string.format("%s 与 %s 发生贸易纠纷",
                    fd.name, cfd and cfd.name or "?"),
                choiceA = { label = string.format("支持%s (+10/-10)", fd.name),
                            favorDeltaSelf = 10, favorDeltaOther = -10 },
                choiceB = { label = "保持中立 (无变化)",
                            favorDeltaSelf = 0, favorDeltaOther = 0 },
            }
        end
        return nil
    elseif roll <= math.floor(85 - positiveBonus * 100) and maxFavor < 20 then
        -- 背叛警告：好感过低时（L3 减少此概率）
        return {
            type = "diplo_warning",
            factionKey = pick,
            factionName = fd.name,
            icon = fd.icon,
            desc = string.format("⚠️ %s 对你极度不满，可能随时宣战！", fd.name),
        }
    else
        -- 贸易机会：限时+20好感（需花费）
        return {
            type = "diplo_opportunity",
            factionKey = pick,
            factionName = fd.name,
            icon = fd.icon,
            desc = string.format("%s 提议深化合作", fd.name),
            cost = { metal = 200 },
            favorDelta = 20,
        }
    end
end

--- 检查某星球是否处于军事合作（海盗攻击时协防）
---@param planetId number
---@return boolean
function DiplomacySystem:hasMilitary(planetId)
    local st = self.planets[planetId]
    return st and st.military and not st.atWar
end

-- P2-2: 长期贸易协议 API =====================================================

--- 当前激活的长期协议数量
---@return number
function DiplomacySystem:countLongTrades()
    local n = 0
    for _, st in pairs(self.planets) do
        if st.longTrade then n = n + 1 end
    end
    return n
end

--- 激活某星球的长期贸易协议（消耗晶体×100）
---@param planetId number
---@param rm       table  ResourceManager
---@return boolean success, string msg
function DiplomacySystem:activateLongTrade(planetId, rm)
    local st = self.planets[planetId]
    if not st then return false, "该星球无中立势力" end
    if st.atWar            then return false, "宣战中，无法签订协议" end
    if st.favor < LONG_TRADE_THRESHOLD then
        return false, string.format("好感度不足（需 %d，当前 %d）", LONG_TRADE_THRESHOLD, st.favor)
    end
    if st.longTrade        then return false, "长期协议已激活" end
    if self:countLongTrades() >= MAX_LONG_TRADES then
        return false, string.format("已达协议上限（最多 %d 个）", MAX_LONG_TRADES)
    end
    if not rm:canAfford(LONG_TRADE_COST) then
        return false, string.format("晶体不足（需 %d）", LONG_TRADE_COST.crystal)
    end
    rm:spend(LONG_TRADE_COST)
    st.longTrade      = true
    st.longTradeTimer = 0
    local fd = NEUTRAL_FACTIONS[st.factionKey]
    return true, string.format("📋 与 %s 签订长期贸易协议！每 %ds 自动低价购入特产资源",
        fd and fd.name or "未知势力", LONG_TRADE_INTERVAL)
end

--- 获取长期协议列表（用于 UI 展示）
---@return table  { {planetId, factionKey, factionName, icon, favor, longTradeTimer} }
function DiplomacySystem:getLongTradeList()
    local list = {}
    for pid, st in pairs(self.planets) do
        if st.longTrade then
            local fd = NEUTRAL_FACTIONS[st.factionKey] or {}
            list[#list+1] = {
                planetId    = pid,
                factionKey  = st.factionKey,
                factionName = fd.name or "?",
                icon        = fd.icon or "❓",
                favor       = st.favor,
                timerPct    = st.longTradeTimer / LONG_TRADE_INTERVAL,  -- 0-1
            }
        end
    end
    return list
end

--- 序列化（存档）
function DiplomacySystem:serialize()
    local out = {}
    for pid, st in pairs(self.planets) do
        out[tostring(pid)] = {
            factionKey      = st.factionKey,
            favor           = st.favor,
            tradeTimer      = st.tradeTimer,
            atWar           = st.atWar,
            military        = st.military,
            longTrade       = st.longTrade,       -- P2-2
            longTradeTimer  = st.longTradeTimer,  -- P2-2
        }
    end
    -- P1-1 V2.4: 三角博弈+协议状态
    out._p1_1 = {
        triangleRels    = self.triangleRels,
        alliances       = self.alliances,
        blockades       = self.blockades,
        intelShares     = self.intelShares,
        diploEventTimer = self.diploEventTimer,
    }
    return out
end

--- 反序列化（读档）
---@param data table   serialize() 结果
---@param allPlanets table
function DiplomacySystem:deserialize(data, allPlanets)
    if type(data) ~= "table" then return end
    local pmap = {}
    for _, p in ipairs(allPlanets or {}) do pmap[p.id] = p end
    for pidStr, st in pairs(data) do
        if pidStr == "_p1_1" then goto continue end  -- 跳过 meta 字段
        local pid = tonumber(pidStr)
        if pid then
            self.planets[pid] = {
                factionKey      = st.factionKey,
                favor           = st.favor          or 40,
                tradeTimer      = st.tradeTimer      or 0,
                atWar           = st.atWar           or false,
                military        = st.military        or false,
                longTrade       = st.longTrade       or false,  -- P2-2
                longTradeTimer  = st.longTradeTimer  or 0,      -- P2-2
            }
            local p = pmap[pid]
            if p then p.neutralFaction = st.factionKey end
        end
        ::continue::
    end
    -- P1-1 V2.4: 恢复三角博弈+协议状态
    local p11 = data._p1_1
    if p11 then
        self.triangleRels    = p11.triangleRels    or {}
        self.alliances       = p11.alliances       or {}
        self.blockades       = p11.blockades       or {}
        self.intelShares     = p11.intelShares     or {}
        self.diploEventTimer = p11.diploEventTimer or 0
    end
end

-- ============================================================================
-- 导出常量（供外部引用）
-- ============================================================================
DiplomacySystem.NEUTRAL_FACTIONS       = NEUTRAL_FACTIONS
DiplomacySystem.TRADE_THRESHOLD        = TRADE_THRESHOLD
DiplomacySystem.MILITARY_THRESHOLD     = MILITARY_THRESHOLD
DiplomacySystem.LONG_TRADE_THRESHOLD   = LONG_TRADE_THRESHOLD
DiplomacySystem.LONG_TRADE_BREAK_FAVOR = LONG_TRADE_BREAK_FAVOR
DiplomacySystem.LONG_TRADE_COST        = LONG_TRADE_COST
DiplomacySystem.LONG_TRADE_INTERVAL    = LONG_TRADE_INTERVAL
DiplomacySystem.MAX_LONG_TRADES        = MAX_LONG_TRADES
DiplomacySystem.INTEL_THRESHOLD        = INTEL_THRESHOLD
DiplomacySystem.ALLIANCE_THRESHOLD     = ALLIANCE_THRESHOLD
DiplomacySystem.BLOCKADE_THRESHOLD     = BLOCKADE_THRESHOLD
DiplomacySystem.MEDIATE_THRESHOLD      = MEDIATE_THRESHOLD
DiplomacySystem.BLOCKADE_COST          = BLOCKADE_COST
DiplomacySystem.MEDIATE_COST           = MEDIATE_COST
DiplomacySystem.BLOCKADE_DURATION      = BLOCKADE_DURATION
DiplomacySystem.DIPLO_EVENT_INTERVAL   = DIPLO_EVENT_INTERVAL
DiplomacySystem.REL_COMPETE            = REL_COMPETE
DiplomacySystem.REL_NEUTRAL            = REL_NEUTRAL
DiplomacySystem.REL_COOPERATE          = REL_COOPERATE

return DiplomacySystem
