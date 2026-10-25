local addonName, Pathwise = ...

-- Professions (Core/Professions.lua): which ones suit each class, the rank
-- caps and their requirements, the tools gathering needs, and how profession
-- trainers are titled in QuestieDB's NPC data. Classic Era values.

Pathwise.Data.Professions = {
  -- key = skill line name as the client shows it (English client).
  -- trainer: NPC sub-title of a trainer; person: what higher-rank trainers
  -- are called ("Journeyman Leatherworker", "Artisan Leatherworker", ...).
  -- tool: item needed in the bags to gather (item ID, vendor type).
  LIST = {
    Alchemy = { primary = true, trainer = "Alchemy Trainer", person = "Alchemist" },
    Blacksmithing = { primary = true, trainer = "Blacksmithing Trainer", person = "Blacksmith",
      tool = { id = 5956, name = "Blacksmith Hammer" } },
    Enchanting = { primary = true, trainer = "Enchanting Trainer", person = "Enchanter" },
    Engineering = { primary = true, trainer = "Engineering Trainer", person = "Engineer",
      tool = { id = 6219, name = "Arclight Spanner" } },
    Herbalism = { primary = true, gather = true, trainer = "Herbalism Trainer", person = "Herbalist" },
    Leatherworking = { primary = true, trainer = "Leatherworking Trainer", person = "Leatherworker" },
    Mining = { primary = true, gather = true, trainer = "Mining Trainer", person = "Miner",
      tool = { id = 2901, name = "Mining Pick" } },
    Skinning = { primary = true, gather = true, trainer = "Skinning Trainer", person = "Skinner",
      tool = { id = 7005, name = "Skinning Knife" } },
    Tailoring = { primary = true, trainer = "Tailoring Trainer", person = "Tailor" },
    Cooking = { trainer = "Cooking Trainer", person = "Cook" },
    ["First Aid"] = { trainer = "First Aid Trainer", person = "Physician" },
    Fishing = { trainer = "Fishing Trainer", person = "Fisherman" },
  },

  -- Each rank's skill cap, and what's needed to train it: character level
  -- and skill in the rank below.
  RANKS = {
    { name = "Apprentice", cap = 75, level = 5, skill = 0 },
    { name = "Journeyman", cap = 150, level = 10, skill = 50 },
    { name = "Expert", cap = 225, level = 20, skill = 125 },
    { name = "Artisan", cap = 300, level = 35, skill = 200 },
  },
  MAX_PRIMARY = 2,

  -- Recommendations per class: leveling (the default suggestion), gold
  -- (alternative: two gathering professions to sell everything), endgame
  -- (worth switching to at 60), secondary (worth having). The reasons are
  -- in the locale (PROF_WHY_<CLASS>).
  ADVICE = {
    HUNTER = {
      leveling = { "Skinning", "Leatherworking" },
      gold = { "Skinning", "Mining" },
      endgame = "Engineering",
      secondary = { "First Aid", "Cooking", "Fishing" },
    },
    ROGUE = {
      leveling = { "Skinning", "Leatherworking" },
      gold = { "Skinning", "Mining" },
      endgame = "Engineering",
      secondary = { "First Aid", "Cooking" },
    },
    WARRIOR = {
      leveling = { "Mining", "Blacksmithing" },
      gold = { "Mining", "Skinning" },
      endgame = "Engineering",
      secondary = { "First Aid", "Cooking" },
    },
    PALADIN = {
      leveling = { "Mining", "Blacksmithing" },
      gold = { "Mining", "Herbalism" },
      secondary = { "First Aid", "Cooking" },
    },
    SHAMAN = {
      leveling = { "Skinning", "Leatherworking" },
      gold = { "Mining", "Herbalism" },
      secondary = { "First Aid", "Cooking" },
    },
    DRUID = {
      leveling = { "Skinning", "Leatherworking" },
      gold = { "Herbalism", "Skinning" },
      secondary = { "First Aid", "Cooking" },
    },
    MAGE = {
      leveling = { "Tailoring", "Enchanting" },
      gold = { "Herbalism", "Mining" },
      secondary = { "First Aid", "Cooking" },
    },
    PRIEST = {
      leveling = { "Tailoring", "Enchanting" },
      gold = { "Herbalism", "Mining" },
      secondary = { "First Aid", "Cooking" },
    },
    WARLOCK = {
      leveling = { "Tailoring", "Enchanting" },
      gold = { "Herbalism", "Mining" },
      secondary = { "First Aid", "Cooking" },
    },
  },

  -- Skinning skill needed for a beast of a level: 1 up to level 10,
  -- (level - 10) * 10 up to 20, level * 5 above.
  SKINNING = "Skinning",
}
