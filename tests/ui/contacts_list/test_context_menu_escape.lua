local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- A contact's right-click menu is reported to the window, so ESC closes the
-- menu before the messenger.

local SAVED_NAMES = { "Menu", "MenuUtil", "UnitPopup_OpenMenu" }

-- Runs fn(env) with the game's menu API stubbed: opening a menu shows
-- env.menu, the frame Menu.GetManager():GetOpenMenu() returns while shown.
-- env.reported lists the menus reported to the window.
local function withMenus(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local env = { reported = {}, anchor = factory.CreateFrame("Button", nil, nil) }
  env.menu = factory.CreateFrame("Frame", nil, nil)
  local manager = {
    GetOpenMenu = function()
      return env.menu:IsShown() and env.menu or nil
    end,
  }
  rawset(_G, "Menu", {
    ModifyMenu = function() end,
    GetManager = function()
      return manager
    end,
  })
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function()
      env.menu:Show()
      return env.menu
    end,
  })
  rawset(_G, "UnitPopup_OpenMenu", function()
    env.menu:Show()
  end)
  PickerPopup.SetEscapeFrameShownHandler(function(shown, isGameMenu)
    table.insert(env.reported, { frame = shown, isGameMenu = isGameMenu })
  end)
  local ok, err = pcall(fn, env)
  PickerPopup.SetEscapeFrameShownHandler(nil)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_player_menu_is_reported_to_the_window
  withMenus(function(env)
    assert(ContextMenu.Open({ channel = "WOW", displayName = "Arthas-Area52" }, env.anchor) == true, "precondition: the player menu opens")
    assert(#env.reported == 1 and env.reported[1].frame == env.menu and env.reported[1].isGameMenu, "the player menu must take ESC first")
  end)

  -- test_group_menu_is_reported_to_the_window
  withMenus(function(env)
    assert(ContextMenu.Open({ channel = "GUILD", displayName = "Guild" }, env.anchor) == true, "precondition: the group menu opens")
    assert(#env.reported == 1 and env.reported[1].frame == env.menu, "the group menu must take ESC first")
  end)

  -- test_menu_that_did_not_open_is_not_reported
  -- Some other menu may be open; it isn't the window's.
  withMenus(function(env)
    env.menu:Show()
    assert(ContextMenu.Open({ channel = "WOW" }, env.anchor) == false, "precondition: no name, no menu")
    assert(#env.reported == 0, "nothing opened, nothing to report")
  end)
end
