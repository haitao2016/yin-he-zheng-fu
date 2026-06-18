-- Auto-split from PirateAI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function PirateAI:generateFixedBases(defs)
    self.bases = {}
    for i, def in ipairs(defs) do
        self.bases[i] = {
            id          = i,
            x           = def.x,
            y           = def.y,
            hp          = PIRATE_BASE_HP,
            maxHp       = PIRATE_BASE_HP,
            level       = def.level or 3,
            attackTimer = PIRATE_ATTACK_INTERVAL * self.attackIntervalFactor * (1.5 + i * 0.5),
            recoverTimer = 0,
            pulse       = i * 1.2,
            active      = true,
        }
    end
    print(string.format("[PirateAI] 战役固定基地: %d 个", #self.bases))
end
