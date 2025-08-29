-- ########################################################
-- MyCombatTextCoachSmart Options (Per-Character Only)
-- Export/Import with Base64 encoded settings
-- ########################################################

local Options = {}

-- =======================
-- Defaults
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
-- Load Per-Character Settings
-- =======================
Options.settings = {}

if MyCombatTextCharDB then
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            Options.settings[k] = {}
            for key,val in pairs(v) do
                Options.settings[k][key] = MyCombatTextCharDB[k] and MyCombatTextCharDB[k][key] or val
            end
        else
            Options.settings[k] = MyCombatTextCharDB[k] ~= nil and MyCombatTextCharDB[k] or v
        end
    end
else
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            Options.settings[k]={}
            for key,val in pairs(v) do
                Options.settings[k][key]=val
            end
        else
            Options.settings[k]=v
        end
    end
end

local function SaveSettings()
    MyCombatTextCharDB = Options.settings
end

-- =======================
-- Setters / Getters
-- =======================
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

function Options:GetColor(eventType) return self.settings.colors[eventType] or {r=1,g=1,b=1} end
function Options:GetTextSize() return self.settings.textSize end
function Options:IsMultiSchoolTagsEnabled() return self.settings.showMultiSchoolTags end
function Options:IsCombatSummaryEnabled() return self.settings.showCombatSummary end
function Options:IsDungeonSummaryEnabled() return self.settings.showDungeonSummary end
function Options:IsSmartCoachEnabled() return self.settings.enableSmartCoach end

-- =======================
-- Reset
-- =======================
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

-- =======================
-- Base64 Helpers
-- =======================
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64enc(data)
    return ((data:gsub('.', function(x) 
        local r,bits='',x:byte()
        for i=8,1,-1 do r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64dec(data)
    data = data:gsub('[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- =======================
-- Serialization
-- =======================
local function Serialize(tbl)
    local function serializeTable(t)
        local parts={}
        for k,v in pairs(t) do
            if type(v)=="table" then
                table.insert(parts, k.."="..serializeTable(v))
            elseif type(v)=="boolean" then
                table.insert(parts, k.."="..(v and "1" or "0"))
            else
                table.insert(parts, k.."="..tostring(v))
            end
        end
        return "{"..table.concat(parts,",").."}"
    end
    return serializeTable(tbl)
end

local function Deserialize(str)
    local f,err = loadstring("return "..str)
    if not f then return nil, err end
    local ok, result = pcall(f)
    if ok then return result else return nil, result end
end

-- =======================
-- Export / Import
-- =======================
function Options:Export()
    local raw = Serialize(self.settings)
    local encoded = base64enc(raw)
    print("MyCombatText Export String:\n"..encoded)
end

function Options:Import(str)
    local decoded = base64dec(str)
    local tbl, err = Deserialize(decoded)
    if not tbl then
        print("Import failed: "..err)
        return
    end
    self.settings = tbl
    SaveSettings()
    print("Import successful! Settings applied.")
end

-- =======================
-- Slash Commands
-- =======================
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
    elseif cmd=="export" then Options:Export()
    elseif cmd=="import" then Options:Import(rest)
    elseif cmd=="share" then Options:Share()
    else
        print("Usage: /mcts size <num>, colors <type> <r> <g> <b>, multischool on/off, combat on/off, dungeon on/off, coach on/off, reset, export, import <string>")
    end
end
-- =======================
-- Share (Popup EditBox)
-- =======================
StaticPopupDialogs["MYCOMBATTEXT_SHARE"] = {
    text = "Copy this export string:",
    button1 = "Close",
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self, data)
        local editBox = self.editBox
        editBox:SetText(data)
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
}

function Options:Share()
    local raw = Serialize(self.settings)
    local encoded = base64enc(raw)
    StaticPopup_Show("MYCOMBATTEXT_SHARE", nil, nil, encoded)
end

-- =======================
-- Global
-- =======================
MyCombatTextOptions=Options
