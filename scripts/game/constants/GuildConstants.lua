--[[
Constants/GuildConstants.lua
公会系统常量
]]

local M = {}

-- 公会等级奖励
M.GUILD_LEVEL_REWARDS = {
    { level = 1, exp = 0,       reward = { bonusGold = 0.05 },                  memberSlot = 10 },
    { level = 2, exp = 1000,    reward = { bonusGold = 0.10 },                  memberSlot = 15 },
    { level = 3, exp = 3000,    reward = { bonusGold = 0.15 },                  memberSlot = 20 },
    { level = 4, exp = 7000,    reward = { bonusGold = 0.20 },                  memberSlot = 30 },
    { level = 5, exp = 15000,   reward = { bonusGold = 0.25 },                  memberSlot = 50 },
    { level = 6, exp = 30000,   reward = { bonusGold = 0.30, bonusExp = 0.10 }, memberSlot = 75 },
    { level = 7, exp = 50000,   reward = { bonusGold = 0.35, bonusExp = 0.15 }, memberSlot = 100 },
    { level = 8, exp = 80000,   reward = { bonusGold = 0.40, bonusExp = 0.20 }, memberSlot = 150 },
}

-- 公会设置选项
M.GUILD_JOIN_TYPES = {
    OPEN     = { id = "OPEN",     name = "开放加入", desc = "任何人都可以立即加入" },
    APPROVAL = { id = "APPROVAL", name = "需要审批", desc = "需要会长/官员审批" },
    INVITE   = { id = "INVITE",   name = "仅邀请",   desc = "只能通过邀请加入" },
}

-- 公会成员角色
M.GUILD_ROLES = {
    LEADER  = { name = "会长", permissions = { kick = true,  promote = true,  settings = true,  disband = true } },
    OFFICER = { name = "官员", permissions = { kick = true,  promote = false, settings = false, disband = false } },
    MEMBER  = { name = "成员", permissions = { kick = false, promote = false, settings = false, disband = false } },
}

-- 公会每日任务
M.GUILD_DAILY_TASKS = {
    { id = "TASK_DONATE", name = "公会捐赠", desc = "向公会捐赠 100 金属",
      target = 100, type = "DONATE",   reward = { contribution = 50,  guildExp = 10 } },
    { id = "TASK_BATTLE", name = "公会战斗", desc = "参与公会活动战斗 3 次",
      target = 3,   type = "BATTLE",   reward = { contribution = 30,  guildExp = 5 } },
    { id = "TASK_RALLY",  name = "公会集结", desc = "响应集结请求",
      target = 1,   type = "RALLY",    reward = { contribution = 100, guildExp = 20 } },
}

-- 公会每周挑战
M.GUILD_WEEKLY_TASKS = {
    { id = "WEEKLY_WAVE", name = "周波次挑战", desc = "本周累计达到波次 100",
      target = 100, type = "TOTAL_WAVE",  reward = { contribution = 500, guildExp = 100, item = "GUILD_CHEST" } },
    { id = "WEEKLY_KILL", name = "周击杀挑战", desc = "本周累计击杀 500 艘敌舰",
      target = 500, type = "TOTAL_KILL",  reward = { contribution = 300, guildExp = 60 } },
    { id = "WEEKLY_BOSS", name = "Boss击杀",  desc = "本周击败 Boss 5 次",
      target = 5,   type = "BOSS_KILL",   reward = { contribution = 400, guildExp = 80, item = "LEGENDARY_BOX" } },
}

-- 运行时数据
M.RUNTIME_GUILDS = {}
M.RUNTIME_PLAYER_GUILD = {}

return M
