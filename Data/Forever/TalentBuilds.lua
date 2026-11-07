local addonName, Pathwise = ...

-- WoW Forever's talent builds. Forever reworked the talent trees (trait
-- trees: new talents, others moved or with other ranks), so Classic's
-- builds don't fit them. These replace them on Forever, build for build,
-- under the same keys (the paths choose them as on Classic):
--   { tab, tier, column, ranks, name, node }
-- node is the talent's trait node ID - what Pathwise matches in the game
-- (tab/tier/column, Forever's grid as the talent window shows it, are the
-- fallback). Each pick spends `ranks` points in a row from level 10.
--
-- Source: Forever's talent data (TraitNode, TraitNodeEntry, TraitDefinition,
-- TraitEdge, TraitCond; client 1.60.1.70790, via wago.tools). Every build
-- was checked against it: each talent's row is open by then (5 points per
-- row in that tree), prerequisites are full first, 51 points in all. They
-- follow Pathwise's Classic build for each path (main tree to its last
-- talent, the rest where Classic put it), with Forever's talents where
-- Classic's are gone. The hunter's Beast Mastery build is a player's pick
-- (Wowhead's Forever PvE guide).

if Pathwise.Platform.flavor ~= "Forever" then
  return
end

local builds = {
    DRUID = {
      BALANCE = {
        name = "Balance (31/0/20)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Improved Wrath", 104923 }, -- 10-14
          { 1, 2, 1, 3, "Moonglow", 104925 }, -- 15-17
          { 1, 2, 2, 2, "Improved Moonfire", 104931 }, -- 18-19
          { 1, 2, 3, 2, "Nature's Majesty", 104927 }, -- 20-21
          { 1, 3, 3, 1, "Nature's Splendor", 104928 }, -- 22
          { 1, 2, 4, 2, "Nature's Reach", 104929 }, -- 23-24
          { 1, 4, 2, 5, "Vengeance", 104932 }, -- 25-29
          { 1, 4, 1, 1, "Insect Swarm", 104930 }, -- 30
          { 1, 5, 2, 1, "Nature's Grace", 104934 }, -- 31
          { 1, 5, 3, 3, "Eclipse", 104935 }, -- 32-34
          { 1, 6, 2, 5, "Moonfury", 104936 }, -- 35-39
          { 1, 7, 2, 1, "Moonkin Form", 104937 }, -- 40
          { 3, 1, 2, 5, "Nature's Focus", 104957 }, -- 41-45
          { 3, 1, 3, 5, "Heart of the Wild", 104958 }, -- 46-50
          { 3, 2, 2, 3, "Reflection", 104920 }, -- 51-53
          { 3, 3, 2, 3, "Subtlety", 104917 }, -- 54-56
          { 3, 4, 2, 4, "Tranquil Spirit", 104915 }, -- 57-60
        },
      },
      FERAL = {
        name = "Feral leveling (0/36/15)",
        gamePositions = true,
        picks = {
          { 2, 1, 2, 5, "Ferocity", 104938 }, -- 10-14
          { 2, 1, 3, 5, "Furor", 104939 }, -- 15-19
          { 2, 2, 2, 3, "Feral Instinct", 104940 }, -- 20-22
          { 2, 2, 4, 2, "Thick Hide", 104942 }, -- 23-24
          { 2, 3, 4, 2, "Sharpened Claws", 104946 }, -- 25-26
          { 2, 3, 3, 1, "Feral Charge", 104944 }, -- 27
          { 2, 3, 2, 2, "Savage Fury", 104948 }, -- 28-29
          { 2, 4, 1, 3, "Predatory Strikes", 104952 }, -- 30-32
          { 2, 4, 4, 2, "Blood Frenzy", 104947 }, -- 33-34
          { 2, 5, 2, 1, "Leader of the Pack", 104955 }, -- 35
          { 2, 5, 4, 2, "Natural Instinct", 104950 }, -- 36-37
          { 2, 2, 3, 2, "Brutal Impact", 104941 }, -- 38-39
          { 2, 6, 1, 5, "Rend and Tear", 104953 }, -- 40-44
          { 2, 7, 2, 1, "Primal Bite", 104956 }, -- 45
          { 3, 1, 3, 5, "Heart of the Wild", 104958 }, -- 46-50
          { 3, 1, 2, 5, "Nature's Focus", 104957 }, -- 51-55
          { 3, 2, 3, 3, "Natural Shapeshifter", 104919 }, -- 56-58
          { 3, 3, 2, 2, "Subtlety", 104917 }, -- 59-60
        },
      },
      RESTORATION = {
        name = "Restoration (15/5/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 2, 5, "Nature's Focus", 104957 }, -- 10-14
          { 3, 2, 1, 5, "Naturalist", 104922 }, -- 15-19
          { 3, 3, 3, 5, "Gift of Nature", 104916 }, -- 20-24
          { 3, 4, 2, 5, "Tranquil Spirit", 104915 }, -- 25-29
          { 3, 4, 4, 1, "Swiftmend", 104912 }, -- 30
          { 3, 4, 3, 3, "Improved Rejuvenation", 104914 }, -- 31-33
          { 3, 5, 1, 1, "Nature's Swiftness", 104921 }, -- 34
          { 3, 5, 2, 3, "Living Spirit", 104911 }, -- 35-37
          { 3, 6, 3, 2, "Improved Regrowth", 104913 }, -- 38-39
          { 3, 7, 2, 1, "Wild Growth", 104910 }, -- 40
          { 1, 1, 2, 2, "Improved Wrath", 104923 }, -- 41-42
          { 1, 1, 3, 3, "Genesis", 104924 }, -- 43-45
          { 1, 2, 1, 3, "Moonglow", 104925 }, -- 46-48
          { 1, 2, 4, 2, "Nature's Reach", 104929 }, -- 49-50
          { 1, 2, 3, 2, "Nature's Majesty", 104927 }, -- 51-52
          { 1, 2, 2, 1, "Improved Moonfire", 104931 }, -- 53
          { 1, 3, 3, 1, "Nature's Splendor", 104928 }, -- 54
          { 1, 3, 1, 1, "Improved Entangling Roots", 104926 }, -- 55
          { 2, 1, 3, 5, "Furor", 104939 }, -- 56-60
        },
      },
    },
    HUNTER = {
      BM_FOREVER = {
        name = "Beast Mastery (31/16/4)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Deadly Aspects", 104960 }, -- 10-14
          { 1, 1, 3, 3, "Endurance Training", 104976 }, -- 15-17
          { 1, 2, 1, 2, "Focused Fire", 104975 }, -- 18-19
          { 1, 3, 3, 5, "Unleashed Fury", 104969 }, -- 20-24
          { 1, 3, 2, 1, "Bestial Swiftness", 104970 }, -- 25
          { 1, 4, 3, 5, "Ferocity", 104967 }, -- 26-30
          { 1, 4, 4, 1, "Summon Hawk", 104966 }, -- 31
          { 1, 5, 2, 1, "Intimidation", 104964 }, -- 32
          { 1, 5, 4, 2, "Bestial Discipline", 104963 }, -- 33-34
          { 1, 6, 3, 5, "Frenzy", 104962 }, -- 35-39
          { 1, 7, 2, 1, "Bestial Wrath", 104961 }, -- 40
          { 2, 1, 3, 5, "Lethal Attacks", 105011 }, -- 41-45
          { 2, 2, 3, 5, "Careful Aim", 105008 }, -- 46-50
          { 2, 2, 1, 3, "Improved Stings", 110870 }, -- 51-53
          { 2, 2, 2, 2, "Efficiency", 105009 }, -- 54-55
          { 2, 4, 2, 1, "Trueshot Aura", 105004 }, -- 56
          { 3, 1, 2, 4, "Improved Tracking", 104996 }, -- 57-60
        },
      },
      MM_LEVELING = {
        name = "Marksmanship leveling (20/31/0)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Deadly Aspects", 104960 }, -- 10-14
          { 1, 1, 3, 3, "Endurance Training", 104976 }, -- 15-17
          { 1, 2, 1, 2, "Focused Fire", 104975 }, -- 18-19
          { 1, 3, 3, 5, "Unleashed Fury", 104969 }, -- 20-24
          { 1, 4, 3, 5, "Ferocity", 104967 }, -- 25-29
          { 2, 1, 3, 5, "Lethal Attacks", 105011 }, -- 30-34
          { 2, 2, 3, 5, "Careful Aim", 105008 }, -- 35-39
          { 2, 3, 2, 5, "Improved Arcane Shot", 105006 }, -- 40-44
          { 2, 4, 2, 1, "Trueshot Aura", 105004 }, -- 45
          { 2, 4, 3, 5, "Mortal Shots", 105002 }, -- 46-50
          { 2, 5, 3, 3, "Barrage", 105001 }, -- 51-53
          { 2, 2, 2, 1, "Efficiency", 105009 }, -- 54
          { 2, 6, 3, 5, "Ranged Weapon Specialization", 104998 }, -- 55-59
          { 2, 7, 2, 1, "Sniper Shot", 104997 }, -- 60
        },
      },
    },
    MAGE = {
      ARCANE = {
        name = "Arcane (31/0/20)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Improved Channeling", 105813 }, -- 10-14
          { 1, 2, 3, 5, "Arcane Concentration", 105810 }, -- 15-19
          { 1, 3, 2, 3, "Arcane Impact", 105807 }, -- 20-22
          { 1, 3, 4, 1, "Arcane Blast", 105806 }, -- 23
          { 1, 2, 4, 2, "Missile Barrage", 105809 }, -- 24-25
          { 1, 4, 3, 3, "Arcane Meditation", 105803 }, -- 26-28
          { 1, 4, 4, 1, "Arcane Wrath", 113627 }, -- 29
          { 1, 5, 2, 1, "Presence of Mind", 105801 }, -- 30
          { 1, 5, 3, 5, "Arcane Mind", 105800 }, -- 31-35
          { 1, 6, 3, 3, "Arcane Instability", 105799 }, -- 36-38
          { 1, 2, 1, 1, "Arcane Subtlety", 105812 }, -- 39
          { 1, 7, 2, 1, "Arcane Power", 105798 }, -- 40
          { 3, 1, 2, 5, "Improved Frostbolt", 105779 }, -- 41-45
          { 3, 2, 1, 5, "Ice Shards", 105777 }, -- 46-50
          { 3, 1, 3, 3, "Precision", 105778 }, -- 51-53
          { 3, 3, 1, 3, "Frost Channeling", 105772 }, -- 54-56
          { 3, 2, 3, 2, "Improved Frost Nova", 105775 }, -- 57-58
          { 3, 4, 1, 2, "Arctic Reach", 105770 }, -- 59-60
        },
      },
      FIRE = {
        name = "Fire (20/31/0)",
        gamePositions = true,
        picks = {
          { 2, 1, 2, 5, "Incineration", 105796 }, -- 10-14
          { 2, 2, 1, 5, "Ignite", 105794 }, -- 15-19
          { 2, 2, 3, 3, "Impact", 105792 }, -- 20-22
          { 2, 3, 3, 1, "Pyroblast", 105790 }, -- 23
          { 2, 3, 1, 1, "Burning Soul", 105789 }, -- 24
          { 2, 4, 4, 3, "Master of Elements", 105785 }, -- 25-27
          { 2, 4, 1, 3, "Improved Scorch", 105788 }, -- 28-30
          { 2, 5, 2, 3, "Critical Mass", 105784 }, -- 31-33
          { 2, 5, 3, 1, "Blast Wave", 105783 }, -- 34
          { 2, 6, 3, 3, "Fire Power", 105782 }, -- 35-37
          { 2, 1, 3, 2, "Accelerant", 105795 }, -- 38-39
          { 2, 7, 2, 1, "Combustion", 105781 }, -- 40
          { 1, 1, 1, 2, "Wand Specialization", 105815 }, -- 41-42
          { 1, 1, 2, 3, "Improved Channeling", 105813 }, -- 43-45
          { 1, 2, 3, 5, "Arcane Concentration", 105810 }, -- 46-50
          { 1, 2, 1, 2, "Arcane Subtlety", 105812 }, -- 51-52
          { 1, 2, 2, 2, "Magic Absorption", 105811 }, -- 53-54
          { 1, 2, 4, 2, "Missile Barrage", 105809 }, -- 55-56
          { 1, 4, 3, 3, "Arcane Meditation", 105803 }, -- 57-59
          { 1, 3, 1, 1, "Arcane Geometry", 105808 }, -- 60
        },
      },
      FROST = {
        name = "Frost leveling (20/0/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 2, 5, "Improved Frostbolt", 105779 }, -- 10-14
          { 3, 2, 1, 5, "Ice Shards", 105777 }, -- 15-19
          { 3, 1, 3, 3, "Precision", 105778 }, -- 20-22
          { 3, 3, 1, 3, "Frost Channeling", 105772 }, -- 23-25
          { 3, 4, 4, 3, "Shatter", 105768 }, -- 26-28
          { 3, 4, 2, 1, "Ice Block", 105769 }, -- 29
          { 3, 3, 3, 1, "Ice Lance", 105767 }, -- 30
          { 3, 5, 2, 1, "Cold Snap", 105766 }, -- 31
          { 3, 5, 1, 3, "Improved Cone of Cold", 105765 }, -- 32-34
          { 3, 5, 3, 2, "Fingers of Frost", 105764 }, -- 35-36
          { 3, 6, 3, 3, "Winter's Chill", 105763 }, -- 37-39
          { 3, 7, 2, 1, "Ice Barrier", 105762 }, -- 40
          { 1, 1, 1, 2, "Wand Specialization", 105815 }, -- 41-42
          { 1, 1, 2, 3, "Improved Channeling", 105813 }, -- 43-45
          { 1, 2, 3, 5, "Arcane Concentration", 105810 }, -- 46-50
          { 1, 2, 1, 2, "Arcane Subtlety", 105812 }, -- 51-52
          { 1, 2, 2, 2, "Magic Absorption", 105811 }, -- 53-54
          { 1, 2, 4, 2, "Missile Barrage", 105809 }, -- 55-56
          { 1, 4, 3, 3, "Arcane Meditation", 105803 }, -- 57-59
          { 1, 3, 1, 1, "Arcane Geometry", 105808 }, -- 60
        },
      },
    },
    PALADIN = {
      HOLY = {
        name = "Holy (31/20/0)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Spiritual Focus", 105335 }, -- 10-14
          { 1, 2, 1, 3, "Healing Light", 105333 }, -- 15-17
          { 1, 2, 2, 2, "Reverence", 110871 }, -- 18-19
          { 1, 3, 2, 5, "Illumination", 105329 }, -- 20-24
          { 1, 3, 1, 1, "Divine Favor", 105325 }, -- 25
          { 1, 4, 2, 2, "Infusion of Light", 110873 }, -- 26-27
          { 1, 4, 3, 1, "Oath of Light", 105330 }, -- 28
          { 1, 3, 3, 1, "Holy Conduit", 105704 }, -- 29
          { 1, 5, 2, 1, "Holy Shock", 105323 }, -- 30
          { 1, 5, 3, 2, "Boundless Light", 113631 }, -- 31-32
          { 1, 2, 4, 2, "Purifying Power", 105327 }, -- 33-34
          { 1, 6, 3, 4, "Holy Power", 105321 }, -- 35-38
          { 1, 4, 1, 1, "Divine Precision", 105324 }, -- 39
          { 1, 7, 2, 1, "Light's Vigil", 105320 }, -- 40
          { 2, 1, 2, 5, "Divine Intellect", 105332 }, -- 41-45
          { 2, 2, 2, 2, "Guardian's Favor", 105637 }, -- 46-47
          { 2, 2, 4, 2, "Sacred Duty", 105632 }, -- 48-49
          { 2, 2, 1, 1, "Precision", 105638 }, -- 50
          { 2, 3, 2, 3, "Improved Hammer of Justice", 105633 }, -- 51-53
          { 2, 3, 1, 1, "Templar's Bulwark", 105625 }, -- 54
          { 2, 3, 4, 1, "Toughness", 105630 }, -- 55
          { 2, 4, 1, 1, "Swift Judgement", 110878 }, -- 56
          { 2, 4, 3, 4, "Anticipation", 105636 }, -- 57-60
        },
      },
      PROTECTION = {
        name = "Protection (0/31/20)",
        gamePositions = true,
        picks = {
          { 2, 1, 3, 5, "Redoubt", 105626 }, -- 10-14
          { 2, 2, 1, 3, "Precision", 105638 }, -- 15-17
          { 2, 2, 2, 2, "Guardian's Favor", 105637 }, -- 18-19
          { 2, 3, 4, 5, "Toughness", 105630 }, -- 20-24
          { 2, 3, 3, 2, "Shield Specialization", 110874 }, -- 25-26
          { 2, 4, 2, 3, "Improved Righteous Fury", 105634 }, -- 27-29
          { 2, 4, 3, 5, "Anticipation", 105636 }, -- 30-34
          { 2, 5, 2, 1, "Holy Shield", 105628 }, -- 35
          { 2, 5, 1, 2, "Stoicism", 105639 }, -- 36-37
          { 2, 6, 3, 2, "Iron Creed", 110879 }, -- 38-39
          { 2, 7, 2, 1, "Shieldsworn", 110875 }, -- 40
          { 3, 1, 2, 5, "Deflection", 105707 }, -- 41-45
          { 3, 2, 1, 2, "Improved Judgement", 105705 }, -- 46-47
          { 3, 2, 2, 3, "Conviction", 105703 }, -- 48-50
          { 3, 3, 3, 1, "Seal of Command", 105696 }, -- 51
          { 3, 3, 1, 3, "Vindication", 105702 }, -- 52-54
          { 3, 3, 4, 1, "Pursuit of Justice", 105699 }, -- 55
          { 3, 4, 1, 2, "Eye for an Eye", 105698 }, -- 56-57
          { 3, 4, 2, 1, "Sacred Arbiter", 105700 }, -- 58
          { 3, 2, 3, 2, "Sanctified Judgement", 105701 }, -- 59-60
        },
      },
      RET_LEVELING = {
        name = "Retribution leveling (20/0/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 3, 5, "Benediction", 105706 }, -- 10-14
          { 3, 2, 1, 2, "Improved Judgement", 105705 }, -- 15-16
          { 3, 2, 2, 3, "Conviction", 105703 }, -- 17-19
          { 3, 3, 3, 1, "Seal of Command", 105696 }, -- 20
          { 3, 3, 1, 3, "Vindication", 105702 }, -- 21-23
          { 3, 3, 4, 1, "Pursuit of Justice", 105699 }, -- 24
          { 3, 4, 4, 3, "Two-Handed Weapon Specialization", 105697 }, -- 25-27
          { 3, 4, 2, 1, "Sacred Arbiter", 105700 }, -- 28
          { 3, 1, 2, 1, "Deflection", 105707 }, -- 29
          { 3, 5, 3, 3, "Vengeance", 105693 }, -- 30-32
          { 3, 5, 2, 1, "Repentance", 105694 }, -- 33
          { 3, 2, 3, 1, "Sanctified Judgement", 105701 }, -- 34
          { 3, 6, 3, 5, "Champion of the Light", 110882 }, -- 35-39
          { 3, 7, 2, 1, "Unsealed Wrath", 105692 }, -- 40
          { 1, 1, 3, 5, "Divine Strength", 113630 }, -- 41-45
          { 1, 2, 3, 5, "Improved Seals", 105334 }, -- 46-50
          { 1, 2, 2, 2, "Reverence", 110871 }, -- 51-52
          { 1, 3, 2, 5, "Illumination", 105329 }, -- 53-57
          { 1, 2, 4, 2, "Purifying Power", 105327 }, -- 58-59
          { 1, 4, 1, 1, "Divine Precision", 105324 }, -- 60
        },
      },
    },
    PRIEST = {
      HEALER = {
        name = "Holy/Discipline healing (20/31/0)",
        gamePositions = true,
        picks = {
          { 2, 1, 2, 3, "Improved Renew", 105866 }, -- 10-12
          { 2, 1, 3, 2, "Holy Specialization", 110855 }, -- 13-14
          { 2, 2, 3, 5, "Divine Fury", 105863 }, -- 15-19
          { 2, 3, 4, 3, "Inspiration", 105860 }, -- 20-22
          { 2, 3, 1, 1, "Holy Nova", 105862 }, -- 23
          { 2, 3, 2, 1, "Blessed Recovery", 105861 }, -- 24
          { 2, 4, 2, 3, "Improved Healing", 105858 }, -- 25-27
          { 2, 4, 1, 1, "Holy Reach", 105859 }, -- 28
          { 2, 4, 4, 1, "Holy Binding", 105856 }, -- 29
          { 2, 5, 3, 5, "Spiritual Guidance", 105853 }, -- 30-34
          { 2, 6, 3, 3, "Spiritual Healing", 105852 }, -- 35-37
          { 2, 5, 2, 1, "Spirit of Redemption", 105854 }, -- 38
          { 2, 5, 1, 1, "Litany of Light", 105855 }, -- 39
          { 2, 7, 2, 1, "Prayer of Mending", 105851 }, -- 40
          { 1, 1, 3, 5, "Twin Disciplines", 105849 }, -- 41-45
          { 1, 2, 3, 5, "Mental Strength", 105837 }, -- 46-50
          { 1, 3, 4, 3, "Meditation", 105843 }, -- 51-53
          { 1, 3, 2, 1, "Inner Focus", 105844 }, -- 54
          { 1, 3, 1, 3, "Mental Agility", 105842 }, -- 55-57
          { 1, 3, 3, 1, "Improved Power Word: Shield", 105846 }, -- 58
          { 1, 2, 1, 2, "Silent Resolve", 105848 }, -- 59-60
        },
      },
      SHADOW = {
        name = "Shadow leveling (20/0/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 3, 5, "Spirit Tap", 105833 }, -- 10-14
          { 3, 2, 3, 2, "Improved Shadow Word: Pain", 105830 }, -- 15-16
          { 3, 2, 1, 3, "Improved Mind Blast", 105831 }, -- 17-19
          { 3, 3, 3, 1, "Mind Flay", 105826 }, -- 20
          { 3, 3, 4, 2, "Improved Mind Flay", 105825 }, -- 21-22
          { 3, 2, 1, 2, "Improved Mind Blast", 105831 }, -- 23-24
          { 3, 4, 3, 3, "Shadow Weaving", 105821 }, -- 25-27
          { 3, 4, 2, 1, "Vampiric Embrace", 105820 }, -- 28
          { 3, 4, 1, 1, "Dark Inspiration", 105823 }, -- 29
          { 3, 5, 3, 2, "Devouring Contagion", 105819 }, -- 30-31
          { 3, 1, 1, 3, "Shadow Focus", 110851 }, -- 32-34
          { 3, 6, 3, 5, "Darkness", 105818 }, -- 35-39
          { 3, 7, 2, 1, "Shadowform", 105817 }, -- 40
          { 1, 1, 2, 2, "Wand Specialization", 105850 }, -- 41-42
          { 1, 1, 3, 5, "Twin Disciplines", 105849 }, -- 43-47
          { 1, 2, 3, 3, "Mental Strength", 105837 }, -- 48-50
          { 1, 3, 3, 3, "Improved Power Word: Shield", 105846 }, -- 51-53
          { 1, 3, 4, 3, "Meditation", 105843 }, -- 54-56
          { 1, 3, 2, 1, "Inner Focus", 105844 }, -- 57
          { 1, 3, 1, 3, "Mental Agility", 105842 }, -- 58-60
        },
      },
    },
    ROGUE = {
      ASSASSINATION = {
        name = "Assassination daggers (31/20/0)",
        gamePositions = true,
        picks = {
          { 1, 1, 3, 5, "Malice", 105722 }, -- 10-14
          { 1, 2, 1, 3, "Ruthlessness", 105721 }, -- 15-17
          { 1, 2, 4, 2, "Improved Slice and Dice", 105739 }, -- 18-19
          { 1, 3, 3, 2, "Lethality", 105716 }, -- 20-21
          { 1, 3, 1, 2, "Vigor", 105720 }, -- 22-23
          { 1, 3, 2, 1, "Blood Splatter", 105718 }, -- 24
          { 1, 4, 3, 5, "Improved Poisons", 105713 }, -- 25-29
          { 1, 4, 2, 1, "Cold Blood", 105715 }, -- 30
          { 1, 4, 1, 2, "Vile Poisons", 105714 }, -- 31-32
          { 1, 5, 1, 2, "Relentless Strikes", 113633 }, -- 33-34
          { 1, 5, 2, 1, "Venom", 105712 }, -- 35
          { 1, 6, 3, 3, "Seal Fate", 105710 }, -- 36-38
          { 1, 1, 2, 1, "Remorseless Attacks", 105723 }, -- 39
          { 1, 7, 2, 1, "Mutilate", 105709 }, -- 40
          { 2, 1, 2, 2, "Efficient Strikes", 105741 }, -- 41-42
          { 2, 1, 3, 5, "Lightning Reflexes", 113398 }, -- 43-47
          { 2, 2, 3, 3, "Precision", 105737 }, -- 48-50
          { 2, 2, 1, 3, "Puncturing Wounds", 105719 }, -- 51-53
          { 2, 3, 1, 2, "Endurance", 105736 }, -- 54-55
          { 2, 4, 3, 2, "Weapon Expertise", 105726 }, -- 56-57
          { 2, 4, 4, 3, "Aggression", 105730 }, -- 58-60
        },
      },
      COMBAT = {
        name = "Combat swords (20/31/0)",
        gamePositions = true,
        picks = {
          { 2, 1, 2, 2, "Efficient Strikes", 105741 }, -- 10-11
          { 2, 1, 3, 5, "Lightning Reflexes", 113398 }, -- 12-16
          { 2, 2, 3, 3, "Precision", 105737 }, -- 17-19
          { 2, 2, 2, 3, "Deflection", 105738 }, -- 20-22
          { 2, 3, 1, 2, "Endurance", 105736 }, -- 23-24
          { 2, 4, 4, 3, "Aggression", 105730 }, -- 25-27
          { 2, 4, 3, 2, "Weapon Expertise", 105726 }, -- 28-29
          { 2, 5, 1, 2, "Dual Wield Specialization", 113635 }, -- 30-31
          { 2, 5, 2, 1, "Blade Flurry", 105728 }, -- 32
          { 2, 5, 3, 5, "Hack and Slash", 105727 }, -- 33-37
          { 2, 6, 3, 2, "Flash of Steel", 105740 }, -- 38-39
          { 2, 7, 2, 1, "Adrenaline Rush", 105724 }, -- 40
          { 1, 1, 3, 5, "Malice", 105722 }, -- 41-45
          { 1, 2, 1, 3, "Ruthlessness", 105721 }, -- 46-48
          { 1, 2, 4, 2, "Improved Slice and Dice", 105739 }, -- 49-50
          { 1, 3, 3, 2, "Lethality", 105716 }, -- 51-52
          { 1, 1, 2, 2, "Remorseless Attacks", 105723 }, -- 53-54
          { 1, 1, 1, 1, "Improved Gouge", 105742 }, -- 55
          { 1, 4, 2, 1, "Cold Blood", 105715 }, -- 56
          { 1, 2, 2, 2, "Improved Expose Armor", 105717 }, -- 57-58
          { 1, 3, 2, 1, "Blood Splatter", 105718 }, -- 59
          { 1, 3, 1, 1, "Vigor", 105720 }, -- 60
        },
      },
      SUBTLETY = {
        name = "Subtlety hemorrhage (0/20/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 3, 5, "Opportunity", 105760 }, -- 10-14
          { 3, 2, 3, 3, "Improved Ambush", 105749 }, -- 15-17
          { 3, 2, 4, 2, "Dirty Tricks", 105757 }, -- 18-19
          { 3, 3, 1, 3, "Initiative", 105755 }, -- 20-22
          { 3, 3, 2, 1, "Premeditation", 105743 }, -- 23
          { 3, 3, 3, 3, "Serrated Blades", 105752 }, -- 24-26
          { 3, 4, 2, 1, "Ghostly Strike", 105754 }, -- 27
          { 3, 4, 1, 2, "Elusiveness", 105753 }, -- 28-29
          { 3, 5, 3, 1, "Hemorrhage", 105748 }, -- 30
          { 3, 5, 2, 1, "Preparation", 105746 }, -- 31
          { 3, 5, 1, 2, "Heightened Senses", 105747 }, -- 32-33
          { 3, 1, 1, 1, "Setup", 105751 }, -- 34
          { 3, 6, 3, 5, "Boot Knife", 105750 }, -- 35-39
          { 3, 7, 2, 1, "Death Mark", 110866 }, -- 40
          { 2, 1, 2, 2, "Efficient Strikes", 105741 }, -- 41-42
          { 2, 1, 3, 5, "Lightning Reflexes", 113398 }, -- 43-47
          { 2, 2, 3, 3, "Precision", 105737 }, -- 48-50
          { 2, 2, 1, 3, "Puncturing Wounds", 105719 }, -- 51-53
          { 2, 3, 1, 2, "Endurance", 105736 }, -- 54-55
          { 2, 4, 3, 2, "Weapon Expertise", 105726 }, -- 56-57
          { 2, 4, 4, 3, "Aggression", 105730 }, -- 58-60
        },
      },
    },
    SHAMAN = {
      ELEMENTAL = {
        name = "Elemental (31/0/20)",
        gamePositions = true,
        picks = {
          { 1, 1, 2, 5, "Convection", 104773 }, -- 10-14
          { 1, 1, 3, 5, "Concussion", 104772 }, -- 15-19
          { 1, 2, 3, 3, "Elemental Alacrity", 104771 }, -- 20-22
          { 1, 3, 1, 1, "Elemental Focus", 104768 }, -- 23
          { 1, 2, 1, 1, "Elemental Devastation", 104769 }, -- 24
          { 1, 4, 2, 3, "Eye of the Storm", 104763 }, -- 25-27
          { 1, 4, 1, 2, "Trial by Fire", 104764 }, -- 28-29
          { 1, 5, 2, 1, "Call of Thunder", 104760 }, -- 30
          { 1, 5, 3, 3, "Lightning Overload", 104759 }, -- 31-33
          { 1, 5, 1, 1, "Elemental Reach", 104761 }, -- 34
          { 1, 6, 3, 5, "Elemental Fury", 104766 }, -- 35-39
          { 1, 7, 2, 1, "Lightning Mastery", 104758 }, -- 40
          { 3, 1, 3, 5, "Tidal Focus", 104729 }, -- 41-45
          { 3, 2, 3, 5, "Totemic Focus", 104735 }, -- 46-50
          { 3, 2, 1, 3, "Mindfulness", 104734 }, -- 51-53
          { 3, 3, 1, 2, "Ancestral Healing", 104731 }, -- 54-55
          { 3, 4, 1, 5, "Tidal Mastery", 104738 }, -- 56-60
        },
      },
      ENHANCEMENT = {
        name = "Enhancement leveling (0/31/20)",
        gamePositions = true,
        picks = {
          { 2, 1, 2, 5, "Thundering Strikes", 104753 }, -- 10-14
          { 2, 1, 3, 5, "Ancestral Knowledge", 104756 }, -- 15-19
          { 2, 2, 2, 3, "Mental Dexterity", 104755 }, -- 20-22
          { 2, 3, 1, 1, "Elemental Weapons", 104750 }, -- 23
          { 2, 3, 3, 1, "Shamanistic Focus", 104749 }, -- 24
          { 2, 4, 2, 5, "Flurry", 104747 }, -- 25-29
          { 2, 4, 3, 1, "Stormstrike", 104743 }, -- 30
          { 2, 5, 1, 1, "Spirit Weapons", 104745 }, -- 31
          { 2, 5, 2, 2, "Mental Quickness", 104744 }, -- 32-33
          { 2, 5, 3, 1, "Improved Stormstrike", 104742 }, -- 34
          { 2, 6, 3, 5, "Maelstrom Weapon", 104741 }, -- 35-39
          { 2, 7, 2, 1, "Rage of the Farseer", 104740 }, -- 40
          { 3, 1, 3, 5, "Tidal Focus", 104729 }, -- 41-45
          { 3, 2, 3, 5, "Totemic Focus", 104735 }, -- 46-50
          { 3, 2, 1, 3, "Mindfulness", 104734 }, -- 51-53
          { 3, 3, 1, 2, "Ancestral Healing", 104731 }, -- 54-55
          { 3, 4, 2, 5, "Restorative Totems", 104730 }, -- 56-60
        },
      },
      RESTORATION = {
        name = "Restoration (0/20/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 2, 5, "Improved Healing Wave", 104739 }, -- 10-14
          { 3, 1, 3, 5, "Tidal Focus", 104729 }, -- 15-19
          { 3, 3, 2, 3, "Healing Focus", 104733 }, -- 20-22
          { 3, 3, 1, 2, "Ancestral Healing", 104731 }, -- 23-24
          { 3, 4, 1, 5, "Tidal Mastery", 104738 }, -- 25-29
          { 3, 4, 2, 2, "Restorative Totems", 104730 }, -- 30-31
          { 3, 4, 3, 1, "Mana Tide Totem", 104728 }, -- 32
          { 3, 5, 2, 3, "Healing Way", 104727 }, -- 33-35
          { 3, 5, 3, 1, "Nature's Swiftness", 104726 }, -- 36
          { 3, 6, 3, 3, "Purification", 104725 }, -- 37-39
          { 3, 7, 2, 1, "Riptide", 104724 }, -- 40
          { 2, 1, 3, 5, "Ancestral Knowledge", 104756 }, -- 41-45
          { 2, 2, 1, 2, "Guardian Totems", 104754 }, -- 46-47
          { 2, 2, 2, 3, "Mental Dexterity", 104755 }, -- 48-50
          { 2, 3, 4, 3, "Anticipation", 104748 }, -- 51-53
          { 2, 3, 3, 1, "Shamanistic Focus", 104749 }, -- 54
          { 2, 3, 1, 1, "Elemental Weapons", 104750 }, -- 55
          { 2, 4, 1, 5, "Toughness", 104746 }, -- 56-60
        },
      },
    },
    WARLOCK = {
      AFFLICTION = {
        name = "Affliction leveling (31/20/0)",
        gamePositions = true,
        picks = {
          { 1, 2, 3, 5, "Improved Corruption", 105924 }, -- 10-14
          { 1, 1, 1, 2, "Improved Life Tap", 105921 }, -- 15-16
          { 1, 3, 2, 2, "Soul Harvest", 105922 }, -- 17-18
          { 1, 3, 3, 3, "Improved Drains", 105920 }, -- 19-21
          { 1, 4, 3, 1, "Amplify Curse", 105916 }, -- 22
          { 1, 5, 2, 3, "Fel Concentration", 105918 }, -- 23-25
          { 1, 5, 1, 2, "Improved Bane of Agony", 105919 }, -- 26-27
          { 1, 6, 2, 2, "Nightfall", 105914 }, -- 28-29
          { 1, 6, 1, 3, "Malevolence", 110876 }, -- 30-32
          { 1, 7, 2, 1, "Siphon Life", 105912 }, -- 33
          { 1, 7, 3, 1, "Soul Siphon", 105911 }, -- 34
          { 1, 8, 3, 5, "Shadow Mastery", 105910 }, -- 35-39
          { 1, 9, 2, 1, "Wrack", 105909 }, -- 40
          { 2, 1, 3, 5, "Demonic Embrace", 105907 }, -- 41-45
          { 2, 1, 4, 5, "Unholy Power", 105906 }, -- 46-50
          { 2, 2, 2, 3, "Improved Voidwalker", 105904 }, -- 51-53
          { 2, 2, 3, 2, "Fel Vitality", 105903 }, -- 54-55
          { 2, 3, 3, 2, "Master Summoner", 105898 }, -- 56-57
          { 2, 4, 3, 1, "Fel Domination", 105895 }, -- 58
          { 2, 4, 4, 2, "Demonic Brand", 105896 }, -- 59-60
        },
      },
      DEMONOLOGY = {
        name = "Demonology (20/31/0)",
        gamePositions = true,
        picks = {
          { 2, 1, 3, 5, "Demonic Embrace", 105907 }, -- 10-14
          { 2, 2, 3, 3, "Fel Vitality", 105903 }, -- 15-17
          { 2, 2, 1, 2, "Demonic Aegis", 105902 }, -- 18-19
          { 2, 3, 3, 2, "Master Summoner", 105898 }, -- 20-21
          { 2, 3, 2, 1, "Demonic Sacrifice", 105900 }, -- 22
          { 2, 3, 1, 2, "Improved Sayaad", 105901 }, -- 23-24
          { 2, 4, 3, 1, "Fel Domination", 105895 }, -- 25
          { 2, 4, 1, 2, "Decimation", 105897 }, -- 26-27
          { 2, 4, 4, 2, "Demonic Brand", 105896 }, -- 28-29
          { 2, 5, 2, 1, "Soul Link", 105892 }, -- 30
          { 2, 5, 3, 3, "Demonic Knowledge", 105893 }, -- 31-33
          { 2, 5, 1, 1, "Improved Felhunter", 105894 }, -- 34
          { 2, 6, 3, 5, "Master Demonologist", 105891 }, -- 35-39
          { 2, 7, 2, 1, "Demonic Pact", 105890 }, -- 40
          { 1, 2, 3, 5, "Improved Corruption", 105924 }, -- 41-45
          { 1, 1, 1, 2, "Improved Life Tap", 105921 }, -- 46-47
          { 1, 3, 2, 2, "Soul Harvest", 105922 }, -- 48-49
          { 1, 3, 3, 3, "Improved Drains", 105920 }, -- 50-52
          { 1, 4, 3, 1, "Amplify Curse", 105916 }, -- 53
          { 1, 5, 2, 3, "Fel Concentration", 105918 }, -- 54-56
          { 1, 5, 1, 2, "Improved Bane of Agony", 105919 }, -- 57-58
          { 1, 2, 2, 2, "Suppression", 105925 }, -- 59-60
        },
      },
      DESTRUCTION = {
        name = "Destruction (0/20/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 2, 5, "Improved Shadow Bolt", 105889 }, -- 10-14
          { 3, 1, 3, 5, "Bane", 105888 }, -- 15-19
          { 3, 2, 2, 3, "Cataclysm", 105887 }, -- 20-22
          { 3, 2, 3, 2, "Aftermath", 105886 }, -- 23-24
          { 3, 3, 2, 5, "Ruin", 105883 }, -- 25-29
          { 3, 3, 3, 1, "Shadowburn", 105884 }, -- 30
          { 3, 4, 1, 2, "Intensity", 105882 }, -- 31-32
          { 3, 4, 3, 1, "Conflagrate", 105880 }, -- 33
          { 3, 5, 2, 1, "Bane of Havoc", 105876 }, -- 34
          { 3, 6, 3, 5, "Shadow and Flame", 105875 }, -- 35-39
          { 3, 7, 2, 1, "Incinerate", 105874 }, -- 40
          { 2, 1, 3, 5, "Demonic Embrace", 105907 }, -- 41-45
          { 2, 1, 2, 3, "Improved Imp", 105908 }, -- 46-48
          { 2, 2, 3, 2, "Fel Vitality", 105903 }, -- 49-50
          { 2, 3, 2, 1, "Demonic Sacrifice", 105900 }, -- 51
          { 2, 3, 3, 2, "Master Summoner", 105898 }, -- 52-53
          { 2, 2, 2, 2, "Improved Voidwalker", 105904 }, -- 54-55
          { 2, 4, 3, 1, "Fel Domination", 105895 }, -- 56
          { 2, 4, 4, 3, "Demonic Brand", 105896 }, -- 57-59
          { 2, 4, 1, 1, "Decimation", 105897 }, -- 60
        },
      },
    },
    WARRIOR = {
      ARMS_LEVELING = {
        name = "Arms leveling (31/20/0)",
        gamePositions = true,
        picks = {
          { 1, 1, 1, 3, "Improved Heroic Strike", 105958 }, -- 10-12
          { 1, 1, 3, 3, "Improved Rend", 105956 }, -- 13-15
          { 1, 2, 2, 3, "Improved Tactical Mastery", 105954 }, -- 16-18
          { 1, 2, 4, 2, "Improved Overpower", 105952 }, -- 19-20
          { 1, 3, 2, 1, "Anger Management", 105951 }, -- 21
          { 1, 3, 3, 3, "Deep Wounds", 105950 }, -- 22-24
          { 1, 4, 2, 3, "Two-Handed Weapon Specialization", 105948 }, -- 25-27
          { 1, 4, 3, 2, "Impale", 105947 }, -- 28-29
          { 1, 5, 2, 1, "Sweeping Strikes", 105945 }, -- 30
          { 1, 5, 3, 5, "Weaponmaster", 105944 }, -- 31-35
          { 1, 6, 1, 2, "Improved Slam", 110858 }, -- 36-37
          { 1, 1, 2, 2, "Deflection", 105957 }, -- 38-39
          { 1, 7, 2, 1, "Mortal Strike", 105941 }, -- 40
          { 2, 1, 3, 5, "Cruelty", 105939 }, -- 41-45
          { 2, 2, 3, 5, "Unbridled Wrath", 105937 }, -- 46-50
          { 2, 3, 4, 5, "Enrage", 105931 }, -- 51-55
          { 2, 1, 2, 3, "Booming Voice", 105938 }, -- 56-58
          { 2, 4, 4, 2, "Improved Execute", 105932 }, -- 59-60
        },
      },
      FURY = {
        name = "Fury (20/31/0)",
        gamePositions = true,
        picks = {
          { 2, 1, 3, 5, "Cruelty", 105939 }, -- 10-14
          { 2, 2, 3, 5, "Unbridled Wrath", 105937 }, -- 15-19
          { 2, 3, 4, 5, "Enrage", 105931 }, -- 20-24
          { 2, 4, 1, 5, "Dual Wield Specialization", 105933 }, -- 25-29
          { 2, 4, 4, 2, "Improved Execute", 105932 }, -- 30-31
          { 2, 5, 2, 1, "Death Wish", 105927 }, -- 32
          { 2, 5, 1, 2, "Improved Berserker Rage", 105978 }, -- 33-34
          { 2, 6, 3, 3, "Flurry", 105928 }, -- 35-37
          { 2, 6, 1, 2, "Improved Whirlwind", 105977 }, -- 38-39
          { 2, 7, 2, 1, "Bloodthirst", 105930 }, -- 40
          { 1, 1, 1, 3, "Improved Heroic Strike", 105958 }, -- 41-43
          { 1, 1, 3, 3, "Improved Rend", 105956 }, -- 44-46
          { 1, 2, 2, 3, "Improved Tactical Mastery", 105954 }, -- 47-49
          { 1, 2, 4, 2, "Improved Overpower", 105952 }, -- 50-51
          { 1, 3, 2, 1, "Anger Management", 105951 }, -- 52
          { 1, 3, 3, 3, "Deep Wounds", 105950 }, -- 53-55
          { 1, 4, 3, 2, "Impale", 105947 }, -- 56-57
          { 1, 1, 2, 3, "Deflection", 105957 }, -- 58-60
        },
      },
      PROTECTION = {
        name = "Protection (15/5/31)",
        gamePositions = true,
        picks = {
          { 3, 1, 2, 5, "Shield Specialization", 105976 }, -- 10-14
          { 3, 2, 1, 5, "Anticipation", 105975 }, -- 15-19
          { 3, 3, 1, 1, "Last Stand", 105970 }, -- 20
          { 3, 3, 4, 3, "Defiance", 110856 }, -- 21-23
          { 3, 3, 2, 2, "Master of Defense", 105971 }, -- 24-25
          { 3, 4, 1, 3, "Improved Sunder Armor", 105968 }, -- 26-28
          { 3, 4, 2, 1, "Vanguard", 105966 }, -- 29
          { 3, 5, 2, 1, "Concussion Blow", 105965 }, -- 30
          { 3, 5, 3, 3, "Focused Rage", 105961 }, -- 31-33
          { 3, 5, 1, 2, "Improved Shield Wall", 105964 }, -- 34-35
          { 3, 6, 3, 4, "Bastion", 105962 }, -- 36-39
          { 3, 7, 2, 1, "Shield Slam", 105959 }, -- 40
          { 1, 1, 2, 5, "Deflection", 105957 }, -- 41-45
          { 1, 1, 1, 3, "Improved Heroic Strike", 105958 }, -- 46-48
          { 1, 2, 2, 3, "Improved Tactical Mastery", 105954 }, -- 49-51
          { 1, 2, 1, 2, "Improved Charge", 105955 }, -- 52-53
          { 1, 3, 2, 1, "Anger Management", 105951 }, -- 54
          { 1, 2, 4, 1, "Improved Overpower", 105952 }, -- 55
          { 2, 1, 3, 5, "Cruelty", 105939 }, -- 56-60
        },
      },
    },
}

for class, list in pairs(builds) do
  local data = Pathwise.Data.TalentBuilds[class]
  for key, build in pairs(list) do
    data.builds[key] = build
  end
end

-- Hunters: Beast Mastery for the Leveling path (the default) and Survival
-- too (no build of its own); Marksmanship keeps its own.
local hunter = Pathwise.Data.TalentBuilds.HUNTER
hunter.bySpec.BEAST_MASTERY = "BM_FOREVER"
hunter.bySpec.LEVELING = "BM_FOREVER"
hunter.bySpec.SURVIVAL = "BM_FOREVER"
hunter.default = "BM_FOREVER"
