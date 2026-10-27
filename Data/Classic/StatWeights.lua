local addonName, Pathwise = ...

-- Stat weights per class -> per spec/goal key. An item's score is the sum of
-- stat * weight. Keys are the locale-independent stat keys returned by
-- GetItemStats, plus two custom keys for weapon DPS.
--
-- All values are placeholder starting points, to be tuned while testing.
-- A spec without its own table falls back to LEVELING.
-- Weights are relative to the spec's main stat = 1.0 (Agility for hunters
-- and rogues, Strength for warriors, Intellect or spell power for casters),
-- so scores can be compared between items but not between specs. Armor
-- follows the hunter rule, 1 Stamina ~ 40 armor, except for tanks.
-- Wands are ranged weapons: RANGED_WEAPON_DPS is the wand for casters.
-- "Equip:" bonuses: verified in game, the client reports +healing as
-- ITEM_MOD_SPELL_HEALING_DONE (no _SHORT; Pagan Belt of Healing), so
-- GearScore matches a key with or without _SHORT. TODO verify with
-- /pw stats: spell damage, mana per 5, hit, crit, defense, dodge, parry,
-- block. Keys the client doesn't report simply score nothing.

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
  WARRIOR = {
    -- Arms with a two-hander: weapon damage first, then Strength.
    LEVELING = {
      ITEM_MOD_STRENGTH_SHORT = 1.0,
      ITEM_MOD_AGILITY_SHORT = 0.6,
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_SPIRIT_SHORT = 0.05,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 10,
      ITEM_MOD_CRIT_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0125,
      MELEE_WEAPON_DPS = 3.5,
      RANGED_WEAPON_DPS = 0.1,
    },
    -- Two weapons: hit and crit count for more.
    FURY = {
      ITEM_MOD_STRENGTH_SHORT = 1.0,
      ITEM_MOD_AGILITY_SHORT = 0.7,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 14,
      ITEM_MOD_CRIT_RATING_SHORT = 12,
      RESISTANCE0_NAME = 0.01,
      MELEE_WEAPON_DPS = 3.0,
      RANGED_WEAPON_DPS = 0.1,
    },
    -- Tank: Stamina, armor and avoidance before damage.
    PROTECTION = {
      ITEM_MOD_STRENGTH_SHORT = 0.5,
      ITEM_MOD_AGILITY_SHORT = 0.6,
      ITEM_MOD_STAMINA_SHORT = 1.0,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.2,
      ITEM_MOD_HIT_RATING_SHORT = 6,
      ITEM_MOD_CRIT_RATING_SHORT = 4,
      ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 1.5,
      ITEM_MOD_DODGE_RATING_SHORT = 15,
      ITEM_MOD_PARRY_RATING_SHORT = 14,
      ITEM_MOD_BLOCK_RATING_SHORT = 8,
      ITEM_MOD_BLOCK_VALUE_SHORT = 0.3,
      RESISTANCE0_NAME = 0.06,
      MELEE_WEAPON_DPS = 1.2,
      RANGED_WEAPON_DPS = 0.05,
    },
  },
  PALADIN = {
    -- Retribution with a two-hander: weapon damage and Strength, some Intellect for mana.
    LEVELING = {
      ITEM_MOD_STRENGTH_SHORT = 1.0,
      ITEM_MOD_AGILITY_SHORT = 0.5,
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 0.4,
      ITEM_MOD_SPIRIT_SHORT = 0.15,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_SPELL_POWER_SHORT = 0.3,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0.3,
      ITEM_MOD_HIT_RATING_SHORT = 8,
      ITEM_MOD_CRIT_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0125,
      MELEE_WEAPON_DPS = 3.5,
    },
    -- Healer: Intellect and healing power.
    HOLY = {
      ITEM_MOD_STRENGTH_SHORT = 0.05,
      ITEM_MOD_STAMINA_SHORT = 0.3,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.3,
      ITEM_MOD_SPELL_POWER_SHORT = 0.7,
      ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0.7,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.0,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0075,
    },
    -- Tank: Stamina and armor, spell damage for Holy Shield and Consecration.
    PROTECTION = {
      ITEM_MOD_STRENGTH_SHORT = 0.4,
      ITEM_MOD_AGILITY_SHORT = 0.4,
      ITEM_MOD_STAMINA_SHORT = 1.0,
      ITEM_MOD_INTELLECT_SHORT = 0.4,
      ITEM_MOD_SPELL_POWER_SHORT = 0.5,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0.5,
      ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 1.5,
      ITEM_MOD_DODGE_RATING_SHORT = 12,
      ITEM_MOD_PARRY_RATING_SHORT = 12,
      ITEM_MOD_BLOCK_RATING_SHORT = 8,
      ITEM_MOD_BLOCK_VALUE_SHORT = 0.3,
      RESISTANCE0_NAME = 0.06,
      MELEE_WEAPON_DPS = 1.0,
    },
  },
  ROGUE = {
    -- Combat: weapon damage and Agility.
    LEVELING = {
      ITEM_MOD_STRENGTH_SHORT = 0.5,
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 12,
      ITEM_MOD_CRIT_RATING_SHORT = 12,
      RESISTANCE0_NAME = 0.01,
      MELEE_WEAPON_DPS = 3.0,
      RANGED_WEAPON_DPS = 0.2,
    },
    -- Daggers: crit counts for more (Seal Fate).
    ASSASSINATION = {
      ITEM_MOD_STRENGTH_SHORT = 0.5,
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_STAMINA_SHORT = 0.35,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 12,
      ITEM_MOD_CRIT_RATING_SHORT = 15,
      RESISTANCE0_NAME = 0.0087,
      MELEE_WEAPON_DPS = 3.0,
      RANGED_WEAPON_DPS = 0.2,
    },
    -- Hemorrhage: more Stamina for PvP.
    SUBTLETY = {
      ITEM_MOD_STRENGTH_SHORT = 0.5,
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_STAMINA_SHORT = 0.6,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 10,
      ITEM_MOD_CRIT_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.015,
      MELEE_WEAPON_DPS = 3.0,
      RANGED_WEAPON_DPS = 0.2,
    },
  },
  PRIEST = {
    -- Shadow with a wand: spell damage, Spirit (Spirit Tap) and the wand.
    LEVELING = {
      ITEM_MOD_STAMINA_SHORT = 0.6,
      ITEM_MOD_INTELLECT_SHORT = 0.8,
      ITEM_MOD_SPIRIT_SHORT = 1.0,
      ITEM_MOD_SPELL_POWER_SHORT = 1.0,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.0,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 8,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 6,
      RESISTANCE0_NAME = 0.015,
      RANGED_WEAPON_DPS = 2.5,
    },
    -- Healer: Intellect, Spirit and healing power.
    DISCIPLINE = {
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.8,
      ITEM_MOD_SPELL_POWER_SHORT = 0.7,
      ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0.8,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.0,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.01,
      RANGED_WEAPON_DPS = 1.0,
    },
    -- Healer: healing power, Spirit and Intellect.
    HOLY = {
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.9,
      ITEM_MOD_SPELL_POWER_SHORT = 0.7,
      ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0.8,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.0,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.01,
      RANGED_WEAPON_DPS = 1.0,
    },
  },
  SHAMAN = {
    -- Enhancement with a two-hander: weapon damage and Strength.
    LEVELING = {
      ITEM_MOD_STRENGTH_SHORT = 1.0,
      ITEM_MOD_AGILITY_SHORT = 0.6,
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 0.4,
      ITEM_MOD_SPIRIT_SHORT = 0.1,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_SPELL_POWER_SHORT = 0.3,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0.3,
      ITEM_MOD_HIT_RATING_SHORT = 8,
      ITEM_MOD_CRIT_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0125,
      MELEE_WEAPON_DPS = 3.5,
    },
    -- Lightning: spell damage and Intellect.
    ELEMENTAL = {
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.3,
      ITEM_MOD_SPELL_POWER_SHORT = 1.2,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.2,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.0,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0125,
    },
    -- Healer: Intellect, healing power and mana per 5.
    RESTORATION = {
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.4,
      ITEM_MOD_SPELL_POWER_SHORT = 0.7,
      ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0.8,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.5,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.01,
    },
  },
  MAGE = {
    -- Frost: spell damage, Intellect and the wand.
    LEVELING = {
      ITEM_MOD_STAMINA_SHORT = 0.6,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.6,
      ITEM_MOD_SPELL_POWER_SHORT = 1.2,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.2,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.015,
      RANGED_WEAPON_DPS = 2.0,
    },
    -- Arcane: Intellect counts for more (Arcane Mind).
    ARCANE = {
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 1.2,
      ITEM_MOD_SPIRIT_SHORT = 0.6,
      ITEM_MOD_SPELL_POWER_SHORT = 1.1,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.1,
      ITEM_MOD_MANA_REGENERATION_SHORT = 1.5,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.0125,
      RANGED_WEAPON_DPS = 1.5,
    },
    -- Fire: crit counts for more (Ignite).
    FIRE = {
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.5,
      ITEM_MOD_SPELL_POWER_SHORT = 1.2,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.2,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 12,
      RESISTANCE0_NAME = 0.0125,
      RANGED_WEAPON_DPS = 1.5,
    },
  },
  WARLOCK = {
    -- Affliction: spell damage and Stamina (Life Tap turns health into mana).
    LEVELING = {
      ITEM_MOD_STAMINA_SHORT = 0.9,
      ITEM_MOD_INTELLECT_SHORT = 0.6,
      ITEM_MOD_SPIRIT_SHORT = 0.4,
      ITEM_MOD_SPELL_POWER_SHORT = 1.0,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.0,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 4,
      RESISTANCE0_NAME = 0.0225,
      RANGED_WEAPON_DPS = 2.0,
    },
    -- Demonology: Stamina and Intellect (Demonic Embrace, Fel Intellect).
    DEMONOLOGY = {
      ITEM_MOD_STAMINA_SHORT = 1.0,
      ITEM_MOD_INTELLECT_SHORT = 0.7,
      ITEM_MOD_SPIRIT_SHORT = 0.2,
      ITEM_MOD_SPELL_POWER_SHORT = 0.9,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 0.9,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 5,
      RESISTANCE0_NAME = 0.025,
      RANGED_WEAPON_DPS = 1.5,
    },
    -- Destruction: spell damage and crit (Ruin).
    DESTRUCTION = {
      ITEM_MOD_STAMINA_SHORT = 0.6,
      ITEM_MOD_INTELLECT_SHORT = 0.6,
      ITEM_MOD_SPIRIT_SHORT = 0.2,
      ITEM_MOD_SPELL_POWER_SHORT = 1.0,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.0,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.015,
      RANGED_WEAPON_DPS = 1.5,
    },
  },
  DRUID = {
    -- Feral: Strength and Agility (weapon damage does nothing in cat or bear form).
    LEVELING = {
      ITEM_MOD_STRENGTH_SHORT = 1.0,
      ITEM_MOD_AGILITY_SHORT = 1.0,
      ITEM_MOD_STAMINA_SHORT = 0.6,
      ITEM_MOD_INTELLECT_SHORT = 0.3,
      ITEM_MOD_SPIRIT_SHORT = 0.1,
      ITEM_MOD_ATTACK_POWER_SHORT = 0.5,
      ITEM_MOD_HIT_RATING_SHORT = 10,
      ITEM_MOD_CRIT_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.02,
    },
    -- Balance: spell damage and Intellect.
    BALANCE = {
      ITEM_MOD_STAMINA_SHORT = 0.5,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.4,
      ITEM_MOD_SPELL_POWER_SHORT = 1.2,
      ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 1.2,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.0,
      ITEM_MOD_HIT_SPELL_RATING_SHORT = 10,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 10,
      RESISTANCE0_NAME = 0.0125,
    },
    -- Healer: Intellect, Spirit and healing power.
    RESTORATION = {
      ITEM_MOD_STAMINA_SHORT = 0.4,
      ITEM_MOD_INTELLECT_SHORT = 1.0,
      ITEM_MOD_SPIRIT_SHORT = 0.6,
      ITEM_MOD_SPELL_POWER_SHORT = 0.7,
      ITEM_MOD_SPELL_HEALING_DONE_SHORT = 0.8,
      ITEM_MOD_MANA_REGENERATION_SHORT = 2.5,
      ITEM_MOD_CRIT_SPELL_RATING_SHORT = 8,
      RESISTANCE0_NAME = 0.01,
    },
  },
}

-- Specs that use their class's leveling weights.
local weights = Pathwise.Data.StatWeights
weights.WARRIOR.ARMS = weights.WARRIOR.LEVELING
weights.PALADIN.RETRIBUTION = weights.PALADIN.LEVELING
weights.ROGUE.COMBAT = weights.ROGUE.LEVELING
weights.PRIEST.SHADOW = weights.PRIEST.LEVELING
weights.SHAMAN.ENHANCEMENT = weights.SHAMAN.LEVELING
weights.MAGE.FROST = weights.MAGE.LEVELING
weights.WARLOCK.AFFLICTION = weights.WARLOCK.LEVELING
weights.DRUID.FERAL = weights.DRUID.LEVELING
