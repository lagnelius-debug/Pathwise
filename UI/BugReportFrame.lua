local addonName, Pathwise = ...

-- Bug report window (/pw bug): the GitHub link and the report from
-- Core/BugReport.lua, each in a box that selects all of itself when clicked
-- (Ctrl+C copies it). Addons can't go online: the player opens the link in
-- a browser, describes the problem and pastes the report into the form.

local L = Pathwise.L

local BugReportFrame = Pathwise:NewModule("BugReportFrame")

local WIDTH = 480
local REPORT_HEIGHT = 220

local frame, linkBox, reportBox
local reportText = ""

-- A box the player can select and copy from, but not change.
local function ReadOnly(box, getText)
  box:SetAutoFocus(false)
  box:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  box:SetScript("OnMouseUp", function(self)
    self:SetFocus()
    self:HighlightText()
  end)
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(getText())
      self:HighlightText()
    end
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    frame:Hide()
  end)
end

local function CreateWindow()
  frame = Pathwise.Theme.CreateWindow("PathwiseBugReport", UIParent, L.BUGREPORT_TITLE)
  frame:SetWidth(WIDTH)
  frame:SetFrameStrata("DIALOG")
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame.close:SetScript("OnClick", function()
    frame:Hide()
  end)
  if UISpecialFrames then
    table.insert(UISpecialFrames, "PathwiseBugReport")
  end

  local content = frame.content
  local steps = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  steps:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  steps:SetPoint("RIGHT", content, "RIGHT", 0, 0)
  steps:SetJustifyH("LEFT")
  steps:SetText(L.BUGREPORT_STEPS)

  linkBox = CreateFrame("EditBox", "PathwiseBugReportLink", content, "InputBoxTemplate")
  linkBox:SetHeight(20)
  linkBox:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -58)
  linkBox:SetPoint("RIGHT", content, "RIGHT", -2, 0)
  linkBox:SetFontObject("GameFontHighlightSmall")
  ReadOnly(linkBox, function()
    return Pathwise:GetModule("BugReport").ISSUE_URL
  end)

  local scroll = CreateFrame("ScrollFrame", "PathwiseBugReportScroll", content, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -88)
  scroll:SetPoint("RIGHT", content, "RIGHT", -24, 0)
  scroll:SetHeight(REPORT_HEIGHT)
  reportBox = CreateFrame("EditBox", "PathwiseBugReportText", scroll)
  reportBox:SetMultiLine(true)
  reportBox:SetWidth(WIDTH - 70)
  reportBox:SetFontObject("GameFontHighlightSmall")
  ReadOnly(reportBox, function()
    return reportText
  end)
  scroll:SetScrollChild(reportBox)

  frame.footer.text:SetText(L.BUGREPORT_FOOTER)
  frame:SetContentHeight(88 + REPORT_HEIGHT)
  frame:Hide()
end

-- Opens the window with a fresh report, selected for copying.
function BugReportFrame:Open()
  if not frame then
    CreateWindow()
  end
  reportText = Pathwise:GetModule("BugReport"):Build()
  linkBox:SetText(Pathwise:GetModule("BugReport").ISSUE_URL)
  reportBox:SetText(reportText)
  frame:Show()
  reportBox:SetFocus()
  reportBox:HighlightText()
end

function BugReportFrame:GetReportText()
  return reportText
end

-- /pw bug
Pathwise:RegisterCommand("bug", function()
  BugReportFrame:Open()
end, L.CMD_BUG)
