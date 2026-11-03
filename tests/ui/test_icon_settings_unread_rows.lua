local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local FindUI = require("tests.helpers.find_ui")
local UnreadRows = require("WhisperMessenger.UI.MessengerWindow.IconSettings.UnreadRows")

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(config, onChange)
    local frame = factory.CreateFrame("Frame", nil, parent)
    local anchor = factory.CreateFrame("Frame", nil, frame)
    local panel = SettingsControls.NewPanelRegistry()
    local rows = UnreadRows.Create(factory, frame, panel, config, onChange or function() end, {
      toggleColors = SettingsControls.ToggleColors(Theme),
      toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 },
      selectorColors = SettingsControls.SelectorColors(Theme),
      rowSpacing = -8,
      anchor = anchor,
    })
    return frame, rows, anchor
  end

  -- test_first_row_hangs_below_anchor

  do
    local _, rows, anchor = build({})
    local point = rows.showBadgeToggle.row.points[1]
    assert(point[2] == anchor, "test_first_row_hangs_below_anchor: badge row should anchor to the given row")
    assert(point[5] == -8, "test_first_row_hangs_below_anchor: badge row should use the row spacing, got " .. tostring(point[5]))
  end

  -- test_toggle_reports_its_setting_key

  do
    local changedKey, changedValue
    local frame = build({}, function(key, value)
      changedKey, changedValue = key, value
    end)
    FindUI.click(FindUI.toggle(frame, "Show unread badge"))
    assert(changedKey == "showUnreadBadge", "test_toggle_reports_its_setting_key: got " .. tostring(changedKey))
    assert(changedValue == false, "test_toggle_reports_its_setting_key: badge starts on, so a click turns it off")
  end

  -- test_position_selector_offers_four_sides

  do
    local frame = build({ widgetPreviewPosition = "left" })
    local buttons = FindUI.selectorButtons(frame, "Widget preview position")
    assert(#buttons == 4, "test_position_selector_offers_four_sides: got " .. tostring(#buttons))
  end
end
