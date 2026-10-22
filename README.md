# Pathwise

A World of Warcraft addon that follows your character's progression and tells you what to do next. The full design is in [docs/PATHWISE_DESIGN.md](docs/PATHWISE_DESIGN.md).

**Target:** WoW Classic Era. **Status:**
- M0 (skeleton) and M1 (character tracker, spec detection, goal prompt) are tested in game on Classic Era 1.15.9 with a level 1 Night Elf Hunter.
- M2 (gear advisor and tooltip line) is working in game; a few checks are still open (see below).
- M3 (quest reward picker) is working in game.
- M4 (trainer reminder and spellbook Training panel) is built and passes the offline tests. It has not been tested in game yet.

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
| `/pw score` | Print the score of each equipped item and the total |
| `/pw stats [item]` | Print an item's raw stats as the game reports them. Type `/pw stats `, then shift-click an item |
| `/pw training` | List the spells you can learn now (recommended and optional) and the ones coming soon |
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

## In-game test checklist (M2)

- [ ] Hovering an item in your bags shows a `Pathwise:` line, e.g. `+8% upgrade` in green, `-8% downgrade` in red, or `about the same` in yellow. The percentage is the change to the total score of all your equipped gear, so swapping an item and swapping back give about the same size number.
- [ ] An armor-only item, like boots with only an Armor value, beats an equipped item with no armor.
- [ ] A plate or mail item, or a mace, says `not usable by your class`. Mail says `... at level 40` instead.
- [ ] An item above your level ends with `at level X`.
- [ ] Equipped items don't get a line. Neither do the comparison tooltips that appear next to the main tooltip.
- [ ] Hovering the same item repeatedly never shows the line twice.
- [ ] A better bow beats the Worn Shortbow by a large margin. Ranged DPS is weighted heavily.
- [ ] Items linked in chat (click the link) also get the line.
- [ ] `/pw score` lists your equipped items with scores.
- [ ] `/pw stats` on a piece of armor lists `RESISTANCE0_NAME` (armor). On a weapon it lists `ITEM_MOD_DAMAGE_PER_SECOND_SHORT`.
- [ ] With `/pw debug` on, the tooltip line also shows both scores, e.g. `(2.8 vs 0.6)`.

## In-game test checklist (M3)

- [ ] Turning in a quest with several reward choices puts a green border and a `Best upgrade` label on the best one, and prints `Pathwise: Best reward: [item] (+X% upgrade).` in chat.
- [ ] If no reward is an upgrade, the label says `Best to sell` and chat names the item with the highest vendor price.
- [ ] Pathwise never selects the reward itself.
- [ ] The highlight disappears when the quest window closes. It doesn't show up on the next quest window.
- [ ] Quests with only one reward, or none, show nothing.
- [ ] If an item has a two-line name, check that the label doesn't cover it.

## In-game test checklist (M4)

- [ ] Opening the spellbook shows a book icon tab below the spellbook's own tabs, with the number of recommended spells on it.
- [ ] The **Pathwise: Training** panel appears to the right of the spellbook. It lists **Recommended for <your path>** with costs and a total, then **Optional (can skip)**, then **Coming soon**.
- [ ] Each spell's name and icon in the panel matches what the trainer offers. A wrong name or icon means a wrong spell ID in the data.
- [ ] Hovering a spell in the panel shows its tooltip.
- [ ] Clicking the tab hides or shows the panel, and the choice is remembered.
- [ ] After you learn spells at the trainer, they disappear from the list right away.
- [ ] On level up, one chat line names the new recommended spells. It doesn't repeat for the same level.
- [ ] `/pw spec mm` moves Raptor Strike and Mongoose Bite to Optional. `/pw spec surv` makes them recommended again.
- [ ] Mend Pet only shows up after you've learned Tame Beast from the level 10 quest.

## Things to verify in game (marked `TODO verify` in code)

- `UnitCharacterPoints("player")` returns unspent talent points. This can only be checked from level 10.
- The talent tab order for each non-hunter class in `Data/Classic/ClassSpecs.lua`. The hunter order is verified.
- Weapon DPS is reported by `GetItemStats` as `ITEM_MOD_DAMAGE_PER_SECOND_SHORT`. Use `/pw stats` on a weapon to check. Armor (`RESISTANCE0_NAME`) is verified in game.
- Which tooltip hook Classic Era uses. `/pw debug` prints `Tooltip hook: ...` at login.
- The weapon types hunters can use, and that dual wield starts at level 20 (`Data/Classic/ClassGear.lua`).
- Every spell ID, level and cost in `Data/Classic/ClassSpells.lua`. The data comes from WhatsTraining.
- That `IsSpellKnown`/`IsPlayerSpell` recognise passive spells like Parry, Dual Wield and Mail.
- That the event `LEARNED_SPELL_IN_SKILL_LINE` fires when you learn a spell in 1.15.9.
- Whether `PLAYER_TALENT_UPDATE` exists in Classic Era. If it doesn't, `/pw debug` reports it once and Pathwise continues normally.

## Development

- Layers: `Platform/` is the only place that calls flavor-specific WoW API. `Core/` holds the logic and never calls the WoW API directly. `UI/` may use frame and tooltip APIs. `Data/` holds plain tables.
- Offline smoke tests run against a small mock of the WoW API. Run `lua5.1 tests/run.lua` from the repo root, and set `PATHWISE_ECHO=1` to see chat output. These tests catch Lua errors and logic bugs, but they don't replace testing in game.
- Hunter trainer data (`Data/Classic/ClassSpells.lua`) is based on [WhatsTraining](https://github.com/fusionpit/WhatsTraining) by fusionpit, MIT License.
- The `tests/` and `docs/` folders aren't listed in the TOC, so WoW ignores them.
