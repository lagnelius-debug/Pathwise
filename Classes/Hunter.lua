local addonName, Pathwise = ...

-- Hunter module (only active for hunters):
--   ammo   warn when ammo runs low or none is equipped
--   pet    remind to feed the pet when it isn't happy, with its diet
--   taming at level 10, point to the hunter trainer's "Taming the Beast"
--          quest until Tame Beast is learned
-- Each puts an item in the Next Steps window and says it once in chat.

local L = Pathwise.L
local Platform = Pathwise.Platform
local Data = Pathwise.Data

local Hunter = Pathwise:NewModule("Hunter")

local UPDATE_DELAY = 0.5

local updatePending = false
local lastAmmoState  -- "ok", "low", "critical", "none" or "noweapon"
local lastHappiness  -- pet happiness at the previous update

local function GetSnapshot()
  return Pathwise:GetModule("Character"):GetSnapshot()
end

local function IsHunter()
  return GetSnapshot().class == "HUNTER"
end

---------------------------------------------------------------------------
-- Ammo
---------------------------------------------------------------------------

-- "ARROWS", "BULLETS", or nil when the ranged weapon needs no ammo (thrown)
-- or there is none.
local function AmmoKind()
  local ranged = GetSnapshot().equipment[18]
  local info = ranged and Platform.GetItemInfo(ranged.link or ranged.itemID)
  return info and Data.Hunter.AMMO_KIND[info.subclassID]
end

-- Pure function: ammo state for a count and thresholds.
function Hunter.AmmoState(count, hasAmmo, warn, critical)
  if not hasAmmo then
    return "none"
  elseif count < critical then
    return "critical"
  elseif count < warn then
    return "low"
  end
  return "ok"
end

local STATE_RANK = { ok = 0, low = 1, critical = 2, none = 3 }

local function AmmoItems()
  local kind = AmmoKind()
  if not kind then
    lastAmmoState = "noweapon"
    return {}
  end
  local count, itemID = Platform.GetAmmo()
  local db = Pathwise.db
  local state = Hunter.AmmoState(count, itemID ~= nil, db.ammoWarn, db.ammoCritical)
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local noun = L["AMMO_" .. kind]

  -- Chat when it gets worse (not on every bag update).
  if STATE_RANK[state] > (STATE_RANK[lastAmmoState] or 0) and db.chatMessages then
    if state == "none" then
      Pathwise:Printf(L.AMMO_NONE_CHAT, noun)
    elseif state == "critical" then
      Pathwise:Printf(L.AMMO_CRITICAL_CHAT, count, noun)
    elseif state == "low" then
      Pathwise:Printf(L.AMMO_LOW_CHAT, count, noun)
    end
  end
  lastAmmoState = state

  if state == "none" then
    return { { id = "ammo", priority = P.AMMO_CRITICAL, text = string.format(L.AMMO_NONE, noun) } }
  elseif state == "critical" then
    return { { id = "ammo", priority = P.AMMO_CRITICAL, text = string.format(L.AMMO_CRITICAL, count, noun) } }
  elseif state == "low" then
    return { { id = "ammo", priority = P.AMMO_LOW, text = string.format(L.AMMO_LOW, count, noun) } }
  end
  return {}
end

---------------------------------------------------------------------------
-- Pet
---------------------------------------------------------------------------

local function PetItems()
  local pet = Platform.GetHunterPet()
  local happiness = pet and pet.happiness
  local items = {}
  if happiness and happiness < 3 then
    local P = Pathwise:GetModule("NextSteps").PRIORITY
    local mood = happiness == 1 and L.PET_UNHAPPY or L.PET_CONTENT
    local diet = #pet.foodTypes > 0 and table.concat(pet.foodTypes, ", ") or "?"
    items[1] = {
      id = "pet",
      priority = happiness == 1 and P.PET_UNHAPPY or P.PET_FEED,
      text = string.format(L.PET_FEED, pet.name or "?", mood),
      detail = { string.format(L.PET_DIET, diet), L.PET_HOW },
    }
    -- Chat when the mood drops (summoning an unhappy pet counts too).
    if (lastHappiness == nil or happiness < lastHappiness) and Pathwise.db.chatMessages then
      Pathwise:Printf(L.PET_FEED_CHAT, pet.name or "?", mood, diet)
    end
  end
  lastHappiness = happiness
  return items
