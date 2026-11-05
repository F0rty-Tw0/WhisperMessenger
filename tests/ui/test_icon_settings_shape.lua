local FakeUI = require("tests.helpers.fake_ui")
local IconSettings = require("WhisperMessenger.UI.MessengerWindow.IconSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local BACKGROUND = "Square button background"
local SHAPE = "Widget shape"

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_saved_square_shape_survives_a_panel_rebuild
  do
    local result = IconSettings.Create(factory, parent, { widgetShape = "square" }, { onChange = function() end })
    local buttons = FindUI.selectorButtons(result.frame, SHAPE)
    assert(buttons[2]._selected == true and buttons[1]._selected == false, "test_saved_square_shape_survives_a_panel_rebuild: square is selected")
    assert(
      FindUI.disabledCover(FindUI.byLabel(result.frame, BACKGROUND)) == nil,
      "test_saved_square_shape_survives_a_panel_rebuild: background toggle usable"
    )
  end

  -- test_unknown_saved_shape_reads_as_circle
  do
    local result = IconSettings.Create(factory, parent, { widgetShape = "triangle" }, { onChange = function() end })
    local buttons = FindUI.selectorButtons(result.frame, SHAPE)
    assert(buttons[1]._selected == true, "test_unknown_saved_shape_reads_as_circle: circle is selected")
    assert(FindUI.disabledCover(FindUI.byLabel(result.frame, BACKGROUND)) ~= nil, "test_unknown_saved_shape_reads_as_circle: toggle unavailable")
  end

  -- test_reset_while_square_returns_to_circle_and_disables_the_background_toggle
  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, { widgetShape = "square" }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.widgetShape == "circle", "test_reset_while_square: reset emits circle")
    assert(FindUI.selectorButtons(result.frame, SHAPE)[1]._selected == true, "test_reset_while_square: circle selected after reset")
    assert(FindUI.disabledCover(FindUI.byLabel(result.frame, BACKGROUND)) ~= nil, "test_reset_while_square: background toggle unavailable")
  end

  -- test_background_toggle_tooltip_names_the_widget_shape
  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    local savedTooltip = _G.GameTooltip
    local lines = {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function() end,
      AddLine = function(_, value)
        lines[#lines + 1] = value
      end,
      Show = function() end,
      Hide = function() end,
    }
    local row = FindUI.byLabel(result.frame, BACKGROUND)
    row:GetScript("OnEnter")(row)
    _G.GameTooltip = savedTooltip
    assert(
      lines[1] == "Shows a square behind the widget icon when the widget shape is square. Turn it off to show only the two chat bubbles.",
      "test_background_toggle_tooltip: got " .. tostring(lines[1])
    )
  end

  -- test_set_language_relocalizes_shape_selector_and_reason
  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    local row = FindUI.byLabel(result.frame, BACKGROUND)
    Localization.Configure({ language = "deDE" })
    result.setLanguage()
    local buttons = FindUI.selectorButtons(result.frame, "Widget-Form")
    assert(#buttons == 2, "test_set_language: selector label is localized")
    assert(FindUI.text(buttons[2], "Quadrat") ~= nil, "test_set_language: option labels are localized")
    local cover = FindUI.disabledCover(row)
    assert(cover, "test_set_language: disabled cover exists")
    local savedTooltip = _G.GameTooltip
    local shown
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_, value)
        shown = value
      end,
      Show = function() end,
      Hide = function() end,
    }
    cover:GetScript("OnEnter")(cover)
    _G.GameTooltip = savedTooltip
    Localization.Configure({ language = "enUS" })
    assert(shown == "Nur mit quadratischer Widget-Form.", "test_set_language: reason is localized, got " .. tostring(shown))
  end

  print("  All icon settings shape tests passed")
end
