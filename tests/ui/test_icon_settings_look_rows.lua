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

  -- test_border_rows_follow_the_background_row

  do
    local _, rows = build({})
    assert(rows.borderToggle.row.points[1][2] == rows.backgroundToggle.row, "test_border_rows_follow_the_background_row: border")
    assert(rows.borderThemedToggle.row.points[1][2] == rows.borderToggle.row, "test_border_rows_follow_the_background_row: themed")
  end

  -- test_last_row_is_the_themed_border_toggle

  do
    local _, rows = build({})
    assert(rows.lastRow == rows.borderThemedToggle.row, "test_last_row_is_the_themed_border_toggle")
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
    FindUI.click(FindUI.toggle(frame, "Button background"))
    assert(key == "iconBackground" and value == false, "test_background_toggle_reports_its_key: got " .. tostring(key) .. "," .. tostring(value))
  end

  -- test_show_border_reports_its_key

  do
    local key, value
    local frame = build({}, function(k, v)
      key, value = k, v
    end)
    FindUI.click(FindUI.toggle(frame, "Show border"))
    assert(key == "iconBorder" and value == false, "test_show_border_reports_its_key: got " .. tostring(key) .. "," .. tostring(value))
  end

  -- test_themed_border_reports_its_key

  do
    local key, value
    local frame = build({}, function(k, v)
      key, value = k, v
    end)
    FindUI.click(FindUI.toggle(frame, "Color border with theme"))
    assert(key == "iconBorderThemed" and value == false, "test_themed_border_reports_its_key: got " .. tostring(key) .. "," .. tostring(value))
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

  -- test_background_toggle_is_usable_on_every_shape

  do
    for _, config in ipairs({ {}, { widgetShape = "square" } }) do
      local _, rows = build(config)
      local row = rows.backgroundToggle.row
      assert(FindUI.disabledCover(row) == nil, "test_background_toggle_is_usable_on_every_shape: usable on build")
      rows.changed("widgetShape", "circle")
      assert(FindUI.disabledCover(row) == nil, "test_background_toggle_is_usable_on_every_shape: usable after circle")
    end
  end

  -- Hover target; returns the tooltip's title and added lines.
  local function hover(target)
    local saved = _G.GameTooltip
    local title, lines = nil, {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_, value)
        title = value
      end,
      AddLine = function(_, value)
        lines[#lines + 1] = value
      end,
      Show = function() end,
      Hide = function() end,
    }
    target:GetScript("OnEnter")(target)
    _G.GameTooltip = saved

    return title, lines
  end

  -- test_background_tooltip_names_both_shapes

  do
    local _, rows = build({})
    local title, lines = hover(rows.backgroundToggle.row)
    assert(title == "Button background", "test_background_tooltip_names_both_shapes: title, got " .. tostring(title))
    assert(
      lines[1] == "Shows the circle or square behind the widget icon. Turn it off to show only the two chat bubbles.",
      "test_background_tooltip_names_both_shapes: got " .. tostring(lines[1])
    )
  end

  -- test_themed_border_is_disabled_while_the_border_is_off

  do
    local _, rows = build({ iconBorder = false })
    local row = rows.borderThemedToggle.row
    local cover = FindUI.disabledCover(row)
    assert(cover ~= nil, "test_themed_border_is_disabled_while_the_border_is_off: covered")
    assert(row.alpha < 1, "test_themed_border_is_disabled_while_the_border_is_off: dimmed")
    local reason = hover(cover)
    assert(reason == "Only with Show border on.", "test_themed_border_is_disabled_while_the_border_is_off: got " .. tostring(reason))
  end

  -- test_themed_border_keeps_its_value_while_disabled

  do
    local frame = build({ iconBorder = false, iconBorderThemed = false })
    assert(FindUI.isToggleOn(FindUI.toggle(frame, "Color border with theme")) == false, "test_themed_border_keeps_its_value_while_disabled")
  end

  -- test_turning_the_border_off_disables_the_themed_toggle_at_once

  do
    local frame, rows = build({})
    local row = rows.borderThemedToggle.row
    assert(FindUI.disabledCover(row) == nil, "test_turning_the_border_off: usable while the border is on")
    FindUI.click(FindUI.toggle(frame, "Show border"))
    assert(FindUI.disabledCover(row) ~= nil, "test_turning_the_border_off: covered once off")
    FindUI.click(FindUI.toggle(frame, "Show border"))
    assert(FindUI.disabledCover(row) == nil, "test_turning_the_border_off: usable again once on")
    assert(row.alpha == 1, "test_turning_the_border_off: full alpha when usable")
  end

  -- test_reset_with_the_border_off_frees_the_themed_toggle

  do
    local changes = {}
    local frame, rows, _, panel = build({ iconBorder = false }, function(k, v)
      changes[k] = v
    end)
    panel:reset(rows.changed)
    assert(changes.iconBorder == true and changes.iconBorderThemed == true, "test_reset_with_the_border_off: defaults reported")
    assert(FindUI.disabledCover(rows.borderThemedToggle.row) == nil, "test_reset_with_the_border_off: themed toggle usable")
    assert(FindUI.isToggleOn(FindUI.toggle(frame, "Show border")) == true, "test_reset_with_the_border_off: border toggle on")
  end

  -- test_set_language_relocalizes_the_border_rows

  do
    local German = require("WhisperMessenger.Locale.deDE")
    local name = "test_set_language_relocalizes_the_border_rows"
    assert(German["Show border"], name .. ": deDE has no 'Show border'")
    assert(German["Color border with theme"], name .. ": deDE has no 'Color border with theme'")
    assert(German["Button background"], name .. ": deDE has no 'Button background'")
    assert(German["Only with Show border on."], name .. ": deDE has no border reason")

    local frame, rows = build({ iconBorder = false })
    Localization.Configure({ language = "deDE" })
    rows.setLanguage()
    local found = {
      FindUI.text(frame, German["Show border"]),
      FindUI.text(frame, German["Color border with theme"]),
      FindUI.text(frame, German["Button background"]),
    }
    local reason = hover(FindUI.disabledCover(rows.borderThemedToggle.row))
    Localization.Configure({ language = "enUS" })
    assert(found[1] and found[2] and found[3], name .. ": translated labels found")
    assert(reason == German["Only with Show border on."], name .. ": reason, got " .. tostring(reason))
  end
end
