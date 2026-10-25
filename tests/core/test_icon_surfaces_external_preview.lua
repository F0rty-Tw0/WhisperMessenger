local IconSurfaces = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")

-- opts: own (built preview), external (holder entry), windowVisible,
-- tabMode, legacy (surfaces and icon without the external fields).
local function run(opts)
  local log = {}
  local state = { log = log, dropped = false }
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
  end
  IconSurfaces.Update({}, surfaces)
  state.joined = table.concat(log, ",")
  return state
end

local function own(sentAt)
  return { senderName = "Jaina", messageText = "hi", sentAt = sentAt }
end

local function external()
  return { sender = "Crafter", text = "x", stamp = 100 }
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

  test_external_alone_goes_to_the_widget_only()
  test_newer_own_whisper_wins_and_drops_the_external()
  test_own_not_newer_than_the_stamp_loses()
  test_whispers_tab_on_screen_does_not_suppress_external()
  test_no_external_keeps_todays_behaviour()
  test_surfaces_without_the_new_fields_still_work()
end
