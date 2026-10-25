local AnimatedFactory = require("tests.helpers.animated_factory")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function build()
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:Show()
  local icon = ToggleIcon.Create(factory, {
    parent = parent,
    getBadgePulse = function()
      return true
    end,
    getShowUnreadBadge = function()
      return true
    end,
  })
  icon.frame:Show()
  local function glowPlaying()
    for _, group in ipairs(factory.groups) do
      if group.playing then
        return true
      end
    end
    return false
  end
  return icon, glowPlaying
end

return function()
  -- test_panel_badges_alone_do_not_pulse
  do
    local icon, glowPlaying = build()
    icon.setUnreadCount(2, 0)
    assert(icon.badgeLabel:GetText() == "2", "badge shows the total, got " .. tostring(icon.badgeLabel:GetText()))
    assert(not glowPlaying(), "panel badges alone do not glow")
  end

  -- test_whisper_unread_still_pulses_with_panel_badges
  do
    local icon, glowPlaying = build()
    icon.setUnreadCount(3, 1)
    assert(icon.badgeLabel:GetText() == "3", "badge shows the total")
    assert(glowPlaying(), "a whisper still glows")
  end

  -- test_count_alone_still_pulses_for_old_callers
  do
    local icon, glowPlaying = build()
    icon.setUnreadCount(2)
    assert(glowPlaying(), "no pulse count: the count decides")
  end
end
