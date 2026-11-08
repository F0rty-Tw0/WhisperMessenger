local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

-- One row of the Behavior page's addon list: a toggle labelled with the
-- addon's title and, for an addon that is not loaded this session, a
-- "Not loaded" label and a Forget button on the right. Rows are pooled:
-- Create builds the widgets once, Bind points a row at a registry entry.
local IntegrationRow = {}

local GAP = 8
local TOGGLE_HEIGHT = 24
local FORGET_WIDTH = 80
local FORGET_HEIGHT = 22

local function showTooltip(toggleRow)
  local tooltip = _G.GameTooltip
  if toggleRow.tooltipText == nil or tooltip == nil or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(toggleRow, "ANCHOR_TOP")
  tooltip:SetText(toggleRow.tooltipText)
  tooltip:Show()
end

local function hideTooltip()
  local tooltip = _G.GameTooltip
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- createToggleRow freezes a tooltip at creation, so a pooled row sets its own:
-- only the "Other addons" row has one.
local function setTooltip(toggleRow, tooltipText)
  toggleRow.tooltipText = tooltipText
  toggleRow:SetScript("OnEnter", tooltipText and showTooltip or nil)
  toggleRow:SetScript("OnLeave", tooltipText and hideTooltip or nil)
end

-- The "Not loaded" label and the Forget button share one holder frame,
-- shown only for addons that are not loaded.
local function createMissing(factory, row, handlers)
  local missing = factory.CreateFrame("Frame", nil, row)
  missing:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  local forget = UIHelpers.createOptionButton(
    factory,
    missing,
    "",
    SettingsControls.OptionButtonColors(Theme),
    { height = FORGET_HEIGHT, width = FORGET_WIDTH, ghost = true }
  )
  forget:SetPoint("RIGHT", missing, "RIGHT", 0, 0)
  forget:SetScript("OnClick", function()
    handlers.onForget(row.name)
  end)
  forget:Show()

  local notLoaded = missing:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  notLoaded:SetPoint("RIGHT", forget, "LEFT", -GAP, 0)

  row.missing = missing
  row.forget = forget
  row.notLoaded = notLoaded
end

-- handlers = { onToggle(name, on), onForget(name) }.
function IntegrationRow.Create(factory, parent, handlers)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  row.toggle = UIHelpers.createToggleRow(
    factory,
    row,
    "",
    false,
    SettingsControls.ToggleColors(Theme),
    { width = row.width, height = TOGGLE_HEIGHT },
    function(on)
      handlers.onToggle(row.name, on)
    end
  )
  row.toggle.row:SetPoint("LEFT", row, "LEFT", 0, 0)

  createMissing(factory, row, handlers)
  return row
end

-- entry: one registry.rows() entry. labels = { shared, tooltip, notLoaded, forget }.
function IntegrationRow.Bind(row, entry, labels)
  row.name = entry.name
  row.seen = entry.seen
  row.toggle.label:SetText(entry.shared and labels.shared or entry.title)
  row.toggle.setValue(entry.allowed)
  setTooltip(row.toggle.row, entry.shared and labels.tooltip or nil)
  row.notLoaded:SetText(labels.notLoaded)
  row.forget.label:SetText(labels.forget)
  if entry.seen then
    row.missing:Hide()
  else
    row.missing:Show()
  end
  IntegrationRow.RefreshTheme(row)
  IntegrationRow.SetWidth(row, row.width)
  row.toggle.row:Show()
  row:Show()
end

function IntegrationRow.RefreshTheme(row)
  local colors = SettingsControls.ToggleColors(Theme)
  if row.seen == false then
    colors.text = Theme.COLORS.text_secondary
  end
  row.toggle.applyThemeColors(colors)
  UIHelpers.setTextColor(row.notLoaded, Theme.COLORS.text_secondary)
  if row.forget.applyThemeColors then
    row.forget.applyThemeColors(SettingsControls.OptionButtonColors(Theme))
  end
end

-- A not-loaded row's toggle shrinks to leave room for its label and button.
function IntegrationRow.SetWidth(row, width)
  row.width = width
  local toggleWidth = width
  if row.seen == false then
    local missingWidth = math.ceil(row.notLoaded:GetStringWidth()) + GAP + FORGET_WIDTH
    row.missing:SetSize(missingWidth, TOGGLE_HEIGHT)
    toggleWidth = math.max(1, width - missingWidth - GAP)
  end
  row.toggle.setWidth(toggleWidth)
  row:SetSize(width, math.max(TOGGLE_HEIGHT, row.toggle.row:GetHeight()))
end

ns.MessengerWindowBehaviorIntegrationRow = IntegrationRow
return IntegrationRow
