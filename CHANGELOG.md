# Changelog

Newest first. The release workflow uses the section for the version it
publishes as the release notes.

## 0.24.0

- The target button and the Pathwise macro go through the kinds of mobs
  of a "Do together" step in turn: once you've targeted one kind (say a
  Small Crag Boar), the next click goes for the next kind (Rockjaw Trogg),
  and so on, back to the first. The button's label names the one it goes
  for next. When that kind isn't around, it targets one of the others, as
  before. A change made in a fight waits until the fight ends (the game
  doesn't allow changing them in combat).

## 0.23.1

- "On the way" hints are now only in the To-do list, under the step the
  arrow follows. The arrow keeps its short label (two hints under it were
  too much text).

## 0.23.0

- **On the way**: when the way to your next step passes the mobs or objects
  of another quest you're on, the arrow says so under its label, e.g.
  `On the way: Kill Rockjaw Trogg (A New Threat)`, and the same line shows
  under the step in the To-do list. It counts spawns within about 50 yards
  of the straight line to the target, names at most two quests, and is
  worked out again as you move. Not for routes that go around something
  (much longer than the straight line, like a boat), quests for later, or
  targets right next to you. Needs QuestieDB.

## 0.22.1

Fixes from a check of auto turn-in:

- Full bags: the reward is no longer "taken" when it can't fit (it failed
  and the window stayed open, and every visit to the NPC opened the quest
  again, so its vendor or other options were out of reach). Chat says to
  make room and take it yourself; the quest is opened from the list again
  once your bags change.
- Quests without objectives (escorts, "Report to ...") are only opened
  from the giver's list when the giver marks them complete. An unfinished
  escort could be opened and leave you stuck in its "not done yet"
  window.

## 0.22.0

