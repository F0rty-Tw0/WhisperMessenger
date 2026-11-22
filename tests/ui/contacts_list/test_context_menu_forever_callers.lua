local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local World = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local HeaderMenu = require("WhisperMessenger.UI.ConversationPane.HeaderMenu")
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")

-- On WoW: Forever the conversation header and a chat bubble's sender open
-- WM's own popup too, never a Blizzard menu.

local function noop() end

-- Runs fn(factory, anchor) on Forever in a popup world with every Blizzard
-- menu API spied on; none may be hit.
local function onForever(fn)
  Flavor.With(true, true, function()
    World.With(function(factory, anchor)
      BannedMenuApis.AssertNone(function()
        fn(factory, anchor)
      end)
    end)
  end)
end

-- A right-click on a shown conversation header bound to a whisper with Arthas.
local function rightClickHeader(factory)
  local window = factory.CreateFrame("Frame", nil, _G.UIParent)
  local header = factory.CreateFrame("Frame", nil, window)
  header:Show()
  local view = { _selectedContact = { channel = "WOW", displayName = "Arthas" } }
  HeaderMenu.Bind(header, view, { rowActions = { onMarkUnread = noop, onUpdatePrefs = noop } }, ContextMenu)
  header:GetScript("OnMouseUp")(header, "RightButton")
end

-- Runs fn() with GetCursorPosition answering x, y.
local function withCursor(x, y, fn)
  local saved = rawget(_G, "GetCursorPosition")
  rawset(_G, "GetCursorPosition", function()
    return x, y
  end)
  local ok, err = pcall(fn)
  rawset(_G, "GetCursorPosition", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  Localization.Configure({ language = "enUS" })
  -- test_header_right_click_opens_own_popup
  onForever(function(factory)
    rightClickHeader(factory)
    assert(MenuPopup.IsShown(), "header opens WM's popup")
    assert(Probe.Labels()[1] == "title:Arthas", "titled with the contact, got " .. tostring(Probe.Labels()[1]))
    assert(Probe.Find("Mute") ~= nil, "header popup has Mute")
    assert(Probe.Find("Open chat") == nil, "header popup has no Open chat")
  end)

  -- test_header_popup_opens_at_the_cursor
  withCursor(300, 500, function()
    onForever(function(factory)
      rightClickHeader(factory)
      local _, relativeTo, _, x, y = MenuPopup.GetFrame():GetPoint(1)
      assert(relativeTo == _G.UIParent and x == 300 and y == 500, "at the cursor, not beside the pane-wide header")
    end)
  end)

  -- test_group_sender_gets_block_entry
  onForever(function(_factory, anchor)
    local message = { direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak", lineID = 42 }
    local conversation = { contact = { channel = "CHANNEL" }, rowActions = { onIgnorePlayer = noop } }
    assert(PlayerMenu.Open(message, anchor, ContextMenu, conversation) == true, "sender popup opens")
    assert(Probe.Find("Block…") ~= nil, "group sender can be blocked")
    assert(Probe.Find("Open chat") == nil, "sender popup has no Open chat")
  end)

  -- test_whisper_sender_gets_contact_popup
  onForever(function(_factory, anchor)
    local message = { direction = "in", channel = "WOW", playerName = "Arthas" }
    local conversation = { contact = { channel = "WOW", displayName = "Arthas" }, rowActions = { onUpdatePrefs = noop } }
    assert(PlayerMenu.Open(message, anchor, ContextMenu, conversation) == true, "sender popup opens")
    assert(Probe.Labels()[1] == "title:Arthas", "titled with the contact, got " .. tostring(Probe.Labels()[1]))
    assert(Probe.Find("Mute") ~= nil, "whisper sender popup has Mute")
  end)
end
