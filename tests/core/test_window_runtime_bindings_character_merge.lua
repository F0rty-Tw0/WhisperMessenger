local Bootstrap = require("WhisperMessenger.Bootstrap")
local CharacterMergeFold = require("WhisperMessenger.Model.CharacterMergeFold")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local FakeUI = require("tests.helpers.fake_ui")
local World = require("tests.helpers.character_merge_world")

-- A character's chat that folds into their Battle.net friend's chat while it
-- is open hands the window over to the friend's chat: the list drops the
-- character row and a reply goes out over Battle.net.
local K = World.K
local B = World.B
local OTHER = "wow::WOW::thrall-area52"

local function conversations(withCharacterRecord)
  local list = {
    [B] = {
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      channel = "BN",
      unreadCount = 0,
      unreadActivityCount = 0,
      lastActivityAt = 100,
      lastPreview = "from the app",
      messages = { { id = "b1", direction = "in", kind = "user", text = "from the app", sentAt = 100, playerName = "Jaina#1234" } },
    },
  }
  list[OTHER] = {
    displayName = "Thrall-Area52",
    channel = "WOW",
    unreadCount = 0,
    unreadActivityCount = 0,
    lastActivityAt = 50,
    lastPreview = "lok'tar",
    messages = { { id = "o1", direction = "in", kind = "user", text = "lok'tar", sentAt = 50, playerName = "Thrall-Area52", channel = "WOW" } },
  }
  if withCharacterRecord then
    list[K] = {
      displayName = World.NAME,
      channel = "WOW",
      guid = "Player-1-ARTHAS",
      unreadCount = 1,
      unreadActivityCount = 0,
      lastActivityAt = 200,
      lastPreview = "from the character",
      messages = {
        { id = "k1", direction = "in", kind = "user", text = "from the character", sentAt = 200, playerName = World.NAME, channel = "WOW" },
      },
    }
  end
  return list
end

local function boot(withCharacterRecord, openKey)
  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  return Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, settings = {}, conversations = conversations(withCharacterRecord) },
    characterState = { activeConversationKey = openKey, window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
end

-- Opening the window jumps to an unread chat, so the character's line is
-- read first: the saved open chat is the one that shows.
local function openWithoutJumping(runtime)
  runtime.store.conversations[K].unreadCount = 0
  runtime.toggle()
end

-- Stands in for the router's fold, then its callback.
local function fold(runtime)
  CharacterMergeFold.Fold(runtime.store, runtime.characterMerges, K, B, nil, World.NAME, 200)
  assert(type(runtime.onCharacterMerged) == "function", "the router has a merge callback to call")
  runtime.onCharacterMerged(K, B)
end

local function sendFromComposer(runtime)
  local sent = {}
  local savedHandleSend = SendHandler.HandleSend
  SendHandler.HandleSend = function(_runtime, payload)
    sent[#sent + 1] = payload
    return true
  end
  runtime.window.composer.input:SetText("hello")
  runtime.window.composer.sendButton.scripts.OnClick()
  SendHandler.HandleSend = savedHandleSend
  return sent[1]
end

local function shownRows(runtime)
  local items = {}
  for _, row in ipairs(runtime.window.contacts.rows) do
    if row.item ~= nil and row:IsShown() then
      items[row.item.conversationKey] = row.item
    end
  end
  return items
end

return function()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList

  -- test_reply_from_the_merged_chat_goes_over_battle_net
  do
    local runtime = boot(true, K)
    runtime.toggle()
    fold(runtime)
    local payload = sendFromComposer(runtime)
    assert(payload ~= nil, "the composer sends")
    assert(payload.conversationKey == B, "the reply is filed in the friend's chat, got " .. tostring(payload.conversationKey))
    assert(payload.channel == "BN" and payload.bnetAccountID == 77, "the reply goes over Battle.net, got " .. tostring(payload.channel))
  end

  -- test_contact_list_drops_the_character_row
  do
    local runtime = boot(true, K)
    runtime.toggle()
    fold(runtime)
    local items = shownRows(runtime)
    assert(items[K] == nil, "no character row is left")
    assert(items[B] ~= nil and items[B].lastPreview == "from the character", "the friend's row shows the character's newest line")
  end

  -- test_open_character_chat_with_no_record_hands_over
  do
    local runtime = boot(false, K)
    runtime.toggle()
    fold(runtime)
    local payload = sendFromComposer(runtime)
    assert(
      payload ~= nil and payload.conversationKey == B and payload.channel == "BN",
      "the friend's chat opens in place of the unsaved character chat"
    )
  end

  -- test_merge_while_the_friend_chat_is_open_keeps_it_open
  do
    local runtime = boot(true, B)
    openWithoutJumping(runtime)
    assert(runtime.activeConversationKey == B, "precondition: the friend's chat is the open chat")
    fold(runtime)
    assert(runtime.activeConversationKey == B, "the friend's chat stays open")
    assert(shownRows(runtime)[K] == nil, "the character row goes")
  end

  -- test_merge_while_another_chat_is_open_keeps_that_chat_open
  do
    local runtime = boot(true, OTHER)
    openWithoutJumping(runtime)
    assert(runtime.activeConversationKey == OTHER, "precondition: another chat is the open chat")
    fold(runtime)
    assert(runtime.activeConversationKey == OTHER, "the other chat stays open")
    local items = shownRows(runtime)
    assert(items[K] == nil and items[B] ~= nil, "the character row folds into the friend's row")
  end

  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
end
