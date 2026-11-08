--[[
  Squad Tactics for SpaceBourne 2 (UE4SS Lua mod). Part of the SpaceBourne 2 realism set.
  Tactical orders for your ground squad: "Lead the way" (bounding overwatch). See DESIGN.md.

  Layout:
    config.lua        your settings
    st/gamedefs.lua   every game-internal name (the only file to check after a game patch)
    st/lead.lua       the "Lead the way" order
    st/hooks.lua      lazy, fault-isolated hook registration (as HTR and Silent Ops)
    st/gametick.lua   timed work on the game thread (shared by the set; no LoopAsync)
    st/hudmsg.lua     the set's on-screen line (shared by the set)
]]

local VERSION = "0.1.0"

local U = require("st.util")

-- Settings -------------------------------------------------------------------------------
local defaults = {
    Enabled = true,
    Lead = { StartOn = true, Key = "0", Pointmen = 2, Distance = 900, SecondDistance = 600, Leapfrog = 400,
        MaxLead = 1600, MinLead = 250, LeapWhenAhead = 350, YouMoved = 200, MinHoldSeconds = 1.5, RetrySeconds = 2, SideOffset = 150, SideSearch = 400,
        WallGap = 80, ArriveRadius = 120, MoveTimeout = 8, RunAbove = 250, Crouch = true, MaxRange = 4000,
        CombatRange = 5000, CombatSeconds = 12, TickSeconds = 0.5, ScanSeconds = 20 },
    Messages = true,
    Debug = { Log = false, Commands = false },
}
local function fill(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then dst[k] = v
        elseif type(v) == "table" and type(dst[k]) == "table" then fill(dst[k], v) end
    end
end
local okCfg, cfg = pcall(require, "config")
if not okCfg or type(cfg) ~= "table" then
    U.warn("config.lua could not be read (" .. tostring(cfg) .. "); using defaults")
    cfg = {}
end
fill(cfg, defaults)
U.Verbose = cfg.Debug.Log == true

if cfg.Enabled == false then
    U.warn("Squad Tactics " .. VERSION .. " loaded, disabled in config.lua (Enabled = false)")
    return
end

SQUAD_TACTICS = { version = VERSION, cfg = cfg }

local G = require("st.gamedefs")
local H = require("st.hooks")
local L = require("st.lead")
local HM = require("st.hudmsg")
local GT = require("st.gametick")
GT.log = function(msg) U.warn(msg) end
L.on = cfg.Lead.StartOn ~= false

local function say(text)
    if cfg.Messages == false then return end
    pcall(function() HM.show(L.player, text, 4, true) end)
end

-- Gunfire near you hands the pointmen back to the game's combat AI (hooks run on the game thread).
local function shotAt(self)
    local a
    pcall(function() a = self:get() end)
    L.combat(os.clock(), U.location(a))
end
H.add(G.Fn.NpcShot, shotAt, "npc shot")
H.add(G.Fn.SquadShot, function() L.combat(os.clock(), nil) end, "squad shot")
H.add(G.Fn.SquadPistol, function() L.combat(os.clock(), nil) end, "squad pistol")
H.add(G.Fn.PlayerShot, function() L.combat(os.clock(), nil) end, "your shot")
H.add(G.Fn.PlayerBeam, function() L.combat(os.clock(), nil) end, "your beam")

-- Timed work on the game thread: the HUD draw on foot and in a ship, the ALS tick as a fallback.
GT.drive(GT.HUD_TICK, "hud")
GT.drive(GT.FOOT_TICK, "foot")
GT.boot(function() L.reset() end)
local reportAt = os.clock() + 30
GT.every(cfg.Lead.TickSeconds or 0.5, function(now)
    local ok, err = pcall(L.tick, now)
    if not ok then U.warn("lead: " .. tostring(err)) end
    if U.Verbose and now > reportAt then reportAt = now + 30; U.log(L.report()) end
end)
GT.every(1.0, function(now)
    pcall(H.poll, now)
    if cfg.Debug.Commands then
        local f = io.open(U.Dir .. "debug_cmd.txt", "r")
        if f then
            local cmd = f:read("*a") or ""
            f:close()
            os.remove(U.Dir .. "debug_cmd.txt")
            if cmd:find("toggle") then U.warn("debug: lead the way " .. (L.toggle() and "ON" or "OFF")) end
            if cmd:find("report") then U.warn(L.report()) end
        end
    end
end)

-- Key: the set's shared key plan (plain key = frequent action; the plain bind stays quiet while Shift
-- is held, so Shift+0 stays Ammo Discipline's).
local ALIAS = { ["0"] = "ZERO", ["1"] = "ONE", ["2"] = "TWO", ["3"] = "THREE", ["4"] = "FOUR", ["5"] = "FIVE",
    ["6"] = "SIX", ["7"] = "SEVEN", ["8"] = "EIGHT", ["9"] = "NINE", DELETE = "DEL", INSERT = "INS" }
local FORBIDDEN = { F1 = 1, F2 = 1, F5 = 1, F6 = 1, F8 = 1, F10 = 1, F11 = 1, F12 = 1 }
local function bind(spec, fn)
    if type(spec) ~= "string" or spec == "" then return "none" end
    local shift, key = false, nil
    for part in spec:upper():gsub("%s", ""):gmatch("[^+]+") do
        if part == "SHIFT" then shift = true else key = ALIAS[part] or part end
    end
    if not key or not Key[key] or FORBIDDEN[key] then U.warn("key '" .. spec .. "' not usable; no key bound"); return "none" end
    local run = function() ExecuteInGameThread(function() pcall(fn) end) end
    if shift and ModifierKey then RegisterKeyBind(Key[key], { ModifierKey.SHIFT }, run) else RegisterKeyBind(Key[key], run) end
    return spec
end
local bound = bind(cfg.Lead.Key, function()
    local on = L.toggle()
    say(on and "Squad: lead the way" or "Squad: follow me")
end)

U.warn(string.format("=== Squad Tactics %s loaded: lead the way %s, key %s ===", VERSION, L.on and "ON" or "OFF", bound))
