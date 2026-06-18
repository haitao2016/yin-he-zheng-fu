-- Auto-split from Client.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

local function buildEvolutionBonus()
    local cfg = {}
    for _, node in ipairs(EVOLUTION_TREE) do
        if evolutionUnlocked_[node.id] then
            node.apply(cfg)
        end
    end
    return cfg
end
