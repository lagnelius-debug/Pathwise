local addonName, Pathwise = ...

-- What each class can equip in Classic Era, by item class/subclass ID
-- (locale-independent). The value is the level from which the class can use
-- it (e.g. hunters learn Mail at 40).
--
-- Armor subclasses:  0 Misc (rings, necks, trinkets, ...), 1 Cloth,
--                    2 Leather, 3 Mail, 4 Plate, 6 Shield
-- Weapon subclasses: 0 1H Axe, 1 2H Axe, 2 Bow, 3 Gun, 4 1H Mace, 5 2H Mace,
--                    6 Polearm, 7 1H Sword, 8 2H Sword, 10 Staff, 13 Fist,
--                    14 Misc, 15 Dagger, 16 Thrown, 18 Crossbow, 19 Wand,
--                    20 Fishing Pole
--
-- dualWieldLevel: level from which one-handers can go in the off hand.
-- Classes without an entry are treated as able to use everything.

Pathwise.Data.ClassGear = {
  HUNTER = {
    armor = { [0] = 1, [1] = 1, [2] = 1, [3] = 40 },
    weapons = {
      [0] = 1, [1] = 1, [2] = 1, [3] = 1, [6] = 1, [7] = 1, [8] = 1,
      [10] = 1, [13] = 1, [14] = 1, [15] = 1, [16] = 1, [18] = 1, [20] = 1,
    }, -- TODO verify (fist weapons, polearms, thrown)
    dualWieldLevel = 20, -- TODO verify
  },
}
