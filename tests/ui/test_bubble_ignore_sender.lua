local FakeUI = require("tests.helpers.fake_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")

-- Right-clicking a message in a channel or group chat offers "Ignore
-- sender…" for other players' lines; never for your own lines and never in
-- whisper chats (the contact row menu covers those).

local function stubMenuUtil()
  local menu = { buttons = {} }
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function(owner, generator)
      generator(owner, {
        CreateButton = function(_, text, callback)
          menu.buttons[#menu.buttons + 1] = { text = text, callback = callback }
        end,
      })
    end,
  })
  return menu
end

local function menuButton(menu, text)
  for _, button in ipairs(menu.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function stubPopup(typed)
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name)
    _G.StaticPopupDialogs[name].OnAccept({
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    })
  end)
end

-- Transcript bound to a conversation with `channel`; returns the bubble
-- options a transcript hands to its bubbles.
local function bindTranscript(channel, onIgnorePlayer)
  local transcript = {}
  local view = { _selectedContact = { channel = channel } }
  TranscriptSetup.BindPlayerMenu(transcript, view, { onIgnorePlayer = onIgnorePlayer })
  return { onIgnoreSender = transcript.onIgnoreSender, canIgnoreSender = transcript.canIgnoreSender }
end

local function rightClick(factory, parent, message, bubbleOptions)
  bubbleOptions.persistentFactory = factory
  local bubble = BubbleFrame.CreateBubble(factory, parent, message, bubbleOptions)
  bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  local parent = factory.CreateFrame("Frame", nil, _G.UIParent)

  local incoming = { direction = "in", kind = "user", text = "wts boost", playerName = "Spammer-Realm", channel = "CHANNEL" }
  local outgoing = { direction = "out", kind = "user", text = "lfg", playerName = "Me-Realm", channel = "CHANNEL" }

  local ignored = {}
  local function onIgnorePlayer(name, reason)
    ignored[#ignored + 1] = { name = name, reason = reason }
  end

  -- test_incoming_channel_message_offers_ignore_sender
  do
    local menu = stubMenuUtil()
    rightClick(factory, parent, incoming, bindTranscript("CHANNEL", onIgnorePlayer))
    local ignore = menuButton(menu, "Block sender…")
    assert(ignore ~= nil, "incoming channel line offers Block sender…")

    -- test_accepting_ignores_the_sender_with_the_reason
    stubPopup("gold spam")
    ignore.callback()
    assert(ignored[1] and ignored[1].name == "Spammer-Realm", "sender ignored")
    assert(ignored[1].reason == "gold spam", "reason passed on")
    rawset(_G, "StaticPopup_Show", nil)
  end

  -- test_outgoing_message_has_no_ignore_sender
  do
    local menu = stubMenuUtil()
    rightClick(factory, parent, outgoing, bindTranscript("CHANNEL", onIgnorePlayer))
    assert(menuButton(menu, "Block sender…") == nil, "own lines cannot be ignored")
  end

  -- test_whisper_conversation_has_no_ignore_sender
  do
    local menu = stubMenuUtil()
    rightClick(factory, parent, { direction = "in", kind = "user", text = "hi", playerName = "Jaina-Realm" }, bindTranscript("WOW", onIgnorePlayer))
    assert(menuButton(menu, "Block sender…") == nil, "whisper chats use the contact menu instead")
  end

  -- test_bnet_conversation_has_no_ignore_sender
  do
    local menu = stubMenuUtil()
    local line = { direction = "in", kind = "user", text = "hi", playerName = "Jaina-Realm", channel = "BN_CONVERSATION" }
    rightClick(factory, parent, line, bindTranscript("BN_CONVERSATION", onIgnorePlayer))
    assert(menuButton(menu, "Block sender…") == nil, "Battle.net conversation senders are not characters")
  end

  -- test_bnet_token_sender_has_no_ignore_sender
  do
    local menu = stubMenuUtil()
    local line = { direction = "in", kind = "user", text = "hi", playerName = "|Kq12|k", channel = "GUILD" }
    rightClick(factory, parent, line, bindTranscript("GUILD", onIgnorePlayer))
    assert(menuButton(menu, "Block sender…") == nil, "a Battle.net name token is not a character name")
  end

  -- test_sender_name_menu_gets_the_ignore_handler
  do
    local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")
    local realOpen, passed = PlayerMenu.Open, nil
    rawset(PlayerMenu, "Open", function(_message, _anchor, _contextMenu, conversation)
      passed = conversation
      return true
    end)
    local transcript = {}
    TranscriptSetup.BindPlayerMenu(transcript, { _selectedContact = { channel = "CHANNEL" } }, { onIgnorePlayer = onIgnorePlayer })
    transcript.openPlayerMenu(incoming, parent)
    rawset(PlayerMenu, "Open", realOpen)
    assert(passed and passed.onIgnorePlayer == onIgnorePlayer, "the name menu can offer our Ignore…")
  end

  rawset(_G, "MenuUtil", nil)
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
  _G.UIParent = savedUIParent
end
