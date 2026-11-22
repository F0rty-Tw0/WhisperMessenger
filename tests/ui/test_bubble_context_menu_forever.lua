local FakeUI = require("tests.helpers.fake_ui")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")

-- On WoW: Forever the bubble right-click menu is WM's own popup; Blizzard's
-- menus (MenuUtil, EasyMenu, UIDropDownMenu) taint from addon code there.

local function noReactions()
  return false
end

return function()
  local factory = FakeUI.NewFactory()
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, rawget(_G, "CreateFrame"), _G.UISpecialFrames
  Localization.Configure({ language = "enUS" })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  anchor:Show()

  local ok, err = pcall(function()
    -- test_forever_bubble_with_reply_and_block_opens_own_popup
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        local replied = 0
        local opened = ContextMenu.Open("hello", anchor, {
          canReact = noReactions,
          onReply = function()
            replied = replied + 1
          end,
          onIgnoreSender = function() end,
        })
        assert(opened == true and MenuPopup.IsShown(), "own popup opens")
        local labels = table.concat(Probe.Labels(), ",")
        assert(labels == "button:Reply,button:Copy text,button:Block sender…", "bubble rows, got " .. labels)
        Probe.Click("Reply")
        assert(replied == 1, "Reply runs its handler")
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_forever_bubble_without_handlers_opens_own_popup
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        local opened = ContextMenu.Open("hello", anchor, { canReact = noReactions })
        assert(opened == true and MenuPopup.IsShown(), "own popup opens")
        local labels = table.concat(Probe.Labels(), ",")
        assert(labels == "button:Copy text", "copy only, got " .. labels)
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_forever_copy_text_copies
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        ManualCopyCapture.With(function(copied)
          assert(ContextMenu.Open("hello", anchor, { canReact = noReactions }) == true, "own popup opens")
          Probe.Click("Copy text")
          assert(copied.text == "hello", "Copy text copies, got " .. tostring(copied.text))
        end)
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
    MenuPopup.Close()

    -- test_forever_without_anchor_copies_text
    Flavor.With(true, true, function()
      BannedMenuApis.With(function(calls)
        ManualCopyCapture.With(function(copied)
          assert(ContextMenu.Open("hello", nil, {}) == true, "falls back to copy")
          assert(copied.text == "hello", "copies the text, got " .. tostring(copied.text))
          assert(not MenuPopup.IsShown(), "no popup without an anchor")
        end)
        assert(#calls == 0, "touched " .. table.concat(calls, ", "))
      end)
    end)
  end)

  MenuPopup.Close()
  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
  if not ok then
    error(err, 0)
  end
end
