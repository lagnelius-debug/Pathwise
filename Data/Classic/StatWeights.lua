local addonName, Pathwise = ...

-- Stat weights per class -> per spec/goal key. An item's score is the sum of
-- stat * weight. Keys are the locale-independent stat keys returned by
-- GetItemStats, plus two custom keys for weapon DPS.
--
-- All values are placeholder starting points, to be tuned while testing.
-- A spec without its own table falls back to LEVELING.
-- Weights are relative to Agility = 1.0 within each spec, so scores can be
-- compared between items but not between specs.
-- TODO verify: crit/hit ("Equip: Improves your chance...") are not scored
-- yet; check how Classic Era's GetItemStats reports them.

Pathwise.Data.StatWeights = {
  HUNTER = {
    LEVELING = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.45,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 0.25,
      ITEM_MOD_SPIRIT_SHORT = 0.1,
      ITEM_MOD_STRENGTH_SHORT = 0.05,
      -- Armor: 1 Stamina ~ 40 armor. +1 Stamina is +10 health (about 4% at
      -- level 10, 0.3% at 60); 40 armor is about 1-2% less physical damage
      -- at level 10. Still breaks ties between items without stats.
      RESISTANCE0_NAME = 0.01,
      RANGED_WEAPON_DPS = 3.0, -- custom key: ranged weapon DPS is weighted heavily
      MELEE_WEAPON_DPS = 0.2,  -- custom key: melee weapon is mostly a stat stick
    },
    -- Beast Mastery: solo-focused, so survivability and less downtime
    -- (Stamina, Intellect, Spirit) count for more than in the other trees.
    BEAST_MASTERY = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.45,
      ITEM_MOD_STAMINA_SHORT = 0.55,
      ITEM_MOD_INTELLECT_SHORT = 0.35,
      ITEM_MOD_SPIRIT_SHORT = 0.15,
      ITEM_MOD_STRENGTH_SHORT = 0.05,
      RESISTANCE0_NAME = 0.014, -- 1 Stamina ~ 40 armor
      RANGED_WEAPON_DPS = 2.8,
      MELEE_WEAPON_DPS = 0.2,
    },
    -- Marksmanship: pure ranged damage; survivability matters less.
    MARKSMANSHIP = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_STAMINA_SHORT = 0.25,
      ITEM_MOD_INTELLECT_SHORT = 0.3,
      ITEM_MOD_SPIRIT_SHORT = 0.05,
      ITEM_MOD_STRENGTH_SHORT = 0.03,
      RESISTANCE0_NAME = 0.006, -- 1 Stamina ~ 40 armor
      RANGED_WEAPON_DPS = 3.5,
      MELEE_WEAPON_DPS = 0.1,
    },
    -- Survival: talents multiply Agility, so it is worth more relative to
    -- attack power; some melee talents make the melee weapon count a bit.
    SURVIVAL = {
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.4,
      ITEM_MOD_RANGED_ATTACK_POWER_SHORT = 0.36,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 0.25,
      ITEM_MOD_SPIRIT_SHORT = 0.05,
      ITEM_MOD_STRENGTH_SHORT = 0.1,
      RESISTANCE0_NAME = 0.01, -- 1 Stamina ~ 40 armor
      RANGED_WEAPON_DPS = 2.8,
      MELEE_WEAPON_DPS = 0.5,
    },
  },
}
