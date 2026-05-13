# Pacing, Flow, and Dynamic Difficulty

Advanced pacing techniques, dynamic difficulty adjustment integrated with level design, and metric tracking for UrhoX Lua games.

---

## 1. Advanced Pacing Techniques

### Intensity Curve Shapes

Different genres require different intensity curve patterns:

```
ACTION GAME (High Tempo):
  ████   ██   ████   ███   █████
  ██  █  ██   █  █   █ █   █   █
  █    ██  ███    ███   ███     ████
  Rapid oscillation, short rest periods

HORROR GAME (Tension Build):
  ─────────────────────────████████
  ─────────────────███████
  ─────────████████
  ─────████
  Slow build to a single overwhelming peak

PUZZLE GAME (Eureka Moments):
  ────█   ────██   ────███
  ────     ────     ────
  Low baseline with sudden spikes of satisfaction

RPG / ADVENTURE (Rising Waves):
      ╱╲        ╱╲╱╲
     ╱  ╲  ╱╲  ╱    ╲
  ──╱    ╲╱  ╲╱      ╲──
  Each wave higher than the last
```

### Beat Chart

A beat chart maps level progression through discrete "beats":

```lua
--- Beat chart: sequence of designed moments in a level
---@class Beat
---@field name string
---@field type string "setup"|"tension"|"climax"|"relief"|"reward"
---@field intensity number 0.0-1.0
---@field durationSec number expected duration
---@field notes string design notes

--- Example beat chart for a dungeon level
local dungeonBeats = {
    { name = "Entrance Hall",    type = "setup",   intensity = 0.1, durationSec = 30,
      notes = "Safe zone, establish atmosphere, show distant objective" },
    { name = "First Encounter",  type = "tension", intensity = 0.4, durationSec = 45,
      notes = "2 weak enemies, teach combat basics" },
    { name = "Treasure Alcove",  type = "relief",  intensity = 0.1, durationSec = 15,
      notes = "Small reward, health pickup, safe moment" },
    { name = "Corridor Ambush",  type = "tension", intensity = 0.6, durationSec = 40,
      notes = "3 enemies from multiple directions, test awareness" },
    { name = "Bridge Puzzle",    type = "tension", intensity = 0.5, durationSec = 60,
      notes = "Logic puzzle, change of pace from combat" },
    { name = "Safe Room",        type = "relief",  intensity = 0.0, durationSec = 20,
      notes = "Save point, resource replenishment, lore" },
    { name = "Mini-boss Arena",  type = "climax",  intensity = 0.8, durationSec = 90,
      notes = "Tough enemy, use all learned skills" },
    { name = "Loot Room",        type = "reward",  intensity = 0.1, durationSec = 20,
      notes = "Significant reward, sense of accomplishment" },
    { name = "Final Corridor",   type = "tension", intensity = 0.5, durationSec = 30,
      notes = "Last gauntlet before boss, heighten anticipation" },
    { name = "Boss Chamber",     type = "climax",  intensity = 1.0, durationSec = 120,
      notes = "Level climax, multi-phase boss fight" },
    { name = "Victory",          type = "reward",  intensity = 0.0, durationSec = 15,
      notes = "Celebration, loot, story progression" },
}

--- Calculate total expected level duration from beat chart
---@param beats Beat[]
---@return number totalSeconds
local function calculateLevelDuration(beats)
    local total = 0
    for i = 1, #beats do
        total = total + beats[i].durationSec
    end
    return total
end

--- Get average intensity of a beat chart
---@param beats Beat[]
---@return number averageIntensity
local function calculateAverageIntensity(beats)
    local totalIntensity = 0
    local totalDuration = 0
    for i = 1, #beats do
        totalIntensity = totalIntensity + beats[i].intensity * beats[i].durationSec
        totalDuration = totalDuration + beats[i].durationSec
    end
    return totalDuration > 0 and (totalIntensity / totalDuration) or 0
end

-- Usage:
-- local duration = calculateLevelDuration(dungeonBeats)
-- log:Write(LOG_INFO, "Expected level duration: " .. duration .. "s")
-- local avgIntensity = calculateAverageIntensity(dungeonBeats)
-- log:Write(LOG_INFO, "Average intensity: " .. avgIntensity)
```

