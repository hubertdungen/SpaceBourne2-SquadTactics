--[[
  "Lead the way": bounding overwatch for your squad (DESIGN.md section 2).

  While the order is on and you are on foot, 1-2 squad soldiers (the pointmen) move ahead of you along
  the way you are going, to a spot against the side of the corridor or room, crouch there and watch
  forward. When you catch up with one, it moves on to the next spot while the other keeps watching:
  they leapfrog ahead of you. The rest of the squad follows you as usual.

  How (verified in game, tests 23 and 23b, 2026-11-08):
    - a pointman's battle timer is paused (as Silent Ops' quiet orders do), so its own logic does not
      pull it back; MoveToLocation with pathfinding failed on the station deck, a straight move worked
      (8 m in 5 s), so pathfinding is tried first and the straight line second;
    - facing: ALS looking-direction mode + actor and control rotation: held its heading;
    - spots: line traces, one reused out table cleared before each call (a second call with the
      filled table failed); at most three traces per move (ahead, side, and the straight line when
      there is no path).
  Any gunfire near you (yours, the squad's, an NPC's within Lead.CombatRange) hands the pointmen back
  to the game's own combat AI for Lead.CombatSeconds.
]]

local U = require("st.util")
local G = require("st.gamedefs")
local P = G.P

local L = { on = true, men = {}, squad = {}, scanAt = -1e9, combatUntil = 0, player = nil, playerA = nil,
    traceFresh = false, stats = { ticks = 0, time = 0, max = 0, moves = 0, traces = 0 } }

local function cfg() return SQUAD_TACTICS.cfg.Lead end

local KSL
local function ksl()
    if not U.valid(KSL) then KSL = StaticFindObject(G.KismetSystem) end
    return U.valid(KSL) and KSL or nil
end

local function controllerOf(a)
    local c = U.get(a, "Controller", nil)
    if U.valid(c) then return c end
    return nil
end

-- The soldier's battle logic timer: paused while it is a pointman (as Silent Ops does).
local function setTimer(sol, running)
    local lib = ksl()
    if not lib then return end
    pcall(function()
        local h = { Handle = sol[P.MainTimer].Handle }
        if running then lib:K2_UnPauseTimerHandle(sol, h) else lib:K2_PauseTimerHandle(sol, h) end
    end)
end

local function usable(sol)
    return U.valid(sol) and U.get(sol, P.Dead, false) ~= true and U.get(sol, P.Injured, false) ~= true
end

-- Line trace from a to b: the distance to the first hit (cm), false if clear, nil if the trace failed.
-- One reused OutHit table, cleared before each call (UE4SS 3.0.1 keeps every table passed as an out
-- parameter; and a second call with the filled table failed in test 23b). If even that fails, a new
-- table per call (traces are rare: at most two per move).
local HIT = {}
local WHITE = { R = 1, G = 1, B = 1, A = 1 }
local function trace(a, b)
    local lib = ksl()
    if not lib or not U.valid(L.player) then return nil end
    local out = HIT
    if L.traceFresh then out = {} else for k in pairs(HIT) do HIT[k] = nil end end
    L.stats.traces = L.stats.traces + 1
    local ok, hit = pcall(function()
        return lib:LineTraceSingle(L.player, a, b, 0, false, {}, 0, out, true, WHITE, WHITE, 0.0)
    end)
    if not ok and not L.traceFresh then
        L.traceFresh = true
        U.warn("reused trace table refused; using a new one per trace")
        return trace(a, b)
    end
    if not ok then return nil end
    if hit ~= true then return false end
    local d
    pcall(function() d = out.Distance end)
    return type(d) == "number" and d or false
end

-- You, on foot (nil in a ship or a menu).
local function playerOnFoot()
    if not U.valid(L.pc) then
        L.pc = FindFirstOf(G.Controller)
        if not U.valid(L.pc) then return nil end
    end
    local p = U.get(L.pc, "Pawn", nil)
    if not U.valid(p) or U.className(p) ~= G.PlayerClass then return nil end
    return p
