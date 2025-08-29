-- ########################################################
-- MyCombatTextCoachSmart_Dungeon
-- Multi-School Combat Text + Class/Spec Cooldowns + Smart Coaching + Dungeon-Wide Logging
-- ########################################################

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- =======================
-- Color Helper
-- =======================
local function Colorize(text, color)
    return string.format("|cff%02x%02x%02x%s|r", color.r*255, color.g*255, color.b*255, text)
end

local function ShowCombatText(msg, isCrit)
    if not CombatText_AddMessage then return end
    CombatText_AddMessage(msg, CombatText_StandardScroll, 1,1,1, isCrit and "crit" or nil, false)
end

-- =======================
-- Colors
-- =======================
local COLORS = {
    physical = {r=1, g=0, b=0},
    holy     = {r=1, g=0.9, b=0.5},
    fire     = {r=1, g=0.3, b=0},
    nature   = {r=0.2, g=1, b=0.2},
    frost    = {r=0.5, g=0.8, b=1},
    shadow   = {r=0.6, g=0.4, b=0.8},
    arcane   = {r=0.6, g=0.8, b=1},
    dodge    = {r=1, g=1, b=0},
    parry    = {r=0, g=1, b=1},
    absorb   = {r=0, g=1, b=0},
    miss     = {r=0.7, g=0.7, b=0.7},
    block    = {r=0.6, g=0.4, b=1},
    magical  = {r=0.6, g=0.8, b=1},
    coach    = {r=1, g=0.66, b=0},
}

-- =======================
-- School Mapping
-- =======================
local SCHOOL_MASKS = {
    [1] = {"Physical", COLORS.physical},
    [2] = {"Holy", COLORS.holy},
    [4] = {"Fire", COLORS.fire},
    [8] = {"Nature", COLORS.nature},
    [16] = {"Frost", COLORS.frost},
    [32] = {"Shadow", COLORS.shadow},
    [64] = {"Arcane", COLORS.arcane},
}

local FIXED_ORDER = {2,4,8,16,32,64} -- Holy → Fire → Nature → Frost → Shadow → Arcane

local function GetSchoolTags(school)
    if not school or school == 1 then
        return {{"Physical", COLORS.physical}}
    end
    local tags = {{"[Magical]", COLORS.magical}}
    for _, bit in ipairs(FIXED_ORDER) do
        if bit.band(school, bit) ~= 0 then
            local info = SCHOOL_MASKS[bit]
            table.insert(tags, {info[1], info[2]})
        end
    end
    return tags
end

-- =======================
-- Combat Stats
-- =======================
local combatStats = {
    totalDamageTaken = 0,
    blocked = 0,
    absorbed = 0,
    parried = 0,
    dodged = 0,
    missed = 0,
    criticalsReceived = 0,
    cooldownsUsed = {},
}

-- =======================
-- Full Dungeon Log
-- =======================
local fullCombatLog = {}

-- =======================
-- Class/Spec Cooldowns
-- =======================
local classCooldowns = {
    WARRIOR = {"Shield Wall", "Last Stand", "Rallying Cry"},
    DRUID   = {"Barkskin", "Ironfur", "Survival Instincts"},
    MAGE    = {"Ice Block"},
    PALADIN = {"Divine Shield", "Guardian of Ancient Kings"},
    DEATHKNIGHT = {"Anti-Magic Shell", "Icebound Fortitude"},
}

local trackedCooldowns = {}
local function UpdateTrackedCooldowns()
    trackedCooldowns = {}
    local _, playerClass = UnitClass("player")
    if classCooldowns[playerClass] then
        for _, spellName in ipairs(classCooldowns[playerClass]) do
            trackedCooldowns[spellName] = true
        end
    end
end

-- Call once at load
UpdateTrackedCooldowns()

-- =======================
-- Coaching Functions
-- =======================
local function PrintCoachAdvice(msg, priority)
    local color = COLORS.coach
    if priority=="high" then color={r=1,g=0.44,b=0.27}
    elseif priority=="low" then color={r=0.66,g=0.66,b=1} end
    ShowCombatText(Colorize("[Coach] "..msg, color))
end

