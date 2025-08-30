-- ########################################################
-- MythicPlusCombatText.lua
-- MyCombatTextCoachSmart - corrected, ready-to-paste
-- Tracks incoming/outgoing damage, bleeds, and per-mob Mythic+ progress
-- ########################################################

local f = CreateFrame("Frame")

-- safe reference to player GUID (update on login/specialization)
local playerGUID = UnitGUID("player")

-- =======================
-- Colors (your chosen palette)
-- =======================
local COLORS = {
    physical = {r=1, g=0,   b=0},    -- Red
    bleed    = {r=0.8, g=0, b=0},    -- Darker red
    holy     = {r=1, g=0.84, b=0},   -- Gold/Yellow
    fire     = {r=1, g=0,   b=0},    -- Bright Red
    nature   = {r=0.6, g=0.4, b=0.2},-- Brown/Tan
    frost    = {r=0, g=0.5, b=1},    -- Blue
    shadow   = {r=0, g=0,   b=0},    -- Black
    arcane   = {r=0.6, g=0, b=0.8},  -- Purple
    dodge    = {r=1, g=1,   b=0},    -- Yellow
    parry    = {r=0, g=1,   b=1},    -- Cyan
    absorb   = {r=0, g=1,   b=0},    -- Green
    miss     = {r=0.7, g=0.7, b=0.7},-- Gray
    block    = {r=0.6, g=0.4, b=1},  -- Lavender
    magical  = {r=0.6, g=0.8, b=1},  -- Generic magical
    coach    = {r=1, g=0.66, b=0},   -- Orange coach tips
}

-- =======================
-- School / mask mapping
-- =======================
local SCHOOL_MASKS = {
    [1]  = {"Physical", COLORS.physical},
    [2]  = {"Holy",     COLORS.holy},
    [4]  = {"Fire",     COLORS.fire},
    [8]  = {"Nature",   COLORS.nature},
    [16] = {"Frost",    COLORS.frost},
    [32] = {"Shadow",   COLORS.shadow},
    [64] = {"Arcane",   COLORS.arcane},
}
local FIXED_ORDER = {2,4,8,16,32,64} -- order for multi-school tags

-- safe bit-band function (works with bit or bit32)
local band = (bit and bit.band) or (bit32 and bit32.band) or function(a,b) return (a % (2*b)) >= b and 1 or 0 end

local function GetSchoolTags(school)
    if not school or school == 1 then
        return { { "Physical", COLORS.physical } }
    end
    local tags = { { "[Magical]", COLORS.magical } }
    for _, mask in ipairs(FIXED_ORDER) do
        if band(school, mask) ~= 0 then
            local info = SCHOOL_MASKS[mask]
            if info then
                table.insert(tags, { info[1], info[2] })
            end
        end
    end
    return tags
end

-- =======================
-- Bleed spell list (extendable)
-- Put spellIDs you want highlighted as Bleed
-- =======================
local BLEED_SPELLS = {
    [772]    = true,  -- example: Rend (Warrior; ID must be verified for your expansion)
    [1943]   = true,  -- Rupture (Rogue)
    [1079]   = true,  -- Rip (Druid)
    -- Add more spellIDs here (update with correct IDs for your expansion)
}

-- =======================
-- Small helpers
-- =======================
local function Colorize(text, color)
    if not color then return text end
    return string.format("|cff%02x%02x%02x%s|r", math.floor(color.r*255), math.floor(color.g*255), math.floor(color.b*255), text)
end

local function SafeGetOptionColor(key)
    if MyCombatTextOptions and MyCombatTextOptions.GetColor then
        return MyCombatTextOptions:GetColor(key) or COLORS[key] or {r=1,g=1,b=1}
    end
    return COLORS[key] or {r=1,g=1,b=1}
end

local function ShowFloating(msg, isCrit)
    if not CombatText_AddMessage then return end
    -- Use color codes in msg (Colorize) so we can pass white to API
    CombatText_AddMessage(msg, CombatText_StandardScroll, 1,1,1, isCrit and "crit" or nil, false)
