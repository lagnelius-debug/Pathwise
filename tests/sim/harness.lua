-- Real-data simulations: Pathwise on the mock client (tests/mock_wow.lua)
-- with QuestieDB's WoW Forever data (tests/sim/fetch.sh) and the game's map
-- rectangles (tests/sim/MapRects.lua). Each scenario runs in a process of
-- its own (tests/sim/check.lua); see tests/sim/run.sh.
--
--   local H = dofile("tests/sim/harness.lua")
--   local Pathwise = H.Load({ level = 20, mapID = 1433, x = 0.3, y = 0.45, faction = "Alliance",
--     done = H.TypicalDone(16, {}, "Alliance") })
--   H.SetLog({ H.LogEntry(id), ... })

package.path = "./tests/?.lua;" .. package.path
local WoW = require("mock_wow")
local S = WoW.state

local H = { WoW = WoW }
local QDB = "tests/sim/.cache/QuestieDB"

local function ReadFile(path)
  local f = io.open(path, "rb")
  if not f then
    error("missing " .. path .. " - run tests/sim/fetch.sh first", 0)
  end
  local text = f:read("*a")
  f:close()
  return text
end

-- A QuestieDB data or support file, run with only what it needs: it sets
-- tables on the modules QuestieLoader hands it.
local modules = { QuestieDB = {}, ZoneDB = { private = {} } }
local function RunDataFile(path)
  local chunk = assert(loadstring(ReadFile(path), "@" .. path))
  setfenv(chunk, {
    QuestieLoader = { ImportModule = function(_, name) modules[name] = modules[name] or {} return modules[name] end },
    UnitFactionGroup = function() return S.faction and S.faction[1] or "Alliance" end,
    pairs = pairs, ipairs = ipairs, type = type, tostring = tostring, tonumber = tonumber, table = table,
    string = string, math = math, setmetatable = setmetatable,
  })
  chunk()
end
for _, file in ipairs({ "Quest", "Npc", "Item", "Object" }) do
  RunDataFile(QDB .. "/data/Forever/forever" .. file .. "DB.lua")
end
RunDataFile(QDB .. "/support/Forever/Zones/areaIdToUiMapId.lua")

local DB = modules.QuestieDB
local function Rows(source)
  return assert(loadstring(source))()
end
DB.quests, DB.npcs, DB.items, DB.objects = Rows(DB.questData), Rows(DB.npcData), Rows(DB.itemData), Rows(DB.objectData)
H.DB = DB

