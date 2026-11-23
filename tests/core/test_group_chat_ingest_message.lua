local Message = require("WhisperMessenger.Core.Ingest.GroupChatIngest.Message")
local MessageMetadata = require("WhisperMessenger.Model.ConversationStore.MessageMetadata")
local Mention = require("WhisperMessenger.Model.Mention")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

-- The stored message for one group chat line holds only the fields it has.

local PLAYER_INFO = { className = "Paladin", classTag = "PALADIN", raceName = "Human", raceTag = "Human", factionName = "Alliance" }

local function guildPayload(index, playerInfo)
  return {
    text = "hello guild " .. index,
    lineID = 5000 + index,
    guid = "Player-1-" .. index,
    playerName = "Other-Area52",
    bnSenderID = 0,
    playerInfo = playerInfo,
  }
end

local function withQuietSender(run)
  local playerName, showLevels = Mention.PlayerName, DisplayName.ShowPlayerLevels
  rawset(Mention, "PlayerName", function()
    return "Nobodyhere"
  end)
  rawset(DisplayName, "ShowPlayerLevels", function()
    return false
  end)
  local ok, err = pcall(run)
  rawset(Mention, "PlayerName", playerName)
  rawset(DisplayName, "ShowPlayerLevels", showLevels)
  assert(ok, err)
end

local function fullCount()
  collectgarbage()
  collectgarbage()
  return collectgarbage("count")
end

-- A table constructor reserves a slot for every field it names, set or nil:
-- naming all seventeen fields doubled the table of every stored group line.
local function test_built_group_message_is_sized_by_the_fields_it_holds()
  local count = 500
  local payloads = {}
  for index = 1, count do
    payloads[index] = guildPayload(index, PLAYER_INFO)
  end
  local built = {}
  local before = fullCount()
  for index = 1, count do
    local message = Message.Build(payloads[index], "in", "GUILD", 1000 + index, nil)
    MessageMetadata.Compact(message, nil)
    built[index] = message
  end
  local bytesPerMessage = (fullCount() - before) * 1024 / #built
  assert(bytesPerMessage < 1000, string.format("a stored group line should cost under 1000 bytes, got %.0f", bytesPerMessage))
end

local function test_line_without_player_info_leaves_sender_fields_unset()
  local message = Message.Build(guildPayload(1, nil), "in", "GUILD", 1001, nil)
  assert(message.className == nil and message.classTag == nil and message.raceName == nil, "no player info -> no class or race")
  assert(message.senderClassTag == nil and message.senderName == nil, "an incoming line has no sender stamp")
  assert(message.text == "hello guild 1" and message.playerName == "Other-Area52" and message.lineID == 5001, "text, sender and line are kept")
end

local function test_line_without_battle_net_sender_leaves_account_unset()
  local payload = guildPayload(1, PLAYER_INFO)
  payload.bnSenderID = nil
  local message = Message.Build(payload, "in", "GUILD", 1001, nil)
  assert(message.bnetAccountID == nil, "no Battle.net sender -> no account id")
end

local function test_built_group_message_keeps_every_value()
  local message = Message.Build(guildPayload(3, PLAYER_INFO), "in", "PARTY", 1003, false)
  local expected = {
    id = "5003",
    direction = "in",
    kind = "user",
    text = "hello guild 3",
    sentAt = 1003,
    lineID = 5003,
    guid = "Player-1-3",
    playerName = "Other-Area52",
    channel = "PARTY",
    bnetAccountID = 0,
    className = "Paladin",
    classTag = "PALADIN",
    raceName = "Human",
    raceTag = "Human",
    factionName = "Alliance",
    isLeader = false,
  }
  for field, value in pairs(expected) do
    assert(message[field] == value, field .. " should be " .. tostring(value) .. ", got " .. tostring(message[field]))
  end
  for field in pairs(message) do
    assert(expected[field] ~= nil, "unexpected field " .. field)
  end
end

return function()
  withQuietSender(function()
    test_built_group_message_is_sized_by_the_fields_it_holds()
    test_line_without_player_info_leaves_sender_fields_unset()
    test_line_without_battle_net_sender_leaves_account_unset()
    test_built_group_message_keeps_every_value()
  end)
end