end

---------------------------------------------------------------------------
-- Taming quest
---------------------------------------------------------------------------

-- True if a quest of the taming chain is in the quest log.
local function TamingQuestInLog(firstQuestID)
  for _, quest in ipairs(Platform.GetQuestLog()) do
    if quest.questID == firstQuestID or Data.Hunter.TAMING_TITLES[quest.title] then
      return true
    end
  end
  return false
end

local function TamingItems()
  local snapshot = GetSnapshot()
  if (snapshot.level or 1) < Data.Hunter.TAMING_LEVEL or Platform.IsSpellKnown(Data.Hunter.TAME_BEAST_SPELL) then
    return {}
  end
  -- Already on the quests: the quest step (and its arrow) takes over;
  -- pointing back at the trainer would send the player the wrong way.
  if TamingQuestInLog(Data.Hunter.TAMING_QUESTS[snapshot.race]) then
    return {}
  end
  local P = Pathwise:GetModule("NextSteps").PRIORITY
  local questID = Data.Hunter.TAMING_QUESTS[snapshot.race]
  local item = {
    id = "taming",
    priority = P.TAMING,
    text = L.TAMING_STEP,
    detail = { L.TAMING_DETAIL },
  }
  if questID then
    item.target = Pathwise:GetModule("QuestieData"):GetQuestGiverTarget(questID, L.TAMING_TARGET)
  end
  local charDB = Pathwise.charDB
  if not charDB.tamingReminded and Pathwise.db.chatMessages then
    charDB.tamingReminded = true
    Pathwise:Print(L.TAMING_CHAT)
  end
  return { item }
end

---------------------------------------------------------------------------
-- Updates
---------------------------------------------------------------------------

function Hunter:Update()
  if not IsHunter() then
    return
  end
  local items = {}
  for _, list in ipairs({ AmmoItems(), PetItems(), TamingItems() }) do
    for _, item in ipairs(list) do
      items[#items + 1] = item
    end
  end
  Pathwise:GetModule("NextSteps"):SetItems("hunter", items)
end

function Hunter:ScheduleUpdate()
  if updatePending then
    return
  end
  updatePending = true
  Platform.After(UPDATE_DELAY, function()
    updatePending = false
    Hunter:Update()
  end)
end

local UPDATE_SECTIONS = { all = true, level = true, equipment = true, bags = true }

function Hunter:OnCharacterUpdated(_, _, section)
  if UPDATE_SECTIONS[section] then
    self:ScheduleUpdate()
  end
end

function Hunter:OnUnitEvent(_, unit)
  if unit == nil or unit == "player" or unit == "pet" then
    self:ScheduleUpdate()
  end
end

function Hunter:OnSpellLearned()
  self:ScheduleUpdate()
end

function Hunter:OnInitialize()
  self:RegisterCallback("CHARACTER_UPDATED", "OnCharacterUpdated")
end

function Hunter:OnEnable()
  if not IsHunter() then
    return
  end
  self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnUnitEvent")
  self:RegisterEvent("UNIT_PET", "OnUnitEvent")
  self:RegisterEvent("UNIT_HAPPINESS", "OnUnitEvent")
  self:RegisterEvent("PET_UI_UPDATE", "OnUnitEvent")
  self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "OnSpellLearned")
  self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnSpellLearned")
  self:RegisterEvent("QUEST_LOG_UPDATE", "ScheduleUpdate") -- taming quests picked up / done
  self:ScheduleUpdate()
end

-- /pw ammo [warn] [critical]
Pathwise:RegisterCommand("ammo", function(args)
  local warn, critical = args:match("^(%d+)%s+(%d+)$")
  warn, critical = tonumber(warn), tonumber(critical)
  if warn and critical and critical < warn then
    Pathwise.db.ammoWarn, Pathwise.db.ammoCritical = warn, critical
    lastAmmoState = nil
    Hunter:Update()
  elseif args ~= "" then
    Pathwise:Print(L.AMMO_USAGE)
    return
  end
  local count = Platform.GetAmmo()
  Pathwise:Printf(L.AMMO_STATUS, count, Pathwise.db.ammoWarn, Pathwise.db.ammoCritical)
end, L.CMD_AMMO)