end

-- =======================
-- Combat stats
-- =======================
local combatStats = {
    taken = 0,
    dealt = 0,
    absorbed = 0,
    blocked = 0,
    parried = 0,
    dodged = 0,
    missed = 0,
    cooldownsUsed = {},
}
local fullCombatLog = {}

-- =======================
-- Mythic+ forces tracking
-- =======================
local prevForces = 0

local function QueryForcesCriterion()
    -- loop a few criterion slots and return the first that looks like "Forces"
    for i=1,10 do
        local name, _, _, cur, total, _, _, _, _, _ = C_Scenario.GetCriteriaInfo(i)
        if not name then break end
        if name:lower():find("force") or name:lower():find("enemy") then
            return cur, total
        end
    end
    return nil, nil
end

local function ShowForcesFloatingText()
    local cur, total = QueryForcesCriterion()
    if not cur or not total or total == 0 then return end
    local gained = cur - prevForces
    if gained < 0 then gained = cur end -- reset cases
    prevForces = cur
    local percent = (cur / total) * 100
    local msg = string.format("[%s] [%s] [%d/%d]",
        ("+%d mythic mob"):format(gained),
        ("%.1f%% total"):format(percent),
        cur, total
    )
    local color = SafeGetOptionColor("coach")
    ShowFloating(Colorize(msg, color), false)
end

