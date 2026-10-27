local addonName, Pathwise = ...

-- Travel (Core/Travel.lua): regions that walking alone can't connect, and
-- the portals and boats between them. The arrow leads to a connector first
-- when the destination is in another region (e.g. Rut'theran Village from
-- the top of Teldrassil: only through the portal in Darnassus).
--
-- Positions are { uiMapID, x, y } with x, y 0-1. Sources: the VanillaGuide
-- addon's Teldrassil and Darkshore routes (Darnassus portal "gate at 30,41";
-- Nessa Shadowsong 56,92 and the hippogryph master 58,93 in Rut'theran;
-- Auberdine docks around 33-35,40-43). Zeppelin towers: where each route's
-- zeppelin master stands (QuestieDB); Ratchet and Booty Bay: next to the
-- wharfmasters. Other boat docks are approximate: the arrow gets you to the
-- right place and the label says which boat.

Pathwise.Data.Travel = {
  -- Checked in order; the first match names the region. box = { x1, y1,
  -- x2, y2 } on that map. Maps not listed fall back to their continent.
  AREAS = {
    { region = "RUTTHERAN", mapID = 1438, box = { 0.50, 0.86, 0.62, 0.99 } }, -- Rut'theran Village
    { region = "TELDRASSIL", mapID = 1438 }, -- Teldrassil (the top of the tree)
    { region = "TELDRASSIL", mapID = 1457 }, -- Darnassus
    { region = "FEATHERMOON", mapID = 1444, box = { 0.24, 0.33, 0.36, 0.56 } }, -- Sardor Isle, Feralas
  },
  -- Continent (world instance ID) -> region for maps not in AREAS.
  CONTINENTS = { [1] = "KALIMDOR", [0] = "EASTERN_KINGDOMS" },
  -- Continent (world instance ID) -> its world map (what flight maps show).
  CONTINENT_MAPS = { [1] = 1414, [0] = 1415 },

  -- Capitals belong to the zone around them when deciding what's "in this
  -- zone" (finish the zone before leaving it): uiMapID -> zone uiMapID.
  ZONE_GROUPS = {
    [1457] = 1438, -- Darnassus -> Teldrassil
    [1453] = 1429, -- Stormwind -> Elwynn Forest
    [1455] = 1426, -- Ironforge -> Dun Morogh
    [1454] = 1411, -- Orgrimmar -> Durotar
    [1456] = 1412, -- Thunder Bluff -> Mulgore
    [1458] = 1420, -- Undercity -> Tirisfal Glades
  },

  -- One-way connectors (each direction listed). Their cost in "yards on
  -- foot", on top of walking to them: cost (a fixed part: waiting for the
  -- boat) plus the distance crossed times pace (how long the crossing takes
  -- compared to running it; a portal is instant). Between continents the
  -- distance can't be measured: sail is the crossing in yards instead (the
  -- ships take 5-6 minutes for a round trip, so about 2 minutes 20 one way).
  -- faction: only for that faction (the docks or towers are in its towns).
  CONNECTORS = {
    { from = "TELDRASSIL", to = "RUTTHERAN", label = "TRAVEL_PORTAL_TO_RUTTHERAN", cost = 0,
      entry = { 1457, 0.30, 0.41 }, exit = { 1438, 0.56, 0.895 } },
    { from = "RUTTHERAN", to = "TELDRASSIL", label = "TRAVEL_PORTAL_TO_DARNASSUS", cost = 0,
      entry = { 1438, 0.56, 0.895 }, exit = { 1457, 0.30, 0.41 } },
    -- Boats sail about as fast as you run, and you wait for one about a
    -- minute on average.
    { from = "RUTTHERAN", to = "KALIMDOR", label = "TRAVEL_BOAT_TO_AUBERDINE", cost = 500, pace = 0.8,
      entry = { 1438, 0.55, 0.94 }, exit = { 1439, 0.33, 0.41 } },
    { from = "KALIMDOR", to = "RUTTHERAN", label = "TRAVEL_BOAT_TO_RUTTHERAN", cost = 500, pace = 0.8,
      entry = { 1439, 0.33, 0.41 }, exit = { 1438, 0.55, 0.94 } },

    -- Feathermoon Stronghold, on an island off Feralas.
    { from = "KALIMDOR", to = "FEATHERMOON", label = "TRAVEL_BOAT_TO_FEATHERMOON", cost = 500, pace = 0.8,
      faction = "Alliance", entry = { 1444, 0.433, 0.428 }, exit = { 1444, 0.310, 0.398 } },
    { from = "FEATHERMOON", to = "KALIMDOR", label = "TRAVEL_BOAT_FROM_FEATHERMOON", cost = 500, pace = 0.8,
      faction = "Alliance", entry = { 1444, 0.310, 0.398 }, exit = { 1444, 0.433, 0.428 } },

    -- Between the continents. Alliance boats: Auberdine and Theramore to
    -- Menethil Harbor (Wetlands).
    { from = "KALIMDOR", to = "EASTERN_KINGDOMS", label = "TRAVEL_BOAT_AUBERDINE_TO_MENETHIL", cost = 500, sail = 1000,
      faction = "Alliance", entry = { 1439, 0.324, 0.439 }, exit = { 1437, 0.046, 0.571 } },
    { from = "EASTERN_KINGDOMS", to = "KALIMDOR", label = "TRAVEL_BOAT_MENETHIL_TO_AUBERDINE", cost = 500, sail = 1000,
      faction = "Alliance", entry = { 1437, 0.046, 0.571 }, exit = { 1439, 0.324, 0.439 } },
    { from = "KALIMDOR", to = "EASTERN_KINGDOMS", label = "TRAVEL_BOAT_THERAMORE_TO_MENETHIL", cost = 500, sail = 1000,
      faction = "Alliance", entry = { 1445, 0.716, 0.564 }, exit = { 1437, 0.050, 0.634 } },
    { from = "EASTERN_KINGDOMS", to = "KALIMDOR", label = "TRAVEL_BOAT_MENETHIL_TO_THERAMORE", cost = 500, sail = 1000,
      faction = "Alliance", entry = { 1437, 0.050, 0.634 }, exit = { 1445, 0.716, 0.564 } },
    -- The goblin boat, for everyone: Ratchet (the Barrens) to Booty Bay.
    { from = "KALIMDOR", to = "EASTERN_KINGDOMS", label = "TRAVEL_BOAT_RATCHET_TO_BOOTY_BAY", cost = 500, sail = 1100,
      entry = { 1413, 0.637, 0.386 }, exit = { 1434, 0.259, 0.731 } },
    { from = "EASTERN_KINGDOMS", to = "KALIMDOR", label = "TRAVEL_BOAT_BOOTY_BAY_TO_RATCHET", cost = 500, sail = 1100,
      entry = { 1434, 0.259, 0.731 }, exit = { 1413, 0.637, 0.386 } },
    -- Horde zeppelins: the towers outside Orgrimmar (Durotar), outside
    -- Undercity (Tirisfal Glades) and at Grom'gol (Stranglethorn Vale).
    { from = "KALIMDOR", to = "EASTERN_KINGDOMS", label = "TRAVEL_ZEPPELIN_ORGRIMMAR_TO_UNDERCITY", cost = 500, sail = 1100,
      faction = "Horde", entry = { 1411, 0.508, 0.135 }, exit = { 1420, 0.607, 0.589 } },
    { from = "EASTERN_KINGDOMS", to = "KALIMDOR", label = "TRAVEL_ZEPPELIN_UNDERCITY_TO_ORGRIMMAR", cost = 500, sail = 1100,
      faction = "Horde", entry = { 1420, 0.607, 0.589 }, exit = { 1411, 0.508, 0.135 } },
    { from = "KALIMDOR", to = "EASTERN_KINGDOMS", label = "TRAVEL_ZEPPELIN_ORGRIMMAR_TO_GROMGOL", cost = 500, sail = 1000,
      faction = "Horde", entry = { 1411, 0.507, 0.129 }, exit = { 1434, 0.315, 0.294 } },
    { from = "EASTERN_KINGDOMS", to = "KALIMDOR", label = "TRAVEL_ZEPPELIN_GROMGOL_TO_ORGRIMMAR", cost = 500, sail = 1000,
      faction = "Horde", entry = { 1434, 0.315, 0.294 }, exit = { 1411, 0.507, 0.129 } },
    -- Undercity - Grom'gol stays on the Eastern Kingdoms, but saves the long
    -- walk through the whole continent.
    { from = "EASTERN_KINGDOMS", to = "EASTERN_KINGDOMS", label = "TRAVEL_ZEPPELIN_UNDERCITY_TO_GROMGOL", cost = 500, sail = 1000,
      faction = "Horde", entry = { 1420, 0.618, 0.592 }, exit = { 1434, 0.314, 0.299 } },
    { from = "EASTERN_KINGDOMS", to = "EASTERN_KINGDOMS", label = "TRAVEL_ZEPPELIN_GROMGOL_TO_UNDERCITY", cost = 500, sail = 1000,
      faction = "Horde", entry = { 1434, 0.314, 0.299 }, exit = { 1420, 0.618, 0.592 } },
  },
}
