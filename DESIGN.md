# Squad Tactics — design notes

## 1. The idea (the user, 2026-11-08)

> "nas patrulhas e avanços os amigos (e inimigos) avançarem por exemplo num corredor um deles ou 2 e
> cobrirem-se atrás duma porta ou barricada ou objeto olhando para fora e sempre atento, abrindo
> caminho à medida que o player avança, isto sob ordens prévias de que podem fazer isto claro"

More orders wanted: only 1-2 advance; teams or everyone move to a point; patrol; shoot the downed;
investigate a room or an area; cover me or my friends; all varying with each soldier's training.

0.1.0 ships the first one, **Lead the way**. The rest is planned below (sections 4-5).

## 2. Lead the way (0.1.0)

- **Pointmen:** the 1-2 nearest usable soldiers of `Q1_GroundSquad_C` (not dead, not in injured
  mode). The squad list comes from one `FindAllOf` (about 100 ms, measured), only when pointmen are
  missing: right after a load every 5 s up to four times while the squad is not there yet, then at
  most every `ScanSeconds`.
- **Taking control:** while a pointman moves to its spot and watches there, the soldier's battle
  logic timer (`MainTimer`) is paused with `KismetSystemLibrary.K2_PauseTimerHandle`, as Silent Ops'
  quiet orders do; otherwise its own logic pulls it back to you. The pause is checked every tick
  (`K2_IsTimerPausedHandle`) and set again if the game restarted the timer. A pointman with no spot to
  go to (no spot twice in a row, or a move that failed) runs the game's logic again: it follows you
  and fights until it gets a spot (0.1.1; 0.1.0 left it paused, standing still: the dungeon report).
  Released: timer running, uncrouched, ALS rotation mode restored, movement stopped.
- **Heading:** your velocity when you move, else your control rotation.
- **Spot:** `Distance` (900) ahead for the first pointman, `SecondDistance` (600) for the second, or
  `Leapfrog` (400) past the other pointman, at most `MaxLead`. Trace 1 along your heading: a wall
  closer than that shortens the spot to the wall minus `WallGap`, and closer than `MinLead` means
  wait. Trace 2 to the pointman's side (first left, second right) up to `SideSearch`: a wall there
  puts the spot against it (minus `WallGap`), else `SideOffset` off your line.
- **Traces** (0.1.1): visibility channel. A hit within 75 cm of a squad soldier is that soldier: the
  trace goes on 90 cm past it (up to three times), so your squad crowding a corridor is not taken for
  a wall (test 27: a soldier 1 m ahead stopped the visibility and camera channels alike; 0.1.0 then
  found "a wall right ahead" and waited, paused). Tracing by object type (`LineTraceSingleForObjects`
  with WorldStatic + WorldDynamic) never hit anything, not even corridor walls: UE4SS 3.0.1 does not
  pass the array of object types.
- **Move:** `AIController.MoveToLocation(spot, 60, ..., bUsePathfinding = true, project = true)`;
  when that fails (result 0), a path half way there; then the same without pathfinding: a straight
  move. Gait running when you move faster than `RunAbove`, else walking.
- **Hold:** arrived within `ArriveRadius`, or the move stopped, or `MoveTimeout`: crouch, ALS looking
  direction, actor and control rotation set to your heading.
- **Leapfrog:** one pointman moves at a time. The one least ahead of you moves on when it is less
  than `LeapWhenAhead` ahead (you caught up, or you turned), it has held `MinHoldSeconds`, and you
  moved `YouMoved` since its last move (without that, one that stopped short of its spot moved
  again and again while you stood: test 24).
- **Fights:** releases the pointmen for `CombatSeconds`: your shots; an NPC's shot from within
  `CombatRange` (3000) of you or a pointman; a squad soldier's shot (`BattleShoot`, `PistolShot`) at a
  target (`C_Target`) that close. The game calls `BattleShoot` every 1.5 s while a soldier sees a
  target, however far: 0.1.0 counted those at any range, and in a dungeon full of creatures the
  pointmen hardly ever led.
