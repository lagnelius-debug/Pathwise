local addonName, Pathwise = ...

-- Hunter-specific data (Classes/Hunter.lua).

Pathwise.Data.Hunter = {
  -- Tame Beast: learned through the level 10 "Taming the Beast" quests.
  TAME_BEAST_SPELL = 1515,

  -- First "Taming the Beast" quest per race (race token from UnitRace).
  -- IDs from QuestieDB's Classic quest data.
  TAMING_QUESTS = {
    NightElf = 6063, -- Dazalar, Dolanaar
    Dwarf = 6064,    -- Grif Wildheart, Kharanos
    Orc = 6062,      -- Thotar, Razor Hill
    Troll = 6062,
    Tauren = 6061,   -- Yaw Sharpmane, Bloodhoof Village
  },
  TAMING_LEVEL = 10,

  -- Ranged weapon subclasses that use arrows or bullets (thrown weapons
  -- need no ammo).
  AMMO_KIND = { [2] = "ARROWS", [18] = "ARROWS", [3] = "BULLETS" },
}
