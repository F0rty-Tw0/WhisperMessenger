-- A chat lock (InChatMessagingLockdown or restriction type 5) counts as
-- competitive content: composer sends queue, channel ingest pauses.
local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")

local KEY = "me::WOW::thrall-nagrand"

local function boot(apiLocked, sent)
  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.C_RestrictedActions = nil
  _G.C_ChatInfo = {
    InChatMessagingLockdown = function()
      return apiLocked
    end,
  }
  Bootstrap._inMythicContent = false
  Bootstrap._inEncounter = false
  Bootstrap._inCompetitiveContent = false
  return Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = {} },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text)
        table.insert(sent, text)
      end,
    },
    bnetApi = {
      SendWhisper = function(_id, text)
        table.insert(sent, text)
      end,
    },
  })
end

local function queuedDelivery(runtime, key)
  local conversation = runtime.store.conversations[key]
  local message = conversation and conversation.messages[1]
  return message and message.delivery
end

return function()
  local savedUIParent = _G.UIParent
  local savedChatInfo = _G.C_ChatInfo
  local savedRestricted = _G.C_RestrictedActions
  local savedBNSendWhisper = rawget(_G, "BNSendWhisper")

  -- test_runtime_is_chat_locked_follows_api
  do
    local runtime = boot(true, {})
    assert(runtime.isChatLocked() == true, "API lock must reach runtime.isChatLocked")
    assert(runtime.isCompetitiveContent() == true, "chat lock counts as competitive content")
  end

  -- test_runtime_not_competitive_when_chat_unlocked
  do
    local runtime = boot(false, {})
    assert(runtime.isCompetitiveContent() == false, "no lock, no flags: not competitive")
  end

  -- test_composer_whisper_queued_under_chat_lock
  do
    local sent = {}
    local runtime = boot(true, sent)
    SendHandler.HandleSend(runtime, {
      conversationKey = KEY,
      target = "Thrall-Nagrand",
      displayName = "Thrall-Nagrand",
      text = "hi",
    }, function() end)
    assert(#sent == 0, "SendChatMessage must not run under chat lock")
    local delivery = queuedDelivery(runtime, KEY)
    assert(delivery == "queued", "whisper must be stored queued, got " .. tostring(delivery))
  end

  -- test_composer_bnet_whisper_queued_under_chat_lock
  do
    local sent = {}
    local runtime = boot(true, sent)
    rawset(_G, "BNSendWhisper", function(_id, text)
      table.insert(sent, text)
    end)
    local bnKey = "me::BN::jaina"
    SendHandler.HandleSend(runtime, {
      conversationKey = bnKey,
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      bnetAccountID = 12,
      channel = "BN",
      text = "hi",
    }, function() end)
    assert(#sent == 0, "BNet send must not run under chat lock")
    local delivery = queuedDelivery(runtime, bnKey)
    assert(delivery == "queued", "BNet whisper must be stored queued, got " .. tostring(delivery))
  end

  -- test_channel_ingest_suspended_under_chat_lock
  do
    local runtime = boot(true, {})
    assert(runtime.isChannelIngestSuspended() == true, "chat lock suspends channel ingest")
  end

  rawset(_G, "BNSendWhisper", savedBNSendWhisper)
  _G.C_RestrictedActions = savedRestricted
  _G.C_ChatInfo = savedChatInfo
  _G.UIParent = savedUIParent
end