- **Floors:** a pointman more than `FloorHeight` (350) above or below you goes back to the squad.
- **Squad list:** read again (one `FindAllOf`, about 50 ms) only when nobody usable is left on it;
  0.1.0 read it every time the pointmen came back after a fight (a visible hitch, test 27).
- **Off foot** (ship, hoverbike, menus) or the order off: pointmen released.

### Verified in game (2026-11-08)

- Test 23: `MoveToLocation` with pathfinding returned 0 (Failed) for squad soldiers on the station
  deck; a paused soldier did not move. `K2_SetFocalPoint` alone left it 43 degrees off. Crouch works.
- Test 23b: the controller is `QQ_ALSAIController`; the soldier's `GoalActor` is you. A straight
  `MoveToLocation` (no pathfinding) returned 2 and walked 8.1 m in 5 s. ALS looking direction +
  actor and control rotation: 0 degrees off 3 s later. A line trace worked, but a second one with the
  same filled out table failed: the table is now cleared before each call.
- Test 24: two pointmen out of a squad of four, leapfrogging 6-9 m ahead as you stepped forward,
  "against a wall" or "open side" as expected; traces with the cleared table worked; 0.4-0.7 ms per
  tick (every 0.5 s), the squad scan about 100 ms once.
- Tests 27-29 (0.1.1, station corridor, the squad teleported in a crowd 1-3 m in front of you): the
  pointmen led along the corridor and back, against the walls, past soldiers in the trace, 0 failed
  moves; an enemy shot 18 m away released them and they led again 12 s later without a squad scan;
  0.4-0.6 ms a tick. A dungeon could not be reached by script: the test level's space dungeon door
  (`C_SpaceDungeonDoor_C`, role 0) ran `Interacting` but no dungeon loaded.

## 3. Costs and UE4SS 3.0.1 rules

- Timed work only through the set's `gametick.lua` (HUD draw + ALS tick); no LoopAsync or
  ExecuteWithDelay (UE4SS.dll+0x87c104 crash).
- `LineTraceSingle` has an out parameter: one reused table, cleared before each call, at most two
  traces per move. No other out-parameter calls (`K2_SetActorRotation`, `MoveToLocation`,
  `SetControlRotation` have none).
- `IsValid` before every call on an object; references kept across ticks are checked by address.

## 4. Planned orders (not in 0.1.0)

| Order | How | Needs |
|---|---|---|
| Hold & cover me | the squad stops, crouches and faces outward around you (sectors split by count) | facing (verified), spots on a circle with traces |
| 1-2 advance to where you look | your view point (the camera's aim trace) becomes the spot | aim trace (out param: reused table) |
| Team / everyone to a point | as above for the whole squad, spread around the point | spreading spots |
| Patrol | a loop of points you set (key on each), walked while no fight | point list per squad |
| Investigate a room | 2 soldiers go to the room's middle and back | ties in with Silent Ops' search logic |
| Finish the downed | shoot knocked-out enemies (HTR 0.4.15 bleed-out knockouts) | HTR's downed state, a fire call |
| Cover friends | as cover me, around a squad mate or ally | the friend's position |

Training should vary each: elite soldiers move faster between spots and hold a wider arc; militia
hesitate (`MinHoldSeconds` longer) and pick worse spots (fewer traces).

## 5. The enemy side (planned)

Enemy patrol groups that leapfrog the same way: a group of 2-4 `Q1_Shooter_AI_C` that walk together
picks a lead; quality by HTR's training tier (Pirate / Militia / Regular / Elite: more pointmen, longer
holds, better spots). Only out of combat, only for groups near you (cost), handed back to the game's
combat AI on the first shot. Silent Ops' awareness stays in charge of who sees you.

## 6. Keys

