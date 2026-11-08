--[[ Every game-internal name Squad Tactics uses: after a game update, this is the file to check. ]]

local G = {}

G.SquadShort   = "Q1_GroundSquad_C"                                          -- your ground squad soldiers
G.PlayerClass  = "Q1_Character_C"                                            -- you, on foot
G.Controller   = "Q1Controller_C"                                            -- your player controller
G.Shooter      = "/Game/1Data/11_AI/Q1_Shooter_AI.Q1_Shooter_AI_C"            -- every on-foot NPC with a gun
G.Soldier      = "/Game/1Data/11_AI/BattleAI/Master_Soldier.Master_Soldier_C" -- squad and battle soldiers
G.HandWeapon   = "/Game/1Data/Weapons/Hand_Weapons/Weapons/Master_Hand_Weapon.Master_Hand_Weapon_C"
G.KismetSystem = "/Script/Engine.Default__KismetSystemLibrary"
G.TargetPoint  = "/Script/Engine.TargetPoint"                                 -- our order anchors
G.ChildActor   = "/Script/Engine.ChildActorComponent"                         -- the slot on an anchor
G.Font         = "/Engine/EngineFonts/Roboto.Roboto"
G.DrawHUD      = "/Game/1Data/Q1Hud.Q1Hud_C:ReceiveDrawHUD"                    -- the HUD canvas, each frame
-- door Blueprints (DungeonFlow interior doors, dungeon gates): aiming at one offers "Stack up" first
G.Doors = { DoorBase_C = true, New_Door_C = true, New_DoorSalvage_C = true, OneWayDoor_C = true,
    New_OneWayDoor_C = true, Door_1_C = true, Door_2_C = true, Door_3_C = true, Door_4_C = true,
    EBP_LockDoor_C = true, Q1_DungeonDoor_C = true, C_SpaceDungeonDoor_C = true, C_CampTypeDoor_C = true,
    C_Cave_TypeDoor_C = true, C_SalvageTypeDoor_C = true }

-- Fire events: any of them near you means a fight, and the squad goes back to the game's own combat AI.
G.Fn = {
    NpcShot     = G.Shooter .. ":JustShoot",           -- every shot of an on-foot NPC
    PlayerShot  = G.HandWeapon .. ":SpawnProjectile",  -- your projectile guns
    PlayerBeam  = G.HandWeapon .. ":ActiveBeam1",      -- your beam weapons
    SquadShot   = G.Soldier .. ":BattleShoot",
    SquadPistol = G.Soldier .. ":PistolShot",
}

G.P = {
    MainTimer    = "MainTimer",      -- the soldier's battle logic timer (FTimerHandle); paused while we lead
    Dead         = "NPCDead",
    Injured      = "InInjuredMode",
    RotationMode = "RotationMode",   -- ALS: 0 velocity direction, 1 looking direction, 2 aiming
    Target       = "C_Target",       -- the soldier's current target (Master_Soldier)
    CrewIndex    = "Crew Index",     -- the soldier's place in your crew (teams are split by it)
    GoalRM       = "GoalRM",         -- the formation slot it follows (a ChildActorComponent on you)
    GoalActor    = "GoalActor",      -- that slot's actor
}

-- AIController:MoveToLocation result (EPathFollowingRequestResult)
G.Move = { Failed = 0, AlreadyAtGoal = 1, Success = 2 }
-- PathFollowingComponent status (EPathFollowingStatus)
G.MoveStatus = { Idle = 0, Waiting = 1, Paused = 2, Moving = 3 }
G.Gait = { Walking = 0, Running = 1, Sprinting = 2 }
G.LookingDirection = 1

return G
