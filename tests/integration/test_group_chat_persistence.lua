-- Integration: party/raid chat history survives /reload and logout.
-- Writes a party message, flushes PLAYER_LOGOUT, and re-initializes
-- from the "saved" account state. Asserts the conversation is intact.

local SavedState = require("WhisperMessenger.Persistence.SavedState")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  local function simulateRelog(accountState, characterState, profileId)
    local reloaded = {
      conversations = accountState.conversations,
      channelMessages = accountState.channelMessages,
      settings = accountState.settings,
      contacts = accountState.contacts,
      pendingHydration = accountState.pendingHydration,
      schemaVersion = accountState.schemaVersion,
    }
    local reloadedAccount, reloadedCharacter = SavedState.Initialize(reloaded, characterState, profileId)
    local reloadedRuntime = RuntimeFactory.CreateRuntimeState(reloadedAccount, reloadedCharacter, profileId, {
      now = function()
        return 6000
      end,
    })
    return reloadedAccount, reloadedCharacter, reloadedRuntime
  end

  local profileId = "arthas-area52"
  local accountState, characterState = SavedState.Initialize(nil, nil, profileId)
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, profileId, {
    now = function()
      return 5000
    end,
    localPlayerGuid = "Player-1-00000042",
  })

  -- Incoming party message
  GroupChatIngest.HandleEvent(runtime, "CHAT_MSG_PARTY", {
    text = "Ready check!",
    playerName = "Jaina-Goldrinn",
    guid = "Player-1-00000099",
    lineID = 1,
  })

  local partyKey = "party::" .. profileId
  assert(accountState.conversations[partyKey] ~= nil, "party conversation should be stored before logout, got nil")
  local messageCount = #(accountState.conversations[partyKey].messages or {})
  assert(messageCount == 1, "party conversation should have 1 message, got " .. messageCount)

  -- PLAYER_LOGOUT runs before WoW serializes SavedVariables. After the
  -- persistence fix this must NOT wipe group chats.
  local savedIsInGroup = _G.IsInGroup
  _G.IsInGroup = function()
    return true
  end
  LifecycleHandlers.Handle({ runtime = runtime }, "PLAYER_LOGOUT")
  _G.IsInGroup = savedIsInGroup

  assert(accountState.conversations[partyKey] ~= nil, "party conversation must survive PLAYER_LOGOUT (persistence contract)")

  -- Simulate WoW serializing + restoring the saved variable.
  local reloadedAccount, _reloadedCharacter, reloadedRuntime = simulateRelog(accountState, characterState, profileId)

  assert(reloadedAccount.conversations[partyKey] ~= nil, "party conversation must be present after relog, got nil")
  local reloadedMessages = reloadedAccount.conversations[partyKey].messages or {}
  assert(#reloadedMessages == 1, "party conversation should retain 1 message after relog, got " .. #reloadedMessages)
  assert(reloadedMessages[1].text == "Ready check!", "party message text should round-trip, got " .. tostring(reloadedMessages[1].text))
  assert(reloadedRuntime.store.conversations[partyKey] ~= nil, "party conversation should be in runtime store after relog")
  assert(
    reloadedRuntime.store.conversations[partyKey].channel == ChannelType.PARTY,
    "party conversation should keep its PARTY channel tag through relog"
  )

  local category = _G.LE_PARTY_CATEGORY_HOME or 1
  local partyGUID = "Party-0-0000000000000077"
  local guidKey = "party::" .. profileId .. "::" .. category .. "::" .. partyGUID

  local function partyMessage(rt, text, lineID)
    GroupChatIngest.HandleEvent(rt, "CHAT_MSG_PARTY", {
      text = text,
      playerName = "Jaina-Goldrinn",
      guid = "Player-1-00000099",
      lineID = lineID,
    })
  end

  -- test_reload_without_group_joined_reuses_guid_session
  do
    local account, character = SavedState.Initialize(nil, nil, profileId)
    local rt = RuntimeFactory.CreateRuntimeState(account, character, profileId, {})
    LifecycleHandlers.Handle({ runtime = rt }, "GROUP_JOINED", {}, category, partyGUID)
    partyMessage(rt, "before reload", 10)

    -- /reload: GROUP_JOINED is not guaranteed to fire again.
    local _, _, reloadedRt = simulateRelog(account, character, profileId)
    partyMessage(reloadedRt, "after reload", 11)

    local conversation = reloadedRt.store.conversations[guidKey]
    assert(conversation ~= nil, "reload must keep writing to the same group session")
    assert(#conversation.messages == 2, "both messages should share one thread, got " .. #conversation.messages)
    assert(reloadedRt.store.conversations["party::" .. profileId] == nil, "reload must not fork a singleton party thread")
  end

  -- test_rejoining_same_guid_reopens_closed_session
  do
    local account, character = SavedState.Initialize(nil, nil, profileId)
    local rt = RuntimeFactory.CreateRuntimeState(account, character, profileId, {})
    local bootstrap = { runtime = rt }
    LifecycleHandlers.Handle(bootstrap, "GROUP_JOINED", {}, category, partyGUID)
    partyMessage(rt, "before relog", 20)

    -- Relog can report leaving and then rejoining the very same group.
    LifecycleHandlers.Handle(bootstrap, "GROUP_LEFT", {}, category, partyGUID)
    local _, _, reloadedRt = simulateRelog(account, character, profileId)
    LifecycleHandlers.Handle({ runtime = reloadedRt }, "GROUP_JOINED", {}, category, partyGUID)

    local conversation = reloadedRt.store.conversations[guidKey]
    assert(conversation.leftGroup == nil, "rejoining the same group must reopen its session")
  end
end
