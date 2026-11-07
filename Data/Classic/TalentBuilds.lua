local addonName, Pathwise = ...

-- Talent builds per class, as an ordered list of talent picks:
--   { tab, tier, column, ranks, name }
-- tab/tier/column locate the talent in the client's talent tree (locale-
-- free); name is English, for reading this file and as a display fallback.
-- Each pick spends `ranks` points in a row, starting at level 10 (one point
-- per level), so the list adds up to 51 points at level 60.
--
-- bySpec picks the build for the active spec/goal (Core/Talents.lua).
--
-- Talent positions are from the 1.12 trees, checked with a script against
-- the Classic talent data of wowsims (MIT): every pick's tier is open by
-- then (5 points per tier in that tree), prerequisites are filled first and
-- each build adds up to 51. TODO verify in game with /pw talents check (it
-- compares these names with the client's).

Pathwise.Data.TalentBuilds = {
  HUNTER = {
    default = "BM_LEVELING",
    bySpec = {
      LEVELING = "BM_LEVELING",
      BEAST_MASTERY = "BM_LEVELING",
      MARKSMANSHIP = "MM_LEVELING",
      SURVIVAL = "BM_LEVELING", -- no Survival build yet
    },
    builds = {
      -- Beast Mastery leveling, 31/20/0: strong pet early, Bestial Wrath at
      -- 40, then Marksmanship for ranged damage.
      BM_LEVELING = {
        name = "Beast Mastery leveling (31/20/0)",
        picks = {
          { 1, 1, 2, 5, "Improved Aspect of the Hawk" }, -- 10-14
          { 1, 1, 3, 5, "Endurance Training" },          -- 15-19
          { 1, 3, 2, 1, "Bestial Swiftness" },           -- 20
          { 1, 3, 3, 5, "Unleashed Fury" },              -- 21-25
          { 1, 4, 3, 5, "Ferocity" },                    -- 26-30
          { 1, 5, 2, 1, "Intimidation" },                -- 31
          { 1, 5, 1, 2, "Spirit Bond" },                 -- 32-33
          { 1, 2, 3, 1, "Thick Hide" },                  -- 34
          { 1, 6, 3, 5, "Frenzy" },                      -- 35-39
          { 1, 7, 2, 1, "Bestial Wrath" },               -- 40
          { 2, 1, 3, 5, "Efficiency" },                  -- 41-45
          { 2, 2, 3, 5, "Lethal Shots" },                -- 46-50
          { 2, 3, 1, 1, "Aimed Shot" },                  -- 51
          { 2, 3, 4, 3, "Hawk Eye" },                    -- 52-54
          { 2, 3, 2, 1, "Improved Arcane Shot" },        -- 55
          { 2, 4, 3, 5, "Mortal Shots" },                -- 56-60
        },
      },
      -- Marksmanship first, 20/31/0: Aimed Shot at 20, Trueshot Aura at 40,
      -- then Beast Mastery for the pet and Aspect of the Hawk.
      MM_LEVELING = {
        name = "Marksmanship leveling (20/31/0)",
        picks = {
          { 2, 1, 3, 5, "Efficiency" },                  -- 10-14
          { 2, 2, 3, 5, "Lethal Shots" },                -- 15-19
          { 2, 3, 1, 1, "Aimed Shot" },                  -- 20
          { 2, 3, 4, 3, "Hawk Eye" },                    -- 21-23
          { 2, 3, 2, 2, "Improved Arcane Shot" },        -- 24-25
          { 2, 4, 3, 5, "Mortal Shots" },                -- 26-30
          { 2, 5, 2, 3, "Barrage" },                     -- 31-33
          { 2, 5, 1, 1, "Scatter Shot" },                -- 34
          { 2, 6, 3, 5, "Ranged Weapon Specialization" }, -- 35-39
          { 2, 7, 2, 1, "Trueshot Aura" },               -- 40
          { 1, 1, 2, 5, "Improved Aspect of the Hawk" }, -- 41-45
          { 1, 1, 3, 5, "Endurance Training" },          -- 46-50
          { 1, 3, 2, 1, "Bestial Swiftness" },           -- 51
          { 1, 3, 3, 5, "Unleashed Fury" },              -- 52-56
          { 1, 4, 3, 4, "Ferocity" },                    -- 57-60
        },
      },
    },
  },
  WARRIOR = {
    default = "ARMS_LEVELING",
    bySpec = {
      LEVELING = "ARMS_LEVELING",
      ARMS = "ARMS_LEVELING",
      FURY = "FURY",
      PROTECTION = "PROTECTION",
    },
    builds = {
      -- Two-hander and Mortal Strike at 40, then Fury for crits and Enrage.
      ARMS_LEVELING = {
        name = "Arms leveling (31/20/0)",
        picks = {
          { 1, 1, 1, 3, "Improved Heroic Strike" }, -- 10-12
          { 1, 1, 2, 2, "Deflection" }, -- 13-14
          { 1, 2, 2, 5, "Tactical Mastery" }, -- 15-19
          { 1, 1, 3, 3, "Improved Rend" }, -- 20-22
          { 1, 3, 2, 1, "Anger Management" }, -- 23
          { 1, 3, 3, 3, "Deep Wounds" }, -- 24-26
          { 1, 4, 2, 3, "Two-Handed Weapon Specialization" }, -- 27-29
          { 1, 4, 3, 2, "Impale" }, -- 30-31
          { 1, 4, 2, 2, "Two-Handed Weapon Specialization" }, -- 32-33
          { 1, 5, 2, 1, "Sweeping Strikes" }, -- 34
          { 1, 3, 1, 2, "Improved Overpower" }, -- 35-36
          { 1, 1, 2, 3, "Deflection" }, -- 37-39
          { 1, 7, 2, 1, "Mortal Strike" }, -- 40
          { 2, 1, 3, 5, "Cruelty" }, -- 41-45
          { 2, 2, 3, 5, "Unbridled Wrath" }, -- 46-50
          { 2, 3, 4, 5, "Improved Battle Shout" }, -- 51-55
          { 2, 4, 3, 5, "Enrage" }, -- 56-60
        },
      },
      -- Dual wield, Flurry and Bloodthirst, then Arms for Deep Wounds and Impale.
      FURY = {
        name = "Fury (17/34/0)",
        picks = {
          { 2, 1, 3, 5, "Cruelty" }, -- 10-14
          { 2, 2, 3, 5, "Unbridled Wrath" }, -- 15-19
          { 2, 3, 4, 5, "Improved Battle Shout" }, -- 20-24
          { 2, 4, 3, 5, "Enrage" }, -- 25-29
          { 2, 5, 2, 1, "Death Wish" }, -- 30
          { 2, 4, 1, 5, "Dual Wield Specialization" }, -- 31-35
          { 2, 6, 3, 5, "Flurry" }, -- 36-40
          { 2, 4, 2, 2, "Improved Execute" }, -- 41-42
          { 2, 7, 2, 1, "Bloodthirst" }, -- 43
          { 1, 1, 1, 3, "Improved Heroic Strike" }, -- 44-46
          { 1, 1, 3, 3, "Improved Rend" }, -- 47-49
          { 1, 2, 2, 5, "Tactical Mastery" }, -- 50-54
          { 1, 3, 2, 1, "Anger Management" }, -- 55
          { 1, 3, 3, 3, "Deep Wounds" }, -- 56-58
          { 1, 4, 3, 2, "Impale" }, -- 59-60
        },
      },
      -- Shield tank: Defiance, Last Stand and Shield Slam.
      PROTECTION = {
        name = "Protection (5/5/41)",
        picks = {
          { 3, 1, 2, 5, "Shield Specialization" }, -- 10-14
          { 3, 1, 3, 5, "Anticipation" }, -- 15-19
          { 3, 2, 3, 5, "Toughness" }, -- 20-24
          { 3, 2, 1, 2, "Improved Bloodrage" }, -- 25-26
          { 3, 3, 1, 1, "Last Stand" }, -- 27
          { 3, 3, 2, 3, "Improved Shield Block" }, -- 28-30
          { 3, 3, 4, 5, "Defiance" }, -- 31-35
          { 3, 3, 3, 3, "Improved Revenge" }, -- 36-38
          { 3, 4, 1, 3, "Improved Sunder Armor" }, -- 39-41
          { 3, 4, 3, 2, "Improved Taunt" }, -- 42-43
          { 3, 5, 2, 1, "Concussion Blow" }, -- 44
          { 3, 6, 3, 5, "One-Handed Weapon Specialization" }, -- 45-49
          { 3, 7, 2, 1, "Shield Slam" }, -- 50
          { 2, 1, 3, 5, "Cruelty" }, -- 51-55
          { 1, 1, 1, 3, "Improved Heroic Strike" }, -- 56-58
          { 1, 1, 2, 2, "Deflection" }, -- 59-60
        },
      },
    },
  },
  PALADIN = {
    default = "RET_LEVELING",
    bySpec = {
      LEVELING = "RET_LEVELING",
      RETRIBUTION = "RET_LEVELING",
      HOLY = "HOLY",
      PROTECTION = "PROTECTION",
    },
    builds = {
      -- Seal of Command at 20, Repentance at 40, then Holy for Consecration.
      RET_LEVELING = {
        name = "Retribution leveling (20/0/31)",
        picks = {
          { 3, 1, 2, 5, "Improved Blessing of Might" }, -- 10-14
          { 3, 2, 1, 2, "Improved Judgement" }, -- 15-16
          { 3, 2, 3, 3, "Deflection" }, -- 17-19
          { 3, 3, 3, 1, "Seal of Command" }, -- 20
          { 3, 3, 2, 5, "Conviction" }, -- 21-25
          { 3, 3, 4, 2, "Pursuit of Justice" }, -- 26-27
          { 3, 4, 1, 2, "Eye for an Eye" }, -- 28-29
          { 3, 5, 1, 3, "Two-Handed Weapon Specialization" }, -- 30-32
          { 3, 5, 3, 1, "Sanctity Aura" }, -- 33
          { 3, 3, 1, 1, "Vindication" }, -- 34
          { 3, 6, 2, 5, "Vengeance" }, -- 35-39
          { 3, 7, 2, 1, "Repentance" }, -- 40
          { 1, 1, 2, 5, "Divine Strength" }, -- 41-45
          { 1, 1, 3, 5, "Divine Intellect" }, -- 46-50
          { 1, 3, 2, 1, "Consecration" }, -- 51
          { 1, 3, 1, 3, "Healing Light" }, -- 52-54
          { 1, 3, 4, 2, "Unyielding Faith" }, -- 55-56
          { 1, 3, 3, 2, "Improved Lay on Hands" }, -- 57-58
          { 1, 2, 3, 2, "Improved Seal of Righteousness" }, -- 59-60
        },
      },
      -- Healer: Illumination, Divine Favor and Holy Shock, then Protection for Blessing of Kings.
      HOLY = {
        name = "Holy (31/20/0)",
        picks = {
          { 1, 1, 3, 5, "Divine Intellect" }, -- 10-14
          { 1, 2, 2, 5, "Spiritual Focus" }, -- 15-19
          { 1, 3, 1, 3, "Healing Light" }, -- 20-22
          { 1, 3, 2, 1, "Consecration" }, -- 23
          { 1, 3, 3, 1, "Improved Lay on Hands" }, -- 24
          { 1, 4, 2, 5, "Illumination" }, -- 25-29
          { 1, 5, 2, 1, "Divine Favor" }, -- 30
          { 1, 4, 3, 2, "Improved Blessing of Wisdom" }, -- 31-32
          { 1, 3, 3, 1, "Improved Lay on Hands" }, -- 33
          { 1, 3, 4, 1, "Unyielding Faith" }, -- 34
          { 1, 6, 3, 5, "Holy Power" }, -- 35-39
          { 1, 7, 2, 1, "Holy Shock" }, -- 40
          { 2, 1, 2, 5, "Improved Devotion Aura" }, -- 41-45
          { 2, 2, 2, 2, "Guardian's Favor" }, -- 46-47
          { 2, 2, 4, 3, "Toughness" }, -- 48-50
          { 2, 3, 1, 1, "Blessing of Kings" }, -- 51
          { 2, 2, 1, 3, "Precision" }, -- 52-54
          { 2, 2, 4, 1, "Toughness" }, -- 55
          { 2, 4, 3, 3, "Improved Concentration Aura" }, -- 56-58
          { 2, 4, 2, 2, "Improved Hammer of Justice" }, -- 59-60
        },
      },
      -- Tank: Blessing of Sanctuary and Holy Shield, then Retribution.
      PROTECTION = {
        name = "Protection (0/31/20)",
        picks = {
          { 2, 1, 3, 5, "Redoubt" }, -- 10-14
          { 2, 2, 4, 5, "Toughness" }, -- 15-19
          { 2, 3, 1, 1, "Blessing of Kings" }, -- 20
          { 2, 3, 3, 3, "Shield Specialization" }, -- 21-23
          { 2, 3, 2, 3, "Improved Righteous Fury" }, -- 24-26
          { 2, 2, 1, 3, "Precision" }, -- 27-29
          { 2, 5, 2, 1, "Blessing of Sanctuary" }, -- 30
          { 2, 4, 2, 3, "Improved Hammer of Justice" }, -- 31-33
          { 2, 2, 2, 1, "Guardian's Favor" }, -- 34
          { 2, 6, 3, 5, "One-Handed Weapon Specialization" }, -- 35-39
          { 2, 7, 2, 1, "Holy Shield" }, -- 40
          { 3, 1, 3, 5, "Benediction" }, -- 41-45
          { 3, 2, 1, 2, "Improved Judgement" }, -- 46-47
          { 3, 2, 3, 3, "Deflection" }, -- 48-50
          { 3, 3, 3, 1, "Seal of Command" }, -- 51
          { 3, 3, 2, 5, "Conviction" }, -- 52-56
          { 3, 3, 4, 2, "Pursuit of Justice" }, -- 57-58
          { 3, 3, 1, 2, "Vindication" }, -- 59-60
        },
      },
    },
  },
  ROGUE = {
    default = "COMBAT",
    bySpec = {
      LEVELING = "COMBAT",
      COMBAT = "COMBAT",
      ASSASSINATION = "ASSASSINATION",
      SUBTLETY = "SUBTLETY",
    },
    builds = {
      -- Sinister Strike, Blade Flurry and Adrenaline Rush, then Assassination for Lethality.
      COMBAT = {
        name = "Combat swords (19/32/0)",
        picks = {
          { 2, 1, 2, 2, "Improved Sinister Strike" }, -- 10-11
          { 2, 1, 3, 3, "Lightning Reflexes" }, -- 12-14
          { 2, 2, 3, 5, "Precision" }, -- 15-19
          { 2, 3, 1, 2, "Endurance" }, -- 20-21
          { 2, 2, 2, 3, "Deflection" }, -- 22-24
          { 2, 4, 3, 5, "Dual Wield Specialization" }, -- 25-29
          { 2, 5, 2, 1, "Blade Flurry" }, -- 30
          { 2, 5, 3, 5, "Sword Specialization" }, -- 31-35
          { 2, 6, 2, 2, "Weapon Expertise" }, -- 36-37
          { 2, 6, 3, 3, "Aggression" }, -- 38-40
          { 2, 7, 2, 1, "Adrenaline Rush" }, -- 41
          { 1, 1, 3, 5, "Malice" }, -- 42-46
          { 1, 2, 1, 3, "Ruthlessness" }, -- 47-49
          { 1, 2, 2, 2, "Murder" }, -- 50-51
          { 1, 3, 1, 1, "Relentless Strikes" }, -- 52
          { 1, 3, 3, 5, "Lethality" }, -- 53-57
          { 1, 1, 1, 3, "Improved Eviscerate" }, -- 58-60
        },
      },
      -- Cold Blood and Seal Fate, then Combat for dagger damage.
      ASSASSINATION = {
        name = "Assassination daggers (31/20/0)",
        picks = {
          { 1, 1, 3, 5, "Malice" }, -- 10-14
          { 1, 2, 1, 3, "Ruthlessness" }, -- 15-17
          { 1, 2, 2, 2, "Murder" }, -- 18-19
          { 1, 3, 1, 1, "Relentless Strikes" }, -- 20
          { 1, 3, 3, 5, "Lethality" }, -- 21-25
          { 1, 1, 1, 3, "Improved Eviscerate" }, -- 26-28
          { 1, 2, 4, 1, "Improved Slice and Dice" }, -- 29
          { 1, 5, 2, 1, "Cold Blood" }, -- 30
          { 1, 2, 4, 2, "Improved Slice and Dice" }, -- 31-32
          { 1, 4, 2, 2, "Vile Poisons" }, -- 33-34
          { 1, 6, 2, 5, "Seal Fate" }, -- 35-39
          { 1, 7, 2, 1, "Vigor" }, -- 40
          { 2, 1, 2, 2, "Improved Sinister Strike" }, -- 41-42
          { 2, 1, 3, 3, "Lightning Reflexes" }, -- 43-45
          { 2, 2, 1, 3, "Improved Backstab" }, -- 46-48
          { 2, 2, 3, 5, "Precision" }, -- 49-53
          { 2, 1, 3, 2, "Lightning Reflexes" }, -- 54-55
          { 2, 4, 2, 5, "Dagger Specialization" }, -- 56-60
        },
      },
      -- Hemorrhage, Preparation and Premeditation, then Combat.
      SUBTLETY = {
        name = "Subtlety hemorrhage (0/20/31)",
        picks = {
          { 3, 1, 3, 5, "Opportunity" }, -- 10-14
          { 3, 2, 3, 5, "Camouflage" }, -- 15-19
          { 3, 3, 1, 3, "Initiative" }, -- 20-22
          { 3, 3, 2, 1, "Ghostly Strike" }, -- 23
          { 3, 3, 3, 1, "Improved Ambush" }, -- 24
          { 3, 4, 3, 3, "Serrated Blades" }, -- 25-27
          { 3, 4, 1, 2, "Setup" }, -- 28-29
          { 3, 5, 4, 1, "Hemorrhage" }, -- 30
          { 3, 5, 2, 1, "Preparation" }, -- 31
          { 3, 5, 3, 2, "Dirty Deeds" }, -- 32-33
          { 3, 5, 1, 1, "Heightened Senses" }, -- 34
          { 3, 6, 3, 5, "Deadliness" }, -- 35-39
          { 3, 7, 2, 1, "Premeditation" }, -- 40
          { 2, 1, 2, 2, "Improved Sinister Strike" }, -- 41-42
          { 2, 1, 3, 5, "Lightning Reflexes" }, -- 43-47
          { 2, 2, 3, 5, "Precision" }, -- 48-52
          { 2, 2, 2, 3, "Deflection" }, -- 53-55
          { 2, 4, 3, 5, "Dual Wield Specialization" }, -- 56-60
        },
      },
    },
  },
  PRIEST = {
    default = "SHADOW",
    bySpec = {
      LEVELING = "SHADOW",
      SHADOW = "SHADOW",
      DISCIPLINE = "HEALER",
      HOLY = "HEALER",
    },
    builds = {
      -- Spirit Tap and Wand Specialization first, Shadowform at 45, then Discipline.
      SHADOW = {
        name = "Shadow leveling (20/0/31)",
        picks = {
          { 3, 1, 2, 5, "Spirit Tap" }, -- 10-14
          { 1, 1, 3, 5, "Wand Specialization" }, -- 15-19
          { 3, 2, 2, 2, "Improved Shadow Word: Pain" }, -- 20-21
          { 3, 2, 3, 3, "Shadow Focus" }, -- 22-24
          { 3, 3, 3, 1, "Mind Flay" }, -- 25
          { 3, 3, 2, 4, "Improved Mind Blast" }, -- 26-29
          { 3, 4, 4, 5, "Shadow Weaving" }, -- 30-34
          { 3, 5, 2, 1, "Vampiric Embrace" }, -- 35
          { 3, 5, 3, 2, "Improved Vampiric Embrace" }, -- 36-37
          { 3, 2, 3, 2, "Shadow Focus" }, -- 38-39
          { 3, 6, 3, 5, "Darkness" }, -- 40-44
          { 3, 7, 2, 1, "Shadowform" }, -- 45
          { 1, 2, 3, 3, "Improved Power Word: Shield" }, -- 46-48
          { 1, 2, 2, 2, "Improved Power Word: Fortitude" }, -- 49-50
          { 1, 3, 3, 3, "Meditation" }, -- 51-53
          { 1, 3, 2, 1, "Inner Focus" }, -- 54
          { 1, 2, 4, 1, "Martyrdom" }, -- 55
          { 1, 4, 2, 5, "Mental Agility" }, -- 56-60
        },
      },
      -- Healer: Spiritual Guidance, Inspiration and Divine Spirit.
      HEALER = {
        name = "Holy/Discipline healing (21/30/0)",
        picks = {
          { 1, 1, 3, 5, "Wand Specialization" }, -- 10-14
          { 2, 1, 1, 2, "Healing Focus" }, -- 15-16
          { 2, 1, 2, 3, "Improved Renew" }, -- 17-19
          { 2, 1, 3, 5, "Holy Specialization" }, -- 20-24
          { 2, 2, 3, 5, "Divine Fury" }, -- 25-29
          { 2, 3, 4, 3, "Inspiration" }, -- 30-32
          { 2, 4, 2, 3, "Improved Healing" }, -- 33-35
          { 2, 5, 1, 2, "Improved Prayer of Healing" }, -- 36-37
          { 2, 5, 3, 5, "Spiritual Guidance" }, -- 38-42
          { 2, 6, 3, 2, "Spiritual Healing" }, -- 43-44
          { 1, 2, 3, 3, "Improved Power Word: Shield" }, -- 45-47
          { 1, 2, 2, 2, "Improved Power Word: Fortitude" }, -- 48-49
          { 1, 3, 3, 3, "Meditation" }, -- 50-52
          { 1, 3, 2, 1, "Inner Focus" }, -- 53
          { 1, 2, 1, 1, "Silent Resolve" }, -- 54
          { 1, 4, 2, 5, "Mental Agility" }, -- 55-59
          { 1, 5, 3, 1, "Divine Spirit" }, -- 60
        },
      },
    },
  },
  SHAMAN = {
    default = "ENHANCEMENT",
    bySpec = {
      LEVELING = "ENHANCEMENT",
      ENHANCEMENT = "ENHANCEMENT",
      ELEMENTAL = "ELEMENTAL",
      RESTORATION = "RESTORATION",
    },
    builds = {
      -- Two-handers, Flurry and Stormstrike, then Restoration.
      ENHANCEMENT = {
        name = "Enhancement leveling (0/31/20)",
        picks = {
          { 2, 1, 2, 5, "Ancestral Knowledge" }, -- 10-14
          { 2, 2, 2, 5, "Thundering Strikes" }, -- 15-19
          { 2, 2, 3, 2, "Improved Ghost Wolf" }, -- 20-21
          { 2, 3, 3, 1, "Two-Handed Axes and Maces" }, -- 22
          { 2, 3, 1, 2, "Enhancing Totems" }, -- 23-24
          { 2, 4, 2, 5, "Flurry" }, -- 25-29
          { 2, 5, 2, 3, "Elemental Weapons" }, -- 30-32
          { 2, 5, 1, 2, "Improved Weapon Totems" }, -- 33-34
          { 2, 6, 3, 5, "Weapon Mastery" }, -- 35-39
          { 2, 7, 2, 1, "Stormstrike" }, -- 40
          { 3, 1, 2, 5, "Improved Healing Wave" }, -- 41-45
          { 3, 1, 3, 5, "Tidal Focus" }, -- 46-50
          { 3, 3, 1, 3, "Nature's Guidance" }, -- 51-53
          { 3, 2, 3, 2, "Totemic Focus" }, -- 54-55
          { 3, 4, 2, 5, "Restorative Totems" }, -- 56-60
        },
      },
      -- Lightning Mastery and Elemental Mastery, then Restoration.
      ELEMENTAL = {
        name = "Elemental (31/0/20)",
        picks = {
          { 1, 1, 2, 5, "Convection" }, -- 10-14
          { 1, 1, 3, 5, "Concussion" }, -- 15-19
          { 1, 3, 3, 5, "Call of Thunder" }, -- 20-24
          { 1, 3, 1, 1, "Elemental Focus" }, -- 25
          { 1, 2, 3, 3, "Call of Flame" }, -- 26-28
          { 1, 4, 2, 1, "Eye of the Storm" }, -- 29
          { 1, 5, 2, 1, "Elemental Fury" }, -- 30
          { 1, 3, 2, 4, "Reverberation" }, -- 31-34
          { 1, 6, 3, 5, "Lightning Mastery" }, -- 35-39
          { 1, 7, 2, 1, "Elemental Mastery" }, -- 40
          { 3, 1, 3, 5, "Tidal Focus" }, -- 41-45
          { 3, 2, 3, 5, "Totemic Focus" }, -- 46-50
          { 3, 3, 1, 3, "Nature's Guidance" }, -- 51-53
          { 3, 2, 1, 2, "Improved Reincarnation" }, -- 54-55
          { 3, 4, 3, 5, "Tidal Mastery" }, -- 56-60
        },
      },
      -- Healer: Nature's Swiftness and Mana Tide Totem.
      RESTORATION = {
        name = "Restoration (0/20/31)",
        picks = {
          { 3, 1, 2, 5, "Improved Healing Wave" }, -- 10-14
          { 3, 1, 3, 5, "Tidal Focus" }, -- 15-19
          { 3, 2, 2, 3, "Ancestral Healing" }, -- 20-22
          { 3, 3, 3, 1, "Totemic Mastery" }, -- 23
          { 3, 3, 1, 1, "Nature's Guidance" }, -- 24
          { 3, 4, 2, 5, "Restorative Totems" }, -- 25-29
          { 3, 4, 3, 5, "Tidal Mastery" }, -- 30-34
          { 3, 5, 1, 3, "Healing Way" }, -- 35-37
          { 3, 5, 3, 1, "Nature's Swiftness" }, -- 38
          { 3, 6, 3, 1, "Purification" }, -- 39
          { 3, 7, 2, 1, "Mana Tide Totem" }, -- 40
          { 2, 1, 2, 5, "Ancestral Knowledge" }, -- 41-45
          { 2, 2, 2, 5, "Thundering Strikes" }, -- 46-50
          { 2, 2, 3, 2, "Improved Ghost Wolf" }, -- 51-52
          { 2, 3, 1, 2, "Enhancing Totems" }, -- 53-54
          { 2, 3, 4, 1, "Anticipation" }, -- 55
          { 2, 4, 3, 5, "Toughness" }, -- 56-60
        },
      },
    },
  },
  MAGE = {
    default = "FROST",
    bySpec = {
      LEVELING = "FROST",
      FROST = "FROST",
      FIRE = "FIRE",
      ARCANE = "ARCANE",
    },
    builds = {
      -- Frostbolt, Shatter and Ice Barrier, then Arcane for Arcane Concentration.
      FROST = {
        name = "Frost leveling (20/0/31)",
        picks = {
          { 3, 1, 2, 5, "Improved Frostbolt" }, -- 10-14
          { 3, 1, 3, 3, "Elemental Precision" }, -- 15-17
          { 3, 2, 1, 5, "Ice Shards" }, -- 18-22
          { 3, 2, 3, 2, "Improved Frost Nova" }, -- 23-24
          { 3, 3, 2, 1, "Cold Snap" }, -- 25
          { 3, 3, 1, 3, "Piercing Ice" }, -- 26-28
          { 3, 4, 2, 3, "Frost Channeling" }, -- 29-31
          { 3, 4, 3, 5, "Shatter" }, -- 32-36
          { 3, 5, 2, 1, "Ice Block" }, -- 37
          { 3, 5, 3, 2, "Improved Cone of Cold" }, -- 38-39
          { 3, 7, 2, 1, "Ice Barrier" }, -- 40
          { 1, 1, 1, 2, "Arcane Subtlety" }, -- 41-42
          { 1, 1, 2, 3, "Arcane Focus" }, -- 43-45
          { 1, 2, 3, 5, "Arcane Concentration" }, -- 46-50
          { 1, 3, 2, 3, "Improved Arcane Explosion" }, -- 51-53
          { 1, 3, 3, 1, "Arcane Resilience" }, -- 54
          { 1, 2, 1, 1, "Wand Specialization" }, -- 55
          { 1, 4, 4, 3, "Arcane Meditation" }, -- 56-58
          { 1, 4, 2, 2, "Improved Counterspell" }, -- 59-60
        },
      },
      -- Ignite, Blast Wave and Combustion, then Arcane.
      FIRE = {
        name = "Fire (20/31/0)",
        picks = {
          { 2, 1, 2, 5, "Improved Fireball" }, -- 10-14
          { 2, 2, 1, 5, "Ignite" }, -- 15-19
          { 2, 3, 3, 1, "Pyroblast" }, -- 20
          { 2, 3, 1, 2, "Incinerate" }, -- 21-22
          { 2, 1, 3, 2, "Impact" }, -- 23-24
          { 2, 4, 4, 3, "Master of Elements" }, -- 25-27
          { 2, 2, 3, 2, "Improved Fire Blast" }, -- 28-29
          { 2, 5, 2, 3, "Critical Mass" }, -- 30-32
          { 2, 5, 3, 1, "Blast Wave" }, -- 33
          { 2, 1, 3, 1, "Impact" }, -- 34
          { 2, 6, 3, 5, "Fire Power" }, -- 35-39
          { 2, 7, 2, 1, "Combustion" }, -- 40
          { 1, 1, 1, 2, "Arcane Subtlety" }, -- 41-42
          { 1, 1, 2, 3, "Arcane Focus" }, -- 43-45
          { 1, 2, 3, 5, "Arcane Concentration" }, -- 46-50
          { 1, 3, 2, 3, "Improved Arcane Explosion" }, -- 51-53
          { 1, 3, 3, 1, "Arcane Resilience" }, -- 54
          { 1, 2, 1, 1, "Wand Specialization" }, -- 55
          { 1, 4, 4, 3, "Arcane Meditation" }, -- 56-58
          { 1, 4, 2, 2, "Improved Counterspell" }, -- 59-60
        },
      },
      -- Presence of Mind and Arcane Power, then Frost.
      ARCANE = {
        name = "Arcane (31/0/20)",
        picks = {
          { 1, 1, 1, 2, "Arcane Subtlety" }, -- 10-11
          { 1, 1, 2, 3, "Arcane Focus" }, -- 12-14
          { 1, 2, 3, 5, "Arcane Concentration" }, -- 15-19
          { 1, 3, 2, 3, "Improved Arcane Explosion" }, -- 20-22
          { 1, 3, 3, 1, "Arcane Resilience" }, -- 23
          { 1, 2, 1, 1, "Wand Specialization" }, -- 24
          { 1, 4, 4, 3, "Arcane Meditation" }, -- 25-27
          { 1, 4, 2, 2, "Improved Counterspell" }, -- 28-29
          { 1, 5, 2, 1, "Presence of Mind" }, -- 30
          { 1, 5, 3, 5, "Arcane Mind" }, -- 31-35
          { 1, 6, 2, 3, "Arcane Instability" }, -- 36-38
          { 1, 1, 3, 1, "Improved Arcane Missiles" }, -- 39
          { 1, 7, 2, 1, "Arcane Power" }, -- 40
          { 3, 1, 2, 5, "Improved Frostbolt" }, -- 41-45
          { 3, 1, 3, 3, "Elemental Precision" }, -- 46-48
          { 3, 2, 1, 5, "Ice Shards" }, -- 49-53
          { 3, 2, 3, 2, "Improved Frost Nova" }, -- 54-55
          { 3, 3, 1, 3, "Piercing Ice" }, -- 56-58
          { 3, 4, 2, 2, "Frost Channeling" }, -- 59-60
        },
      },
    },
  },
  WARLOCK = {
    default = "AFFLICTION",
    bySpec = {
      LEVELING = "AFFLICTION",
      AFFLICTION = "AFFLICTION",
      DEMONOLOGY = "DEMONOLOGY",
      DESTRUCTION = "DESTRUCTION",
    },
    builds = {
      -- Corruption, Nightfall and Siphon Life, then Demonology for the Voidwalker.
      AFFLICTION = {
        name = "Affliction leveling (31/20/0)",
        picks = {
          { 1, 1, 3, 5, "Improved Corruption" }, -- 10-14
          { 1, 2, 3, 2, "Improved Life Tap" }, -- 15-16
          { 1, 2, 4, 3, "Improved Drain Life" }, -- 17-19
          { 1, 3, 1, 3, "Improved Curse of Agony" }, -- 20-22
          { 1, 3, 2, 2, "Fel Concentration" }, -- 23-24
          { 1, 4, 2, 2, "Nightfall" }, -- 25-26
          { 1, 4, 1, 2, "Grim Reach" }, -- 27-28
          { 1, 3, 3, 1, "Amplify Curse" }, -- 29
          { 1, 5, 2, 1, "Siphon Life" }, -- 30
          { 1, 2, 2, 2, "Improved Drain Soul" }, -- 31-32
          { 1, 3, 2, 2, "Fel Concentration" }, -- 33-34
          { 1, 6, 2, 5, "Shadow Mastery" }, -- 35-39
          { 1, 7, 2, 1, "Dark Pact" }, -- 40
          { 2, 1, 3, 5, "Demonic Embrace" }, -- 41-45
          { 2, 2, 2, 3, "Improved Voidwalker" }, -- 46-48
          { 2, 1, 1, 2, "Improved Healthstone" }, -- 49-50
          { 2, 3, 2, 1, "Fel Domination" }, -- 51
          { 2, 3, 3, 4, "Fel Stamina" }, -- 52-55
          { 2, 4, 2, 2, "Master Summoner" }, -- 56-57
          { 2, 4, 3, 3, "Unholy Power" }, -- 58-60
        },
      },
      -- Demonic Sacrifice, Master Demonologist and Soul Link, then Affliction.
      DEMONOLOGY = {
        name = "Demonology (20/31/0)",
        picks = {
          { 2, 1, 3, 5, "Demonic Embrace" }, -- 10-14
          { 2, 1, 2, 3, "Improved Imp" }, -- 15-17
          { 2, 2, 2, 2, "Improved Voidwalker" }, -- 18-19
          { 2, 3, 2, 1, "Fel Domination" }, -- 20
          { 2, 3, 3, 5, "Fel Stamina" }, -- 21-25
          { 2, 4, 2, 2, "Master Summoner" }, -- 26-27
          { 2, 4, 3, 2, "Unholy Power" }, -- 28-29
          { 2, 5, 2, 1, "Demonic Sacrifice" }, -- 30
          { 2, 4, 3, 3, "Unholy Power" }, -- 31-33
          { 2, 2, 3, 1, "Fel Intellect" }, -- 34
          { 2, 6, 3, 5, "Master Demonologist" }, -- 35-39
          { 2, 7, 2, 1, "Soul Link" }, -- 40
          { 1, 1, 3, 5, "Improved Corruption" }, -- 41-45
          { 1, 2, 3, 2, "Improved Life Tap" }, -- 46-47
          { 1, 2, 4, 3, "Improved Drain Life" }, -- 48-50
          { 1, 3, 1, 3, "Improved Curse of Agony" }, -- 51-53
          { 1, 3, 2, 2, "Fel Concentration" }, -- 54-55
          { 1, 4, 2, 2, "Nightfall" }, -- 56-57
          { 1, 4, 1, 2, "Grim Reach" }, -- 58-59
          { 1, 3, 3, 1, "Amplify Curse" }, -- 60
        },
      },
      -- Shadow Bolt, Shadowburn and Ruin, with Demonic Sacrifice.
      DESTRUCTION = {
        name = "Destruction (0/21/30)",
        picks = {
          { 3, 1, 2, 5, "Improved Shadow Bolt" }, -- 10-14
          { 3, 1, 3, 5, "Cataclysm" }, -- 15-19
          { 3, 2, 2, 5, "Bane" }, -- 20-24
          { 3, 3, 3, 5, "Devastation" }, -- 25-29
          { 3, 3, 4, 1, "Shadowburn" }, -- 30
          { 3, 5, 3, 1, "Ruin" }, -- 31
          { 3, 4, 2, 2, "Destructive Reach" }, -- 32-33
          { 3, 4, 1, 2, "Intensity" }, -- 34-35
          { 3, 2, 3, 4, "Aftermath" }, -- 36-39
          { 2, 1, 3, 5, "Demonic Embrace" }, -- 40-44
          { 2, 2, 2, 3, "Improved Voidwalker" }, -- 45-47
          { 2, 1, 1, 2, "Improved Healthstone" }, -- 48-49
          { 2, 3, 2, 1, "Fel Domination" }, -- 50
          { 2, 3, 3, 5, "Fel Stamina" }, -- 51-55
          { 2, 4, 2, 2, "Master Summoner" }, -- 56-57
          { 2, 4, 3, 2, "Unholy Power" }, -- 58-59
          { 2, 5, 2, 1, "Demonic Sacrifice" }, -- 60
        },
      },
    },
  },
  DRUID = {
    default = "FERAL",
    bySpec = {
      LEVELING = "FERAL",
      FERAL = "FERAL",
      BALANCE = "BALANCE",
      RESTORATION = "RESTORATION",
    },
    builds = {
      -- Furor first, cat and bear talents to Leader of the Pack, then Omen of Clarity.
      FERAL = {
        name = "Feral leveling (11/31/9)",
        picks = {
          { 3, 1, 3, 5, "Furor" }, -- 10-14
          { 2, 1, 2, 5, "Ferocity" }, -- 15-19
          { 2, 2, 3, 3, "Thick Hide" }, -- 20-22
          { 2, 2, 1, 2, "Feral Instinct" }, -- 23-24
          { 2, 3, 3, 3, "Sharpened Claws" }, -- 25-27
          { 2, 3, 1, 2, "Feline Swiftness" }, -- 28-29
          { 2, 4, 2, 3, "Predatory Strikes" }, -- 30-32
          { 2, 4, 3, 2, "Blood Frenzy" }, -- 33-34
          { 2, 4, 4, 2, "Primal Fury" }, -- 35-36
          { 2, 5, 1, 2, "Savage Fury" }, -- 37-38
          { 2, 5, 3, 1, "Faerie Fire (Feral)" }, -- 39
          { 2, 6, 2, 5, "Heart of the Wild" }, -- 40-44
          { 2, 7, 2, 1, "Leader of the Pack" }, -- 45
          { 1, 1, 2, 1, "Nature's Grasp" }, -- 46
          { 1, 1, 3, 4, "Improved Nature's Grasp" }, -- 47-50
          { 1, 2, 3, 5, "Natural Weapons" }, -- 51-55
          { 1, 3, 3, 1, "Omen of Clarity" }, -- 56
          { 3, 1, 2, 4, "Improved Mark of the Wild" }, -- 57-60
        },
      },
      -- Moonfire and Starfire to Moonkin Form, then Restoration.
      BALANCE = {
        name = "Balance (31/0/20)",
        picks = {
          { 1, 1, 1, 5, "Improved Wrath" }, -- 10-14
          { 1, 2, 2, 5, "Improved Moonfire" }, -- 15-19
          { 1, 3, 4, 2, "Nature's Reach" }, -- 20-21
          { 1, 2, 1, 3, "Improved Entangling Roots" }, -- 22-24
          { 1, 4, 2, 5, "Vengeance" }, -- 25-29
          { 1, 5, 2, 1, "Nature's Grace" }, -- 30
          { 1, 5, 3, 3, "Moonglow" }, -- 31-33
          { 1, 4, 3, 1, "Improved Starfire" }, -- 34
          { 1, 6, 2, 5, "Moonfury" }, -- 35-39
          { 1, 7, 2, 1, "Moonkin Form" }, -- 40
          { 3, 1, 3, 5, "Furor" }, -- 41-45
          { 3, 1, 2, 5, "Improved Mark of the Wild" }, -- 46-50
          { 3, 3, 3, 1, "Insect Swarm" }, -- 51
          { 3, 3, 2, 3, "Reflection" }, -- 52-54
          { 3, 2, 2, 1, "Nature's Focus" }, -- 55
          { 3, 4, 2, 5, "Tranquil Spirit" }, -- 56-60
        },
      },
      -- Healer: Nature's Swiftness and Swiftmend, then Balance.
      RESTORATION = {
        name = "Restoration (20/0/31)",
        picks = {
          { 3, 1, 3, 5, "Furor" }, -- 10-14
          { 3, 2, 1, 5, "Improved Healing Touch" }, -- 15-19
          { 3, 3, 2, 3, "Reflection" }, -- 20-22
          { 3, 3, 3, 1, "Insect Swarm" }, -- 23
          { 3, 2, 2, 1, "Nature's Focus" }, -- 24
          { 3, 4, 2, 5, "Tranquil Spirit" }, -- 25-29
          { 3, 5, 1, 1, "Nature's Swiftness" }, -- 30
          { 3, 5, 3, 4, "Gift of Nature" }, -- 31-34
          { 3, 6, 3, 5, "Improved Regrowth" }, -- 35-39
          { 3, 7, 2, 1, "Swiftmend" }, -- 40
          { 1, 1, 1, 5, "Improved Wrath" }, -- 41-45
          { 1, 2, 2, 5, "Improved Moonfire" }, -- 46-50
          { 1, 3, 4, 2, "Nature's Reach" }, -- 51-52
          { 1, 3, 1, 3, "Improved Thorns" }, -- 53-55
          { 1, 4, 2, 5, "Vengeance" }, -- 56-60
        },
      },
    },
  },
}