local function EvaluateCoach()
    local mitigation = 0
    if combatStats.totalDamageTaken>0 then
        mitigation = (combatStats.blocked + combatStats.absorbed)/combatStats.totalDamageTaken*100
    end

    if mitigation<20 then
        PrintCoachAdvice("Mitigation low! Use defensive cooldowns more efficiently.", "high")
    elseif mitigation<50 then
        PrintCoachAdvice("Good mitigation, room to improve timing.", "medium")
    else
        PrintCoachAdvice("Excellent mitigation this pull!", "low")
    end

    for spell, _ in pairs(trackedCooldowns) do
        if not combatStats.cooldownsUsed[spell] or #combatStats.cooldownsUsed[spell]==0 then
            PrintCoachAdvice(spell.." not used! Consider using during high-damage phases.", "high")
        end
    end
end

-- =======================
-- Post-Combat Summary
-- =======================
local function ShowCombatSummary()
    local totalDamage = combatStats.totalDamageTaken
    local absorbedPct = totalDamage > 0 and (combatStats.absorbed / totalDamage * 100) or 0
    local blockedPct  = totalDamage > 0 and (combatStats.blocked / totalDamage * 100) or 0
    local parryRate   = (combatStats.parried + combatStats.dodged + combatStats.missed) > 0 and
                        (combatStats.parried / (combatStats.parried + combatStats.dodged + combatStats.missed) * 100) or 0

    local missedCooldowns = {}
    for spell,_ in pairs(trackedCooldowns) do
        if not combatStats.cooldownsUsed[spell] or #combatStats.cooldownsUsed[spell]==0 then
            table.insert(missedCooldowns, spell)
        end
    end
    local missedCooldownsText = #missedCooldowns>0 and table.concat(missedCooldowns, ", ") or "None"

    ShowCombatText("===== Combat Summary =====")
    ShowCombatText(string.format("Absorbed: %d (%.1f%%)", combatStats.absorbed, absorbedPct))
    ShowCombatText(string.format("Blocked: %d (%.1f%%)", combatStats.blocked, blockedPct))
    ShowCombatText(string.format("Parry Rate: %.1f%%", parryRate))
    ShowCombatText("Cooldowns Missed: "..missedCooldownsText)

    if absorbedPct < 20 then
        ShowCombatText("[Coach] Consider improving absorption through shields or defensive abilities.")
    end
    if blockedPct < 20 then
        ShowCombatText("[Coach] Increase block effectiveness, timing defensive cooldowns better.")
    end
    if parryRate < 10 then
        ShowCombatText("[Coach] Parry rate low — consider stats or defensive timing.")
    end

    -- Reset stats for next combat
    for k,_ in pairs(combatStats) do
        if k~="cooldownsUsed" then combatStats[k]=0 end
    end
    combatStats.cooldownsUsed = {}
end

-- =======================
-- Full Dungeon Summary
-- =======================
local function PrintDungeonSummary()
    local totalDamage = 0
    local totalBlocked = 0
    local totalAbsorbed = 0
    local totalDodged = 0
    local totalParried = 0
    local totalMissed = 0

    for _, entry in ipairs(fullCombatLog) do
        totalDamage = totalDamage + (entry.damage or 0)
        totalBlocked = totalBlocked + (entry.blocked or 0)
        totalAbsorbed = totalAbsorbed + (entry.absorbed or 0)
        totalDodged = totalDodged + (entry.dodged or 0)
        totalParried = totalParried + (entry.parried or 0)
        totalMissed = totalMissed + (entry.missed or 0)
    end

    ShowCombatText("===== Dungeon Total Summary =====")
    ShowCombatText("Damage Taken: "..totalDamage)
    ShowCombatText("Blocked: "..totalBlocked)
    ShowCombatText("Absorbed: "..totalAbsorbed)
    ShowCombatText("Dodged: "..totalDodged)
    ShowCombatText("Parried: "..totalParried)
    ShowCombatText("Missed: "..totalMissed)

    -- Smart advice
    if totalBlocked / totalDamage < 0.2 then
        ShowCombatText("[Coach] Increase block stats and timing of defensive cooldowns!")
    end
    if totalAbsorbed / totalDamage < 0.2 then
        ShowCombatText("[Coach] Improve absorption via shields or defensive abilities!")
    end
end

