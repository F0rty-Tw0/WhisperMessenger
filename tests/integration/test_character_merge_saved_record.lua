local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Router = require("WhisperMessenger.Core.EventRouter")
local World = require("tests.helpers.character_merge_world")

-- A Battle.net chat and a character chat of the same friend, shaped like the
-- saved records (field names from a live SavedVariables file, values made
-- up), fold into one chat when the character whispers again.
local K, B, NAME = World.K, World.B, World.NAME

local function bnetLine(id, direction, text, sentAt)
  local line = {
    id = id,
    lineID = tonumber(id),
    kind = "user",
    direction = direction,
    text = text,
    sentAt = sentAt,
    channel = "BN",
    playerName = "Jaina",
    battleTag = "Jaina#1234",
    bnetAccountID = 77,
    gameAccountName = "Jaina-Area52",
    guid = "Player-B",
  }
  if direction == "out" then
    line.senderName = "Me"
    line.senderClassTag = "MAGE"
    line.wireId = "w" .. id
  end
  return line
end

local function bnetRecord()
  return {
    conversationKey = B,
    channel = "BN",
    displayName = "Jaina#1234",
    battleTag = "Jaina#1234",
    bnetAccountID = 77,
    gameAccountName = "Jaina-Area52",
    guid = "Player-B",
    areaName = "Dalaran",
    className = "Mage",
    raceName = "Human",
    factionName = "Alliance",
    unreadCount = 2,
    unreadActivityCount = 0,
    lastActivityAt = 500,
    lastActivityLineID = 5,
    lastPreview = "b 3",
    lastIncomingAt = 500,
    lastIncomingLineID = 5,
    lastIncomingSender = "Jaina",
    lastIncomingPreview = "b 3",
    lastSeenAt = 500,
    messages = { bnetLine("1", "in", "b 1", 100), bnetLine("3", "out", "b 2", 300), bnetLine("5", "in", "b 3", 500) },
  }
end

local function characterRecord()
  return {
    conversationKey = K,
    channel = "WOW",
    displayName = NAME,
    guid = "Player-1",
    className = "Paladin",
    classTag = "PALADIN",
    raceName = "Human",
    raceTag = "Human",
    factionName = "Alliance",
    unreadCount = 1,
    unreadActivityCount = 0,
    lastActivityAt = 600,
    lastActivityLineID = 6,
    lastPreview = "k 3",
    lastIncomingAt = 200,
    lastIncomingLineID = 2,
    lastIncomingSender = NAME,
    lastIncomingPreview = "k 1",
    messages = {
      { id = "2", lineID = 2, kind = "user", direction = "in", text = "k 1", sentAt = 200, channel = "WOW", playerName = NAME, guid = "Player-1" },
      -- Stored before lines were compacted: still carries its identity.
      { id = "4", lineID = 4, kind = "user", direction = "out", text = "k 2", sentAt = 400, channel = "WOW", playerName = NAME, guid = "Player-1" },
      -- Compacted: identity left to the chat record.
      { id = "6", lineID = 6, kind = "user", direction = "out", text = "k 3", sentAt = 600 },
    },
  }
end

local function isCharacterText(text)
  return string.sub(text, 1, 2) == "k " or text == "new"
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  local accountState = { conversations = { [B] = bnetRecord(), [K] = characterRecord() }, channelMessages = {} }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, { activeConversationKey = nil }, "me", {
    now = function()
      return 1000
    end,
    bnetApi = {
      GetAccountInfoByGUID = function()
        return { bnetAccountID = 77, battleTag = "Jaina#1234" }
      end,
    },
  })
  assert(runtime.characterMerges ~= nil, "every runtime carries the merge handle")
  Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", { text = "new", playerName = NAME, guid = "Player-1", lineID = 900 })

  local merged = accountState.conversations[B]
  assert(accountState.conversations[K] == nil, "the character chat is folded away")
  assert(#merged.messages == 7, "every line of both chats plus the new one, got " .. #merged.messages)
  local times = {}
  for index, line in ipairs(merged.messages) do
    times[index] = line.sentAt
    if isCharacterText(line.text) then
      assert(line.channel == "WOW" and line.playerName == NAME, "character line '" .. line.text .. "' must be stamped")
    else
      assert(line.channel == "BN", "Battle.net line '" .. line.text .. "' keeps its channel")
    end
  end
  assert(table.concat(times, ",") == "100,200,300,400,500,600,1000", "lines in time order, got " .. table.concat(times, ","))
  assert(merged.channel == "BN" and merged.battleTag == "Jaina#1234" and merged.bnetAccountID == 77, "B keeps its identity")
  assert(merged.unreadCount == 4, "unread 2 + 1 + the new line, got " .. tostring(merged.unreadCount))
  assert(merged.lastActivityAt == 1000, "activity is the new line")
  assert(accountState.mergedCharacters[K].bnetKey == B, "the merge is in the saved table")
  _G.C_Timer = savedTimer
end
