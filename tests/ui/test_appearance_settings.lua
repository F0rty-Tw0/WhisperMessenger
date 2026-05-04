local FakeUI = require("tests.helpers.fake_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_theme_preset_selector_exists

  do
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.themePresetSelector ~= nil, "test_theme_preset_selector_exists: should expose themePresetSelector")
    assert(result.themePresetSelector.buttons ~= nil, "test_theme_preset_selector_exists: themePresetSelector should have buttons")
    assert(
      #result.themePresetSelector.buttons == 4,
      "test_theme_preset_selector_exists: should have 4 preset buttons, got: " .. tostring(#result.themePresetSelector.buttons)
    )
  end

  -- test_theme_preset_selector_labels

  do
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local labels = {}
    for _, btn in ipairs(result.themePresetSelector.buttons) do
      if btn.label and btn.label.text then
        table.insert(labels, btn.label.text)
      end
    end

    local expected = {
      ["Midnight"] = false,
      ["Shadowlands"] = false,
      ["Draenor"] = false,
      ["Azeroth"] = false,
    }
    for _, text in ipairs(labels) do
      if expected[text] ~= nil then
        expected[text] = true
      end
    end

    assert(expected["Midnight"], "test_theme_preset_selector_labels: should have a 'Midnight' button")
    assert(expected["Shadowlands"], "test_theme_preset_selector_labels: should have a 'Shadowlands' button")
    assert(expected["Draenor"], "test_theme_preset_selector_labels: should have a 'Draenor' button")
    assert(expected["Azeroth"], "test_theme_preset_selector_labels: should have an 'Azeroth' button")
  end

  -- test_theme_preset_selector_fires_on_change

  do
    local changes = {}
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Draenor" button (third one)
    local warmBtn = result.themePresetSelector.buttons[3]
    local onClick = warmBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_theme_preset_selector_fires_on_change: button should have OnClick")
    onClick(warmBtn)

    assert(
      changes.themePreset == "plumber_warm",
      "test_theme_preset_selector_fires_on_change: should fire onChange with themePreset=plumber_warm, got: " .. tostring(changes.themePreset)
    )
  end

  -- test_theme_preset_selector_highlights_initial

  do
    local config = { themePreset = "elvui_dark" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local darkBtn = result.themePresetSelector.buttons[2]
    assert(
      darkBtn._selected == true,
      "test_theme_preset_selector_highlights_initial: Shadowlands button should be selected when themePreset=elvui_dark"
    )
    local defaultBtn = result.themePresetSelector.buttons[1]
    assert(
      defaultBtn._selected ~= true,
      "test_theme_preset_selector_highlights_initial: Midnight button should NOT be selected when themePreset=elvui_dark"
    )
  end

  -- test_font_selector_exists

  do
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.fontSelector ~= nil, "test_font_selector_exists: should expose fontSelector")
    assert(result.fontSelector.buttons ~= nil, "test_font_selector_exists: fontSelector should have buttons")
    assert(
      #result.fontSelector.buttons == 3,
      "test_font_selector_exists: should have 3 font buttons, got: " .. tostring(#result.fontSelector.buttons)
    )
  end

  -- test_font_selector_labels

  do
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local labels = {}
    for _, btn in ipairs(result.fontSelector.buttons) do
      if btn.label and btn.label.text then
        table.insert(labels, btn.label.text)
      end
    end

    local found = { default = false, system = false, morpheus = false }
    for _, text in ipairs(labels) do
      local lower = string.lower(text)
      if string.find(lower, "default", 1, true) then
        found.default = true
      end
      if string.find(lower, "system", 1, true) then
        found.system = true
      end
      if string.find(lower, "morpheus", 1, true) then
        found.morpheus = true
      end
    end

    assert(found.default, "test_font_selector_labels: should have a 'Default' button")
    assert(found.system, "test_font_selector_labels: should have a 'System' button")
    assert(found.morpheus, "test_font_selector_labels: should have a 'Morpheus' button")
  end

  -- test_font_selector_fires_on_change

  do
    local changes = {}
    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "System" button (second one)
    local systemBtn = result.fontSelector.buttons[2]
    local onClick = systemBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_font_selector_fires_on_change: button should have OnClick")
    onClick(systemBtn)

    assert(
      changes.fontFamily == "system",
      "test_font_selector_fires_on_change: should fire onChange with fontFamily=system, got: " .. tostring(changes.fontFamily)
    )
  end

  -- test_font_selector_default_highlights_initial

  do
    local config = { fontFamily = "system" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    -- The system button (index 2) should be the selected one
    local systemBtn = result.fontSelector.buttons[2]
    assert(systemBtn._selected == true, "test_font_selector_default_highlights_initial: system button should be selected when fontFamily=system")

    local defaultBtn = result.fontSelector.buttons[1]
    assert(
      defaultBtn._selected ~= true,
      "test_font_selector_default_highlights_initial: default button should NOT be selected when fontFamily=system"
    )
  end

  -- test_reset_resets_font_and_theme_to_defaults

  do
    local changes = {}
    local config = {
      fontFamily = "system",
      themePreset = "elvui_dark",
      windowOpacityInactive = 0.90,
      windowOpacityActive = 0.60,
    }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click reset
    local resetClick = result.resetButton:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_resets_font_and_theme: resetButton should have OnClick")
    resetClick(result.resetButton)

    assert(
      changes.themePreset == "wow_default",
      "test_reset_resets_font_and_theme: reset should fire onChange with themePreset=wow_default, got: " .. tostring(changes.themePreset)
    )
    assert(
      changes.fontFamily == "default",
      "test_reset_resets_font_and_theme: reset should fire onChange with fontFamily=default, got: " .. tostring(changes.fontFamily)
    )
    assert(
      math.abs((changes.windowOpacityInactive or 0) - 0.7) < 0.0001,
      "test_reset_resets_font_and_theme: reset should fire onChange with windowOpacityInactive=0.7, got: " .. tostring(changes.windowOpacityInactive)
    )
    assert(
      math.abs((changes.windowOpacityActive or 0) - 1.0) < 0.0001,
      "test_reset_resets_font_and_theme: reset should fire onChange with windowOpacityActive=1.0, got: " .. tostring(changes.windowOpacityActive)
    )
    assert(result.themePresetSelector.buttons[1]._selected == true, "test_reset_resets_font_and_theme: Midnight theme should be selected after reset")
    assert(result.fontSelector.buttons[1]._selected == true, "test_reset_resets_font_and_theme: Default font should be selected after reset")
  end

  -- test_font_buttons_show_tooltip_on_enter

  do
    _G.GameTooltip = {
      _owner = nil,
      _text = nil,
      _shown = false,
      SetOwner = function(self, owner, anchor)
        self._owner = owner
        self._anchor = anchor
      end,
      SetText = function(self, text)
        self._text = text
      end,
      AddLine = function(self, text)
        self._addedLine = text
      end,
      Show = function(self)
        self._shown = true
      end,
      Hide = function(self)
        self._shown = false
        self._text = nil
        self._addedLine = nil
      end,
    }

    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    -- Hover over the "System" button (2nd)
    local systemBtn = result.fontSelector.buttons[2]
    local onEnter = systemBtn:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_font_tooltip: button should have OnEnter")
    onEnter(systemBtn)

    assert(_G.GameTooltip._shown == true, "test_font_tooltip: GameTooltip should be shown on hover")
    assert(
      _G.GameTooltip._text ~= nil and _G.GameTooltip._text ~= "",
      "test_font_tooltip: GameTooltip should have text, got: " .. tostring(_G.GameTooltip._text)
    )

    -- Leave should hide
    local onLeave = systemBtn:GetScript("OnLeave")
    onLeave(systemBtn)
    assert(_G.GameTooltip._shown == false, "test_font_tooltip: GameTooltip should be hidden on leave")

    _G.GameTooltip = nil
  end

  -- test_each_font_button_has_distinct_tooltip

  do
    local tooltipTexts = {}
    _G.GameTooltip = {
      _text = nil,
      _shown = false,
      SetOwner = function() end,
      SetText = function(self, text)
        self._text = text
      end,
      AddLine = function() end,
      Show = function(self)
        self._shown = true
      end,
      Hide = function(self)
        self._shown = false
        self._text = nil
      end,
    }

    local config = { fontFamily = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    for _, btn in ipairs(result.fontSelector.buttons) do
      local onEnter = btn:GetScript("OnEnter")
      onEnter(btn)
      table.insert(tooltipTexts, _G.GameTooltip._text)
      local onLeave = btn:GetScript("OnLeave")
      onLeave(btn)
    end

    assert(#tooltipTexts == 3, "test_distinct_tooltips: should have 3 tooltips")
    assert(tooltipTexts[1] ~= tooltipTexts[2], "test_distinct_tooltips: tooltips 1 and 2 should differ")
    assert(tooltipTexts[2] ~= tooltipTexts[3], "test_distinct_tooltips: tooltips 2 and 3 should differ")

    _G.GameTooltip = nil
  end

  -- test_font_size_slider_exists

  do
    local config = { fontSize = 12 }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.fontSizeSlider ~= nil, "test_font_size_slider_exists: should expose fontSizeSlider")
  end

  -- test_font_size_slider_fires_on_change

  do
    local changes = {}
    local config = { fontSize = 12 }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local onValueChanged = result.fontSizeSlider:GetScript("OnValueChanged")
    assert(onValueChanged ~= nil, "test_font_size_fires: slider should have OnValueChanged")
    onValueChanged(result.fontSizeSlider, 16)

    assert(changes.fontSize == 16, "test_font_size_fires: should fire onChange with fontSize=16, got: " .. tostring(changes.fontSize))
  end

  -- test_font_outline_selector_exists

  do
    local config = { fontOutline = "NONE" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.fontOutlineSelector ~= nil, "test_font_outline_selector_exists: should expose fontOutlineSelector")
    assert(
      #result.fontOutlineSelector.buttons == 3,
      "test_font_outline_selector_exists: should have 3 outline buttons, got: " .. tostring(#result.fontOutlineSelector.buttons)
    )
  end

  -- test_font_outline_selector_fires_on_change

  do
    local changes = {}
    local config = { fontOutline = "NONE" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Outline" button (second one)
    local outlineBtn = result.fontOutlineSelector.buttons[2]
    local onClick = outlineBtn:GetScript("OnClick")
    onClick(outlineBtn)

    assert(
      changes.fontOutline == "OUTLINE",
      "test_font_outline_fires: should fire onChange with fontOutline=OUTLINE, got: " .. tostring(changes.fontOutline)
    )
  end

  -- test_font_color_selector_exists

  do
    local config = { fontColor = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.fontColorSelector ~= nil, "test_font_color_selector_exists: should expose fontColorSelector")
    assert(
      #result.fontColorSelector.buttons >= 6,
      "test_font_color_selector_exists: should have at least 6 color buttons, got: " .. tostring(#result.fontColorSelector.buttons)
    )
  end

  -- test_font_color_selector_fires_on_change

  do
    local changes = {}
    local config = { fontColor = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Gold" button (second one: default, gold, ...)
    local goldBtn = result.fontColorSelector.buttons[2]
    local onClick = goldBtn:GetScript("OnClick")
    onClick(goldBtn)

    assert(changes.fontColor == "gold", "test_font_color_fires: should fire onChange with fontColor=gold, got: " .. tostring(changes.fontColor))
  end

  -- test_reset_resets_new_font_settings

  do
    local changes = {}
    local config = {
      fontFamily = "system",
      fontSize = 16,
      fontOutline = "OUTLINE",
      fontColor = "gold",
      themePreset = "elvui_dark",
      windowOpacityInactive = 0.90,
      windowOpacityActive = 0.60,
    }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetClick = result.resetButton:GetScript("OnClick")
    resetClick(result.resetButton)

    assert(changes.fontSize == 12, "test_reset_new_settings: reset should fire fontSize=12, got: " .. tostring(changes.fontSize))
    assert(changes.fontOutline == "NONE", "test_reset_new_settings: reset should fire fontOutline=NONE, got: " .. tostring(changes.fontOutline))
    assert(changes.fontColor == "default", "test_reset_new_settings: reset should fire fontColor=default, got: " .. tostring(changes.fontColor))
  end

  -- test_russian_localizes_appearance_panel

  do
    Localization.Configure({ language = "ruRU" })
    local result = AppearanceSettings.Create(factory, parent, { themePreset = "wow_default", fontFamily = "default" }, { onChange = function() end })

    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["Внешний вид"], "Russian appearance panel should translate title")
    assert(texts["Настройте темы, шрифты и прозрачность окна."], "Russian appearance panel should translate hint")
    assert(result.themePresetSelector.label.text == "Профиль темы", "Theme Preset label should be localized")
    assert(result.fontSelector.label.text == "Шрифт", "Font Family label should be localized")
    assert(result.fontSelector.buttons[1].label.text == "По умолчанию", "Default font option should be localized")
    assert(result.fontOutlineSelector.label.text == "Обводка шрифта", "Font Outline label should be localized")
    assert(result.bubbleColorSelector.label.text == "Цвета пузырей", "Bubble Colors label should be localized")
    assert(result.resetButton.label.text == "Сбросить настройки", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end
  print("  All appearance settings tests passed")
end
