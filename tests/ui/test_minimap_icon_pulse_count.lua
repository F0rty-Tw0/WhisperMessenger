local AnimatedFactory = require("tests.helpers.animated_factory")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

local function build()
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  local icon = MinimapIcon.Create(factory, {
    parent = parent,
    getBadgePulse = function()
      return true
    end,
    getShowUnreadBadge = function()
      return true
    end,
  })
  return icon
end

return function()
  -- test_panel_badges_alone_do_not_pulse
  do
    local icon = build()
    icon.setUnreadCount(2, 0)
    assert(icon.badgeLabel:GetText() == "2", "badge shows the total, got " .. tostring(icon.badgeLabel:GetText()))
    assert(icon.pulseGlow.animation.playing == false, "panel badges alone do not glow")
  end

  -- test_whisper_unread_still_pulses_with_panel_badges
  do
    local icon = build()
    icon.setUnreadCount(3, 1)
    assert(icon.badgeLabel:GetText() == "3", "badge shows the total")
    assert(icon.pulseGlow.animation.playing == true, "a whisper still glows")
  end

  -- test_count_alone_still_pulses_for_old_callers
  do
    local icon = build()
    icon.setUnreadCount(2)
    assert(icon.pulseGlow.animation.playing == true, "no pulse count: the count decides")
  end
end
