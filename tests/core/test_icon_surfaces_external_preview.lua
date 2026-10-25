local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

-- opts: own (built preview), external (holder entry), windowVisible,
-- tabMode, previewsOff, legacy (surfaces and icon without the external fields),
-- withPulse (the icon has setExternalPulse; its arguments land in state.pulses).
local function run(opts)
  local log = {}
  local state = { log = log, dropped = false, pulses = {} }
  local icon = {
    setIncomingPreview = function(sender)
      log[#log + 1] = "own:" .. tostring(sender)
    end,
  }
  if not opts.legacy then
    icon.setExternalPreview = function(entry)
      log[#log + 1] = "ext:" .. tostring(entry and entry.sender)
    end
  end
  if opts.withPulse then
    icon.setExternalPulse = function(on)
      state.pulses[#state.pulses + 1] = on
    end
  end
  local surfaces = {
    getWindow = function()
      return {
        getTabMode = function()
          return opts.tabMode or "whispers"
        end,
      }
    end,
    isWindowVisible = function()
      return opts.windowVisible == true
    end,
    buildMessagePreview = function()
      return opts.own
    end,
    getIcon = function()
      return icon
    end,
    getMinimapIcon = function()
      return {
        setIncomingPreview = function(sender)
          log[#log + 1] = "map:" .. tostring(sender)
        end,
      }
    end,
    getLdbObject = function()
      return nil
    end,
  }
  if not opts.legacy then
    surfaces.getExternalPreview = function()
      return opts.external
    end
    surfaces.dropExternalPreview = function()
      state.dropped = true
    end
    surfaces.previewsOff = function()
      return opts.previewsOff == true
    end
  end
  IconSurfaces.Update({}, surfaces)
  state.joined = table.concat(log, ",")
  return state
end

local function own(sentAt)
  return { senderName = "Jaina", messageText = "hi", sentAt = sentAt }
end

local function external(pulse)
  return { sender = "Crafter", text = "x", stamp = 100, pulse = pulse }
end

return function()
  local function test_external_alone_goes_to_the_widget_only()
    local s = run({ external = external() })
    assert(s.joined == "ext:Crafter,map:nil", "external shows on the widget only, got " .. s.joined)
  end

  local function test_newer_own_whisper_wins_and_drops_the_external()
    local s = run({ own = own(150), external = external() })
    assert(s.joined == "own:Jaina,map:Jaina", "a newer own whisper takes the widget, got " .. s.joined)
    assert(s.dropped == true, "the external entry is dropped")
  end

  local function test_own_not_newer_than_the_stamp_loses()
    for _, sentAt in ipairs({ 100, 50 }) do
      local s = run({ own = own(sentAt), external = external() })
      assert(s.joined == "ext:Crafter,map:Jaina", "own at " .. sentAt .. " keeps the external, got " .. s.joined)
      assert(s.dropped == false, "the external entry stays")
    end
  end

  local function test_whispers_tab_on_screen_does_not_suppress_external()
    local s = run({ own = own(150), external = external(), windowVisible = true, tabMode = "whispers" })
    assert(s.joined == "ext:Crafter,map:nil", "the open Whispers tab hides only the own preview, got " .. s.joined)
  end

  local function test_no_external_keeps_todays_behaviour()
    local s = run({ own = own(150) })
    assert(s.joined == "own:Jaina,map:Jaina", "no external shows the own preview, got " .. s.joined)
    local empty = run({})
    assert(empty.joined == "own:nil,map:nil", "nothing to show clears both, got " .. empty.joined)
  end

  local function test_surfaces_without_the_new_fields_still_work()
    local s = run({ own = own(150), legacy = true })
    assert(s.joined == "own:Jaina,map:Jaina", "old surfaces keep working, got " .. s.joined)
  end

  local function test_previews_off_drops_the_external()
    local s = run({ external = external(), previewsOff = true })
    assert(s.joined == "own:nil,map:nil", "previews off clear the widget, got " .. s.joined)
    assert(s.dropped == true, "the external entry is dropped")
  end

  local function pulses(s)
    return s.pulses
  end

  local function test_external_pulse_reaches_the_icon()
    assert(pulses(run({ withPulse = true, external = external(true) }))[1] == true, "an armed entry pulses the icon")
  end

  local function test_external_without_pulse_sends_false()
    assert(pulses(run({ withPulse = true, external = external() }))[1] == false, "an entry without pulse sends false")
  end

  local function test_newer_own_whisper_turns_the_pulse_off()
    local s = run({ withPulse = true, external = external(true), own = own(200) })
    assert(pulses(s)[1] == false, "a newer own whisper drops the external pulse")
  end

  local function test_no_external_entry_turns_the_pulse_off()
    assert(pulses(run({ withPulse = true, own = own(200) }))[1] == false, "no entry means no pulse")
  end

  local function test_previews_off_turns_the_pulse_off()
    local s = run({ withPulse = true, external = external(true), previewsOff = true })
    assert(pulses(s)[1] == false, "previews off drop the external pulse")
  end

  local function test_icon_without_set_external_pulse_still_works()
    local s = run({ external = external(true) })
    assert(s.joined == "ext:Crafter,map:nil", "an icon without setExternalPulse is left alone, got " .. s.joined)
  end

  test_external_pulse_reaches_the_icon()
  test_external_without_pulse_sends_false()
  test_newer_own_whisper_turns_the_pulse_off()
  test_no_external_entry_turns_the_pulse_off()
  test_previews_off_turns_the_pulse_off()
  test_icon_without_set_external_pulse_still_works()
  test_external_alone_goes_to_the_widget_only()
  test_newer_own_whisper_wins_and_drops_the_external()
  test_own_not_newer_than_the_stamp_loses()
  test_whispers_tab_on_screen_does_not_suppress_external()
  test_no_external_keeps_todays_behaviour()
  test_surfaces_without_the_new_fields_still_work()
  test_previews_off_drops_the_external()
end
