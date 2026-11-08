# Changelog

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
