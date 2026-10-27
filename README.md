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
- All classes: trainer spells, talent builds (three per class), stat weights, usable gear and the path choices for warriors, paladins, rogues, priests, shamans, mages, warlocks and druids too. Built and passing the offline tests, not yet tested in game.
- Pet ability guide (hunter): which ranks your pet can learn at its level and which beast to tame for each, with the arrow on the nearest one. Built and passing the offline tests, not yet tested in game.
- Window themes (docs/PATHWISE_THEMES.md): 13 themes on the To-do window (v2 painted corner art and v3 emblem themes included), an Appearance section in the settings and `/pw theme`. Built and passing the offline tests, not yet tested in game.

## Install

1. Download the newest `Pathwise-<version>.zip` from [Releases](https://github.com/lagnelius-debug/Pathwise/releases/latest) (the zip under "Assets", not "Source code"). Unzip it into `World of Warcraft/_classic_era_/Interface/AddOns/`. The folder must be named `Pathwise` and contain `Pathwise_Vanilla.toc` directly.
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
| `/pw theme` | List the window themes (numbered, active one marked). `/pw theme 7` or `/pw theme wildwood` sets one, `/pw theme next` cycles |
| `/pw pet` | Pet ability guide: the ranks your pet can learn at its level and the beasts that teach them |
| `/pw features` | Open the Features page: turn single features on or off |
| `/pw settings` | Open the Pathwise settings (minimap button, target button, meters or yards, window theme) |
| `/pw season summer\|autumn\|auto` | Wildwood theme leaves (auto = autumn in September to November) |
| `/pw minimap` | Show or hide the minimap button |
| `/pw professions` | Profession advice for your class and your current skills. `/pw professions off` / `on` hides or shows the profession steps |
| `/pw flights` | List the flight points Pathwise knows for this character (talk to a flight master to update them) |
| `/pw hearth on\|off` | Suggest setting your hearthstone in the zone you're questing in |
| `/pw pickups on\|off` | Suggest quests to pick up nearby (needs QuestieDB) |
| `/pw units meters\|yards` | Show distances in meters (default) or yards |
| `/pw targetbutton` | Turn the floating target button for quest mobs on or off |
| `/pw macro` | Put the "Pathwise" target macro on your cursor to drop on an action bar. `/pw macro off` / `on` stops or resumes updating it |

## In-game test checklist (M0 and M1)

Test with a fresh level 1 Night Elf Hunter.

**M0**
- [ ] The addon loads with no Lua errors, and chat shows `Pathwise: v0.2.0 loaded` (the version of the zip you installed).
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
- [ ] When Pathwise knows where a quest happens (QuestieDB or learned), the line shows the distance, e.g. `- 73 m` (or yards, see `/pw units`). Quests within about 300 yards come first, nearest first. Far steps (turn-ins included) come after the nearby work, as a route: the closest far step first, then always the closest one from there, so the guide doesn't send you across the zone and back. Walking somewhere else re-sorts the list within a few seconds, and the arrow follows the top line.
- [ ] Quest titles are colored like in the quest log (red, orange, yellow, green, grey). Orange quests say "(hard)".
- [ ] Hovering a line shows the quest's zone and objectives.
- [ ] The list updates on its own when you kill quest mobs, accept, turn in or abandon quests, change zone or level up.
- [ ] When a quest's last objective completes, chat says `Quest complete: <quest> - turn it in.` once.
- [ ] With spells to learn, a `Visit your trainer: N recommended spells (cost)` line appears between turn-ins and other quests.
- [ ] Collapsing a zone in the quest log adds a line asking you to expand it.

## In-game test checklist (navigation arrow)

- [ ] `/pw way 50 50 Test` shows an arrow near the top of the screen. It turns as you turn, is green when you face the target, yellow when it's to your side and red when it's behind you, and shows the distance in meters (`/pw units yards` switches to yards). Walking there prints `Arrived at Test.` and the arrow disappears.
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

## In-game test checklist (other classes)

Make a character of another class (any level works; a level 10+ one shows talents).

- [ ] The path prompt (or `/pw spec`) offers Leveling and the three trees of the class, with a tooltip for each. `/pw spec prot`, `/pw spec resto`, `/pw spec destro` and the like work.
- [ ] `/pw talents check` reports no problems (it compares the build with the client's talent names), and `/pw talents` lists sensible next points.
- [ ] `/pw training` at a new level lists the class's spells. A priest only sees the racial spells of its own race, a mage only its own faction's teleports. Druid bear and cat abilities appear once you have the form.
- [ ] Gear tooltips show upgrade percentages. A caster's wand counts. Below level 35, plate says "usable at level 40 - you'll have better gear by then" for warriors and paladins, and a rogue sees "not usable by your class" on axes.
- [ ] `/pw stats` on an item with spell damage, healing or mana per 5 lists those keys (please send me the output: it tells me whether the weights match).

## In-game test checklist (pet ability guide)

- [ ] With your pet out, `/pw pet` lists its name, family and level, and each ability it could have a higher rank of (e.g. `Claw (Rank 3): tame Den Mother (18, Darkshore), ...`), or says it already has the best ranks.
- [ ] Open Beast Training once (spellbook). Abilities your hunter already knows then show up as `Teach Claw (Rank 3) to <pet> in Beast Training` instead of a tame step.
- [ ] Otherwise Next Steps shows `Tame a <beast> (level ..) to learn <ability> (Rank ..)` (at most 2 of these, below quests). The arrow points to the nearest spawn spot when you click the step. Hover the step to read where it is and the stable reminder.
- [ ] Teaching the rank or leveling the pet updates the steps. Beasts above your level, elites and beasts in dungeons are never suggested.
- [ ] Settings > Pathwise > Features: "Hunter: pet ability guide" off removes the steps at once.

## In-game test checklist (M6 hunter module)

- [ ] Below 200 arrows, Next Steps shows `Low ammo: N arrows left` and chat warns once. Below 50 the warning is urgent (top of the list). An empty ammo slot shows `No ammo equipped!`.
- [ ] A gun says "bullets". A thrown weapon gives no ammo warnings.
- [ ] When your pet is content or unhappy, Next Steps shows `Feed <pet> (content)`. Hovering shows what it eats. Chat says it once when the mood drops. The line goes away once the pet is happy.
- [ ] At level 10, without Tame Beast, Next Steps shows the Taming the Beast step and chat reminds you once. With QuestieDB, the arrow points to your hunter trainer (Dazalar in Dolanaar for Night Elves). The step disappears once you've learned Tame Beast.

## In-game test checklist (window themes)

**Fully restart WoW** (exit the game, not just `/reload`) the first time. WoW only picks up new texture files on a client start. A green square instead of an ornament means a texture didn't load.

- [ ] The To-do window has the **Dragonflight** look by default: dark red background, 3 px red border, gold trim line, a header band with a small "PATHWISE" label and a centered "To-do" title, and painted gold dragon heads on the two top corners (see the v2 checklist below for the corner art).
- [ ] The step the arrow follows is highlighted, with a tinted row background, or a vertical bar in Corner Brackets.
- [ ] The footer shows `N steps · <zone>` on the left and the **Path** button on the right.
- [ ] `/pw theme` lists all 13 themes with numbers and marks the active one. `/pw theme 6` switches to Skyhawk immediately, with no `/reload`. `/pw theme next` cycles. No ornaments from the previous theme are left behind.
- [ ] Check each theme once: 1 Gilded Hairline (thin gold line, small diamonds, a diamond on the divider), 2 Classic Tooltip (Blizzard tooltip look, "Pathwise · To-do" on one line), 3 Moonlit (crescent next to the title), 4 Corner Brackets (no border, gold L-shapes in the corners), 5 Dragonflight, 6 Skyhawk (eagles), 7 Wildwood (branches with leaves on all four corners), 8 Phoenix Ember (feathers fanning out from all four corners).
- [ ] Quest names keep their difficulty colors in every theme.
- [ ] Esc > Options > AddOns > **Pathwise** (or `/pw settings`) shows **Appearance** with 8 buttons, each with a two-color swatch. The active one has a gold outline. Clicking one switches the theme right away.
- [ ] The chosen theme survives `/reload` and relog, and other characters use it too.
- [ ] Cycle `/pw theme next` 20-30 times: no errors, and no slowdown.

## In-game test checklist (painted corner art, Wildwood seasons)

From docs/PATHWISE_THEMES_V2.md. **Fully restart WoW** first (not just `/reload`): the corner art uses new texture files.

- [ ] No green squares in any theme: all 9 new textures load.
- [ ] Phoenix Ember (`/pw theme 13`): feathers fan outward from all four corners.
- [ ] Wildwood (`/pw theme 12`): dark wood border with a moss line inside. Branches lie along the top and side edges at all four corners; the bottom ones point down and outward. Green leaves by default.
- [ ] `/pw season autumn` swaps to autumn leaves right away and chat says `Wildwood season: Autumn`. `/pw season auto` uses autumn in September to November, summer otherwise. `/pw season summer` brings the green back.
- [ ] In the settings (`/pw settings`), a "Wildwood season" choice (Summer / Autumn / Auto) appears under the theme buttons only while Wildwood is active. Clicking one changes the leaves right away.
- [ ] The close button (X) is never covered by the art and still closes the window, in every theme.
- [ ] Cycle `/pw theme next` many times: no Lua errors and no art left over from the previous theme.

## In-game test checklist (portals and boats)

A `/reload` is enough.

- [ ] On top of Teldrassil, with a step in Rut'theran Village (e.g. turning in to Nessa Shadowsong): the arrow says `Take the portal to Rut'theran Village (in Darnassus)` with `then: <your step>` underneath, and points to the portal in Darnassus (30, 41), not down the tree. The distance is to the portal.
- [ ] At the portal it says `Take it here`. After the portal, the arrow points straight to the step.
- [ ] From Rut'theran back up: `Take the portal up to Darnassus`.
- [ ] From Darkshore to Teldrassil: `Take the boat to Rut'theran Village (Auberdine docks)`, then the portal up if needed. The other way: `Take the boat to Auberdine (Rut'theran docks)`.
- [ ] Steps in Rut'theran now count as far away when you're up on the tree, so walkable steps come first.
- [ ] Finish the zone before leaving: in Rut'theran with turn-ins still waiting on Teldrassil (or in Darnassus), the guide sends you back up through the portal before anything in Darkshore. "Flight to Auberdine" (turned in in Darkshore) is only suggested once Teldrassil is done; its tooltip says why.

## In-game test checklist (boats and zeppelins)

The dock positions are approximate (the zeppelin towers are exact): tell me if the arrow ends up far from a boat.

- [ ] Alliance, in Darkshore, with a step in the Wetlands or anywhere in the Eastern Kingdoms (or `/pw way` on that map): the arrow says `Take the boat to Menethil Harbor (Auberdine docks)` and leads to the southern pier. In Menethil the way back says `Take the boat to Auberdine (Menethil Harbor docks)`.
- [ ] From Dustwallow Marsh: `Take the boat to Menethil Harbor (Theramore docks)`, and from Menethil to Theramore the other pier.
- [ ] From the Barrens to Stranglethorn (and back): the Ratchet - Booty Bay boat, for both factions.
- [ ] Horde: from Durotar to Tirisfal or Stranglethorn the arrow leads to the tower outside Orgrimmar and names the zeppelin and its master (Frezza for Undercity, Snurk Bucksquick for Grom'gol). From Tirisfal to Stranglethorn: the Undercity - Grom'gol zeppelin (Hin Denburg). Alliance characters never get zeppelins, Horde ones never get the Menethil boats.
- [ ] With flight points known on the other side, the route goes boat first, then flight (e.g. Darkshore to Elwynn: boat to Menethil, then fly to Stormwind).
- [ ] Feralas (Alliance): steps in Feathermoon Stronghold lead to the ferry on the Forgotten Coast first.
- [ ] Quests on the other continent are now ordered by the real way there instead of being "can't measure".

## In-game test checklist (hearthstone)

A `/reload` is enough.

- [ ] Pathwise first has to learn where your hearthstone is set: walk through that town once, set it at an innkeeper, or use it once.
- [ ] In a zone with 4 or more quest steps while your hearthstone is set elsewhere, the To-do window shows `Set your hearthstone in Darkshore: talk to Innkeeper Shaussiy`. The tooltip says why; with QuestieDB the arrow points at the nearest innkeeper.
- [ ] Walking past the inn moves the step up so you can do it on the way.
- [ ] After "Make this inn your home" the step disappears.
- [ ] `/pw hearth off` turns the tips off.

## In-game test checklist (flight paths)

A `/reload` is enough.

- [ ] Talk to a flight master once (the flight map opens). `/pw flights` then lists the flight points you know, e.g. `Rut'theran Village, Auberdine`.
- [ ] On a long trip (roughly 800 m or more) where a known flight point is near you and another near the destination, the arrow says `Fly from Auberdine to <town> (<flight master>)` with your step underneath, and points at the flight master. Short trips stay on foot.
- [ ] From the top of Teldrassil to Darkshore with Rut'theran known: the portal first, then the flight from Rut'theran.
- [ ] During the flight the arrow points straight at your step; after landing it continues on foot.
- [ ] Discovering a new flight point (talking to its flight master) adds it right away.

## In-game test checklist (quest pickups)

Needs QuestieDB. A `/reload` is enough. The quest list is read a few seconds after login.

- [ ] The To-do window shows up to 4 `Pick up: [level] Quest - 27 m` lines for quests you can take now, nearest first. Hovering one says who gives it; under the current one it says `Get the quest from <NPC>`. Wanted posters count too.
- [ ] Only quests for your race and class, at your level (not grey, not red - no level 60 cloth donations at 12), not done before, and with their earlier quests done. No holiday, profession or repeatable quests.
- [ ] Nearby pickups (about 300 m) come right after nearby quest work; far ones join the route with your other far steps. The arrow and the target macro go to the quest giver.
- [ ] Taking the quest makes its pickup line disappear; turning in a quest can bring up its follow-up.
- [ ] No quests that aren't really offered (like "The Hunter's Path" from Jocaste at low level). If one shows up anyway, talk to the giver: when the quest isn't in their list, the line disappears and stays away until your next level.
- [ ] With nothing left to pick up on this continent and nothing to do in your log: `No quests left nearby: try Darkshore (10-20)`, with other zones for your level in the tooltip.
- [ ] `/pw pickups off` hides pickups and the zone suggestion; `/pw pickups on` brings them back.

## In-game test checklist (talent highlight)

A `/reload` is enough.

- [ ] With an unspent talent point, open the talent window (N). The recommended talent has a pulsing gold glow, and hovering it adds `Pathwise: recommended next point (rank 1/5)` to its tooltip.
- [ ] When the recommended talent is in another tree, that tree's tab at the bottom glows instead. Clicking the tab moves the glow onto the talent.
- [ ] After spending the point, the glow moves to the next recommended talent, or disappears when no points are left.

## In-game test checklist (professions)

A `/reload` is enough. The trainer arrow needs QuestieDB.

- [ ] At level 5 or higher, chat says once: `Professions for a Hunter: Skinning + Leatherworking`. `/pw professions` explains why, gives the gold option (Skinning + Mining), Engineering at 60 and the secondary professions, and lists your current skills.
- [ ] The To-do window shows `Learn professions: ...` with what you're missing. Hover it for the reasons. With QuestieDB, a few seconds after login the line gets a location: click it and the arrow points to the nearest trainer of your faction. Walking up to a trainer (about 300 yards) moves the step up and the arrow follows it.
- [ ] Once you have two primary professions (any two), the learn step only suggests First Aid, or disappears.
- [ ] With Skinning but no Skinning Knife in your bags: `Buy a Skinning Knife (needed for Skinning)`. It goes away when the knife is in your bags. Same for Mining (Mining Pick).
- [ ] At skill 50 and level 10: `Train Journeyman Skinning (52/75)`. When the skill reaches the cap (75/75) the step moves up and says skill-ups are wasted. Expert (skill 125, level 20) and Artisan (200, level 35) work the same way.
- [ ] With Skinning, hovering a beast shows `Pathwise: Skinning 50 needed (you have 52)`, green when you can skin it and red when you can't. Not on humanoids, and not without Skinning.
- [ ] `/pw professions off` hides all profession steps and tooltip lines; `/pw professions on` brings them back.

## In-game test checklist (3D arrow)

**Fully restart WoW** first (not just `/reload`): the arrow uses a new texture file. A green square instead of the arrow means it didn't load.

- [ ] The guide arrow is a solid, lit 3D arrowhead with a dark outline and a soft shadow, tilted as if lying on the ground in front of you.
- [ ] Turning your character turns the arrow smoothly, and you see its sides and back when it points sideways or toward you.
- [ ] The color fades from green (ahead) through yellow (to the side) to red (behind you).
- [ ] Label, distance and the Next button sit below the arrow without overlapping it.

## In-game test checklist (emblem themes)

From docs/PATHWISE_THEMES_V3.md. **Fully restart WoW** first (not just `/reload`): there are 14 new texture files.

- [ ] No green squares in any of the 13 themes.
- [ ] The 7 emblem themes have a gold head on both top corners, facing outward on both sides and overlapping the corner (not floating away from it), and a gem centered on each bottom corner: 5 Dragonflight (dragon, ruby), 6 Skyhawk (eagle, sapphire), 7 Ironhorn (bull, topaz), 8 Frostfang (wolf, ice), 9 Lionheart (lion, amethyst), 10 Moonwatch (owl, moonstone), 11 Phoenix Crest (phoenix, ember gem).
- [ ] The close button (X) is visible and works in all 13 themes.
- [ ] `/pw theme` lists all 13 with numbers. `/pw theme 9`, `/pw theme frostfang` and `/pw theme next` work.
- [ ] `/pw settings` shows the 13 theme buttons in a grid of 3 columns (5 rows), with the Wildwood season choice under it when Wildwood is active. Nothing runs off the panel, and long names fit or end in "...".
- [ ] Cycle `/pw theme next` through all 13 a couple of times: no Lua errors and no art left over.

## In-game test checklist (window size, minimap button)

- [ ] Long lines in the To-do window stay on one line and end in "...". They no longer wrap into the next row.
- [ ] Dragging the size grip in the bottom-right corner resizes the window. The rows adapt while you drag, and the steps that don't fit show as "... and N more". Right-clicking the grip goes back to automatic height. The size survives `/reload`.
- [ ] A Pathwise map icon sits on the minimap's edge. Left-click shows or hides the To-do window, right-click opens the settings, and dragging moves it around the edge. Its position survives `/reload`.
- [ ] `/pw minimap` and the "Show minimap button" checkbox in the settings hide and show it.
- [ ] Key Bindings > Pathwise > "Show/hide the To-do window" works.

## Things to verify in game (marked `TODO verify` in code)

- `UnitCharacterPoints("player")` returns unspent talent points. This can only be checked from level 10.
- The talent tab order for each non-hunter class in `Data/Classic/ClassSpecs.lua` (`/pw talents check` on each class). The hunter order is verified.
- The "Equip:" stat keys for casters and tanks (spell damage, healing, mana per 5, defense, block): `/pw stats` on such an item shows which keys the client reports (`Data/Classic/StatWeights.lua`).
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
- Theme details that need a look in game: ornament positions and sizes, the close button next to the top-right creature, and whether 1 px lines look sharp. The settings panel registration, through the Settings API or legacy Interface Options.
- Whether `PLAYER_TALENT_UPDATE` exists in Classic Era. If it doesn't, `/pw debug` reports it once and Pathwise continues normally.

## Development

- Layers: `Platform/` is the only place that calls flavor-specific WoW API. `Core/` holds the logic and never calls the WoW API directly. `UI/` may use frame and tooltip APIs. `Data/` holds plain tables.
- Offline smoke tests run against a small mock of the WoW API. Run `lua5.1 tests/run.lua` from the repo root, and set `PATHWISE_ECHO=1` to see chat output. These tests catch Lua errors and logic bugs, but they don't replace testing in game.
- Quest locations can come from [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0). It's an optional dependency read at runtime through its public `LibQuestieDB` API; Pathwise ships none of its data.
- Pet ability ranks and the beasts that teach them come from [LibTameable-1.0](https://github.com/Langmans/LibTameable-1.0) by Langmans (GPL-3.0), embedded in `Libs/` with its license. Its data is built from [CMaNGOS](https://github.com/cmangos) (GPL-3.0) and Tamed (MIT; see `Libs/LibTameable-1.0/Data/Tamed-LICENSE.txt`). [LibStub](https://www.wowace.com/projects/libstub) is public domain.
- Class trainer data (`Data/Classic/ClassSpells.lua`) is based on [WhatsTraining](https://github.com/fusionpit/WhatsTraining) by fusionpit, MIT License. English spell names for the other classes come from the [vmangos](https://github.com/vmangos/core) world database.
- Talent positions in the builds were checked against the Classic talent data of [wowsims](https://github.com/wowsims/sod) (MIT).
- The `tests/` and `docs/` folders aren't listed in the TOC, so WoW ignores them.

## In-game test checklist (target button, spawn spots)

- [ ] With a kill or loot quest (e.g. Webwood Venom), a target button with a crosshair icon and `Target: Webwood Spider` shows up. Clicking it targets the nearest Webwood Spider and marks it with a skull. Needs QuestieDB.
- [ ] The button hides for turn-ins and when no quest needs a mob. Changes during combat happen right after the fight.
- [ ] Drag the button to move it (not in combat). Its position survives `/reload`.
- [ ] `/pw targetbutton` and the "Show target button for quest mobs" checkbox in the settings turn it off and on.
- [ ] When the arrow points at a mob's spawn spot it shows no distance, and `Look around here` once you get there. Objects that stay put (a moonwell, a herb, an ore vein), turn-ins and your own waypoints show the distance.

## License

Pathwise is released under the GNU General Public License v3.0 or later (see [LICENSE](LICENSE)), because it embeds LibTameable-1.0, which is GPL-3.0.
