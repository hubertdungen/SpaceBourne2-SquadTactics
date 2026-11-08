# Changelog

## 0.1.0 — 2026-11-08

- First version: the **"Lead the way"** order (bounding overwatch). One or two squad soldiers go
  ahead of you to the side of the corridor, crouch and watch forward, and leapfrog on as you catch
  up; gunfire near you hands them back to the game's combat AI. On by default; key 0.
- Tested in game (scripted): two pointmen chosen from a squad of four, leapfrogging 6-9 m ahead as
  you moved, against the wall when there was one; cost 0.4-0.7 ms every half second (the one-off
  squad scan about 100 ms). Two later fixes (a pointman that stopped short no longer moves again
  while you stand; a faster first squad scan after a load) and the hand-back on enemy fire are not
  tested in game yet.
