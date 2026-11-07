# WoW Forever talent builds for Pathwise, by talent name in point order.
# Each mirrors Pathwise's Classic build for that path (main tree to its
# capstone, the rest where Classic put it), with Forever's talents where
# Classic's are gone. validate.py checks them against Forever's trees.
B = {
 'HUNTER': {
  # The player's own Beast Mastery build (Wowhead's PvE guide), 31/16/4.
  'BM_FOREVER': ('Beast Mastery', [
    ('Deadly Aspects', 5), ('Endurance Training', 3), ('Focused Fire', 2), ('Unleashed Fury', 5),
    ('Bestial Swiftness', 1), ('Ferocity', 5), ('Summon Hawk', 1), ('Intimidation', 1), ('Bestial Discipline', 2),
    ('Frenzy', 5), ('Bestial Wrath', 1),
    ('Lethal Attacks', 5), ('Careful Aim', 5), ('Improved Stings', 3), ('Efficiency', 2), ('Trueshot Aura', 1),
    ('Improved Tracking', 4)]),
  'MM_LEVELING': ('Marksmanship leveling', [
    ('Deadly Aspects', 5), ('Endurance Training', 3), ('Focused Fire', 2), ('Unleashed Fury', 5), ('Ferocity', 5),
    ('Lethal Attacks', 5), ('Careful Aim', 5), ('Improved Arcane Shot', 5), ('Trueshot Aura', 1), ('Mortal Shots', 5),
    ('Barrage', 3), ('Efficiency', 1), ('Ranged Weapon Specialization', 5), ('Sniper Shot', 1)]),
 },
 'WARRIOR': {
  'ARMS_LEVELING': ('Arms leveling', [
    ('Improved Heroic Strike', 3), ('Improved Rend', 3), ('Improved Tactical Mastery', 3), ('Improved Overpower', 2),
    ('Anger Management', 1), ('Deep Wounds', 3), ('Two-Handed Weapon Specialization', 3), ('Impale', 2),
    ('Sweeping Strikes', 1), ('Weaponmaster', 5), ('Improved Slam', 2), ('Deflection', 2), ('Mortal Strike', 1),
    ('Cruelty', 5), ('Unbridled Wrath', 5), ('Enrage', 5), ('Booming Voice', 3), ('Improved Execute', 2)]),
  'FURY': ('Fury', [
    ('Cruelty', 5), ('Unbridled Wrath', 5), ('Enrage', 5), ('Dual Wield Specialization', 5), ('Improved Execute', 2),
    ('Death Wish', 1), ('Improved Berserker Rage', 2), ('Flurry', 3), ('Improved Whirlwind', 2), ('Bloodthirst', 1),
    ('Improved Heroic Strike', 3), ('Improved Rend', 3), ('Improved Tactical Mastery', 3), ('Improved Overpower', 2),
    ('Anger Management', 1), ('Deep Wounds', 3), ('Impale', 2), ('Deflection', 3)]),
  'PROTECTION': ('Protection', [
    ('Shield Specialization', 5), ('Anticipation', 5), ('Last Stand', 1), ('Defiance', 3), ('Master of Defense', 2),
    ('Improved Sunder Armor', 3), ('Vanguard', 1), ('Concussion Blow', 1), ('Focused Rage', 3),
    ('Improved Shield Wall', 2), ('Bastion', 4), ('Shield Slam', 1),
    ('Deflection', 5), ('Improved Heroic Strike', 3), ('Improved Tactical Mastery', 3), ('Improved Charge', 2),
    ('Anger Management', 1), ('Improved Overpower', 1), ('Cruelty', 5)]),
 },
 'MAGE': {
  'FROST': ('Frost leveling', [
    ('Improved Frostbolt', 5), ('Ice Shards', 5), ('Precision', 3), ('Frost Channeling', 3), ('Shatter', 3),
    ('Ice Block', 1), ('Ice Lance', 1), ('Cold Snap', 1), ('Improved Cone of Cold', 3), ('Fingers of Frost', 2),
    ("Winter's Chill", 3), ('Ice Barrier', 1),
    ('Wand Specialization', 2), ('Improved Channeling', 3), ('Arcane Concentration', 5), ('Arcane Subtlety', 2),
    ('Magic Absorption', 2), ('Missile Barrage', 2), ('Arcane Meditation', 3), ('Arcane Geometry', 1)]),
  'FIRE': ('Fire', [
    ('Incineration', 5), ('Ignite', 5), ('Impact', 3), ('Pyroblast', 1), ('Burning Soul', 1), ('Master of Elements', 3),
    ('Improved Scorch', 3), ('Critical Mass', 3), ('Blast Wave', 1), ('Fire Power', 3), ('Accelerant', 2),
    ('Combustion', 1),
    ('Wand Specialization', 2), ('Improved Channeling', 3), ('Arcane Concentration', 5), ('Arcane Subtlety', 2),
    ('Magic Absorption', 2), ('Missile Barrage', 2), ('Arcane Meditation', 3), ('Arcane Geometry', 1)]),
  'ARCANE': ('Arcane', [
    ('Improved Channeling', 5), ('Arcane Concentration', 5), ('Arcane Impact', 3), ('Arcane Blast', 1),
    ('Missile Barrage', 2), ('Arcane Meditation', 3), ('Arcane Wrath', 1), ('Presence of Mind', 1), ('Arcane Mind', 5),
    ('Arcane Instability', 3), ('Arcane Subtlety', 1), ('Arcane Power', 1),
    ('Improved Frostbolt', 5), ('Ice Shards', 5), ('Precision', 3), ('Frost Channeling', 3),
    ('Improved Frost Nova', 2), ('Arctic Reach', 2)]),
 },
 'PALADIN': {
  'RET_LEVELING': ('Retribution leveling', [
    ('Benediction', 5), ('Improved Judgement', 2), ('Conviction', 3), ('Seal of Command', 1), ('Vindication', 3),
    ('Pursuit of Justice', 1), ('Two-Handed Weapon Specialization', 3), ('Sacred Arbiter', 1), ('Deflection', 1),
    ('Vengeance', 3), ('Repentance', 1), ('Sanctified Judgement', 1), ('Champion of the Light', 5),
    ('Unsealed Wrath', 1),
    ('Divine Strength', 5), ('Improved Seals', 5), ('Reverence', 2), ('Illumination', 5), ('Purifying Power', 2),
    ('Divine Precision', 1)]),
  'HOLY': ('Holy', [
    ('Spiritual Focus', 5), ('Healing Light', 3), ('Reverence', 2), ('Illumination', 5), ('Divine Favor', 1),
    ('Infusion of Light', 2), ('Oath of Light', 1), ('Holy Conduit', 1), ('Holy Shock', 1), ('Boundless Light', 2),
    ('Purifying Power', 2), ('Holy Power', 4), ('Divine Precision', 1), ("Light's Vigil", 1),
    ('Divine Intellect', 5), ("Guardian's Favor", 2), ('Sacred Duty', 2), ('Precision', 1),
    ('Improved Hammer of Justice', 3), ("Templar's Bulwark", 1), ('Toughness', 1), ('Swift Judgement', 1),
    ('Anticipation', 4)]),
  'PROTECTION': ('Protection', [
    ('Redoubt', 5), ('Precision', 3), ("Guardian's Favor", 2), ('Toughness', 5), ('Shield Specialization', 2),
    ('Improved Righteous Fury', 3), ('Anticipation', 5), ('Holy Shield', 1), ('Stoicism', 2), ('Iron Creed', 2),
    ('Shieldsworn', 1),
    ('Deflection', 5), ('Improved Judgement', 2), ('Conviction', 3), ('Seal of Command', 1), ('Vindication', 3),
    ('Pursuit of Justice', 1), ('Eye for an Eye', 2), ('Sacred Arbiter', 1), ('Sanctified Judgement', 2)]),
 },
 'PRIEST': {
  'SHADOW': ('Shadow leveling', [
    ('Spirit Tap', 5), ('Improved Shadow Word: Pain', 2), ('Improved Mind Blast', 3), ('Mind Flay', 1),
    ('Improved Mind Flay', 2), ('Improved Mind Blast', 2), ('Shadow Weaving', 3), ('Vampiric Embrace', 1),
    ('Dark Inspiration', 1), ('Devouring Contagion', 2), ('Shadow Focus', 3), ('Darkness', 5), ('Shadowform', 1),
    ('Wand Specialization', 2), ('Twin Disciplines', 5), ('Mental Strength', 3), ('Improved Power Word: Shield', 3),
    ('Meditation', 3), ('Inner Focus', 1), ('Mental Agility', 3)]),
  'HEALER': ('Holy/Discipline healing', [
    ('Improved Renew', 3), ('Holy Specialization', 2), ('Divine Fury', 5), ('Inspiration', 3), ('Holy Nova', 1),
    ('Blessed Recovery', 1), ('Improved Healing', 3), ('Holy Reach', 1), ('Holy Binding', 1),
    ('Spiritual Guidance', 5), ('Spiritual Healing', 3), ('Spirit of Redemption', 1), ('Litany of Light', 1),
    ('Prayer of Mending', 1),
    ('Twin Disciplines', 5), ('Mental Strength', 5), ('Meditation', 3), ('Inner Focus', 1), ('Mental Agility', 3),
    ('Improved Power Word: Shield', 1), ('Silent Resolve', 2)]),
 },
 'DRUID': {
  'BALANCE': ('Balance', [
    ('Improved Wrath', 5), ('Moonglow', 3), ('Improved Moonfire', 2), ("Nature's Majesty", 2), ("Nature's Splendor", 1),
    ("Nature's Reach", 2), ('Vengeance', 5), ('Insect Swarm', 1), ("Nature's Grace", 1), ('Eclipse', 3),
    ('Moonfury', 5), ('Moonkin Form', 1),
    ("Nature's Focus", 5), ('Heart of the Wild', 5), ('Reflection', 3), ('Subtlety', 3), ('Tranquil Spirit', 4)]),
  'FERAL': ('Feral leveling', [
    ('Ferocity', 5), ('Furor', 5), ('Feral Instinct', 3), ('Thick Hide', 2), ('Sharpened Claws', 2),
    ('Feral Charge', 1), ('Savage Fury', 2), ('Predatory Strikes', 3), ('Blood Frenzy', 2), ('Leader of the Pack', 1),
    ('Natural Instinct', 2), ('Brutal Impact', 2), ('Rend and Tear', 5), ('Primal Bite', 1),
    ('Heart of the Wild', 5), ("Nature's Focus", 5), ('Natural Shapeshifter', 3), ('Subtlety', 2)]),
  'RESTORATION': ('Restoration', [
    ("Nature's Focus", 5), ('Naturalist', 5), ('Gift of Nature', 5), ('Tranquil Spirit', 5), ('Swiftmend', 1),
    ('Improved Rejuvenation', 3), ("Nature's Swiftness", 1), ('Living Spirit', 3), ('Improved Regrowth', 2),
    ('Wild Growth', 1),
    ('Improved Wrath', 2), ('Genesis', 3), ('Moonglow', 3), ("Nature's Reach", 2), ("Nature's Majesty", 2),
    ('Improved Moonfire', 1), ("Nature's Splendor", 1), ('Improved Entangling Roots', 1), ('Furor', 5)]),
 },
 'ROGUE': {
  'COMBAT': ('Combat swords', [
    ('Efficient Strikes', 2), ('Lightning Reflexes', 5), ('Precision', 3), ('Deflection', 3), ('Endurance', 2),
    ('Aggression', 3), ('Weapon Expertise', 2), ('Dual Wield Specialization', 2), ('Blade Flurry', 1),
    ('Hack and Slash', 5), ('Flash of Steel', 2), ('Adrenaline Rush', 1),
    ('Malice', 5), ('Ruthlessness', 3), ('Improved Slice and Dice', 2), ('Lethality', 2), ('Remorseless Attacks', 2),
    ('Improved Gouge', 1), ('Cold Blood', 1), ('Improved Expose Armor', 2), ('Blood Splatter', 1), ('Vigor', 1)]),
  'ASSASSINATION': ('Assassination daggers', [
    ('Malice', 5), ('Ruthlessness', 3), ('Improved Slice and Dice', 2), ('Lethality', 2), ('Vigor', 2),
    ('Blood Splatter', 1), ('Improved Poisons', 5), ('Cold Blood', 1), ('Vile Poisons', 2), ('Relentless Strikes', 2),
    ('Venom', 1), ('Seal Fate', 3), ('Remorseless Attacks', 1), ('Mutilate', 1),
    ('Efficient Strikes', 2), ('Lightning Reflexes', 5), ('Precision', 3), ('Puncturing Wounds', 3), ('Endurance', 2),
    ('Weapon Expertise', 2), ('Aggression', 3)]),
  'SUBTLETY': ('Subtlety hemorrhage', [
    ('Opportunity', 5), ('Improved Ambush', 3), ('Dirty Tricks', 2), ('Initiative', 3), ('Premeditation', 1),
    ('Serrated Blades', 3), ('Ghostly Strike', 1), ('Elusiveness', 2), ('Hemorrhage', 1), ('Preparation', 1),
    ('Heightened Senses', 2), ('Setup', 1), ('Boot Knife', 5), ('Death Mark', 1),
    ('Efficient Strikes', 2), ('Lightning Reflexes', 5), ('Precision', 3), ('Puncturing Wounds', 3), ('Endurance', 2),
    ('Weapon Expertise', 2), ('Aggression', 3)]),
 },
 'SHAMAN': {
  'ELEMENTAL': ('Elemental', [
    ('Convection', 5), ('Concussion', 5), ('Elemental Alacrity', 3), ('Elemental Focus', 1), ('Elemental Devastation', 1),
    ('Eye of the Storm', 3), ('Trial by Fire', 2), ('Call of Thunder', 1), ('Lightning Overload', 3),
    ('Elemental Reach', 1), ('Elemental Fury', 5), ('Lightning Mastery', 1),
    ('Tidal Focus', 5), ('Totemic Focus', 5), ('Mindfulness', 3), ('Ancestral Healing', 2), ('Tidal Mastery', 5)]),
  'ENHANCEMENT': ('Enhancement leveling', [
    ('Thundering Strikes', 5), ('Ancestral Knowledge', 5), ('Mental Dexterity', 3), ('Elemental Weapons', 1),
    ('Shamanistic Focus', 1), ('Flurry', 5), ('Stormstrike', 1), ('Spirit Weapons', 1), ('Mental Quickness', 2),
    ('Improved Stormstrike', 1), ('Maelstrom Weapon', 5), ('Rage of the Farseer', 1),
    ('Tidal Focus', 5), ('Totemic Focus', 5), ('Mindfulness', 3), ('Ancestral Healing', 2), ('Restorative Totems', 5)]),
  'RESTORATION': ('Restoration', [
    ('Improved Healing Wave', 5), ('Tidal Focus', 5), ('Healing Focus', 3), ('Ancestral Healing', 2),
    ('Tidal Mastery', 5), ('Restorative Totems', 2), ('Mana Tide Totem', 1), ('Healing Way', 3),
    ("Nature's Swiftness", 1), ('Purification', 3), ('Riptide', 1),
    ('Ancestral Knowledge', 5), ('Guardian Totems', 2), ('Mental Dexterity', 3), ('Anticipation', 3),
    ('Shamanistic Focus', 1), ('Elemental Weapons', 1), ('Toughness', 5)]),
 },
 'WARLOCK': {
  'AFFLICTION': ('Affliction leveling', [
    ('Improved Corruption', 5), ('Improved Life Tap', 2), ('Soul Harvest', 2), ('Improved Drains', 3),
    ('Amplify Curse', 1), ('Fel Concentration', 3), ('Improved Bane of Agony', 2), ('Nightfall', 2),
    ('Malevolence', 3), ('Siphon Life', 1), ('Soul Siphon', 1), ('Shadow Mastery', 5), ('Wrack', 1),
    ('Demonic Embrace', 5), ('Unholy Power', 5), ('Improved Voidwalker', 3), ('Fel Vitality', 2),
    ('Master Summoner', 2), ('Fel Domination', 1), ('Demonic Brand', 2)]),
  'DEMONOLOGY': ('Demonology', [
    ('Demonic Embrace', 5), ('Fel Vitality', 3), ('Demonic Aegis', 2), ('Master Summoner', 2),
    ('Demonic Sacrifice', 1), ('Improved Sayaad', 2), ('Fel Domination', 1), ('Decimation', 2), ('Demonic Brand', 2),
    ('Soul Link', 1), ('Demonic Knowledge', 3), ('Improved Felhunter', 1), ('Master Demonologist', 5),
    ('Demonic Pact', 1),
    ('Improved Corruption', 5), ('Improved Life Tap', 2), ('Soul Harvest', 2), ('Improved Drains', 3),
    ('Amplify Curse', 1), ('Fel Concentration', 3), ('Improved Bane of Agony', 2), ('Suppression', 2)]),
  'DESTRUCTION': ('Destruction', [
    ('Improved Shadow Bolt', 5), ('Bane', 5), ('Cataclysm', 3), ('Aftermath', 2), ('Ruin', 5), ('Shadowburn', 1),
    ('Intensity', 2), ('Conflagrate', 1), ('Bane of Havoc', 1), ('Shadow and Flame', 5), ('Incinerate', 1),
    ('Demonic Embrace', 5), ('Improved Imp', 3), ('Fel Vitality', 2), ('Demonic Sacrifice', 1),
    ('Master Summoner', 2), ('Improved Voidwalker', 2), ('Fel Domination', 1), ('Demonic Brand', 3),
    ('Decimation', 1)]),
 },
}
