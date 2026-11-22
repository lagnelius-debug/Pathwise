local addonName, Pathwise = ...

-- New spell ranks onto the action bars: learning a higher rank (Frostbolt
-- Rank 5) puts it on the action buttons that held the highest lower rank
-- of that spell (Rank 4), so it's used straight away. A lower rank kept on
-- a button of its own as well (Rank 1, to slow) stays. Action buttons
-- can't change in combat, nor with something on the cursor: then it
-- waits. Off on the Features page.

local L = Pathwise.L
local Platform = Pathwise.Platform

local ActionBarRanks = Pathwise:NewModule("ActionBarRanks")

-- Seconds between tries while the cursor holds something.
ActionBarRanks.RETRY_SECONDS = 1

local pending = {} -- [spellID] = true: learned, not yet put on the bars
local retrying = false

-- Pure: the action slots to change for a learned rank. slots: list of
-- { slot, name, rank } of the spells on the bars. Returns the slots
-- holding the highest lower rank of the same spell, and that rank.
function ActionBarRanks.SlotsToUpgrade(name, rank, slots)
  local highest
  for _, entry in ipairs(slots) do
    if entry.name == name and entry.rank and entry.rank < rank and (not highest or entry.rank > highest) then
      highest = entry.rank
    end
  end
  local list = {}
  for _, entry in ipairs(slots) do
    if highest and entry.name == name and entry.rank == highest then
      list[#list + 1] = entry.slot
    end
  end
  return list, highest
end

-- Puts a learned rank on the bars. False when it has to wait (combat, the
-- cursor); true when done or there was nothing to do.
function ActionBarRanks:Upgrade(spellID)
  local name, newText = Platform.GetSpellDisplay(spellID)
  local rank = Platform.GetSpellRank(spellID)
  if not name or not rank then
    return true
  end
  local slots, oldID = {}, {}
  for slot = 1, Platform.ACTION_SLOTS do
    local id = Platform.GetActionSpell(slot)
    if id and id ~= spellID and Platform.GetSpellName(id) == name then
      slots[#slots + 1] = { slot = slot, name = name, rank = Platform.GetSpellRank(id) }
      oldID[slot] = id
    end
  end
  local list = ActionBarRanks.SlotsToUpgrade(name, rank, slots)
  if #list == 0 then
    return true
  end
  if Platform.InCombat() or Platform.CursorHolds() then
    return false
  end
  local _, oldText = Platform.GetSpellDisplay(oldID[list[1]])
  for _, slot in ipairs(list) do
    Platform.PlaceSpellOnAction(slot, spellID)
  end
  if Pathwise.db.chatMessages then
    Pathwise:Printf(L.ACTIONBAR_RANK_UPGRADED, name, newText or tostring(rank), oldText or "?")
  end
  return true
end

-- Tries the learned ranks; what has to wait waits for the end of combat or
-- an empty cursor.
function ActionBarRanks:Process()
  for spellID in pairs(pending) do
    if self:Upgrade(spellID) then
      pending[spellID] = nil
    end
  end
  if next(pending) == nil then
    return
  end
  if Platform.InCombat() then
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
  elseif not retrying then
    retrying = true
    Platform.After(ActionBarRanks.RETRY_SECONDS, function()
      retrying = false
      ActionBarRanks:Process()
    end)
  end
end

function ActionBarRanks:OnCombatEnded()
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
  self:Process()
end

function ActionBarRanks:OnSpellLearned(_, spellID)
  if not Pathwise.db.actionBarRanks or type(spellID) ~= "number" then
    return
  end
  pending[spellID] = true
  self:Process()
end

function ActionBarRanks:OnEnable()
  -- (Renamed in 1.15.x; WoW Forever has the new name. Both are harmless.)
  self:RegisterEvent("LEARNED_SPELL_IN_TAB", "OnSpellLearned")
  self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE", "OnSpellLearned")
end
