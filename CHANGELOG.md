# Changelog

## 0.2.2 — 2026-11-13

From your own game's log:
- **Lead the way kept working only until the first "Fall in".** "Fall in" for everyone switched it
  off, and it stayed off until "Lead the way" was picked again in the list. Now "Fall in" only
  cancels orders: the pointmen lead again at once. To switch leading off, the list has
  **Stop leading**.
- **Orders and pointmen on missions.** Squad Tactics looked only for your own crew. It now takes
  every soldier on your side near you, so soldiers fighting with you on a mission get orders too.
  With nobody on your side near you, Z says "No squad here: call your ground squad first".
- **No more soldiers stuck in walls.** A soldier with no path to its spot no longer walks there in a
  straight line (one could get wedged); it follows you meanwhile.
- **No more pointman churn.** With your squad far behind (more than 30 m), pointmen were picked and
  dropped every half second. Now only soldiers within reach are picked.
- Tested in game (scripted, tests 38-40): your side read through the parent soldier class (your
  squad of 4 found), move here, cover him, stack up, fall in; after each fall in the pointmen led
  again at once.

## 0.2.1 — 2026-11-12

- **Rescue me.** While you are down (knocked out by Hardcore Tactical Realism), a tap of **Z** asks
  your squad to come for you now: the nearest ally (a medic first) comes at once, even with enemies
  close. Holding Z shows "Rescue me" at the top of the list; letting go gives it. A line on screen
  says "Rescue requested".
- Needs Hardcore Tactical Realism 0.4.16 or later (it does the rescue). Without it, the Z tap while
  you are down gives "Fall in": everyone comes back to you.
- While you are down the list does not follow the mouse (the game turns the camera by itself then).
- Tested in game (scripted, test 37, real key input, HTR 0.4.16): down, a Z tap gave Rescue me,
  wrote HTR's request and HTR took it within a few seconds.

## 0.2.0 — 2026-11-08

- **Squad orders, Ready-or-Not style.** Aim at a spot and tap **Z** for the order that fits it, or
  hold **Z** for the order list next to the crosshair (mouse up/down picks, left/right picks who; let
  go to give it). **0** picks who: all, red team, blue team, the one or two soldiers nearest the spot.
- Orders: move here, hold & cover, stack up (at a door), stack & clear (two go in to the corners, the
  rest cover the doorway, "Room clear"), cover him (one of your soldiers), lead the way, fall in.
- Soldiers on a spot keep fighting the game's way and come back to it: the game's AI follows our
  spot instead of you. Crouched watchers fight when shots come near and then watch again.
- Orders on your go: 0 while holding Z makes the order wait; a tap of Z then starts them all (GO).
- A soldier that cannot reach its spot goes to the middle of the order instead of standing still.
- "Lead the way" stays on by default; it is now in the order list (with "Fall in"), and 0 no longer
  switches it (`Lead.Key` is empty by default).
- Fixed: after a trip in a ship, pointmen could stay paused (standing still) until the next load.
- Tested in game (scripted, tests 30-35): the order list and markers drawn, move here (all), hold &
  cover (red) with a fight and back, fall in (every soldier back on your slot), stack up on a wall,
  stack & clear, an order on your go, lead the way from the list, cover him; the hit actor and doors
  read from the aim. No pause in a tick above 4 ms after the one squad read at load.
- Tested with real key and mouse input sent to the game (tests 36b-36c): Z tap, Z held with the list
  and the mouse picking the row (the view stays still), 0 for who, 0 with Z held (the order waits),
  Z tap for GO, Shift+Z, fall in.
- Keyboard and mouse only for now. Not in yet: finishing Hardcore Tactical Realism's downed enemies, patrols.

## 0.1.1 — 2026-11-08

- **Lead the way works in dungeons.** In a dungeon the pointmen stood still or moved about 1 m.
  - A pointman that has no spot to go to now follows you and fights the game's way until it finds one. Before, it stood still and stayed out of the fight.
  - Soldiers in the way are no longer taken for a wall. Your squad crowding a narrow corridor in front of you made the pointmen wait, standing still.
  - A squad soldier's shot counts as a fight only when its target is within `CombatRange` of you or a pointman. Before, any shot of your squad at anything, however far away, sent the pointmen back to the game's AI. In a dungeon full of creatures they hardly ever led.
- A pointman on another floor (lifts, stairs) goes back to the squad (`FloorHeight`).
- When a path to the spot fails, the pointman tries half way there before the straight move.
- The game sometimes restarts a pointman's battle timer; it is now paused again.
- `CombatRange` default 3000 (was 5000).
- No more hitch after a fight: the squad list (about 50 ms to read) is read again only when nobody is
  left on it; 0.1.0 read it every time the pointmen came back after gunfire.
- With `Debug.Log` on, the log says why a pointman did not move.
- Tested in game (scripted, tests 27-29) in a station corridor with the squad crowding in front of
  you: the pointmen led both ways along it, against the walls, past the soldiers in the way, with no
  failed move; an enemy 18 m away handed them back and they led again afterwards without a hitch.
  0.4-0.6 ms every half second. Not yet tested in a dungeon itself (no dungeon in the test saves).

## 0.1.0 — 2026-11-08

- First version: the **"Lead the way"** order (bounding overwatch). One or two squad soldiers go
  ahead of you to the side of the corridor, crouch and watch forward, and leapfrog on as you catch
  up; gunfire near you hands them back to the game's combat AI. On by default; key 0.
- Tested in game (scripted): two pointmen chosen from a squad of four, leapfrogging 6-9 m ahead as
  you moved, against the wall when there was one, and still while you stood; an enemy's shots handed
  them back to the game's combat AI and they took the lead again afterwards. Path-found moves work
  on the station deck. Cost 0.4-0.8 ms every half second, the one-off squad scan 50-100 ms.
