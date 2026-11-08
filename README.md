![Squad Tactics](docs/banner.png)

# Squad Tactics — your squad leads the way in SpaceBourne 2

In SpaceBourne 2 your ground squad trails behind you in a loose crowd. With Squad Tactics, one or two
of your soldiers move ahead of you down a corridor or across a room, take a spot against the wall,
crouch and watch forward, and leapfrog on as you catch up: one moves while the other keeps watching.
When shooting starts, they fight the game's own way.

**Links:** [GitHub](https://github.com/hubertdungen/SpaceBourne2-SquadTactics) · UE4SS Lua mod ·
works alone or with the rest of the realism set.
**Install the whole realism set in one go:** the
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)).

## Features

### Lead the way

- **Pointmen.** One or two soldiers of your ground squad (the nearest ones) go ahead of you along the
  way you are walking, about 6 and 9 m in front.
- **To cover, not to the middle.** Each pointman goes to its side of the corridor and stops against
  the wall when there is one, short of any wall ahead.
- **Watching forward.** At the spot they crouch and face the way you are going.
- **Leapfrogging.** When you catch up with a pointman, it moves on past the other one, which keeps
  watching. Run, and they run to the next spot.
- **The rest of the squad** follows you as usual.

### Fights come first

- **Gunfire hands them back.** Your shots, your squad's, or an enemy's within 50 m: the pointmen go
  back to the game's own combat AI for a while, then take the lead again.
- **Only on foot.** In a ship or on the hoverbike nothing changes.

### On by default

- The order is on as soon as the mod is installed. Press **0** to switch between "lead the way" and
  the game's normal "follow me".

## Requirements

- SpaceBourne 2 (Steam), with a ground squad (recruit soldiers for your faction).
- [UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1) (the realism installer
  installs it for you).

## Install

**A. SpaceBourne 2 Realism installer (recommended)**
Get it on [Nexus](https://www.nexusmods.com/spacebourne2/mods/11) or
[GitHub](https://github.com/hubertdungen/SpaceBourne2-Realism/releases/latest). Tick Squad Tactics
and any other mods of the set: it installs UE4SS if you don't have it, switches the mods on and keeps
them updated.

**B. Manual** (the zip on the [releases page](https://github.com/hubertdungen/SpaceBourne2-SquadTactics/releases))
1. Extract the zip into your game folder (`...\SpaceBourne 2`, the one with `SpaceBourne2.exe`).
   It creates `SB2\Binaries\Win64\Mods\SquadTactics` and switches itself on.
2. No UE4SS yet? Get [RE-UE4SS 3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/v3.0.1)
   and copy `dwmapi.dll`, `UE4SS.dll` and `UE4SS-settings.ini` into
   `SpaceBourne 2\SB2\Binaries\Win64\`.

**Uninstall:** untick Squad Tactics in the installer or delete the `SquadTactics` folder. Squad
Tactics never writes to your saves.

## Controls

| Key | Action |
|---|---|
| **0** | Lead the way on / off (off = the game's normal follow) |

The key follows the realism set's shared key plan and can be changed in `scripts\config.lua`.

## Settings

Edit `Mods\SquadTactics\scripts\config.lua` (every line is optional):

- `Lead.Pointmen` — 1 or 2 soldiers lead.
- `Lead.Distance`, `Lead.SecondDistance`, `Lead.Leapfrog`, `Lead.MaxLead` — how far ahead they go.
- `Lead.LeapWhenAhead`, `Lead.YouMoved`, `Lead.MinHoldSeconds` — when a pointman moves on.
- `Lead.SideOffset`, `Lead.SideSearch`, `Lead.WallGap` — how they pick their side of the corridor.
- `Lead.Crouch` — crouch at the spot.
- `Lead.CombatRange`, `Lead.CombatSeconds` — when gunfire hands them back to the game's combat AI.
- `Lead.StartOn`, `Lead.Key`, `Messages`.

## Known limits

- **No true cover map.** The game gives mods no cover points, so a pointman picks "the side of the
  corridor, against the wall if there is one", found with a couple of line traces.
- **Straight moves where there is no navigation data** (station decks): a pointman then walks in a
  straight line to its spot and stops early if something is in the way.
- **Silent Ops' quiet squad orders** (F3) also steer the squad: use one or the other at a time.

Design notes and plans (more orders, enemy patrols that leapfrog too): [DESIGN.md](DESIGN.md).
Version history: [CHANGELOG.md](CHANGELOG.md).

## The SpaceBourne 2 realism set

Separate mods that work alone or in any combination. The
[SpaceBourne 2 Realism installer](https://github.com/hubertdungen/SpaceBourne2-Realism)
([Nexus](https://www.nexusmods.com/spacebourne2/mods/11)) installs the ones you tick and keeps them updated.

- **[Hardcore Tactical Realism](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/4)): realistic ballistics, wounds and tactical AI. The core of the set.
- **[Silent Ops](https://github.com/hubertdungen/SpaceBourne2-SilentOps)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/6)): stealth, silent takedowns and suppressors.
- **[Squad Tactics](https://github.com/hubertdungen/SpaceBourne2-SquadTactics)**: your squad leads the way, bounding from cover.
- **[Ammo Discipline](https://github.com/hubertdungen/SpaceBourne2-AmmoDiscipline)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/12)): carried ammo limits and scavenging, so every magazine counts.
- **[Gear Without Levels](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/7)): use gear above your level, with small handling penalties.
- **[Tactical First Person](https://github.com/hubertdungen/SpaceBourne2-TacticalFirstPerson)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/15)): first person on foot, weapons held up, aiming down the sights.
- **[Tactical Engineering](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/10)): realistic deployable turrets.
- **[Get Out of the Way](https://github.com/hubertdungen/SpaceBourne2-GetOutOfTheWay)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/14)): NPCs step aside naturally when you walk through them.
- **[Ground Waypoints](https://github.com/hubertdungen/SpaceBourne2-GroundWaypoints)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/13)): planet waypoints on foot and on the hoverbike.
- **[Faction Power](https://github.com/hubertdungen/SpaceBourne2-FactionPower)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/9)): dungeons, strategic sales and missions earn your faction power.
- **[Bigger Armies](https://github.com/hubertdungen/SpaceBourne2-BiggerArmies)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/17)): twice the general slots for your faction's ground and space forces.
- **[Clear HUD](https://github.com/hubertdungen/SpaceBourne2-ClearHUD)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/16)): a reticle you can see and HUD colours of your choice.
- **[Split Controls](https://github.com/hubertdungen/SpaceBourne2-SplitControls)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/5)): separate vertical invert for ship and on foot, per device.
- **[SB2 HOTAS](https://github.com/hubertdungen/SpaceBourne2-HOTAS)**
  ([Nexus](https://www.nexusmods.com/spacebourne2/mods/8)): HOTAS, rudder pedals, triple screens and head tracking.

## License

MIT. See [LICENSE](LICENSE).
