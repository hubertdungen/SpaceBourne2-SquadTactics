# Changelog

## 0.1.0 — 2026-11-08

- First version: the **"Lead the way"** order (bounding overwatch). One or two squad soldiers go
  ahead of you to the side of the corridor, crouch and watch forward, and leapfrog on as you catch
  up; gunfire near you hands them back to the game's combat AI. On by default; key 0.
- Tested in game (scripted): two pointmen chosen from a squad of four, leapfrogging 6-9 m ahead as
  you moved, against the wall when there was one, and still while you stood; an enemy's shots handed
  them back to the game's combat AI and they took the lead again afterwards. Path-found moves work
  on the station deck. Cost 0.4-0.8 ms every half second, the one-off squad scan 50-100 ms.
