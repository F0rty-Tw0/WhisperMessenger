local CompactLayoutSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.CompactLayoutSetting")
local withPopups = require("tests.helpers.reload_popups").With

local function dialog(popups)
  return _G.StaticPopupDialogs[popups.shown[1]]
end

return function()
  -- test_a_new_style_waits_for_the_reload_before_saving
  withPopups(function(popups)
    local settings = { compactLayout = true }
    CompactLayoutSetting.Apply(settings, false, true)
    assert(#popups.shown == 1, "the player is offered a reload")
    assert(settings.compactLayout == true, "not saved yet")
    dialog(popups).OnAccept()
    assert(settings.compactLayout == false, "saved on reload")
    assert(popups.reloads == 1, "reloaded")
  end)

  -- test_cancel_drops_the_choice_and_shows_the_saved_style
  withPopups(function(popups)
    local settings = { compactLayout = true }
    local shown = nil
    CompactLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    dialog(popups).OnCancel()
    assert(settings.compactLayout == true, "the next login keeps the running window")
    assert(shown == true, "the toggle goes back")
  end)

  -- test_cancel_shows_a_never_saved_choice_as_the_compact_style
  withPopups(function(popups)
    local settings = {}
    local shown = nil
    CompactLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    dialog(popups).OnCancel()
    assert(settings.compactLayout == nil, "nothing saved")
    assert(shown == true, "an unset style is the compact style")
  end)

  -- test_the_running_style_saves_and_asks_nothing
  withPopups(function(popups)
    local settings = {}
    CompactLayoutSetting.Apply(settings, true, true)
    assert(settings.compactLayout == true, "saved")
    assert(#popups.shown == 0, "nothing changed, so no reload is needed")
    assert(#popups.hidden == 0, "and no one else's popup is closed")
  end)

  -- test_going_back_to_the_running_style_closes_the_offer
  withPopups(function(popups)
    local settings = { compactLayout = true }
    CompactLayoutSetting.Apply(settings, false, true)
    CompactLayoutSetting.Apply(settings, true, true)
    assert(#popups.shown == 1, "offered once")
    assert(#popups.hidden == 1, "and withdrawn")
    assert(settings.compactLayout == true, "the running style stays saved")
  end)

  -- test_the_last_choice_wins_when_the_popup_stays_up
  withPopups(function(popups)
    local settings = { compactLayout = false }
    CompactLayoutSetting.Apply(settings, true, false)
    dialog(popups).OnAccept()
    assert(settings.compactLayout == true, "classic running, compact chosen")
  end)

  -- test_a_client_with_no_popup_drops_the_choice
  withPopups(function()
    rawset(_G, "StaticPopup_Show", nil)
    local settings = { compactLayout = true }
    local shown = nil
    CompactLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    assert(settings.compactLayout == true and shown == true, "nothing to confirm with, so nothing changes")
  end)
end
