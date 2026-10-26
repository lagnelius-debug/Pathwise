# Changelog

Newest first. The release workflow uses the section for the version it
publishes as the release notes.

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
