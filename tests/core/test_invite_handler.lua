local Store = require("WhisperMessenger.Model.ConversationStore")
local InviteHandler = require("WhisperMessenger.Core.Bootstrap.InviteHandler")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local CONVERSATION_KEY = "wow::WOW::arthas-area52"

local function newRuntime(whispers)
  local runtime = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    now = function()
      return 100
    end,
    chatApi = {
      SendChatMessage = function(text, chatType, _, target)
        table.insert(whispers, { text = text, chatType = chatType, target = target })
      end,
      RegisterAddonMessagePrefix = function() end,
      SendAddonMessage = function() end,
    },
    bnetApi = {},
  }
  runtime.store.conversations[CONVERSATION_KEY] = {
    conversationKey = CONVERSATION_KEY,
    displayName = "Arthas-Area52",
    channel = "WOW",
    messages = {},
  }
  return runtime
end

local function newContact()
  return {
    conversationKey = CONVERSATION_KEY,
    displayName = "Arthas-Area52",
    guid = "Player-1",
    channel = "WOW",
  }
end

return function()
  local savedInCombatLockdown = _G.InCombatLockdown
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  -- test_invite_text_fits_one_whisper
  assert(#InviteHandler.INVITE_TEXT <= 255, "the invite whisper must fit WoW's 255-byte chat limit")

  -- test_invite_sends_one_whisper_and_marks_the_conversation
  do
    local whispers = {}
    local runtime = newRuntime(whispers)
    local refreshes = 0

    local accepted = InviteHandler.HandleInvite(runtime, newContact(), function()
      refreshes = refreshes + 1
    end)

    assert(accepted == true, "inviting a whisper contact should send")
    assert(#whispers == 1, "invite should send exactly one whisper, got: " .. tostring(#whispers))
    assert(whispers[1].text == InviteHandler.INVITE_TEXT, "invite whisper should carry the invite text")
    assert(whispers[1].target == "Arthas-Area52", "invite whisper should go to the selected contact")
    assert(runtime.store.conversations[CONVERSATION_KEY].inviteSent == true, "an accepted invite should be recorded on the conversation")
    assert(refreshes > 0, "an accepted invite should refresh the window")
  end

  -- test_second_invite_sends_nothing
  do
    local whispers = {}
    local runtime = newRuntime(whispers)
    local contact = newContact()

    assert(InviteHandler.HandleInvite(runtime, contact, function() end) == true, "first invite should send")
    local sentAfterFirst = #whispers

    assert(InviteHandler.HandleInvite(runtime, contact, function() end) == false, "a second invite should be refused")
    assert(#whispers == sentAfterFirst, "a second invite must not send another whisper")
  end

  -- test_group_contact_is_never_invited
  do
    local whispers = {}
    local runtime = newRuntime(whispers)
    local groupContact = { conversationKey = CONVERSATION_KEY, displayName = "Raid Group", channel = "RAID" }

    assert(InviteHandler.HandleInvite(runtime, groupContact, function() end) == false, "group conversations should not be invited")
    assert(#whispers == 0, "group invite must not send a whisper")
    assert(runtime.store.conversations[CONVERSATION_KEY].inviteSent == nil, "a refused invite must not mark the conversation")
  end

  -- test_window_callbacks_expose_invite_through_the_invite_handler
  do
    local runtime = { store = Store.New({ maxMessagesPerConversation = 10 }) }
    local received = nil
    local callbacks = WindowCallbacks.Create({
      runtime = runtime,
      inviteHandler = {
        HandleInvite = function(nextRuntime, selectedContact, refreshWindow)
          assert(nextRuntime == runtime, "invite callback should receive runtime")
          assert(type(refreshWindow) == "function", "invite callback should receive the window refresher")
          received = selectedContact
          return "invite-result"
        end,
      },
    })

    local contact = newContact()
    assert(type(callbacks.onInviteContact) == "function", "window callbacks should expose onInviteContact")
    assert(callbacks.onInviteContact(contact) == "invite-result", "invite callback should delegate to the invite handler")
    assert(received == contact, "invite callback should preserve the selected contact")
  end

  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
end
