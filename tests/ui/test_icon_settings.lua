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
    assert(texts["Configure icon and widget settings."], "test_icons_owns_all_icon_and_widget_controls: English hint should use the fallback key")

    assert(result.iconModeSelector ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconModeSelector should exist")
    assert(#result.iconModeSelector.buttons == 4, "test_icons_owns_all_icon_and_widget_controls: iconModeSelector should expose four modes")
    assert(result.iconModeSelector.buttons[4]._key == "none", "test_icons_owns_all_icon_and_widget_controls: fourth mode should be none")
    assert(result.iconSizeSlider ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconSizeSlider should exist")
    assert(result.iconDesaturatedToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: iconDesaturatedToggle should exist")
    assert(result.lockToggleIconToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: lockToggleIconToggle should exist")
    assert(result.shareWidgetPositionToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: shareWidgetPositionToggle should exist")
    assert(
      result.shareWidgetPositionToggle.getValue() == false,
      "test_share_widget_position_toggle_defaults_off: shareWidgetPosition should default off"
    )
    assert(
      result.shareWidgetPositionToggle.label.text == "Share widget position across characters",
      "test_share_widget_position_toggle_defaults_off: toggle should use the localized label"
    )
    assert(result.showBadgeToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: showBadgeToggle should exist")
    assert(result.badgePulseToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: badgePulseToggle should exist")
    assert(result.widgetMessagePreviewToggle ~= nil, "test_icons_owns_all_icon_and_widget_controls: widgetMessagePreviewToggle should exist")
    assert(result.transparentWidgetToggle == nil, "test_icons_owns_all_icon_and_widget_controls: transparentWidgetToggle should not exist")
    assert(result.widgetTransparencySlider ~= nil, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider should exist")
    assert(
      result.widgetTransparencySlider.minValue == 0,
      "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider minimum should be 0"
    )
    assert(
      result.widgetTransparencySlider.maxValue == 1,
      "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider maximum should be 1"
    )
    assert(
      result.widgetTransparencySlider.valueStep == 0.05,
      "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider step should be 0.05"
    )
    assert(result.widgetTransparencySlider.value == 0, "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider should default to 0%")
    assert(
      result.widgetTransparencySlider.parent.children[1].text == "Widget transparency",
      "test_icons_owns_all_icon_and_widget_controls: widgetTransparencySlider should use the transparency label"
    )

    local savedTooltip = _G.GameTooltip
    local tooltipState = { lines = {}, shown = false, hidden = false }
    _G.GameTooltip = {
      SetOwner = function(_, owner, anchor)
        tooltipState.owner = owner
        tooltipState.anchor = anchor
      end,
      SetText = function(_, value)
        tooltipState.title = value
      end,
      AddLine = function(_, value)
        tooltipState.lines[#tooltipState.lines + 1] = value
      end,
      Show = function()
        tooltipState.shown = true
      end,
      Hide = function()
        tooltipState.hidden = true
      end,
    }

    local tooltipRow = result.widgetTransparencySlider.parent
    local onEnter = tooltipRow:GetScript("OnEnter")
    assert(onEnter ~= nil, "test_widget_transparency_tooltip: slider row should have OnEnter script")
    onEnter(tooltipRow)
    assert(tooltipState.owner == tooltipRow, "test_widget_transparency_tooltip: tooltip should use the slider row as owner")
    assert(tooltipState.anchor == "ANCHOR_TOP", "test_widget_transparency_tooltip: tooltip should anchor above the slider row")
    assert(tooltipState.title == "Widget transparency", "test_widget_transparency_tooltip: tooltip should use the transparency title")
    assert(
      tooltipState.lines[1] == "Controls how transparent the widget is when not hovered.",
      "test_widget_transparency_tooltip: tooltip should explain widget transparency"
    )
    assert(tooltipState.shown == true, "test_widget_transparency_tooltip: tooltip should show on enter")

    local onLeave = tooltipRow:GetScript("OnLeave")
    assert(onLeave ~= nil, "test_widget_transparency_tooltip: slider row should have OnLeave script")
    onLeave(tooltipRow)
    assert(tooltipState.hidden == true, "test_widget_transparency_tooltip: tooltip should hide on leave")

    tooltipState.lines = {}
    tooltipState.title = nil
    tooltipState.shown = false
    tooltipState.hidden = false
    local sharePositionRow = result.shareWidgetPositionToggle.row
    local sharePositionOnEnter = sharePositionRow:GetScript("OnEnter")
    assert(sharePositionOnEnter ~= nil, "test_share_widget_position_tooltip: toggle row should have OnEnter script")
    sharePositionOnEnter(sharePositionRow)
    assert(tooltipState.owner == sharePositionRow, "test_share_widget_position_tooltip: tooltip should use the toggle row as owner")
    assert(tooltipState.anchor == "ANCHOR_TOP", "test_share_widget_position_tooltip: tooltip should anchor above the toggle row")
    assert(
      tooltipState.title == "Share widget position across characters",
      "test_share_widget_position_tooltip: tooltip should use the localized title"
    )
    assert(
      tooltipState.lines[1] == "Uses one widget position for all characters on this WoW account.",
      "test_share_widget_position_tooltip: tooltip should explain account-wide sharing"
    )
    assert(tooltipState.shown == true, "test_share_widget_position_tooltip: tooltip should show on enter")
    local sharePositionOnLeave = sharePositionRow:GetScript("OnLeave")
    assert(sharePositionOnLeave ~= nil, "test_share_widget_position_tooltip: toggle row should have OnLeave script")
    sharePositionOnLeave(sharePositionRow)
    assert(tooltipState.hidden == true, "test_share_widget_position_tooltip: tooltip should hide on leave")
    _G.GameTooltip = savedTooltip
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
    result.shareWidgetPositionToggle.dot:GetScript("OnClick")(result.shareWidgetPositionToggle.dot)
    result.showBadgeToggle.dot:GetScript("OnClick")(result.showBadgeToggle.dot)
    result.badgePulseToggle.dot:GetScript("OnClick")(result.badgePulseToggle.dot)
    result.widgetMessagePreviewToggle.dot:GetScript("OnClick")(result.widgetMessagePreviewToggle.dot)
    assert(result.transparentWidgetToggle == nil, "test_icon_and_widget_controls_fire_existing_keys: transparentWidgetToggle should not exist")
    result.widgetTransparencySlider:SetValue(0.4)
    assert(
      result.widgetTransparencySlider.parent.children[2].text == "40%",
      "test_icon_and_widget_controls_fire_existing_keys: widget transparency should display a percent"
    )
    result.autoDismissSlider:SetValue(60)
    result.positionSelector.buttons[2]:GetScript("OnClick")(result.positionSelector.buttons[2])

    assert(changes.iconMode == "both", "test_icon_and_widget_controls_fire_existing_keys: iconMode should be both")
    assert(changes.iconSize == 32, "test_icon_and_widget_controls_fire_existing_keys: iconSize should be 32")
    assert(changes.iconDesaturated == false, "test_icon_and_widget_controls_fire_existing_keys: iconDesaturated should be false")
    assert(changes.lockToggleIcon == true, "test_icon_and_widget_controls_fire_existing_keys: lockToggleIcon should be true")
    assert(changes.shareWidgetPosition == true, "test_icon_and_widget_controls_fire_existing_keys: shareWidgetPosition should be true")
    assert(changes.showUnreadBadge == false, "test_icon_and_widget_controls_fire_existing_keys: showUnreadBadge should be false")
    assert(changes.badgePulse == false, "test_icon_and_widget_controls_fire_existing_keys: badgePulse should be false")
    assert(changes.showWidgetMessagePreview == false, "test_icon_and_widget_controls_fire_existing_keys: showWidgetMessagePreview should be false")
    assert(changes.transparentWidget == nil, "test_icon_and_widget_controls_fire_existing_keys: transparentWidget should not be emitted")
    assert(changes.widgetTransparency == 0.4, "test_icon_and_widget_controls_fire_existing_keys: widget transparency should be 0.4")
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
      widgetTransparency = 0.25,
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
      shareWidgetPosition = false,
      showUnreadBadge = true,
      badgePulse = true,
      showWidgetMessagePreview = true,
      widgetTransparency = 0,
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
    assert(resetCount == 11, "test_icons_reset_emits_only_icon_and_widget_defaults: reset should emit eleven icon/widget keys")
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
    assert(
      texts["Настройте параметры значков и виджета."],
      "test_icons_refresh_layout_and_language: Icons hint should be localized"
    )
    assert(
      result.lockToggleIconToggle.label.text == "Закрепить позицию значка",
      "test_icons_refresh_layout_and_language: existing labels should remain localized"
    )
    Localization.Configure({ language = "enUS" })
  end

  print("  All icon settings tests passed")
end
