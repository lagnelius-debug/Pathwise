local addonName, Pathwise = ...

-- After dying: while the player is a ghost, the arrow leads to the body
-- (to resurrect there), before anything else and even with the To-do
-- window closed. The game says where the body is (C_DeathInfo); else the
-- spot where the player died, or - inside a dungeon - its entrance. Next
-- on the arrow leaves it until the next death (for the spirit healer).

local L = Pathwise.L
local Platform = Pathwise.Platform

local Corpse = Pathwise:NewModule("Corpse")

local skipped = false

-- The body as an arrow target, or nil when its place isn't known.
function Corpse:Target()
  local mapID, x, y = Platform.GetCorpsePosition()
  local spot = Pathwise.charDB.deathSpot
  if not mapID and spot and spot.mapID then
    mapID, x, y = spot.mapID, spot.x, spot.y
  end
  if mapID then
    return { mapID = mapID, x = x, y = y, label = L.ARROW_CORPSE, corpse = true }
  end
  -- Died inside a dungeon: the way back in is its entrance.
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local dungeon = spot and spot.dungeon and DungeonGuide.Get(spot.dungeon)
  local entrance = dungeon and DungeonGuide:EntranceTarget(dungeon)
  if entrance then
    return { mapID = entrance.mapID, x = entrance.x, y = entrance.y,
      label = string.format(L.ARROW_CORPSE_DUNGEON, dungeon.name), corpse = true }
  end
end

-- Puts the arrow on the body while the player is a ghost, or takes it off.
function Corpse:Refresh()
  local ghost = Platform.IsGhost()
  if not ghost and not Platform.IsDead() then
    Pathwise.charDB.deathSpot = nil
    skipped = false
  end
  local target = ghost and Pathwise.db.corpseArrow and not skipped and self:Target() or nil
  Pathwise:GetModule("Waypoints"):SetCorpse(target)
end

-- Died: where (the body stays there).
function Corpse:OnDead()
  local mapID, x, y = Platform.GetPlayerMapPosition()
  local inside = Pathwise:GetModule("DungeonGuide"):GetInside()
  Pathwise.charDB.deathSpot = mapID and { mapID = mapID, x = x, y = y }
    or inside and { dungeon = inside.id } or nil
  skipped = false
  self:Refresh()
end

-- Next on the arrow: not to the body until the next death.
function Corpse:OnSkipped()
  skipped = true
  self:Refresh()
end

function Corpse:OnEvent()
  self:Refresh()
end

function Corpse:OnInitialize()
  self:RegisterCallback("CORPSE_SKIPPED", "OnSkipped")
end

function Corpse:OnEnable()
  self:RegisterEvent("PLAYER_DEAD", "OnDead")
  -- Released (now a ghost) or resurrected; back in the body.
  self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
  self:RegisterEvent("PLAYER_UNGHOST", "OnEvent")
  -- Another map: the body's place is asked for on the new one.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
  self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")
  self:Refresh()
end
