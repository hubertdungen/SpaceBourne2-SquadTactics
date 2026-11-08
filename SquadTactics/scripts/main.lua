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

local VERSION = "0.2.0"

local U = require("st.util")

-- Settings -------------------------------------------------------------------------------
local defaults = {
    Enabled = true,
    Lead = { StartOn = true, Key = "", Pointmen = 2, Distance = 900, SecondDistance = 600, Leapfrog = 400,
        MaxLead = 1600, MinLead = 250, LeapWhenAhead = 350, YouMoved = 200, MinHoldSeconds = 1.5, RetrySeconds = 2, SideOffset = 150, SideSearch = 400,
        WallGap = 80, ArriveRadius = 120, MoveTimeout = 8, RunAbove = 250, Crouch = true, MaxRange = 4000,
        CombatRange = 3000, CombatSeconds = 12, TickSeconds = 0.5, ScanSeconds = 20, FloorHeight = 350 },
    Orders = { Enabled = true, Key = "Z", WhoKey = "0", HoldTime = 0.25, MenuStep = 3, RedSize = 2, Range = 5000,
        Spread = 150, HoldArc = 90, DoorHalfWidth = 110, Crouch = true, ArriveRadius = 120, MoveTimeout = 12,
        ClearAfter = 1.5, ClearQuiet = 5, MarkSeconds = 2.5 },
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
local O = require("st.orders")
local M = require("st.menu")
local HM = require("st.hudmsg")
local GT = require("st.gametick")
GT.log = function(msg) U.warn(msg) end
L.on = cfg.Lead.StartOn ~= false

local function say(text)
    if cfg.Messages == false then return end
    pcall(function() HM.show(L.player, text, 4, true) end)
end
O.say = say

-- Gunfire near you or the pointmen hands them back to the game's combat AI (hooks run on the game
-- thread). An NPC's shot counts where the NPC is; a squad soldier's where its target is (the game calls
-- BattleShoot every 1.5 s while a soldier sees a target, even far off: 0.1.0 counted those anywhere,
-- and in a dungeon full of creatures the pointmen hardly ever led).
local function fire(now, at, what)
    L.combat(now, at, what)
    if at then O.combat(now, at) end
    O.shot(now)
end
local function npcShot(self)
    local a
    pcall(function() a = self:get() end)
    local at = U.location(a)
    if at then fire(os.clock(), at, "enemy shot") end
end
local function squadShot(self)
    local a
    pcall(function() a = self:get() end)
    if not U.valid(a) then return end
    local t = U.get(a, G.P.Target, nil)
    if not U.valid(t) then return end -- the game shoots only with a target; none readable: not counted
    local at = U.location(t)
    if at then fire(os.clock(), at, "squad shot at " .. tostring(U.className(t))) end
end
H.add(G.Fn.NpcShot, npcShot, "npc shot")
H.add(G.Fn.SquadShot, squadShot, "squad shot")
H.add(G.Fn.SquadPistol, squadShot, "squad pistol")
local function yourShot(what)
    return function()
        local now = os.clock()
        L.combat(now, nil, what)
        local me = U.valid(L.player) and U.location(L.player) or nil
        if me then O.combat(now, me) end
        O.shot(now)
    end
end
H.add(G.Fn.PlayerShot, yourShot("your shot"), "your shot")
H.add(G.Fn.PlayerBeam, yourShot("your beam"), "your beam")

-- The order list and markers, drawn on the HUD canvas (only while Z is down or just after an order).
H.add(G.DrawHUD, function(self, sx, sy)
    local hud, w, h
    pcall(function() hud = self:get(); w = sx:get(); h = sy:get() end)
    if not U.valid(hud) or not w or not h then return end
    M.frame(hud, w, h, os.clock())
end, "order list")

-- Timed work on the game thread: the HUD draw on foot and in a ship, the ALS tick as a fallback.
GT.drive(GT.HUD_TICK, "hud")
GT.drive(GT.FOOT_TICK, "foot")
GT.boot(function() O.reset(); M.reset(); L.reset() end)
local reportAt = os.clock() + 30
GT.every(cfg.Lead.TickSeconds or 0.5, function(now)
    local ok, err = pcall(L.tick, now)
    if not ok then U.warn("lead: " .. tostring(err)) end
    if O.count() > 0 then
        local ok2, err2 = pcall(O.tick, now)
        if not ok2 then U.warn("orders: " .. tostring(err2)) end
    end
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
            if cmd:find("report") then
                U.warn(L.report())
                local parts = {}
                for _, m in pairs(O.men) do
                    local l = U.location(m.obj)
                    parts[#parts + 1] = string.format("%s %s/%s %.1f m from its spot%s", tostring(m.a), m.order, tostring(m.phase),
                        (l and m.spot) and U.dist2(l, m.spot) / 100 or -1, m.paused and " paused" or "")
                end
                U.warn(string.format("orders: %d given, %d anchors, %d soldiers with orders, %d waiting: %s", O.stats.orders,
                    O.stats.anchors, O.count(), #O.queue, table.concat(parts, "; ")))
            end
            -- scripted tests: "order move", "queue stack", "go", "who", "menu 4" (the list up for 4 s)
            local now = os.clock()
            local id = cmd:match("order (%a+)")
            if id or cmd:find("queue") or cmd:find("menu") then
                local p = L.h.playerOnFoot()
                if p then
                    L.player = p
                    local a = O.aim(L.pc, p)
                    local ctx = O.context(a)
                    U.warn(string.format("debug aim: hit=%s at %s actor=%s door=%s ally=%s -> %s", tostring(a and a.hit),
                        a and a.at and string.format("%.0f,%.0f,%.0f", a.at.X, a.at.Y, a.at.Z) or "-", tostring(a and a.cls),
                        tostring(a and a.door), tostring(a and a.ally ~= nil), ctx))
                    if id then O.give(id == "default" and ctx or id, a, now) end
                    local qid = cmd:match("queue (%a+)")
                    if qid then O.queueOrder(qid, a, now) end
                    local secs = tonumber(cmd:match("menu (%d+)") or "")
                    if secs then M.demo(now, secs) end
                end
            end
            if cmd:find("^%s*go") then O.go(now) end
            if cmd:find("who") then O.cycleWho(now) end
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
local o = cfg.Orders
local function same(a, b) return type(a) == "string" and type(b) == "string" and a:upper():gsub("%s", "") == b:upper():gsub("%s", "") end
local bound = "none"
if not same(cfg.Lead.Key, o.Key) and not same(cfg.Lead.Key, o.WhoKey) then
    bound = bind(cfg.Lead.Key, function()
        local on = L.toggle()
        say(on and "Squad: lead the way" or "Squad: follow me")
    end)
end
local orderKey, whoKey = "none", "none"
if o.Enabled ~= false then
    M.keyName = (o.Key or "Z"):upper()
    orderKey = bind(o.Key, function() M.press(os.clock()) end)
    if orderKey ~= "none" and not o.Key:upper():find("SHIFT") then bind("Shift+" .. o.Key, function() M.press(os.clock()) end) end
    whoKey = bind(o.WhoKey, function() M.who(os.clock()) end)
end

U.warn(string.format("=== Squad Tactics %s loaded: lead the way %s (key %s), orders key %s, who key %s ===", VERSION,
    L.on and "ON" or "OFF", bound, orderKey, whoKey))
