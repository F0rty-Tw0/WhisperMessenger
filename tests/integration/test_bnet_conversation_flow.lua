local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local GroupRouter = require("WhisperMessenger.Core.Bootstrap.EventBridge.GroupRouter")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SelectionSync = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedGlobals = {
    BNGetInfo = _G.BNGetInfo,
    BNGetNumConversations = _G.BNGetNumConversations,
    BNGetConversationInfo = _G.BNGetConversationInfo,
    BNGetNumConversationMembers = _G.BNGetNumConversationMembers,
    BNGetConversationMemberInfo = _G.BNGetConversationMemberInfo,
  }
  local currentMemberID = 98765
  local conversationID = 77
  local sends = {}

  rawset(_G, "BNGetInfo", function()
    return 12345
  end)
  rawset(_G, "BNGetNumConversations", function()
    return 1
  end)
  rawset(_G, "BNGetConversationInfo", function(index)
    if index == 1 then
      return conversationID
    end
    if index == conversationID then
      return { conversationID = conversationID }
    end
    return nil
  end)
  rawset(_G, "BNGetNumConversationMembers", function()
    return 1
  end)
  rawset(_G, "BNGetConversationMemberInfo", function()
    return currentMemberID
  end)

  local runtime = RuntimeFactory.CreateRuntimeState({ conversations = {}, channelMessages = {} }, { activeConversationKey = nil }, "arthas-area52", {
    now = function()
      return 100
    end,
  })
  runtime.chatApi = {
    SendConversationMessage = function(id, text)
      sends[#sends + 1] = { id = id, text = text }
    end,
  }
  runtime.refreshWindow = function() end

  assert(
    GroupRouter.RouteGroupEvent(
      runtime,
      "CHAT_MSG_BN_CONVERSATION",
      {},
      "remote message",
      "Friend#1234",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      1,
      nil,
      98765
    ) == true,
    "remote BN conversation event should route"
  )

  local item = DataBuilder.BuildItems(runtime.store.conversations)[1]
  assert(item.conversationID == conversationID, "snapshot data must expose the routed conversation ID")
  assert(item.unreadCount == 1, "remote message should increment unread state")

  local selectedContact = {}
  SelectionSync.SyncComposerSelectedContact(selectedContact, item)
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    groupSendPolicy = GroupSendPolicy.Create({ runtime = runtime }),
    sendHandler = SendHandler,
    refreshWindow = function() end,
  })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local composer = Composer.Create(factory, parent, selectedContact, callbacks.onSend, function() end, nil)
  composer.input:SetText("reply through exact conversation")
  composer.input.scripts.OnEnterPressed(composer.input)

  assert(#sends == 1, "composer callback must invoke the BNet conversation gateway")
  assert(sends[1].id == conversationID, "gateway must receive the exact stored conversation ID")
  assert(sends[1].text == "reply through exact conversation", "gateway must receive the composer text")
  assert(composer.input.text == "", "nil gateway success should clear the draft")

  currentMemberID = 12345
  assert(
    GroupRouter.RouteGroupEvent(
      runtime,
      "CHAT_MSG_BN_CONVERSATION",
      {},
      "local echo",
      "Me#1234",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      2,
      nil,
      12345
    ) == true,
    "local BN conversation echo should route"
  )
  local conversation = runtime.store.conversations["bnconv::77"]
  assert(conversation.messages[2].direction == "out", "lazy local BNet identity must classify the local echo as outgoing")
  assert(conversation.unreadCount == 1, "local BNet echo must not increment unread state")

  rawset(_G, "BNGetInfo", savedGlobals.BNGetInfo)
  rawset(_G, "BNGetNumConversations", savedGlobals.BNGetNumConversations)
  rawset(_G, "BNGetConversationInfo", savedGlobals.BNGetConversationInfo)
  rawset(_G, "BNGetNumConversationMembers", savedGlobals.BNGetNumConversationMembers)
  rawset(_G, "BNGetConversationMemberInfo", savedGlobals.BNGetConversationMemberInfo)
end