### Pacing Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| **Flat line** | Constant same intensity = boredom | Add peaks and valleys |
| **Relentless peaks** | No rest = exhaustion/frustration | Insert rest zones after every 2-3 encounters |
| **Delayed payoff** | Too much buildup before first action | Front-load an exciting moment early |
| **Momentum breaker** | Long cutscene mid-action | Keep interruptions brief or player-triggered |
| **Reward desert** | Long stretch without any pickup | Place micro-rewards every 60-90 seconds |

---

## 2. Dynamic Difficulty Integration

### Player Performance Tracking

```lua
--- Track player performance metrics for dynamic difficulty
local PlayerMetrics = {}
PlayerMetrics.__index = PlayerMetrics

function PlayerMetrics:new()
    local o = setmetatable({}, self)
    o.deaths = 0
    o.deathsInZone = {}       -- zoneName -> count
    o.damagesTaken = 0
    o.healingUsed = 0
    o.timeSinceLastDeath = 0
    o.killStreak = 0
    o.longestKillStreak = 0
    o.completedChallenges = 0
    o.failedChallenges = 0
    o.averageCompletionRatio = 1.0
    return o
end

function PlayerMetrics:recordDeath(zoneName)
    self.deaths = self.deaths + 1
    self.deathsInZone[zoneName] = (self.deathsInZone[zoneName] or 0) + 1
    self.killStreak = 0
    self.timeSinceLastDeath = 0
end

function PlayerMetrics:recordKill()
    self.killStreak = self.killStreak + 1
    if self.killStreak > self.longestKillStreak then
        self.longestKillStreak = self.killStreak
    end
end

function PlayerMetrics:recordChallengeResult(success)
    if success then
        self.completedChallenges = self.completedChallenges + 1
    else
        self.failedChallenges = self.failedChallenges + 1
    end
    local total = self.completedChallenges + self.failedChallenges
    self.averageCompletionRatio = self.completedChallenges / total
end

--- Get difficulty multiplier based on performance
---@return number multiplier 0.5 (easier) to 1.5 (harder)
function PlayerMetrics:getDifficultyMultiplier()
    local mult = 1.0

    -- Dying a lot in a zone: reduce difficulty
    -- Cruising through: increase difficulty
    if self.averageCompletionRatio < 0.4 then
        mult = mult - 0.3  -- struggling, make easier
    elseif self.averageCompletionRatio > 0.85 then
        mult = mult + 0.2  -- dominating, make harder
    end

    -- Kill streak bonus difficulty
    if self.killStreak > 10 then
        mult = mult + 0.1
    end

    return math.max(0.5, math.min(1.5, mult))
end

function PlayerMetrics:update(dt)
    self.timeSinceLastDeath = self.timeSinceLastDeath + dt
end
```

### Applying Dynamic Difficulty to Level Zones

```lua
--- Adjust zone parameters based on player performance
---@param metrics PlayerMetrics
---@param zoneConfig table base zone configuration
---@return table adjustedConfig
local function adjustZoneForPlayer(metrics, zoneConfig)
    local mult = metrics:getDifficultyMultiplier()

    local adjusted = {}
    for k, v in pairs(zoneConfig) do
        adjusted[k] = v
    end

    -- Scale enemy stats
    if adjusted.enemyHP then
        adjusted.enemyHP = math.floor(adjusted.enemyHP * mult)
    end
    if adjusted.enemyDamage then
        adjusted.enemyDamage = math.floor(adjusted.enemyDamage * mult)
    end
    if adjusted.enemyCount then
        adjusted.enemyCount = math.max(1, math.floor(adjusted.enemyCount * mult))
    end

    -- Scale resources inversely (more resources when struggling)
    if adjusted.healthPickups then
        adjusted.healthPickups = math.max(1,
            math.floor(adjusted.healthPickups * (2.0 - mult)))
    end

    return adjusted
end

-- Example:
-- local baseConfig = { enemyHP = 100, enemyDamage = 10, enemyCount = 3, healthPickups = 2 }
-- local adjusted = adjustZoneForPlayer(playerMetrics, baseConfig)
-- Struggling player: { enemyHP = 70, enemyDamage = 7, enemyCount = 2, healthPickups = 3 }
-- Skilled player:    { enemyHP = 120, enemyDamage = 12, enemyCount = 4, healthPickups = 1 }
```

