--[[
  Squad orders, Ready-or-Not style (DESIGN.md section 8): who (all / red / blue / the one or two nearest
  the spot), where (the spot you aim at), what (move here, hold & cover, stack up, stack & clear, lead
  the way, cover him, fall in), and orders that wait for your "go".

  How a soldier keeps a spot and still fights (verified in game, test 30): its formation slot
  (GoalRM, a ChildActorComponent on you; GoalActor its actor) is pointed at an anchor of ours (a
  TargetPoint with a ChildActorComponent) at the spot. The game's own logic then brings it back there
  whenever it is more than 7 m away, and targets and shoots as usual. "Fall in" puts your slot back.
  A soldier that crouches and watches a way (hold & cover, stack up) has its battle timer paused
  while all is quiet; gunfire near it lets it fight, and it goes back to its spot afterwards.
]]

local U = require("st.util")
local G = require("st.gamedefs")
local P = G.P
local L = require("st.lead")

local O = { who = 1, men = {}, queue = {}, stats = { orders = 0, anchors = 0 } }
O.WHO = { "all", "red", "blue", "one", "two" }
O.WHO_NAME = { all = "ALL", red = "RED", blue = "BLUE", one = "ONE", two = "TWO" }
O.COLOR = {
    all = { R = 1, G = 0.78, B = 0.2, A = 1 }, red = { R = 1, G = 0.32, B = 0.26, A = 1 },
    blue = { R = 0.35, G = 0.62, B = 1, A = 1 }, one = { R = 0.92, G = 0.92, B = 0.92, A = 1 },
    two = { R = 0.92, G = 0.92, B = 0.92, A = 1 },
}
O.NAME = { move = "Move here", hold = "Hold & cover", stack = "Stack up", clear = "Stack & clear",
    lead = "Lead the way", cover = "Cover him", fallin = "Fall in", go = "GO", rescue = "Rescue me" }

local function cfg() return SQUAD_TACTICS.cfg.Orders end
local function lcfg() return SQUAD_TACTICS.cfg.Lead end
local H = function() return L.h end

local function say(text) if O.say then O.say(text) end end

local function norm(x, y)
    local l = math.sqrt(x * x + y * y)
    if l < 1e-6 then return 1, 0 end
    return x / l, y / l
end
local function yawOf(x, y) return math.deg(math.atan(y, x)) end

-- Aim ----------------------------------------------------------------------------------------------
-- One trace along your camera (visibility channel, one reused out table cleared before the call, a new
-- one if refused). The hit actor is read from the hit result when UE4SS gives it (logged once).
local AIM, aimFresh, actorNote = {}, false, false
local WHITE = { R = 1, G = 1, B = 1, A = 1 }

-- The hit result's Actor is a weak pointer: UE4SS hands back an FWeakObjectPtr (test 33), whose own
-- Get() gives the object. Recognised by its name first: no method is called on anything else.
local function hitActor(out)
    local w
    pcall(function() w = out.Actor end)
    if type(w) ~= "userdata" then return nil end
    local name = ""
    pcall(function() name = tostring(w) end)
    if not name:find("^FWeakObjectPtr") then return U.valid(w) and w or nil end
    local o
    pcall(function() o = w:Get() end)
    if not U.valid(o) then pcall(function() o = w:get() end) end
    return U.valid(o) and o or nil
end

