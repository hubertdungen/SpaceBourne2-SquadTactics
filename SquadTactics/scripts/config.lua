--[[
  Squad Tactics - your settings. Edit with any text editor, then restart the game.
  Every line is optional: delete one and the default is used. Distances in cm (100 = 1 m).
]]

return {
    Enabled = true,

    -- "Lead the way": 1-2 soldiers of your ground squad move ahead of you to the next spot against the
    -- side of the corridor, crouch and watch forward, and leapfrog on as you catch up.
    Lead = {
        StartOn        = true,   -- the order is on when the game starts
        Key            = "",     -- a key that switches it on / off ("" = none; "Lead the way" and "Fall in" are in the order list)
        Pointmen       = 2,      -- 1 or 2 soldiers lead; the rest of the squad follows you as usual
        Distance       = 900,    -- how far ahead of you the leading pointman goes
        SecondDistance = 600,    -- ...and the second one
        Leapfrog       = 400,    -- a pointman that moves on goes this far past the other one
        MaxLead        = 1600,   -- never farther ahead than this
        MinLead        = 250,    -- a wall closer than this ahead: they wait
        LeapWhenAhead  = 350,    -- you are this close behind a pointman: it moves on...
        YouMoved       = 200,    -- ...once you have moved this far since its last move
        MinHoldSeconds = 1.5,    -- a pointman watches at least this long before moving on
        RetrySeconds   = 2,      -- no spot found (a wall right ahead): tries again after this
        SideOffset     = 150,    -- off your line, to its side, when there is no wall to hug
        SideSearch     = 400,    -- how far to the side a wall is looked for
        WallGap        = 80,     -- distance kept from walls
        ArriveRadius   = 120,
        MoveTimeout    = 8,      -- seconds; a pointman that cannot get there stops and watches
        RunAbove       = 250,    -- cm/s: when you move faster, they run to the next spot
        Crouch         = true,   -- crouch at the spot
        MaxRange       = 4000,   -- a pointman farther than this from you goes back to the squad
        CombatRange    = 3000,   -- gunfire this close to you or a pointman (a squad soldier's: its target)...
        CombatSeconds  = 12,     -- ...hands the pointmen back to the game's combat AI for this long
        TickSeconds    = 0.5,
        ScanSeconds    = 20,     -- the squad list is refreshed at most this often
        FloorHeight    = 350,    -- a pointman this far above or below you (another floor) goes back to the squad
    },

    -- Squad orders, Ready-or-Not style: aim at a spot, tap Z for the order that fits it, or hold Z for the
    -- list (mouse up/down picks, left/right picks who; let go to give it). 0 picks who gets the order.
    Orders = {
        Enabled        = true,
        Key            = "Z",    -- tap: the fitting order; hold: the list (Shift+Z works too, while you sprint)
        WhoKey         = "0",    -- all -> red -> blue -> the one -> the two soldiers nearest the spot; with Z held: the order waits for your go
        HoldTime       = 0.25,   -- seconds Z is held before the list comes up
        MenuStep       = 3,      -- degrees of mouse movement per line of the list
        RedSize        = 2,      -- soldiers in the red team (by crew order); the rest are blue
        Range          = 5000,   -- how far you can give an order (cm)
        Spread         = 150,    -- room between soldiers at a spot
        HoldArc        = 90,     -- degrees the soldiers holding a spot share between them
        DoorHalfWidth  = 110,    -- from the middle of a door to where the stack starts
        Crouch         = true,   -- crouch when holding or stacked
        ArriveRadius   = 120,
        MoveTimeout    = 12,     -- seconds; a soldier that cannot get to its spot stops and holds
        ClearAfter     = 1.5,    -- Stack & clear: seconds stacked before the first two go in
        ClearQuiet     = 5,      -- seconds without gunfire before "Room clear"
        MarkSeconds    = 2.5,    -- the marker stays this long on the spot after an order
    },

    Messages = true,             -- short HUD line when the order is switched

    Debug = {
        Log = false,             -- write Mods\SquadTactics\squadtactics.log
        Commands = false,        -- testing only: Mods\SquadTactics\debug_cmd.txt can say "toggle"
    },
}
