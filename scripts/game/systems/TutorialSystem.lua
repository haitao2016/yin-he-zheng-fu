--[[
TutorialSystem.lua - 新手教程系统
V2.7 P1-6
分步骤引导玩家熟悉系统
]]

local TutorialSystem = {}

-- 教程步骤定义
TutorialSystem.TUTORIAL_STEPS = {
    {
        id = "WELCOME",
        title = "欢迎来到星际征服",
        content = "这是一款太空策略游戏，你需要指挥舰队抵御敌人进攻，并发展自己的星球。",
        highlightArea = nil,
        nextLabel = "开始",
        condition = function(ps) return true end,
    },
    {
        id = "FLEET",
        title = "舰队管理",
        content = "点击下方的舰队按钮，可以建造和部署你的舰队。驱逐舰是你的主要战斗力。",
        highlightArea = "fleet_button",
        nextLabel = "知道了",
    },
    {
        id = "BUILD",
        title = "建造舰船",
        content = "点击建造队列中的舰船图标来建造。建造需要消耗资源。",
        highlightArea = "build_queue",
        nextLabel = "继续",
    },
    {
        id = "BATTLE",
        title = "战斗",
        content = "每波敌人进攻时，使用技能按钮释放技能来增强舰队战斗力。",
        highlightArea = "skill_bar",
        nextLabel = "好的",
    },
    {
        id = "RESOURCES",
        title = "资源管理",
        content = "顶部显示你的资源。金属和能源是最基础的资源。蓝晶石是稀有资源。",
        highlightArea = "resource_bar",
        nextLabel = "明白",
    },
    {
        id = "UPGRADE",
        title = "升级建筑",
        content = "点击星球上的建筑可以升级它们。高级建筑产出更多资源。",
        highlightArea = "planet_panel",
        nextLabel = "完成教程",
    },
}

-- 获取当前教程进度
function TutorialSystem.getProgress(playerState)
    playerState.tutorialProgress = playerState.tutorialProgress or 0
    return playerState.tutorialProgress
end

-- 获取当前教程步骤
function TutorialSystem.getCurrentStep(playerState)
    local progress = TutorialSystem.getProgress(playerState)
    if progress >= #TutorialSystem.TUTORIAL_STEPS then
        return nil  -- 教程完成
    end
    return TutorialSystem.TUTORIAL_STEPS[progress + 1]
end

-- 完成当前步骤
function TutorialSystem.completeStep(playerState)
    playerState.tutorialProgress = (playerState.tutorialProgress or 0) + 1
    
    -- 保存进度
    if saveValue then
        saveValue("tutorial_progress", playerState.tutorialProgress)
    end
end

-- 跳过教程
function TutorialSystem.skipTutorial(playerState)
    playerState.tutorialProgress = #TutorialSystem.TUTORIAL_STEPS
    playerState.tutorialSkipped = true
    
    if saveValue then
        saveValue("tutorial_progress", playerState.tutorialProgress)
        saveValue("tutorial_skipped", true)
    end
end

-- 是否已完成教程
function TutorialSystem.isCompleted(playerState)
    return (playerState.tutorialProgress or 0) >= #TutorialSystem.TUTORIAL_STEPS
end

-- 是否应该显示教程
function TutorialSystem.shouldShowTutorial(playerState)
    if TutorialSystem.isCompleted(playerState) then return false end
    if playerState.tutorialSkipped then return false end
    return true
end

return TutorialSystem