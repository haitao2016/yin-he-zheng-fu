-- Auto-split from GameUI.lua by code_health_check.py
-- 基于大文件拆分规则（超过 600 行）

        -- 📋 日志按钮
        addHit(screenW_ - 138, 6, 28, 28, function()
            LogPanel.Toggle()
        end)
        -- 📊 战绩按钮
        addHit(screenW_ - 172, 6, 28, 28, function()
            statsVisible_ = not statsVisible_
        end)
        -- 📡 P3-1: 信号按钮
        addHit(screenW_ - 206, 6, 28, 28, function()
            if signalCooldown_ <= 0 then
                signalOpen_ = not signalOpen_
            end
        end)
        -- 🏛️ P1-3: 帝国总览按钮
        addHit(screenW_ - 240, 6, 28, 28, function()
            EmpirePanel.Toggle()
        end)
        -- ⚔ P1-2: 宿敌档案按钮
        addHit(screenW_ - 272, 6, 28, 28, function()
            NemesisRenderPanel.Toggle()
        end)
        -- 📌 P2-1: 任务板按钮
        addHit(screenW_ - 304, 6, 28, 28, function()
            questVisible_ = not questVisible_
        end)
        -- 🤝 P1-1: 外交关系网按钮
        addHit(screenW_ - 338, 6, 28, 28, function()
            diploRelVisible_ = not diploRelVisible_
        end)
        -- 🏗️ P2-2 V2.4: 巨构工程按钮（Lv7+可见）
        local megaBase2 = GalaxyScene.GetBase and GalaxyScene.GetBase()
        if megaBase2 and megaBase2.coreLevel >= 7 then
            addHit(screenW_ - 372, 6, 28, 28, function()
                MegaPanel.Toggle()
            end)
        end
        -- 🎨 P2-3 V2.4: 舰队涂装按钮
        addHit(screenW_ - 406, 6, 28, 28, function()
            -- 打开时刷新解锁上下文
            if not LiveryPanel.IsVisible() then
                LiveryPanel.SetContext({
                    achievements  = AchievementPanel.GetUnlockCount() or 0,
                    leagueRank    = 0,
                    crisisBeaten  = 0,
                    nemesisBeaten = NemesisSystem and NemesisSystem.GetDefeatedCount and NemesisSystem.GetDefeatedCount() or 0,
                    megaCompleted = 0,
                })
            end
            LiveryPanel.Toggle()
        end)
        -- 📖 P3-1 V2.4: 银河百科按钮
        addHit(screenW_ - 440, 6, 28, 28, function()
            GalactopediaPanel.Toggle()
        end)
        -- ⭐ P1-3 V2.5: 文明遗产按钮
        addHit(screenW_ - 474, 6, 28, 28, function()
            LegacyPanel.Toggle()
        end)
    end

    -- P3-3: FPS 计数器更新 & 渲染（最顶层叠加）
    SettingsPanel.UpdateFPS(dt)
    SettingsPanel.RenderFPS()
end

-- ============================================================================
-- Refresh 接口（供 main.lua 调用，更新缓存数据）
-- ============================================================================
