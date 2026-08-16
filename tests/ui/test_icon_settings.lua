local FakeUI = require("tests.helpers.fake_ui")
local loaded, IconSettings = pcall(require, "WhisperMessenger.UI.MessengerWindow.IconSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  assert(loaded, "test_icon_settings_module_exists: IconSettings module must be available")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_icons_owns_all_icon_and_widget_controls

  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["Icons"], "test_icons_owns_all_icon_and_widget_controls: English title should use the fallback key")
    assert(
      texts["Configure icon and widget settings."],
      "test_icons_owns_all_icon_and_widget_controls: English hint should use the fallback key"
    )

    assert(result.iconModeSelector ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconModeSelector should exist")
    assert(#result.iconModeSelector.buttons == 4, "test_icons_owns_all_icon_and_widget_controls: iconModeSelector should expose four modes")
    assert(result.iconModeSelector.buttons[4]._key == "none", "test_icons_owns_all_icon_and_widget_controls: fourth mode should be none")
    assert(result.iconSizeSlider ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconSizeSlider should exist")
    assert(result.iconDesaturatedToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconDesaturatedToggle should exist")
    assert(result.lockToggleIconToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: lockToggleIconToggle should exist")
    assert(result.showBadgeToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: showBadgeToggle should exist")
    assert(result.badgePulseToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: badgePulseToggle should exist")
    assert(result.widgetMessagePreviewToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: widgetMessagePreviewToggle should exist")
    assert(result.autoDismissSlider ~= nil, "test_icons_owns_all_icon_and_widget_controls: autoDismissSlider should exist")
    assert(result.positionSelector ~= nil, "test_icons_owns_all_icon_and_widget_controls: positionSelector should exist")
    assert(result.playSoundToggle == nil, "test_icons_owns_all_icon_and_widget_controls: Icons should not expose playSoundToggle")
    assert(result.soundSelector == nil, "test_icons_owns_all_icon_and_widget_controls: Icons should not expose soundSelector")
    assert(result.frame._wmBottomMarker ~= nil, "test_icons_owns_all_icon_and_widget_controls: panel should retain bottom marker")
  end

  -- test_icon_and_widget_controls_fire_existing_keys

  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    result.iconModeSelector.buttons[3]:GetScript("OnClick")(result.iconModeSelector.buttons[3])
    result.iconSizeSlider:SetValue(32)
    result.iconDesaturatedToggle.dot:GetScript("OnClick")(result.iconDesaturatedToggle.dot)
    result.lockToggleIconToggle.dot:GetScript("OnClick")(result.lockToggleIconToggle.dot)
    result.showBadgeToggle.dot:GetScript("OnClick")(result.showBadgeToggle.dot)
    result.badgePulseToggle.dot:GetScript("OnClick")(result.badgePulseToggle.dot)
    result.widgetMessagePreviewToggle.dot:GetScript("OnClick")(result.widgetMessagePreviewToggle.dot)
    result.autoDismissSlider:SetValue(60)
    result.positionSelector.buttons[2]:GetScript("OnClick")(result.positionSelector.buttons[2])

    assert(changes.iconMode == "both", "test_icon_and_widget_controls_fire_existing_keys: iconMode should be both")
    assert(changes.iconSize == 32, "test_icon_and_widget_controls_fire_existing_keys: iconSize should be 32")
    assert(changes.iconDesaturated == false, "test_icon_and_widget_controls_fire_existing_keys: iconDesaturated should be false")
    assert(changes.lockToggleIcon == true, "test_icon_and_widget_controls_fire_existing_keys: lockToggleIcon should be true")
    assert(changes.showUnreadBadge == false, "test_icon_and_widget_controls_fire_existing_keys: showUnreadBadge should be false")
    assert(changes.badgePulse == false, "test_icon_and_widget_controls_fire_existing_keys: badgePulse should be false")
    assert(changes.showWidgetMessagePreview == false, "test_icon_and_widget_controls_fire_existing_keys: showWidgetMessagePreview should be false")
    assert(changes.widgetPreviewAutoDismissSeconds == 60, "test_icon_and_widget_controls_fire_existing_keys: auto-dismiss should be 60")
    assert(changes.widgetPreviewPosition == "left", "test_icon_and_widget_controls_fire_existing_keys: position should be left")
  end

  -- test_none_icon_mode_fires_none_key

  do
    local selectedMode
    local result = IconSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        if key == "iconMode" then
          selectedMode = value
        end
      end,
    })

    result.iconModeSelector.buttons[4]:GetScript("OnClick")(result.iconModeSelector.buttons[4])
    assert(selectedMode == "none", "test_none_icon_mode_fires_none_key: iconMode should be none")
  end

  -- test_icons_reset_emits_only_icon_and_widget_defaults

  do
    local changes = {}
    local result = IconSettings.Create(factory, parent, {
      iconMode = "both",
      iconSize = 56,
      iconDesaturated = false,
      lockToggleIcon = true,
      showUnreadBadge = false,
      badgePulse = false,
      showWidgetMessagePreview = false,
      widgetPreviewAutoDismissSeconds = 60,
      widgetPreviewPosition = "top",
    }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    result.resetButton:GetScript("OnClick")(result.resetButton)

    local expected = {
      iconMode = "widget",
      iconSize = 42,
      iconDesaturated = true,
      lockToggleIcon = false,
      showUnreadBadge = true,
      badgePulse = true,
      showWidgetMessagePreview = true,
      widgetPreviewAutoDismissSeconds = 30,
      widgetPreviewPosition = "right",
    }
    local resetCount = 0
    for key, value in pairs(changes) do
      assert(expected[key] == value, "test_icons_reset_emits_only_icon_and_widget_defaults: unexpected reset key " .. tostring(key))
      resetCount = resetCount + 1
    end
    for key, value in pairs(expected) do
      assert(changes[key] == value, "test_icons_reset_emits_only_icon_and_widget_defaults: wrong default for " .. key)
    end
    assert(resetCount == 9, "test_icons_reset_emits_only_icon_and_widget_defaults: reset should emit nine icon/widget keys")
  end

  -- test_icons_refresh_layout_and_language

  do
    local result = IconSettings.Create(factory, parent, {}, { onChange = function() end })
    result.refreshLayout(260)
    assert(result.badgePulseToggle.row.width == 260, "test_icons_refresh_layout_and_language: toggle rows should resize")
    assert(result.positionSelector.row.width == 260, "test_icons_refresh_layout_and_language: selector rows should resize")

    Localization.Configure({ language = "ruRU" })
    result.setLanguage()
    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end
    assert(texts["Значки"], "test_icons_refresh_layout_and_language: Icons title should be localized")
    assert(texts["Настройте параметры значков и виджета."], "test_icons_refresh_layout_and_language: Icons hint should be localized")
    assert(result.lockToggleIconToggle.label.text == "Закрепить позицию значка", "test_icons_refresh_layout_and_language: existing labels should remain localized")
    Localization.Configure({ language = "enUS" })
  end

  print("  All icon settings tests passed")
end
