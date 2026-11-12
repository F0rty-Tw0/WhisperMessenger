local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- A whisper sent from the window plays the sent sound once, after it goes
-- out: short, long (in parts) or a reaction. A failed send plays nothing.

local DING_ID = 12889

local function newRuntime(sent)
  return {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text, _chatType, _languageID, target)
        table.insert(sent, { text = text, target = target })
      end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
    accountState = { settings = { playSoundOnSend = true, sentSound = "ding" } },
  }
end

local function payload(text)
  return {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall",
    channel = "WOW",
    text = text or "hello",
  }
end

local function rejectingBNetApi()
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function()
      return { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true, gameAccountInfo = { gameAccountID = 9 } }
    end,
    SendWhisper = function()
      error("rejected")
    end,
  }
end

return function()
  local dings = 0
  rawset(_G, "PlaySound", function(soundId)
    if soundId == DING_ID then
      dings = dings + 1
    end
  end)

  -- test_successful_send_plays_sent_sound_once
  do
    dings = 0
    local sent = {}
    assert(SendHandler.HandleSend(newRuntime(sent), payload(), function() end) == true, "send succeeded")
    assert(#sent == 1, "one whisper went out")
    assert(dings == 1, "a sent whisper plays the sent sound once, got " .. dings)
  end

  -- test_long_send_plays_once
  do
    dings = 0
    local sent = {}
    local long = string.rep("word ", 120)
    assert(SendHandler.HandleSend(newRuntime(sent), payload(long), function() end) == true, "long send succeeded")
    assert(#sent >= 2, "the long whisper went out in parts, got " .. #sent)
    assert(dings == 1, "a whisper sent in parts plays once, got " .. dings)
  end

  -- test_failed_send_plays_nothing
  do
    dings = 0
    local runtime = newRuntime({})
    runtime.bnetApi = rejectingBNetApi()
    rawset(_G, "BNSendWhisper", nil)
    local p =
      { conversationKey = "me::BN::jaina", displayName = "Jaina#1234", battleTag = "Jaina#1234", bnetAccountID = 77, channel = "BN", text = "yo" }
    assert(SendHandler.HandleSend(runtime, p, function() end) == false, "send failed")
    assert(dings == 0, "a failed send plays nothing, got " .. dings)
  end

  -- test_reaction_send_plays_sent_sound
  do
    dings = 0
    local p = payload()
    p.reactionControl = { sourceText = "hi", operation = { type = "reaction", operation = "set", key = "heart", wireId = "w1" } }
    assert(SendHandler.HandleSend(newRuntime({}), p, function() end) == true, "reaction send succeeded")
    assert(dings == 1, "a reaction plays the sent sound, got " .. dings)
  end

  -- test_sent_sound_off_by_default
  do
    dings = 0
    local runtime = newRuntime({})
    runtime.accountState.settings.playSoundOnSend = nil
    SendHandler.HandleSend(runtime, payload(), function() end)
    assert(dings == 0, "the sent sound is off until turned on, got " .. dings)
  end

  rawset(_G, "PlaySound", nil)
end