function O.aim(pc, p)
    local cam = U.get(pc, "PlayerCameraManager", nil)
    local lib = H().ksl()
    if not U.valid(cam) or not lib then return nil end
    local loc, rot
    pcall(function() local v = cam:GetCameraLocation(); loc = { X = v.X, Y = v.Y, Z = v.Z } end)
    pcall(function() local r = cam:GetCameraRotation(); rot = { Pitch = r.Pitch, Yaw = r.Yaw } end)
    if not loc or not rot then return nil end
    local cp = math.cos(math.rad(rot.Pitch))
    local dir = { X = cp * math.cos(math.rad(rot.Yaw)), Y = cp * math.sin(math.rad(rot.Yaw)), Z = math.sin(math.rad(rot.Pitch)) }
    local range = cfg().Range or 5000
    local b = { X = loc.X + dir.X * range, Y = loc.Y + dir.Y * range, Z = loc.Z + dir.Z * range }
    local out = AIM
    if aimFresh then out = {} else for k in pairs(AIM) do AIM[k] = nil end end
    local ok, hit = pcall(function() return lib:LineTraceSingle(p, loc, b, 0, false, {}, 0, out, true, WHITE, WHITE, 0.0) end)
    if not ok and not aimFresh then
        aimFresh, out = true, {}
        ok, hit = pcall(function() return lib:LineTraceSingle(p, loc, b, 0, false, {}, 0, out, true, WHITE, WHITE, 0.0) end)
    end
    local a = { from = loc, dir = dir, yaw = rot.Yaw, hit = ok and hit == true }
    if a.hit then
        pcall(function() local v = out.ImpactPoint; a.at = { X = v.X, Y = v.Y, Z = v.Z } end)
        if not a.at then pcall(function() local v = out.Location; a.at = { X = v.X, Y = v.Y, Z = v.Z } end) end
        pcall(function() local n = out.ImpactNormal; a.normal = { X = n.X, Y = n.Y, Z = n.Z } end)
        a.actor = hitActor(out)
        if not actorNote then
            actorNote = true
            U.log("aim: hit actor " .. (a.actor and ("read: " .. tostring(U.className(a.actor))) or "not readable"))
        end
        if not a.at then a.hit = false end
    end
    return a
end

-- What the aim is on: a door, one of your squad, a wall or the floor, or nothing.
-- One of your squad: the hit actor itself, or (hit actor not readable) a hit on a soldier's body,
-- not on the floor at its feet (test 34: aiming at the floor next to a soldier gave "cover him").
local function squadAt(at, actor)
    local aa = actor and U.addr(actor)
    for _, s in ipairs(L.squad) do
        if aa and s.a == aa and U.alive(s.obj, s.a) then return s end
    end
    if actor then return nil end
    for _, s in ipairs(L.squad) do
        local l = U.alive(s.obj, s.a) and U.location(s.obj) or nil
        if l and math.sqrt((l.X - at.X) ^ 2 + (l.Y - at.Y) ^ 2) < 50 and at.Z > l.Z - 60 and at.Z < l.Z + 110 then return s end
    end
    return nil
end

