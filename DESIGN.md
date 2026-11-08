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
- **Taking control:** the soldier's battle logic timer (`MainTimer`) is paused with
  `KismetSystemLibrary.K2_PauseTimerHandle`, as Silent Ops' quiet orders do; otherwise its own logic
  pulls it back to you. Released: timer running, uncrouched, ALS rotation mode restored, movement
  stopped.
- **Heading:** your velocity when you move, else your control rotation.
- **Spot:** `Distance` (900) ahead for the first pointman, `SecondDistance` (600) for the second, or
  `Leapfrog` (400) past the other pointman, at most `MaxLead`. Trace 1 along your heading: a wall
  closer than that shortens the spot to the wall minus `WallGap`, and closer than `MinLead` means
  wait. Trace 2 to the pointman's side (first left, second right) up to `SideSearch`: a wall there
  puts the spot against it (minus `WallGap`), else `SideOffset` off your line.
- **Move:** `AIController.MoveToLocation(spot, 60, ..., bUsePathfinding = true, project = true)`;
  when that fails (result 0), the same without pathfinding: a straight move. Gait running when you
  move faster than `RunAbove`, else walking.
- **Hold:** arrived within `ArriveRadius`, or the move stopped, or `MoveTimeout`: crouch, ALS looking
  direction, actor and control rotation set to your heading.
- **Leapfrog:** one pointman moves at a time. The one least ahead of you moves on when it is less
  than `LeapWhenAhead` ahead (you caught up, or you turned), it has held `MinHoldSeconds`, and you
  moved `YouMoved` since its last move (without that, one that stopped short of its spot moved
  again and again while you stood: test 24).
- **Fights:** a hook on every NPC shot within `CombatRange` of you, your shots and your squad's
  releases the pointmen for `CombatSeconds`.
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
- Not yet in game: the fixes of section 2 (no re-move while you stand, faster first scan) and the
  hand-back on enemy fire (test 24b stalled at the main menu with the screen off).

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

`0` (plain zero): free in the set's key plan (Ground Waypoints only suggests it as an optional
toggle; Shift+0 is Ammo Discipline's and stays quiet, UE4SS matches modifiers exactly).

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