local function Entity(rows, keys)
  local ids
  return {
    Get = function(id, key)
      local row = rows[id]
      return row and keys[key] and row[keys[key]] or nil
    end,
    GetAllIds = function()
      if not ids then
        ids = {}
        for id in pairs(rows) do
          ids[#ids + 1] = id
        end
        table.sort(ids)
      end
      return ids
    end,
  }
end

-- LibQuestieDB's public API, as much as Pathwise uses.
LibQuestieDB = {
  RequireContract = function() return true end,
  Support = { Get = function(name) return modules[name] end },
  Quest = Entity(DB.quests, DB.questKeys),
  Npc = Entity(DB.npcs, DB.npcKeys),
  Item = Entity(DB.items, DB.itemKeys),
  Object = Entity(DB.objects, DB.objectKeys),
}
local function Q(id, key)
  return LibQuestieDB.Quest.Get(id, key)
end
H.Q = Q

-- AreaId -> UiMapId, as Pathwise merges them.
local areaToUiMap = {}
for _, source in ipairs({ modules.ZoneDB.private.areaIdToUiMapId, modules.ZoneDB.private.areaIdToUiMapIdOverride }) do
  for area, map in pairs(type(source) == "string" and assert(loadstring(source))() or source or {}) do
    areaToUiMap[area] = map
  end
end
H.areaToUiMap = areaToUiMap

-- The game's map rectangles (world yards).
WoW.mapRects = dofile("tests/sim/MapRects.lua")

-- Faction bits in requiredRaces (WoW Forever adds bits above 32).
local ALLIANCE_BITS, HORDE_BITS = { 1, 4, 8, 64 }, { 2, 16, 32, 128 }
local function HasBit(n, bit)
  return math.floor(n / bit) % 2 == 1
end
local function ForFaction(races, faction)
  races = (races or 0) % 4294967296
  if races == 0 then
    return true
  end
  for _, bit in ipairs(faction == "Horde" and HORDE_BITS or ALLIANCE_BITS) do
    if HasBit(races, bit) then
      return true
    end
  end
  return false
end
H.ForFaction = ForFaction

-- Loads Pathwise for a character: opts { level, mapID, x, y, faction
-- ("Alliance"/"Horde"), class ({ "Hunter", "HUNTER", 3 }), race, done
-- ([questID] = true), zone }.
function H.Load(opts)
  local faction = opts.faction or "Alliance"
  S.class = opts.class or { "Hunter", "HUNTER", 3 }
  S.race = opts.race or (faction == "Horde" and { "Orc", "Orc", 2 } or { "Night Elf", "NightElf", 4 })
  S.faction = { faction, faction }
  S.level, S.xp, S.xpMax = opts.level, 100, 20000
  S.zone, S.subZone, S.mapID, S.mapX, S.mapY = opts.zone or "Z", "", opts.mapID, opts.x, opts.y
  local Pathwise = WoW.LoadAddon("./Pathwise_Vanilla.toc", "Pathwise")
  WoW.FireEvent("ADDON_LOADED", "Pathwise")
  WoW.FireEvent("PLAYER_LOGIN")
  WoW.FireEvent("PLAYER_ENTERING_WORLD", true, false)
  H.Pathwise = Pathwise
  local done = opts.done or {}
  H.done = done
  C_QuestLog = C_QuestLog or {}
  C_QuestLog.IsQuestFlaggedCompleted = function(id) return done[id] == true end
  IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
  local QuestieData = Pathwise:GetModule("QuestieData")
  QuestieData:ResetPickups()
  QuestieData:PickupsReady()
  for _ = 1, 400 do
    WoW.RunTimers()
  end
  return Pathwise
end

-- A quest log entry for a quest (objectives from QuestieDB, not done; all
-- done with complete = true).
function H.LogEntry(id, complete)
  local objectives = {}
  local o = Q(id, "objectives") or {}
  for _, row in ipairs(o[1] or {}) do
    local npc = DB.npcs[row[1]]
    objectives[#objectives + 1] = { text = (row[2] or (npc and npc[1]) or "?") .. " slain: " .. (complete and "5/5" or "0/5"),
      finished = complete or false }
  end
  for _, row in ipairs(o[3] or {}) do
    local item = DB.items[row[1]]
    objectives[#objectives + 1] = { text = ((item and item[1]) or "?") .. ": " .. (complete and "1/1" or "0/1"),
      type = "item", finished = complete or false }
  end
  return { title = Q(id, "name"), level = Q(id, "questLevel"), questID = id, complete = complete and 1 or nil,
    objectives = objectives }
end

function H.SetLog(entries)
  WoW.questLog = entries
  WoW.FireEvent("QUEST_LOG_UPDATE")
  H.Pathwise:GetModule("QuestAdvisor"):ScheduleUpdate()
  for _ = 1, 20 do
    WoW.RunTimers()
  end
end

-- Quests given in a map's zone around a level (not done, for the faction):
-- up to n IDs, in ID order.
function H.ZoneQuests(mapID, level, n, faction, done)
  local found = {}
  for _, id in ipairs(LibQuestieDB.Quest.GetAllIds()) do
    local lvl = Q(id, "questLevel") or 0
    local repeatable = (Q(id, "specialFlags") or 0) % 2 == 1
    if not done[id] and not repeatable and lvl >= level - 3 and lvl <= level + 1
      and (Q(id, "requiredLevel") or 1) <= level and ForFaction(Q(id, "requiredRaces"), faction) then
      local here = false
      for _, npcId in ipairs((Q(id, "startedBy") or {})[1] or {}) do
        local spawns = LibQuestieDB.Npc.Get(npcId, "spawns") or {}
        for area in pairs(spawns) do
          here = here or areaToUiMap[area] == mapID
        end
      end
      if here then
        found[#found + 1] = id
        if #found >= n then
          break
        end
      end
    end
  end
  return found
end

-- What a typical character has done: every quest up to a quest level (with
-- a zone, not repeatable, for the faction), and the chains before `extra`.
function H.TypicalDone(maxQuestLevel, extra, faction)
  local done = {}
  for _, id in ipairs(LibQuestieDB.Quest.GetAllIds()) do
    local lvl = Q(id, "questLevel") or 0
    local sort = Q(id, "zoneOrSort") or 0
    local repeatable = (Q(id, "specialFlags") or 0) % 2 == 1
    if lvl > 0 and lvl <= maxQuestLevel and sort > 0 and not repeatable
      and ForFaction(Q(id, "requiredRaces"), faction or "Alliance") then
      done[id] = true
    end
  end
  local function Pre(id, depth)
    if depth > 10 then
      return
    end
    for _, key in ipairs({ "preQuestSingle", "preQuestGroup" }) do
      for _, pre in ipairs(Q(id, key) or {}) do
        done[pre] = true
        Pre(pre, depth + 1)
      end
    end
  end
  for _, id in ipairs(extra or {}) do
    Pre(id, 0)
  end
  return done
end

-- The quest steps, as plain text lines ("priority id text").
function H.Steps()
  local lines = {}
  for _, item in ipairs(H.Pathwise:GetModule("NextSteps"):GetItems()) do
    lines[#lines + 1] = { priority = item.priority, id = item.id,
      text = ((item.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), item = item }
  end
  return lines
end

return H