-- a door Blueprint, or a part attached to one (the space dungeon gate's transmitter, test 34)
local function isDoor(actor, cls)
    if cls and G.Doors[cls] then return true end
    local parent
    pcall(function() parent = actor:GetAttachParentActor() end)
    if not U.valid(parent) then pcall(function() parent = actor:GetOwner() end) end
    return U.valid(parent) and G.Doors[U.className(parent) or ""] == true
end

function O.context(a)
    if not a or not a.hit then return "fallin" end
    a.wall = a.normal and math.abs(a.normal.Z) < 0.5
    local cls = a.actor and U.className(a.actor)
    a.cls = cls
    if a.actor and isDoor(a.actor, cls) then a.door = true end
    local s = squadAt(a.at, a.actor)
    if s then a.ally = s.obj end
    if a.door then return "stack" end
    if a.ally then return "cover" end
    return "move"
end

-- "Rescue me" through Hardcore Tactical Realism 0.4.16+ (its README, "For other mods"): you are down
-- while your pawn's Injured? is true; creating HTR's rescue.request file makes your rescue urgent (the
-- nearest ally comes at once). Separate Lua states, so a file. Checked once per game start: HTR's
-- version from its main.lua, and not switched off in mods.txt.
local function modsDir() return U.Dir:match("^(.*[\\/])[^\\/]+[\\/]$") end

function O.htrRescue()
    if O.htrChecked then return O.htrOK end
    O.htrChecked, O.htrOK = true, false
    local dir = modsDir()
    if not dir then return false end
    local f = io.open(dir .. "HardcoreTacticalRealism\\scripts\\main.lua", "r")
    if not f then U.log("rescue me: Hardcore Tactical Realism not found"); return false end
    local src = f:read("*a") or ""
    f:close()
    local a, b, c = src:match('VERSION%s*=%s*"(%d+)%.(%d+)%.(%d+)"')
    local v = a and (tonumber(a) * 10000 + tonumber(b) * 100 + tonumber(c)) or 0
    local off = false
    local m = io.open(dir .. "mods.txt", "r")
    if m then
        local t = m:read("*a") or ""
        m:close()
        off = t:find("HardcoreTacticalRealism%s*:%s*0") ~= nil
    end
    O.htrOK = v >= 416 and not off
    O.htrDir = dir .. "HardcoreTacticalRealism\\"
    U.log(string.format("rescue me: Hardcore Tactical Realism %s.%s.%s%s -> %s", tostring(a), tostring(b), tostring(c),
        off and " (off in mods.txt)" or "", O.htrOK and "available" or "not available (needs 0.4.16)"))
    return O.htrOK
end

-- you are down (HTR holds you knocked out, or the game's own injured state)
function O.down()
    return U.valid(L.player) and U.get(L.player, "Injured?", false) == true
end

local function rescue(now)
    local ok = false
    if O.htrRescue() then
        local f = io.open(O.htrDir .. "rescue.request", "w")
        if f then f:write("Squad Tactics\n"); f:close(); ok = true end
    end
    U.log("order: rescue me, request written " .. tostring(ok))
    say(ok and "Rescue requested" or "Rescue me needs Hardcore Tactical Realism 0.4.16")
    return ok
end

-- The order list for this aim, the fitting one first; with orders waiting, GO first.
-- While you are down: Rescue me (with HTR 0.4.16+), else Fall in: everyone comes to you.
function O.menuFor(a)
    if O.down() then
        local def = O.htrRescue() and "rescue" or "fallin"
        return def == "rescue" and { "rescue", "fallin" } or { "fallin" }, def
    end
    local def = O.context(a)
    local items = {}
    if #O.queue > 0 then items[#items + 1] = "go" end
    local function add(id) for _, x in ipairs(items) do if x == id then return end end; items[#items + 1] = id end
    add(def)
    if a and a.hit then
        if a.door then add("stack"); add("clear") end
        add("move"); add("hold")
        if a.wall then add("stack"); add("clear") end
        if a.ally then add("cover") end
    end
    add("lead"); add("fallin")
    return items, def
end

-- Who -------------------------------------------------------------------------------------------------
local function squadNow(now)
    local out = {}
    for _, s in ipairs(L.ensureSquad(now)) do
        if U.alive(s.obj, s.a) and H().usable(s.obj) then out[#out + 1] = s end
    end
    table.sort(out, function(x, y) if x.crew ~= y.crew then return x.crew < y.crew end; return tostring(x.a) < tostring(y.a) end)
    return out
end

function O.selected(now, at)
    local all = squadNow(now)
    local who = O.WHO[O.who]
    if who == "all" then return all end
    if who == "red" or who == "blue" then
        local n, r = cfg().RedSize or 2, {}
        for i, s in ipairs(all) do if (i <= n) == (who == "red") then r[#r + 1] = s end end
        return r
    end
    local ref = at or U.location(L.player)
    if not ref then return {} end
    for _, s in ipairs(all) do
        local l = U.location(s.obj)
        s.d = l and ((l.X - ref.X) ^ 2 + (l.Y - ref.Y) ^ 2) or 1e18
    end
    table.sort(all, function(x, y) return x.d < y.d end)
    local r = {}
    for i = 1, math.min(#all, who == "one" and 1 or 2) do r[i] = all[i] end
    return r
end

function O.cycleWho(now)
    O.who = O.who % #O.WHO + 1
    local who = O.WHO[O.who]
    local n = #O.selected(now, nil)
    say(string.format("Squad: %s (%d)", O.WHO_NAME[who], n))
    U.log(string.format("who: %s (%d)", O.WHO_NAME[who], n))
    return who
end

-- Anchors and slots ------------------------------------------------------------------------------------
local function spawnAnchor(at)
    local TP, CAC = StaticFindObject(G.TargetPoint), StaticFindObject(G.ChildActor)
    if not U.valid(TP) or not U.valid(CAC) or not U.valid(L.player) then return nil end
    local a
    pcall(function() a = L.player:GetWorld():SpawnActor(TP, at, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
    if not U.valid(a) then return nil end
    local T = { Rotation = { X = 0, Y = 0, Z = 0, W = 1 }, Translation = { X = 0, Y = 0, Z = 0 }, Scale3D = { X = 1, Y = 1, Z = 1 } }
    local comp
    pcall(function() comp = a:AddComponentByClass(CAC, false, T, false) end)
    if not U.valid(comp) then pcall(function() a:K2_DestroyActor() end); return nil end
    pcall(function() a:FinishAddComponent(comp, false, T) end)
    O.stats.anchors = O.stats.anchors + 1
    return a, comp
end

-- the slot on another actor (cover him): a ChildActorComponent added to that soldier
local function slotOn(actor)
    local CAC = StaticFindObject(G.ChildActor)
    if not U.valid(CAC) or not U.valid(actor) then return nil end
    local T = { Rotation = { X = 0, Y = 0, Z = 0, W = 1 }, Translation = { X = -150, Y = 0, Z = 0 }, Scale3D = { X = 1, Y = 1, Z = 1 } }
    local comp
    pcall(function() comp = actor:AddComponentByClass(CAC, false, T, false) end)
    if not U.valid(comp) then return nil end
    pcall(function() actor:FinishAddComponent(comp, false, T) end)
    return comp
end

local function setSlot(m, comp, actor)
    if m.oldRM == nil then
        m.oldRM, m.oldGA = U.get(m.obj, P.GoalRM, false), U.get(m.obj, P.GoalActor, false)
    end
    m.slot, m.slotActor = comp, actor
    pcall(function() m.obj[P.GoalRM] = comp; m.obj[P.GoalActor] = actor end)
end

local function freeAnchor(m)
    if U.valid(m.anchor) then pcall(function() m.anchor:K2_DestroyActor() end) end
    if U.valid(m.coverComp) then pcall(function() m.coverComp:K2_DestroyComponent(m.coverComp) end) end
    m.anchor, m.coverComp, m.slot, m.slotActor = nil, nil, nil, nil
end

-- the soldier's own slot on you: the one it had, else your SquadLocations[its crew index]
local function homeSlot(m)
    if m.oldRM and U.valid(m.oldRM) then return m.oldRM, m.oldGA end
    local crew = U.get(m.obj, P.CrewIndex, nil)
    local arr = U.valid(L.player) and U.get(L.player, "SquadLocations", nil) or nil
    if type(crew) ~= "number" or not arr then return nil end
    local comp
    pcall(function() comp = arr[crew + 1] end)
    if not U.valid(comp) then return nil end
    return comp, U.get(comp, "ChildActor", nil)
end

-- the soldier back to following you, the game's way
local function clear(m)
    if U.alive(m.obj, m.a) then
        local rm, ga = homeSlot(m)
        if rm then pcall(function() m.obj[P.GoalRM] = rm; m.obj[P.GoalActor] = ga end) end
        H().setTimer(m.obj, true)
        pcall(function() m.obj:UnCrouch(false) end)
        if m.rot ~= nil then pcall(function() m.obj:SetRotationMode(m.rot) end) end
    end
    freeAnchor(m)
    L.busy[m.a] = nil
    O.men[m.a] = nil
end

function O.clearAll()
    for _, m in pairs(O.men) do clear(m) end
    O.men = {}
end

-- Spots ------------------------------------------------------------------------------------------------
-- n spots on a short line across your view at the point, each traced from the point so none is
-- inside a wall; on a wall, the line is 1 m out from it.
local function spread(a, n, gap)
    local at = { X = a.at.X, Y = a.at.Y, Z = a.at.Z }
    if a.wall and a.normal then at.X, at.Y = at.X + a.normal.X * 100, at.Y + a.normal.Y * 100 end
    local fx, fy = norm(a.dir.X, a.dir.Y)
    local rx, ry = -fy, fx
    local base = { X = at.X, Y = at.Y, Z = at.Z + 60 }
    local spots = {}
    for i = 1, n do
        local k = (i - (n + 1) / 2) * gap
        local off = k
        if math.abs(k) > 1 then
            local sx, sy = rx * (k > 0 and 1 or -1), ry * (k > 0 and 1 or -1)
            local h = H().trace(base, { X = base.X + sx * math.abs(k), Y = base.Y + sy * math.abs(k), Z = base.Z })
            if h then off = (k > 0 and 1 or -1) * math.max(0, h - 60) end
        end
        spots[i] = { X = at.X + rx * off, Y = at.Y + ry * off, Z = at.Z + 90 }
    end
    return spots, yawOf(fx, fy)
end

-- Stack up: on your side of the door, against the wall on both sides of the frame, facing the door.
local function door(a)
    local c = { X = a.at.X, Y = a.at.Y, Z = a.at.Z }
    if a.door and a.actor then
        local l = U.location(a.actor)
        if l then c.X, c.Y = l.X, l.Y end
    end
    local nx, ny
    if a.normal and math.abs(a.normal.Z) < 0.5 then nx, ny = norm(a.normal.X, a.normal.Y) else nx, ny = norm(-a.dir.X, -a.dir.Y) end
    return c, nx, ny
end

local function stackSpots(a, n)
    local c, nx, ny = door(a)
    local tx, ty = -ny, nx
    local half = cfg().DoorHalfWidth or 110
    local spots, faces = {}, {}
    for i = 1, n do
        local side = (i % 2 == 1) and -1 or 1
        local row = math.floor((i - 1) / 2)
        local along = half + 50 + row * 80
        local s = { X = c.X + nx * 70 + tx * side * along, Y = c.Y + ny * 70 + ty * side * along, Z = c.Z + 90 }
        spots[i], faces[i] = s, yawOf(c.X - s.X, c.Y - s.Y)
    end
    return spots, faces
end

-- Clear: two spots inside the room, about 45 degrees left and right of straight in, short of the walls.
local function roomSpots(a)
    local c, nx, ny = door(a)
    local ix, iy = -nx, -ny
    local entry = { X = c.X + ix * 150, Y = c.Y + iy * 150, Z = c.Z + 60 }
    local out = {}
    for k, ang in ipairs({ -50, 50 }) do
        local r = math.rad(ang)
        local dx, dy = ix * math.cos(r) - iy * math.sin(r), ix * math.sin(r) + iy * math.cos(r)
        local h = H().trace(entry, { X = entry.X + dx * 800, Y = entry.Y + dy * 800, Z = entry.Z })
        local d = h and math.max(100, h - 100) or 600
        out[k] = { spot = { X = entry.X + dx * d, Y = entry.Y + dy * d, Z = c.Z + 90 }, face = yawOf(dx, dy) }
    end
    return out
end

-- Moving and holding --------------------------------------------------------------------------------
-- A path to the spot; none: a path to the order's centre (test 32: a spread spot behind a crate or
-- inside a wall left a soldier standing still); none either: straight at the spot. The anchor (its
-- slot) goes where it goes.
local function goTo(m, spot, now, paused)
    local c = H().controllerOf(m.obj)
    if not c then return false end
    H().setTimer(m.obj, not paused)
    m.paused = paused
    pcall(function() m.obj:UnCrouch(false) end)
    pcall(function() m.obj:SetDesiredGait(G.Gait.Running) end)
    local r = -1
    pcall(function() r = c:MoveToLocation(spot, 60.0, true, true, true, false, nil, true) end)
    if not H().moved(r) and m.centre and U.dist2(m.centre, spot) > 50 then
        local c2 = m.centre
        pcall(function() r = c:MoveToLocation(c2, 60.0, true, true, true, false, nil, true) end)
        if H().moved(r) then
            spot = { X = c2.X, Y = c2.Y, Z = c2.Z }
            if U.valid(m.anchor) then pcall(function() m.anchor:K2_TeleportTo(spot, { Pitch = 0, Yaw = 0, Roll = 0 }) end) end
            U.log("orders: no path to " .. tostring(m.a) .. "'s spot; it goes to the centre")
        end
    end
    if not H().moved(r) then pcall(function() r = c:MoveToLocation(spot, 60.0, true, false, false, false, nil, true) end) end
    m.spot, m.phase, m.since, m.lastPos, m.lastMoveAt = spot, "moving", now, U.location(m.obj), now
    return H().moved(r)
end

local function watch(m, now)
    m.phase, m.since = "watching", now
    H().setTimer(m.obj, false)
    m.paused = true
    if cfg().Crouch ~= false then pcall(function() m.obj:Crouch(false) end) end
    if m.face then
        pcall(function() m.obj:SetRotationMode(G.LookingDirection) end)
        pcall(function() m.obj:K2_SetActorRotation({ Pitch = 0, Yaw = m.face, Roll = 0 }, false) end)
        local c = H().controllerOf(m.obj)
        if c then pcall(function() c:SetControlRotation({ Pitch = 0, Yaw = m.face, Roll = 0 }) end) end
    end
end

local function there(m, now)
    m.phase, m.since = "there", now
    H().setTimer(m.obj, true)
    m.paused = false
end

local function newMan(s, order, now)
    local old = O.men[s.a]
    if old then clear(old) end
    L.drop(s.a)
    L.busy[s.a] = true
    local m = { obj = s.obj, a = s.a, order = order, since = now, rot = U.get(s.obj, P.RotationMode, nil) }
    if type(m.rot) ~= "number" then m.rot = nil end
    O.men[s.a] = m
    return m
end

-- Give an order --------------------------------------------------------------------------------------
function O.give(order, a, now, sel)
    if order == "rescue" then return rescue(now) end
    sel = sel or O.selected(now, a and a.at)
    local who = O.WHO[O.who]
    local tag = O.WHO_NAME[who]
    if #sel == 0 then say(string.format("%s: nobody to order", tag)); return false end
    O.stats.orders = O.stats.orders + 1
    U.log(string.format("order: %s for %s (%d)", order, tag, #sel))
    if order == "fallin" then
        for _, s in ipairs(sel) do if O.men[s.a] then clear(O.men[s.a]) end end
        if who == "all" then L.on = false; L.only = nil; L.releaseAll("fall in") else
            for _, s in ipairs(sel) do L.drop(s.a) end
        end
        say(tag .. ": fall in")
        return true
    end
    if order == "lead" then
        for _, s in ipairs(sel) do if O.men[s.a] then clear(O.men[s.a]) end end
        if who == "all" then L.only = nil else
            L.only = {}
            for _, s in ipairs(sel) do L.only[s.a] = true end
        end
        L.on = true
        L.releaseAll("new pointmen")
        say(tag .. ": lead the way")
        return true
    end
    if not a or not a.hit then say("No spot there"); return false end
    if order == "cover" then
        local target = a.ally
        if not U.valid(target) then say("Nobody to cover there"); return false end
        local n = 0
        for _, s in ipairs(sel) do
            if U.addr(s.obj) ~= U.addr(target) then
                local m = newMan(s, "cover", now)
                m.coverComp = slotOn(target)
                if m.coverComp then setSlot(m, m.coverComp, target); there(m, now); n = n + 1 else clear(m) end
            end
        end
        say(string.format("%s: cover him (%d)", tag, n))
        return n > 0
    end
    local spots, faces, yaw
    if order == "move" or order == "hold" then
        spots, yaw = spread(a, #sel, cfg().Spread or 150)
        faces = {}
        local arc = cfg().HoldArc or 90
        for i = 1, #sel do faces[i] = yaw + ((#sel > 1) and ((i - 1) / (#sel - 1) - 0.5) * arc or 0) end
    elseif order == "stack" or order == "clear" then
        spots, faces = stackSpots(a, #sel)
    else
        return false
    end
    local rooms = order == "clear" and roomSpots(a) or nil
    for i, s in ipairs(sel) do
        local m = newMan(s, order, now)
        m.face, m.home = faces[i], spots[i]
        if order == "stack" or order == "clear" then
            local c, nx, ny = door(a)
            m.centre = { X = c.X + nx * 120, Y = c.Y + ny * 120, Z = c.Z + 90 } -- in front of the door
        else
            m.centre = { X = a.at.X, Y = a.at.Y, Z = a.at.Z + 90 }
        end
        if rooms and i <= 2 then m.room = rooms[i] end
        m.anchor, m.slot = spawnAnchor(spots[i])
        if m.slot then setSlot(m, m.slot, m.anchor) end
        goTo(m, spots[i], now, order ~= "move")
    end
    O.mark = { at = a.at, text = O.NAME[order], until_ = now + (cfg().MarkSeconds or 2.5), who = who }
    say(string.format("%s: %s", tag, O.NAME[order]:lower()))
    return true
end

-- Orders that wait for your go
function O.queueOrder(order, a, now)
    local sel = O.selected(now, a and a.at)
    O.queue[#O.queue + 1] = { order = order, aim = a, who = O.who, sel = sel }
    say(string.format("%s: %s - on your go (%d waiting)", O.WHO_NAME[O.WHO[O.who]], O.NAME[order]:lower(), #O.queue))
end

function O.go(now)
    local q = O.queue
    O.queue = {}
    local keep = O.who
    for _, x in ipairs(q) do
        O.who = x.who
        O.give(x.order, x.aim, now, x.sel)
        if x.order == "clear" then for _, m in pairs(O.men) do if m.order == "clear" then m.goNow = true end end end
    end
    O.who = keep
    say("GO")
end

-- Gunfire near a watching soldier: it fights (timer running), and goes back to its spot afterwards.
function O.combat(now, pos)
    local range = lcfg().CombatRange or 3000
    for _, m in pairs(O.men) do
        if m.paused then
            local l = U.location(m.obj)
            if not pos or (l and U.dist2(l, pos) <= range) then
                H().setTimer(m.obj, true)
                m.paused = false
                m.fightUntil = now + (lcfg().CombatSeconds or 12)
                if m.phase == "watching" then m.phase = "fighting" end
            end
        end
    end
end

-- Every half second: arrivals, watching, the clear, and soldiers that are gone.
function O.tick(now)
    local c = cfg()
    local inClear, stacked, entered = false, true, 0
    for a, m in pairs(O.men) do
        if not U.alive(m.obj, m.a) or not H().usable(m.obj) then
            clear(m)
        else
            -- the game may put its own slot back (crew update): ours again
            if m.slot and U.valid(m.slot) and U.addr(U.get(m.obj, P.GoalRM, nil)) ~= U.addr(m.slot) then
                pcall(function() m.obj[P.GoalRM] = m.slot; m.obj[P.GoalActor] = m.slotActor end)
            end
            if m.paused and H().timerPaused(m.obj) == false then H().setTimer(m.obj, false) end
            local l = U.location(m.obj)
            if m.phase == "moving" and l and m.lastPos then
                if U.dist2(l, m.lastPos) > 50 then m.lastPos, m.lastMoveAt = l, now
                elseif now - m.lastMoveAt > 4 and m.centre and not m.triedCentre and U.dist2(m.spot, m.centre) > 50 then
                    m.triedCentre = true
                    U.log("orders: " .. tostring(m.a) .. " stuck; to the centre")
                    goTo(m, m.centre, now, m.paused)
                end
            end
            if m.phase == "moving" then
                local st
                local ctl = H().controllerOf(m.obj)
                if ctl then pcall(function() st = ctl:GetMoveStatus() end) end
                local arrived = l and m.spot and U.dist2(l, m.spot) < (c.ArriveRadius or 120)
                if arrived or (st == G.MoveStatus.Idle and now - m.since > 1.0) or now - m.since > (c.MoveTimeout or 12) then
                    if m.order == "move" or m.order == "enter" then there(m, now)
                    elseif now < (m.fightUntil or 0) then m.phase = "fighting"; H().setTimer(m.obj, true); m.paused = false
                    else watch(m, now) end
                end
            elseif m.phase == "fighting" and now > (m.fightUntil or 0) then
                if l and m.spot and U.dist2(l, m.spot) > 200 then goTo(m, m.spot, now, true) else watch(m, now) end
            end
            if m.order == "clear" then
                inClear = true
                if m.phase == "moving" then stacked = false end
            end
            if m.order == "enter" then entered = entered + 1 end
        end
    end
    -- stack & clear: once stacked (or on your go), the first two go in
    if inClear and stacked then
        for _, m in pairs(O.men) do
            if m.order == "clear" and m.room and (m.goNow or now - m.since > (c.ClearAfter or 1.5)) then
                m.order, m.face = "enter", m.room.face
                freeAnchor(m)
                m.anchor, m.slot = spawnAnchor(m.room.spot)
                if m.slot then setSlot(m, m.slot, m.anchor) end
                goTo(m, m.room.spot, now, false)
                O.clearing = { since = now, quietFrom = now }
            elseif m.order == "clear" and not m.room and m.phase == "watching" then
                m.order = "stack" -- the rest cover the doorway
            end
        end
    end
    if O.clearing and entered > 0 then
        local allThere = true
        for _, m in pairs(O.men) do if m.order == "enter" and m.phase == "moving" then allThere = false end end
        if allThere and now - (O.lastShot or 0) > (c.ClearQuiet or 5) and now - O.clearing.since > 3 then
            say("Room clear")
            O.clearing = nil
        end
    end
end

function O.shot(now) O.lastShot = now end

-- After a load or possession (a ship): soldiers still there follow you again.
function O.reset()
    O.clearAll()
    O.queue, O.mark, O.clearing = {}, nil, nil
end

function O.count()
    local n = 0
    for _ in pairs(O.men) do n = n + 1 end
    return n
end

return O
