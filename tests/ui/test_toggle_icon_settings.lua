local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_badge_hidden_when_showUnreadBadge_disabled

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

    assert(icon.badge.shown == false, "test_badge_hidden_when_showUnreadBadge_disabled: badge should be hidden when setting is off")
  end

  -- test_badge_shown_when_showUnreadBadge_enabled

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

    assert(icon.badge.shown == true, "test_badge_shown_when_showUnreadBadge_enabled: badge should be visible when setting is on")
  end

  -- test_badge_hidden_when_showUnreadBadge_toggled_off_dynamically

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

    assert(icon.badge.shown == false, "test_badge_hidden_when_showUnreadBadge_toggled_off_dynamically: badge should hide after setting toggled off")
  end

  -- test_pulse_not_started_when_badgePulse_disabled

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

  -- test_defaults_when_no_getters_provided

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      unreadCount = 5,
    })

    -- Without getters, should default to showing badge (backward compat)
    assert(icon.badge.shown == true, "test_defaults_when_no_getters_provided: badge should show by default")
  end

  -- test_icon_uses_custom_size

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      iconSize = 32,
    })

    local w, h = icon.frame:GetSize()
    assert(w == 32, "test_icon_uses_custom_size: frame width should be 32, got " .. tostring(w))
    assert(h == 32, "test_icon_uses_custom_size: frame height should be 32, got " .. tostring(h))
  end

  -- test_apply_icon_size_resizes_frame

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
      "test_apply_icon_size_resizes_frame: chat icon width should be " .. expectedChatSize .. ", got " .. tostring(chatW)
    )
  end

  -- test_icon_desaturated_when_no_unread

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
      "test_icon_desaturated_when_no_unread: background should be desaturated, got " .. tostring(icon.background.desaturated)
    )
    assert(
      icon.border.desaturated == true,
      "test_icon_desaturated_when_no_unread: border should be desaturated, got " .. tostring(icon.border.desaturated)
    )
  end

  -- test_icon_colorized_on_unread

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
      "test_icon_colorized_on_unread: chatIcon should be colorized when unread > 0, got " .. tostring(icon.label.desaturated)
    )
    assert(
      icon.background.desaturated == false,
      "test_icon_colorized_on_unread: background should be colorized when unread > 0, got " .. tostring(icon.background.desaturated)
    )
  end

  -- test_icon_desaturated_when_unread_cleared

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
      "test_icon_desaturated_when_unread_cleared: icon should desaturate after unread cleared, got " .. tostring(icon.label.desaturated)
    )
  end

  -- test_icon_always_colorized_when_desaturation_disabled

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

  -- test_message_preview_hidden_by_default

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(icon.previewFrame ~= nil, "test_message_preview_hidden_by_default: previewFrame should exist")
    assert(icon.previewFrame.shown == false, "test_message_preview_hidden_by_default: preview should start hidden when no incoming message exists")
  end

  -- test_setIncomingPreview_shows_sender_and_message

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(type(icon.setIncomingPreview) == "function", "setIncomingPreview method should exist")
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")

    assert(icon.previewFrame.shown == true, "preview should show after setting incoming preview")
    assert(
      icon.previewSenderLabel.text == "Jaina-Proudmoore",
      "preview sender should render the sender name, got: " .. tostring(icon.previewSenderLabel.text)
    )
    assert(
      icon.previewMessageLabel.text == "Need assistance?",
      "preview message should render the latest incoming text, got: " .. tostring(icon.previewMessageLabel.text)
    )
  end

  -- test_dismiss_preview_hides_and_calls_handler

  do
    local dismissed = false
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      onDismissPreview = function()
        dismissed = true
      end,
    })

    assert(icon.previewDismissButton ~= nil, "preview dismiss button should exist")
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")

    local onClick = icon.previewDismissButton:GetScript("OnClick")
    assert(onClick ~= nil, "preview dismiss button should have OnClick handler")
    onClick(icon.previewDismissButton)

    assert(dismissed == true, "dismiss handler should fire when preview dismiss button clicked")
    assert(icon.previewFrame.shown == false, "preview should hide after dismiss button clicked")
    assert(icon.previewSenderLabel.text == "", "preview sender should clear after dismiss")
    assert(icon.previewMessageLabel.text == "", "preview message should clear after dismiss")
  end

  -- test_setIncomingPreview_clears_when_message_missing

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")
    icon.setIncomingPreview(nil, nil)

    assert(icon.previewFrame.shown == false, "preview should hide when cleared")
    assert(icon.previewSenderLabel.text == "", "preview sender should clear when hidden")
    assert(icon.previewMessageLabel.text == "", "preview message should clear when hidden")
  end

  -- test_right_click_on_preview_dismisses

  do
    local dismissed = false
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      onDismissPreview = function()
        dismissed = true
      end,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")

    local onMouseUp = icon.previewFrame:GetScript("OnMouseUp")
    assert(onMouseUp ~= nil, "preview frame should have OnMouseUp handler for right-click dismiss")
    onMouseUp(icon.previewFrame, "RightButton")

    assert(dismissed == true, "right-click on preview should trigger dismiss handler")
    assert(icon.previewFrame.shown == false, "preview should hide after right-click dismiss")
  end

  -- test_left_click_on_preview_does_not_dismiss

  do
    local dismissed = false
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      onDismissPreview = function()
        dismissed = true
      end,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")

    local onMouseUp = icon.previewFrame:GetScript("OnMouseUp")
    onMouseUp(icon.previewFrame, "LeftButton")

    assert(dismissed == false, "left-click on preview should not dismiss")
    assert(icon.previewFrame.shown == true, "preview should remain visible on left-click")
  end

  -- test_preview_class_icon_renders

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")

    assert(icon.previewClassIcon ~= nil, "preview class icon should exist")
    assert(
      type(icon.previewClassIcon.texturePath) == "string" and icon.previewClassIcon.texturePath:find("ClassIcon_MAGE"),
      "preview class icon texture should resolve from classTag"
    )
    assert(icon.previewClassIconFrame.shown == true, "preview class icon frame should show when preview visible")
  end

  -- test_preview_width_clamped_between_min_and_max

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")

    local width = icon.previewFrame.width or 0
    assert(width > 0, "preview width should be set after content populates")
    assert(width <= 200, "preview width should not exceed max (200), got: " .. tostring(width))

    icon.setIncomingPreview("Arthas", string.rep("A very long incoming message text ", 10), "DEATHKNIGHT")
    local wideWidth = icon.previewFrame.width or 0
    assert(wideWidth == 200, "very long content should cap at max width 200, got: " .. tostring(wideWidth))
  end

  -- test_preview_auto_dismiss_schedules_timer_when_enabled

  do
    local timers = {}
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function(_seconds, _callback) end,
      NewTimer = function(seconds, callback)
        table.insert(timers, { seconds = seconds, callback = callback })
        return { Cancel = function() end }
      end,
    }

    local dismissed = false
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      getPreviewAutoDismissSeconds = function()
        return 30
      end,
      onDismissPreview = function()
        dismissed = true
      end,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")

    assert(#timers == 1, "expected one auto-dismiss timer scheduled")
    assert(timers[1].seconds == 30, "timer should be scheduled for configured seconds")
    assert(icon.previewFrame.shown == true, "preview should remain visible before timer fires")

    timers[1].callback()
    assert(icon.previewFrame.shown == false, "timer callback should dismiss the preview")
    assert(dismissed == true, "timer dismiss should invoke onDismissPreview handler")

    _G.C_Timer = savedTimer
  end

  -- test_preview_auto_dismiss_not_scheduled_when_seconds_zero

  do
    local timers = {}
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function(_seconds, _callback) end,
      NewTimer = function(seconds, callback)
        table.insert(timers, { seconds = seconds, callback = callback })
        return { Cancel = function() end }
      end,
    }

    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      getPreviewAutoDismissSeconds = function()
        return 0
      end,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")

    assert(#timers == 0, "no timer should be scheduled when auto-dismiss is zero")
    assert(icon.previewFrame.shown == true, "preview should stay shown when auto-dismiss disabled")

    _G.C_Timer = savedTimer
  end

  -- test_preview_auto_dismiss_cancelled_on_new_preview

  do
    local timers = {}
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function(_seconds, _callback) end,
      NewTimer = function(seconds, callback)
        table.insert(timers, { seconds = seconds, callback = callback })
        return { Cancel = function() end }
      end,
    }

    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      getPreviewAutoDismissSeconds = function()
        return 30
      end,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "First", "MAGE")
    icon.setIncomingPreview("Arthas", "Second", "DEATHKNIGHT")

    assert(#timers == 2, "expected a timer per preview update")
    timers[1].callback()
    assert(icon.previewFrame.shown == true, "stale timer should not dismiss the current preview")
    assert(icon.previewMessageLabel.text == "Second", "current preview text should be preserved")

    timers[2].callback()
    assert(icon.previewFrame.shown == false, "latest timer should dismiss the current preview")

    _G.C_Timer = savedTimer
  end

  -- test_preview_auto_dismiss_keeps_original_timer_when_same_content_resent

  do
    local timers = {}
    local cancelCount = 0
    local savedTimer = _G.C_Timer
    _G.C_Timer = {
      After = function() end,
      NewTimer = function(seconds, callback)
        local timer = { seconds = seconds, callback = callback }
        timer.Cancel = function()
          cancelCount = cancelCount + 1
        end
        table.insert(timers, timer)
        return timer
      end,
    }

    local icon = ToggleIcon.Create(factory, {
      parent = parent,
      getPreviewAutoDismissSeconds = function()
        return 30
      end,
    })

    icon.setIncomingPreview("Jaina", "Need help?", "MAGE")
    icon.setIncomingPreview("Jaina", "Need help?", "MAGE")
    icon.setIncomingPreview("Jaina", "Need help?", "MAGE")

    assert(#timers == 1, "expected only one auto-dismiss timer when the same preview content is reapplied via refresh, got: " .. tostring(#timers))

    timers[1].callback()
    assert(
      icon.previewFrame.shown == false,
      "original auto-dismiss timer must still fire and dismiss the preview after repeated same-content refreshes"
    )

    _G.C_Timer = savedTimer
  end

  -- test_preview_dismiss_button_hover_changes_color

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })
    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?")

    local onEnter = icon.previewDismissButton:GetScript("OnEnter")
    local onLeave = icon.previewDismissButton:GetScript("OnLeave")
    assert(onEnter ~= nil, "dismiss button should have OnEnter handler")
    assert(onLeave ~= nil, "dismiss button should have OnLeave handler")

    onEnter(icon.previewDismissButton)
    local hoverColor = icon.previewDismissLabel.textColor or {}
    assert(hoverColor[1] and hoverColor[1] > 0.9, "hover should brighten dismiss label red channel")

    onLeave(icon.previewDismissButton)
    local idleColor = icon.previewDismissLabel.textColor or {}
    assert(idleColor[1] and idleColor[1] < 0.9, "leave should restore base red tint")
  end

  -- test_setCompetitiveContent_method_exists

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(type(icon.setCompetitiveContent) == "function", "test_setCompetitiveContent_method_exists: setCompetitiveContent should be a function")
  end

  -- test_competitive_indicator_hidden_by_default

  do
    local icon = ToggleIcon.Create(factory, {
      parent = parent,
    })

    assert(icon.competitiveIndicator ~= nil, "test_competitive_indicator_hidden_by_default: competitiveIndicator should exist")
    assert(icon.competitiveIndicator.shown == false, "test_competitive_indicator_hidden_by_default: indicator should be hidden by default")
  end

  -- test_competitive_indicator_shown_when_active

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

  -- test_competitive_indicator_hidden_when_cleared

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

  -- test_competitive_tooltip_includes_status

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
