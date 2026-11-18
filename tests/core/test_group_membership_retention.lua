local SavedState = require("WhisperMessenger.Persistence.SavedState")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- Leaving a group writes a "Left party" line, but leaving and rejoining is not
-- chat: a group chat ages out from its last real message, like a whisper.
return function()
  local savedTime = _G.time
  local savedDate = _G.date
  local savedIsInGroup = _G.IsInGroup
  local savedIsInRaid = _G.IsInRaid
  local savedLE_HOME = _G.LE_PARTY_CATEGORY_HOME
  local savedLE_INSTANCE = _G.LE_PARTY_CATEGORY_INSTANCE
  _G.date = _G.date or os.date
  _G.LE_PARTY_CATEGORY_HOME = 1
  _G.LE_PARTY_CATEGORY_INSTANCE = 2

  local HOUR = 3600
  local PROFILE_ID = "arthas-area52"
  local PARTY_GUID = "Party-1-0000000000000001"
  local CATEGORY = 1
  local PARTY_KEY = "party::" .. PROFILE_ID .. "::" .. CATEGORY .. "::" .. PARTY_GUID
  local LEGACY_PARTY_KEY = "party::" .. PROFILE_ID

  local clock = 1000000
  rawset(_G, "time", function()
    return clock
  end)

  local function makeBootstrap(options)
    local accountState, characterState = SavedState.Initialize(nil, nil, PROFILE_ID)
    local runtimeOptions = {
      now = function()
        return clock
      end,
      localPlayerGuid = "Player-1-42",
    }
    for field, value in pairs(options or {}) do
      runtimeOptions[field] = value
    end
    local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, PROFILE_ID, runtimeOptions)
    return { runtime = runtime }
  end

  local function partyChat(runtime, text, lineID)
    GroupChatIngest.HandleEvent(runtime, "CHAT_MSG_PARTY", {
      text = text,
      playerName = "Thrall-Area52",
      guid = "Player-1-77",
      lineID = lineID,
    })
  end

  -- test_rejoin_and_leave_do_not_keep_group_chat_past_retention
  do
    local Bootstrap = makeBootstrap()
    local runtime = Bootstrap.runtime
    local start = clock

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", {}, CATEGORY, PARTY_GUID)
    partyChat(runtime, "pull at 5", 1)
    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", {}, CATEGORY, PARTY_GUID)

    -- Relog reports GROUP_LEFT then GROUP_JOINED for the same party GUID.
    clock = start + 23 * HOUR
    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", {}, CATEGORY, PARTY_GUID)
    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", {}, CATEGORY, PARTY_GUID)

    clock = start + 25 * HOUR
    Store.ApplyRetention(runtime.store, clock)

    assert(runtime.store.conversations[PARTY_KEY] == nil, "party chat idle for 25h must expire under the 24h limit despite leave/rejoin")
  end

  -- test_left_line_keeps_last_activity_and_shows_in_preview
  do
    local Bootstrap = makeBootstrap()
    local runtime = Bootstrap.runtime
    local chatAt = clock

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", {}, CATEGORY, PARTY_GUID)
    partyChat(runtime, "gg", 2)
    clock = chatAt + HOUR
    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", {}, CATEGORY, PARTY_GUID)

    local conversation = runtime.store.conversations[PARTY_KEY]
    local messages = conversation.messages
    assert(messages[#messages].kind == "system", "the Left line is still recorded")
    assert(conversation.lastActivityAt == chatAt, "leaving must not count as activity, got " .. tostring(conversation.lastActivityAt))
    assert(conversation.lastPreview == messages[#messages].text, "the row preview shows the Left line")
  end

  -- test_left_line_counts_against_message_cap
  do
    local Bootstrap = makeBootstrap({ maxMessagesPerConversation = 2 })
    local runtime = Bootstrap.runtime

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", {}, CATEGORY, PARTY_GUID)
    partyChat(runtime, "one", 3)
    partyChat(runtime, "two", 4)
    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", {}, CATEGORY, PARTY_GUID)

    local messages = runtime.store.conversations[PARTY_KEY].messages
    assert(#messages == 2, "the Left line must count against the per-chat cap, got " .. #messages)
    assert(messages[1].text == "two", "the oldest line makes room for the Left line")
  end

  -- test_left_line_sets_message_age_boundary
  do
    local Bootstrap = makeBootstrap()
    local runtime = Bootstrap.runtime
    local store = runtime.store

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", {}, CATEGORY, PARTY_GUID)
    partyChat(runtime, "old", 5)
    clock = clock + 25 * HOUR
    -- The chat is still recent but all its lines aged out, so no message-age
    -- boundary is pending.
    store.conversations[PARTY_KEY].lastActivityAt = clock
    Store.ApplyRetention(store, clock)
    assert(#store.conversations[PARTY_KEY].messages == 0, "the old line aged out")
    assert(store.messageRetentionAt[PARTY_KEY] == math.huge, "no line, no boundary")

    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", {}, CATEGORY, PARTY_GUID)

    assert(
      store.messageRetentionAt[PARTY_KEY] == clock + 86400,
      "the Left line must schedule its own expiry, got " .. tostring(store.messageRetentionAt[PARTY_KEY])
    )
  end

  -- test_legacy_roster_leave_keeps_last_activity
  do
    rawset(_G, "IsInGroup", function()
      return false
    end)
    rawset(_G, "IsInRaid", function()
      return false
    end)
    local Bootstrap = makeBootstrap()
    local store = Bootstrap.runtime.store
    local chatAt = clock - HOUR
    store.conversations[LEGACY_PARTY_KEY] = {
      channel = "PARTY",
      lastActivityAt = chatAt,
      messages = { { id = "m1", kind = "user", direction = "in", text = "hi", sentAt = chatAt } },
    }

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", {})

    local conversation = store.conversations[LEGACY_PARTY_KEY]
    assert(#conversation.messages == 2, "the legacy row records its Left line")
    assert(conversation.lastActivityAt == chatAt, "a legacy leave must not count as activity, got " .. tostring(conversation.lastActivityAt))
  end

  _G.time = savedTime
  _G.date = savedDate
  _G.IsInGroup = savedIsInGroup
  _G.IsInRaid = savedIsInRaid
  _G.LE_PARTY_CATEGORY_HOME = savedLE_HOME
  _G.LE_PARTY_CATEGORY_INSTANCE = savedLE_INSTANCE
end
