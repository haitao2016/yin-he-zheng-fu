-- ============================================================================
-- interface_checker.lua  -- 接口契约自检脚本
-- ============================================================================

local M = {}

local function getFunctionNames(module)
    local names = {}
    for k, v in pairs(module) do
        if type(v) == "function" then
            table.insert(names, k)
        end
    end
    table.sort(names)
    return names
end

function M.CheckAll()
    print("[InterfaceChecker] 开始接口契约检查...")
    
    local checks = {
        { name = "GameUI", required = {
            "RefreshFleetPanel", "SetMapSelectedFleet", "RefreshPlanetPanel",
            "ShowEndGame", "ShowEventPopup", "Notify"
        }},
        { name = "ClientBattle", required = {
            "OnFleetSiegeBase", "StartExplorerTask", "SwitchScene", "GetPlayerTargets"
        }},
        { name = "ClientGalaxy", required = {
            "DoColonize", "OnBatchUpgrade", "OnExplorerColonize"
        }},
        { name = "GalaxyEvents", required = {
            "ScheduleChain"
        }},
        { name = "CampaignSystem", required = {
            "CompleteLevel"
        }},
        { name = "LegacySystem", required = {
            "AwardEndOfGame"
        }},
        { name = "Audio", required = {
            "PlayBGM", "Play"
        }}
    }
    
    local allPassed = true
    
    for _, check in ipairs(checks) do
        local passed = M.CheckModule(check.name, check.required)
        if not passed then allPassed = false end
    end
    
    if allPassed then
        print("\n[InterfaceChecker] ✓ 所有接口检查通过！")
    else
        print("\n[InterfaceChecker] ✗ 部分接口检查失败")
    end
    
    return allPassed
end

function M.CheckModule(moduleName, requiredFuncs)
    print(string.format("[InterfaceChecker] 检查模块: %s", moduleName))
    
    local success, module = pcall(require, moduleName:lower())
    
    if not success then
        print(string.format("  ✗ 模块加载失败: %s", module))
        return false
    end
    
    local foundFuncs = getFunctionNames(module)
    local foundSet = {}
    for _, name in ipairs(foundFuncs) do
        foundSet[name] = true
    end
    
    local allFound = true
    
    for _, funcName in ipairs(requiredFuncs) do
        if foundSet[funcName] then
            print(string.format("  ✓ %s", funcName))
        else
            print(string.format("  ✗ %s - 未找到", funcName))
            allFound = false
        end
    end
    
    return allFound
end

function M.CheckSpecific(moduleName, funcNames)
    return M.CheckModule(moduleName, funcNames)
end

return M