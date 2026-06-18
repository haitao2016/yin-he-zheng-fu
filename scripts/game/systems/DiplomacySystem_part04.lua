-- Auto-split from DiplomacySystem.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

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
