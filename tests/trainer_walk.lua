-- Levels every class from 1 to 60 and checks that each trainer spell shows
-- up (recommended or optional) at the level it can be learned, learning
-- everything on the way. The player is taken to have every talent and to
-- have done every class quest (so the ranks that need them count too).
-- Used by run_classes.lua (Classic Era) and run_forever.lua (WoW Forever).
-- Reported: Consecration and Blessing of Kings never showed (WoW Forever).
return function(WoW, Pathwise, check, label)
  local Trainer = Pathwise:GetModule("Trainer")
  local snapshot = Pathwise:GetModule("Character"):GetSnapshot()
  local saved = { class = snapshot.class, raceID = snapshot.raceID, faction = snapshot.faction, level = snapshot.level }
  local known = WoW.knownSpells
  local players = {
    { "WARRIOR", 1, "Alliance" }, { "PALADIN", 1, "Alliance" }, { "HUNTER", 4, "Alliance" },
    { "ROGUE", 1, "Alliance" }, { "PRIEST", 1, "Alliance" }, { "PRIEST", 5, "Horde" },
    { "SHAMAN", 2, "Horde" }, { "MAGE", 1, "Alliance" }, { "MAGE", 2, "Horde" },
    { "WARLOCK", 1, "Alliance" }, { "DRUID", 4, "Alliance" },
  }
  for _, player in ipairs(players) do
    local class, raceID, faction = player[1], player[2], player[3]
    local entries = Pathwise.Data.ClassSpells[class]
    local inData, forPlayer = {}, {}
    for _, entry in ipairs(entries) do
      inData[entry.id] = true
    end
    WoW.knownSpells = {}
    for _, entry in ipairs(entries) do
      -- Talents, and what class quests teach (requirements not in the data).
      if entry.talent then
        WoW.knownSpells[entry.id] = true
      end
      if entry.requires and not inData[entry.requires] then
        WoW.knownSpells[entry.requires] = true
      end
      local races = true
      if entry.races then
        races = false
        for _, id in ipairs(entry.races) do
          races = races or id == raceID
        end
      end
      forPlayer[entry] = not entry.talent and races and (not entry.faction or entry.faction == faction)
    end
    snapshot.class, snapshot.raceID, snapshot.faction = class, raceID, faction
    local missing = {}
    for level = 1, 60 do
      snapshot.level = level
      local list = Trainer:BuildList()
      local offered = {}
      for _, item in ipairs(list.available) do
        offered[item.id] = true
      end
      for _, entry in ipairs(entries) do
        if forPlayer[entry] and entry.level == level and not offered[entry.id] and not WoW.knownSpells[entry.id] then
          missing[#missing + 1] = entry.name .. " " .. tostring(entry.rank or "") .. " (" .. level .. ")"
        end
      end
      for id in pairs(offered) do
        WoW.knownSpells[id] = true
      end
    end
    local left = {}
    for _, entry in ipairs(entries) do
      if forPlayer[entry] and not WoW.knownSpells[entry.id] then
        left[#left + 1] = entry.name .. " " .. tostring(entry.rank or "")
      end
    end
    check(string.format("%s: %s (%s) - every trainer spell at its level (%s%s)", label, class, faction,
      table.concat(missing, ", "), #left > 0 and ("; never: " .. table.concat(left, ", ")) or ""),
      #missing == 0 and #left == 0)
  end
  WoW.knownSpells = known
  snapshot.class, snapshot.raceID, snapshot.faction, snapshot.level = saved.class, saved.raceID, saved.faction, saved.level
  Trainer:BuildList()
end
