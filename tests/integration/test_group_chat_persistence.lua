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
    local reloadedAccount, reloadedCharacter =
      SavedState.Initialize(reloaded, characterState, profileId)
    local reloadedRuntime = RuntimeFactory.CreateRuntimeState(
      reloadedAccount,
      reloadedCharacter,
      profileId,
      { now = function()
        return 6000
      end }
    )
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
  assert(
    accountState.conversations[partyKey] ~= nil,
    "party conversation should be stored before logout, got nil"
  )
  local messageCount = #(accountState.conversations[partyKey].messages or {})
  assert(messageCount == 1, "party conversation should have 1 message, got " .. messageCount)

  -- PLAYER_LOGOUT runs before WoW serializes SavedVariables. After the
  -- persistence fix this must NOT wipe group chats.
  local savedIsInGroup = _G.IsInGroup
  _G.IsInGroup = function()
    return true
  end
  LifecycleHandlers.Handle({ runtime = runtime }, "PLAYER_LOGOUT", {
    trace = function() end,
    getContentDetector = function()
      return nil
    end,
    getPresenceCache = function()
      return nil
    end,
    loadModule = function()
      return nil
    end,
  })
  _G.IsInGroup = savedIsInGroup

  assert(
    accountState.conversations[partyKey] ~= nil,
    "party conversation must survive PLAYER_LOGOUT (persistence contract)"
  )

  -- Simulate WoW serializing + restoring the saved variable.
  local reloadedAccount, _reloadedCharacter, reloadedRuntime = simulateRelog(accountState, characterState, profileId)

  assert(
    reloadedAccount.conversations[partyKey] ~= nil,
    "party conversation must be present after relog, got nil"
  )
  local reloadedMessages = reloadedAccount.conversations[partyKey].messages or {}
  assert(
    #reloadedMessages == 1,
    "party conversation should retain 1 message after relog, got " .. #reloadedMessages
  )
  assert(
    reloadedMessages[1].text == "Ready check!",
    "party message text should round-trip, got " .. tostring(reloadedMessages[1].text)
  )
  assert(
    reloadedRuntime.store.conversations[partyKey] ~= nil,
    "party conversation should be in runtime store after relog"
  )
  assert(
    reloadedRuntime.store.conversations[partyKey].channel == ChannelType.PARTY,
    "party conversation should keep its PARTY channel tag through relog"
  )
end
