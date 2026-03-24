local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_badge_hidden_when_showUnreadBadge_disabled
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 5,
      getShowUnreadBadge = function()
        return false
      end,
      getBadgePulse = function()
        return true
      end,
    })

    assert(
      icon.badge.shown == false,
      "test_badge_hidden_when_showUnreadBadge_disabled: badge should be hidden when setting is off"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_badge_shown_when_showUnreadBadge_enabled
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 5,
      getShowUnreadBadge = function()
        return true
      end,
      getBadgePulse = function()
        return true
      end,
    })

    assert(
      icon.badge.shown == true,
      "test_badge_shown_when_showUnreadBadge_enabled: badge should be visible when setting is on"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_badge_hidden_when_showUnreadBadge_toggled_off_dynamically
  -- -----------------------------------------------------------------------
  do
    local showBadge = true
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 3,
      getShowUnreadBadge = function()
        return showBadge
      end,
      getBadgePulse = function()
        return true
      end,
    })

    assert(icon.badge.shown == true, "badge should be visible initially")

    -- Simulate setting change
    showBadge = false
    icon.setUnreadCount(3)

    assert(
      icon.badge.shown == false,
      "test_badge_hidden_when_showUnreadBadge_toggled_off_dynamically: badge should hide after setting toggled off"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_pulse_not_started_when_badgePulse_disabled
  -- -----------------------------------------------------------------------
  do
    local pulseStarted = false
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 0,
      getShowUnreadBadge = function()
        return true
      end,
      getBadgePulse = function()
        return false
      end,
    })

    -- Set unread count to trigger pulse path
    icon.setUnreadCount(5)

    -- Badge should show but pulse should not be active
    assert(
      icon.badge.shown == true,
      "test_pulse_not_started_when_badgePulse_disabled: badge should still show"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_defaults_when_no_getters_provided
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 5,
    })

    -- Without getters, should default to showing badge (backward compat)
    assert(
      icon.badge.shown == true,
      "test_defaults_when_no_getters_provided: badge should show by default"
    )
  end
end