-- =======================
-- Combat log handler
-- =======================
local function HandleCombatLogEvent(...)
    local timestamp, subEvent = select(1, ...)
    -- standard positions for source/dest/spell/amount from CombatLogGetCurrentEventInfo
    -- indexes: 1=time, 2=subEvent, 4=sourceGUID, 5=sourceName, 8=destGUID, 9=destName, 12=spellID, 13=spellName, 14=spellSchool, 15=amount
    local _, sub, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()

    amount = amount or 0
    blocked = blocked or 0
    absorbed = absorbed or 0
    spellName = spellName or "Unknown"

    -- OUTGOING damage done by player
    if sourceGUID == playerGUID then
        if sub == "SWING_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" then
            combatStats.dealt = combatStats.dealt + amount
            table.insert(fullCombatLog, {when = GetTime(), type = "dealt", spell = spellName, amount = amount})
            -- show outgoing with + prefix (optional color: use physical for melee, magical otherwise)
            local outColor = (sub == "SWING_DAMAGE" and SafeGetOptionColor("physical")) or SafeGetOptionColor("magical")
            ShowFloating(Colorize(string.format("+%d (%s)", amount, spellName), outColor), critical)
        end
    end

    -- INCOMING damage to player
    if destGUID == playerGUID then
        if sub == "SWING_DAMAGE" then
            combatStats.taken = combatStats.taken + amount
            combatStats.blocked = combatStats.blocked + blocked
            combatStats.absorbed = combatStats.absorbed + absorbed
            table.insert(fullCombatLog, {when = GetTime(), type = "taken", spell = "Physical", amount = amount, blocked = blocked, absorbed = absorbed})
            local msg = string.format("-%d (Physical)", amount)
            if blocked>0 then msg = msg.." "..Colorize("[Blocked "..blocked.."]", SafeGetOptionColor("block")) end
            if absorbed>0 then msg = msg.." "..Colorize("[Absorbed "..absorbed.."]", SafeGetOptionColor("absorb")) end
            ShowFloating(Colorize(msg, SafeGetOptionColor("physical")), critical)
        elseif sub == "RANGE_DAMAGE" or sub == "SPELL_DAMAGE" then
            combatStats.taken = combatStats.taken + amount
            combatStats.blocked = combatStats.blocked + blocked
            combatStats.absorbed = combatStats.absorbed + absorbed
            table.insert(fullCombatLog, {when = GetTime(), type = "taken", spell = spellName, amount = amount, blocked = blocked, absorbed = absorbed})
            local schoolTags = GetSchoolTags(spellSchool or 0)
            local mainColor = schoolTags[2] and schoolTags[2][2] or SafeGetOptionColor("magical")
            local magicalTag = (schoolTags[1] and schoolTags[1][1]) and Colorize(schoolTags[1][1], SafeGetOptionColor("magical")) or ""
            local elementTags = ""
            for i=2,#schoolTags do elementTags = elementTags.." "..Colorize(schoolTags[i][1], schoolTags[i][2]) end
            local msg = string.format("-%d (%s) %s%s", amount, spellName, magicalTag, elementTags)
            if blocked>0 then msg = msg.." "..Colorize("[Blocked "..blocked.."]", SafeGetOptionColor("block")) end
            if absorbed>0 then msg = msg.." "..Colorize("[Absorbed "..absorbed.."]", SafeGetOptionColor("absorb")) end
            ShowFloating(Colorize(msg, mainColor), critical)
        elseif sub == "SPELL_PERIODIC_DAMAGE" then
            -- check for bleed
            if BLEED_SPELLS[spellID] then
                combatStats.taken = combatStats.taken + amount
                table.insert(fullCombatLog, {when = GetTime(), type = "taken", spell = spellName, amount = amount, bleed = true})
                ShowFloating(Colorize(string.format("-%d (%s) [Bleed]", amount, spellName), SafeGetOptionColor("bleed")), critical)
            else
                combatStats.taken = combatStats.taken + amount
                table.insert(fullCombatLog, {when = GetTime(), type = "taken", spell = spellName, amount = amount})
                ShowFloating(Colorize(string.format("-%d (Dot: %s)", amount, spellName), SafeGetOptionColor("magical")), critical)
            end
        elseif sub == "SWING_MISSED" or sub == "SPELL_MISSED" or sub == "RANGE_MISSED" then
            local missType = select(21, CombatLogGetCurrentEventInfo()) or ""
            if missType == "DODGE" then combatStats.dodged = combatStats.dodged + 1; ShowFloating(Colorize("Dodged", SafeGetOptionColor("dodge")), false)
            elseif missType == "PARRY" then combatStats.parried = combatStats.parried + 1; ShowFloating(Colorize("Parried", SafeGetOptionColor("parry")), false)
            elseif missType == "MISS" then combatStats.missed = combatStats.missed + 1; ShowFloating(Colorize("Missed", SafeGetOptionColor("miss")), false)
            elseif missType == "ABSORB" then combatStats.absorbed = combatStats.absorbed + amount; ShowFloating(Colorize("Absorbed", SafeGetOptionColor("absorb")), false)
            elseif missType == "BLOCK" then combatStats.blocked = combatStats.blocked + amount; ShowFloating(Colorize("Blocked", SafeGetOptionColor("block")), false) end
        end
    end
end

-- =======================
-- Summaries
-- =======================
local function ShowCombatSummary()
    -- per-pull (on leaving combat)
    local total = combatStats.taken
    local absorbedPct = total>0 and (combatStats.absorbed / total * 100) or 0
    local blockedPct = total>0 and (combatStats.blocked / total * 100) or 0
    local parryRate = (combatStats.parried + combatStats.dodged + combatStats.missed) > 0 and
                      (combatStats.parried / (combatStats.parried + combatStats.dodged + combatStats.missed) * 100) or 0

    ShowFloating(Colorize("===== Combat Summary =====", SafeGetOptionColor("coach")))
    ShowFloating(Colorize(string.format("Absorbed: %d (%.1f%%)", combatStats.absorbed, absorbedPct), SafeGetOptionColor("absorb")))
    ShowFloating(Colorize(string.format("Blocked: %d (%.1f%%)", combatStats.blocked, blockedPct), SafeGetOptionColor("block")))
    ShowFloating(Colorize(string.format("Parry Rate: %.1f%%", parryRate), SafeGetOptionColor("parry")))
    ShowFloating(Colorize("Damage Taken: "..combatStats.taken, SafeGetOptionColor("physical")))
    ShowFloating(Colorize("Damage Dealt: "..combatStats.dealt, SafeGetOptionColor("magical")))
    -- reset per-pull
    combatStats.taken = 0; combatStats.dealt = 0; combatStats.absorbed = 0; combatStats.blocked = 0
    combatStats.parried = 0; combatStats.dodged = 0; combatStats.missed = 0
    combatStats.cooldownsUsed = {}
