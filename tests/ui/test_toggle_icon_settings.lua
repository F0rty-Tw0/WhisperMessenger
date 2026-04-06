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
    assert(icon.badge.shown == true, "test_pulse_not_started_when_badgePulse_disabled: badge should still show")
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
    assert(icon.badge.shown == true, "test_defaults_when_no_getters_provided: badge should show by default")
  end

  -- -----------------------------------------------------------------------
  -- test_icon_uses_custom_size
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      iconSize = 32,
    })

    local w, h = icon.frame:GetSize()
    assert(w == 32, "test_icon_uses_custom_size: frame width should be 32, got " .. tostring(w))
    assert(h == 32, "test_icon_uses_custom_size: frame height should be 32, got " .. tostring(h))
  end

  -- -----------------------------------------------------------------------
  -- test_apply_icon_size_resizes_frame
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(icon.applyIconSize, "test_apply_icon_size_resizes_frame: applyIconSize method should exist")
    icon.applyIconSize(56)

    local w, h = icon.frame:GetSize()
    assert(w == 56, "test_apply_icon_size_resizes_frame: frame width should be 56 after resize, got " .. tostring(w))
    assert(h == 56, "test_apply_icon_size_resizes_frame: frame height should be 56 after resize, got " .. tostring(h))

    -- Chat icon should be 60% of new size
    local chatW, _chatH = icon.label:GetSize()
    local expectedChatSize = math.floor(56 * 0.6)
    assert(
      chatW == expectedChatSize,
      "test_apply_icon_size_resizes_frame: chat icon width should be "
        .. expectedChatSize
        .. ", got "
        .. tostring(chatW)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_desaturated_when_no_unread
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 0,
      getIconDesaturated = function()
        return true
      end,
      getShowUnreadBadge = function()
        return true
      end,
    })

    assert(
      icon.label.desaturated == true,
      "test_icon_desaturated_when_no_unread: chatIcon should be desaturated, got " .. tostring(icon.label.desaturated)
    )
    assert(
      icon.background.desaturated == true,
      "test_icon_desaturated_when_no_unread: background should be desaturated, got "
        .. tostring(icon.background.desaturated)
    )
    assert(
      icon.border.desaturated == true,
      "test_icon_desaturated_when_no_unread: border should be desaturated, got " .. tostring(icon.border.desaturated)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_colorized_on_unread
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 3,
      getIconDesaturated = function()
        return true
      end,
      getShowUnreadBadge = function()
        return true
      end,
    })

    assert(
      icon.label.desaturated == false,
      "test_icon_colorized_on_unread: chatIcon should be colorized when unread > 0, got "
        .. tostring(icon.label.desaturated)
    )
    assert(
      icon.background.desaturated == false,
      "test_icon_colorized_on_unread: background should be colorized when unread > 0, got "
        .. tostring(icon.background.desaturated)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_desaturated_when_unread_cleared
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 5,
      getIconDesaturated = function()
        return true
      end,
      getShowUnreadBadge = function()
        return true
      end,
    })

    assert(icon.label.desaturated == false, "should be colorized initially with unread")

    icon.setUnreadCount(0)

    assert(
      icon.label.desaturated == true,
      "test_icon_desaturated_when_unread_cleared: icon should desaturate after unread cleared, got "
        .. tostring(icon.label.desaturated)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_icon_always_colorized_when_desaturation_disabled
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 0,
      getIconDesaturated = function()
        return false
      end,
      getShowUnreadBadge = function()
        return true
      end,
    })

    assert(
      icon.label.desaturated == false,
      "test_icon_always_colorized_when_desaturation_disabled: icon should never desaturate when setting is off, got "
        .. tostring(icon.label.desaturated)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_setCompetitiveContent_method_exists
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(
      type(icon.setCompetitiveContent) == "function",
      "test_setCompetitiveContent_method_exists: setCompetitiveContent should be a function"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_competitive_indicator_hidden_by_default
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(
      icon.competitiveIndicator ~= nil,
      "test_competitive_indicator_hidden_by_default: competitiveIndicator should exist"
    )
    assert(
      icon.competitiveIndicator.shown == false,
      "test_competitive_indicator_hidden_by_default: indicator should be hidden by default"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_competitive_indicator_shown_when_active
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    icon.setCompetitiveContent(true)

    assert(
      icon.competitiveIndicator.shown == true,
      "test_competitive_indicator_shown_when_active: indicator should show when competitive content is active"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_competitive_indicator_hidden_when_cleared
  -- -----------------------------------------------------------------------
  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    icon.setCompetitiveContent(true)
    icon.setCompetitiveContent(false)

    assert(
      icon.competitiveIndicator.shown == false,
      "test_competitive_indicator_hidden_when_cleared: indicator should hide when competitive content ends"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_competitive_tooltip_includes_status
  -- -----------------------------------------------------------------------
  do
    local tooltipText = ""
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipText = text
      end,
      Show = function() end,
      Hide = function() end,
    }

    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    icon.setCompetitiveContent(true)

    -- Trigger OnEnter to populate tooltip
    if icon.frame.scripts and icon.frame.scripts.OnEnter then
      icon.frame.scripts.OnEnter()
    end

    assert(
      string.find(tooltipText, "unavailable", 1, true) ~= nil,
      "test_competitive_tooltip_includes_status: tooltip should mention unavailable, got: " .. tostring(tooltipText)
    )

    _G.GameTooltip = nil
  end
end
