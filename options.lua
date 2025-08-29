-- ########################################################
-- MyCombatTextCoachSmart_Dungeon
-- Copyright (c) 2025 YourName
-- License: Non-commercial personal use only
-- ########################################################


-- ########################################################
-- MyCombatTextCoachSmart Options
-- Allows customization of colors, text size, and features
-- ########################################################

local Options = {}

-- =======================
-- Default Settings
-- =======================
Options.defaults = {
    textSize = 16,  -- size of floating combat text
    colors = {
        physical = {r=1, g=0, b=0},
        magical  = {r=0.6, g=0.8, b=1},
        dodge    = {r=1, g=1, b=0},
        parry    = {r=0, g=1, b=1},
        absorb   = {r=0, g=1, b=0},
        miss     = {r=0.7, g=0.7, b=0.7},
        block    = {r=0.6, g=0.4, b=1},
        coach    = {r=1, g=0.66, b=0},
    },
    showMultiSchoolTags = true,
    showCombatSummary = true,
    showDungeonSummary = true,
    enableSmartCoach = true,
}

-- =======================
-- Current Settings (load defaults initially)
-- =======================
Options.settings = {}
for k,v in pairs(Options.defaults) do
    if type(v)=="table" then
        Options.settings[k] = {}
        for key,val in pairs(v) do
            Options.settings[k][key] = val
        end
    else
        Options.settings[k] = v
    end
end

-- =======================
-- Setters
-- =======================
function Options:SetColor(eventType, r, g, b)
    if self.settings.colors[eventType] then
        self.settings.colors[eventType] = {r=r, g=g, b=b}
        print(string.format("MyCombatText: %s color set to R:%.2f G:%.2f B:%.2f", eventType, r, g, b))
    end
end

function Options:SetTextSize(size)
    self.settings.textSize = size
    print("MyCombatText: Text size set to "..size)
end

function Options:ToggleMultiSchoolTags(state)
    self.settings.showMultiSchoolTags = state
    print("MyCombatText: Multi-school tags "..(state and "enabled" or "disabled"))
end

function Options:ToggleCombatSummary(state)
    self.settings.showCombatSummary = state
    print("MyCombatText: Combat summary "..(state and "enabled" or "disabled"))
end

function Options:ToggleDungeonSummary(state)
    self.settings.showDungeonSummary = state
    print("MyCombatText: Dungeon summary "..(state and "enabled" or "disabled"))
end

function Options:ToggleSmartCoach(state)
    self.settings.enableSmartCoach = state
    print("MyCombatText: Smart coach "..(state and "enabled" or "disabled"))
end

-- =======================
-- Getters
-- =======================
function Options:GetColor(eventType)
    return self.settings.colors[eventType] or {r=1,g=1,b=1}
end

function Options:GetTextSize()
    return self.settings.textSize
end

function Options:IsMultiSchoolTagsEnabled()
    return self.settings.showMultiSchoolTags
end

function Options:IsCombatSummaryEnabled()
    return self.settings.showCombatSummary
end

function Options:IsDungeonSummaryEnabled()
    return self.settings.showDungeonSummary
end

function Options:IsSmartCoachEnabled()
    return self.settings.enableSmartCoach
end

-- =======================
-- Slash Command Interface
-- =======================
SLASH_MYCOMBATTEXT1 = "/mcts"
SLASH_MYCOMBATTEXT2 = "/combattext"

SlashCmdList["MYCOMBATTEXT"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    if cmd=="size" and tonumber(rest) then
        Options:SetTextSize(tonumber(rest))
    elseif cmd=="colors" then
        local typeName, r,g,b = rest:match("^(%S+)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)$")
        r,g,b = tonumber(r), tonumber(g), tonumber(b)
        if typeName and r and g and b then
            Options:SetColor(typeName, r,g,b)
        else
            print("Usage: /mcts colors <type> <r> <g> <b> (0-1)")
        end
    elseif cmd=="multischool" then
        Options:ToggleMultiSchoolTags(rest=="on")
    elseif cmd=="combat" then
        Options:ToggleCombatSummary(rest=="on")
    elseif cmd=="dungeon" then
        Options:ToggleDungeonSummary(rest=="on")
    elseif cmd=="coach" then
        Options:ToggleSmartCoach(rest=="on")
    else
        print([[
MyCombatText Options:
  /mcts size <number>          - Set text size
  /mcts colors <type> <r> <g> <b>  - Set color (0-1 range)
  /mcts multischool on/off     - Enable/Disable multi-school tags
  /mcts combat on/off          - Enable/Disable combat summaries
  /mcts dungeon on/off         - Enable/Disable dungeon summary
  /mcts coach on/off           - Enable/Disable smart coach
Types: physical, magical, dodge, parry, absorb, miss, block, coach
]])
    end
end

-- =======================
-- Export
-- =======================
MyCombatTextOptions = Options
