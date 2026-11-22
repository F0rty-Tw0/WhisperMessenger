local FakeUI = require("tests.helpers.fake_ui")
local Probe = require("tests.helpers.menu_popup_probe")
local BannedMenuApis = require("tests.helpers.banned_menu_apis")
local Flavor = require("tests.helpers.flavor")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local HeaderMenu = require("WhisperMessenger.UI.ConversationPane.HeaderMenu")
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")

-- On WoW: Forever the conversation header and a chat bubble's sender open
-- WM's own popup too, never a Blizzard menu.

local function noop() end

-- Runs fn on Forever with every Blizzard menu API spied on; none may be hit.
local function onForever(fn)
  Flavor.With(true, true, function()
    BannedMenuApis.With(function(calls)
      fn()
      assert(#calls == 0, "touched " .. table.concat(calls, ", "))
    end)
  end)
  MenuPopup.Close()
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
    -- test_header_right_click_opens_own_popup
    onForever(function()
      local window = factory.CreateFrame("Frame", nil, _G.UIParent)
      local header = factory.CreateFrame("Frame", nil, window)
      header:Show()
      local view = { _selectedContact = { channel = "WOW", displayName = "Arthas" } }
      HeaderMenu.Bind(header, view, { rowActions = { onMarkUnread = noop, onUpdatePrefs = noop } }, ContextMenu)
      header:GetScript("OnMouseUp")(header, "RightButton")
      assert(MenuPopup.IsShown(), "header opens WM's popup")
      assert(Probe.Labels()[1] == "title:Arthas", "titled with the contact, got " .. tostring(Probe.Labels()[1]))
      assert(Probe.Find("Mute") ~= nil, "header popup has Mute")
      assert(Probe.Find("Open chat") == nil, "header popup has no Open chat")
    end)

    -- test_group_sender_gets_block_entry
    onForever(function()
      local message = { direction = "in", channel = "CHANNEL", playerName = "Hilan-Kazzak", lineID = 42 }
      local conversation = { contact = { channel = "CHANNEL" }, rowActions = { onIgnorePlayer = noop } }
      assert(PlayerMenu.Open(message, anchor, ContextMenu, conversation) == true, "sender popup opens")
      assert(Probe.Find("Block…") ~= nil, "group sender can be blocked")
      assert(Probe.Find("Open chat") == nil, "sender popup has no Open chat")
    end)

    -- test_whisper_sender_gets_contact_popup
    onForever(function()
      local message = { direction = "in", channel = "WOW", playerName = "Arthas" }
      local conversation = { contact = { channel = "WOW", displayName = "Arthas" }, rowActions = { onUpdatePrefs = noop } }
      assert(PlayerMenu.Open(message, anchor, ContextMenu, conversation) == true, "sender popup opens")
      assert(Probe.Labels()[1] == "title:Arthas", "titled with the contact, got " .. tostring(Probe.Labels()[1]))
      assert(Probe.Find("Mute") ~= nil, "whisper sender popup has Mute")
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
