local addonName, Pathwise = ...

-- Class quests that teach something important (Classes/ClassQuests.lua):
-- stances, forms, demons, totems, poisons, the free mounts. The hunter's
-- taming quests are in Classes/Hunter.lua.
--
-- Entry: { key, level, spell, name, item, skill, important, starts, finals, chain }
--   key        locale keys CQ_<key> (step) and CQ_<key>_DETAIL
--   level      level the quest can be picked up
--   spell      a spell the quest teaches (rank 1); name is its English name,
--              to find the higher ranks in Data.ClassSpells
--   item       an item the quest gives (a totem); with no spell, having it
--              means done
--   skill      a skill the quest teaches (rogue Poisons)
--   important  a top step; the others come after the quests
--   starts     first quests of the chain -> RequiredRaces mask (0: anyone);
--              the arrow goes to the nearest giver of one for your race
--   finals     the last quests (done once one is completed)
--   chain      every quest of the chain: while one is in the quest log, the
--              quest itself is the step to follow
--
-- Quest IDs, levels, races and chains are from the vmangos world database
-- (quest_template: the class quests whose reward teaches a spell),
-- following PrevQuestId / NextQuestId back to the first quests. (One
-- Touch of Weakness quest, 5659, says Undead and Troll there; the spell is
-- Undead only, so it's Undead here.)

Pathwise.Data.ClassQuests = {
  WARRIOR = {
    -- Defensive Stance, Sunder Armor, Taunt
    { key = "DEFENSIVE_STANCE", level = 10, spell = 71, name = "Defensive Stance", important = true,
      starts = { [1505] = 178, [1638] = 77, [1679] = 77, [1684] = 77, [1818] = 178 },
      finals = { 1498, 1665, 1678, 1683, 1819 },
      chain = { 1498, 1505, 1638, 1639, 1640, 1665, 1678, 1679, 1683, 1684, 1818, 1819 },
    },
    -- Berserker Stance, Intercept
    { key = "BERSERKER_STANCE", level = 30, spell = 2458, name = "Berserker Stance", important = true,
      starts = { [1718] = 0 },
      finals = { 1719 },
      chain = { 1718, 1719 },
    },
  },
  PALADIN = {
    -- Redemption
    { key = "REDEMPTION", level = 12, spell = 7328, name = "Redemption", important = true,
      starts = { [1641] = 1, [1645] = 4 },
      finals = { 1785, 1788 },
      chain = {
        1641, 1642, 1643, 1644, 1645, 1646, 1647, 1648, 1778, 1779, 1780, 1781,
        1783, 1784, 1785, 1786, 1787, 1788,
      },
    },
    -- Sense Undead, Verigan's Fist
    { key = "TOME_OF_VALOR", level = 20, spell = 5502, name = "Sense Undead",
      starts = { [1649] = 77 },
      finals = { 1652 },
      chain = { 1649, 1650, 1651, 1652 },
    },
    -- Summon Warhorse
    { key = "WARHORSE", level = 40, spell = 13819, name = "Summon Warhorse", important = true,
      starts = { [1661] = 77 },
      finals = { 1661 },
      chain = { 1661 },
    },
  },
  ROGUE = {
    -- the Poisons skill
    { key = "POISONS", level = 20, spell = 2842, name = "Poisons", skill = "Poisons", important = true,
      starts = { [2360] = 77, [2460] = 178 },
      finals = { 2359, 2480 },
      chain = { 2359, 2360, 2458, 2460, 2478, 2479, 2480 },
    },
  },
  PRIEST = {
    -- Human, Dwarf
    { key = "DESPERATE_PRAYER", level = 10, spell = 13908, name = "Desperate Prayer",
      starts = { [5634] = 5, [5635] = 5, [5636] = 5, [5637] = 5, [5638] = 5, [5639] = 5, [5640] = 5 },
      finals = { 5634, 5635, 5636, 5637, 5638, 5639, 5640 },
      chain = { 5634, 5635, 5636, 5637, 5638, 5639, 5640 },
    },
    -- Night Elf
    { key = "STARSHARDS", level = 10, spell = 10797, name = "Starshards",
      starts = { [5627] = 8, [5628] = 8, [5629] = 8, [5630] = 8, [5631] = 8, [5632] = 8, [5633] = 8 },
      finals = { 5627, 5628, 5629, 5630, 5631, 5632, 5633 },
      chain = { 5627, 5628, 5629, 5630, 5631, 5632, 5633 },
    },
    -- Troll
    { key = "HEX_OF_WEAKNESS", level = 10, spell = 9035, name = "Hex of Weakness",
      starts = { [5652] = 128, [5654] = 128, [5655] = 128, [5656] = 128, [5657] = 128 },
      finals = { 5652, 5654, 5655, 5656, 5657 },
      chain = { 5652, 5654, 5655, 5656, 5657 },
    },
    -- Undead
    { key = "TOUCH_OF_WEAKNESS", level = 10, spell = 2652, name = "Touch of Weakness",
      starts = { [5658] = 16, [5659] = 16, [5660] = 16, [5661] = 16, [5662] = 16, [5663] = 16 },
      finals = { 5658, 5659, 5660, 5661, 5662, 5663 },
      chain = { 5658, 5659, 5660, 5661, 5662, 5663 },
    },
    -- Dwarf
    { key = "FEAR_WARD", level = 20, spell = 6346, name = "Fear Ward",
      starts = { [5641] = 4, [5645] = 4, [5647] = 4 },
      finals = { 5641, 5645, 5647 },
      chain = { 5641, 5645, 5647 },
    },
    -- Troll
    { key = "SHADOWGUARD", level = 20, spell = 18137, name = "Shadowguard",
      starts = { [5642] = 128, [5643] = 128, [5680] = 128 },
      finals = { 5642, 5643, 5680 },
      chain = { 5642, 5643, 5680 },
    },
    -- Undead
    { key = "DEVOURING_PLAGUE", level = 20, spell = 2944, name = "Devouring Plague",
      starts = { [5644] = 16, [5646] = 16, [5679] = 16 },
      finals = { 5644, 5646, 5679 },
      chain = { 5644, 5646, 5679 },
    },
    -- Night Elf
    { key = "ELUNES_GRACE", level = 20, spell = 2651, name = "Elune's Grace",
      starts = { [5672] = 8, [5673] = 8, [5674] = 8, [5675] = 8 },
      finals = { 5672, 5673, 5674, 5675 },
      chain = { 5672, 5673, 5674, 5675 },
    },
    -- Human
    { key = "FEEDBACK", level = 20, spell = 13896, name = "Feedback",
      starts = { [5676] = 1, [5677] = 1, [5678] = 1 },
      finals = { 5676, 5677, 5678 },
      chain = { 5676, 5677, 5678 },
    },
  },
  SHAMAN = {
    -- Earth Totem, Stoneskin Totem
    { key = "EARTH_TOTEM", level = 4, spell = 8071, name = "Stoneskin Totem", item = 5175, important = true,
      starts = { [1516] = 178, [1519] = 178 },
      finals = { 1518, 1521 },
      chain = { 1516, 1517, 1518, 1519, 1520, 1521 },
    },
    -- Fire Totem, Searing Totem
    { key = "FIRE_TOTEM", level = 10, spell = 3599, name = "Searing Totem", item = 5176, important = true,
      starts = { [1522] = 178, [1523] = 178, [2983] = 178, [2984] = 178 },
      finals = { 1527 },
      chain = { 1522, 1523, 1524, 1525, 1526, 1527, 2983, 2984 },
    },
    -- Water Totem, Healing Stream Totem
    { key = "WATER_TOTEM", level = 20, spell = 5394, name = "Healing Stream Totem", item = 5177, important = true,
      starts = { [1528] = 178, [1529] = 178, [2985] = 130, [2986] = 178 },
      finals = { 96 },
      chain = { 63, 96, 100, 220, 1528, 1529, 1530, 1534, 1535, 1536, 2985, 2986 },
    },
    -- Air Totem
    { key = "AIR_TOTEM", level = 30, item = 5178, important = true,
      starts = { [1531] = 178, [1532] = 178 },
      finals = { 1531, 1532 },
      chain = { 1531, 1532 },
    },
  },
  WARLOCK = {
    -- Summon Imp
    { key = "IMP", level = 1, spell = 688, name = "Summon Imp", important = true,
      starts = { [1470] = 178, [1485] = 178, [1598] = 77, [1599] = 77 },
      finals = { 1470, 1485, 1599, 1598 },
      chain = { 1470, 1485, 1598, 1599 },
    },
    -- Summon Voidwalker
    { key = "VOIDWALKER", level = 10, spell = 697, name = "Summon Voidwalker", important = true,
      starts = { [1478] = 178, [1506] = 178, [1685] = 77 },
      finals = { 1471, 1504, 1689 },
      chain = { 1471, 1473, 1478, 1501, 1504, 1506, 1685, 1688, 1689 },
    },
    -- Summon Succubus
    { key = "SUCCUBUS", level = 20, spell = 712, name = "Summon Succubus", important = true,
      starts = { [1472] = 178, [1507] = 178, [1717] = 77 },
      finals = { 1474, 1513, 1739 },
      chain = {
        1472, 1474, 1476, 1507, 1508, 1509, 1510, 1511, 1512, 1513, 1515, 1716,
        1717, 1738, 1739,
      },
    },
    -- Summon Felhunter
    { key = "FELHUNTER", level = 30, spell = 691, name = "Summon Felhunter", important = true,
      starts = { [1798] = 77, [1801] = 178 },
      finals = { 1795 },
      chain = { 1758, 1795, 1798, 1801, 1802, 1803, 1804, 1805 },
    },
    -- Summon Felsteed
    { key = "FELSTEED", level = 40, spell = 5784, name = "Summon Felsteed", important = true,
      starts = { [3631] = 178, [4487] = 77, [4488] = 77, [4489] = 178 },
      finals = { 4490 },
      chain = { 3631, 4487, 4488, 4489, 4490 },
    },
  },
  DRUID = {
    -- Bear Form, Growl, Maul
    { key = "BEAR_FORM", level = 10, spell = 5487, name = "Bear Form", important = true,
      starts = { [5923] = 77, [5924] = 77, [5925] = 77, [5926] = 178, [5927] = 178, [5928] = 178 },
      finals = { 6001, 6002 },
      chain = {
        5921, 5922, 5923, 5924, 5925, 5926, 5927, 5928, 5929, 5930, 5931, 5932,
        6001, 6002,
      },
    },
    -- Cure Poison
    { key = "CURE_POISON", level = 14, spell = 8946, name = "Cure Poison",
      starts = { [6121] = 77, [6126] = 178 },
      finals = { 6125, 6130 },
      chain = { 6121, 6122, 6123, 6124, 6125, 6126, 6127, 6128, 6129, 6130 },
    },
    -- Aquatic Form
    { key = "AQUATIC_FORM", level = 16, spell = 1066, name = "Aquatic Form", important = true,
      starts = { [26] = 8, [27] = 32 },
      finals = { 5061, 31 },
      chain = { 26, 27, 28, 29, 30, 31, 272, 5061 },
    },
  },
}
