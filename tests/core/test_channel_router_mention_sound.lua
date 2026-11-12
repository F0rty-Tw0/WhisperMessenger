local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- A channel line naming the player plays the mention pick, not the whisper pick.

local ORB_ID = 32585

-- All 18 CHAT_MSG_CHANNEL arguments, as the live client sends them.
local function tradeLine(runtime, text, sender, lineID, zoneChannelID)
  return EventBridge.RouteChannelEvent(
    runtime,
    "CHAT_MSG_CHANNEL",
    text,
    sender,
    "Common",
    "2. Trade - Stormwind City",
    sender,
    "",
    zoneChannelID,
    2,
    "Trade - Stormwind City",
    7,
    lineID,
    "Player-1-" .. sender,
    0,
    false,
    false,
    false
  )
end

local function makeRuntime(settings)
  return {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    channelMessageStore = ChannelMessageStore.New(),
    accountState = { settings = settings, filters = { ignored = {}, rules = {} } },
    collapseIndex = {},
    now = function()
      return 100
    end,
    scheduleIncomingRefresh = function() end,
  }
end

return function()
  -- test_channel_mention_uses_mention_sound
  do
    local played = {}
    local savedUnitName = _G.UnitName
    rawset(_G, "UnitName", function()
      return "Arthas"
    end)
    rawset(_G, "FlashClientIcon", function() end)
    rawset(_G, "PlaySound", function(soundId)
      played[#played + 1] = soundId
    end)
    local runtime = makeRuntime({
      enabledChannels = { trade = true },
      playSoundOnWhisper = true,
      notificationSound = "bell",
      mentionSound = "orb",
    })
    tradeLine(runtime, "Arthas you still need ore?", "Seller", 8201, 2)
    assert(#played == 1 and played[1] == ORB_ID, "a channel mention plays the mention pick, got " .. tostring(played[1]))
    rawset(_G, "UnitName", savedUnitName)
    rawset(_G, "FlashClientIcon", nil)
    rawset(_G, "PlaySound", nil)
  end
end
