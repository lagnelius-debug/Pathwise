local addonName, Pathwise = ...

-- Bug report (/pw bug): a plain-text summary of everything that helps find
-- a problem - versions, game, character, place, mode, the To-do steps, the
-- arrow and the last errors Pathwise caught. Addons can't go online, so
-- the player copies it into the GitHub bug form (UI/BugReportFrame.lua
-- shows it). The text is in English: it's for the issue tracker.

local Platform = Pathwise.Platform

local BugReport = Pathwise:NewModule("BugReport")

BugReport.ISSUE_URL = "https://github.com/lagnelius-debug/Pathwise/issues/new?template=bug_report.yml"
local MAX_STEPS = 8

-- Color codes and texture escapes out: plain text.
local function Plain(text)
  return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

local function Position(mapID, x, y)
  if not mapID then
    return "unknown"
  end
  return string.format("map %d at %.1f, %.1f", mapID, (x or 0) * 100, (y or 0) * 100)
end

function BugReport:Build()
  local lines = {}
  local function Add(text, ...)
    lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
  end
  local client = Platform.GetClientInfo()
  Add("Pathwise %s on %s", Platform.GetAddOnMetadata("Version") or "?", Platform.flavor or "?")
  Add("Client %s (build %s, interface %s, %s)", client.version or "?", client.build or "?", tostring(client.interface or "?"),
    Platform.GetLocale() or "?")
  local QuestieData = Pathwise:GetModule("QuestieData")
  Add("QuestieDB: %s", QuestieData:IsAvailable() and (Platform.GetAddOnMetadata("Version", "QuestieDB") or "loaded")
    or "not loaded")

  local s = Pathwise:GetModule("Character"):GetSnapshot()
  Add("Character: level %s %s %s (%s)", tostring(s.level or "?"), s.race or "?", s.class or "?", s.faction or "?")
  local zone = s.zone or {}
  Add("Where: %s / %s, %s", zone.zone or "?", zone.subZone or "?", Position(Platform.GetPlayerMapPosition()))
  local DungeonGuide = Pathwise:GetModule("DungeonGuide")
  local inside, dungeon = DungeonGuide:GetInside(), DungeonGuide:GetActive()
  Add("Mode: %s", inside and ("inside " .. inside.name) or dungeon and ("dungeon mode, " .. dungeon.name) or "normal")
  Add("Theme: %s", tostring(Pathwise.db.theme or Pathwise.DefaultTheme or "default"))

  local Waypoints = Pathwise:GetModule("Waypoints")
  local target, kind = Waypoints:GetTarget()
  if target then
    Add("Arrow (%s): %s, %s", kind or "?", Plain(target.label), Position(target.mapID, target.x, target.y))
  else
    Add("Arrow: none")
  end

  local items = Pathwise:GetModule("NextSteps"):GetItems()
  Add("")
  Add("To-do (%d steps):", #items)
  for i = 1, math.min(#items, MAX_STEPS) do
    Add("- [%s] %s", tostring(items[i].id), Plain(items[i].text))
  end

  local errors = Platform.GetRecentErrors()
  Add("")
  Add("Recent errors (%d):", #errors)
  for _, err in ipairs(errors) do
    Add("- %s", Plain(err.message))
    for line in tostring(err.stack or ""):gmatch("[^\n]+") do
      Add("    %s", line)
    end
  end
  return table.concat(lines, "\n")
end