end

local function PrintDungeonSummary()
    -- compile fullCombatLog if you want more detailed aggregations
    ShowFloating(Colorize("===== Dungeon Total Summary =====", SafeGetOptionColor("coach")))
    local totalTaken, totalBlocked, totalAbsorbed, totalDodged, totalParried, totalMissed, totalDealt = 0,0,0,0,0,0,0
    for i=1,#fullCombatLog do
        local e = fullCombatLog[i]
        if e.type=="taken" then
            totalTaken = totalTaken + (e.amount or 0)
            totalBlocked = totalBlocked + (e.blocked or 0)
            totalAbsorbed = totalAbsorbed + (e.absorbed or 0)
            totalDodged = totalDodged + (e.dodged or 0)
            totalParried = totalParried + (e.parried or 0)
            totalMissed = totalMissed + (e.missed or 0)
        elseif e.type=="dealt" then
            totalDealt = totalDealt + (e.amount or 0)
        end
    end
    ShowFloating(Colorize("Damage Taken: "..totalTaken, SafeGetOptionColor("physical")))
    ShowFloating(Colorize("Blocked: "..totalBlocked, SafeGetOptionColor("block")))
    ShowFloating(Colorize("Absorbed: "..totalAbsorbed, SafeGetOptionColor("absorb")))
    ShowFloating(Colorize("Dodged: "..totalDodged, SafeGetOptionColor("dodge")))
    ShowFloating(Colorize("Parried: "..totalParried, SafeGetOptionColor("parry")))
    ShowFloating(Colorize("Missed: "..totalMissed, SafeGetOptionColor("miss")))
    ShowFloating(Colorize("Damage Dealt: "..totalDealt, SafeGetOptionColor("magical")))
end
HEALER_COACH = {
    PRIEST = {
        HOLY = {
            aoe_threshold = 50000, -- damage in <4s
            st_threshold  = 20000, -- tank intake in <3s
            aoe_suggestions = {"Divine Hymn", "Holy Word: Salvation", "Prayer of Healing"},
            st_suggestions  = {"Guardian Spirit", "Holy Word: Serenity"},
        },
        DISCIPLINE = {
            aoe_threshold = 40000,
            st_threshold  = 18000,
            aoe_suggestions = {"Evangelism", "Barrier", "Rapture"},
            st_suggestions  = {"Pain Suppression", "Penance"},
        },
    },
    SHAMAN = {
        RESTORATION = {
            aoe_threshold = 60000,
            st_threshold  = 22000,
            aoe_suggestions = {"Spirit Link Totem", "Healing Tide Totem", "Ascendance"},
            st_suggestions  = {"Riptide", "Earth Shield", "Unleash Life"},
        },
    },
    DRUID = {
        RESTORATION = {
            aoe_threshold = 55000,
            st_threshold  = 20000,
            aoe_suggestions = {"Tranquility", "Flourish", "Wild Growth"},
            st_suggestions  = {"Ironbark", "Swiftmend"},
        },
    },
    PALADIN = {
        HOLY = {
            aoe_threshold = 50000,
            st_threshold  = 25000,
            aoe_suggestions = {"Aura Mastery", "Avenging Wrath", "Light of Dawn"},
            st_suggestions  = {"Blessing of Sacrifice", "Word of Glory"},
        },
    },
    EVOKER = {
        PRESERVATION = {
            aoe_threshold = 55000,
            st_threshold  = 23000,
            aoe_suggestions = {"Rewind", "Dream Breath", "Emerald Communion"},
            st_suggestions  = {"Time Dilation", "Verdant Embrace"},
        },
    },
    MONK = {
        MISTWEAVER = {
            aoe_threshold = 50000,
            st_threshold  = 20000,
            aoe_suggestions = {"Revival", "Yu’lon’s Whisper", "Essence Font"},
            st_suggestions  = {"Life Cocoon", "Enveloping Mist"},
        },
    },
}
-- Healing Coach Prototype

