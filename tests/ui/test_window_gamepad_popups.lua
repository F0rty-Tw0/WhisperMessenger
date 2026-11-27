local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup(overrides)
  local env = FakeGamepad.New()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  local popup = factory.CreateFrame("Frame", "WhisperMessengerTestPopup", nil)
  return env, frame, GamepadNav.New(frame, env.deps(overrides)), popup
end

local function names(env)
  local out = {}
  for _, c in ipairs(env.calls) do
    table.insert(out, c.name)
  end
  return table.concat(out, ",")
end

local function endCombat(env)
  env.combat = false
  env.regen()
  env.flush()
end

local function open(nav, popup)
  popup:Show()
  nav.popupShown(popup)
end

local function close(nav, popup)
  popup:Hide()
  nav.popupHidden(popup)
end

return function()
  -- test_popup_shown_hands_focus_to_the_popup
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    assert(names(env) == "FrameShown,HandlePopupShown" and env.calls[2].args[1] == popup, "FCM focuses the popup")
    assert(env.isListed(popup), "popup listed")
  end

  -- test_popup_hidden_returns_focus_and_keeps_the_window
  do
    local env, frame, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    close(nav, popup)
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden", "shown, then hidden, in that order")
    assert(env.calls[3].args[1] == popup and env.calls[3].args[1] ~= frame, "the popup leaves, not the window")
    assert(not env.isListed(popup) and nav.isRegistered(), "window still registered")
  end

  -- test_popup_hidden_without_being_shown_does_nothing
  do
    local env, _, nav, popup = setup()
    nav.popupHidden(popup) -- builders hide a new popup once at creation
    close(nav, popup)
    assert(#env.calls == 0, "never listed: no FrameHidden")
  end

  -- test_popup_refused_by_the_game_is_not_handed_back_on_hide
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    env.refusePopups = true
    open(nav, popup)
    close(nav, popup)
    assert(env.count("HandlePopupShown") == 1 and env.count("FrameHidden") == 0, "refused popup: no FrameHidden on close")
  end

  -- test_popup_reshown_while_still_listed_is_hidden_first
  do
    local env, _, nav, popup = setup()
    open(nav, popup)
    nav.popupShown(popup)
    assert(names(env) == "HandlePopupShown,FrameHidden,HandlePopupShown", "stale entry: hide, then show once")
  end

  -- test_popup_shown_in_combat_waits_for_regen
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    env.combat = true
    open(nav, popup)
    assert(names(env) == "FrameShown", "nothing in combat")
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown", "focused once combat ends")
  end

  -- test_popup_shown_and_hidden_in_one_combat_leaves_no_entry
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    env.combat = true
    open(nav, popup)
    close(nav, popup)
    endCombat(env)
    assert(names(env) == "FrameShown" and not env.isListed(popup), "cancelled out: no FCM call at all")
  end

  -- test_popup_hidden_in_combat_is_hidden_on_regen
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    env.combat = true
    close(nav, popup)
    assert(env.count("FrameHidden") == 0, "blocked in combat")
    endCombat(env)
    env.regen()
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden" and env.calls[3].args[1] == popup, "hidden once on regen")
  end

  -- test_popup_reshown_in_combat_is_hidden_then_shown_on_regen
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    env.combat = true
    close(nav, popup)
    open(nav, popup)
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden,HandlePopupShown", "still listed: hide, then show")
    assert(env.isListed(popup), "ends listed")
  end

  -- test_popup_closed_before_regen_is_not_shown
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    env.combat = true
    nav.popupShown(popup) -- asked while shown, then hidden without a report
    endCombat(env)
    assert(names(env) == "FrameShown", "not shown at regen: no HandlePopupShown")
  end

  -- test_regen_settles_window_then_popups_then_rescan
  do
    local env, _, nav, popup = setup()
    env.combat = true
    nav.onShow()
    open(nav, popup)
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown", "window first: it is the popup's return frame")
    env.combat = true
    local other = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    nav.ignore({})
    open(nav, other)
    nav.refresh()
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown,MarkFrameIgnored,HandlePopupShown,RefreshButtonGroups", "marks, popups, re-scan")
  end

  -- test_pending_popups_settle_in_the_order_asked
  do
    local env, _, nav, first = setup()
    local second = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    nav.onShow()
    env.combat = true
    open(nav, second)
    open(nav, first)
    open(nav, second)
    endCombat(env)
    assert(env.calls[2].args[1] == second and env.calls[3].args[1] == first and #env.calls == 3, "first-asked order, once each")
  end

  -- test_second_combat_settles_the_popup_again
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    env.combat = true
    open(nav, popup)
    endCombat(env)
    env.combat = true
    close(nav, popup)
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden" and not env.isListed(popup), "each combat settles on its own")
  end

  -- test_popup_reopened_before_the_regen_event_stays_listed
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    env.combat = true
    close(nav, popup)
    env.combat = false
    open(nav, popup) -- combat is over, PLAYER_REGEN_ENABLED not yet fired
    env.regen()
    env.flush()
    assert(env.isListed(popup) and env.count("FrameHidden") == 1, "the late settle does not hide the open popup")
  end

  -- test_combat_start_unlists_open_popup_and_reshows_it_after_the_window
  do
    local env, frame, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    env.fire("PLAYER_REGEN_DISABLED")
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden,FrameHidden", "popup and window leave before lockdown")
    assert(env.calls[3].args[1] == popup and env.calls[4].args[1] == frame and not env.isListed(popup), "popup first")
    env.combat = true
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden,FrameHidden,FrameShown,HandlePopupShown", "window, then popup")
    assert(env.isListed(popup), "popup listed again")
  end

  -- test_popup_closed_in_combat_after_combat_start_is_not_reshown
  do
    local env, _, nav, popup = setup()
    nav.onShow()
    open(nav, popup)
    env.fire("PLAYER_REGEN_DISABLED")
    env.combat = true
    close(nav, popup)
    endCombat(env)
    assert(names(env) == "FrameShown,HandlePopupShown,FrameHidden,FrameHidden,FrameShown", "closed meanwhile: no popup call")
  end

  -- test_popup_close_handler_reports_handled_once_per_popup
  do
    local _, _, nav, popup = setup()
    local closed = 0
    nav.setPopupCloseHandler(popup, function()
      closed = closed + 1
      return true
    end)
    nav.setPopupCloseHandler(popup, function()
      return false
    end)
    assert(popup.SmartNavigationCloseHandler(popup) == true and closed == 1, "the first handler stays")
  end

  -- test_popup_methods_without_the_api_touch_nothing
  for _, overrides in ipairs({ { smartNavigation = false }, { gamepadMode = false } }) do
    local env, _, nav, popup = setup(overrides)
    nav.setPopupCloseHandler(popup, function()
      return true
    end)
    open(nav, popup)
    close(nav, popup)
    assert(#env.calls == 0 and popup.SmartNavigationCloseHandler == nil, "inert without the gamepad UI API")
  end

  -- test_popup_methods_without_handle_popup_shown_do_nothing
  do
    local env = FakeGamepad.New()
    local fcm = env.gamepadMode.FrameControlsManager
    local factory = FakeUI.NewFactory()
    local frame, popup = factory.CreateFrame("Frame", nil, nil), factory.CreateFrame("Frame", nil, nil)
    local gamepadMode = { FrameControlsManager = { FrameShown = fcm.FrameShown, FrameHidden = fcm.FrameHidden } }
    local nav = GamepadNav.New(frame, env.deps({ gamepadMode = gamepadMode }))
    open(nav, popup)
    close(nav, popup)
    nav.setPopupCloseHandler(popup, function()
      return true
    end)
    assert(#env.calls == 0 and popup.SmartNavigationCloseHandler == nil, "older client without HandlePopupShown: no popup call, no error")
  end
end
