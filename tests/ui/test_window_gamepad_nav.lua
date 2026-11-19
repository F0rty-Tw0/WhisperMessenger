local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup(overrides)
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps(overrides))
end

return function()
  -- test_off_forever_touches_nothing
  for _, overrides in ipairs({ { isForever = false }, { gamepadMode = false } }) do
    local env, frame, nav = setup(overrides)
    nav.setCloseHandler(function()
      return true
    end)
    nav.setScrollFrame({})
    nav.onShow()
    nav.refresh()
    nav.ignore({})
    nav.onHide()
    env.flush()
    assert(#env.calls == 0 and frame.SmartNavigationCloseHandler == nil and nav.isActive() == false, "inert off Forever")
  end

  -- test_show_registers_and_hide_unregisters
  do
    local env, frame, nav = setup()
    nav.onShow()
    assert(env.count("FrameShown") == 1 and nav.isRegistered(), "show registers once")
    nav.onHide()
    assert(env.count("FrameHidden") == 1 and not nav.isRegistered(), "hide unregisters once")
    assert(env.calls[2].args[1] == frame, "the window frame is what FCM gets")
  end

  -- test_mouse_mode_show_makes_no_later_calls
  do
    local env, _, nav = setup()
    env.shownResults = { "nil" }
    nav.onShow()
    nav.refresh()
    env.flush()
    nav.onHide()
    assert(#env.calls == 1 and not nav.isRegistered(), "nil from FrameShown: nothing more")
  end

  -- test_stale_entry_is_hidden_then_shown_once
  do
    local env, _, nav = setup()
    env.shownResults = { false, true }
    nav.onShow()
    local names = {}
    for _, c in ipairs(env.calls) do
      table.insert(names, c.name)
    end
    assert(table.concat(names, ",") == "FrameShown,FrameHidden,FrameShown" and nav.isRegistered(), "recovery once")
  end

  -- test_panel_info_callback_sets_the_chat_scroll_frame
  do
    local env, frame, nav = setup()
    local chatScroll = {}
    nav.setScrollFrame(chatScroll)
    nav.onShow()
    assert(env.count("SetScrollFrameForFrame") == 1 and env.scrollFrameFor(frame) == chatScroll, "right stick → chat")
  end

  -- test_close_handler_returns_what_fn_returns
  do
    local _, frame, nav = setup()
    nav.setCloseHandler(function()
      return true
    end)
    assert(frame.SmartNavigationCloseHandler(frame) == true, "B handled by us")
  end

  -- test_two_refreshes_in_one_frame_rescan_once
  do
    local env, _, nav = setup()
    nav.onShow()
    nav.refresh()
    nav.refresh()
    assert(env.count("RefreshButtonGroups") == 0, "deferred to next frame")
    env.flush()
    assert(env.count("RefreshButtonGroups") == 1, "coalesced to one")
  end

  -- test_refresh_while_unregistered_does_nothing
  do
    local env, _, nav = setup()
    nav.refresh()
    env.flush()
    assert(env.count("RefreshButtonGroups") == 0, "not registered: no re-scan")
  end

  -- test_refresh_then_hide_before_next_frame_does_not_rescan
  do
    local env, _, nav = setup()
    nav.onShow()
    nav.refresh()
    nav.onHide()
    env.flush()
    assert(env.count("RefreshButtonGroups") == 0, "hidden before the frame ran")
  end

  -- test_refresh_without_panel_info_does_not_rescan
  do
    local env, frame, nav = setup()
    nav.onShow()
    env.panelInfo[frame] = nil
    nav.refresh()
    env.flush()
    assert(env.count("RefreshButtonGroups") == 0, "would recreate panel info")
  end

  -- test_ignore_marks_each_widget_once
  do
    local env, _, nav = setup()
    local grip = {}
    nav.ignore(grip, true)
    nav.ignore(grip, true)
    nav.ignore(nil)
    assert(env.count("MarkFrameIgnored") == 1 and env.calls[1].args[1] == grip and env.calls[1].args[2] == true, "once")
  end

  -- test_set_scroll_frame_while_registered_swaps_at_once
  do
    local env, frame, nav = setup()
    local chat, page = {}, {}
    nav.setScrollFrame(chat)
    nav.onShow()
    nav.setScrollFrame(page)
    assert(env.count("SetScrollFrameForFrame") == 2 and env.scrollFrameFor(frame) == page, "settings open: right stick → page")
    nav.setScrollFrame(chat)
    assert(env.count("SetScrollFrameForFrame") == 3 and env.scrollFrameFor(frame) == chat, "settings closed: back to the chat")
  end

  -- test_reregistration_uses_the_latest_scroll_frame
  do
    local env, frame, nav = setup()
    local chat, page = {}, {}
    nav.setScrollFrame(chat)
    nav.onShow()
    nav.setScrollFrame(page)
    nav.onHide()
    nav.onShow()
    assert(env.scrollFrameFor(frame) == page, "panel-info callback reads the latest frame")
  end

  -- test_set_scroll_frame_while_unregistered_waits_for_registration
  do
    local env, _, nav = setup()
    nav.setScrollFrame({})
    nav.setScrollFrame({})
    assert(env.count("SetScrollFrameForFrame") == 0, "no panel info yet: no call")
  end
end
