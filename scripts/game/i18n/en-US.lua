-- ============================================================================
-- game/i18n/en-US.lua -- English (US) resource file
-- ============================================================================

return {
    -- ========================================================================
    -- UI General Text
    -- ========================================================================

    ["ui.confirm"] = "Confirm",
    ["ui.cancel"] = "Cancel",
    ["ui.save"] = "Save",
    ["ui.settings"] = "Settings",
    ["ui.exit"] = "Exit",
    ["ui.research"] = "Research",
    ["ui.fleet"] = "Fleet",
    ["ui.base"] = "Base",
    ["ui.campaign"] = "Campaign",
    ["ui.season"] = "Season",
    ["ui.guild"] = "Guild",
    ["ui.friends"] = "Friends",

    ["ui.back"] = "Back",
    ["ui.close"] = "Close",
    ["ui.ok"] = "OK",
    ["ui.yes"] = "Yes",
    ["ui.no"] = "No",
    ["ui.next"] = "Next",
    ["ui.prev"] = "Prev",
    ["ui.search"] = "Search",
    ["ui.filter"] = "Filter",
    ["ui.sort"] = "Sort",

    ["ui.level"] = "Level",
    ["ui.exp"] = "EXP",
    ["ui.power"] = "Power",
    ["ui.reward"] = "Reward",
    ["ui.claim"] = "Claim",
    ["ui.locked"] = "Locked",
    ["ui.unlocked"] = "Unlocked",
    ["ui.completed"] = "Completed",
    ["ui.inProgress"] = "In Progress",

    ["ui.loading"] = "Loading...",
    ["ui.connecting"] = "Connecting...",
    ["ui.error"] = "Error",
    ["ui.success"] = "Success",
    ["ui.warning"] = "Warning",
    ["ui.info"] = "Info",

    ["ui.language"] = "Language",
    ["ui.chinese"] = "简体中文",
    ["ui.english"] = "English",

    -- ========================================================================
    -- Achievement Descriptions
    -- ========================================================================

    ["achievement.first_blood.name"] = "First Blood",
    ["achievement.first_blood.desc"] = "Defeat your first Boss",

    ["achievement.boss_slayer.name"] = "Boss Slayer",
    ["achievement.boss_slayer.desc"] = "Defeat {count} Bosses",

    ["achievement.legendary_hunter.name"] = "Legendary Hunter",
    ["achievement.legendary_hunter.desc"] = "Defeat a Super Boss",

    ["achievement.unbroken.name"] = "Unbroken",
    ["achievement.unbroken.desc"] = "Clear any wave without taking damage",

    ["achievement.endless_warrior.name"] = "Endless Warrior",
    ["achievement.endless_warrior.desc"] = "Reach wave {wave} in Endless Mode",

    ["achievement.boss_rush_champion.name"] = "Boss Rush Champion",
    ["achievement.boss_rush_champion.desc"] = "Complete Boss Rush (5 Bosses)",

    ["achievement.first_steps.name"] = "First Steps",
    ["achievement.first_steps.desc"] = "Research your first technology",

    ["achievement.research_master.name"] = "Research Master",
    ["achievement.research_master.desc"] = "Research all technologies",

    ["achievement.ship_builder.name"] = "Ship Builder",
    ["achievement.ship_builder.desc"] = "Build {count} ships",

    ["achievement.fleet_admiral.name"] = "Fleet Admiral",
    ["achievement.fleet_admiral.desc"] = "Reach {power} total fleet power",

    ["achievement.trading_tycoon.name"] = "Trading Tycoon",
    ["achievement.trading_tycoon.desc"] = "Complete {count} trades",

    ["achievement.guild_founder.name"] = "Guild Founder",
    ["achievement.guild_founder.desc"] = "Found a guild",

    ["achievement.campaign_hero.name"] = "Campaign Hero",
    ["achievement.campaign_hero.desc"] = "Complete Chapter 1 of the campaign",

    ["achievement.season_veteran.name"] = "Season Veteran",
    ["achievement.season_veteran.desc"] = "Earn {points} cumulative season points",

    ["achievement.galactic_explorer.name"] = "Galactic Explorer",
    ["achievement.galactic_explorer.desc"] = "Explore {count} star systems",

    ["achievement.resource_baron.name"] = "Resource Baron",
    ["achievement.resource_baron.desc"] = "Collect {amount} total resources",

    ["achievement.speed_runner.name"] = "Speed Runner",
    ["achievement.speed_runner.desc"] = "Finish any campaign in {time} seconds",

    ["achievement.commander_elite.name"] = "Elite Commander",
    ["achievement.commander_elite.desc"] = "Reach commander level {level}",

    ["achievement.perfectionist.name"] = "Perfectionist",
    ["achievement.perfectionist.desc"] = "Earn 3 stars on any campaign stage",

    ["achievement.survivor.name"] = "Survivor",
    ["achievement.survivor.desc"] = "Clear wave {wave} without losing a ship",

    -- ========================================================================
    -- Event Descriptions
    -- ========================================================================

    ["event.pirate_raid.name"] = "Pirate Raid",
    ["event.pirate_raid.desc"] = "A pirate fleet appears nearby. Prepare for battle!",

    ["event.merchant_ship.name"] = "Merchant Visit",
    ["event.merchant_ship.desc"] = "A friendly merchant ship offers rare goods.",

    ["event.asteroid_field.name"] = "Asteroid Field",
    ["event.asteroid_field.desc"] = "A mineral-rich asteroid field has been discovered.",

    ["event.anomaly.name"] = "Spatial Anomaly",
    ["event.anomaly.desc"] = "Unknown spatial anomaly detected—could be treasure or trouble.",

    ["event.distress_signal.name"] = "Distress Signal",
    ["event.distress_signal.desc"] = "A distress call received from a stranded vessel. Answer the call?",

    ["event.nebulon.name"] = "Nebula Wonder",
    ["event.nebulon.desc"] = "Passing through a beautiful nebula grants a brief energy boost.",

    ["event.black_hole.name"] = "Black Hole Warning",
    ["event.black_hole.desc"] = "Black hole gravity field detected ahead. Proceed with extreme caution!",

    ["event.ancient_ruins.name"] = "Ancient Ruins",
    ["event.ancient_ruins.desc"] = "Lost civilization ruins discovered—may contain precious technology.",

    ["event.space_storm.name"] = "Space Storm",
    ["event.space_storm.desc"] = "A powerful ion storm is approaching, reducing fleet maneuverability.",

    ["event.diplomatic_meeting.name"] = "Diplomatic Meeting",
    ["event.diplomatic_meeting.desc"] = "A friendly faction invites you to a diplomatic meeting.",

    ["event.supernova.name"] = "Supernova",
    ["event.supernova.desc"] = "A nearby star has erupted violently—radiation hazard!",

    ["event.derelict.name"] = "Derelict Ship",
    ["event.derelict.desc"] = "An abandoned warship spotted—may still hold useful supplies.",

    ["event.alien_contact.name"] = "First Contact",
    ["event.alien_contact.desc"] = "First contact with an unknown alien civilization.",

    ["event.bounty_hunter.name"] = "Bounty Hunter",
    ["event.bounty_hunter.desc"] = "Your bounty has attracted elite bounty hunters.",

    ["event.void_rift.name"] = "Void Rift",
    ["event.void_rift.desc"] = "A mysterious rift opens, unleashing anomalous energy beings.",

    ["event.comet_shower.name"] = "Comet Shower",
    ["event.comet_shower.desc"] = "Comets sweep through the system, bringing rare ice cores.",

    -- ========================================================================
    -- Commander Skill Text
    -- ========================================================================

    ["commander.skill.tactical_genius.name"] = "Tactical Genius",
    ["commander.skill.tactical_genius.desc"] = "All ship attack +{value}%",

    ["commander.skill.defensive_mastery.name"] = "Defensive Mastery",
    ["commander.skill.defensive_mastery.desc"] = "All damage taken -{value}%",

    ["commander.skill.logistics_expert.name"] = "Logistics Expert",
    ["commander.skill.logistics_expert.desc"] = "Resource production efficiency +{value}%",

    ["commander.skill.engineering_wizard.name"] = "Engineering Wizard",
    ["commander.skill.engineering_wizard.desc"] = "Ship build time -{value}%",

    ["commander.skill.research_visionary.name"] = "Research Visionary",
    ["commander.skill.research_visionary.desc"] = "Tech research speed +{value}%",

    ["commander.skill.diplomatic_charm.name"] = "Diplomatic Charm",
    ["commander.skill.diplomatic_charm.desc"] = "Trade profit +{value}%",

    ["commander.skill.admiral_aura.name"] = "Admiral Aura",
    ["commander.skill.admiral_aura.desc"] = "Total fleet power +{value}%",

    ["commander.skill.lucky_star.name"] = "Lucky Star",
    ["commander.skill.lucky_star.desc"] = "Rare item drop rate +{value}%",

    ["commander.skill.rapid_deployment.name"] = "Rapid Deployment",
    ["commander.skill.rapid_deployment.desc"] = "Fleet deployment time -{value}%",

    ["commander.skill.resource_sense.name"] = "Resource Sense",
    ["commander.skill.resource_sense.desc"] = "Resource discovery chance +{value}%",

    ["commander.skill.vanguard.name"] = "Vanguard Command",
    ["commander.skill.vanguard.desc"] = "First wave deals extra +{value}% damage",

    ["commander.skill.iron_will.name"] = "Iron Will",
    ["commander.skill.iron_will.desc"] = "Retain {value}% combat strength after losses",
}
