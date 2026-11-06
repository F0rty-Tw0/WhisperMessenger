local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local function build(running)
  local case = { shown = 0, hidden = 0, settings = {} }
  case.savedShow = rawget(_G, "StaticPopup_Show")
  case.savedHide = rawget(_G, "StaticPopup_Hide")
  rawset(_G, "StaticPopup_Show", function()
    case.shown = case.shown + 1
  end)
  rawset(_G, "StaticPopup_Hide", function()
    case.hidden = case.hidden + 1
  end)
  case.onChange = SettingsHandler.Create({
    runtime = { store = { config = {} }, phoneLayoutActive = running },
    accountSettings = case.settings,
  })
  return case
end

local function restore(case)
  rawset(_G, "StaticPopup_Show", case.savedShow)
  rawset(_G, "StaticPopup_Hide", case.savedHide)
end

return function()
  -- test_changing_the_window_style_saves_and_offers_a_reload
  do
    local case = build(true)
    case.onChange("phoneLayout", false)
    restore(case)
    assert(case.settings.phoneLayout == false, "saved")
    assert(case.shown == 1, "the player is offered a reload")
  end

  -- test_reset_to_the_running_style_asks_nothing
  do
    local case = build(true)
    case.onChange("phoneLayout", true)
    restore(case)
    assert(case.settings.phoneLayout == true, "saved")
    assert(case.shown == 0, "nothing changed, so no reload is needed")
    assert(case.hidden == 0, "and no one else's popup is closed")
  end

  -- test_going_back_to_the_running_style_closes_the_offer
  do
    local case = build(true)
    case.onChange("phoneLayout", false)
    case.onChange("phoneLayout", true)
    restore(case)
    assert(case.shown == 1, "offered once")
    assert(case.hidden == 1, "and withdrawn")
  end

  -- test_classic_session_offers_a_reload_for_the_phone_style
  do
    local case = build(false)
    case.onChange("phoneLayout", true)
    restore(case)
    assert(case.shown == 1, "classic running, phone chosen")
  end
end
