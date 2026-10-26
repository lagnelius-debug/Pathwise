local addonName, Pathwise = ...

-- Travel (Core/Travel.lua): regions that walking alone can't connect, and
-- the portals and boats between them. The arrow leads to a connector first
-- when the destination is in another region (e.g. Rut'theran Village from
-- the top of Teldrassil: only through the portal in Darnassus).
--
-- Positions are { uiMapID, x, y } with x, y 0-1. Sources: the VanillaGuide
-- addon's Teldrassil and Darkshore routes (Darnassus portal "gate at 30,41";
-- Nessa Shadowsong 56,92 and the hippogryph master 58,93 in Rut'theran;
-- Auberdine docks around 33-35,40-43). Boat docks are approximate: the
-- arrow gets you to the right place and the label says which boat.

Pathwise.Data.Travel = {
  -- Checked in order; the first match names the region. box = { x1, y1,
  -- x2, y2 } on that map. Maps not listed fall back to their continent.
  AREAS = {
    { region = "RUTTHERAN", mapID = 1438, box = { 0.50, 0.86, 0.62, 0.99 } }, -- Rut'theran Village
    { region = "TELDRASSIL", mapID = 1438 }, -- Teldrassil (the top of the tree)
    { region = "TELDRASSIL", mapID = 1457 }, -- Darnassus
  },
  -- Continent (world instance ID) -> region for maps not in AREAS.
  CONTINENTS = { [1] = "KALIMDOR", [0] = "EASTERN_KINGDOMS" },

  -- One-way connectors (each direction listed). cost: extra yards the trip
  -- counts as (waiting for a boat), on top of walking to it.
  CONNECTORS = {
    { from = "TELDRASSIL", to = "RUTTHERAN", label = "TRAVEL_PORTAL_TO_RUTTHERAN", cost = 0,
      entry = { 1457, 0.30, 0.41 }, exit = { 1438, 0.56, 0.895 } },
    { from = "RUTTHERAN", to = "TELDRASSIL", label = "TRAVEL_PORTAL_TO_DARNASSUS", cost = 0,
      entry = { 1438, 0.56, 0.895 }, exit = { 1457, 0.30, 0.41 } },
    { from = "RUTTHERAN", to = "KALIMDOR", label = "TRAVEL_BOAT_TO_AUBERDINE", cost = 400,
      entry = { 1438, 0.55, 0.94 }, exit = { 1439, 0.33, 0.41 } },
    { from = "KALIMDOR", to = "RUTTHERAN", label = "TRAVEL_BOAT_TO_RUTTHERAN", cost = 400,
      entry = { 1439, 0.33, 0.41 }, exit = { 1438, 0.55, 0.94 } },
  },
}
