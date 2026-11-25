local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local World = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")

-- On WoW: Forever with the gamepad UI on the bubble right-click menu is WM's
-- own popup; Blizzard's menus (MenuUtil, EasyMenu, UIDropDownMenu) taint
-- from addon code there. With the mouse it is Blizzard's menu, as on Retail.

local function noReactions()
  return false
end

-- Runs fn(anchor) on Forever with the pad UI on in a popup world; no
-- Blizzard menu may be hit.
local function onForever(fn)
  Flavor.With(true, true, function()
    Flavor.WithPadUI(true, function()
      World.With(function(_factory, anchor)
        BannedMenuApis.AssertNone(function()
          fn(anchor)
        end)
      end)
    end)
  end)
end

-- Runs fn(anchor, calls) on Forever with the pad UI off in a popup world;
-- calls lists every Blizzard menu API hit.
local function onForeverMouse(fn)
  Flavor.With(true, true, function()
    Flavor.WithPadUI(false, function()
      World.With(function(_factory, anchor)
        BannedMenuApis.With(function(calls)
          fn(anchor, calls)
        end)
      end)
    end)
  end)
end

local function replyAndBlock(onReply)
  return { canReact = noReactions, onReply = onReply, onIgnoreSender = function() end }
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_forever_bubble_with_reply_and_block_opens_own_popup
  onForever(function(anchor)
    local opened = ContextMenu.Open("hello", anchor, replyAndBlock(function() end))
    assert(opened == true and MenuPopup.IsShown(), "own popup opens")
    local labels = table.concat(Probe.Labels(), ",")
    assert(labels == "button:Reply,button:Copy text,button:Block sender…", "bubble rows, got " .. labels)
  end)

  -- test_forever_reply_runs_its_handler
  onForever(function(anchor)
    local replied = 0
    ContextMenu.Open(
      "hello",
      anchor,
      replyAndBlock(function()
        replied = replied + 1
      end)
    )
    Probe.Click("Reply")
    assert(replied == 1, "Reply runs its handler")
  end)

  -- test_forever_bubble_without_handlers_opens_own_popup
  onForever(function(anchor)
    local opened = ContextMenu.Open("hello", anchor, { canReact = noReactions })
    assert(opened == true and MenuPopup.IsShown(), "own popup opens")
    local labels = table.concat(Probe.Labels(), ",")
    assert(labels == "button:Copy text", "copy only, got " .. labels)
  end)

  -- test_forever_copy_text_copies
  onForever(function(anchor)
    ManualCopyCapture.With(function(copied)
      assert(ContextMenu.Open("hello", anchor, { canReact = noReactions }) == true, "own popup opens")
      Probe.Click("Copy text")
      assert(copied.text == "hello", "Copy text copies, got " .. tostring(copied.text))
    end)
  end)

  -- test_forever_without_anchor_copies_text
  onForever(function()
    ManualCopyCapture.With(function(copied)
      assert(ContextMenu.Open("hello", nil, {}) == true, "falls back to copy")
      assert(copied.text == "hello", "copies the text, got " .. tostring(copied.text))
      assert(not MenuPopup.IsShown(), "no popup without an anchor")
    end)
  end)

  -- test_forever_mouse_bubble_with_reply_and_block_opens_menu_util
  onForeverMouse(function(anchor, calls)
    ContextMenu.Open("hello", anchor, replyAndBlock(function() end))
    assert(calls[1] == "MenuUtil.CreateContextMenu", "pad off: Blizzard's menu, got " .. tostring(calls[1]))
    assert(not MenuPopup.IsShown(), "pad off: no WM popup")
  end)

  -- test_forever_mouse_bubble_without_handlers_opens_easy_menu
  onForeverMouse(function(anchor, calls)
    ContextMenu.Open("hello", anchor, { canReact = noReactions })
    assert(calls[1] == "EasyMenu", "pad off: Blizzard's copy menu, got " .. tostring(calls[1]))
    assert(not MenuPopup.IsShown(), "pad off: no WM popup")
  end)
end
