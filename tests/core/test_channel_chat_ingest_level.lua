local Store = require("WhisperMessenger.Model.ConversationStore")
local ChannelChatIngest = require("WhisperMessenger.Core.Ingest.ChannelChatIngest")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

local STUBBED = { "UnitTokenFromGUID", "UnitLevel" }

local function makeState()
  return {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    accountState = {
      settings = { enabledChannels = { trade = true } },
      filters = { ignored = {}, rules = {} },
    },
    collapseIndex = {},
    now = function()
      return 100
    end,
  }
end

local function tradeLine(text, sender, lineID)
  return {
    text = text,
    playerName = sender,
    channelName = "2. Trade - Stormwind City",
    zoneChannelID = 2,
    channelIndex = 2,
    channelBaseName = "Trade - Stormwind City",
    lineID = lineID,
    guid = "Player-1-" .. sender,
  }
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  rawset(_G, "UnitTokenFromGUID", function(guid)
    if guid == "Player-1-Nergrom" then
      return "party1"
    end
    return nil
  end)
  rawset(_G, "UnitLevel", function(unit)
    if unit == "party1" then
      return 20
    end
    return nil
  end)

  -- test_option_off_skips_the_level_lookup
  do
    DisplayName.Configure({ showPlayerLevels = false })
    local _, conversation = ChannelChatIngest.HandleEvent(makeState(), tradeLine("LF tank Deadmines", "Nergrom", 9300))
    local message = assert(conversation, "the line was stored").messages[1]
    assert(message.senderLevel == nil, "expected no senderLevel with the option off, got " .. tostring(message.senderLevel))
  end

  DisplayName.Configure({ showPlayerLevels = true })

  -- test_incoming_channel_line_freezes_sender_level
  do
    local _, conversation = ChannelChatIngest.HandleEvent(makeState(), tradeLine("LF tank Deadmines", "Nergrom", 9301))
    conversation = assert(conversation, "the line was stored")
    local message = conversation.messages[#conversation.messages]
    assert(message.senderLevel == 20, "expected senderLevel 20, got " .. tostring(message.senderLevel))
  end

  DisplayName.Configure({ showPlayerLevels = false })
  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
end
