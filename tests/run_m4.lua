-- M4: trainer reminder and spellbook Training panel.
local WoW, Pathwise, check, section = ...
local S = WoW.state

local Trainer = Pathwise:GetModule("Trainer")
local snapshot = Pathwise:GetModule("Character"):GetSnapshot()

for _, entry in ipairs(Pathwise.Data.ClassSpells.HUNTER) do
  WoW.spellNames[entry.id] = entry.name
end
WoW.spellNames[1515] = "Tame Beast"

local function Learn(...)
  for _, id in ipairs({ ... }) do WoW.knownSpells[id] = true end
  WoW.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 1, 1)
end

local function SetLevel(level)
  snapshot.level = nil
  S.level = level
  WoW.FireEvent("PLAYER_LEVEL_UP", level)
end

local function Names(items)
  local names = {}
  for _, item in ipairs(items) do names[#names + 1] = Trainer.FormatName(item) end
  return table.concat(names, ", ")
end

local function Has(items, name)
  for _, item in ipairs(items) do
    if Trainer.FormatName(item) == name then return item end
  end
end

---------------------------------------------------------------------------
section("M4: data")

local ids, ok = {}, true
for _, entry in ipairs(Pathwise.Data.ClassSpells.HUNTER) do
  if ids[entry.id] then ok = false end
  ids[entry.id] = true
  if not entry.talent and not (entry.level and entry.cost) then ok = false end
end
check("hunter spell data: unique ids, levels and costs", ok)

---------------------------------------------------------------------------
section("M4: available and upcoming")

WoW.knownSpells = {}
Pathwise.charDB.trainerAnnouncedLevel = nil
WoW.Slash("spec leveling")
Learn(1494, 13163, 1978, 3044, 1130, 5116, 3127, 14260, 13165, 13549, 19883) -- everything up to 10
WoW.ClearChat()
SetLevel(12)
local list = Trainer:GetList()
check("recommended at 12", Names(list.recommended) == "Arcane Shot (Rank 2), Wing Clip (Rank 1)")
check("Distracting Shot is optional", Names(list.optional) == "Distracting Shot (Rank 1)")
check("Mend Pet needs Tame Beast", not Has(list.available, "Mend Pet (Rank 1)"))
check("upcoming within 4 levels", Has(list.upcoming, "Immolation Trap (Rank 1)") and Has(list.upcoming, "Raptor Strike (Rank 3)")
  and not Has(list.upcoming, "Multi-Shot (Rank 1)"))
check("announcement names recommended, counts optional",
  WoW.ChatContains("New at your trainer: Arcane Shot (Rank 2), Wing Clip (Rank 1) (+1 optional). Cost: 12s."))

WoW.ClearChat()
WoW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
WoW.FireEvent("PLAYER_LEVEL_UP", 12)
check("announced only once per level", not WoW.ChatContains("New at your trainer"))

Learn(1515) -- Tame Beast from the level 10 quest
check("Mend Pet after Tame Beast", Has(Trainer:GetList().recommended, "Mend Pet (Rank 1)"))

Learn(14281, 2974, 136)
check("learned spells drop off", Names(Trainer:GetList().recommended) == "" and Names(Trainer:GetList().optional) == "Distracting Shot (Rank 1)")
WoW.ClearChat()
WoW.Slash("training")
check("/pw training with only optional", WoW.ChatContains("Optional, can skip to save gold") and WoW.ChatContains("Coming soon:"))

---------------------------------------------------------------------------
section("M4: ranks and talents")

-- A higher rank known hides lower ranks even if the client stops reporting them.
WoW.knownSpells[1978] = nil
check("lower rank counts as known via higher rank", not Has(Trainer:BuildList().available, "Serpent Sting (Rank 1)"))

-- Skipped ranks: both learnable in one visit.
WoW.knownSpells = { [3044] = true, [1515] = true }
SetLevel(20)
list = Trainer:GetList()
check("skipped ranks all available", Has(list.recommended, "Arcane Shot (Rank 2)") and Has(list.recommended, "Arcane Shot (Rank 3)"))
check("never-learned spell: every rank up to your level is available", Has(list.recommended, "Serpent Sting (Rank 1)") and Has(list.recommended, "Serpent Sting (Rank 3)"))

SetLevel(28)
check("talent rank hidden without the talent", not Has(Trainer:GetList().available, "Aimed Shot (Rank 2)"))
Learn(19434)
check("talent rank available with the talent", Has(Trainer:GetList().recommended, "Aimed Shot (Rank 2)"))

---------------------------------------------------------------------------
section("M4: path")

WoW.Slash("spec mm")
list = Trainer:GetList()
check("MM: Raptor Strike optional", Has(list.optional, "Raptor Strike (Rank 4)") and not Has(list.recommended, "Raptor Strike (Rank 4)"))
check("MM: Wing Clip still recommended", Has(list.recommended, "Wing Clip (Rank 1)"))
WoW.Slash("spec surv")
list = Trainer:GetList()
check("Survival: Raptor Strike recommended", Has(list.recommended, "Raptor Strike (Rank 4)"))
check("Survival: Dual Wield recommended", Has(list.recommended, "Dual Wield"))
WoW.Slash("spec leveling")
check("Leveling: Dual Wield optional", Has(Trainer:GetList().optional, "Dual Wield"))

---------------------------------------------------------------------------
section("M4: spellbook panel")

local panel, tab = _G.PathwiseTrainingPanel, _G.PathwiseSpellBookTab
check("panel and tab created", panel ~= nil and tab ~= nil)
SpellBookFrame:Show()
check("panel shown with the spellbook", panel:IsShown())
local function PanelHas(text)
  for i = 1, 200 do
    local frame = nil
    for _, f in ipairs(WoW.frames) do
      if f.left and f._parent and f._shown and f.left:GetText() == text then return true end
    end
    return false
  end
end
check("panel lists recommended header", PanelHas("Recommended for Leveling"))
check("panel lists a spell", PanelHas("Arcane Shot (Rank 4)"))
check("panel lists optional header", PanelHas("Optional (can skip)"))
check("tab count shows recommended", tab.count:GetText() == #Trainer:GetList().recommended)
tab:Click()
check("tab hides the panel", not panel:IsShown() and Pathwise.db.trainerPanel == false)
SpellBookFrame:Hide()
SpellBookFrame:Show()
check("panel stays hidden when reopening", not panel:IsShown())
tab:Click()
check("tab shows it again", panel:IsShown() and Pathwise.db.trainerPanel == true)
SpellBookFrame:Hide()
