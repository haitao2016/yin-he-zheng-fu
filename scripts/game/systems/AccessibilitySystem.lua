--[[
AccessibilitySystem.lua - 辅助功能系统
V3.0 Phase 2 P3-2
提供色盲模式、字体大小、高对比度、减少动画等辅助功能
]]

local AccessibilitySystem = {}

-- 默认设置
local DEFAULT_SETTINGS = {
    -- 色盲模式
    colorblindMode = "NONE",        -- NONE, RED_GREEN, BLUE_YELLOW
    -- 字体大小
    fontSize = "MEDIUM",            -- SMALL, MEDIUM, LARGE, EXTRA_LARGE
    -- 高对比度
    highContrast = false,
    -- 减少动画
    reducedMotion = false,
    -- 屏幕震动
    screenShake = true,
    -- 受伤闪烁
    damageFlash = true,
    -- 颜色方案
    colorScheme = "DEFAULT",        -- DEFAULT, DARK, LIGHT
    -- UI 缩放
    uiScale = 1.0,
    -- 字幕
    subtitles = true,
    -- 字幕大小
    subtitleSize = "MEDIUM",
    -- 音频描述
    audioDescription = false,
    -- 辅助功能提示
    accessibilityHints = true,
}

local currentSettings = {}

-- 初始化
function AccessibilitySystem.init()
    currentSettings = {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        currentSettings[k] = v
    end
end

-- 获取当前设置
function AccessibilitySystem.getSettings()
    local settings = {}
    for k, v in pairs(currentSettings) do
        settings[k] = v
    end
    return settings
end

-- 获取单个设置
function AccessibilitySystem.getSetting(key)
    return currentSettings[key]
end

-- 设置单个选项
function AccessibilitySystem.setSetting(key, value)
    if currentSettings[key] ~= nil then
        currentSettings[key] = value
        AccessibilitySystem.onSettingChanged(key, value)
    end
end

-- 批量更新设置
function AccessibilitySystem.updateSettings(newSettings)
    for k, v in pairs(newSettings) do
        if currentSettings[k] ~= nil then
            currentSettings[k] = v
            AccessibilitySystem.onSettingChanged(k, v)
        end
    end
end

-- 设置变更回调
function AccessibilitySystem.onSettingChanged(key, value)
    -- 通知 UI 系统更新配色
    if key == "colorblindMode" or key == "highContrast" or key == "colorScheme" then
        AccessibilitySystem.applyColorScheme()
    end
    -- 通知 UI 系统更新字体
    if key == "fontSize" then
        AccessibilitySystem.applyFontSize()
    end
    -- 通知 UI 系统更新缩放
    if key == "uiScale" then
        AccessibilitySystem.applyUIScale()
    end
end

-- 应用配色方案（色盲模式 + 高对比度）
function AccessibilitySystem.applyColorScheme()
    local scheme = {}

    if currentSettings.highContrast then
        scheme = {
            -- 高对比度配色
            background = "#000000",
            foreground = "#FFFFFF",
            primary = "#00FF00",
            secondary = "#FFFF00",
            danger = "#FF0000",
            success = "#00FF00",
            warning = "#FFFF00",
            info = "#00FFFF",
            healthBar = "#00FF00",
            shieldBar = "#00FFFF",
            energyBar = "#FFFF00",
            enemyHealth = "#FF0000",
            friendlyHealth = "#00FF00",
        }
    elseif currentSettings.colorblindMode == "RED_GREEN" then
        scheme = {
            -- 红绿色盲友好配色（使用蓝-橙替代）
            background = "#1a1a2e",
            foreground = "#eaeaea",
            primary = "#0077b6",
            secondary = "#023e8a",
            danger = "#ff6b35",      -- 橙色替代红色
            success = "#00b4d8",      -- 蓝绿色替代绿色
            warning = "#ffd166",
            info = "#90e0ef",
            healthBar = "#00b4d8",
            shieldBar = "#90e0ef",
            energyBar = "#ffd166",
            enemyHealth = "#ff6b35",
            friendlyHealth = "#00b4d8",
        }
    elseif currentSettings.colorblindMode == "BLUE_YELLOW" then
        scheme = {
            -- 蓝黄色盲友好配色（使用红-绿替代）
            background = "#1a1a2e",
            foreground = "#eaeaea",
            primary = "#e63946",      -- 红色替代蓝色
            secondary = "#457b9d",
            danger = "#e63946",
            success = "#2a9d8f",      -- 绿色替代黄色
            warning = "#f4a261",
            info = "#a8dadc",
            healthBar = "#2a9d8f",
            shieldBar = "#a8dadc",
            energyBar = "#f4a261",
            enemyHealth = "#e63946",
            friendlyHealth = "#2a9d8f",
        }
    else
        scheme = {
            -- 默认配色
            background = "#1a1a2e",
            foreground = "#eaeaea",
            primary = "#4a90d9",
            secondary = "#2ecc71",
            danger = "#e74c3c",
            success = "#2ecc71",
            warning = "#f39c12",
            info = "#3498db",
            healthBar = "#2ecc71",
            shieldBar = "#3498db",
            energyBar = "#f1c40f",
            enemyHealth = "#e74c3c",
            friendlyHealth = "#2ecc71",
        }
    end

    -- 应用到全局主题
    if _G and _G.Theme then
        _G.Theme.colors = scheme
    end

    return scheme
end

-- 应用字体大小
function AccessibilitySystem.applyFontSize()
    local sizes = {
        SMALL = { base = 12, title = 18, small = 10 },
        MEDIUM = { base = 14, title = 22, small = 12 },
        LARGE = { base = 16, title = 26, small = 14 },
        EXTRA_LARGE = { base = 18, title = 30, small = 16 },
    }
    local size = sizes[currentSettings.fontSize] or sizes.MEDIUM

    if _G and _G.Theme then
        _G.Theme.fontSizes = size
    end

    return size
end

-- 应用 UI 缩放
function AccessibilitySystem.applyUIScale()
    local scale = currentSettings.uiScale or 1.0
    if _G and _G.Theme then
        _G.Theme.uiScale = scale
    end
    return scale
end

-- 获取是否启用减少动画
function AccessibilitySystem.isReducedMotion()
    return currentSettings.reducedMotion == true
end

-- 获取是否启用屏幕震动
function AccessibilitySystem.isScreenShakeEnabled()
    return currentSettings.screenShake == true
end

-- 获取是否启用受伤闪烁
function AccessibilitySystem.isDamageFlashEnabled()
    return currentSettings.damageFlash == true
end

-- 获取雷达图维度标签（色盲友好）
function AccessibilitySystem.getRadarChartLabels()
    if currentSettings.colorblindMode == "RED_GREEN" then
        return { "战斗力", "经济力", "探索力", "生存力", "效率", "通用性" }
    elseif currentSettings.colorblindMode == "BLUE_YELLOW" then
        return { "战斗力", "经济力", "探索力", "生存力", "效率", "通用性" }
    end
    return { "combat", "economy", "exploration", "survival", "efficiency", "versatility" }
end

-- 获取伤害数字颜色（色盲友好）
function AccessibilitySystem.getDamageColor(damageType)
    if currentSettings.colorblindMode == "RED_GREEN" then
        if damageType == "CRITICAL" then
            return "#ff6b35"  -- 橙色
        elseif damageType == "NORMAL" then
            return "#00b4d8"  -- 蓝绿色
        else
            return "#ffd166"  -- 黄色
        end
    elseif currentSettings.colorblindMode == "BLUE_YELLOW" then
        if damageType == "CRITICAL" then
            return "#e63946"  -- 红色
        elseif damageType == "NORMAL" then
            return "#2a9d8f"  -- 绿色
        else
            return "#f4a261"  -- 橙色
        end
    end
    -- 默认
    if damageType == "CRITICAL" then
        return "#ff4444"
    elseif damageType == "NORMAL" then
        return "#ffffff"
    else
        return "#ffff44"
    end
end

-- 获取状态图标替代方案（色盲模式用文字替代图标）
function AccessibilitySystem.getStatusIcon替代(status)
    if not currentSettings.highContrast then
        return nil
    end
    local iconMap = {
        POISON = "[毒]",
        BURN = "[烧]",
        SLOW = "[缓]",
        STUN = "[晕]",
        SHIELD = "[盾]",
        HEAL = "[治]",
    }
    return iconMap[status] or status
end

-- 保存设置到存档
function AccessibilitySystem.serialize()
    local data = {}
    for k, v in pairs(currentSettings) do
        data[k] = v
    end
    return data
end

-- 从存档加载设置
function AccessibilitySystem.deserialize(data)
    if not data then return end
    for k, v in pairs(data) do
        if currentSettings[k] ~= nil then
            currentSettings[k] = v
        end
    end
    -- 应用设置
    AccessibilitySystem.applyColorScheme()
    AccessibilitySystem.applyFontSize()
    AccessibilitySystem.applyUIScale()
end

-- 重置为默认设置
function AccessibilitySystem.resetToDefaults()
    for k, v in pairs(DEFAULT_SETTINGS) do
        currentSettings[k] = v
    end
    AccessibilitySystem.applyColorScheme()
    AccessibilitySystem.applyFontSize()
    AccessibilitySystem.applyUIScale()
end

-- 初始化
AccessibilitySystem.init()

return AccessibilitySystem
