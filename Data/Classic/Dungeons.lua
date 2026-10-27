local addonName, Pathwise = ...

-- Classic Era dungeons for the dungeon guide (Core/DungeonGuide.lua), in
-- level order.
--   id         the dungeon's area ID (what QuestieDB tags its quests with,
--              as zoneOrSort)
--   alt        more area IDs its quests may be tagged with
--   min, max   the usual level range
--   faction    only listed for that faction (it's in their capital)
--   entrances  { areaId, x, y } with x, y 0-100 on that zone
-- Area IDs, alternative IDs and entrances are from QuestieDB's dungeon
-- table (support/Zones/dungeons.lua, GPL-3.0); level ranges are the usual
-- ones from leveling guides.

Pathwise.Data.Dungeons = {
  { id = 2437, name = "Ragefire Chasm", min = 13, max = 18, faction = "Horde", entrances = { { 1637, 52.6, 49 } } },
  { id = 718, name = "Wailing Caverns", min = 17, max = 24, entrances = { { 17, 46, 36.5 } } },
  { id = 1581, name = "The Deadmines", alt = { 10029 }, min = 17, max = 26, entrances = { { 40, 42.5, 71.7 } } },
  { id = 209, name = "Shadowfang Keep", alt = { 10014, 10015, 10016, 10017, 10018, 10019 }, min = 22, max = 30,
    entrances = { { 130, 44.8, 67.8 } } },
  { id = 719, name = "Blackfathom Deeps", alt = { 10020, 10021 }, min = 24, max = 32, entrances = { { 331, 14.5, 14.2 } } },
  { id = 717, name = "The Stockade", min = 24, max = 32, faction = "Alliance", entrances = { { 1519, 42.3, 58.9 } } },
  { id = 721, name = "Gnomeregan", alt = { 133, 10030, 10031, 10032 }, min = 29, max = 38, entrances = { { 1, 24.3, 39.8 } } },
  { id = 491, name = "Razorfen Kraul", alt = { 1717 }, min = 29, max = 38, entrances = { { 17, 42.9, 90.2 } } },
  { id = 796, name = "Scarlet Monastery", alt = { 6109, 6386, 10008, 10009, 10010 }, min = 34, max = 45,
    entrances = { { 85, 82.6, 33.8 } } },
  { id = 722, name = "Razorfen Downs", min = 37, max = 46, entrances = { { 17, 49, 93.9 } } },
  { id = 1337, name = "Uldaman", alt = { 1517, 10033 }, min = 41, max = 51, entrances = { { 3, 44.6, 12.1 }, { 3, 65.2, 43.5 } } },
  { id = 1176, name = "Zul'Farrak", alt = { 978 }, min = 44, max = 54, entrances = { { 440, 38.7, 20.1 } } },
  { id = 2100, name = "Maraudon", alt = { 10000 }, min = 46, max = 55, entrances = { { 405, 29.1, 62.5 } } },
  { id = 1477, name = "The Temple of Atal'Hakkar", alt = { 1417 }, min = 50, max = 56, entrances = { { 8, 69.9, 53.5 } } },
  { id = 1584, name = "Blackrock Depths", alt = { 1585 }, min = 52, max = 60,
    entrances = { { 51, 34.8, 85.3 }, { 46, 29.4, 38.3 } } },
  { id = 2557, name = "Dire Maul", min = 55, max = 60, entrances = { { 357, 59.2, 45.1 } } },
  { id = 1583, name = "Blackrock Spire", alt = { 10003, 10004, 10005, 10006, 10007 }, min = 55, max = 60,
    entrances = { { 51, 34.8, 85.3 }, { 46, 29.4, 38.3 } } },
  { id = 2057, name = "Scholomance", alt = { 10011, 10012, 10013 }, min = 58, max = 60, entrances = { { 28, 69.7, 73.2 } } },
  { id = 2017, name = "Stratholme", min = 58, max = 60, entrances = { { 139, 31.3, 15.7 }, { 139, 47.9, 23.9 } } },
}
