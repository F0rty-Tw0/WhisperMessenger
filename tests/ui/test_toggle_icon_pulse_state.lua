local PulseState = require("WhisperMessenger.UI.ToggleIcon.PulseState")

local function build(opts)
  opts = opts or {}
  local env = { glow = { on = false, starts = 0, stops = 0 }, shown = true, allowPulse = true }
  local options = {
    start = function()
      env.glow.on = true
      env.glow.starts = env.glow.starts + 1
    end,
    stop = function()
      env.glow.on = false
      env.glow.stops = env.glow.stops + 1
    end,
    isExternalShown = function()
      return env.shown
    end,
  }
  if not opts.noSetting then
    options.getBadgePulse = function()
      return env.allowPulse
    end
  end
  env.state = PulseState.New(options)
  return env
end

return function()
  local function test_stopping_one_source_never_stops_the_other()
    local e = build()
    e.state.setUnreadWants(true)
    e.state.setExternal(true)
    e.state.setUnreadWants(false)
    assert(e.glow.on == true, "external keeps it")
    e.state.setExternal(false)
    assert(e.glow.on == false, "both off stops it")
    e.state.setExternal(true)
    e.state.setUnreadWants(true)
    e.state.setExternal(false)
    assert(e.glow.on == true, "unread keeps it")
  end

  local function test_external_glows_only_while_the_preview_shows()
    local e = build()
    e.state.setExternal(true)
    assert(e.glow.on == true, "external glows while shown")
    e.shown = false
    e.state.refresh()
    assert(e.glow.on == false, "only while the preview shows")
    e.shown = true
    e.state.refresh()
    assert(e.glow.on == true, "back when it shows again")
  end

  local function test_external_obeys_only_the_pulse_setting()
    local e = build()
    e.allowPulse = false
    e.state.setExternal(true)
    assert(e.glow.on == false, "pulse setting off silences the external glow")
    e.allowPulse = true
    e.state.refresh()
    assert(e.glow.on == true, "setting back on lets it glow")
  end

  local function test_missing_pulse_setting_allows_the_external_glow()
    local e = build({ noSetting = true })
    e.state.setExternal(true)
    assert(e.glow.on == true, "no getBadgePulse means allowed")
  end

  local function test_unread_wants_ignores_the_external_conditions()
    local e = build()
    e.shown = false
    e.state.setUnreadWants(true)
    assert(e.glow.on == true, "unread glow does not need the preview")
  end

  test_stopping_one_source_never_stops_the_other()
  test_external_glows_only_while_the_preview_shows()
  test_external_obeys_only_the_pulse_setting()
  test_missing_pulse_setting_allows_the_external_glow()
  test_unread_wants_ignores_the_external_conditions()
end
