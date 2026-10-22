local FakeUI = require("tests.helpers.fake_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local Localization = require("WhisperMessenger.Locale.Localization")

-- A bubble's right-click menu is reported to the window, so ESC closes the
-- menu before the messenger, on the Retail menu and the Classic dropdown.

local SAVED_NAMES = {
  "CreateFrame",
  "UIParent",
  "MenuUtil",
  "EasyMenu",
  "DropDownList1",
  "UIDropDownMenu_Initialize",
  "UIDropDownMenu_CreateInfo",
  "UIDropDownMenu_AddButton",
  "ToggleDropDownMenu",
  "CopyToClipboard",
  "WhisperMessengerBubbleContextMenu",
}

local function noReactions()
  return false
end

-- Runs fn(env) with no menu API; env.api(name, fn) installs one.
-- env.dropDownList stands in for Classic's DropDownList1; env.reported
-- lists the menus reported to the window.
local function withWorld(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, nil)
  end
  local factory = FakeUI.NewFactory()
  local env = { reported = {} }
  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  env.dropDownList = factory.CreateFrame("Frame", "DropDownList1", nil)
  rawset(_G, "DropDownList1", env.dropDownList)
  env.menu = factory.CreateFrame("Frame", nil, nil)
  function env.api(name, value)
    rawset(_G, name, value)
  end
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

  -- test_retail_menu_is_reported_to_the_window
  withWorld(function(env)
    env.api("MenuUtil", {
      CreateContextMenu = function()
        env.menu:Show()
        return env.menu
      end,
    })
    local opened = ContextMenu.Open("hello", nil, { canReact = noReactions, onReply = function() end })
    assert(opened == true, "precondition: the menu opens")
    assert(#env.reported == 1 and env.reported[1].frame == env.menu and env.reported[1].isGameMenu, "the bubble menu must take ESC first")
  end)

  -- test_classic_easy_menu_is_reported_to_the_window
  withWorld(function(env)
    env.api("EasyMenu", function()
      env.dropDownList:Show()
    end)
    assert(ContextMenu.Open("hello", nil, { canReact = noReactions }) == true, "precondition: the menu opens")
    assert(#env.reported == 1 and env.reported[1].frame == env.dropDownList, "the Classic menu must take ESC first")
  end)

  -- test_classic_dropdown_menu_is_reported_to_the_window
  withWorld(function(env)
    env.api("UIDropDownMenu_Initialize", function() end)
    env.api("UIDropDownMenu_CreateInfo", function()
      return {}
    end)
    env.api("UIDropDownMenu_AddButton", function() end)
    env.api("ToggleDropDownMenu", function()
      env.dropDownList:Show()
    end)
    assert(ContextMenu.Open("hello", nil, { canReact = noReactions }) == true, "precondition: the menu opens")
    assert(#env.reported == 1 and env.reported[1].frame == env.dropDownList, "the Classic dropdown must take ESC first")
  end)

  -- test_copy_fallback_reports_no_menu
  -- Some other menu may be open; it isn't the window's.
  withWorld(function(env)
    env.dropDownList:Show()
    env.api("CopyToClipboard", function() end)
    ContextMenu.Open("hello", nil, { canReact = noReactions })
    assert(#env.reported == 0, "no menu opened, nothing to report")
  end)
end
