local FakeUI = require("tests.helpers.fake_ui")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

local NAME = "WhisperMessengerTestGamepadPopup"

-- Runs fn(popup, seen, hooks) with a fresh UISpecialFrames; clears every listener after.
local function withPopup(fn)
  local savedSpecial = _G.UISpecialFrames
  _G.UISpecialFrames = {}
  local popup = FakeUI.NewFactory().CreateFrame("Frame", NAME, nil)
  local seen = {}
  local hooks = {
    shown = function(p)
      table.insert(seen, { "shown", p })
    end,
    hidden = function(p)
      table.insert(seen, { "hidden", p })
    end,
  }
  local ok, err = pcall(fn, popup, seen, hooks)
  PickerPopup.SetGamepadPopupHooks(nil, nil)
  PickerPopup.SetEscapeFrameShownHandler(nil)
  _G.UISpecialFrames = savedSpecial
  assert(ok, err)
end

return function()
  -- test_gamepad_hooks_hear_show_and_hide
  withPopup(function(popup, seen, hooks)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PickerPopup.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    assert(#seen == 2 and seen[1][1] == "shown" and seen[1][2] == popup and seen[2][1] == "hidden" and seen[2][2] == popup, "show, then hide")
  end)

  -- test_gamepad_hooks_fire_once_though_registered_twice
  withPopup(function(popup, seen, hooks)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PickerPopup.RegisterEscape(NAME, popup)
    PickerPopup.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    assert(#seen == 2, "one hook per frame")
  end)

  -- test_hooks_set_after_registration_still_hear_the_popup
  withPopup(function(popup, seen, hooks)
    PickerPopup.RegisterEscape(NAME, popup)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    popup:Show()
    assert(#seen == 1 and seen[1][1] == "shown", "popups built before the window still report")
  end)

  -- test_popup_registered_by_name_only_reports_nothing
  withPopup(function(popup, seen, hooks)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PickerPopup.RegisterEscape(NAME)
    popup:Show()
    popup:Hide()
    assert(#seen == 0, "no frame given: no hook")
  end)

  -- test_escape_handler_unchanged_with_both_listeners
  withPopup(function(popup, seen, hooks)
    local escape = {}
    PickerPopup.SetEscapeFrameShownHandler(function(shown, isGameMenu)
      table.insert(escape, { shown, isGameMenu })
    end)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PickerPopup.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    local menu = {}
    PickerPopup.ReportMenuShown(menu)
    assert(#escape == 2 and escape[1][1] == popup and escape[1][2] == nil, "ESC handler gets the popup once, on show")
    assert(escape[2][1] == menu and escape[2][2] == true, "and the game menu, as before")
    assert(#seen == 2, "game menus never reach the gamepad hooks: FCM focuses them itself")
  end)

  -- test_cleared_hooks_hear_nothing
  withPopup(function(popup, seen, hooks)
    PickerPopup.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PickerPopup.RegisterEscape(NAME, popup)
    PickerPopup.SetGamepadPopupHooks(nil, nil)
    popup:Show()
    popup:Hide()
    assert(#seen == 0, "cleared")
  end)
end
