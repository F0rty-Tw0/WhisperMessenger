local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_sound_selector_exists
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, { onChange = function() end })

    assert(result.soundSelector ~= nil, "test_sound_selector_exists: soundSelector should not be nil")
    assert(result.soundSelector.buttons ~= nil, "test_sound_selector_exists: soundSelector.buttons should not be nil")
    assert(
      #result.soundSelector.buttons == 5,
      "test_sound_selector_exists: should have 5 sound buttons, got: " .. tostring(#result.soundSelector.buttons)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_sound_selector_default_whisper
  -- -----------------------------------------------------------------------
  do
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, { onChange = function() end })

    local firstBtn = result.soundSelector.buttons[1]
    assert(
      firstBtn._selected == true,
      "test_sound_selector_default_whisper: first (whisper) button should be selected by default"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_sound_selector_fires_on_change
  -- -----------------------------------------------------------------------
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
      "test_sound_selector_fires_on_change: onChange should fire with notificationSound=ping, got: "
        .. tostring(changes.notificationSound)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_reset_restores_defaults
  -- -----------------------------------------------------------------------
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
      "test_reset_restores_defaults: onChange should fire notificationSound=whisper, got: "
        .. tostring(changes.notificationSound)
    )
    local firstBtn = result.soundSelector.buttons[1]
    assert(
      firstBtn._selected == true,
      "test_reset_restores_defaults: first (whisper) button should be selected after reset"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_size_slider_fires_on_change
  -- -----------------------------------------------------------------------
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
      "test_icon_size_slider_fires_on_change: onChange should fire with iconSize=32, got: "
        .. tostring(changes.iconSize)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_desaturated_toggle_fires_on_change
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = {}
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    assert(
      result.iconDesaturatedToggle ~= nil,
      "test_icon_desaturated_toggle_fires_on_change: iconDesaturatedToggle should exist"
    )

    -- Toggle is on by default (iconDesaturated defaults true), click dot to toggle off
    local onClick = result.iconDesaturatedToggle.dot:GetScript("OnClick")
    assert(onClick ~= nil, "dot should have OnClick handler")
    onClick(result.iconDesaturatedToggle.dot)

    assert(
      changes.iconDesaturated ~= nil,
      "test_icon_desaturated_toggle_fires_on_change: onChange should fire for iconDesaturated"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_reset_restores_icon_defaults
  -- -----------------------------------------------------------------------
  do
    local changes = {}
    local config = {
      iconSize = 56,
      iconDesaturated = false,
    }
    local result = NotificationSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local resetClick = result.resetButton:GetScript("OnClick")
    resetClick(result.resetButton)

    assert(
      changes.iconSize == 42,
      "test_reset_restores_icon_defaults: iconSize should reset to 42, got: " .. tostring(changes.iconSize)
    )
    assert(
      changes.iconDesaturated == true,
      "test_reset_restores_icon_defaults: iconDesaturated should reset to true, got: "
        .. tostring(changes.iconDesaturated)
    )
  end

  print("  All notification settings tests passed")
end
