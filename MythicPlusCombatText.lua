-- ########################################################
-- MythicPlusCombatText.lua
-- MyCombatTextCoachSmart - Corrected Version
-- ########################################################

local f = CreateFrame("Frame")
local playerGUID = UnitGUID("player")

-- =======================
-- Colors
-- =======================
local COLORS = {
    physical = {r=1, g=0,   b=0},
    bleed    = {r=0.8, g=0, b=0},
    holy     = {r=1, g=0.84, b=0},
    fire     = {r=1, g=0,   b=0},
    nature   = {r=0.6, g=0.4, b=0.2},
    frost    = {r=0, g=0.5, b=1},
    shadow   = {r=0, g=0,   b=0},
    arcane   = {r=0.6, g=0, b=0.8},
    dodge    = {r=1, g=1,   b=0},
    parry    = {r=0, g=1,   b=1},
    absorb   = {r=0, g=1,   b=0},
    miss     = {r=0.7, g=0.7, b=0.7},
    block    = {r=0.6, g=0.4, b=1},
    magical  = {r=0.6, g=0.8, b=1},
    coach    = {r=1, g=0.66, b=0},
}

-- =======================
-- WoW Class Colors
-- =======================
local CLASS_COLORS = {
    DRUID     = {r=1.0, g=0.49, b=0.04},
    MONK      = {r=0.0, g=1.0, b=0.59},
    SHAMAN    = {r=0.0, g=0.44, b=0.87},
    PRIEST    = {r=1.0, g=1.0, b=1.0},
    PALADIN   = {r=0.96, g=0.55, b=0.73},
    EVOKER    = {r=0.20, g=0.58, b=0.50},
}

-- =======================
-- Spec Mapping
-- =======================
local SPEC_MAP = {
    -- Priest
    [256] = {"PRIEST","DISCIPLINE"},
    [257] = {"PRIEST","HOLY"},
    [258] = {"PRIEST","SHADOW"},
    -- Shaman
    [264] = {"SHAMAN","RESTORATION"},
    -- Druid
    [105] = {"DRUID","RESTORATION"},
    -- Paladin
    [65]  = {"PALADIN","HOLY"},
    -- Monk
    [270] = {"MONK","MISTWEAVER"},
    -- Evoker
    [1468]= {"EVOKER","PRESERVATION"},
}

-- =======================
-- Helpers
-- =======================
local function Colorize(text, color)
    if not color then return text end
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(color.r*255),
        math.floor(color.g*255),
        math.floor(color.b*255),
        text)
end

local function SafeGetOptionColor(key)
    if MyCombatTextOptions and MyCombatTextOptions.GetColor then
        return MyCombatTextOptions:GetColor(key) or COLORS[key] or {r=1,g=1,b=1}
    end
    return COLORS[key] or {r=1,g=1,b=1}
end

local function ShowFloating(msg, isCrit)
    if CombatText_AddMessage then
        CombatText_AddMessage(msg, CombatText_StandardScroll, 1,1,1, isCrit and "crit" or nil, false)
    end
end

-- =======================
-- Combat Stats
-- =======================
local combatStats = {
    taken=0, dealt=0, absorbed=0, blocked=0,
    parried=0, dodged=0, missed=0, cooldownsUsed={},
}
local fullCombatLog = {}
local prevForces = 0

-- =======================
-- Combat Log Handler
-- =======================
local function HandleCombatLogEvent()
    local timestamp, subEvent, _, sourceGUID, sourceName, _, _, destGUID, destName,
        _, _, spellID, spellName, school, amount, overkill, resisted, blocked, absorbed, critical =
        CombatLogGetCurrentEventInfo()

    -- Fix SWING_DAMAGE argument shift
    if subEvent == "SWING_DAMAGE" then
        spellName = "Melee"
        amount, overkill, school, resisted, blocked, absorbed, critical = select(12, CombatLogGetCurrentEventInfo())
    end

    amount = amount or 0
    spellName = spellName or "Unknown"
    blocked = blocked or 0
    absorbed = absorbed or 0

    -- OUTGOING damage
    if sourceGUID == playerGUID then
        if subEvent == "SWING_DAMAGE" or subEvent == "RANGE_DAMAGE" or
           subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
            combatStats.dealt = combatStats.dealt + amount
            ShowFloating(Colorize(string.format("+%d (%s)", amount, spellName), SafeGetOptionColor("magical")), critical)
        end
    end

    -- INCOMING damage
    if destGUID == playerGUID then
        if subEvent == "SWING_DAMAGE" or subEvent == "RANGE_DAMAGE" or
           subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
            combatStats.taken = combatStats.taken + amount
            ShowFloating(Colorize(string.format("-%d (%s)", amount, spellName), SafeGetOptionColor("physical")), critical)
        elseif subEvent == "SWING_MISSED" or subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED" then
            local missType = select(15, CombatLogGetCurrentEventInfo()) or ""
            if missType == "DODGE" then ShowFloating(Colorize("Dodged", SafeGetOptionColor("dodge")))
            elseif missType == "PARRY" then ShowFloating(Colorize("Parried", SafeGetOptionColor("parry")))
            elseif missType == "MISS" then ShowFloating(Colorize("Missed", SafeGetOptionColor("miss")))
            elseif missType == "ABSORB" then ShowFloating(Colorize("Absorbed", SafeGetOptionColor("absorb")))
            elseif missType == "BLOCK" then ShowFloating(Colorize("Blocked", SafeGetOptionColor("block"))) end
        end
    end
end

-- =======================
-- Summaries
-- =======================
local function ShowCombatSummary()
    local total = combatStats.taken
    local absorbedPct = total>0 and (combatStats.absorbed/total*100) or 0
    local blockedPct = total>0 and (combatStats.blocked/total*100) or 0

    ShowFloating(Colorize("===== Combat Summary =====", SafeGetOptionColor("coach")))
    ShowFloating(Colorize(string.format("Absorbed: %d (%.1f%%)", combatStats.absorbed, absorbedPct), SafeGetOptionColor("absorb")))
    ShowFloating(Colorize(string.format("Blocked: %d (%.1f%%)", combatStats.blocked, blockedPct), SafeGetOptionColor("block")))
    ShowFloating(Colorize("Damage Taken: "..combatStats.taken, SafeGetOptionColor("physical")))
    ShowFloating(Colorize("Damage Dealt: "..combatStats.dealt, SafeGetOptionColor("magical")))

    -- Reset
    for k,_ in pairs(combatStats) do
        if type(combatStats[k])=="number" then combatStats[k]=0
        elseif type(combatStats[k])=="table" then combatStats[k]={} end
    end
end

-- =======================
-- Event Dispatcher
-- =======================
f:SetScript("OnEvent", function(self,event,...)
    if event=="PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        prevForces=0
    elseif event=="COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent()
    elseif event=="PLAYER_REGEN_ENABLED" then
        ShowCombatSummary()
    elseif event=="CHALLENGE_MODE_COMPLETED" then
        ShowFloating(Colorize("Dungeon Completed!", SafeGetOptionColor("coach")))
        fullCombatLog = {}
        prevForces=0
    elseif event=="UNIT_DIED" then
        C_Timer.After(0.35, function() end) -- stub for mob forces
    end
end)

f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("UNIT_DIED")
