local addonName, Pathwise = ...

-- Talent trees and selectable goals per class (Classic Era).
--
-- trees: spec key for each talent tab, in tab order as returned by
--        GetTalentTabInfo(1..3). Keys are locale-independent; display names
--        live in the locale file as SPEC_<KEY>.
-- goals: options offered by the goal prompt (/pw spec). Classes without their
--        own list use GenericGoals.

Pathwise.Data.GenericGoals = { "LEVELING", "TANK", "HEALER", "DAMAGE" }

-- Used when no goal is chosen and the spec can't be inferred from talents.
Pathwise.Data.DefaultGoal = "LEVELING"

-- Shorthands accepted by /pw spec <goal>.
Pathwise.Data.GoalAliases = {
  BM = "BEAST_MASTERY",
  MM = "MARKSMANSHIP",
  SV = "SURVIVAL",
  LVL = "LEVELING",
  DPS = "DAMAGE",
  PROT = "PROTECTION",
  RET = "RETRIBUTION",
  ASSA = "ASSASSINATION",
  ASSASS = "ASSASSINATION",
  SUB = "SUBTLETY",
  DISC = "DISCIPLINE",
  SP = "SHADOW",
  ELE = "ELEMENTAL",
  ENH = "ENHANCEMENT",
  RESTO = "RESTORATION",
  AFF = "AFFLICTION",
  AFFLI = "AFFLICTION",
  DEMO = "DEMONOLOGY",
  DESTRO = "DESTRUCTION",
  BOOMKIN = "BALANCE",
  MOONKIN = "BALANCE",
  CAT = "FERAL",
  BEAR = "FERAL",
}

-- Two trees whose point totals are this close (and both non-zero) count as a
-- hybrid; Pathwise then uses the player's chosen goal instead.
Pathwise.Data.HybridMargin = 3

-- Tree order is the client's (GetTalentTabInfo 1-3); the hunter's is
-- verified in game, the others match the talent data the builds were
-- checked against (Data/Classic/TalentBuilds.lua).
Pathwise.Data.ClassSpecs = {
  HUNTER = {
    trees = { "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" }, -- verified in game (1.15.9)
    goals = { "LEVELING", "BEAST_MASTERY", "MARKSMANSHIP", "SURVIVAL" },
  },
  WARRIOR = {
    trees = { "ARMS", "FURY", "PROTECTION" },
    goals = { "LEVELING", "ARMS", "FURY", "PROTECTION" },
  },
  PALADIN = {
    trees = { "HOLY", "PROTECTION", "RETRIBUTION" },
    goals = { "LEVELING", "HOLY", "PROTECTION", "RETRIBUTION" },
  },
  ROGUE = {
    trees = { "ASSASSINATION", "COMBAT", "SUBTLETY" },
    goals = { "LEVELING", "ASSASSINATION", "COMBAT", "SUBTLETY" },
  },
  PRIEST = {
    trees = { "DISCIPLINE", "HOLY", "SHADOW" },
    goals = { "LEVELING", "DISCIPLINE", "HOLY", "SHADOW" },
  },
  SHAMAN = {
    trees = { "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
    goals = { "LEVELING", "ELEMENTAL", "ENHANCEMENT", "RESTORATION" },
  },
  MAGE = {
    trees = { "ARCANE", "FIRE", "FROST" },
    goals = { "LEVELING", "ARCANE", "FIRE", "FROST" },
  },
  WARLOCK = {
    trees = { "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
    goals = { "LEVELING", "AFFLICTION", "DEMONOLOGY", "DESTRUCTION" },
  },
  DRUID = {
    trees = { "BALANCE", "FERAL", "RESTORATION" },
    goals = { "LEVELING", "BALANCE", "FERAL", "RESTORATION" },
  },
}
