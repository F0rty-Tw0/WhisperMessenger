local Store = require("WhisperMessenger.Model.ConversationStore")
local Router = require("WhisperMessenger.Core.EventRouter")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")

-- Only real chat counts as activity: a status line such as "player is
-- offline" shows in the thread and the row preview, but it never bumps the
-- chat up the list or restarts its Message Retention timer.
return function()
  local HOUR = 3600
  local DAY = 24 * HOUR
  local ARTHAS_KEY = "bnet::BN::arthas#1234"
  local JAINA_KEY = "wow::WOW::jaina-area52"

  local function makeState(clock)
    return {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10, conversationMaxAge = DAY, messageMaxAge = DAY }, function()
        return clock.now
      end),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return clock.now
      end,
    }
  end

  local function arthasPayload(text, lineID)
    return {
      text = text,
      playerName = "Arthas-Area52",
      lineID = lineID,
      guid = "Player-3676-0ABCDEF0",
      channel = "BN",
      bnetAccountID = 42,
      accountInfo = { battleTag = "Arthas#1234" },
    }
  end

  local function arthasOffline(state, lineID)
    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", arthasPayload("Arthas is offline.", lineID))
  end

  local function listOrder(state)
    local keys = {}
    for _, item in ipairs(DataBuilder.BuildItems(state.store.conversations)) do
      table.insert(keys, item.conversationKey)
    end
    return table.concat(keys, ",")
  end

  -- test_offline_line_keeps_list_order_and_expires_from_last_real_message
  do
    local clock = { now = 1000000 }
    local state = makeState(clock)
    local chatAt = clock.now
    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", arthasPayload("brb", 1))
    clock.now = chatAt + HOUR
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "hi", playerName = "Jaina-Area52", lineID = 2, guid = "Player-3676-0000BEEF" })
    local orderBefore = listOrder(state)
    assert(orderBefore == JAINA_KEY .. "," .. ARTHAS_KEY, "Jaina wrote last, got " .. orderBefore)

    clock.now = chatAt + 2 * HOUR
    arthasOffline(state, 3)

    local arthas = state.store.conversations[ARTHAS_KEY]
    assert(arthas.messages[#arthas.messages].kind == "system", "the offline line is in the thread")
    assert(arthas.lastPreview == "Arthas is offline.", "the row preview shows the offline line, got " .. tostring(arthas.lastPreview))
    assert(arthas.lastActivityAt == chatAt, "a status line is not activity, got " .. tostring(arthas.lastActivityAt))
    assert(arthas.lastActivityLineID == 1, "activity keeps the real line's ID, got " .. tostring(arthas.lastActivityLineID))
    assert(listOrder(state) == orderBefore, "a status line must not bump the chat up the list, got " .. listOrder(state))

    clock.now = chatAt + DAY + 30 * 60
    Store.ApplyRetention(state.store, clock.now)
    assert(state.store.conversations[ARTHAS_KEY] == nil, "idle 24.5h since the last real message, the chat must expire")
    assert(state.store.conversations[JAINA_KEY] ~= nil, "Jaina wrote 23.5h ago, her chat stays")
  end

  -- test_status_line_that_opens_a_chat_still_ages_out
  do
    local clock = { now = 2000000 }
    local state = makeState(clock)
    local lineAt = clock.now
    arthasOffline(state, 4)

    local arthas = state.store.conversations[ARTHAS_KEY]
    assert(arthas.lastActivityAt == lineAt, "a chat with no real message yet ages from its first line, got " .. tostring(arthas.lastActivityAt))

    clock.now = lineAt + DAY + 1
    Store.ApplyRetention(state.store, clock.now)
    assert(state.store.conversations[ARTHAS_KEY] == nil, "a chat holding only a status line must still expire")
  end

  -- test_status_line_inserted_by_time_does_not_count_as_activity
  do
    local clock = { now = 3000000 }
    local chatAt = clock.now
    local state = makeState(clock)
    Store.AppendIncoming(state.store, JAINA_KEY, { id = "m1", kind = "user", direction = "in", text = "hi", sentAt = chatAt }, false)

    clock.now = chatAt + DAY + 1
    local notice = { id = "n1", kind = "system", direction = "in", text = "Jaina is offline.", sentAt = clock.now }
    Store.InsertIncomingChronological(state.store, JAINA_KEY, notice, false)

    assert(state.store.conversations[JAINA_KEY] == nil, "past the limit from the last real message, a status line must not keep the chat")
  end

  -- A chat whose real line m1 at chatAt is followed by a status line 20h later.
  local function jainaWithStatusLine(clock)
    local state = makeState(clock)
    local chatAt = clock.now
    local real = { id = "m1", kind = "user", direction = "in", text = "hi", sentAt = chatAt, lineID = 1 }
    Store.AppendIncoming(state.store, JAINA_KEY, real, false)
    clock.now = chatAt + 20 * HOUR
    local notice = { id = "s1", kind = "system", direction = "in", text = "Jaina is offline.", sentAt = clock.now, lineID = 2 }
    Store.InsertIncomingChronological(state.store, JAINA_KEY, notice, false)
    clock.now = chatAt + 21 * HOUR
    return state, chatAt
  end

  local function replayed(chatAt, direction)
    return { id = "m2", kind = "user", direction = direction, text = "replayed", sentAt = chatAt + 10 * HOUR, lineID = 3 }
  end

  -- test_real_line_arriving_behind_a_status_line_moves_activity
  do
    local clock = { now = 4000000 }
    local state, chatAt = jainaWithStatusLine(clock)
    Store.InsertIncomingChronological(state.store, JAINA_KEY, replayed(chatAt, "in"), false)

    local jaina = state.store.conversations[JAINA_KEY]
    assert(jaina.lastActivityAt == chatAt + 10 * HOUR, "the replayed real line is the latest activity, got " .. tostring(jaina.lastActivityAt))
    assert(jaina.lastPreview == "Jaina is offline.", "the newer status line keeps the preview, got " .. tostring(jaina.lastPreview))
    clock.now = chatAt + DAY + 60
    Store.ApplyRetention(state.store, clock.now)
    assert(state.store.conversations[JAINA_KEY] ~= nil, "the last real line is 14h old, the chat must stay")
  end

  -- test_real_line_arriving_past_the_limit_of_older_activity_keeps_the_chat
  do
    local clock = { now = 4500000 }
    local state, chatAt = jainaWithStatusLine(clock)
    clock.now = chatAt + DAY + 60
    Store.InsertIncomingChronological(state.store, JAINA_KEY, replayed(chatAt, "in"), false)

    assert(state.store.conversations[JAINA_KEY] ~= nil, "the arriving real line is 14h old, the chat must stay")
  end

  -- test_real_line_arriving_behind_a_status_line_is_the_last_incoming
  do
    local clock = { now = 5000000 }
    local state, chatAt = jainaWithStatusLine(clock)
    Store.InsertIncomingChronological(state.store, JAINA_KEY, replayed(chatAt, "in"), false)

    local jaina = state.store.conversations[JAINA_KEY]
    assert(jaina.lastIncomingPreview == "replayed", "the replayed line is the newest incoming, got " .. tostring(jaina.lastIncomingPreview))
  end

  -- test_own_line_arriving_behind_a_status_line_moves_activity
  do
    local clock = { now = 6000000 }
    local state, chatAt = jainaWithStatusLine(clock)
    Store.InsertOutgoingChronological(state.store, JAINA_KEY, replayed(chatAt, "out"))

    local jaina = state.store.conversations[JAINA_KEY]
    assert(jaina.lastActivityAt == chatAt + 10 * HOUR, "the player's line is the latest activity, got " .. tostring(jaina.lastActivityAt))
    assert(jaina.lastPreview == "Jaina is offline.", "the newer status line keeps the preview, got " .. tostring(jaina.lastPreview))
  end

  -- test_older_activity_record_keeps_a_newer_status_line_as_preview
  do
    local clock = { now = 7000000 }
    local state, chatAt = jainaWithStatusLine(clock)
    Store.RecordIncomingActivity(state.store, JAINA_KEY, replayed(chatAt, "in"), false)

    local jaina = state.store.conversations[JAINA_KEY]
    assert(jaina.lastPreview == "Jaina is offline.", "an older line must not roll the preview back, got " .. tostring(jaina.lastPreview))
    assert(jaina.lastActivityAt == chatAt + 10 * HOUR, "the older real line is still the latest activity, got " .. tostring(jaina.lastActivityAt))
  end

  -- test_line_arriving_behind_a_newer_line_keeps_the_newer_contact_data
  for _, direction in ipairs({ "in", "out" }) do
    local clock = { now = 8000000 }
    local state, chatAt = jainaWithStatusLine(clock)
    local jaina = state.store.conversations[JAINA_KEY]
    jaina.gameAccountName = "Current"
    local message = replayed(chatAt, direction)
    message.gameAccountName = "Stale"
    if direction == "in" then
      Store.InsertIncomingChronological(state.store, JAINA_KEY, message, false)
    else
      Store.InsertOutgoingChronological(state.store, JAINA_KEY, message)
    end
    assert(
      jaina.gameAccountName == "Current",
      direction .. ": an older line must not overwrite contact data, got " .. tostring(jaina.gameAccountName)
    )
  end

  -- test_older_real_line_takes_over_activity_from_a_status_line_that_opened_the_chat
  local arrivals = {
    {
      "insertIn",
      function(store, message)
        Store.InsertIncomingChronological(store, JAINA_KEY, message, false)
      end,
    },
    {
      "insertOut",
      function(store, message)
        message.direction = "out"
        Store.InsertOutgoingChronological(store, JAINA_KEY, message)
      end,
    },
    {
      "record",
      function(store, message)
        Store.RecordIncomingActivity(store, JAINA_KEY, message, false)
      end,
    },
  }
  for _, arrival in ipairs(arrivals) do
    local name, arrive = arrival[1], arrival[2]
    local clock = { now = 9000000 }
    local state = makeState(clock)
    local noticeAt = clock.now
    Store.AppendIncoming(
      state.store,
      JAINA_KEY,
      { id = "s1", kind = "system", direction = "in", text = "Jaina is offline.", sentAt = noticeAt },
      false
    )
    local jaina = state.store.conversations[JAINA_KEY]
    jaina.gameAccountName = "Current"
    clock.now = noticeAt + HOUR
    local older = { id = "m1", kind = "user", direction = "in", text = "older", sentAt = noticeAt - 2 * HOUR, lineID = 7, gameAccountName = "Stale" }
    arrive(state.store, older)

    assert(jaina.lastActivityAt == noticeAt - 2 * HOUR, name .. ": the real line is the activity, got " .. tostring(jaina.lastActivityAt))
    assert(jaina.lastActivityLineID == 7, name .. ": activity takes the real line's ID, got " .. tostring(jaina.lastActivityLineID))
    assert(jaina.lastPreview == "Jaina is offline.", name .. ": the newer status line keeps the preview, got " .. tostring(jaina.lastPreview))
    assert(jaina.gameAccountName == "Current", name .. ": an older line must not overwrite contact data, got " .. tostring(jaina.gameAccountName))
  end
end
