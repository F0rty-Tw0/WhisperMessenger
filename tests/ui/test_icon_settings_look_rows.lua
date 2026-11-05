local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local FindUI = require("tests.helpers.find_ui")
local LookRows = require("WhisperMessenger.UI.MessengerWindow.IconSettings.LookRows")

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(config, onChange)
    local frame = factory.CreateFrame("Frame", nil, parent)
    local anchor = factory.CreateFrame("Frame", nil, frame)
    local panel = SettingsControls.NewPanelRegistry()
    local rows = LookRows.Create(factory, frame, panel, config, onChange or function() end, {
      toggleColors = SettingsControls.ToggleColors(Theme),
      toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 },
      selectorColors = SettingsControls.SelectorColors(Theme),
      rowSpacing = -8,
      anchor = anchor,
    })
    return frame, rows, anchor, panel
  end

  -- test_shape_selector_hangs_below_anchor

  do
    local _, rows, anchor = build({})
    local point = rows.shapeSelector.row.points[1]
    assert(point[2] == anchor, "test_shape_selector_hangs_below_anchor: should anchor to the given row")
    assert(point[5] == -8, "test_shape_selector_hangs_below_anchor: should use the row spacing, got " .. tostring(point[5]))
  end

  -- test_background_toggle_hangs_below_the_shape_selector

  do
    local _, rows = build({})
    local point = rows.backgroundToggle.row.points[1]
    assert(point[2] == rows.shapeSelector.row, "test_background_toggle_hangs_below_the_shape_selector")
  end

  -- test_last_row_is_the_background_toggle

  do
    local _, rows = build({})
    assert(rows.lastRow == rows.backgroundToggle.row, "test_last_row_is_the_background_toggle")
  end

  -- test_shape_click_reports_widget_shape

  do
    local key, value
    local frame = build({}, function(k, v)
      key, value = k, v
    end)
    FindUI.click(FindUI.selectorButtons(frame, "Widget shape")[2])
    assert(key == "widgetShape" and value == "square", "test_shape_click_reports_widget_shape: got " .. tostring(key) .. "," .. tostring(value))
  end

  -- test_background_toggle_reports_its_key

  do
    local key, value
    local frame = build({}, function(k, v)
      key, value = k, v
    end)
    FindUI.click(FindUI.toggle(frame, "Square button background"))
    assert(key == "iconBackground" and value == false, "test_background_toggle_reports_its_key: got " .. tostring(key) .. "," .. tostring(value))
  end

  -- test_changed_passes_through_to_on_change

  do
    local key, value
    local _, rows = build({}, function(k, v)
      key, value = k, v
    end)
    rows.changed("iconSize", 50)
    assert(key == "iconSize" and value == 50, "test_changed_passes_through_to_on_change")
  end

  -- test_background_follows_the_shape_through_changed

  do
    local _, rows = build({})
    local row = rows.backgroundToggle.row
    assert(FindUI.disabledCover(row) ~= nil, "test_background_follows_the_shape_through_changed: covered before square")
    rows.changed("widgetShape", "square")
    assert(FindUI.disabledCover(row) == nil, "test_background_follows_the_shape_through_changed: cover gone once square")
  end
end