local f = CreateFrame("Frame")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

local damageLog = {}
local lastCombat = {}

local function LogDamage(dstGUID, amount, school)
    local now = GetTime()
    damageLog[#damageLog+1] = {t=now, target=dstGUID, dmg=amount}
end

local function Analyze()
    if not damageLog[1] then return end

    local playerClass, playerSpec = UnitClass("player")
    local coach = HEALER_COACH[playerClass] and HEALER_COACH[playerClass][playerSpec]
    if not coach then
        print("Healing Coach: No profile found for "..playerClass.." spec "..(playerSpec or "?"))
        return
    end

    local aoe_total, st_total = 0, 0
    local tankGUID = UnitGUID("party1") -- crude assumption, can refine with UnitGroupRolesAssigned("unit")

    for _,entry in ipairs(damageLog) do
        if entry.target == tankGUID then
            st_total = st_total + entry.dmg
        else
            aoe_total = aoe_total + entry.dmg
        end
    end

    print("=== Healing Coach Report ===")
    print("AoE Damage Taken: "..aoe_total)
    if aoe_total >= coach.aoe_threshold then
        print("Suggestion: Use one of → "..table.concat(coach.aoe_suggestions, ", "))
    end

    print("Tank Damage Taken: "..st_total)
    if st_total >= coach.st_threshold then
        print("Suggestion: Use one of → "..table.concat(coach.st_suggestions, ", "))
    end

    wipe(damageLog)
end

f:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, _, _, dstGUID, _, _, _, _, spellName, _, _, amount = CombatLogGetCurrentEventInfo()
        if subEvent == "SWING_DAMAGE" then
            amount = spellName -- arg mismatch for SWING_DAMAGE
        end
        if amount and dstGUID and UnitIsFriend("player", dstGUID) then
            LogDamage(dstGUID, amount)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- end of combat
        Analyze()
    end
end)
local lastAlert = 0
local function Alert(msg)
    if GetTime() - lastAlert > 5 then -- throttle to avoid spam
        CombatText_AddMessage("|cff00ff00Healing Coach:|r "..msg, CombatText_StandardScroll, 0,1,0)
        lastAlert = GetTime()
    end
end

-- inside damage logging:
if st_burst > coach.st_threshold then
    local spell = coach.st_suggestions[math.random(#coach.st_suggestions)]
    Alert("Tank burst! Consider: "..spell)
end
if aoe_burst > coach.aoe_threshold then
    local spell = coach.aoe_suggestions[math.random(#coach.aoe_suggestions)]
    Alert("Group AoE! Try: "..spell)
end

-- =======================
-- Event hookup
-- =======================
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")      -- leave combat
f:RegisterEvent("CHALLENGE_MODE_COMPLETED") -- dungeon done
f:RegisterEvent("UNIT_DIED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        prevForces = 0
        -- if options exist, ensure they're available; options.lua should set MyCombatTextOptions globally
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- pass through current event
        HandleCombatLogEvent(CombatLogGetCurrentEventInfo())
    elseif event == "PLAYER_REGEN_ENABLED" then
        ShowCombatSummary()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        PrintDungeonSummary()
        fullCombatLog = {} -- reset dungeon log if you want
        prevForces = 0
    elseif event == "UNIT_DIED" then
        -- show live mob progress after a short delay so the scenario info updates
        C_Timer.After(0.35, ShowForcesFloatingText)
    end
end)

-- Periodic coach eval (non-blocking)
if C_Timer then
    C_Timer.NewTicker(10, function()
        -- lightweight coach check (optional)
        -- EvaluateCoach() -- if you have that function in your main file, or keep this stub
    end)
end

-- end of file
