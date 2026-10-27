-- Pet ability guide (hunters), with LibTameable-1.0's Classic Era data.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local PetGuide = Pathwise:GetModule("PetGuide")
local NextSteps = Pathwise:GetModule("NextSteps")
local P = NextSteps.PRIORITY
local lib = LibStub("LibTameable-1.0")

local function Item(id)
  for _, item in ipairs(NextSteps:GetItems()) do
    if item.id == id then return item end
  end
end
local function Update()
  PetGuide:Update()
end

-- A level 16 cat with Bite 2 and Claw 2; the hunter is level 20.
S.class = { "Hunter", "HUNTER", 3 }
S.level = 20
WoW.FireEvent("PLAYER_LEVEL_UP", 20)
WoW.RunTimers()
S.mapID, S.mapX, S.mapY = 1439, 0.40, 0.40 -- Darkshore
local petSpells = { 17255, 16828, 1742 } -- Bite 2, Claw 2, Cower 1
S.pet = { name = "Sabertooth", happiness = 3, foods = { "Meat" } }
local petLevel = 16
local unitLevel = UnitLevel
UnitLevel = function(unit) if unit == "pet" then return petLevel end return S.level end
UnitCreatureFamily = function(unit) if unit == "pet" and S.pet then return "Cat" end end
HasPetSpells = function() return #petSpells end
-- (Pet actions come with a flag above the spell ID.)
GetSpellBookItemInfo = function(i, book) return "PETACTION", petSpells[i] and petSpells[i] + 0x1000000 end
GetSpellBookItemName = function(i) return WoW.spellNames[petSpells[i]], nil end
for id, name in pairs({ [17253] = "Bite", [17255] = "Bite", [17256] = "Bite", [16827] = "Claw", [16828] = "Claw",
  [16829] = "Claw", [1742] = "Cower", [23099] = "Dash", [24450] = "Prowl" }) do
  WoW.spellNames[id] = name
end
Pathwise.charDB.beastTraining, Pathwise.charDB.beastTrainingSeen = {}, false

---------------------------------------------------------------------------
section("Pet guide: what the pet can learn")

check("library data loaded (Classic Era)", lib:HasData() and lib:GetClient() == "era")
local upgrades = PetGuide:GetUpgrades()
local names = {}
for _, u in ipairs(upgrades) do names[#names + 1] = u.name .. " " .. u.rank end
check("level 16 cat: Bite 3 and Claw 3 (level 16 ranks), nothing at level 30 yet, no Cower",
  table.concat(names, ", ") == "Bite 3, Claw 3", table.concat(names, ", "))

---------------------------------------------------------------------------
section("Pet guide: tame a beast that teaches it")

Update()
local claw = Item("pet:16827")
check("Claw 3: tame the nearest beast that teaches it (Darkshore: Den Mother or Ghost Saber)", claw
  and (claw.text:find("^Tame a Den Mother %(level 18%-19%) to learn Claw %(Rank 3%)$")
    or claw.text:find("^Tame a Ghost Saber %(level 19%-20%) to learn Claw %(Rank 3%)$"))
  and claw.priority == P.PET_TAME, claw and claw.text)
check("arrow and target button on the beast", claw.target and claw.target.mapID == 1439 and claw.target.spawn
  and (claw.target.names[1] == "Den Mother" or claw.target.names[1] == "Ghost Saber"))
check("says to stable the pet first and how it's learned", claw.detail[2]:find("stable", 1, true)
  and claw.detail[3]:find("Beast Training", 1, true))
check("asks to open Beast Training once", claw.detail[#claw.detail]:find("Open Beast Training once", 1, true))
check("Bite 3: no beast reachable here teaches it - no step (rather than a wrong one)", Item("pet:17253") == nil)

-- Too low to tame them: no step
S.level = 17 -- (only the guide reads it here; the tracked level never goes down)
local realSnapshot = Pathwise:GetModule("Character").GetSnapshot
local fake = setmetatable({ level = 17 }, { __index = realSnapshot(Pathwise:GetModule("Character")) })
Pathwise:GetModule("Character").GetSnapshot = function() return fake end
Update()
check("hunter too low to tame the teachers: no step", Item("pet:16827") == nil)
Pathwise:GetModule("Character").GetSnapshot = realSnapshot
S.level = 20

---------------------------------------------------------------------------
section("Pet guide: Beast Training")

-- Opening Beast Training: Claw 3 is known already
local crafts = { { "Bite", "Rank 2" }, { "Claw", "Rank 3" }, { "Growl", "Rank 2" } }
GetCraftDisplaySkillLine = function() return "Beast Training" end
GetNumCrafts = function() return #crafts end
GetCraftInfo = function(i) return crafts[i][1], crafts[i][2], "optimal", 0, nil, 10, 16 end
WoW.FireEvent("CRAFT_SHOW")
WoW.RunTimers()
check("Beast Training read", Pathwise.charDB.beastTrainingSeen and Pathwise.charDB.beastTraining[16829])
claw = Item("pet:16827")
check("known rank: teach it in Beast Training", claw and claw.text == "Teach Claw (Rank 3) to Sabertooth in Beast Training"
  and claw.priority == P.PET_TEACH and claw.target == nil)
GetCraftDisplaySkillLine = function() return "Enchanting" end
Pathwise.charDB.beastTraining[16829] = true
WoW.FireEvent("CRAFT_SHOW")
WoW.RunTimers()
check("another craft window (Enchanting) changes nothing", Pathwise.charDB.beastTraining[16829] == true)

-- The pet learned it: no step
petSpells[2] = 16829
Update()
check("pet has Claw 3: no Claw step", Item("pet:16827") == nil)

---------------------------------------------------------------------------
section("Pet guide: /pw pet and the switch")

WoW.ClearChat()
WoW.Slash("pet")
check("/pw pet: pet, family, level and what to learn", WoW.ChatContains("Sabertooth (Cat, level 16):")
  and WoW.ChatContains("Bite (Rank 3): tame"))
Pathwise.db.petGuide = false
Update()
check("pet guide off: no steps", Item("pet:16827") == nil and Item("pet:17253") == nil)
Pathwise.db.petGuide = true
S.pet = nil
Update()
WoW.ClearChat()
WoW.Slash("pet")
check("no pet: says to call it", WoW.ChatContains("Call your pet first."))

-- Clean up
UnitLevel, UnitCreatureFamily, HasPetSpells, GetSpellBookItemInfo = unitLevel, nil, nil, nil
GetSpellBookItemName = nil
GetCraftDisplaySkillLine, GetNumCrafts, GetCraftInfo = nil, nil, nil
