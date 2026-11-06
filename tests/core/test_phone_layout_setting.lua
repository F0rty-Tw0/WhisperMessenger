local PhoneLayoutSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PhoneLayoutSetting")
local withPopups = require("tests.helpers.reload_popups").With

local function dialog(popups)
  return _G.StaticPopupDialogs[popups.shown[1]]
end

return function()
  -- test_a_new_style_waits_for_the_reload_before_saving
  withPopups(function(popups)
    local settings = { phoneLayout = true }
    PhoneLayoutSetting.Apply(settings, false, true)
    assert(#popups.shown == 1, "the player is offered a reload")
    assert(settings.phoneLayout == true, "not saved yet")
    dialog(popups).OnAccept()
    assert(settings.phoneLayout == false, "saved on reload")
    assert(popups.reloads == 1, "reloaded")
  end)

  -- test_cancel_drops_the_choice_and_shows_the_saved_style
  withPopups(function(popups)
    local settings = { phoneLayout = true }
    local shown = nil
    PhoneLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    dialog(popups).OnCancel()
    assert(settings.phoneLayout == true, "the next login keeps the running window")
    assert(shown == true, "the toggle goes back")
  end)

  -- test_cancel_shows_a_never_saved_choice_as_the_phone_style
  withPopups(function(popups)
    local settings = {}
    local shown = nil
    PhoneLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    dialog(popups).OnCancel()
    assert(settings.phoneLayout == nil, "nothing saved")
    assert(shown == true, "an unset style is the phone style")
  end)

  -- test_the_running_style_saves_and_asks_nothing
  withPopups(function(popups)
    local settings = {}
    PhoneLayoutSetting.Apply(settings, true, true)
    assert(settings.phoneLayout == true, "saved")
    assert(#popups.shown == 0, "nothing changed, so no reload is needed")
    assert(#popups.hidden == 0, "and no one else's popup is closed")
  end)

  -- test_going_back_to_the_running_style_closes_the_offer
  withPopups(function(popups)
    local settings = { phoneLayout = true }
    PhoneLayoutSetting.Apply(settings, false, true)
    PhoneLayoutSetting.Apply(settings, true, true)
    assert(#popups.shown == 1, "offered once")
    assert(#popups.hidden == 1, "and withdrawn")
    assert(settings.phoneLayout == true, "the running style stays saved")
  end)

  -- test_the_last_choice_wins_when_the_popup_stays_up
  withPopups(function(popups)
    local settings = { phoneLayout = false }
    PhoneLayoutSetting.Apply(settings, true, false)
    dialog(popups).OnAccept()
    assert(settings.phoneLayout == true, "classic running, phone chosen")
  end)

  -- test_a_client_with_no_popup_drops_the_choice
  withPopups(function()
    rawset(_G, "StaticPopup_Show", nil)
    local settings = { phoneLayout = true }
    local shown = nil
    PhoneLayoutSetting.Apply(settings, false, true, function(saved)
      shown = saved
    end)
    assert(settings.phoneLayout == true and shown == true, "nothing to confirm with, so nothing changes")
  end)
end
