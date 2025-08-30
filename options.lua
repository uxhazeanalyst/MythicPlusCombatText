-- ########################################################
-- MyCombatTextCoachSmart Options (Per-Character Only)
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
        holy     = {r=1, g=0.9, b=0.5},
        fire     = {r=1, g=0.3, b=0},
        nature   = {r=0.6, g=0.9, b=0.2},
        frost    = {r=0.5, g=0.8, b=1},
        shadow   = {r=0.4, g=0, b=0.6},
        arcane   = {r=0.7, g=0.3, b=0.9},
        bleed    = {r=0.8, g=0.1, b=0.1},
        dodge    = {r=1, g=1, b=0},
        parry    = {r=0, g=1, b=1},
        absorb   = {r=0, g=1, b=0},
        miss     = {r=0.7, g=0.7, b=0.7},
        block    = {r=0.6, g=0.4, b=1},
        coach    = {r=1, g=0.66, b=0},
    },
    showMultiSchoolTags = true,
    showCombatSummary   = true,
    showDungeonSummary  = true,
    enableSmartCoach    = true,
    enableHealerCoach   = true,
    enableHealerSummary = true,
}

-- =======================
-- Load Settings
-- =======================
Options.settings = {}

local function SaveSettings() MyCombatTextCharDB = Options.settings end

local function LoadSettings()
    if not MyCombatTextCharDB then
        Options:ResetToDefaults()
        return
    end
    Options.settings = {}
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            Options.settings[k]={}
            for kk,vv in pairs(v) do
                Options.settings[k][kk] = (MyCombatTextCharDB[k] and MyCombatTextCharDB[k][kk]) or vv
            end
        else
            Options.settings[k] = (MyCombatTextCharDB[k]~=nil and MyCombatTextCharDB[k]) or v
        end
    end
end

-- =======================
-- Getters/Setters
-- =======================
function Options:SetColor(eventType,r,g,b)
    eventType=eventType:lower()
    if self.settings.colors[eventType] then
        self.settings.colors[eventType]={r=r,g=g,b=b}
        SaveSettings()
    else print("Unknown eventType:",eventType) end
end

function Options:GetColor(eventType)
    return self.settings.colors[eventType:lower()] or {r=1,g=1,b=1}
end

function Options:SetTextSize(s) self.settings.textSize=s; SaveSettings() end
function Options:GetTextSize() return self.settings.textSize end

function Options:ToggleHealerCoach(state) self.settings.enableHealerCoach=state; SaveSettings() end
function Options:IsHealerCoachEnabled() return self.settings.enableHealerCoach end

function Options:ToggleHealerSummary(state) self.settings.enableHealerSummary=state; SaveSettings() end
function Options:IsHealerSummaryEnabled() return self.settings.enableHealerSummary end

-- =======================
-- Reset
-- =======================
function Options:ResetToDefaults()
    self.settings={}
    for k,v in pairs(Options.defaults) do
        if type(v)=="table" then
            self.settings[k]={}
            for kk,vv in pairs(v) do self.settings[k][kk]=vv end
        else self.settings[k]=v end
    end
    SaveSettings()
end

-- =======================
-- Export/Import
-- =======================
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

local function base64enc(data)
    return ((data:gsub('.', function(x)
        local r,byte='',x:byte()
        for i=8,1,-1 do r=r..(byte%2^i-byte%2^(i-1)>0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x<6 then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function Serialize(tbl)
    local parts={}
    for k,v in pairs(tbl) do
        if type(v)=="table" then
            table.insert(parts,k.."="..Serialize(v))
        elseif type(v)=="boolean" then
            table.insert(parts,k.."="..(v and "1" or "0"))
        else
            table.insert(parts,k.."="..tostring(v))
        end
    end
    return "{"..table.concat(parts,",").."}"
end

function Options:Export()
    local raw=Serialize(self.settings)
    local encoded=base64enc(raw)
    print("MyCombatText Export String:\n"..encoded)
end

-- =======================
-- Slash Commands
-- =======================
SLASH_MYCOMBATTEXT1="/mcts"
SLASH_MYCOMBATTEXT2="/combattext"
SlashCmdList["MYCOMBATTEXT"]=function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd=cmd:lower()
    if cmd=="size" and tonumber(rest) then
        Options:SetTextSize(tonumber(rest)); print("Text size set to "..rest)
    elseif cmd=="colors" then
        local t,r,g,b=rest:match("^(%S+)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)$")
        if t then Options:SetColor(t,tonumber(r),tonumber(g),tonumber(b)) end
    elseif cmd=="reset" then Options:ResetToDefaults()
    elseif cmd=="export" then Options:Export()
    elseif cmd=="healer" then Options:ToggleHealerCoach(rest=="on")
    elseif cmd=="healersum" then Options:ToggleHealerSummary(rest=="on")
    else print("Usage: /mcts size <num>, colors <type> r g b, healer on/off, healersum on/off, reset, export")
    end
end

-- =======================
-- Init
-- =======================
LoadSettings()
MyCombatTextOptions=Options
