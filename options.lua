-- ########################################################
-- MyCombatTextCoachSmart Options
-- Copyright (c) 2025 YourName
-- License: Non-commercial personal use only
-- ########################################################

local Options = {}

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
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            Options.settings[k]={}
            for key,val in pairs(v) do
                Options.settings[k][key] = val
            end
        else
            Options.settings[k] = v
        end
    end
end

local function SaveSettings()
    MyCombatTextDB = Options.settings
end

-- Setters
function Options:SetColor(eventType,r,g,b)
    if self.settings.colors[eventType] then
        self.settings.colors[eventType]={r=r,g=g,b=b}
        SaveSettings()
    end
end
function Options:SetTextSize(size) self.settings.textSize=size; SaveSettings() end
function Options:ToggleMultiSchoolTags(state) self.settings.showMultiSchoolTags=state; SaveSettings() end
function Options:ToggleCombatSummary(state) self.settings.showCombatSummary=state; SaveSettings() end
function Options:ToggleDungeonSummary(state) self.settings.showDungeonSummary=state; SaveSettings() end
function Options:ToggleSmartCoach(state) self.settings.enableSmartCoach=state; SaveSettings() end

-- Getters
function Options:GetColor(eventType) return self.settings.colors[eventType] or {r=1,g=1,b=1} end
function Options:GetTextSize() return self.settings.textSize end
function Options:IsMultiSchoolTagsEnabled() return self.settings.showMultiSchoolTags end
function Options:IsCombatSummaryEnabled() return self.settings.showCombatSummary end
function Options:IsDungeonSummaryEnabled() return self.settings.showDungeonSummary end
function Options:IsSmartCoachEnabled() return self.settings.enableSmartCoach end

function Options:ResetToDefaults()
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            for key,val in pairs(v) do
                self.settings[k][key]=val
            end
        else
            self.settings[k]=v
        end
    end
    SaveSettings()
end

SLASH_MYCOMBATTEXT1="/mcts"
SLASH_MYCOMBATTEXT2="/combattext"
SlashCmdList["MYCOMBATTEXT"]=function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd=cmd:lower()
    if cmd=="size" and tonumber(rest) then Options:SetTextSize(tonumber(rest))
    elseif cmd=="colors" then
        local typeName,r,g,b=rest:match("^(%S+)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)$")
        r,g,b=tonumber(r),tonumber(g),tonumber(b)
        if typeName and r and g and b then Options:SetColor(typeName,r,g,b) end
    elseif cmd=="multischool" then Options:ToggleMultiSchoolTags(rest=="on")
    elseif cmd=="combat" then Options:ToggleCombatSummary(rest=="on")
    elseif cmd=="dungeon" then Options:ToggleDungeonSummary(rest=="on")
    elseif cmd=="coach" then Options:ToggleSmartCoach(rest=="on")
    elseif cmd=="reset" then Options:ResetToDefaults()
    else print("Usage: /mcts size <num>, colors <type> <r> <g> <b>, multischool on/off, combat on/off, dungeon on/off, coach on/off, reset") end
end

MyCombatTextOptions=Options
