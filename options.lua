-- ########################################################
-- MyCombatTextCoachSmart Options
-- Copyright (c) 2025 YourName
-- License: Non-commercial personal use only
-- You may not redistribute, sell, or use this addon commercially
-- without explicit permission.
-- ########################################################

local Options = {}

-- =======================
-- Default Settings
-- =======================
Options.defaults = {
    textSize = 16,
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
-- Load Saved Settings or Defaults
-- =======================
Options.settings = {}
if MyCombatTextDB then
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            Options.settings[k] = {}
            for key,val in pairs(v) do
                Options.settings[k][key] = MyCombatTextDB[k] and MyCombatTextDB[k][key] or val
            end
        else
            Options.settings[k] = MyCombatTextDB[k] ~= nil and MyCombatTextDB[k] or v
        end
    end
else
    -- no saved data, use defaults
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
end

-- =======================
-- Save Current Settings
-- =======================
local function SaveSettings()
    MyCombatTextDB = Options.settings
end

-- =======================
-- Setters (also save)
-- =======================
function Options:SetColor(eventType, r, g, b)
    if self.settings.colors[eventType] then
        self.settings.colors[eventType] = {r=r, g=g, b=b}
        SaveSettings()
        print(string.format("MyCombatText: %s color set to R:%.2f G:%.2f B:%.2f", eventType, r, g, b))
    end
end

function Options:SetTextSize(size)
    self.settings.textSize = size
    SaveSettings()
    print("MyCombatText: Text size set to "..size)
end

function Options:ToggleMultiSchoolTags(state)
    self.settings.showMultiSchoolTags = state
    SaveSettings()
    print("MyCombatText: Multi-school tags "..(state and "enabled" or "disabled"))
end

function Options:ToggleCombatSummary(state)
    self.settings.showCombatSummary = state
    SaveSettings()
    print("MyCombatText: Combat summary "..(state and "enabled" or "disabled"))
end

function Options:ToggleDungeonSummary(state)
    self.settings.showDungeonSummary = state
    SaveSettings()
    print("MyCombatText: Dungeon summary "..(state and "enabled" or "disabled"))
end

function Options:ToggleSmartCoach(state)
    self.settings.enableSmartCoach = state
    SaveSettings()
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
-- Reset to Defaults
-- =======================
function Options:ResetToDefaults()
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            for key,val in pairs(v) do
                self.settings[k][key] = val
            end
        else
            self.settings[k] = v
        end
    end
    SaveSettings()
    print("MyCombatText: Settings reset to defaults.")
end

-- =======================
-- Slash Commands
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
    elseif cmd=="reset" then
        Options:ResetToDefaults()
    else
        print([[MyCombatText Options:
  /mcts size <number>          - Set text size
  /mcts colors <type> <r> <g> <b>  - Set color (0-1 range)
  /mcts multischool on/off     - Enable/Disable multi-school tags
  /mcts combat on/off          - Enable/Disable combat summaries
  /mcts dungeon on/off         - Enable/Disable dungeon summary
  /mcts coach on/off           - Enable/Disable smart coach
  /mcts reset                  - Reset all settings to defaults
Types: physical, magical, dodge, parry, absorb, miss, block, coach]])
    end
end

-- =======================
-- Export
-- =======================
MyCombatTextOptions = Options
