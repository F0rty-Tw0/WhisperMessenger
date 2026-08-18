local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")

local function createSoundPlayer(supportsVolume)
  local previews = {}
  local normalizedValues = {}

  return {
    previews = previews,
    normalizedValues = normalizedValues,
    SupportsVolume = function()
      return supportsVolume
    end,
    NormalizeVolume = function(value)
      normalizedValues[#normalizedValues + 1] = value
      return SoundPlayer.NormalizeVolume(value)
    end,
    Preview = function(soundKey, volume)
      previews[#previews + 1] = { soundKey = soundKey, volume = volume }
    end,
  }
end

local function countEvents(events, expectedKey, expectedValue)
  local count = 0
  for _, event in ipairs(events) do
    if event.key == expectedKey and event.value == expectedValue then
      count = count + 1
    end
  end
  return count
end

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

  -- test_volume_slider_requires_supported_sound_player

  do
    local resetEvents = {}
    local unsupportedSoundPlayer = createSoundPlayer(false)
    local unsupported = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        resetEvents[#resetEvents + 1] = { key = key, value = value }
      end,
      soundPlayer = unsupportedSoundPlayer,
    })

    assert(
      unsupported.notificationVolumeSlider == nil,
      "test_volume_slider_requires_supported_sound_player: unsupported clients should not expose a volume slider"
    )
    assert(
      unsupported.resetButton.point[1] == "TOPLEFT"
        and unsupported.resetButton.point[2] == unsupported.soundSelector.row
        and unsupported.resetButton.point[3] == "BOTTOMLEFT",
      "test_volume_slider_requires_supported_sound_player: unsupported reset should anchor below sound selector"
    )
    unsupported.resetButton:GetScript("OnClick")(unsupported.resetButton)

    assert(#resetEvents == 3, "test_volume_slider_requires_supported_sound_player: unsupported reset should emit exactly three callbacks")
    assert(
      countEvents(resetEvents, "playSoundOnWhisper", false) == 1,
      "test_volume_slider_requires_supported_sound_player: unsupported reset should reset sound toggle exactly once"
    )
    assert(
      countEvents(resetEvents, "notificationSound", "whisper") == 1,
      "test_volume_slider_requires_supported_sound_player: unsupported reset should reset sound exactly once"
    )
    assert(
      countEvents(resetEvents, "notificationVolume", 1) == 1,
      "test_volume_slider_requires_supported_sound_player: unsupported reset should reset volume exactly once"
    )

    local supportedSoundPlayer = createSoundPlayer(true)
    local supported = NotificationSettings.Create(factory, parent, { notificationVolume = 0.73 }, {
      onChange = function() end,
      soundPlayer = supportedSoundPlayer,
    })
    local slider = supported.notificationVolumeSlider

    assert(slider ~= nil, "test_volume_slider_requires_supported_sound_player: supported clients should expose a volume slider")
    assert(
      supported.resetButton.point[1] == "TOPLEFT" and supported.resetButton.point[2] == slider.row and supported.resetButton.point[3] == "BOTTOMLEFT",
      "test_volume_slider_requires_supported_sound_player: supported reset should anchor below volume slider"
    )
    assert(slider.slider.minValue == 0, "test_volume_slider_requires_supported_sound_player: slider minimum should be 0")
    assert(slider.slider.maxValue == 1, "test_volume_slider_requires_supported_sound_player: slider maximum should be 1")
    assert(slider.slider.valueStep == 0.05, "test_volume_slider_requires_supported_sound_player: slider step should be 0.05")
    assert(slider.slider.value == 0.75, "test_volume_slider_requires_supported_sound_player: initial value should be normalized")
    assert(slider.value.text == "75%", "test_volume_slider_requires_supported_sound_player: current value should be formatted as a percentage")
    assert(slider.minLabel.text == "0%", "test_volume_slider_requires_supported_sound_player: minimum label should be formatted as a percentage")
    assert(slider.maxLabel.text == "100%", "test_volume_slider_requires_supported_sound_player: maximum label should be formatted as a percentage")
    assert(
      supportedSoundPlayer.normalizedValues[1] == 0.73,
      "test_volume_slider_requires_supported_sound_player: initial value should pass through NormalizeVolume"
    )
  end

  -- test_volume_slider_persists_without_previewing

  do
    local changes = {}
    local soundPlayer = createSoundPlayer(true)
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
      soundPlayer = soundPlayer,
    })

    result.notificationVolumeSlider.slider:SetValue(0.63)

    assert(changes.notificationVolume == 0.65, "test_volume_slider_persists_without_previewing: slider changes should persist rounded volume")
    assert(#soundPlayer.previews == 0, "test_volume_slider_persists_without_previewing: slider changes should not preview sound")
  end

  -- test_sound_selection_previews_once_at_current_volume

  do
    local changes = {}
    local soundPlayer = createSoundPlayer(true)
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
      soundPlayer = soundPlayer,
    })

    result.notificationVolumeSlider.slider:SetValue(0.61)
    local pingButton = result.soundSelector.buttons[2]
    pingButton:GetScript("OnClick")(pingButton)

    assert(changes.notificationSound == "ping", "test_sound_selection_previews_once_at_current_volume: sound selection should persist selected sound")
    assert(#soundPlayer.previews == 1, "test_sound_selection_previews_once_at_current_volume: sound selection should preview exactly once")
    assert(
      soundPlayer.previews[1].soundKey == "ping" and math.abs(soundPlayer.previews[1].volume - 0.6) < 0.000001,
      "test_sound_selection_previews_once_at_current_volume: preview should use selected sound and latest volume"
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

  -- test_reset_restores_volume_default_when_supported

  do
    local events = {}
    local soundPlayer = createSoundPlayer(true)
    local result = NotificationSettings.Create(factory, parent, {
      playSoundOnWhisper = true,
      notificationSound = "bell",
      notificationVolume = 0.4,
    }, {
      onChange = function(key, value)
        events[#events + 1] = { key = key, value = value }
      end,
      soundPlayer = soundPlayer,
    })

    result.resetButton:GetScript("OnClick")(result.resetButton)

    assert(#events == 3, "test_reset_restores_volume_default_when_supported: reset should emit exactly three callbacks")
    assert(
      countEvents(events, "playSoundOnWhisper", false) == 1,
      "test_reset_restores_volume_default_when_supported: sound toggle should reset exactly once"
    )
    assert(
      countEvents(events, "notificationSound", "whisper") == 1,
      "test_reset_restores_volume_default_when_supported: sound should reset exactly once"
    )
    assert(countEvents(events, "notificationVolume", 1) == 1, "test_reset_restores_volume_default_when_supported: volume should reset exactly once")
    assert(result.notificationVolumeSlider.slider.value == 1, "test_reset_restores_volume_default_when_supported: slider should reset to full volume")
    assert(#soundPlayer.previews == 0, "test_reset_restores_volume_default_when_supported: reset should not preview a sound")
  end

  -- test_reset_restores_all_notification_defaults

  do
    local events = {}
    local result = NotificationSettings.Create(factory, parent, {
      playSoundOnWhisper = true,
      notificationSound = "bell",
    }, {
      onChange = function(key, value)
        events[#events + 1] = { key = key, value = value }
      end,
    })

    local resetClick = result.resetButton:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_restores_all_notification_defaults: resetButton should have OnClick")
    resetClick(result.resetButton)

    assert(#events == 3, "test_reset_restores_all_notification_defaults: reset should emit exactly three callbacks")
    assert(
      countEvents(events, "playSoundOnWhisper", false) == 1,
      "test_reset_restores_all_notification_defaults: playSoundOnWhisper should reset exactly once"
    )
    assert(
      countEvents(events, "notificationSound", "whisper") == 1,
      "test_reset_restores_all_notification_defaults: notificationSound should reset exactly once"
    )
    assert(
      countEvents(events, "notificationVolume", 1) == 1,
      "test_reset_restores_all_notification_defaults: notificationVolume should reset exactly once"
    )
    assert(result.soundSelector.buttons[1]._selected == true, "test_reset_restores_all_notification_defaults: first sound should be selected")
  end

  -- test_refresh_layout_resizes_sound_selector

  do
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function() end,
      soundPlayer = createSoundPlayer(true),
    })

    assert(type(result.refreshLayout) == "function", "test_refresh_layout_resizes_sound_selector: refreshLayout should be exposed")
    result.refreshLayout(260)

    assert(result.soundSelector.row.width == 260, "test_refresh_layout_resizes_sound_selector: selector should resize to 260")
    assert(result.soundSelector.buttons[5].point[1] == "TOPLEFT", "test_refresh_layout_resizes_sound_selector: 5th button should wrap at 260")
    assert(
      result.notificationVolumeSlider.row.width == 260,
      "test_refresh_layout_resizes_sound_selector: volume slider should resize through panel registry"
    )
    assert(
      result.notificationVolumeSlider.row.point[2] == result.soundSelector.row,
      "test_refresh_layout_resizes_sound_selector: volume slider should anchor below sound selector"
    )
    assert(result.frame._wmBottomMarker ~= nil, "test_refresh_layout_resizes_sound_selector: panel should retain bottom marker")
  end

  -- test_russian_localizes_notification_panel

  do
    Localization.Configure({ language = "ruRU" })
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function() end,
      soundPlayer = createSoundPlayer(true),
    })

    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["Уведомления"], "Russian notifications panel should translate title")
    assert(
      texts["Настройте оповещения о входящих сообщениях."],
      "Russian notifications panel should translate hint"
    )
    assert(result.soundSelector.label.text == "Звук уведомления", "Notification sound label should be localized")
    assert(result.notificationVolumeSlider.label.text == "Громкость уведомлений", "Notification volume label should be localized")
    assert(result.playSoundToggle.label.text == "Звук при новом шепоте", "Play sound toggle should be localized")
    assert(result.resetButton.label.text == "Сбросить настройки", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
    result.setLanguage()
    assert(result.notificationVolumeSlider.label.text == "Notification volume", "Volume label should update with language")
  end

  print("  All notification settings tests passed")
end
