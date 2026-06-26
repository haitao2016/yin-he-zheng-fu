---@diagnostic disable: assign-type-mismatch, return-type-mismatch
-- ============================================================================
-- game/i18n/I18nSystem.lua -- 多语言本地化框架
-- V2.8 I18n-1
-- ============================================================================

local I18nSystem = {}

-- ============================================================================
-- 支持的语言列表
-- ============================================================================

local SUPPORTED_LANGUAGES = {
    "zh-CN",
    "en-US",
}

-- ============================================================================
-- 语言资源注册表（运行时动态加载 / registerLanguage 扩展）
-- ============================================================================

local I18n_LANG_DATA = {}

-- 本地加载内置语言资源（懒加载）
local function loadBuiltinLanguage(lang)
    local ok, data = pcall(function()
        return require("game.i18n." .. lang)
    end)
    if ok and type(data) == "table" then
        I18n_LANG_DATA[lang] = data
        return data
    end
    return nil
end

local function getLanguageData(lang)
    if not I18n_LANG_DATA[lang] then
        loadBuiltinLanguage(lang)
    end
    return I18n_LANG_DATA[lang] or {}
end

-- ============================================================================
-- 当前语言全局变量
-- ============================================================================

if I18n_CURRENT_LANG == nil then
    I18n_CURRENT_LANG = "zh-CN"
end

-- ============================================================================
-- 变量插值
-- 支持格式: "你好, {name}! 等级 {level}"
-- ============================================================================

local function interpolate(text, vars)
    if text == nil then return "" end
    if vars == nil then return text end
    local result = text:gsub("{([%w_%.]+)}", function(key)
        local v = vars[key]
        if v ~= nil then
            return tostring(v)
        end
        return "{" .. key .. "}"
    end)
    return result
end

-- ============================================================================
-- 核心 API
-- ============================================================================

function I18nSystem.setLanguage(lang)
    if lang == nil then return false, "语言不能为空" end
    local found = false
    for _, l in ipairs(SUPPORTED_LANGUAGES) do
        if l == lang then found = true; break end
    end
    if not found and not I18n_LANG_DATA[lang] then
        return false, "不支持的语言: " .. tostring(lang)
    end
    I18n_CURRENT_LANG = lang
    return true, "语言已切换: " .. lang
end

function I18nSystem.getLanguage()
    return I18n_CURRENT_LANG
end

function I18nSystem.getSupportedLanguages()
    local list = {}
    for _, l in ipairs(SUPPORTED_LANGUAGES) do
        table.insert(list, l)
    end
    for lang, _ in pairs(I18n_LANG_DATA) do
        local exists = false
        for _, l in ipairs(list) do
            if l == lang then exists = true; break end
        end
        if not exists then table.insert(list, lang) end
    end
    return list
end

function I18nSystem.getText(key, vars)
    if key == nil then return "" end
    local data = getLanguageData(I18n_CURRENT_LANG)
    local text = data[key]
    if text == nil then
        -- 回退到英文
        local fallback = getLanguageData("en-US")
        text = fallback[key]
    end
    if text == nil then
        -- 回退到中文
        local fallback = getLanguageData("zh-CN")
        text = fallback[key]
    end
    if text == nil then
        return "{" .. key .. "}"
    end
    return interpolate(text, vars)
end

function I18nSystem.registerLanguage(lang, data)
    if lang == nil then return false, "语言标识不能为空" end
    if type(data) ~= "table" then return false, "资源数据必须为 table" end
    local existing = I18n_LANG_DATA[lang] or {}
    for k, v in pairs(data) do
        existing[k] = v
    end
    I18n_LANG_DATA[lang] = existing
    -- 若首次注册该语言，则追加到支持列表
    local found = false
    for _, l in ipairs(SUPPORTED_LANGUAGES) do
        if l == lang then found = true; break end
    end
    if not found then
        table.insert(SUPPORTED_LANGUAGES, lang)
    end
    return true, "语言资源已注册: " .. lang
end

-- ============================================================================
-- 便捷 API（UI 绑定用）
-- ============================================================================

function I18nSystem.t(key, vars)
    return I18nSystem.getText(key, vars)
end

-- ============================================================================
-- 存档
-- ============================================================================

function I18nSystem.serialize()
    return {
        currentLang = I18n_CURRENT_LANG,
        registered = I18n_LANG_DATA,
    }
end

function I18nSystem.deserialize(data)
    if data == nil then return false end
    if data.currentLang then
        I18n_CURRENT_LANG = data.currentLang
    end
    if type(data.registered) == "table" then
        for lang, langData in pairs(data.registered) do
            if type(langData) == "table" then
                local existing = I18n_LANG_DATA[lang] or {}
                for k, v in pairs(langData) do
                    existing[k] = v
                end
                I18n_LANG_DATA[lang] = existing
                local found = false
                for _, l in ipairs(SUPPORTED_LANGUAGES) do
                    if l == lang then found = true; break end
                end
                if not found then
                    table.insert(SUPPORTED_LANGUAGES, lang)
                end
            end
        end
    end
    return true
end

-- ============================================================================
-- 导出
-- ============================================================================

return I18nSystem
