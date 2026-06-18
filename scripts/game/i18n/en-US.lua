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

    -- ========================================================================
    -- Technology Names & Descriptions
    -- ========================================================================

    ["tech.deep_mining.name"] = "Deep Mining",
    ["tech.deep_mining.desc"] = "Mining output +20%. Deep drilling technology for planetary core resources.",
    ["tech.solar_efficiency.name"] = "Solar Efficiency",
    ["tech.solar_efficiency.desc"] = "Power plant output +15%. Improved photovoltaic efficiency.",
    ["tech.crystal_process.name"] = "Crystal Processing",
    ["tech.crystal_process.desc"] = "Crystal processing efficiency +20%.",
    ["tech.hull_alloy.name"] = "Hull Alloy",
    ["tech.hull_alloy.desc"] = "All ships durability +25%.",
    ["tech.shield_reinforce.name"] = "Shield Reinforcement",
    ["tech.shield_reinforce.desc"] = "Shield +100, defense +10%.",
    ["tech.rapid_refine.name"] = "Rapid Refining",
    ["tech.rapid_refine.desc"] = "Ship build time -15%.",
    ["tech.warp_drive.name"] = "Warp Drive",
    ["tech.warp_drive.desc"] = "Fleet movement speed +50%.",
    ["tech.advanced_weapons.name"] = "Advanced Weapons",
    ["tech.advanced_weapons.desc"] = "All battleship attack +30%.",
    ["tech.defense_matrix.name"] = "Defense Matrix",
    ["tech.defense_matrix.desc"] = "Fleet health +30%, shield max +20%.",
    ["tech.void_anchor.name"] = "Void Anchor",
    ["tech.void_anchor.desc"] = "Enemy fleet speed -30%.",
    ["tech.nova_cannon.name"] = "Nova Cannon",
    ["tech.nova_cannon.desc"] = "AOE radius +80%, all damage +50%.",
    ["tech.fortress_protocol.name"] = "Fortress Protocol",
    ["tech.fortress_protocol.desc"] = "Base shield doubled, recovers 1% per second.",
    ["tech.quantum_core.name"] = "Quantum Core",
    ["tech.quantum_core.desc"] = "Research speed +50%, core upgrade cost -20%.",
    ["tech.phase_drive.name"] = "Phase Drive",
    ["tech.phase_drive.desc"] = "Fleet speed +50% again, gains stealth ability.",
    ["tech.stellar_sync.name"] = "Stellar Sync",
    ["tech.stellar_sync.desc"] = "Global production +25%, research +30%.",
    ["tech.stellar_engine.name"] = "Stellar Engine",
    ["tech.stellar_engine.desc"] = "Global speed +60%, battle start acceleration.",
    ["tech.quantum_factory.name"] = "Quantum Factory",
    ["tech.quantum_factory.desc"] = "Ship build speed doubled, upgrade cost -25%.",
    ["tech.void_fleet.name"] = "Void Fleet",
    ["tech.void_fleet.desc"] = "Enemy fleet spawn -30%, enemy damage -20%.",
    ["tech.fortress_protocol_ii.name"] = "Fortress Protocol II",
    ["tech.fortress_protocol_ii.desc"] = "Base shield x3, recovers 2%/sec, counter-shield on hit.",
    ["tech.chrono_research.name"] = "Chrono Research",
    ["tech.chrono_research.desc"] = "Research speed x2.5, event frequency halved.",
    ["tech.galactic_ascend.name"] = "Galactic Ascend",
    ["tech.galactic_ascend.desc"] = "Global damage x2, fleet cap +3, skill points +2/wave, rewards x2.",

    -- ========================================================================
    -- Ship Type Names & Descriptions
    -- ========================================================================

    ["ship.fighter.name"] = "Fighter",
    ["ship.fighter.desc"] = "High-speed light ship, excels at swift attacks.",
    ["ship.corvette.name"] = "Corvette",
    ["ship.corvette.desc"] = "Balanced ship, suitable for flank support.",
    ["ship.destroyer.name"] = "Destroyer",
    ["ship.destroyer.desc"] = "Main combat ship, front-line主力.",
    ["ship.battlecruiser.name"] = "Battlecruiser",
    ["ship.battlecruiser.desc"] = "Heavy firepower ship, rear-line core.",
    ["ship.carrier.name"] = "Carrier",
    ["ship.carrier.desc"] = "Carrier-based aircraft platform.",
    ["ship.void_lord.name"] = "Void Lord",
    ["ship.void_lord.desc"] = "Ultimate warship, crushes all.",
    ["ship.devastator.name"] = "Devastator",
    ["ship.devastator.desc"] = "Doomsday weapon, leaves nothing behind.",
    ["ship.engineer.name"] = "Engineer",
    ["ship.engineer.desc"] = "Support ship, periodically heals nearby allies.",
    ["ship.stealth.name"] = "Stealth",
    ["ship.stealth.desc"] = "High burst, low survival, periodically enters stealth.",
    ["ship.railgun.name"] = "Railgun",
    ["ship.railgun.desc"] = "Ultra-long range single-target high damage, fires railgun after charging.",

    -- ========================================================================
    -- Battle Command Names & Descriptions
    -- ========================================================================

    ["battlecmd.focus_fire.name"] = "Focus Fire",
    ["battlecmd.focus_fire.desc"] = "All fleet focuses target: +50% damage, +100% fire rate, 8 sec",
    ["battlecmd.defense_stance.name"] = "Defense Stance",
    ["battlecmd.defense_stance.desc"] = "Fleet enters defense: -30% damage, +50% defense, 10 sec",
    ["battlecmd.tactical_retreat.name"] = "Tactical Retreat",
    ["battlecmd.tactical_retreat.desc"] = "Fleet retreats: +30% speed, shield +40%, can't attack for 5 sec",
    ["battlecmd.full_salvo.name"] = "Full Salvo",
    ["battlecmd.full_salvo.desc"] = "Fire all weapons at once: +200% damage, consumes all skill charges",
    ["battlecmd.emergency_repair.name"] = "Emergency Repair",
    ["battlecmd.emergency_repair.desc"] = "Emergency repair 30% max HP, 60 sec cooldown",

    -- ========================================================================
    -- Roguelike Card Names & Descriptions
    -- ========================================================================

    ["roguelike.attack_overdrive.name"] = "Attack Overdrive",
    ["roguelike.attack_overdrive.desc"] = "All ship attack +20%",
    ["roguelike.reinforced_armor.name"] = "Reinforced Armor",
    ["roguelike.reinforced_armor.desc"] = "All ship defense +25%",
    ["roguelike.phase_shield.name"] = "Phase Shield",
    ["roguelike.phase_shield.desc"] = "Shield max +30%, regen +15%",
    ["roguelike.resource_boon.name"] = "Resource Boon",
    ["roguelike.resource_boon.desc"] = "Base resource output +40%",
    ["roguelike.hyperspeed.name"] = "Hyperspeed",
    ["roguelike.hyperspeed.desc"] = "Fleet speed +35%, fire rate +15%",
    ["roguelike.quantum_factory.name"] = "Quantum Factory",
    ["roguelike.quantum_factory.desc"] = "Ship build speed +50%, upgrade cost -20%",
    ["roguelike.skill_charge.name"] = "Tactical Charge",
    ["roguelike.skill_charge.desc"] = "Skill charge +2 at battle start",
    ["roguelike.bloodlust.name"] = "Bloodlust",
    ["roguelike.bloodlust.desc"] = "Attack +50%, but take damage +25%",
    ["roguelike.bastion_protocol.name"] = "Bastion Protocol",
    ["roguelike.bastion_protocol.desc"] = "Defense +60%, shield +40%, but speed -30%",
    ["roguelike.power_drain.name"] = "Power Drain",
    ["roguelike.power_drain.desc"] = "Resource output +100%, but lose 5% HP per wave",
    ["roguelike.overclock.name"] = "Overclock",
    ["roguelike.overclock.desc"] = "Fire rate +75%, but shield regen -50%",
    ["roguelike.battle_lust.name"] = "Battle Lust",
    ["roguelike.battle_lust.desc"] = "Restore 2% max HP per enemy killed",
    ["roguelike.critical_mass.name"] = "Critical Mass",
    ["roguelike.critical_mass.desc"] = "Crit rate +20%, crit damage +50%",
    ["roguelike.afterburner.name"] = "Afterburner",
    ["roguelike.afterburner.desc"] = "Evasion +15%, immune to first lethal hit and heal 50% HP",
    ["roguelike.galactic_luck.name"] = "Galactic Luck",
    ["roguelike.galactic_luck.desc"] = "Gain 1 extra card option each selection",
    ["roguelike.void_strike.name"] = "Void Strike",
    ["roguelike.void_strike.desc"] = "All attacks deal 10% current HP as true damage",

    -- ========================================================================
    -- Game Settings Text
    -- ========================================================================

    ["settings.audio"] = "Audio",
    ["settings.graphics"] = "Graphics",
    ["settings.gameplay"] = "Gameplay",
    ["settings.accessibility"] = "Accessibility",
    ["settings.language"] = "Language",
    ["settings.master_volume"] = "Master Volume",
    ["settings.music_volume"] = "Music Volume",
    ["settings.sfx_volume"] = "SFX Volume",
    ["settings.voice_volume"] = "Voice Volume",
    ["settings.graphics_quality"] = "Graphics Quality",
    ["settings.resolution"] = "Resolution",
    ["settings.fullscreen"] = "Fullscreen",
    ["settings.vsync"] = "Vertical Sync",
    ["settings.particle_effects"] = "Particle Effects",
    ["settings.ambient_occlusion"] = "Ambient Occlusion",
    ["settings.bloom"] = "Bloom Effects",
    ["settings.game_speed"] = "Game Speed",
    ["settings.autosave_interval"] = "Autosave Interval",
    ["settings.show_damage_numbers"] = "Show Damage Numbers",
    ["settings.show_tutorial_hints"] = "Show Tutorial Hints",
    ["settings.confirm_before_exit"] = "Confirm Before Exit",
    ["settings.colorblind_mode"] = "Colorblind Mode",
    ["settings.colorblind_none"] = "None",
    ["settings.colorblind_red_green"] = "Red-Green Colorblind",
    ["settings.colorblind_blue_yellow"] = "Blue-Yellow Colorblind",
    ["settings.font_size"] = "Font Size",
    ["settings.font_small"] = "Small",
    ["settings.font_medium"] = "Medium",
    ["settings.font_large"] = "Large",
    ["settings.high_contrast"] = "High Contrast Mode",
    ["settings.reduced_motion"] = "Reduced Motion",
    ["settings.screen_shake"] = "Screen Shake",
    ["settings.damage_flash"] = "Damage Flash",

    -- ========================================================================
    -- Difficulty Names & Descriptions
    -- ========================================================================

    ["difficulty.easy.name"] = "Easy",
    ["difficulty.easy.desc"] = "For beginners: weaker enemies, generous resources.",
    ["difficulty.normal.name"] = "Normal",
    ["difficulty.normal.desc"] = "Standard experience: balanced challenge and rewards.",
    ["difficulty.hard.name"] = "Hard",
    ["difficulty.hard.desc"] = "Advanced challenge: stronger enemies, scarcer resources.",
    ["difficulty.nightmare.name"] = "Nightmare",
    ["difficulty.nightmare.desc"] = "Extreme challenge: extremely powerful enemies, extreme resource scarcity.",

    -- ========================================================================
    -- Campaign Chapter Names
    -- ========================================================================

    ["campaign.prologue.name"] = "Prologue: Sparking Fire",
    ["campaign.chapter1.name"] = "Chapter 1: Darkness Falls",
    ["campaign.chapter2.name"] = "Chapter 2: Empire Strikes Back",
    ["campaign.stage.objective.assault"] = "Assault",
    ["campaign.stage.objective.defend"] = "Defense",
    ["campaign.stage.objective.survive"] = "Survival",
    ["campaign.stage.objective.eliminate"] = "Elimination",
    ["campaign.stage.objective.escort"] = "Escort",
    ["campaign.stage.difficulty.easy"] = "Easy",
    ["campaign.stage.difficulty.medium"] = "Normal",
    ["campaign.stage.difficulty.hard"] = "Hard",
    ["campaign.stage.difficulty.extreme"] = "Extreme",

    -- ========================================================================
    -- Season Text
    -- ========================================================================

    ["season.current"] = "Current Season",
    ["season.next"] = "Next Season",
    ["season.ends_in"] = "{days} days remaining",
    ["season.points"] = "Season Points",
    ["season.rank"] = "Season Rank",
    ["season.rewards"] = "Season Rewards",
    ["season.exclusive"] = "Season Exclusive",

    -- ========================================================================
    -- Galaxy Event Text (New Events)
    -- ========================================================================

    ["event.stargate_open.name"] = "Stargate Open",
    ["event.stargate_open.desc"] = "Stargate opens, providing fast travel通道.",
    ["event.wormhole_appears.name"] = "Wormhole Appears",
    ["event.wormhole_appears.desc"] = "Mysterious wormhole connects two distant regions.",
    ["event.rare_mineral_discovery.name"] = "Rare Mineral Discovery",
    ["event.rare_mineral_discovery.desc"] = "Rare mineral resources detected, mining efficiency greatly increased.",
    ["event.solar_storm.name"] = "Solar Storm",
    ["event.solar_storm.desc"] = "Solar storm interferes with electronic equipment.",
    ["event.trade_festival.name"] = "Interstellar Trade Festival",
    ["event.trade_festival.desc"] = "No trade tax, all trade income +50%.",
    ["event.alien_contact.name"] = "Alien Contact",
    ["event.alien_contact.desc"] = "Contact established with mysterious alien civilization.",
    ["event.void_rift.name"] = "Void Rift",
    ["event.void_rift.desc"] = "Spatial rift opens, unleashing anomalous energy creatures.",
    ["event.pirate_harbor.name"] = "Pirate Harbor",
    ["event.pirate_harbor.desc"] = "Pirate hideout discovered, rich spoils available.",
    ["event.mercenary_offer.name"] = "Mercenary Recruitment",
    ["event.mercenary_offer.desc"] = "Mercenary fleet offers assistance, payment required.",
    ["event.ambush.name"] = "Ambush Warning",
    ["event.ambush.desc"] = "Intelligence shows ambush positions ahead, proceed with caution.",
    ["event.ancient_ruins.name"] = "Ancient Ruins",
    ["event.ancient_ruins.desc"] = "Lost civilization ruins discovered, may contain precious technology.",
    ["event.abandoned_fleet.name"] = "Abandoned Fleet",
    ["event.abandoned_fleet.desc"] = "Abandoned warship wreckage found, salvageable parts available.",
    ["event.comet_shower.name"] = "Comet Shower",
    ["event.comet_shower.desc"] = "Numerous comets sweep through the galaxy, bringing rare ice core resources.",
    ["event.nebula_passage.name"] = "Nebula Passage",
    ["event.nebula_passage.desc"] = "Passing through mysterious nebula grants temporary energy boost to fleet.",
    ["event.wormhole_stable.name"] = "Stable Wormhole",
    ["event.wormhole_stable.desc"] = "Stable wormhole discovered, greatly reduces travel time.",
    ["event.distant_signal.name"] = "Distant Signal",
    ["event.distant_signal.desc"] = "Mysterious signal received from deep space, leads to unknown region.",
    ["event.diplomatic_gift.name"] = "Diplomatic Gift",
    ["event.diplomatic_gift.desc"] = "Friendly faction sends precious gift.",
    ["event.trade_embargo.name"] = "Trade Embargo",
    ["event.trade_embargo.desc"] = "Galaxy economy turmoil, trade income temporarily reduced.",
    ["event.guild_merger.name"] = "Guild Alliance",
    ["event.guild_merger.desc"] = "Multiple guilds propose alliance against common threats.",
    ["event.trade_storm.name"] = "Trade Storm",
    ["event.trade_storm.desc"] = "Galaxy-wide market prices fluctuate drastically.",
    ["event.mining_boom.name"] = "Mining Boom",
    ["event.mining_boom.desc"] = "Mining district bumper harvest, mineral production surges.",
    ["event.crystal_swarm.name"] = "Crystal Swarm",
    ["event.crystal_swarm.desc"] = "Crystal ore veins abnormally active, output greatly increased.",
    ["event.warp_anomaly.name"] = "Warp Anomaly",
    ["event.warp_anomaly.desc"] = "Warp travel experiences random coordinate deviation.",
    ["event.gateway_activation.name"] = "Gateway Activation",
    ["event.gateway_activation.desc"] = "New jump gate to unknown galaxy discovered.",
    ["event.stellar_flare.name"] = "Stellar Flare",
    ["event.stellar_flare.desc"] = "Nearby star erupts, releasing tremendous energy.",
    ["event.void_storm.name"] = "Void Storm",
    ["event.void_storm.desc"] = "Void energy storm sweeps across the galaxy, opportunity and danger并存.",
    ["event.golden_age.name"] = "Golden Age",
    ["event.golden_age.desc"] = "Galaxy enters period of prosperity, all production greatly increased.",

    -- ========================================================================
    -- Resource Type Text
    -- ========================================================================

    ["resource.minerals"] = "Minerals",
    ["resource.energy"] = "Energy",
    ["resource.crystal"] = "Crystal",
    ["resource.nuclear"] = "Nuclear",
    ["resource.credits"] = "Credits",
    ["resource.blue_crystal"] = "Blue Crystal",
    ["resource.purple_crystal"] = "Purple Crystal",
    ["resource.rainbow_crystal"] = "Rainbow Crystal",

    -- ========================================================================
    -- Battle Environment Text
    -- ========================================================================

    ["environment.asteroid_field.name"] = "Asteroid Field",
    ["environment.asteroid_field.desc"] = "Speed -30%, but 20% cover bonus.",
    ["environment.nebula.name"] = "Nebula",
    ["environment.nebula.desc"] = "Stealth +50%, detection range -30%.",
    ["environment.solar_storm.name"] = "Solar Storm",
    ["environment.solar_storm.desc"] = "Shield efficiency -40%, energy regen -20%.",
    ["environment.gravity_well.name"] = "Gravity Well",
    ["environment.gravity_well.desc"] = "All ship and projectile speeds halved.",
    ["environment.debris_field.name"] = "Debris Field",
    ["environment.debris_field.desc"] = "40% cover, 20% chance to salvage resources.",
    ["environment.ion_storm.name"] = "Ion Storm",
    ["environment.ion_storm.desc"] = "Shield regen -50%, skill cooldown +30%.",
    ["environment.warp_zone.name"] = "Warp Zone",
    ["environment.warp_zone.desc"] = "Speed x2, skill cooldown -30%.",
    ["environment.crystal_field.name"] = "Crystal Field",
    ["environment.crystal_field.desc"] = "Shield efficiency +30%, 15% chance for bonus crystal.",

    -- ========================================================================
    -- Formation Text
    -- ========================================================================

    ["formation.vanguard.name"] = "Vanguard Formation",
    ["formation.vanguard.desc"] = "Ships spread out, reducing AOE damage.",
    ["formation.phalanx.name"] = "Phalanx",
    ["formation.phalanx.desc"] = "Tight formation, concentrated firepower.",
    ["formation.flank.name"] = "Flanking Maneuver",
    ["formation.flank.desc"] = "Attack from flanks, enhanced mobility.",
    ["formation.crescent.name"] = "Crescent Formation",
    ["formation.crescent.desc"] = "Curved formation, balanced offense and defense.",
    ["formation.pinzher.name"] = "Pincers",
    ["formation.pinzher.desc"] = "Encirclement attack, priority focus fire.",
    ["formation.skirmish.name"] = "Skirmish Formation",
    ["formation.skirmish.desc"] = "Maintain distance, hit and run tactics.",

    -- ========================================================================
    -- Quick Signal Text
    -- ========================================================================

    ["signal.rally"] = "Rally",
    ["signal.retreat"] = "Retreat",
    ["signal.help"] = "Help",
    ["signal.target"] = "Mark Target",
    ["signal.attack"] = "Attack",
    ["signal.defend"] = "Defend",
    ["signal.wait"] = "Wait",
}
