local Store = require("WhisperMessenger.Model.ConversationStore")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local ChannelChatIngest = require("WhisperMessenger.Core.Ingest.ChannelChatIngest")

-- Public channel lines become CHANNEL conversations, one per channel, only
-- for channels the player turned on.
local TRADE_KEY = "channel::arthas-area52::trade"
local GENERAL_KEY = "channel::arthas-area52::general"

local function makeState(clock)
  return {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    accountState = {
      settings = { enabledChannels = { trade = true, general = true } },
      filters = { ignored = {}, rules = {} },
    },
    collapseIndex = {},
    now = function()
      return clock and clock.t or 100
    end,
  }
end

local function tradeLine(text, sender, lineID, guid)
  return {
    text = text,
    playerName = sender,
    channelName = "2. Trade - Stormwind City",
    zoneChannelID = 2,
    channelIndex = 2,
    channelBaseName = "Trade - Stormwind City",
    lineID = lineID,
    guid = guid or ("Player-1-" .. sender),
  }
end

local function generalLine(text, sender, lineID, zone)
  return {
    text = text,
    playerName = sender,
    channelName = "1. General - " .. zone,
    zoneChannelID = 1,
    channelIndex = 1,
    channelBaseName = "General - " .. zone,
    lineID = lineID,
    guid = "Player-1-" .. sender,
  }
end

local function ingested(state, payload)
  local _, conversation = ChannelChatIngest.HandleEvent(state, payload)
  return assert(conversation, "the line was stored")
end

return function()
  -- test_disabled_channel_stores_nothing
  do
    local state = makeState()
    state.accountState.settings.enabledChannels = {}
    local handled = ChannelChatIngest.HandleEvent(state, tradeLine("WTS ore", "Seller", 9101))
    assert(handled == false, "a channel that is not turned on is not handled")
    assert(next(state.store.conversations) == nil, "nothing is stored")
  end

  -- test_enabled_trade_line_creates_channel_conversation
  do
    local state = makeState()
    local handled, stored = ChannelChatIngest.HandleEvent(state, tradeLine("WTS ore", "Seller", 9102))
    local conversation = assert(stored, "the line was stored")
    assert(handled == true, "an enabled channel line is handled")
    assert(conversation == state.store.conversations[TRADE_KEY], "the line lands in the Trade conversation")
    assert(conversation.displayName == "Trade", "the title is the channel name without its zone, got " .. tostring(conversation.displayName))
    assert(conversation.channel == "CHANNEL", "the conversation is a channel chat")
    assert(conversation.channelIndex == 2 and conversation.channelBaseName == "Trade - Stormwind City", "send fields are stamped")
    assert(conversation.ownerProfileId == "arthas-area52", "the owner character is stamped")
    assert(conversation.messages[1].channel == "CHANNEL" and conversation.messages[1].direction == "in", "the line is an incoming channel message")
  end

  -- test_second_sender_keeps_title_and_guid
  do
    local state = makeState()
    ChannelChatIngest.HandleEvent(state, tradeLine("WTS ore", "Seller", 9103))
    local conversation = ingested(state, tradeLine("WTB herbs", "Buyer", 9104))
    assert(#conversation.messages == 2, "both lines are stored")
    assert(conversation.displayName == "Trade", "a new sender does not rename the chat")
    assert(conversation.guid == nil, "a channel chat carries no sender guid")
  end

  -- test_same_sender_repeat_collapses
  do
    local state = makeState()
    ChannelChatIngest.HandleEvent(state, tradeLine("WTS [Ore] cheap!", "Seller", 9105))
    local conversation = ingested(state, tradeLine("wts ore   CHEAP", "Seller", 9106))
    assert(#conversation.messages == 1, "a repeat adds no row")
    assert(conversation.messages[1].repeatCount == 2, "the repeat counts up on the stored row")
  end

  -- test_collapse_off_keeps_every_line
  do
    local state = makeState()
    state.accountState.settings.collapseDuplicates = false
    ChannelChatIngest.HandleEvent(state, tradeLine("WTS ore", "Seller", 9107))
    local conversation = ingested(state, tradeLine("WTS ore", "Seller", 9108))
    assert(#conversation.messages == 2, "with collapse off a repeat is its own row")
  end

  -- test_zone_change_inserts_divider
  do
    local state = makeState()
    ChannelChatIngest.HandleEvent(state, generalLine("hello", "Anna", 9109, "Elwynn Forest"))
    local conversation = ingested(state, generalLine("hi all", "Bert", 9110, "Stormwind City"))
    assert(state.store.conversations[GENERAL_KEY] == conversation, "General stays one conversation across zones")
    assert(#conversation.messages == 3, "a divider row sits between the lines")
    local divider = conversation.messages[2]
    assert(divider.kind == "system" and divider.text == "Zone: Stormwind City", "the divider names the new zone, got " .. tostring(divider.text))
    assert(conversation.messages[3].text == "hi all", "the new line follows the divider")
    assert(conversation.lastZoneLabel == "Stormwind City", "the zone label is remembered")
  end

  -- test_ignored_sender_stores_nothing
  do
    local state = makeState()
    IgnoreList.Add(state.accountState.filters, "Spammer", { now = 1 })
    local handled = ChannelChatIngest.HandleEvent(state, tradeLine("cheap gold", "Spammer", 9111))
    assert(handled == true, "a dropped line counts as handled")
    assert(next(state.store.conversations) == nil, "nothing is stored for an ignored sender")
  end

  -- test_secret_text_stores_nothing
  do
    local state = makeState()
    local realDetect = ChannelChatIngest._isSecretString
    ChannelChatIngest._isSecretString = function(value)
      return value == "SECRET"
    end
    local handled = ChannelChatIngest.HandleEvent(state, tradeLine("SECRET", "Seller", 9112))
    ChannelChatIngest._isSecretString = realDetect
    assert(handled == false, "a secret payload is dropped")
    assert(next(state.store.conversations) == nil, "nothing is stored for a secret payload")
  end

  -- test_own_line_is_stored_outgoing
  do
    local state = makeState()
    local conversation = ingested(state, tradeLine("LF tailor", "Arthas", 9113, "Player-1-SELF"))
    assert(conversation.messages[1].direction == "out", "the player's own channel line is stored as sent")
  end

  -- test_contacts_list_includes_channel_for_owner
  do
    local state = makeState()
    ChannelChatIngest.HandleEvent(state, tradeLine("WTS ore", "Seller", 9114))
    local items = DataBuilder.BuildItemsForProfile({ conversations = state.store.conversations, settings = {} }, "arthas-area52")
    local found = false
    for _, item in ipairs(items) do
      if item.conversationKey == TRADE_KEY then
        found = true
      end
    end
    assert(found, "the channel chat reaches the contacts list")
  end
end