0.1.0: `0` (plain zero) switches Lead the way on and off. It is free in the set's key plan (Ground
Waypoints only suggests it as an optional toggle; Shift+0 is Ammo Discipline's and stays quiet, UE4SS
matches modifiers exactly). 0.2.0 changes the keys: see section 8.2.

## 7. Pathfinding on the station deck (open question, 2026-11-08)

- Squad soldiers: `MoveToLocation` with pathfinding returned 0 on the test save's station deck, with
  and without projecting the goal; a straight move worked. Silent Ops' investigation and Get Out of
  the Way's side steps use the same call with pathfinding on enemy and station NPCs and work there
  (Get Out of the Way also measures the path with `FindPathToLocationSynchronously`).
- Candidates: no navigation mesh on that deck (it is a landing pad outside), a nav agent of the
  squad soldiers that the mesh does not support, or their controller (`QQ_ALSAIController`).
- Probe ready for a run with the screen on: `dev/st_probe9.lua` (calc kit) compares a squad soldier
  and an enemy spawned next to it: on the mesh or not, a path 8 m ahead (valid, partial, length),
  and the move result for each.
- Meanwhile a straight move goes only as far as the line from the pointman to its spot is clear
  (one more trace), so it stops before a corner instead of walking into it.
- Answered (test 25, after a PC restart): the squad soldier is on the mesh, a path 8 m ahead is valid
  (not partial, 800 cm) and `MoveToLocation` with pathfinding returns 2. The earlier failures came
  with a broken game state (every launch from 04:42 stalled or crashed until the restart). The
  straight move stays as the fallback. The same run verified the hand-back on enemy fire and that
  pointmen stay put while you stand; with a wall right ahead the first pointman retried every tick
  (2.5 ms), so a failed spot now waits `RetrySeconds` (2 s).

## 8. 0.2.0: squad orders like Ready or Not (2026-11-08)

The user: pick everyone, a team or one or two soldiers, aim at a spot and give an order there, as in
Ready or Not. Wished orders: move here, hold and cover here, stack up at a door and clear the room,
lead the way, fall in, cover an ally or me, finish the downed, patrol (later), and a queued order
started with one key. Fast in a fight; every order can be cancelled. Plus better squad movement.

### 8.1 Research answers

**What the game binds on foot** (key presets `MSM1_Character`, `MSM1_X_Shared`, `MSM1_CharacterGamepad`
and the raw key events of `Q1Controller` / `Q1_Character`):

- Middle mouse = the cyborg ability (`C_CyborgAbilityKeyboard`). Mouse wheel = beam power and sniper
  zoom (`C_BeamPower`, `C_SniperZoom`). So no mouse button is free. A UE4SS key bind does not block
  the game's own action, so Squad Tactics stays off the middle mouse button.
