--[[
  The order key (DESIGN.md section 8.2):
    Z tap      the order that fits what you aim at (floor: move here; door: stack up; your soldier:
               cover him; nothing: fall in); with orders waiting: GO
    Z hold     the order list at the aimed spot; mouse up/down picks the order, left/right who gets it
               (the view holds still meanwhile); let go of Z to give it
    0          who: all, red, blue, the one or two nearest the spot
    0 + Z held the order waits for your go
  A held key is read with PlayerController:IsInputKeyDown (as Silent Ops' Shift guard), only while Z
  is down. Drawn on the HUD canvas (post-hook of Q1Hud_C:ReceiveDrawHUD, as Ground Waypoints):
  nothing at all unless Z is down or an order was just given.
]]

local U = require("st.util")
local G = require("st.gamedefs")
local O = require("st.orders")
local L = require("st.lead")

local M = { down = false, open = false, items = {}, idx = 1, queued = false, font = nil, fontTried = false }

local function cfg() return SQUAD_TACTICS.cfg.Orders end

local ZKEY
local function keyDown(pc)
    if not ZKEY then
        local ok, k = pcall(function() return { KeyName = FName(M.keyName or "Z") } end)
        if not ok then return nil end
        ZKEY = k
    end
    local ok, d = pcall(function() return pc:IsInputKeyDown(ZKEY) end)
    if not ok or type(d) ~= "boolean" then return nil end
    return d
end

local function wrap180(d)
    d = (d + 180) % 360 - 180
    return d
end

-- Z pressed (key bind, on the game thread)
function M.press(now)
    if M.down then return end -- key repeat while held
    local p = L.h.playerOnFoot()
    if not p then return end
    L.player = p
    local pc = L.pc
    if not U.valid(pc) then return end
    M.down, M.at, M.open, M.queued = true, now, false, false
    M.aim = O.aim(pc, p)
    M.items, M.def = O.menuFor(M.aim)
    M.idx = 1
    U.log(string.format("key: Z down (fits: %s; list: %s)", tostring(M.def), table.concat(M.items, ",")))
end

-- 0 pressed
function M.who(now)
    if M.down then
        M.queued = not M.queued
        U.log("key: 0 with Z held: on your go = " .. tostring(M.queued))
        return
    end
    U.log("key: 0")
    O.cycleWho(now)
end

local function give(id, now)
    if id == "go" then O.go(now); return end
    if M.queued then O.queueOrder(id, M.aim, now) else O.give(id, M.aim, now) end
end

local function release(now)
    M.down = false
    U.log(string.format("key: Z up after %.2f s, list %s, picked %s", now - (M.at or now), M.open and "open" or "closed",
        tostring(M.open and M.items[M.idx] or (#O.queue > 0 and not M.queued and "go") or M.def)))
    if M.demoUntil then -- scripted test: the list was only shown
        M.demoUntil, M.open = nil, false
        return
    end
    if M.open then
        M.open = false
        give(M.items[M.idx], now)
    elseif #O.queue > 0 and not M.queued then
        O.go(now)
    else
        give(M.def, now)
    end
end

-- The view holds still while the list is up; the mouse moves the highlight instead.
local function steer(pc)
    local r
    pcall(function() local x = pc:GetControlRotation(); r = { Pitch = x.Pitch, Yaw = x.Yaw } end)
    if not r or not M.frozen then return end
    local dp, dy = wrap180(r.Pitch - M.frozen.Pitch), wrap180(r.Yaw - M.frozen.Yaw)
    if dp ~= 0 or dy ~= 0 then pcall(function() pc:SetControlRotation(M.frozen) end) end
    local step = cfg().MenuStep or 3
    M.accP = math.max(-(#M.items - 0.5) * step, math.min(0.5 * step, M.accP + dp))
    M.idx = math.max(1, math.min(#M.items, 1 + math.floor(-M.accP / step + 0.5)))
    M.accY = M.accY + dy
    local side = step * 2.5
    if math.abs(M.accY) > side then
        local n = #O.WHO
        O.who = (O.who - 1 + (M.accY > 0 and 1 or -1)) % n + 1
        M.accY = 0
    end
end

local function openList(pc, now)
    U.log("key: Z held: list open")
    M.open = true
    M.accP, M.accY = 0, 0
    pcall(function() local x = pc:GetControlRotation(); M.frozen = { Pitch = x.Pitch, Yaw = x.Yaw, Roll = 0 } end)
end

-- Each frame (HUD draw): Z still down? then the list, steering and drawing.
function M.frame(hud, w, h, now)
    if M.down then
        local pc = L.pc
        local d = U.valid(pc) and keyDown(pc) or nil
        if M.demoUntil then d = now < M.demoUntil end
        if d == nil then
            release(now) -- cannot read the key: a tap
        elseif d then
            if not M.open and now - M.at >= (cfg().HoldTime or 0.25) then openList(pc, now) end
            if M.open then steer(pc) end
        else
            release(now)
        end
    end
    if not M.down and not (O.mark and now < O.mark.until_) and #O.queue == 0 then return end
    M.draw(hud, w, h, now)
end

local function text(hud, s, col, x, y, scale)
    hud:DrawText(s, col, x, y, M.font, scale, false)
end

local DIM, WHITE, BG = { R = 0.72, G = 0.72, B = 0.72, A = 1 }, { R = 1, G = 1, B = 1, A = 1 }, { R = 0, G = 0, B = 0, A = 0.55 }

local function project(hud, at)
    local s
    pcall(function() local v = hud:Project(at); s = { X = v.X, Y = v.Y, Z = v.Z } end)
    if s and s.Z > 0 then return s end
    return nil
end

local function cross(hud, at, col, label, sc)
    local s = project(hud, at)
    if not s then return end
    hud:DrawRect(col, s.X - 12 * sc, s.Y - 2 * sc, 24 * sc, 4 * sc)
    hud:DrawRect(col, s.X - 2 * sc, s.Y - 12 * sc, 4 * sc, 24 * sc)
    if label then text(hud, label, col, s.X + 16 * sc, s.Y - 12 * sc, 1.0 * sc) end
end

function M.draw(hud, w, h, now)
    if not M.fontTried then M.fontTried = true; M.font = StaticFindObject(G.Font) end
    local sc = h / 1080
    local who = O.WHO[O.who]
    local col = O.COLOR[who]
    pcall(function()
        if M.down and M.aim and M.aim.hit then
            cross(hud, M.aim.at, col, M.open and nil or O.NAME[M.def], sc)
        end
        if M.open then
            local x, y = w / 2 + 70 * sc, h / 2 - 60 * sc
            local lh = 30 * sc
            hud:DrawRect(BG, x - 12 * sc, y - 44 * sc, 270 * sc, (#M.items * 30 + 56) * sc)
            local n = #O.selected(now, M.aim and M.aim.at)
            text(hud, string.format("<  %s (%d)  >%s", O.WHO_NAME[who], n, M.queued and "   on your go" or ""), col, x, y - 38 * sc, 1.25 * sc)
            for i, id in ipairs(M.items) do
                local on = i == M.idx
                text(hud, (on and "> " or "   ") .. O.NAME[id], on and WHITE or DIM, x, y + (i - 1) * lh, (on and 1.3 or 1.15) * sc)
            end
            -- the selected soldiers: a dot in the team's colour over each
            for _, s in ipairs(O.selected(now, M.aim and M.aim.at)) do
                local l = U.location(s.obj)
                if l then
                    local p = project(hud, { X = l.X, Y = l.Y, Z = l.Z + 120 })
                    if p then hud:DrawRect(col, p.X - 5 * sc, p.Y - 5 * sc, 10 * sc, 10 * sc) end
                end
            end
        end
        if not M.down and O.mark and now < O.mark.until_ then
            cross(hud, O.mark.at, O.COLOR[O.mark.who] or col, O.mark.text, sc)
        end
        if #O.queue > 0 then
            text(hud, string.format("%d order%s waiting  -  Z: GO", #O.queue, #O.queue > 1 and "s" or ""), O.COLOR.all,
                w / 2 - 140 * sc, h * 0.16, 1.2 * sc)
        end
    end)
end

function M.reset()
    M.down, M.open, M.demoUntil = false, false, nil
end

-- scripted tests: the list up for some seconds without giving anything
function M.demo(now, secs)
    M.press(now)
    if M.down then M.demoUntil = now + secs end
end

return M
