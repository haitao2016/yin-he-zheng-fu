-- Auto-split from PirateAI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

function PirateAI:generateBases(worldRange, opts)
    self.bases = {}
    -- P2-2: BIPOLAR 模式下海盗基地集中在中线（x≈0，上/下方）
    local baseAngles
    if opts and opts.bipolar then
        baseAngles = { math.pi * 0.5, math.pi * 1.5 }   -- 正上 / 正下
    else
        -- 两个基地对称分布在星图边缘，角度错开 180°
        baseAngles = { math.pi * 0.25, math.pi * 1.25 }
    end
    for i, angle in ipairs(baseAngles) do
        local dist = worldRange * 0.65 + math.random() * worldRange * 0.25
        self.bases[i] = {
            id          = i,
            x           = math.cos(angle) * dist,
            y           = math.sin(angle) * dist,
            hp          = PIRATE_BASE_HP,
            maxHp       = PIRATE_BASE_HP,
            level       = 1,          -- 1~5，影响出兵波次强度
            attackTimer = PIRATE_ATTACK_INTERVAL * self.attackIntervalFactor * (PIRATE_ATTACK_JITTER_LO + math.random() * PIRATE_ATTACK_JITTER_HI),  -- 首次进攻随机延迟（受难度影响）
            recoverTimer = 0,
            pulse       = math.random() * math.pi * 2,
            active      = true,
        }
    end
    print(string.format("[PirateAI] 生成 %d 个海盗基地", #self.bases))
end