end

-- Where you are heading: your movement if you move, else where you look.
local function heading(p)
    local v
    pcall(function() local x = p:GetVelocity(); v = { X = x.X, Y = x.Y } end)
    if v then
        local l = math.sqrt(v.X * v.X + v.Y * v.Y)
        if l > 80 then return { X = v.X / l, Y = v.Y / l } end
    end
    local yaw
    local c = controllerOf(p)
    if c then pcall(function() yaw = c:GetControlRotation().Yaw end) end
    if not yaw then pcall(function() yaw = p:K2_GetActorRotation().Yaw end) end
    if not yaw then return nil end
    return { X = math.cos(math.rad(yaw)), Y = math.sin(math.rad(yaw)) }
end

local function release(m)
    if U.alive(m.obj, m.a) then
        setTimer(m.obj, true)
        pcall(function() m.obj:UnCrouch(false) end)
        if m.rot ~= nil then pcall(function() m.obj:SetRotationMode(m.rot) end) end
        local c = controllerOf(m.obj)
        if c then pcall(function() c:StopMovement() end) end
    end
end

function L.releaseAll(why)
    if #L.men > 0 then U.log("pointmen released: " .. tostring(why)) end
    for _, m in ipairs(L.men) do release(m) end
    L.men = {}
end

-- Squad list: one FindAllOf (~50 ms), only when needed and at most every Lead.ScanSeconds.
local function scan(now)
    if now < L.scanAt then return end
    L.squad = {}
    for _, s in ipairs(FindAllOf(G.SquadShort) or {}) do
        if U.valid(s) then L.squad[#L.squad + 1] = { obj = s, a = U.addr(s) } end
    end
    -- right after a load the squad may not be there yet: look again soon (a few times), then rarely
    L.empty = (#L.squad == 0) and (L.empty or 0) + 1 or 0
    L.scanAt = now + ((L.empty > 0 and L.empty <= 4) and 5 or (cfg().ScanSeconds or 20))
    U.log("squad scan: " .. #L.squad)
end

local function isMan(a)
    for _, m in ipairs(L.men) do if m.a == a then return true end end
    return false
end

-- Pick pointmen: the nearest usable soldiers that are not pointmen yet.
local function recruit(now, pos)
    local want = math.max(1, math.min(2, cfg().Pointmen or 2))
    if #L.men >= want then return end
    local best = {}
    for _, s in ipairs(L.squad) do
        if U.alive(s.obj, s.a) and usable(s.obj) and not isMan(s.a) then
            local l = U.location(s.obj)
            if l then best[#best + 1] = { s = s, d = U.dist2(l, pos) } end
        end
    end
    if #best == 0 and #L.squad > 0 then L.scanAt = math.min(L.scanAt, now + 5) end
    table.sort(best, function(x, y) return x.d < y.d end)
    for i = 1, math.min(#best, want - #L.men) do
        local s = best[i].s
        local m = { obj = s.obj, a = s.a, state = "idle", since = now, side = (#L.men == 0) and -1 or 1,
            rot = U.get(s.obj, P.RotationMode, nil) }
        if type(m.rot) ~= "number" then m.rot = nil end
        setTimer(m.obj, false)
        L.men[#L.men + 1] = m
        U.log(string.format("pointman %d: %s", #L.men, tostring(s.a)))
    end
end

-- The next spot for a pointman: Lead.Distance ahead of you (shortened before a wall), then against the
-- side of the corridor on its side (Lead.SideOffset if there is no wall within Lead.SideSearch).
local function spotFor(m, pos, H, lead)
    local c = cfg()
    local R = { X = -H.Y * m.side, Y = H.X * m.side }
    local eye = { X = pos.X, Y = pos.Y, Z = pos.Z + 40 }
    local h = trace(eye, { X = eye.X + H.X * lead, Y = eye.Y + H.Y * lead, Z = eye.Z })
    if h == nil then return nil end
    if h then lead = h - (c.WallGap or 80) end
    if lead < (c.MinLead or 250) then return nil end -- a wall right ahead: nowhere to go
    local base = { X = eye.X + H.X * lead, Y = eye.Y + H.Y * lead, Z = eye.Z }
    local s = trace(base, { X = base.X + R.X * (c.SideSearch or 400), Y = base.Y + R.Y * (c.SideSearch or 400), Z = base.Z })
    local off = c.SideOffset or 150
    local cover = false
    if s then off, cover = math.max(0, s - (c.WallGap or 80)), true end
    return { X = base.X + R.X * off, Y = base.Y + R.Y * off, Z = pos.Z }, cover
end

local function moveTo(m, spot, now, run)
    local c = controllerOf(m.obj)
    if not c then return false end
    local r = -1
    pcall(function() r = c:MoveToLocation(spot, 60.0, true, true, true, false, nil, true) end)
    if r ~= G.Move.Success and r ~= G.Move.AlreadyAtGoal then
        -- no path here (station decks, test 23): a straight move (test 23b), but only as far as the line
        -- from the pointman to the spot is clear, so it does not walk into a corner
        local from = U.location(m.obj)
        if not from then return false end
        local a = { X = from.X, Y = from.Y, Z = from.Z + 40 }
        local h = trace(a, { X = spot.X, Y = spot.Y, Z = a.Z })
        if h == nil then return false end
        if h then
            local len = U.dist2(from, spot)
            local keep = h - (cfg().WallGap or 80)
            if keep < 150 or len < 1 then return false end
            spot = { X = from.X + (spot.X - from.X) * keep / len, Y = from.Y + (spot.Y - from.Y) * keep / len, Z = spot.Z }
        end
        pcall(function() r = c:MoveToLocation(spot, 60.0, true, false, false, false, nil, true) end)
    end
    if r ~= G.Move.Success and r ~= G.Move.AlreadyAtGoal then return false end
    pcall(function() m.obj:UnCrouch(false) end)
    pcall(function() m.obj:SetDesiredGait(run and G.Gait.Running or G.Gait.Walking) end)
        m.state, m.spot, m.since = "moving", spot, now
    m.leapFrom = U.location(L.player)
    L.stats.moves = L.stats.moves + 1
    return true
end

-- At the spot: crouch and watch along your heading.
local function hold(m, H, now)
    m.state, m.since = "holding", now
    if cfg().Crouch ~= false then pcall(function() m.obj:Crouch(false) end) end
    local yaw = math.deg(math.atan(H.Y, H.X))
    pcall(function() m.obj:SetRotationMode(G.LookingDirection) end)
    pcall(function() m.obj:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false) end)
    local c = controllerOf(m.obj)
    if c then pcall(function() c:SetControlRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }) end) end
end

-- Gunfire near you: the squad fights the game's way for a while.
function L.combat(now, pos)
    if pos and L.player and U.valid(L.player) then
        local me = U.location(L.player)
        if me and U.dist2(me, pos) > (cfg().CombatRange or 5000) then return end
    end
    L.combatUntil = now + (cfg().CombatSeconds or 12)
    if #L.men > 0 then L.releaseAll("gunfire") end
end

function L.tick(now)
    local t0 = os.clock()
    local c = cfg()
    local p = playerOnFoot()
    L.player = p
    if not L.on or not p or now < L.combatUntil then
        if #L.men > 0 then L.releaseAll(not L.on and "order off" or (not p and "not on foot") or "combat") end
        return
    end
    local pos, H = U.location(p), heading(p)
    if not pos or not H then return end
    -- keep only usable pointmen near you
    local keep = {}
    for _, m in ipairs(L.men) do
        local l = U.alive(m.obj, m.a) and usable(m.obj) and U.location(m.obj) or nil
        if l and U.dist2(l, pos) < (c.MaxRange or 4000) then keep[#keep + 1] = m else release(m) end
    end
    L.men = keep
    if #L.men < math.max(1, math.min(2, c.Pointmen or 2)) then
        scan(now)
        recruit(now, pos)
    end
    -- one pointman moves at a time; the other watches
    local moving = false
    for _, m in ipairs(L.men) do
        if m.state == "moving" then
            local l = U.location(m.obj)
            local arrived = l and m.spot and U.dist2(l, m.spot) < (c.ArriveRadius or 120)
            local st
            local ctl = controllerOf(m.obj)
            if ctl then pcall(function() st = ctl:GetMoveStatus() end) end
            if arrived or (st == G.MoveStatus.Idle and now - m.since > 1.0) or now - m.since > (c.MoveTimeout or 8) then
                hold(m, H, now)
            else
                moving = true
            end
        end
    end
    if not moving then
        -- the pointman you have caught up with (least ahead of you) moves on
        local pick, least
        for _, m in ipairs(L.men) do
            local l = U.location(m.obj)
            if l then
                local ahead = (l.X - pos.X) * H.X + (l.Y - pos.Y) * H.Y
                                -- moves on only once you have moved since its last move (one that stopped short of its
                -- spot, blocked or timed out, would otherwise move again and again while you stand)
                local youMoved = not m.leapFrom or U.dist2(pos, m.leapFrom) > (c.YouMoved or 200)
                if (m.state == "idle" or (ahead < (c.LeapWhenAhead or 350) and youMoved)) and (not least or ahead < least) then
                    pick, least = m, ahead
                end
            end
        end
        if pick and now - pick.since > (c.MinHoldSeconds or 1.5) or (pick and pick.state == "idle") then
            local i = 0
            for k, m in ipairs(L.men) do if m == pick then i = k end end
            local lead = (i <= 1) and (c.Distance or 900) or (c.SecondDistance or 600)
            -- the other pointman may already be ahead: leapfrog past it
            for _, m in ipairs(L.men) do
                if m ~= pick then
                    local l = U.location(m.obj)
                    if l then
                        local ahead = (l.X - pos.X) * H.X + (l.Y - pos.Y) * H.Y
                        if ahead + (c.Leapfrog or 400) > lead then lead = ahead + (c.Leapfrog or 400) end
                    end
                end
            end
            lead = math.min(lead, c.MaxLead or 1600)
            local spot, cover = spotFor(pick, pos, H, lead)
            local speed = 0
            pcall(function() local v = p:GetVelocity(); speed = math.sqrt(v.X * v.X + v.Y * v.Y) end)
            if spot and moveTo(pick, spot, now, speed > (c.RunAbove or 250) or pick.state == "idle") then
                U.log(string.format("pointman %s moves %.1f m ahead (%s)", tostring(pick.a), lead / 100, cover and "against a wall" or "open side"))
            else
                pick.since = now -- try again later
            end
        end
    end
    local dt = os.clock() - t0
    local s = L.stats
    s.ticks, s.time = s.ticks + 1, s.time + dt
    if dt > s.max then s.max = dt end
end

function L.toggle()
    L.on = not L.on
    if not L.on then L.releaseAll("order off") end
    return L.on
end

-- After a load or possession: the old soldiers are gone.
function L.reset()
    L.men, L.squad, L.scanAt, L.pc, L.empty = {}, {}, os.clock() + 3, nil, 0
end

function L.report()
    local s = L.stats
    local r = string.format("lead: %d ticks avg %.2f ms max %.2f ms, %d moves, %d traces, %d pointmen, on=%s",
        s.ticks, s.ticks > 0 and s.time / s.ticks * 1000 or 0, s.max * 1000, s.moves, s.traces, #L.men, tostring(L.on))
    L.stats = { ticks = 0, time = 0, max = 0, moves = 0, traces = 0 }
    return r
end

return L
