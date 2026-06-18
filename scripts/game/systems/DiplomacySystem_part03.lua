-- Auto-split from DiplomacySystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
