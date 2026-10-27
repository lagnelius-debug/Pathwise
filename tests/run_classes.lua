-- All classes: trainer spells, talent builds, stat weights, gear and the
-- path choices for every class, not only the hunter.
local WoW, Pathwise, check, section = ...
local Data = Pathwise.Data

local CLASSES = { "HUNTER", "WARRIOR", "PALADIN", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

---------------------------------------------------------------------------
section("Classes: data for every class")

for _, class in ipairs(CLASSES) do
  local specs = Data.ClassSpecs[class]
  check(class .. ": trees and goals", specs and #specs.trees == 3 and specs.goals and specs.goals[1] == "LEVELING")
  for _, goal in ipairs(specs.goals) do
    check(class .. ": goal " .. goal .. " has a name", Pathwise.L["SPEC_" .. goal] ~= "SPEC_" .. goal)
  end
  check(class .. ": gear", Data.ClassGear[class] and Data.ClassGear[class].armor[0] == 1)
  check(class .. ": leveling weights", Data.StatWeights[class] and Data.StatWeights[class].LEVELING)

  -- Trainer spells: unique IDs, levels and costs, every rank's previous
  -- rank in the list (or named with `requires`), optional spells exist.
  local spells = Data.ClassSpells[class]
  local ids, ranks, names, problems = {}, {}, {}, {}
  for _, entry in ipairs(spells or {}) do
    if ids[entry.id] then problems[#problems + 1] = "duplicate " .. entry.id end
    ids[entry.id] = true
    names[entry.name] = true
    ranks[entry.name .. ":" .. (entry.rank or 0)] = true
    if not entry.talent and not (entry.level and entry.cost) then problems[#problems + 1] = "no level/cost " .. entry.id end
  end
  for _, entry in ipairs(spells or {}) do
    if entry.rank and entry.rank > 1 and not ranks[entry.name .. ":" .. (entry.rank - 1)] and not entry.requires then
      problems[#problems + 1] = "rank gap " .. entry.name .. " " .. entry.rank
    end
  end
  check(class .. ": trainer spells (" .. #(spells or {}) .. ") " .. table.concat(problems, ", "),
    spells and #spells > 50 and #problems == 0)
  local unknown = {}
  for spec, list in pairs(Data.SpellPriority[class] or {}) do
    for name in pairs(list) do
      if not names[name] then unknown[#unknown + 1] = spec .. ":" .. name end
    end
  end
  check(class .. ": optional spells are trainer spells " .. table.concat(unknown, ", "), #unknown == 0)

  -- Talent builds: every goal has one; 51 points, tiers open in order, no
  -- talent over 5 ranks, one name per position.
  local builds = Data.TalentBuilds[class]
  for _, goal in ipairs(specs.goals) do
    local key = builds.bySpec[goal] or builds.default
    check(class .. ": build for " .. goal, builds.builds[key] ~= nil)
  end
  for key, build in pairs(builds.builds) do
    local total, inTree, perTalent, nameAt, bad = 0, { 0, 0, 0 }, {}, {}, {}
    for _, pick in ipairs(build.picks) do
      local tab, tier, column, count, name = unpack(pick)
      local position = tab .. ":" .. tier .. ":" .. column
      if inTree[tab] < (tier - 1) * 5 then bad[#bad + 1] = "tier " .. name end
      if nameAt[position] and nameAt[position] ~= name then bad[#bad + 1] = "position " .. name end
      nameAt[position] = name
      perTalent[position] = (perTalent[position] or 0) + count
      if perTalent[position] > 5 then bad[#bad + 1] = "ranks " .. name end
      inTree[tab] = inTree[tab] + count
      total = total + count
    end
    local split = string.format("(%d/%d/%d)", inTree[1], inTree[2], inTree[3])
    check(class .. " " .. key .. ": 51 points, valid order " .. table.concat(bad, ", "),
      total == 51 and #bad == 0 and build.name:find(split, 1, true) ~= nil)
  end
end

---------------------------------------------------------------------------
section("Classes: trainer filters race and faction spells")

local Trainer = Pathwise:GetModule("Trainer")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
local saved = { class = snapshot.class, raceID = snapshot.raceID, faction = snapshot.faction, level = snapshot.level }

local function Has(class, raceID, faction, level, id)
  snapshot.class, snapshot.raceID, snapshot.faction, snapshot.level = class, raceID, faction, level
  local list = Trainer:BuildList()
  for _, item in ipairs(list.available) do
    if item.id == id then return true end
  end
  return false
end

-- Touch of Weakness rank 2 (19261) is Undead only and needs rank 1 (2652,
-- from the priest quest).
WoW.knownSpells[2652] = true
check("priest: Undead gets Touch of Weakness rank 2", Has("PRIEST", 5, "Horde", 20, 19261))
check("priest: Troll doesn't", not Has("PRIEST", 8, "Horde", 20, 19261))
WoW.knownSpells[2652] = nil
check("priest: Undead without rank 1 doesn't either", not Has("PRIEST", 5, "Horde", 20, 19261))
check("mage: Alliance learns Teleport: Ironforge", Has("MAGE", 1, "Alliance", 20, 3562))
check("mage: Horde doesn't", not Has("MAGE", 2, "Horde", 20, 3562))
check("mage: Horde learns Teleport: Orgrimmar", Has("MAGE", 2, "Horde", 20, 3567))
-- Bear abilities need Bear Form (5487, from the druid quest).
check("druid: no Bash without Bear Form", not Has("DRUID", 4, "Alliance", 14, 5211))
WoW.knownSpells[5487] = true
check("druid: Bash with Bear Form", Has("DRUID", 4, "Alliance", 14, 5211))
WoW.knownSpells[5487] = nil

-- Needs a spell the player has a higher rank of (the client may stop
-- reporting the lower one): Greater Blessing of Might needs rank 6.
WoW.knownSpells[25291] = true -- Blessing of Might rank 7
check("paladin: Greater Blessing with a higher Blessing of Might rank", Has("PALADIN", 1, "Alliance", 60, 25782))
WoW.knownSpells[25291] = nil
WoW.knownSpells[19837] = true -- rank 5: rank 6 and the Greater Blessing in the same visit
check("paladin: Greater Blessing with rank 6 learnable in the same visit", Has("PALADIN", 1, "Alliance", 52, 25782))
WoW.knownSpells[19837] = nil
-- Coming soon: not the bear abilities without Bear Form (a class quest).
local function Upcoming(class, level, id)
  snapshot.class, snapshot.raceID, snapshot.faction, snapshot.level = class, 4, "Alliance", level
  for _, item in ipairs(Trainer:BuildList().upcoming) do
    if item.id == id then return true end
  end
  return false
end
check("druid: Bash not coming soon without Bear Form", not Upcoming("DRUID", 12, 5211))
WoW.knownSpells[5487] = true
check("druid: Bash coming soon with Bear Form", Upcoming("DRUID", 12, 5211))
WoW.knownSpells[5487] = nil
check("druid: cat abilities coming soon (Cat Form is a trainer spell)", Upcoming("DRUID", 18, 1082))

snapshot.class, snapshot.raceID, snapshot.faction, snapshot.level = saved.class, saved.raceID, saved.faction, saved.level
Trainer:BuildList()

---------------------------------------------------------------------------
section("Classes: talent picks split over two steps")

-- Arms leveling: Deflection 2 at 13-14, 3 more at 37-39.
local Talents = Pathwise:GetModule("Talents")
local ARMS = Data.TalentBuilds.WARRIOR.builds.ARMS_LEVELING
local function Tree(points, talents)
  return { points = points, talents = talents }
end
local deflection = { name = "Deflection", tier = 1, column = 2, rank = 2, maxRank = 5 }
local trees = {
  Tree(30, {
    { name = "Improved Heroic Strike", tier = 1, column = 1, rank = 3, maxRank = 3 },
    deflection,
    { name = "Improved Rend", tier = 1, column = 3, rank = 3, maxRank = 3 },
    { name = "Tactical Mastery", tier = 2, column = 2, rank = 5, maxRank = 5 },
    { name = "Improved Overpower", tier = 3, column = 1, rank = 2, maxRank = 2 },
    { name = "Anger Management", tier = 3, column = 2, rank = 1, maxRank = 1 },
    { name = "Deep Wounds", tier = 3, column = 3, rank = 3, maxRank = 3 },
    { name = "Two-Handed Weapon Specialization", tier = 4, column = 2, rank = 5, maxRank = 5 },
    { name = "Impale", tier = 4, column = 3, rank = 2, maxRank = 2 },
    { name = "Sweeping Strikes", tier = 5, column = 2, rank = 1, maxRank = 1 },
    { name = "Mortal Strike", tier = 7, column = 2, rank = 0, maxRank = 1 },
  }),
  Tree(0, {}),
  Tree(0, {}),
}
local upcoming = Talents.UpcomingPoints(trees, ARMS, 5)
local text = {}
for _, point in ipairs(upcoming) do text[#text + 1] = point.name .. " " .. point.rank end
check("split pick: Deflection 3, 4, 5, then Mortal Strike (" .. table.concat(text, ", ") .. ")",
  table.concat(text, ", ") == "Deflection 3, Deflection 4, Deflection 5, Mortal Strike 1, Cruelty 1")
check("split pick: no points off the build", Talents.OffBuildPoints(trees, ARMS) == 0)
deflection.rank = 5
upcoming = Talents.UpcomingPoints(trees, ARMS, 1)
check("split pick: done, Mortal Strike next", upcoming[1].name == "Mortal Strike")
-- A talent the client doesn't have (names changed?): the build's total ranks.
table.remove(trees[1].talents, 2)
deflection.rank = 0
upcoming = Talents.UpcomingPoints(trees, ARMS, 5)
check("split pick: unknown talent shows the build's total ranks", upcoming[1].name == "Deflection"
  and upcoming[1].maxRank == 5)
