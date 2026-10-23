# Pathwise

A World of Warcraft addon that follows your character's progression and tells you what to do next. The full design is in [docs/PATHWISE_DESIGN.md](docs/PATHWISE_DESIGN.md).

**Target:** WoW Classic Era. **Status:**
- M0 (skeleton) and M1 (character tracker, spec detection, goal prompt) are tested in game on Classic Era 1.15.9 with a level 1 Night Elf Hunter.
- M2 (gear advisor and tooltip line) is working in game; a few checks are still open (see below).
- M3 (quest reward picker) is working in game.
- M4 (trainer reminder and spellbook Training panel) is built and passes the offline tests. It has not been tested in game yet.
- Quest log advisor and Next Steps window are built and pass the offline tests. They have not been tested in game yet. The quest advisor was planned for after M7, and the window is part of M7.
- Navigation arrow and learned quest locations are built and pass the offline tests. They have not been tested in game yet.
- Optional QuestieDB integration is working in game. With the QuestieDB addon installed, the arrow points to turn-in NPCs and the nearest quest mobs or objects. The "Next" controls are built but not yet tested in game.
- Target macro and sell price in tooltips are built and pass the offline tests. They have not been tested in game yet.
- M5 (talent advisor) and M6 (hunter module: ammo, pet, taming quest) are built and pass the offline tests. They have not been tested in game yet.

## Install

1. Copy this folder to `World of Warcraft/_classic_era_/Interface/AddOns/Pathwise/`. The folder must be named `Pathwise` and contain `Pathwise_Vanilla.toc` directly.
2. The TOC uses interface `11509`, verified in game on 2026-10-22. After a Classic Era patch, run `/dump select(4, GetBuildInfo())` and update `## Interface:` in `Pathwise_Vanilla.toc` if the number changed.
3. Turn on Lua errors with `/console scriptErrors 1`, or install BugGrabber and BugSack.

## Commands

