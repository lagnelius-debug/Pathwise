local addonName, Pathwise = ...

-- WoW Forever: spells that are talents (or class quest rewards) in Classic
-- Era but that Forever's trainers teach - they're not in any of Forever's
-- talent trees (TraitDefinition, build 1.60.1.70790), and the level is
-- Forever's own (SpellLevels.BaseLevel). The training cost isn't in the
-- game's data, so it shows as unknown. Reported: Consecration and Blessing
-- of Kings missing from the recommended training.
-- (Intercept is left to the Berserker Stance quest reminder.)
if Pathwise.Platform.flavor ~= "Forever" then
  return
end

local TRAINED = {
  PALADIN = { [20217] = 20, [26573] = 20, [20473] = 40 }, -- Blessing of Kings, Consecration, Holy Shock
  HUNTER = { [19434] = 20, [19506] = 40 },                -- Aimed Shot, Trueshot Aura
  PRIEST = { [14752] = 30, [724] = 40 },                  -- Divine Spirit, Lightwell
  WARLOCK = { [17962] = 40 },                             -- Conflagrate
  DRUID = { [16689] = 10 },                               -- Nature's Grasp
}

for class, spells in pairs(TRAINED) do
  for _, entry in ipairs(Pathwise.Data.ClassSpells[class] or {}) do
    local level = spells[entry.id]
    if level then
      entry.talent = nil
      entry.level = level
      entry.cost = nil -- (unknown)
      entry.forever = true
    end
  end
end
