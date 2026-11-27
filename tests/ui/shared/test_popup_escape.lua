local FakeUI = require("tests.helpers.fake_ui")
local GlobalWriteSpy = require("tests.helpers.global_write_spy")
local PopupEscape = require("WhisperMessenger.UI.Shared.PopupEscape")

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
  PopupEscape.SetGamepadPopupHooks(nil, nil)
  PopupEscape.SetEscapeFrameShownHandler(nil)
  _G.UISpecialFrames = savedSpecial
  assert(ok, err)
end

return function()
  -- test_gamepad_hooks_hear_show_and_hide
  withPopup(function(popup, seen, hooks)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PopupEscape.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    assert(#seen == 2 and seen[1][1] == "shown" and seen[1][2] == popup and seen[2][1] == "hidden" and seen[2][2] == popup, "show, then hide")
  end)

  -- test_gamepad_hooks_fire_once_though_registered_twice
  withPopup(function(popup, seen, hooks)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PopupEscape.RegisterEscape(NAME, popup)
    PopupEscape.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    assert(#seen == 2, "one hook per frame")
  end)

  -- test_hooks_set_after_registration_still_hear_the_popup
  withPopup(function(popup, seen, hooks)
    PopupEscape.RegisterEscape(NAME, popup)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    popup:Show()
    assert(#seen == 1 and seen[1][1] == "shown", "popups built before the window still report")
  end)

  -- test_popup_registered_by_name_only_reports_nothing
  withPopup(function(popup, seen, hooks)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PopupEscape.RegisterEscape(NAME)
    popup:Show()
    popup:Hide()
    assert(#seen == 0, "no frame given: no hook")
  end)

  -- test_escape_handler_unchanged_with_both_listeners
  withPopup(function(popup, seen, hooks)
    local escape = {}
    PopupEscape.SetEscapeFrameShownHandler(function(shown, isGameMenu)
      table.insert(escape, { shown, isGameMenu })
    end)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PopupEscape.RegisterEscape(NAME, popup)
    popup:Show()
    popup:Hide()
    local menu = {}
    PopupEscape.ReportMenuShown(menu)
    assert(#escape == 2 and escape[1][1] == popup and escape[1][2] == nil, "ESC handler gets the popup once, on show")
    assert(escape[2][1] == menu and escape[2][2] == true, "and the game menu, as before")
    assert(#seen == 2, "game menus never reach the gamepad hooks: FCM focuses them itself")
  end)

  -- test_cleared_hooks_hear_nothing
  withPopup(function(popup, seen, hooks)
    PopupEscape.SetGamepadPopupHooks(hooks.shown, hooks.hidden)
    PopupEscape.RegisterEscape(NAME, popup)
    PopupEscape.SetGamepadPopupHooks(nil, nil)
    popup:Show()
    popup:Hide()
    assert(#seen == 0, "cleared")
  end)

  -- test_register_escape_does_not_reassign_existing_ui_special_frames
  do
    local writes, special = GlobalWriteSpy.Writes("UISpecialFrames", function()
      PopupEscape.RegisterEscape(NAME)
    end)
    assert(writes == 0, "the game's UISpecialFrames is never reassigned")
    assert(special[1] == NAME, "the name still goes into it")
  end

  -- test_register_escape_lists_the_popup_once
  withPopup(function()
    PopupEscape.RegisterEscape(NAME)
    PopupEscape.RegisterEscape(NAME)
    assert(#_G.UISpecialFrames == 1 and _G.UISpecialFrames[1] == NAME, "popup must close on ESC, listed once")
  end)

  -- test_shown_popup_is_reported_once
  -- The messenger window leaves the ESC list while its popup is open, so
  -- ESC closes only the popup.
  withPopup(function(popup)
    local reported = {}
    PopupEscape.SetEscapeFrameShownHandler(function(shown)
      table.insert(reported, shown)
    end)
    PopupEscape.RegisterEscape(NAME, popup)
    PopupEscape.RegisterEscape(NAME, popup)
    popup:Show()
    assert(#reported == 1 and reported[1] == popup, "an opened popup must be reported once")
  end)

  -- Game menus the window opens (MenuUtil, UnitPopup, dropdowns) close on
  -- ESC first too; they are reported as menus.
  local function reportMenu(menu, gameApi)
    local reported = {}
    local saved = {}
    for name, value in pairs(gameApi) do
      saved[name] = rawget(_G, name)
      rawset(_G, name, value)
    end
    PopupEscape.SetEscapeFrameShownHandler(function(shown, isGameMenu)
      table.insert(reported, { frame = shown, isGameMenu = isGameMenu })
    end)
    local ok, err = pcall(PopupEscape.ReportMenuShown, menu)
    PopupEscape.SetEscapeFrameShownHandler(nil)
    for name in pairs(gameApi) do
      rawset(_G, name, saved[name])
    end
    assert(ok, err)
    return reported
  end

  -- test_reported_menu_frame_is_reported_as_a_menu
  do
    local menu = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    local reported = reportMenu(menu, {})
    assert(#reported == 1 and reported[1].frame == menu and reported[1].isGameMenu == true, "the given menu must be reported as a menu")
  end

  -- test_open_game_menu_is_found_when_not_given
  do
    local menu = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    local manager = {
      GetOpenMenu = function()
        return menu
      end,
    }
    local reported = reportMenu(nil, {
      Menu = {
        GetManager = function()
          return manager
        end,
      },
    })
    assert(#reported == 1 and reported[1].frame == menu, "the open game menu must be reported")
  end

  -- test_open_classic_dropdown_list_is_found
  do
    local list = FakeUI.NewFactory().CreateFrame("Frame", "DropDownList1", nil)
    list:Show()
    local reported = reportMenu(nil, { DropDownList1 = list })
    assert(#reported == 1 and reported[1].frame == list, "an open Classic dropdown list must be reported")
  end

  -- test_nothing_reported_without_an_open_menu
  do
    local list = FakeUI.NewFactory().CreateFrame("Frame", "DropDownList1", nil)
    local reported = reportMenu(nil, { DropDownList1 = list })
    assert(#reported == 0, "no open menu, nothing to report")
  end

  -- test_hide_shown_escape_frame_hides_the_most_recent_popup
  withPopup(function(popup)
    while PopupEscape.HideShownEscapeFrame() do
    end -- popups earlier tests left shown stay registered (module state)
    local other = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerTestPicker2", nil)
    PopupEscape.RegisterEscape(NAME, popup)
    PopupEscape.RegisterEscape("WhisperMessengerTestPicker2", other)
    other:Show()
    popup:Show()
    assert(PopupEscape.HideShownEscapeFrame() == true, "a shown popup was hidden")
    assert(not popup:IsShown() and other:IsShown(), "the most recently shown popup goes first")
    assert(PopupEscape.HideShownEscapeFrame() == true and not other:IsShown(), "then the next one")
  end)

  -- test_hide_shown_escape_frame_returns_false_with_none_shown
  withPopup(function(popup)
    while PopupEscape.HideShownEscapeFrame() do
    end
    PopupEscape.RegisterEscape(NAME, popup)
    assert(not popup:IsShown(), "fake frames start hidden")
    assert(PopupEscape.HideShownEscapeFrame() == false, "nothing shown, nothing hidden")
  end)
end
