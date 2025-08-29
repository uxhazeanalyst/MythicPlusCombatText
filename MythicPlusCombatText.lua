-- ########################################################
-- MyCombatText - Multi-School Support
-- Uses Blizzard's default Floating Combat Text system
-- ########################################################

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Helper: WoW color strings
local function Colorize(text, color)
    return string.format("|cff%02x%02x%02x%s|r", color.r*255, color.g*255, color.b*255, text)
end

-- Show Blizzard floating combat text
local function ShowCombatText(msg, isCrit)
    if not CombatText_AddMessage then return end
    CombatText_AddMessage(msg, CombatText_StandardScroll, 1, 1, 1, isCrit and "crit" or nil, false)
end

-- Colors
local COLORS = {
    physical = {r=1, g=0, b=0},       -- red
    holy     = {r=1, g=0.9, b=0.5},   -- pale gold
    fire     = {r=1, g=0.3, b=0},     -- orange-red
    nature   = {r=0.2, g=1, b=0.2},   -- green
    frost    = {r=0.5, g=0.8, b=1},   -- icy blue
    shadow   = {r=0.6, g=0.4, b=0.8}, -- violet
    arcane   = {r=0.6, g=0.8, b=1},   -- light blue
    dodge    = {r=1, g=1, b=0},       -- yellow
    parry    = {r=0, g=1, b=1},       -- cyan
    absorb   = {r=0, g=1, b=0},       -- green
    miss     = {r=0.7, g=0.7, b=0.7}, -- gray
    block    = {r=0.6, g=0.4, b=1},   -- purple
    magical  = {r=0.8, g=0.8, b=1},   -- pale blue for [Magical] tag
}

-- Mapping of combat log school bits
local SCHOOL_MASKS = {
    [1]   = {"Physical", COLORS.physical},
    [2]   = {"Holy",     COLORS.holy},
    [4]   = {"Fire",     COLORS.fire},
    [8]   = {"Nature",   COLORS.nature},
    [16]  = {"Frost",    COLORS.frost},
    [32]  = {"Shadow",   COLORS.shadow},
    [64]  = {"Arcane",   COLORS.arcane},
}

-- Extract school tags from bitmask
local function GetSchoolTags(school)
    local tags = {}
    if not school or school == 1 then
        return {{"Physical", COLORS.physical}}
    end

    -- Always include [Magical]
    table.insert(tags, {"[Magical]", COLORS.magical})

    for bit, info in pairs(SCHOOL_MASKS) do
        if bit.band(school, bit) ~= 0 and bit ~= 1 then
            table.insert(tags, {info[1], info[2]})
        end
    end

    return tags
end

-- Event handler
f:SetScript("OnEvent", function()
    local _, subEvent, _, _, _, _, _, _, _, _,
        _, spellID, spellName, _, amount, overkill, school,
        resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()

    local msg, isCrit = nil, false

    -- Damage ---------------------------------
    if subEvent == "SWING_DAMAGE" then
        msg = Colorize(string.format("-%d (Physical)", amount or 0), COLORS.physical)

        if blocked and blocked > 0 then
            msg = msg .. " " .. Colorize(string.format("[Blocked %d]", blocked), COLORS.block)
        end
        if absorbed and absorbed > 0 then
            msg = msg .. " " .. Colorize(string.format("[Absorbed %d]", absorbed), COLORS.absorb)
        end
        if critical then isCrit = true end

    elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
        local schoolTags = GetSchoolTags(school)
        local schoolColor = (schoolTags[2] and schoolTags[2][2]) or COLORS.magical

        -- Damage + spell name
        msg = Colorize(string.format("-%d (%s)", amount or 0, spellName or "Spell"), schoolColor)

        -- Add school tags
        for _, tagInfo in ipairs(schoolTags) do
            msg = msg .. " " .. Colorize(tagInfo[1], tagInfo[2])
        end

        -- Add blocked/absorbed
        if blocked and blocked > 0 then
            msg = msg .. " " .. Colorize(string.format("[Blocked %d]", blocked), COLORS.block)
        end
        if absorbed and absorbed > 0 then
            msg = msg .. " " .. Colorize(string.format("[Absorbed %d]", absorbed), COLORS.absorb)
        end
        if critical then isCrit = true end
    end

    -- Avoidance ---------------------------------
    if subEvent == "SWING_MISSED" or subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED" then
        if missType == "DODGE" then
            msg = Colorize("Dodged", COLORS.dodge)
        elseif missType == "PARRY" then
            msg = Colorize("Parried", COLORS.parry)
        elseif missType == "MISS" then
            msg = Colorize("Missed", COLORS.miss)
        elseif missType == "ABSORB" then
            msg = Colorize("Absorbed", COLORS.absorb)
        elseif missType == "BLOCK" then
            msg = Colorize("Blocked", COLORS.block)
        end
    end

    -- Output ---------------------------------
    if msg then
        ShowCombatText(msg, isCrit)
    end
end)
