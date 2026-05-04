local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_sound_selector_exists

  do
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.soundSelector ~= nil, "test_sound_selector_exists: soundSelector should not be nil")
    assert(result.soundSelector.buttons ~= nil, "test_sound_selector_exists: soundSelector.buttons should not be nil")
    assert(
      #result.soundSelector.buttons == 16,
      "test_sound_selector_exists: should have 16 sound buttons, got: " .. tostring(#result.soundSelector.buttons)
    )
  end

  -- test_sound_selector_default_whisper

  do
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, { onChange = function() end })

    local firstBtn = result.soundSelector.buttons[1]
    assert(firstBtn._selected == true, "test_sound_selector_default_whisper: first (whisper) button should be selected by default")
  end

  -- test_sound_selector_fires_on_change

  do
    local changes = {}
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click "Ping" button (second one)
    local pingBtn = result.soundSelector.buttons[2]
    local onClick = pingBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_sound_selector_fires_on_change: ping button should have OnClick")
    onClick(pingBtn)

    assert(
      changes.notificationSound == "ping",
      "test_sound_selector_fires_on_change: onChange should fire with notificationSound=ping, got: " .. tostring(changes.notificationSound)
    )
  end

  -- test_reset_restores_defaults

  do
    local changes = {}
    local config = {
      notificationSound = "bell",
    }
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click reset
    local resetClick = result.resetButton:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_restores_defaults: resetButton should have OnClick")
    resetClick(result.resetButton)

    assert(
      changes.notificationSound == "whisper",
      "test_reset_restores_defaults: onChange should fire notificationSound=whisper, got: " .. tostring(changes.notificationSound)
    )
    local firstBtn = result.soundSelector.buttons[1]
    assert(firstBtn._selected == true, "test_reset_restores_defaults: first (whisper) button should be selected after reset")
  end

  -- test_icon_size_slider_fires_on_change

  do
    local changes = {}
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    assert(result.iconSizeSlider ~= nil, "test_icon_size_slider_fires_on_change: iconSizeSlider should exist")

    local onValueChanged = result.iconSizeSlider:GetScript("OnValueChanged")
    assert(onValueChanged ~= nil, "test_icon_size_slider_fires_on_change: slider should have OnValueChanged")
    onValueChanged(result.iconSizeSlider, 32)

    assert(
      changes.iconSize == 32,
      "test_icon_size_slider_fires_on_change: onChange should fire with iconSize=32, got: " .. tostring(changes.iconSize)
    )
  end

  -- test_icon_desaturated_toggle_fires_on_change

  do
    local changes = {}
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    assert(result.iconDesaturatedToggle ~= nil, "test_icon_desaturated_toggle_fires_on_change: iconDesaturatedToggle should exist")

    -- Toggle is on by default (iconDesaturated defaults true), click dot to toggle off
    local onClick = result.iconDesaturatedToggle.dot:GetScript("OnClick")
    assert(onClick ~= nil, "dot should have OnClick handler")
    onClick(result.iconDesaturatedToggle.dot)

    assert(changes.iconDesaturated ~= nil, "test_icon_desaturated_toggle_fires_on_change: onChange should fire for iconDesaturated")
  end

  -- test_widget_message_preview_toggle_fires_on_change

  do
    local changes = {}
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    assert(result.widgetMessagePreviewToggle ~= nil, "test_widget_message_preview_toggle_fires_on_change: widgetMessagePreviewToggle should exist")

    local onClick = result.widgetMessagePreviewToggle.dot:GetScript("OnClick")
    assert(onClick ~= nil, "widget message preview toggle should have OnClick handler")
    onClick(result.widgetMessagePreviewToggle.dot)

    assert(
      changes.showWidgetMessagePreview == false,
      "test_widget_message_preview_toggle_fires_on_change: expected onChange showWidgetMessagePreview=false, got: "
        .. tostring(changes.showWidgetMessagePreview)
    )
  end

  -- test_reset_restores_icon_defaults

  do
    local changes = {}
    local config = {
      iconSize = 56,
      iconDesaturated = false,
      showWidgetMessagePreview = false,
    }
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetClick = result.resetButton:GetScript("OnClick")
    resetClick(result.resetButton)

    assert(changes.iconSize == 42, "test_reset_restores_icon_defaults: iconSize should reset to 42, got: " .. tostring(changes.iconSize))
    assert(
      changes.iconDesaturated == true,
      "test_reset_restores_icon_defaults: iconDesaturated should reset to true, got: " .. tostring(changes.iconDesaturated)
    )
    assert(
      changes.showWidgetMessagePreview == true,
      "test_reset_restores_icon_defaults: showWidgetMessagePreview should reset to true, got: " .. tostring(changes.showWidgetMessagePreview)
    )
  end

  -- test_auto_dismiss_slider_defaults_and_fires_on_change

  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    assert(result.autoDismissSlider ~= nil, "autoDismissSlider should be exposed on the panel")
    assert(
      result.autoDismissSlider:GetValue() == 30,
      "auto-dismiss slider should default to 30s, got: " .. tostring(result.autoDismissSlider:GetValue())
    )

    result.autoDismissSlider:SetValue(0)
    assert(
      changes.widgetPreviewAutoDismissSeconds == 0,
      "setting slider to 0 should fire onChange with widgetPreviewAutoDismissSeconds=0, got: " .. tostring(changes.widgetPreviewAutoDismissSeconds)
    )

    result.autoDismissSlider:SetValue(60)
    assert(
      changes.widgetPreviewAutoDismissSeconds == 60,
      "setting slider to 60 should fire onChange with widgetPreviewAutoDismissSeconds=60, got: " .. tostring(changes.widgetPreviewAutoDismissSeconds)
    )
  end

  -- test_auto_dismiss_slider_respects_config_initial_value

  do
    local result = NotificationSettings.Create(factory, parent, {
      widgetPreviewAutoDismissSeconds = 45,
    }, { onChange = function() end })

    assert(
      result.autoDismissSlider:GetValue() == 45,
      "auto-dismiss slider should use config value, got: " .. tostring(result.autoDismissSlider:GetValue())
    )
  end

  -- test_position_selector_exists_with_four_options

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(result.positionSelector ~= nil, "test_position_selector: positionSelector should be exposed")
    assert(
      result.positionSelector.buttons ~= nil and #result.positionSelector.buttons == 4,
      "test_position_selector: should have 4 position buttons, got: "
        .. tostring(result.positionSelector.buttons and #result.positionSelector.buttons)
    )
  end

  -- test_position_selector_default_is_right

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })
    local selectedKey = nil
    for _, btn in ipairs(result.positionSelector.buttons) do
      if btn._selected then
        selectedKey = btn._key
        break
      end
    end
    assert(selectedKey == "right", "test_position_selector_default: expected 'right' selected, got: " .. tostring(selectedKey))
  end

  -- test_position_selector_fires_on_change

  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local leftBtn = nil
    for _, btn in ipairs(result.positionSelector.buttons) do
      if btn._key == "left" then
        leftBtn = btn
        break
      end
    end
    assert(leftBtn ~= nil, "test_position_selector_fires_on_change: expected a 'left' button")
    leftBtn:GetScript("OnClick")(leftBtn)

    assert(
      changes.widgetPreviewPosition == "left",
      "test_position_selector_fires_on_change: expected onChange widgetPreviewPosition=left, got: " .. tostring(changes.widgetPreviewPosition)
    )
  end

  -- test_position_selector_respects_config_initial

  do
    local result = NotificationSettings.Create(factory, parent, {
      widgetPreviewPosition = "top",
    }, { onChange = function() end })

    local selectedKey = nil
    for _, btn in ipairs(result.positionSelector.buttons) do
      if btn._selected then
        selectedKey = btn._key
        break
      end
    end
    assert(selectedKey == "top", "test_position_selector_respects_config: expected 'top' selected, got: " .. tostring(selectedKey))
  end

  -- test_reset_restores_position_to_right

  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {
      widgetPreviewPosition = "bottom",
    }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    result.resetButton:GetScript("OnClick")(result.resetButton)
    assert(
      changes.widgetPreviewPosition == "right",
      "test_reset_restores_position: expected reset to fire 'right', got: " .. tostring(changes.widgetPreviewPosition)
    )
  end

  -- test_refresh_layout_shrinks_toggles_and_wraps_sound_selector

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(type(result.refreshLayout) == "function", "test_refresh_layout: refreshLayout should be exposed")

    result.refreshLayout(260)

    assert(
      result.badgePulseToggle.row.width == 260,
      "test_refresh_layout: badge toggle row should resize to 260, got " .. tostring(result.badgePulseToggle.row.width)
    )
    assert(
      result.soundSelector.row.width == 260,
      "test_refresh_layout: sound selector row should resize to 260, got " .. tostring(result.soundSelector.row.width)
    )

    -- Fixed 50px buttons with 4px spacing: floor((260+4)/(50+4)) = 4 per row.
    -- Button 5 should wrap to start of row 2 (TOPLEFT anchor), not sit beside button 4 (LEFT anchor).
    assert(
      result.soundSelector.buttons[5].point[1] == "TOPLEFT",
      "test_refresh_layout: 5th sound button should anchor TOPLEFT to wrap, got " .. tostring(result.soundSelector.buttons[5].point[1])
    )
  end

  -- test_russian_localizes_notification_panel

  do
    Localization.Configure({ language = "ruRU" })
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["Уведомления"], "Russian notifications panel should translate title")
    assert(texts["Настройте оповещения о входящих сообщениях."], "Russian notifications panel should translate hint")
    assert(result.soundSelector.label.text == "Звук уведомления", "Notification sound label should be localized")
    assert(result.playSoundToggle.label.text == "Звук при новом шепоте", "Play sound toggle should be localized")
    assert(result.iconDesaturatedToggle.label.text == "Обесцвечивать значок в покое", "Icon desaturation toggle should be localized")
    assert(result.positionSelector.label.text == "Позиция предпросмотра виджета", "Preview position label should be localized")
    assert(result.positionSelector.buttons[1].label.text == "Справа", "Preview position option should be localized")
    assert(result.resetButton.label.text == "Сбросить настройки", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end

  print("  All notification settings tests passed")
end
