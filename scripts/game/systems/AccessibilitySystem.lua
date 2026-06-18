---@diagnostic disable: undefined-global, assign-type-mismatch, return-type-mismatch, param-type-mismatch
--[[
AccessibilitySystem.lua - 辅助功能系统
V3.0 Phase 2 P3-2
提供色盲模式、字体大小、高对比度、减少动画等辅助功能
]]

local AccessibilitySystem = {}

-- 默认设置
local DEFAULT_SETTINGS = {
    colorblindMode = "NONE",     -- NONE, RED_GREEN, BLUE_YELLOW
    fontSize = "MEDIUM",        -- SMALL, MEDIUM, LARGE, EXTRA_LARGE
    highContrast = false,
    reducedMotion = false,
    screenShake = true,
    damageFlash = true,
    colorScheme = "DEFAULT",    -- DEFAULT, DARK, LIGHT
    uiScale = 1.0,
    subtitles = true,
    subtitleSize = "MEDIUM",
    audioDescription = false,
    accessibilityHints = true,
}

-- 配色方案查找表
local COLOR_SCHEMES = {
    DEFAULT = {
        background = "#1a1a2e", foreground = "#eaeaea",
        primary = "#4a90d9", secondary = "#2ecc71",
        danger = "#e74c3c", success = "#2ecc71",
        warning = "#f39c12", info = "#3498db",
        healthBar = "#2ecc71", shieldBar = "#3498db",
        energyBar = "#f1c40f", enemyHealth = "#e74c3c", friendlyHealth = "#2ecc71",
    },
    HIGH_CONTRAST = {
        background = "#000000", foreground = "#FFFFFF",
        primary = "#00FF00", secondary = "#FFFF00",
        danger = "#FF0000", success = "#00FF00",
        warning = "#FFFF00", info = "#00FFFF",
        healthBar = "#00FF00", shieldBar = "#00FFFF",
        energyBar = "#FFFF00", enemyHealth = "#FF0000", friendlyHealth = "#00FF00",
    },
    RED_GREEN = {
        background = "#1a1a2e", foreground = "#eaeaea",
        primary = "#0077b6", secondary = "#023e8a",
        danger = "#ff6b35", success = "#00b4d8",
        warning = "#ffd166", info = "#90e0ef",
        healthBar = "#00b4d8", shieldBar = "#90e0ef",
        energyBar = "#ffd166", enemyHealth = "#ff6b35", friendlyHealth = "#00b4d8",
    },
    BLUE_YELLOW = {
        background = "#1a1a2e", foreground = "#eaeaea",
        primary = "#e63946", secondary = "#457b9d",
        danger = "#e63946", success = "#2a9d8f",
        warning = "#f4a261", info = "#a8dadc",
        healthBar = "#2a9d8f", shieldBar = "#a8dadc",
        energyBar = "#f4a261", enemyHealth = "#e63946", friendlyHealth = "#2a9d8f",
    },
}

-- 字体大小查找表
local FONT_SIZES = {
    SMALL = { base = 12, title = 18, small = 10 },
    MEDIUM = { base = 14, title = 22, small = 12 },
    LARGE = { base = 16, title = 26, small = 14 },
    EXTRA_LARGE = { base = 18, title = 30, small = 16 },
}

-- 伤害颜色查找表
local DAMAGE_COLORS = {
    DEFAULT = { CRITICAL = "#ff4444", NORMAL = "#ffffff", OTHER = "#ffff44" },
    RED_GREEN = { CRITICAL = "#ff6b35", NORMAL = "#00b4d8", OTHER = "#ffd166" },
    BLUE_YELLOW = { CRITICAL = "#e63946", NORMAL = "#2a9d8f", OTHER = "#f4a261" },
}

local currentSettings = {}

