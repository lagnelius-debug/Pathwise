local addonName, Pathwise = ...

-- What each class can equip in Classic Era, by item class/subclass ID
-- (locale-independent). The value is the level from which the class can use
-- it (e.g. hunters learn Mail at 40).
--
-- Armor subclasses:  0 Misc (rings, necks, trinkets, ...), 1 Cloth,
--                    2 Leather, 3 Mail, 4 Plate, 6 Shield, 7 Libram,
--                    8 Idol, 9 Totem
-- Weapon subclasses: 0 1H Axe, 1 2H Axe, 2 Bow, 3 Gun, 4 1H Mace, 5 2H Mace,
--                    6 Polearm, 7 1H Sword, 8 2H Sword, 10 Staff, 13 Fist,
--                    14 Misc, 15 Dagger, 16 Thrown, 18 Crossbow, 19 Wand,
--                    20 Fishing Pole
--
-- dualWieldLevel: level from which one-handers can go in the off hand
-- (nil: never). Classes without an entry are treated as able to use
-- everything.

Pathwise.Data.ClassGear = {
  HUNTER = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 40 },
    weapons = {
      [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 1, [7] = 1, [8] = 1,
      [10] = 1, [13] = 1, [14] = 1, [15] = 1, [16] = 1, [18] = 1, [20] = 1,
    }, -- TODO verify (fist weapons, polearms, thrown)
    dualWieldLevel = 20, -- TODO verify
  },
  WARRIOR = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    weapons = {
      [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1,
      [10] = 1, [13] = 1, [14] = 1, [15] = 1, [16] = 1, [18] = 1, [20] = 1,
    },
    dualWieldLevel = 20,
  },
  PALADIN = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 },
    weapons = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1, [14] = 1, [20] = 1 },
  },
  ROGUE = {
    armor = { [0] = 1, [1] = 1, [2] = 1 },
    weapons = { [2] = 1, [3] = 1, [4] = 1, [7] = 1, [13] = 1, [14] = 1, [15] = 1, [16] = 1, [18] = 1, [20] = 1 },
    dualWieldLevel = 10,
  },
  PRIEST = {
    armor = { [0] = 1, [1] = 1 },
    weapons = { [4] = 1, [10] = 1, [14] = 1, [15] = 1, [19] = 1, [20] = 1 },
  },
  SHAMAN = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 40, [6] = 1, [9] = 1 },
    -- Two-handed axes and maces need the Enhancement talent (the skill
    -- check then says "learn ... first").
    weapons = { [0] = 1, [1] = 1, [4] = 1, [5] = 1, [10] = 1, [13] = 1, [14] = 1, [15] = 1, [20] = 1 },
  },
  MAGE = {
    armor = { [0] = 1, [1] = 1 },
    weapons = { [7] = 1, [10] = 1, [14] = 1, [15] = 1, [19] = 1, [20] = 1 },
  },
  WARLOCK = {
    armor = { [0] = 1, [1] = 1 },
    weapons = { [7] = 1, [10] = 1, [14] = 1, [15] = 1, [19] = 1, [20] = 1 },
  },
  DRUID = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [8] = 1 },
    weapons = { [4] = 1, [5] = 1, [10] = 1, [13] = 1, [14] = 1, [15] = 1, [20] = 1 },
  },
}

-- The weapon/armor skill behind each item subclass, as the passive spell the
-- player knows once it's learned (e.g. Staves from a weapon master). Spell
-- IDs are locale-free. Subclasses without an entry need no skill (rings,
-- necks, trinkets, fishing poles, miscellaneous weapons).
-- TODO verify the IDs in game (/pw stats on a weapon shows usability).
Pathwise.Data.Proficiencies = {
  weapons = {
    [0] = 196,    -- One-Handed Axes
    [1] = 197,    -- Two-Handed Axes
    [2] = 264,    -- Bows
    [3] = 266,    -- Guns
    [4] = 198,    -- One-Handed Maces
    [5] = 199,    -- Two-Handed Maces
    [6] = 200,    -- Polearms
    [7] = 201,    -- One-Handed Swords
    [8] = 202,    -- Two-Handed Swords
    [10] = 227,   -- Staves
    [13] = 15590, -- Fist Weapons
    [15] = 1180,  -- Daggers
    [16] = 2567,  -- Thrown
    [18] = 5011,  -- Crossbows
    [19] = 5009,  -- Wands
  },
  armor = {
    [1] = 9078, -- Cloth
    [2] = 9077, -- Leather
    [3] = 8737, -- Mail
    [4] = 750,  -- Plate Mail
    [6] = 9116, -- Shield
  },
}
