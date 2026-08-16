local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_sound_controls_exist

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(result.playSoundToggle ~= nil, "test_sound_controls_exist: playSoundToggle should not be nil")
    assert(result.soundSelector ~= nil, "test_sound_controls_exist: soundSelector should not be nil")
    assert(result.soundSelector.buttons ~= nil, "test_sound_controls_exist: soundSelector.buttons should not be nil")
    assert(
      #result.soundSelector.buttons == 16,
      "test_sound_controls_exist: should have 16 sound buttons, got: " .. tostring(#result.soundSelector.buttons)
    )
  end

  -- test_notifications_owns_only_sound_controls

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    for _, handle in ipairs({
      "badgePulseToggle",
      "showBadgeToggle",
      "iconSizeSlider",
      "iconDesaturatedToggle",
      "iconModeSelector",
      "lockToggleIconToggle",
      "widgetMessagePreviewToggle",
      "autoDismissSlider",
      "positionSelector",
    }) do
      assert(result[handle] == nil, "test_notifications_owns_only_sound_controls: Notifications should not expose " .. handle)
    end
  end

  -- test_sound_selector_default_whisper

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })
    local firstBtn = result.soundSelector.buttons[1]
    assert(firstBtn._selected == true, "test_sound_selector_default_whisper: first (whisper) button should be selected by default")
  end

  -- test_sound_selector_fires_on_change

  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local pingBtn = result.soundSelector.buttons[2]
    local onClick = pingBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_sound_selector_fires_on_change: ping button should have OnClick")
    onClick(pingBtn)

    assert(
      changes.notificationSound == "ping",
      "test_sound_selector_fires_on_change: onChange should fire notificationSound=ping, got: " .. tostring(changes.notificationSound)
    )
  end

  -- test_reset_restores_only_sound_defaults

  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {
      playSoundOnWhisper = true,
      notificationSound = "bell",
    }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetClick = result.resetButton:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_restores_only_sound_defaults: resetButton should have OnClick")
    resetClick(result.resetButton)

    assert(changes.playSoundOnWhisper == false, "test_reset_restores_only_sound_defaults: playSoundOnWhisper should reset to false")
    assert(changes.notificationSound == "whisper", "test_reset_restores_only_sound_defaults: notificationSound should reset to whisper")
    local resetCount = 0
    for _ in pairs(changes) do
      resetCount = resetCount + 1
    end
    assert(resetCount == 2, "test_reset_restores_only_sound_defaults: reset should emit only sound keys")
    assert(result.soundSelector.buttons[1]._selected == true, "test_reset_restores_only_sound_defaults: first sound should be selected")
  end

  -- test_refresh_layout_resizes_sound_selector

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(type(result.refreshLayout) == "function", "test_refresh_layout_resizes_sound_selector: refreshLayout should be exposed")
    result.refreshLayout(260)

    assert(result.soundSelector.row.width == 260, "test_refresh_layout_resizes_sound_selector: selector should resize to 260")
    assert(
      result.soundSelector.buttons[5].point[1] == "TOPLEFT",
      "test_refresh_layout_resizes_sound_selector: 5th button should wrap at 260"
    )
    assert(result.frame._wmBottomMarker ~= nil, "test_refresh_layout_resizes_sound_selector: panel should retain bottom marker")
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
    assert(result.resetButton.label.text == "Сбросить настройки", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end

  print("  All notification settings tests passed")
end
