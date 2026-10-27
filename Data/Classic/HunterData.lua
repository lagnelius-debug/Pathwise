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
  -- Titles of the quests in the taming chain (English client). While one
  -- is in the quest log, the quest itself is the step to follow.
  TAMING_TITLES = { ["Taming the Beast"] = true, ["Training the Beast"] = true },

  -- Pet guide (Classes/PetGuide.lua): the pet abilities worth upgrading, by
  -- their rank 1 spell ID, most useful first (Cower only lowers threat and
  -- is left out). Ranks, levels, families and teaching beasts come from
  -- LibTameable-1.0.
  PET_ABILITIES = {
    17253, -- Bite
    16827, -- Claw
    24604, -- Furious Howl (wolf)
    24844, -- Lightning Breath (wind serpent)
    24640, -- Scorpid Poison (scorpid)
    24423, -- Screech (bat, carrion bird, owl)
    7371,  -- Charge (boar)
    26090, -- Thunderstomp (gorilla)
    26064, -- Shell Shield (turtle)
    23099, -- Dash
    23145, -- Dive
    24450, -- Prowl (cat)
  },
  -- Pet family names as UnitCreatureFamily gives them (English client) ->
  -- LibTameable family keys, for clients that don't give the family's ID.
  PET_FAMILIES = {
    Wolf = "wolf", Cat = "cat", Spider = "spider", Bear = "bear", Boar = "boar",
    Crocolisk = "crocolisk", ["Carrion Bird"] = "carrionBird", Crab = "crab", Gorilla = "gorilla",
    Raptor = "raptor", Tallstrider = "tallstrider", Scorpid = "scorpid", Turtle = "turtle",
    Bat = "bat", Hyena = "hyena", Owl = "birdOfPrey", ["Wind Serpent"] = "windSerpent",
  },

  -- Ranged weapon subclasses that use arrows or bullets (thrown weapons
  -- need no ammo).
  AMMO_KIND = { [2] = "ARROWS", [18] = "ARROWS", [3] = "BULLETS" },
}