- 1, 2, 3 = weapons; 4, 5, 6 = actions; 9 = photo mode; F1, F2, F5 = the game's squad order mode
  (`SendOrderToSquad` 0/1/2). **7, 8, 0 and Z** are free on foot (Z is free look in a ship only; the
  orders work on foot only, as Silent Ops' F3/F4). Arrow keys, Insert, Home, End, PageDown are free
  too but far from WASD.
- A held key can be read: `PlayerController:IsInputKeyDown({KeyName = FName("Z")})`, as Silent Ops'
  Shift guard does (verified in game). Read only while the order menu is up.
- The game's own input events are hookable Blueprint functions on `Q1_Character_C`
  (`InpActEvt_C_SniperZoom_…`, `InpActEvt_GPC_Order1_…` and so on): the way in for the mouse wheel
  and for a gamepad, if needed.

**Menu and marker on screen:** draw on the HUD canvas in a post-hook of `Q1Hud_C:ReceiveDrawHUD`, as
Ground Waypoints does (`Project` for world-to-screen, `DrawRect`, `DrawText`; no out parameters).
Debug drawing is compiled out of the shipping game. The list sits next to the crosshair; a marker
sits on the aimed spot; a small dot in the team's colour sits over each selected soldier. Hidden in
photo mode and when the game hides its indicators. The set's one-line message (`hudmsg`) confirms
each order.

**Doors:** the aim trace (one reused, cleared out table, as 0.1.0) returns the hit actor. Dungeon
interior doors are DungeonFlow Blueprints (`DoorBase_C`, `New_Door_C`, `OneWayDoor_C`, `Door_1_C` to
`Door_4_C`, `EBP_LockDoor_C`, with `Open` / `Close` and an overlap box); dungeon entrance gates are
`Q1_DungeonDoor_C` and its children (`CPP_DungeonDoor`). A doorway without a door: the hit is a wall
next to an opening, found with two traces along the wall that find its edges (80-300 cm wide). Still
to check in game: which classes the station and outpost doors have (probe: log the hit actor's class
and component while walking through doors).

**Holding a spot while still fighting (the key finding):** a squad soldier follows a formation slot.
Its `GoalRM` is one of your `SquadLocations` (child actor components on you) and `GoalActor` that
slot's actor. Every 1.5 s its battle timer (`MainTimer` → `UpdateBattle`) sends it back along a path
when it is more than 7 m from `GoalRM`, and between those checks it targets and shoots as usual. So
"hold here", "move here" and "cover him" can point `GoalRM` / `GoalActor` at an anchor (a small
invisible actor of ours with a child actor component) at the spot, or attached to the ally, with
the battle timer running: the game's own AI keeps the soldier within 7 m of the spot and fights.
"Fall in" puts your slot back. No pausing, no re-moving by us. Verified (test 30): one soldier's
`GoalRM` / `GoalActor` pointed at a `TargetPoint` with an added `ChildActorComponent` where you
stood, then you walked 12 m on: 10 s later it was 2.7 m from the anchor and 13.9 m from you, battle
timer running, slot still ours; another soldier had followed you (2.1 m). Still to watch: whether the
game puts the slot back on its own (crew update, load); if so we re-point it each tick (one property
read).

**Finish the downed:** HTR keeps knocked-out enemies down and lets only your hits and pirates kill
them. The order needs a small HTR addition (`HTR.isDown(npc)` and a "finish" mark that lets a squad
hit kill that body); without HTR the order is not offered.

### 8.2 Keys (keyboard)

| Key | Action |
|---|---|
| **Z tap** | The order that fits what you aim at, at once (floor: move here; door: stack up; downed enemy: finish; ally: cover him; nothing or the sky: fall in) |
| **Z hold** | Order list at the aimed spot. Move the mouse up and down to pick (the view holds still while Z is down; the mouse wheel too if its game event can be read), left and right to change who. Let go of Z to give it |
| **0** | Who: All (gold) → Red → Blue → 1 soldier → 2 soldiers (the ones nearest the spot). Shown at the screen edge |
| **0 while holding Z** | The order waits for your go. With orders waiting, a Z tap means **Go** |
| **Shift+Z** | Same as Z, so orders work while you sprint |

Shift+0 stays Ammo Discipline's. Silent Ops' F3 quiet orders stay: the last order wins for each
soldier (a shared table both mods check: Silent Ops 0.3.8 skips soldiers Squad Tactics has an order
for, and an F3 order frees them from Squad Tactics).

Gamepad: the game's own pad events can be hooked (the D-pad order mode is `GPC_Order1/2/3`), so a pad
layout is possible. Only if the user plays on foot with a pad; to be planned with a pad test.

### 8.3 Orders

| Order | What the selected soldiers do |
|---|---|
| **Move here** | Each to its own spot around the point (spread on a short arc, traced so no spot is inside a wall), facing the way you looked. Then they hold there and fight there (8.1) |
| **Hold & cover here** | As Move here, crouched, each watching its own sector of the way you looked |
| **Stack up** | On your side of the door, against the wall on both sides of the frame, facing the door |
| **Stack & clear** | Stack up, then on Go (or at once) the first two go through to the room's corners (traces into the room), the rest cover the doorway; "room clear" when nobody shoots for a few seconds; then they hold in the room. Silent Ops' search spots can be reused |
| **Lead the way** | 0.1.0's bounding overwatch for the selection |
| **Fall in** | Back to the game's follow (cancels any order) |
| **Cover me / him** | The anchor rides on you or the aimed ally: they keep within 7 m and fight |
| **Finish him** | One soldier goes to a few metres from the downed enemy and shoots it (HTR needed) |
| **Patrol** | Later: points set from the list, walked out of a fight |

**Lead the way** stays on by default: with no other order, two soldiers lead as in 0.1.0 (the Red
team). Any order to them takes them out of it; "Lead the way" from the list puts it back; "Fall in"
for everyone turns it off. 0 no longer switches it.

**Better squad movement** (the user: improve the NPCs' movement limits), for every order: path-found
moves (verified on the station deck), each soldier its own spot (no crowding), run when far and walk
when close, crouch at holding spots, face the given way (verified), and when a soldier makes no
progress for 2 s, a new path to the next free spot.

### 8.4 Costs

Per frame only while Z is held: one held-key read, the view hold (get and set the control rotation)
and the list drawn (a few `DrawText` / `DrawRect`). Markers of active orders: one `Project` each per
frame. Orders: one aim trace, a few spot traces per order, the 0.5 s tick as 0.1.0. No `LoopAsync`,
no per-frame out-parameter calls.

### 8.5 Test plan

1. Probe run: `GoalRM` / `GoalActor` on an anchor (do they hold there and fight; does the game
   put the slot back), Z held read, list and marker drawn on the HUD, the hit class of station and
   dungeon doors.
2. Build, then a scripted run per order (move, hold, stack and clear, cover, fall in, queue and go)
   and screenshots of the list and a stack-up for the README.

### 8.6 Built (0.2.0) and verified in game (tests 30-35, scripted, test slot)

- Code: `st/orders.lua` (who, aim, context, anchors, orders, the 0.5 s tick), `st/menu.lua` (Z held,
  the list, the view hold, drawing), `st/lead.lua` (soldiers with orders are left out of the
  pointmen; "Lead the way" can be limited to the selection).
- The hit result's `Actor` comes back as an `FWeakObjectPtr` userdata (test 33); its own `Get()` gives
  the actor (test 34: `StaticMeshActor`, `C_SpaceDungeonTransmitor_C`, a squad soldier). Doors are
  recognised by class or by the actor a part is attached to. "Cover him" only for one of your squad
  (the hit actor, or a hit on its body): test 34 gave "cover him" for a hit on the floor next to a
  soldier and even for a static mesh.
- Anchors: one `TargetPoint` + `ChildActorComponent` per soldier and order; the soldier's `GoalRM` /
  `GoalActor` point at it; "Fall in" puts the old slot back (else your `SquadLocations[Crew Index]`).
  Test 32: three of four soldiers on their spots within 0.5 m; the fourth's spot had no path, so a
  soldier without a path now goes to the order's centre (stuck 4 s: the same).
- Hold & cover: watchers paused and crouched (verified); an enemy's shots 25 m away let them fight
  (unpaused, 2.5 m off the spot) and 16 s later they watched again on their spot (verified).
- Stack & clear: the first two went in to the room spots, the rest stayed stacked (verified on a
  wall; a real interior door still to see in a dungeon).
- An order on your go, then GO: all four on their spots (verified). Lead the way from the list and
  fall in for everyone (lead off, every slot back on you): verified.
- Costs: nothing per frame unless Z is down or a marker shows. One squad read at load (~50 ms);
  test 33 found a read every 5 s while all soldiers had orders (lead.lua asked for pointmen that
  could not be found): now only when the list is stale.
