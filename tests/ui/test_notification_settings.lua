local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local function soundButtons(result)
  return FindUI.selectorButtons(result.frame, "Notification sound")
end

local function resetButton(result)
  return FindUI.byLabel(result.frame, "Reset to Defaults")
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_sound_controls_exist

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(FindUI.toggle(result.frame, "Play sound on new whisper") ~= nil, "test_sound_controls_exist: play sound toggle should render")
    local buttons = soundButtons(result)
    assert(#buttons == 16, "test_sound_controls_exist: should have 16 sound buttons, got: " .. tostring(#buttons))
  end

  -- test_notifications_owns_only_sound_controls

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    for _, label in ipairs({
      "Badge pulse animation",
      "Show unread badge",
      "Icon Size",
      "Desaturate icon when idle",
      "Icon Mode",
      "Lock icon position",
      "Show widget message preview",
      "Auto-dismiss widget preview",
      "Widget preview position",
    }) do
      assert(FindUI.text(result.frame, label) == nil, "test_notifications_owns_only_sound_controls: Notifications should not render " .. label)
    end
  end

  -- test_sound_selector_default_whisper

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })
    local firstBtn = soundButtons(result)[1]
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

    local pingBtn = soundButtons(result)[2]
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

    local reset = resetButton(result)
    local resetClick = reset:GetScript("OnClick")
    assert(resetClick ~= nil, "test_reset_restores_only_sound_defaults: resetButton should have OnClick")
    resetClick(reset)

    assert(changes.playSoundOnWhisper == false, "test_reset_restores_only_sound_defaults: playSoundOnWhisper should reset to false")
    assert(changes.notificationSound == "whisper", "test_reset_restores_only_sound_defaults: notificationSound should reset to whisper")
    local resetCount = 0
    for _ in pairs(changes) do
      resetCount = resetCount + 1
    end
    assert(resetCount == 2, "test_reset_restores_only_sound_defaults: reset should emit only sound keys")
    assert(soundButtons(result)[1]._selected == true, "test_reset_restores_only_sound_defaults: first sound should be selected")
  end

  -- test_refresh_layout_resizes_sound_selector

  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })

    assert(type(result.refreshLayout) == "function", "test_refresh_layout_resizes_sound_selector: refreshLayout should be exposed")
    result.refreshLayout(260)

    assert(
      FindUI.byLabel(result.frame, "Notification sound").width == 260,
      "test_refresh_layout_resizes_sound_selector: selector should resize to 260"
    )
    -- Buttons are sized to fit their labels, so how many share a row depends
    -- on label width; the row must still wrap at 260.
    local wrapped = false
    local buttons = soundButtons(result)
    for i = 2, #buttons do
      if buttons[i].point[1] == "TOPLEFT" then
        wrapped = true
      end
    end
    assert(wrapped, "test_refresh_layout_resizes_sound_selector: buttons should wrap at 260")
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
    assert(
      texts["Настройте оповещения о входящих сообщениях."],
      "Russian notifications panel should translate hint"
    )
    assert(#FindUI.selectorButtons(result.frame, "Звук уведомления") == 16, "Notification sound label should be localized")
    assert(FindUI.toggle(result.frame, "Звук при новом шепоте") ~= nil, "Play sound toggle should be localized")
    assert(FindUI.byLabel(result.frame, "Сбросить настройки").frameType == "Button", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end

  print("  All notification settings tests passed")
end