---

## 3. Level Metric Tracking

### Runtime Metrics Collector

```lua
--- Collects runtime level metrics for analysis and balancing
local LevelMetrics = {}
LevelMetrics.__index = LevelMetrics

function LevelMetrics:new(levelName)
    local o = setmetatable({}, self)
    o.levelName = levelName
    o.startTime = 0
    o.endTime = 0
    o.totalDeaths = 0
    o.deathLocations = {}     -- { {x, y, z, timestamp} }
    o.secretsFound = 0
    o.secretsTotal = 0
    o.checkpointsReached = 0
    o.checkpointsTotal = 0
    o.enemiesKilled = 0
    o.enemiesTotal = 0
    o.itemsCollected = 0
    o.itemsTotal = 0
    o.zoneTimings = {}        -- zoneName -> seconds spent
    o.currentZone = nil
    o.zoneEnteredAt = 0
    return o
end

function LevelMetrics:start()
    self.startTime = os.clock()
end

function LevelMetrics:finish()
    self.endTime = os.clock()
    self:leaveCurrentZone()
end

function LevelMetrics:enterZone(zoneName)
    self:leaveCurrentZone()
    self.currentZone = zoneName
    self.zoneEnteredAt = os.clock()
end

function LevelMetrics:leaveCurrentZone()
    if self.currentZone then
        local elapsed = os.clock() - self.zoneEnteredAt
        self.zoneTimings[self.currentZone] =
            (self.zoneTimings[self.currentZone] or 0) + elapsed
    end
end

function LevelMetrics:recordDeath(position)
    self.totalDeaths = self.totalDeaths + 1
    self.deathLocations[#self.deathLocations + 1] = {
        x = position.x, y = position.y, z = position.z,
        timestamp = os.clock() - self.startTime,
    }
end

function LevelMetrics:recordSecret()
    self.secretsFound = self.secretsFound + 1
end

--- Generate summary report
---@return table
function LevelMetrics:getSummary()
    local totalTime = self.endTime > 0
        and (self.endTime - self.startTime) or (os.clock() - self.startTime)
    return {
        level = self.levelName,
        completionTimeSec = math.floor(totalTime),
        deaths = self.totalDeaths,
        secretsFound = self.secretsFound .. "/" .. self.secretsTotal,
        checkpoints = self.checkpointsReached .. "/" .. self.checkpointsTotal,
        enemies = self.enemiesKilled .. "/" .. self.enemiesTotal,
        items = self.itemsCollected .. "/" .. self.itemsTotal,
        zoneTimings = self.zoneTimings,
        deathHotspots = self:getDeathHotspots(),
    }
end

--- Find clusters of deaths (problem areas)
---@return table[] hotspots
function LevelMetrics:getDeathHotspots()
    local hotspots = {}
    local clusterRadius = 5.0  -- meters

    for i = 1, #self.deathLocations do
        local loc = self.deathLocations[i]
        local foundCluster = false

        for j = 1, #hotspots do
            local dx = loc.x - hotspots[j].x
            local dz = loc.z - hotspots[j].z
            if math.sqrt(dx * dx + dz * dz) < clusterRadius then
                hotspots[j].count = hotspots[j].count + 1
                foundCluster = true
                break
            end
        end

        if not foundCluster then
            hotspots[#hotspots + 1] = {
                x = loc.x, y = loc.y, z = loc.z,
                count = 1,
            }
        end
    end

    -- Sort by death count (most deaths first)
    table.sort(hotspots, function(a, b) return a.count > b.count end)
    return hotspots
end
```