-- =======================
-- Main Event Handler
-- =======================
f:SetScript("OnEvent", function(self, event, ...)
    local success, err = pcall(function()
        if event=="COMBAT_LOG_EVENT_UNFILTERED" then
            local _, subEvent, _, _, _, _, _, _, _, _,
                  _, spellID, spellName, _, amount, _, school, _, blocked, absorbed, critical, glancing, crushing, isOffHand, missType = CombatLogGetCurrentEventInfo()

            amount = amount or 0
            blocked = blocked or 0
            absorbed = absorbed or 0
            spellName = spellName or "Unknown"
            school = school or 0
            critical = critical or false
            missType = missType or ""

            local msg, isCrit = nil, false

            if subEvent=="SWING_DAMAGE" then
                msg = Colorize(string.format("-%d (Physical)", amount), COLORS.physical)
                if blocked>0 then msg = msg.." "..Colorize("[Blocked "..blocked.."]", COLORS.block) end
                if absorbed>0 then msg = msg.." "..Colorize("[Absorbed "..absorbed.."]", COLORS.absorb) end
                if critical then isCrit=true end
                combatStats.totalDamageTaken = combatStats.totalDamageTaken + amount
                combatStats.blocked = combatStats.blocked + blocked
                combatStats.absorbed = combatStats.absorbed + absorbed
                if critical then combatStats.criticalsReceived = combatStats.criticalsReceived+1 end

            elseif subEvent=="SPELL_DAMAGE" or subEvent=="RANGE_DAMAGE" then
                local schoolTags = GetSchoolTags(school)
                local spellText = string.format("-%d (%s)", amount, spellName)
                local magicalTag = ""
                if #schoolTags>0 and schoolTags[1][1]=="[Magical]" then
                    magicalTag = Colorize(schoolTags[1][1], schoolTags[1][2])
                end
                local elementTags=""
                for i=2,#schoolTags do
                    elementTags = elementTags.." "..Colorize(schoolTags[i][1], schoolTags[i][2])
                end
                local modifiers=""
                if blocked>0 then modifiers = modifiers.." "..Colorize("[Blocked "..blocked.."]", COLORS.block) end
                if absorbed>0 then modifiers = modifiers.." "..Colorize("[Absorbed "..absorbed.."]", COLORS.absorb) end
                msg = Colorize(spellText, schoolTags[2] and schoolTags[2][2] or COLORS.magical).." "..magicalTag..elementTags..modifiers
                if critical then isCrit=true end
                combatStats.totalDamageTaken = combatStats.totalDamageTaken + amount
                combatStats.blocked = combatStats.blocked + blocked
                combatStats.absorbed = combatStats.absorbed + absorbed
                if critical then combatStats.criticalsReceived = combatStats.criticalsReceived+1 end
            end

            if subEvent=="SWING_MISSED" or subEvent=="SPELL_MISSED" or subEvent=="RANGE_MISSED" then
                if missType=="DODGE" then combatStats.dodged=combatStats.dodged+1; msg=Colorize("Dodged",COLORS.dodge)
                elseif missType=="PARRY" then combatStats.parried=combatStats.parried+1; msg=Colorize("Parried",COLORS.parry)
                elseif missType=="MISS" then combatStats.missed=combatStats.missed+1; msg=Colorize("Missed",COLORS.miss)
                elseif missType=="ABSORB" then combatStats.absorbed=combatStats.absorbed+amount; msg=Colorize("Absorbed",COLORS.absorb)
                elseif missType=="BLOCK" then combatStats.blocked=combatStats.blocked+amount; msg=Colorize("Blocked",COLORS.block)
                end
            end

            -- Display and log
            if msg then
                ShowCombatText(msg,isCrit)
                table.insert(fullCombatLog, {
                    timestamp = GetTime(),
                    eventType = subEvent,
                    spell = spellName,
                    damage = amount,
                    blocked = blocked,
                    absorbed = absorbed,
                    dodged = missType=="DODGE" and 1 or 0,
                    parried = missType=="PARRY" and 1 or 0,
                    missed = missType=="MISS" and 1 or 0,
                })
            end

            if math.random()<0.05 then EvaluateCoach() end

        elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
            local unit, spellNameCast = ...
            if unit=="player" and trackedCooldowns[spellNameCast] then
                if not combatStats.cooldownsUsed[spellNameCast] then combatStats.cooldownsUsed[spellNameCast]={} end
                table.insert(combatStats.cooldownsUsed[spellNameCast], GetTime())
                PrintCoachAdvice(spellNameCast.." used!","medium")
            end

        elseif event=="PLAYER_REGEN_ENABLED" then
            ShowCombatSummary()

        elseif event=="CHALLENGE_MODE_COMPLETED" then
            PrintDungeonSummary()
            fullCombatLog = {}

        elseif event=="PLAYER_SPECIALIZATION_CHANGED" then
            UpdateTrackedCooldowns()
        end
    end)
    if not success then
        print("|cffff0000[MyCombatTextCoachSmart] Error:|r "..tostring(err))
    end
end)

-- =======================
-- Periodic Smart Coach Evaluation
-- =======================
C_Timer.NewTicker(10, EvaluateCoach)