- **Auto turn-in**: talking to the NPC of a finished quest, Pathwise opens
  it from the list (before any new quest, so a follow-up can be accepted
  right after), completes it and takes the reward - unless there are
  rewards to choose from: then the window stays open with the best one
  highlighted, as before. "Report to ..." quests are handed in too.
  Never for quests that aren't in your quest log (repeatable item hand-ins
  you may want to keep), quests that ask for gold, or while you hold
  **Shift**. Switch it off on the Features page ("Turn in finished
  quests").

## 0.21.2

Fixes from a check of the dungeon guide:

- Repeatable quests (like Dire Maul's tributes) no longer count as
  dungeon quests: they never count as done, so the dungeon could never
  say "You've done every quest" and the quest counts in the list were too
  high.
- A dungeon with no quests for your race and class says so, instead of
  "You've done every quest".
- Inside: a boss loot objective names the boss even when other mobs drop
  the item too; a dungeon quest QuestieDB has no objectives for still
  shows, with the game's own objective text; Blackrock Spire counts even
  if the game calls it a raid instance.
- Auto-accept in dungeon mode takes the dungeon's quests and pre-quests
  whatever their level (as the dungeon list suggests them), and never
  another quest by mistake.
- Dungeon mode learns "the giver doesn't offer it" like the normal guide,
  so a pre-quest that isn't really there stops being suggested.
- With an older QuestieDB that can't list its quests, dungeon mode says so
  instead of "Reading the quest data..." forever.
- The window title no longer redraws the To-do window twice when it
  changes.

## 0.21.1

- Dungeon mode is a toggle now: the footer button in the To-do window says
  what a click switches to - "Dungeon mode" (the last dungeon you picked)
  or "Normal mode" - and one click switches. Right-click it to pick another
  dungeon. Also a key binding (Key Bindings > AddOns > Pathwise) and
  `/pw dungeon toggle`. Chat explains dungeon mode once, then just says the
  mode.
- The arrow's "Next" button is now a small, dim "Next »" text link under
  the distance - brighter and underlined on hover, with a tooltip - instead
  of the big red button.

## 0.21.0

- **Inside dungeons**: the To-do list guides you through the dungeon
  (the game gives addons no position inside, so there's no arrow there). It
  shows one step per boss your quests need, in the dungeon's usual order
  and with where to find it - e.g. "Boss 7 of 8: Edwin VanCleef - the top
  deck of the ship" - with what to do and for which quest underneath; the
  objectives on other mobs "along the way"; and the finished quests to turn
  in afterwards. Works in every classic dungeon, with or without dungeon
  mode (boss orders for all 19 dungeons, names checked against QuestieDB).

## 0.20.1

- Dungeon guide: the entrance is no longer the first step when you're far
  below the dungeon (reported with The Deadmines at a low level). It waits
  at the bottom ("from level 17") until you're within 2 levels of the
  dungeon's range, and even then comes after the quests and pre-quests.
- "Later" now shows where each quest chain starts once you're high enough
  - quest, level, giver and zone (e.g. The Defias Brotherhood from level
  14, Gryan Stoutmantle in Westfall) - instead of only the dungeon's own
  quests at the end of the chains.

## 0.20.0

- **Dungeon guide**: "Dungeons" in the To-do window footer (or
  `/pw dungeon`) lists the classic dungeons for your faction with their
  level range and how many of their quests you have left. Pick one and the
  To-do list turns into **dungeon mode** ("Dungeon: The Deadmines"): only
  that dungeon's quests to pick up, the pre-quests that unlock them
  (followed back through their chains, whatever their zone or level), the
  pre-quests and dungeon quests in your log, the way to the entrance with
  the arrow on it, and the dungeon quests that come at a higher level.
  "Leave dungeon mode" (or `/pw dungeon off`) brings the usual guide back.
  Needs QuestieDB; dungeon entrances are QuestieDB's.

## 0.19.0

- **Auto-accept**: talking to a quest giver, the quests the guide suggests
  are accepted without clicking - the quests to pick up (the same rules as
  the "Pick up" steps, wherever the giver is, so the next part of a chain
  counts too) and your class quests. With several quests in the giver's
  list, the suggested one is opened. Hold **Shift** while talking to skip
  it; switch it off on the Features page. Quests shared by other players
  are never accepted.

## 0.18.4

- Class quest reminders no longer jump ahead of everything: with the
  quest giver known, they join the quest plan like any quest to pick up,
  ordered by distance, with the distance shown. A fresh warlock in
  Coldridge Valley now gets the quest 23 m away first instead of the arrow
  pointing at the Imp quest 173 m off. Important ones (stances, demons,
  forms, totems, poisons, mounts) still go on the route even outside the
  zone you're in.

## 0.18.3

- Azure: the window's resize grip moved inside the window, just above the
  bottom-right corner gem, so it no longer darkens the gem. The other
  themes keep it in the corner.

## 0.18.2

- The Auberdine - Menethil Harbor boat: dock positions measured in game
  (Auberdine 32.4, 43.8; Menethil 4.7, 57.2).

## 0.18.1

- Gear advice for healers and casters: the game names some "Equip:"
  bonuses without the `_SHORT` ending Pathwise expected (seen in game:
  `ITEM_MOD_SPELL_HEALING_DONE` on Pagan Belt of Healing), so +healing
  counted for nothing. Both spellings are matched now.

## 0.18.0

- **Azure theme** (docs/PATHWISE_THEMES_V4.md), matching the Pathwise logo:
  deep blue enamel with a shine at the top, antique-gold rune bands that
  repeat along all four edges, gold corner plates with blue gems, a compass
  crest on the top edge, a gem in the header divider and a new current-step
  highlight (fill with a gold bar on the left). Azure is first in the theme
  list, so the theme numbers moved up by one; your saved theme stays.
- **Fully restart WoW** (not just /reload) so the 7 new textures load.

## 0.17.1

Fixes from a check of the features since 0.14.0:

- Smoother frame rate: the arrow no longer works out the whole way (with
  boats, zeppelins and flights) 20 times a second; it does so for a new
  target, after moving 10 yards or every 2 seconds.
- Faster distances: the ways through portals, boats and zeppelins are
  searched once per position and reused for every spawn, giver and
  trainer that is measured; the pet guide measures each map once instead
  of every spawn pin.
- Trainer: spells that need another spell now also count a higher rank of
  it (e.g. Greater Blessing of Might once you know Blessing of Might rank
  7), or learning it in the same visit; and "coming soon" leaves out
  spells that need something from a class quest you haven't done (bear
  abilities without Bear Form).
- Troll priests no longer get the Touch of Weakness quest reminder (the
  quest data listed Trolls for one of its quests; the spell is Undead
  only).
- Pet guide: pet spell IDs with extra flag bits are read correctly.
- Talent advisor: a talent split over two picks shows its full rank count
  even if the client's talent can't be found.
- The Warhorse and Felsteed reminders say the quest saves you buying a
  mount (riding may still cost gold).

## 0.17.0

- **Class quest reminders** for every class besides the hunter (who
  already had the taming quest): Defensive and Berserker Stance, Redemption,
  The Tome of Valor and the paladin Warhorse, rogue Poisons, the priest
  racial spells for your race, the four shaman totems, the warlock demons
  and Felsteed, and the druid Bear Form, Cure Poison and Aquatic Form.
  From the quest's level, Next Steps shows the step with the arrow on the
  nearest quest giver for your race; once the quest is in your log, the
  quest itself takes over, and the reminder is gone once you've learned
  the spell. Switch them off on the Features page.

## 0.16.0

- **Boats and zeppelins**: the arrow and the step order now know every
  boat and zeppelin between the continents - Auberdine and Theramore to
  Menethil Harbor (Alliance), Ratchet to Booty Bay (everyone), and the
  zeppelins between Orgrimmar, Undercity and Grom'gol (Horde) - plus the
  Feathermoon Stronghold ferry. Each faction only gets its own docks and
  towers.
- On the other side the way can go on by flight (e.g. boat to Menethil,
  then fly to Stormwind), and the Undercity - Grom'gol zeppelin is used
  when it beats walking across the Eastern Kingdoms.
- A waypoint on another continent no longer shows "Can't point from here":
  the arrow leads to the first portal, boat or zeppelin of the way.

## 0.15.0

- **All classes**: warriors, paladins, rogues, priests, shamans, mages,
  warlocks and druids now get the same help as hunters:
  - the trainer reminder and Training list with every class spell (racial
    priest spells and faction teleports only for those who can learn them;
    bear and cat abilities once you have the form);
  - three talent builds each (a leveling build and one per other tree),
    picked by your path or your talents;
  - gear advice with stat weights per path (spell damage, healing and mana
    per 5 for casters, avoidance for tanks, wands for priests, mages and
    warlocks) and what the class can wear or wield.
- The path prompt offers each class's own trees, with a description for
  each, and `/pw spec` takes short names like `prot`, `resto` or `destro`.
- Talent builds can now spread a talent over two picks (e.g. 2 points now,
  3 later).

## 0.14.0

- **Pet ability guide** (hunters): Next Steps shows which ability ranks
  your pet can learn at its level and how - `Teach Claw (Rank 3)` when
  your hunter already knows it, otherwise `Tame a Den Mother (level
  18-19) to learn Claw (Rank 3)` with the arrow on the nearest spawn spot
  (normal beasts first, never elites, dungeons or beasts above your
  level). Open Beast Training once so Pathwise knows what you've learned.
  `/pw pet` lists everything; it can be switched off on the Features page.
- Pathwise is now licensed under GPL-3.0-or-later. It embeds LibTameable-1.0
  (GPL-3.0, data from CMaNGOS and Tamed) and LibStub; see the README.

## 0.13.0

- Settings > Pathwise > **Features** (or `/pw features`): switch single
  features on or off, right away, without /reload - quest guide, quest
  pickups, hearthstone tips, trainer reminder, the Training list, talent
  advice, gear tooltips, the quest reward highlight, sell prices,
  profession advice, the target macro, hunter reminders, the pet guide and
  chat messages.

## 0.12.1

Fixes from a full check of the addon:

- Modules switched off in the saved settings no longer react to anything.
- Faster while moving: picking the nearest mob spawn, quest giver, trainer
  or innkeeper no longer tries flight routes for every point, and the
  flight master and innkeeper lists are built once instead of every update.
- Expert and Artisan First Aid, Cooking and Fishing: no arrow to a trainer
  (they come from a book and a quest); the step says so.
- With the Professions header collapsed in the skills window (which hides
  those skills from addons), Pathwise no longer suggests learning
  professions you may already have.
- Hearthstone: the arrival after using it is recorded once you've really
  arrived (also after a loading screen), Astral Recall counts too, no tip
  when QuestieDB knows no inn in the zone, and the innkeeper arrow appears
  as soon as the NPC list is ready.

## 0.12.0

- Hearthstone tip: when you have 4 or more quest steps in a zone and your
  hearthstone is set somewhere else, the To-do window suggests setting it
  at an inn here, with the arrow to the nearest innkeeper (QuestieDB). It
  moves up when you pass the inn. Pathwise learns where your hearthstone
  is set when you set it, use it, or walk through that town.
  `/pw hearth off` turns it off.

## 0.11.2

- Boats now count the time spent sailing (and waiting for the boat), not
  just the walk to the dock. From Rut'theran the arrow suggests the
  flight to Auberdine when you know it, instead of the slower boat.

## 0.11.1

- Quest pickups skip quests far above your level (red), like the level 60
  cloth donations ("A Donation of Wool") that can be picked up at 12.

## 0.11.0

- Flight paths: Pathwise remembers the flight points your character knows
  (they're read each time you talk to a flight master; `/pw flights` lists
  them). On long trips it suggests flying when that's clearly faster:
  "Fly from Auberdine to <town> (<flight master>)", with a portal first
  when needed. Distances used to order steps count the flight too.

## 0.10.2

- Finish the zone before leaving: far steps in your current zone (its
  capital included, e.g. Darnassus for Teldrassil) come before steps in
  other zones, and a quest to pick up that's turned in in another zone
  (like "Flight to Auberdine") waits until the zone is done. Teldrassil
  turn-ins are no longer left behind when you reach Rut'theran.

## 0.10.1

- Quest pickups no longer suggest quests that aren't really offered, like
  "The Hunter's Path" from Jocaste:
  - with the Questie addon loaded, Questie's own check decides (its list
    of quests that are in the database but not in the game, breadcrumbs,
    reputation, events, ...);
  - quests whose later chain quest (or breadcrumb target) is already done
    or in your log are skipped;
  - when you talk to a quest giver and a suggested quest isn't in their
    list, Pathwise remembers it and only tries again after a level up.

## 0.10.0

- The arrow knows about portals and boats: Rut'theran Village is reached
  through the portal in Darnassus (and back up), and Teldrassil and
  Darkshore through the Rut'theran-Auberdine boat. When a step can't be
  walked to, the arrow leads to the portal or boat first and says which
  one, with the step underneath.
- Distances used to order steps (and to pick the nearest quest giver,
  trainer or spawn) follow these routes, so a step "right below" but
  behind a portal no longer counts as close.

## 0.9.0

- Quest pickups (needs QuestieDB): the To-do window suggests up to 4
  quests you can pick up now, nearest first - right race, class and level,
  not done before, earlier quests in the chain done. The arrow and target
  macro point at the quest giver, and pickups join the same near-first
  route as your other steps.
- When nothing is left to pick up on your continent and nothing to do in
  your log, it suggests zones for your level.
- `/pw pickups off` turns it off.

## 0.8.1

- Settings: a "Distances" choice (Meters / Yards) under General, next to
  the `/pw units` command. The arrow and the To-do window switch right away.

## 0.8.0

- The talent window highlights the recommended talent for your next point
  with a pulsing gold glow, and its tooltip says so. When it's in another
  tree, that tree's tab glows instead.

## 0.7.3

- Hunter taming: once a Taming the Beast quest is in your log, the "Get
  your pet" step (and its arrow to the trainer) goes away; the quest
  itself is the step to follow.
- Quest tasks use the quest's own wording when it isn't a plain kill, e.g.
  "Tame a Webwood Lurker" instead of "Kill Webwood Lurker".

## 0.7.2

- Quest rewards: an upgrade that needs training (or a higher level) first
  only wins if it's a big upgrade (10% or more). A smaller one loses to the
  reward that sells for the most, and chat says which upgrade was passed
  over and why.

## 0.7.1

- Gear you can only use more than 5 levels from now (like mail before 40)
  is no longer called an upgrade. The tooltip says "usable at level 40 -
  you'll have better gear by then", and the quest reward picker goes for
  the best sell value instead. Items within 5 levels still show
  "upgrade at level X".

## 0.7.0

- Distances are shown in meters (`/pw units yards` switches back to
  yards), in the To-do window and on the arrow.
- The arrow shows the distance to fixed places such as a moonwell, herb or
  ore vein. Only mob spawn spots (the mob wanders) still have none.

## 0.6.1

- Gear advisor: armor counted for much less against stats. 1 Stamina now
  equals about 40 armor (it was 10), so an item with +1 Stamina and a bit
  less armor is no longer shown as a downgrade. Between items without
  stats, more armor still wins.

## 0.6.0

- Professions: a recommendation for your class (for hunters Skinning +
  Leatherworking, or Skinning + Mining for gold, Engineering at 60), shown
  once in chat and in `/pw professions`.
- To-do steps: learn the recommended professions, train the next rank
  (Journeyman, Expert, Artisan) when you can - higher up when your skill is
  at the cap - and buy the tool gathering needs (Skinning Knife, Mining
  Pick). With QuestieDB the arrow points to the nearest trainer.
- Beast tooltips show the Skinning skill needed, green or red.
- `/pw professions off` hides it all. Two primary professions of your own
  choice end the suggestions.

## 0.5.0

- The guide arrow is now 3D: a lit, faceted arrowhead tilted as if lying
  on the ground, in 64 pre-rendered directions, with an outline and a
  soft shadow. Its color fades from green (ahead) through yellow (to the
  side) to red (behind you).
- **Fully restart WoW** (not just `/reload`) after updating: the arrow
  texture is a new file.

## 0.4.1

- Far quest steps are now planned as a route: the guide goes to the
  closest one first, then always to the closest one from there. A far
  turn-in in one direction no longer comes before a much closer quest in
  the other direction. Turn-ins still get a small head start.

## 0.4.0

- Dragonflight and Skyhawk get clean gold emblem heads (dragon, eagle) with
  new gems, replacing the sculpted heads from 0.3.0.
- Five new emblem themes: Ironhorn (bull), Frostfang (wolf), Lionheart
  (lion), Moonwatch (owl) and Phoenix Crest (phoenix). 13 themes in all.
- The settings show the theme buttons in a 3-column grid.
- **Fully restart WoW** (not just `/reload`) after updating: the new
  textures are only found on a client start.

## 0.3.0

- Painted, full-color corner art for Dragonflight (dragon heads, rubies),
  Skyhawk (eagle heads, sapphires), Wildwood (branches) and Phoenix Ember
  (feathers). The other four themes are unchanged.
- Wildwood seasons: summer or autumn leaves, or auto (autumn in
  September-November). `/pw season summer|autumn|auto` or the settings.
- New Wildwood colors: dark wood border with a moss line.
- The close button always stays visible above the corner art.
- **Fully restart WoW** (not just `/reload`) after updating: the new
  textures are only found on a client start.

## 0.2.0

- Floating target button for quest mobs (`/pw targetbutton`, settings checkbox)
- The arrow shows no distance on mob spawn spots ("Look around here" on arrival)
- Bug fixes from a full code review: To-do window resizing, footer text,
  overflow line, minimap button, `/pw reset`
- Window themes, resizable To-do window, minimap button
