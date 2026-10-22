# Pathwise

A World of Warcraft addon that follows your character's progression and tells you what to do next. The full design is in [docs/PATHWISE_DESIGN.md](docs/PATHWISE_DESIGN.md).

**Target:** WoW Classic Era. **Status:** milestones M0 (skeleton) and M1 (character tracker, spec detection and goal prompt) are built and tested in game on Classic Era 1.15.9 with a level 1 Night Elf Hunter.

## Install

1. Copy this folder to `World of Warcraft/_classic_era_/Interface/AddOns/Pathwise/`. The folder must be named `Pathwise` and contain `Pathwise_Vanilla.toc` directly.
2. The TOC uses interface `11509`, verified in game on 2026-10-22. After a Classic Era patch, run `/dump select(4, GetBuildInfo())` and update `## Interface:` in `Pathwise_Vanilla.toc` if the number changed.
3. Turn on Lua errors with `/console scriptErrors 1`, or install BugGrabber and BugSack.

## Commands

| Command | What it does |
|---|---|
| `/pw help` | List commands |
| `/pw status` | Print the character snapshot: class, level, XP, zone, spec, talents, gear, skills |
| `/pw spec` | Open the goal prompt |
| `/pw spec <goal>` | Set the goal directly, e.g. `bm`, `mm`, `surv`, `leveling`. `/pw spec clear` removes it |
| `/pw debug` | Toggle debug output (`/pw debug on` or `/pw debug off` also work) |
| `/pw reset` | Reset account settings. `/pw reset char` resets this character's data |
| `/pw` | Opens the Next Steps panel once it exists (M7). For now it prints the command list |

## In-game test checklist (M0 and M1)

Test with a fresh level 1 Night Elf Hunter.

**M0**
- [ ] The addon loads with no Lua errors, and chat shows `Pathwise: v0.1.0 loaded`.
- [ ] `/pw debug` prints "Debug output enabled". Running it again disables it. With debug on, logging in or zoning prints `[debug]` lines.
- [ ] `/pathwise help` and `/pw help` both list the commands.

**M1**
- [ ] About 3 seconds after the first login, the goal prompt appears with the buttons Leveling, Beast Mastery, Marksmanship and Survival. Hovering a button shows a tooltip.
- [ ] Closing the prompt with X or Escape prints "No goal chosen, using Leveling…". After `/reload` the prompt does not come back.
- [ ] `/pw spec` reopens the prompt and marks the current goal "(current)". Clicking a button prints "Goal set to …".
- [ ] `/pw spec mm` sets Marksmanship. `/pw spec xyz` lists the valid options.
- [ ] `/pw status` shows the correct name, realm, level, race, class, faction, XP and rested XP, zone and subzone.
- [ ] `/pw status` lists the equipped gear as clickable links, **including the ammo slot** (equip arrows to check).
- [ ] Equip or unequip an item, then run `/pw status` again. The gear list should be updated.
- [ ] Skills list professions and weapon skills, e.g. Bows. If a header is collapsed in the skill window, `/pw status` says so.
- [ ] From level 10, "unspent" in `/pw status` matches the talent window. After spending points, the talent ranks are listed and the spec line says e.g. "Beast Mastery (from talents 5/0/0)".
- [ ] After `/reload`, `WTF/Account/<account>/<realm>/<char>/SavedVariables/Pathwise.lua` contains the goal and the last snapshot.

## Things to verify in game (marked `TODO verify` in code)

- `UnitCharacterPoints("player")` returns unspent talent points. This can only be checked from level 10.
- The talent tab order for each non-hunter class in `Data/Classic/ClassSpecs.lua`. The hunter order is verified.
- Whether `PLAYER_TALENT_UPDATE` exists in Classic Era. If it doesn't, `/pw debug` reports it once and Pathwise continues normally.

## Development

- Layers: `Platform/` is the only place that calls flavor-specific WoW API. `Core/` holds the logic and never calls the WoW API directly. `UI/` may use frame and tooltip APIs. `Data/` holds plain tables.
- Offline smoke tests run against a small mock of the WoW API. Run `lua5.1 tests/run.lua` from the repo root, and set `PATHWISE_ECHO=1` to see chat output. These tests catch Lua errors and logic bugs, but they don't replace testing in game.
- The `tests/` and `docs/` folders aren't listed in the TOC, so WoW ignores them.
