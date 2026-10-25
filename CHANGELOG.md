# Changelog

Newest first. The release workflow uses the section for the version it
publishes as the release notes.

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
