local FakeUI = require("tests.helpers.fake_ui")
local IconSettings = require("WhisperMessenger.UI.MessengerWindow.IconSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local WIDGET_LAYER = "Widget layer"

local function layerButtons(result)
  return FindUI.selectorButtons(result.frame, WIDGET_LAYER)
end

local function selectedKey(result)
  for _, button in ipairs(layerButtons(result)) do
    if button._selected then
      return button._key
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_widget_layer_selector_defaults_high_and_fires_widget_strata
  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[#changes + 1] = key .. "=" .. tostring(value)
      end,
    })
    local buttons = layerButtons(result)
    assert(#buttons == 4, "four layers, got " .. #buttons)
    assert(selectedKey(result) == "HIGH", "High is selected with an empty config, got " .. tostring(selectedKey(result)))
    FindUI.click(buttons[2])
    assert(table.concat(changes, ";") == "widgetStrata=LOW", "clicking Low fires widgetStrata, got " .. table.concat(changes, ";"))
    assert(selectedKey(result) == "LOW", "the click selects Low")
  end

  -- test_widget_layer_selector_shows_the_saved_layer
  do
    local result = IconSettings.Create(factory, parent, { widgetStrata = "BACKGROUND" }, { onChange = function() end })
    assert(selectedKey(result) == "BACKGROUND", "saved layer is selected, got " .. tostring(selectedKey(result)))
  end

  -- test_widget_layer_buttons_explain_the_setting
  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    for _, button in ipairs(layerButtons(result)) do
      assert(
        button._tooltipText == "Sets which game windows the widget sits above. Pick a lower layer to keep bags and other windows on top of it.",
        "tooltip on " .. tostring(button._key)
      )
    end
  end

  -- test_reset_to_defaults_sets_widget_layer_high
  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, { widgetStrata = "LOW" }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.widgetStrata == "HIGH", "reset sets the layer High, got " .. tostring(changes.widgetStrata))
    assert(selectedKey(result) == "HIGH", "reset selects High")
  end

  -- test_widget_layer_row_sits_between_lock_and_share_rows
  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    local lockRow = FindUI.byLabel(result.frame, "Lock icon position")
    local layerRow = FindUI.byLabel(result.frame, WIDGET_LAYER)
    local shareRow = FindUI.byLabel(result.frame, "Same position on every character")
    local _, belowLock = layerRow:GetPoint()
    local _, belowLayer = shareRow:GetPoint()
    assert(belowLock == lockRow, "the layer row hangs below the lock row")
    assert(belowLayer == layerRow, "the share row hangs below the layer row")
  end

  -- test_set_language_translates_the_widget_layer_label_and_buttons
  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    Localization.Configure({ language = "ruRU" })
    result.setLanguage()
    local buttons = FindUI.selectorButtons(result.frame, "Слой виджета")
    local labels = {}
    for _, button in ipairs(buttons) do
      labels[#labels + 1] = button.label.text
    end
    Localization.Configure({ language = "enUS" })
    assert(table.concat(labels, ",") == "Фон,Низкий,Средний,Высокий", "got " .. table.concat(labels, ","))
  end

  print("  All widget layer settings tests passed")
end
