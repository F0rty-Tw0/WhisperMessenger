local AnimatedFactory = require("tests.helpers.animated_factory")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function build(opts)
  opts = opts or {}
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:Show()
  local icon = ToggleIcon.Create(factory, {
    parent = parent,
    getBadgePulse = function()
      return opts.badgePulse ~= false
    end,
    getShowUnreadBadge = function()
      return opts.showBadge ~= false
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

local function entry()
  return {
    sender = "Crafter",
    text = "Needs Plate Belt",
    classTag = "WARRIOR",
    onClick = function() end,
    onDismiss = function() end,
    onShown = function() end,
  }
end

return function()
  -- A shown preview with its pulse on: the glow is playing.
  local function glowingIcon()
    local icon, glowPlaying = build()
    icon.setUnreadCount(0)
    icon.setExternalPreview(entry())
    icon.setExternalPulse(true)
    return icon, glowPlaying
  end

  local function test_external_pulse_glows()
    local _, glowPlaying = glowingIcon()
    assert(glowPlaying(), "external pulse glows")
  end

  local function test_an_unread_refresh_keeps_the_external_glow()
    local icon, glowPlaying = glowingIcon()
    icon.setUnreadCount(0)
    assert(glowPlaying(), "an unread refresh does not stop the external glow")
  end

  local function test_turning_the_external_pulse_off_stops_the_glow()
    local icon, glowPlaying = glowingIcon()
    icon.setExternalPulse(false)
    assert(not glowPlaying(), "turning the external pulse off stops it")
  end

  local function test_unread_pulse_survives_the_external_pulse_stopping()
    local icon, glowPlaying = build()
    icon.setExternalPreview(entry())
    icon.setExternalPulse(true)
    icon.setUnreadCount(3)
    icon.setExternalPulse(false)
    assert(glowPlaying(), "unread still glows")
    icon.setUnreadCount(0)
    assert(not glowPlaying(), "no unread, no external: dark")
  end

  local function test_clearing_the_preview_stops_the_glow()
    local icon, glowPlaying = build()
    icon.setExternalPreview(entry())
    icon.setExternalPulse(true)
    assert(glowPlaying(), "glowing before the dismiss")
    icon.previewFrame:GetScript("OnMouseUp")(icon.previewFrame, "RightButton")
    assert(not glowPlaying(), "dismissing the preview stops its glow")
  end

  local function test_badge_hidden_still_pulses_for_external()
    local icon, glowPlaying = build({ showBadge = false })
    icon.setExternalPreview(entry())
    icon.setExternalPulse(true)
    assert(glowPlaying(), "the external glow does not need the badge")
  end

  local function test_pulse_setting_off_silences_the_external_glow()
    local icon, glowPlaying = build({ badgePulse = false })
    icon.setExternalPreview(entry())
    icon.setExternalPulse(true)
    assert(not glowPlaying(), "the pulse setting rules the external glow")
  end

  local function test_pulse_without_a_shown_preview_does_not_glow()
    local icon, glowPlaying = build()
    icon.setExternalPulse(true)
    assert(not glowPlaying(), "no preview, no glow")
  end

  test_external_pulse_glows()
  test_an_unread_refresh_keeps_the_external_glow()
  test_turning_the_external_pulse_off_stops_the_glow()
  test_unread_pulse_survives_the_external_pulse_stopping()
  test_clearing_the_preview_stops_the_glow()
  test_badge_hidden_still_pulses_for_external()
  test_pulse_setting_off_silences_the_external_glow()
  test_pulse_without_a_shown_preview_does_not_glow()
end