-- 初始化
function AccessibilitySystem.init()
    currentSettings = {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        currentSettings[k] = v
    end
end

-- 获取当前设置（返回副本避免外部修改）
function AccessibilitySystem.getSettings()
    return { ["colorblindMode"] = currentSettings.colorblindMode,
             ["fontSize"] = currentSettings.fontSize,
             ["highContrast"] = currentSettings.highContrast,
             ["reducedMotion"] = currentSettings.reducedMotion,
             ["screenShake"] = currentSettings.screenShake,
             ["damageFlash"] = currentSettings.damageFlash,
             ["colorScheme"] = currentSettings.colorScheme,
             ["uiScale"] = currentSettings.uiScale,
             ["subtitles"] = currentSettings.subtitles,
             ["subtitleSize"] = currentSettings.subtitleSize,
             ["audioDescription"] = currentSettings.audioDescription,
             ["accessibilityHints"] = currentSettings.accessibilityHints }
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
    if key == "colorblindMode" or key == "highContrast" or key == "colorScheme" then
        AccessibilitySystem.applyColorScheme()
    elseif key == "fontSize" then
        AccessibilitySystem.applyFontSize()
    elseif key == "uiScale" then
        AccessibilitySystem.applyUIScale()
    end
end

-- 应用配色方案
function AccessibilitySystem.applyColorScheme()
    local schemeKey = "DEFAULT"
    if currentSettings.highContrast then
        schemeKey = "HIGH_CONTRAST"
    elseif currentSettings.colorblindMode == "RED_GREEN" then
        schemeKey = "RED_GREEN"
    elseif currentSettings.colorblindMode == "BLUE_YELLOW" then
        schemeKey = "BLUE_YELLOW"
    end
    local scheme = COLOR_SCHEMES[schemeKey]

    if _G and _G.Theme then
        _G.Theme.colors = scheme
    end
    return scheme
end

-- 应用字体大小
function AccessibilitySystem.applyFontSize()
    local size = FONT_SIZES[currentSettings.fontSize] or FONT_SIZES.MEDIUM
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

-- 获取雷达图维度标签
function AccessibilitySystem.getRadarChartLabels()
    if currentSettings.colorblindMode == "RED_GREEN" or currentSettings.colorblindMode == "BLUE_YELLOW" then
        return { "战斗力", "经济力", "探索力", "生存力", "效率", "通用性" }
    end
    return { "combat", "economy", "exploration", "survival", "efficiency", "versatility" }
end

-- 获取伤害数字颜色
function AccessibilitySystem.getDamageColor(damageType)
    local colorSet = DAMAGE_COLORS.DEFAULT
    if currentSettings.colorblindMode == "RED_GREEN" then
        colorSet = DAMAGE_COLORS.RED_GREEN
    elseif currentSettings.colorblindMode == "BLUE_YELLOW" then
        colorSet = DAMAGE_COLORS.BLUE_YELLOW
    end
    return colorSet[damageType] or colorSet.OTHER
end

-- 获取状态图标替代方案
function AccessibilitySystem.getStatusIcon替代(status)
    if not currentSettings.highContrast then
        return nil
    end
    local iconMap = {
        POISON = "[毒]", BURN = "[烧]", SLOW = "[缓]",
        STUN = "[晕]", SHIELD = "[盾]", HEAL = "[治]",
    }
    return iconMap[status] or status
end

-- 保存设置到存档
function AccessibilitySystem.serialize()
    return { ["colorblindMode"] = currentSettings.colorblindMode,
             ["fontSize"] = currentSettings.fontSize,
             ["highContrast"] = currentSettings.highContrast,
             ["reducedMotion"] = currentSettings.reducedMotion,
             ["screenShake"] = currentSettings.screenShake,
             ["damageFlash"] = currentSettings.damageFlash,
             ["colorScheme"] = currentSettings.colorScheme,
             ["uiScale"] = currentSettings.uiScale,
             ["subtitles"] = currentSettings.subtitles,
             ["subtitleSize"] = currentSettings.subtitleSize,
             ["audioDescription"] = currentSettings.audioDescription,
             ["accessibilityHints"] = currentSettings.accessibilityHints }
end

-- 从存档加载设置
function AccessibilitySystem.deserialize(data)
    if not data then return end
    for k, v in pairs(data) do
        if currentSettings[k] ~= nil then
            currentSettings[k] = v
        end
    end
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

AccessibilitySystem.init()

return AccessibilitySystem
