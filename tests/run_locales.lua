-- Languages (Locales/*.lua): every translation matches the English string
-- it replaces (same placeholders in the same order, same color codes), none
-- is missing, and choosing a language swaps the strings.
local WoW, Pathwise, check, section = ...

section("Languages")

local L = Pathwise.L
local function Placeholders(text)
  local list = {}
  for spec in text:gsub("%%%%", ""):gmatch("%%[%-%+ #0]*%d*%.?%d*[sdfgxXcq]") do
    list[#list + 1] = spec
  end
  return table.concat(list, " ")
end
local function Count(text, pattern)
  local _, n = text:gsub(pattern, "")
  return n
end
local english = {}
for key, text in pairs(L) do
  english[key] = text
end
for _, key in ipairs({ "BINDING_NAME_PATHWISE_NEXT", "BINDING_NAME_PATHWISE_TOGGLE", "BINDING_NAME_PATHWISE_DUNGEON" }) do
  english[key] = _G[key]
end

for _, code in ipairs({ "deDE", "esES", "frFR" }) do
  local strings = Pathwise.Locales and Pathwise.Locales[code]
  check(code .. ": loaded", strings ~= nil)
  local unknown, wrong, missing = {}, {}, {}
  for key, text in pairs(strings or {}) do
    if english[key] == nil then
      unknown[#unknown + 1] = key
    elseif Placeholders(text) ~= Placeholders(english[key]) or Count(text, "|c%x%x%x%x%x%x%x%x") ~= Count(english[key], "|c%x%x%x%x%x%x%x%x")
      or Count(text, "|r") ~= Count(english[key], "|r") then
      wrong[#wrong + 1] = key
    end
  end
  for key in pairs(english) do
    if strings and strings[key] == nil and key ~= "NEXT_STEPS_NOT_READY" then
      missing[#missing + 1] = key
    end
  end
  table.sort(unknown) table.sort(wrong) table.sort(missing)
  check(code .. ": no keys English doesn't have (" .. table.concat(unknown, ", ") .. ")", #unknown == 0)
  check(code .. ": same placeholders and color codes as English (" .. table.concat(wrong, ", ") .. ")", #wrong == 0)
  check(code .. ": every string translated (" .. #missing .. " missing: " .. table.concat(missing, ", ", 1, math.min(#missing, 12)) .. ")",
    #missing == 0)
end

-- Choosing German: the strings, the commands' help and the key bindings.
local saved = {}
for key, text in pairs(english) do saved[key] = text end
Pathwise.appliedLanguage = nil
Pathwise.db.language = "deDE"
Pathwise:ApplyLanguage()
check("German applied: strings", L.QA_TURN_IN == "Abgeben: %s" and L.SLOT_HEAD == "Kopf")
check("German applied: key bindings", BINDING_NAME_PATHWISE_NEXT == "Zur nächsten Stelle")
WoW.ClearChat()
WoW.Slash("help")
check("German applied: the commands' help", WoW.ChatContains("diese Liste zeigen"))
-- Auto follows the game's language.
local getLocale = GetLocale
GetLocale = function() return "esMX" end
Pathwise.db.language = "auto"
check("auto: the game's language (esMX -> Spanish)", Pathwise:LanguageCode() == "esES")
GetLocale = function() return "koKR" end
check("auto: English for a language Pathwise doesn't have", Pathwise:LanguageCode() == "enUS")
GetLocale = getLocale
WoW.ClearChat()
WoW.Slash("language fr")
check("/pw language fr: saved, applies after a reload", Pathwise.db.language == "frFR" and WoW.ChatContains("/reload"))
WoW.Slash("language klingon")
check("/pw language with an unknown one: the choices", WoW.ChatContains("Deutsch") and Pathwise.db.language == "frFR")
-- Back to English for the tests after this one.
for key, text in pairs(saved) do
  if key:find("^BINDING_") then _G[key] = text else rawset(L, key, text) end
end
Pathwise.db.language = "auto"
Pathwise.appliedLanguage = nil
