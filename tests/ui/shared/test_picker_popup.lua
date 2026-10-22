local FakeUI = require("tests.helpers.fake_ui")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

local NAME = "WhisperMessengerTestPicker"

-- Runs fn(popup) with a fresh UISpecialFrames and a popup frame under NAME.
local function withPopup(fn)
  local savedSpecial, savedPopup = _G.UISpecialFrames, _G[NAME]
  _G.UISpecialFrames = {}
  local popup = FakeUI.NewFactory().CreateFrame("Frame", NAME, nil)
  rawset(_G, NAME, popup)
  local ok, err = pcall(fn, popup)
  PickerPopup.SetEscapeFrameShownHandler(nil)
  _G.UISpecialFrames = savedSpecial
  rawset(_G, NAME, savedPopup)
  assert(ok, err)
end

return function()
  -- test_register_escape_lists_the_popup_once
  withPopup(function()
    PickerPopup.RegisterEscape(NAME)
    PickerPopup.RegisterEscape(NAME)
    assert(#_G.UISpecialFrames == 1 and _G.UISpecialFrames[1] == NAME, "popup must close on ESC, listed once")
  end)

  -- test_shown_popup_is_reported_once
  -- The messenger window leaves the ESC list while its popup is open, so
  -- ESC closes only the popup.
  withPopup(function(popup)
    local reported = {}
    PickerPopup.SetEscapeFrameShownHandler(function(shown)
      table.insert(reported, shown)
    end)
    PickerPopup.RegisterEscape(NAME, popup)
    PickerPopup.RegisterEscape(NAME, popup)
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
    PickerPopup.SetEscapeFrameShownHandler(function(shown, isGameMenu)
      table.insert(reported, { frame = shown, isGameMenu = isGameMenu })
    end)
    local ok, err = pcall(PickerPopup.ReportMenuShown, menu)
    PickerPopup.SetEscapeFrameShownHandler(nil)
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
end