### What Metrics Tell You

| Metric | Healthy Range | Problem Indicator |
|--------|--------------|-------------------|
| Completion time | Within genre target (see SKILL.md §10) | 2x or 0.5x expected = pacing issue |
| Deaths per level | Action: 2-5, Platformer: 5-15 | 0 deaths = too easy; 20+ = frustrating |
| Death hotspots | Spread across level | Cluster of 5+ deaths = difficulty spike |
| Secret find rate | 30-60% of players find each | 0% = too hidden; 100% = too obvious |
| Zone time variance | Even distribution | One zone 3x longer = bottleneck/confusion |
| Checkpoint spacing | 60-120s between deaths | 180s+ to checkpoint = frustrating loop |

---

## 4. Music and Audio Pacing Integration

### Music Transition by Zone Intensity

```lua
--- Crossfade music based on pacing zone intensity
---@param intensity number 0.0-1.0 from PacingManager
---@param musicLayers table { calm, tension, combat } SoundSource nodes
local function updateMusicForIntensity(intensity, musicLayers)
    -- Crossfade between three layers based on intensity
    if intensity < 0.3 then
        -- Calm zone: only calm layer
        musicLayers.calm:SetGain(1.0)
        musicLayers.tension:SetGain(0.0)
        musicLayers.combat:SetGain(0.0)
    elseif intensity < 0.7 then
        -- Tension zone: blend calm and tension
        local t = (intensity - 0.3) / 0.4
        musicLayers.calm:SetGain(1.0 - t)
        musicLayers.tension:SetGain(t)
        musicLayers.combat:SetGain(0.0)
    else
        -- Combat zone: blend tension and combat
        local t = (intensity - 0.7) / 0.3
        musicLayers.calm:SetGain(0.0)
        musicLayers.tension:SetGain(1.0 - t)
        musicLayers.combat:SetGain(t)
    end
end
```

### Ambient Sound Zones

```lua
--- Create an ambient sound zone that fades in/out as player enters/exits
---@param scene Scene
---@param position Vector3
---@param radius number
---@param soundFile string
---@param volume number 0.0-1.0
local function createAmbientZone(scene, position, radius, soundFile, volume)
    local ambient = scene:CreateChild("AmbientZone")
    ambient.position = position

    local sound = cache:GetResource("Sound", soundFile)
    if sound then
        sound.looped = true
        local source = ambient:CreateComponent("SoundSource3D")
        source:SetSoundType("AMBIENT")
        source:Play(sound)
        source:SetGain(volume)
        source.nearDistance = radius * 0.5
        source.farDistance = radius
    end

    return ambient
end

-- Usage:
-- createAmbientZone(scene_, Vector3(0, 0, 50), 20, "Sounds/wind.ogg", 0.5)
-- createAmbientZone(scene_, Vector3(30, 0, 50), 15, "Sounds/water.ogg", 0.7)
```

---

## 5. Pacing Validation Checklist

### Pre-Playtest
- [ ] Beat chart written with intensity values for every zone
- [ ] Total expected duration calculated and within genre target
- [ ] Average intensity is 0.3-0.5 (not too stressful overall)
- [ ] At least one rest zone between any two peak zones
- [ ] First 30 seconds have a hook (interesting visual/event)
- [ ] Music layers configured for calm/tension/combat transitions

### Post-Playtest
- [ ] Actual completion time within 20% of expected
- [ ] Death hotspots identified and addressed
- [ ] No zone takes 3x longer than expected
- [ ] Players found 30-60% of secrets on first play
- [ ] No momentum-breaking interruptions reported
- [ ] Dynamic difficulty (if used) stays within 0.7-1.3 multiplier range
