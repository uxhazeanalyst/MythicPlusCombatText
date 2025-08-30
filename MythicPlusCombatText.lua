-- ########################################################
-- MythicPlusCombatText.lua
-- MyCombatTextCoachSmart - corrected, ready-to-paste
-- ########################################################

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHALLENGE_MODE_COMPLETED")
f:RegisterEvent("UNIT_DIED")

-- safe reference to player GUID
local playerGUID = UnitGUID("player")

-- =======================
-- Colors
-- =======================
local COLORS = {
    physical = {r=1, g=0,   b=0},
    bleed    = {r=0.8, g=0, b=0},
    holy     = {r=1, g=0.84, b=0},
    fire     = {r=1, g=0.3, b=0},
    nature   = {r=0.6, g=0.4, b=0.2},
    frost    = {r=0, g=0.5, b=1},
    shadow   = {r=0.3, g=0, b=0.3}, -- FIX: not invisible
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
-- Utilities
-- =======================
local function Colorize(text, color)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor((color.r or 1)*255),
        math.floor((color.g or 1)*255),
        math.floor((color.b or 1)*255),
        text)
end

local function ShowFloating(msg, isCrit)
    if CombatText_AddMessage then
        CombatText_AddMessage(msg, CombatText_StandardScroll, 1,1,1, isCrit and "crit" or nil, false)
    end
end

-- =======================
-- Combat Log Handler
-- =======================
local function HandleCombatLogEvent()
    local timestamp, subEvent, _, srcGUID, srcName, _, _, dstGUID, dstName,
        _, _, spellID, spellName, spellSchool, amount, overkill,
        school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()

    if subEvent == "SWING_DAMAGE" then
        amount, overkill, school, resisted, blocked, absorbed, critical = spellID, spellSchool, amount, overkill, school, resisted, blocked, absorbed
        spellName = "Melee"
    end

    -- === OUTGOING ===
    if srcGUID == playerGUID and amount then
        ShowFloating(Colorize("+"..amount.." "..spellName, COLORS.magical), critical)
    end

    -- === INCOMING ===
    if dstGUID == playerGUID and amount then
        ShowFloating(Colorize("-"..amount.." "..(spellName or "Hit"), COLORS.physical), critical)
    end
end

-- =======================
-- Dungeon Forces
-- =======================
local prevForces = 0
local function QueryForcesCriterion()
    for i=1,10 do
        local name, _, _, cur, total = C_Scenario.GetCriteriaInfo(i)
        if name and (name:lower():find("force") or name:lower():find("enemy")) then
            return cur, total
        end
    end
end
local function ShowForcesFloatingText()
    local cur, total = QueryForcesCriterion()
    if not cur or not total or total==0 then return end
    local gained = cur - prevForces
    if gained < 0 then gained = cur end
    prevForces = cur
    ShowFloating(Colorize(("+"..gained.." mobs (%.1f%%)"):format((cur/total)*100), COLORS.coach))
end

-- =======================
-- Event Handler
-- =======================
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        prevForces = 0

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent()

    elseif event == "PLAYER_REGEN_ENABLED" then
        ShowFloating(Colorize("Combat ended", COLORS.coach))

    elseif event == "CHALLENGE_MODE_COMPLETED" then
        ShowFloating(Colorize("Dungeon Complete!", COLORS.coach))
        prevForces = 0

    elseif event == "UNIT_DIED" then
        C_Timer.After(0.35, ShowForcesFloatingText)
    end
end)