| Command | What it does |
|---|---|
| `/pw help` | List commands |
| `/pw status` | Print the character snapshot: class, level, XP, zone, spec, talents, gear, skills |
| `/pw spec` | Open the path chooser (same as the **Path** button in the Next Steps window) |
| `/pw spec <path>` | Set the path directly, e.g. `bm`, `mm`, `surv`, `leveling`. `/pw spec clear` removes it, and Pathwise then follows your talents |
| `/pw score` | Print the score of each equipped item and the total |
| `/pw stats [item]` | Print an item's raw stats as the game reports them. Type `/pw stats `, then shift-click an item |
| `/pw training` | List the spells you can learn now (recommended and optional) and the ones coming soon |
| `/pw debug` | Toggle debug output (`/pw debug on` or `/pw debug off` also work) |
| `/pw reset` | Reset account settings. `/pw reset char` resets this character's data |
| `/pw` | Show or hide the Next Steps window |
| `/pw quests` | List your quests in the recommended order in chat |
| `/pw way <x> <y> [name]` | Point the arrow at coordinates on your current zone map, e.g. `/pw way 45.2 63.1 Trainer`. `/pw way clear` removes it |
| `/pw next` | Move the arrow on to the next spot or step (same as the arrow's Next button) |
| `/pw arrow` | Turn the arrow following your next step on or off |
| `/pw talents` | Show your next talent points from the build for your path. `/pw talents check` compares the build data with the game's talent tree |
| `/pw ammo [warn] [critical]` | Show your ammo count and warning levels. `/pw ammo 200 50` sets them |
| `/pw macro` | Put the "Pathwise" target macro on your cursor to drop on an action bar. `/pw macro off` / `on` stops or resumes updating it |

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
- [ ] A weapon your class can use but you haven't learned yet (red in the tooltip, e.g. a staff) says `... (learn Staves first)`. In the quest reward window it gets `Needs training` instead of `Best upgrade`, and a reward you can use right away wins over it.
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

## In-game test checklist (quest advisor and Next Steps window)

- [ ] After login, a **Pathwise: Next steps** window appears on the right side of the screen. It can be dragged, and it remembers where you put it. `/pw` hides or shows it.
- [ ] It lists your quests in this order: **Turn in**, **Failed**, **Almost done** (with %), **Do** (current zone first), **Do ... in <zone>**, **Later (level X)**, **Group quest**, **Low XP**.
- [ ] Quests whose objectives are within about 120 yards of each other become one step, `Do together: [5] Timberling Seeds + [6] Timberling Sprouts`. In the Next Steps window, the step the arrow follows is expanded: each quest is listed with blue "what to do" lines under it, e.g. `Kill Timberling for Timberling Seed` and `Collect Timberling Sprout`. The arrow only shows a short label, like `Timberling Seed (Timberling) +1 quest`, and the distance. The target macro targets the mobs of all the combined quests. Single quests get their what-to-do lines too, e.g. `Kill Webwood Spider` or `Turn in at Gilshalan Windwalker`. This needs QuestieDB.
- [ ] When Pathwise knows where a quest happens (QuestieDB or learned), the line shows the distance, e.g. `- 80 yd`. Quests within about 300 yards come first, nearest first. Far turn-ins wait until the nearby work is done. Walking somewhere else re-sorts the list within a few seconds, and the arrow follows the top line.
- [ ] Quest titles are colored like in the quest log (red, orange, yellow, green, grey). Orange quests say "(hard)".
- [ ] Hovering a line shows the quest's zone and objectives.
- [ ] The list updates on its own when you kill quest mobs, accept, turn in or abandon quests, change zone or level up.
- [ ] When a quest's last objective completes, chat says `Quest complete: <quest> - turn it in.` once.
- [ ] With spells to learn, a `Visit your trainer: N recommended spells (cost)` line appears between turn-ins and other quests.
- [ ] Collapsing a zone in the quest log adds a line asking you to expand it.

## In-game test checklist (navigation arrow)

- [ ] `/pw way 50 50 Test` shows an arrow near the top of the screen. It rotates as you turn, turns green when you face the target, and shows the distance in yards. Walking there prints `Arrived at Test.` and the arrow disappears.
- [ ] The arrow can be dragged. Right-click clears a `/pw way` waypoint.
- [ ] With QuestieDB installed, the arrow points to the nearest quest mob or object for a quest as soon as you accept it, and to the turn-in NPC once it's complete. Quests under a subzone header, like "Shadowglen", no longer say "in Shadowglen" while you're there.
- [ ] Without QuestieDB: accept a quest, then make progress on it, e.g. kill one quest mob. The Next Steps line for that quest gets a blue `*`, and the arrow points to where you made progress.
- [ ] When the quest is complete, the arrow points back to the quest giver (`Turn in: ... (where you got it)`).
- [ ] Clicking a Next Steps line with a `*` points the arrow there.
- [ ] Reaching a quest spawn keeps the arrow there ("You are here") until you loot or kill something for the quest. Then it moves on to the next nearest spawn. Spawns within 20 yards of where the progress happened are skipped for 5 minutes.
- [ ] **Next >** under the arrow moves on to the next spawn. So do right-clicking the arrow, `/pw next`, and the key binding (Key Bindings → Pathwise → "Skip to next spot"). On a step that isn't a spawn, like a turn-in, or once all spawns are used up, it skips the whole step for 5 minutes and points at the next one. `/pw arrow` turns following your next step off and on.
- [ ] In a dungeon, or for a target on another continent, the arrow says `Can't point from here`.
- [ ] The direction is correct, not mirrored or rotated by 90 degrees. Use `/pw way` with a known spot to check.

## In-game test checklist (target macro and sell price)

- [ ] `/pw macro` puts a macro called **Pathwise** on the cursor. Drop it on an action bar.
- [ ] With a quest step active, pressing it targets the nearest quest mob (with QuestieDB) and puts a skull on it. On a turn-in step it targets the turn-in NPC when you're near it.
- [ ] The macro's contents update by themselves when the step changes. Check in Esc → Macros → Character Specific. Changes made in combat happen right after combat.
- [ ] Item tooltips in your bags show `Sell price: ...` with coin icons. A stack shows the total and the price per item, e.g. `Sell price: 6s (5 x 1s 20c)`.
- [ ] At a vendor, only the game's own sell price is shown, not two.
- [ ] Items that can't be sold have no sell price line.

## In-game test checklist (M5 talent advisor)

- [ ] At level 10, Next Steps shows `Spend 1 talent point: Improved Aspect of the Hawk (1/5)` (Leveling or Beast Mastery path), and chat says it once.
- [ ] Hovering the line shows the build name and the next five points.
- [ ] After you spend the point, the line disappears until your next level.
- [ ] `/pw spec mm` (before you've spent points) switches to the Marksmanship build, which starts with Efficiency.
- [ ] If you spend a point elsewhere, the advisor keeps suggesting the next build talent without complaining.
- [ ] `/pw talents check` says `0 mismatches`. Any mismatch line means my talent data is wrong for that talent; send it to me.

## In-game test checklist (changing path)

- [ ] The Next Steps window shows **Path: <your path>** at the top right. Clicking it opens the path chooser.
- [ ] Changing the path switches the gear verdicts, the trainer's recommended or optional spells, and the talent build at once, even with talent points already spent.
- [ ] With points spent that the new path's build doesn't use (3 or more), Next Steps suggests unlearning them at your class trainer.
- [ ] `/pw status` shows e.g. `Beast Mastery (your choice) - your talents look like Marksmanship (0/12/0)`.

## In-game test checklist (M6 hunter module)

- [ ] Below 200 arrows, Next Steps shows `Low ammo: N arrows left` and chat warns once. Below 50 the warning is urgent (top of the list). An empty ammo slot shows `No ammo equipped!`.
- [ ] A gun says "bullets". A thrown weapon gives no ammo warnings.
- [ ] When your pet is content or unhappy, Next Steps shows `Feed <pet> (content)`. Hovering shows what it eats. Chat says it once when the mood drops. The line goes away once the pet is happy.
- [ ] At level 10, without Tame Beast, Next Steps shows the Taming the Beast step and chat reminds you once. With QuestieDB, the arrow points to your hunter trainer (Dazalar in Dolanaar for Night Elves). The step disappears once you've learned Tame Beast.

## Things to verify in game (marked `TODO verify` in code)

- `UnitCharacterPoints("player")` returns unspent talent points. This can only be checked from level 10.
- The talent tab order for each non-hunter class in `Data/Classic/ClassSpecs.lua`. The hunter order is verified.
- Weapon DPS is reported by `GetItemStats` as `ITEM_MOD_DAMAGE_PER_SECOND_SHORT`. Use `/pw stats` on a weapon to check. Armor (`RESISTANCE0_NAME`) is verified in game.
- Which tooltip hook Classic Era uses. `/pw debug` prints `Tooltip hook: ...` at login.
- The weapon types hunters can use, and that dual wield starts at level 20 (`Data/Classic/ClassGear.lua`).
- Every spell ID, level and cost in `Data/Classic/ClassSpells.lua`. The data comes from WhatsTraining.
- That `IsSpellKnown`/`IsPlayerSpell` recognise passive spells like Parry, Dual Wield and Mail.
- That the event `LEARNED_SPELL_IN_SKILL_LINE` fires when you learn a spell in 1.15.9.
- The quest log API (`GetQuestLogTitle` return order, `GetQuestLogLeaderBoard`), and the quest-color fallback when `GetQuestGreenRange` is missing.
- `GetPlayerFacing`, `C_Map.GetPlayerMapPosition` and `C_Map.GetWorldPosFromMapPos` behave as expected in Classic Era (arrow direction and distance).
- `QUEST_ACCEPTED` arguments (questLogIndex, questID) and that `QUEST_TURNED_IN` exists.
- The weapon and armor skill spell IDs in `Data/Classic/ClassGear.lua` (`Pathwise.Data.Proficiencies`). If an item you can use says "learn ... first", the ID for that skill is wrong.
- Macro functions (`CreateMacro`, `EditMacro` with a texture name as icon) in Classic Era 1.15.9, and that `SetRaidTarget` on yourself works solo.
- That bag item buttons keep their stack size in `.count` (sell price for stacks).
- Talent positions in `Data/Classic/TalentBuilds.lua` (`/pw talents check`).
- `GetInventoryItemCount("player", 0)` counts all your ammo of that type. `GetPetHappiness`, `GetPetFoodTypes`, `HasPetUI` and the `UNIT_HAPPINESS` event in Classic Era.
- Whether `PLAYER_TALENT_UPDATE` exists in Classic Era. If it doesn't, `/pw debug` reports it once and Pathwise continues normally.

## Development

- Layers: `Platform/` is the only place that calls flavor-specific WoW API. `Core/` holds the logic and never calls the WoW API directly. `UI/` may use frame and tooltip APIs. `Data/` holds plain tables.
- Offline smoke tests run against a small mock of the WoW API. Run `lua5.1 tests/run.lua` from the repo root, and set `PATHWISE_ECHO=1` to see chat output. These tests catch Lua errors and logic bugs, but they don't replace testing in game.
- Quest locations can come from [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0). It's an optional dependency read at runtime through its public `LibQuestieDB` API; Pathwise ships none of its data.
- Hunter trainer data (`Data/Classic/ClassSpells.lua`) is based on [WhatsTraining](https://github.com/fusionpit/WhatsTraining) by fusionpit, MIT License.
- The `tests/` and `docs/` folders aren't listed in the TOC, so WoW ignores them.
