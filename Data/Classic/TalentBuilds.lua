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
-- Talent positions are from the 1.12 trees. TODO verify in game with
-- /pw talents check (it compares these names with the client's).

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
}
