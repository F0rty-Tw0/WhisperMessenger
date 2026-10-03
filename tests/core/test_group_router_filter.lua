local Store = require("WhisperMessenger.Model.ConversationStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

-- Filtered group lines are dropped before ingest: no store change, no refresh.

local function guildLine(runtime, sender, text, lineID)
  return EventBridge.RouteGroupEvent(runtime, "CHAT_MSG_GUILD", text, sender, "", "", "", "", 0, 0, "", 0, lineID, "Player-1-OTHER")
end

local function makeRuntime()
  local refreshes = 0
  local runtime = {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    accountState = { settings = {}, filters = { ignored = {}, rules = {} } },
    now = function()
      return 100
    end,
    scheduleIncomingRefresh = function()
      refreshes = refreshes + 1
    end,
  }
  return runtime, function()
    return refreshes
  end
end

return function()
  local realHandleEvent = GroupChatIngest.HandleEvent
  local ingestCalls = 0
  rawset(GroupChatIngest, "HandleEvent", function(...)
    ingestCalls = ingestCalls + 1
    return realHandleEvent(...)
  end)

  -- test_ignored_sender_skips_ingest
  do
    local runtime, refreshCount = makeRuntime()
    IgnoreList.Add(runtime.accountState.filters, "Spammer-Area52", { now = 1 })
    ingestCalls = 0
    local handled = guildLine(runtime, "Spammer-Area52", "cheap gold", 7001)
    assert(handled == true, "a dropped line counts as handled")
    assert(ingestCalls == 0, "ingest is never called for an ignored sender")
    assert(next(runtime.store.conversations) == nil, "the store is unchanged")
    assert(refreshCount() == 0, "no refresh is scheduled")
  end

  -- test_rule_blocked_line_skips_ingest
  do
    local runtime = makeRuntime()
    KeywordRules.Add(runtime.accountState.filters, "wts boost")
    ingestCalls = 0
    assert(guildLine(runtime, "Seller-Area52", "WTS boost cheap", 7002) == true)
    assert(ingestCalls == 0, "ingest is never called for a rule-blocked line")
    assert(next(runtime.store.conversations) == nil, "the store is unchanged")
  end

  -- test_clean_line_reaches_ingest
  do
    local runtime = makeRuntime()
    IgnoreList.Add(runtime.accountState.filters, "Spammer-Area52", { now = 1 })
    ingestCalls = 0
    assert(guildLine(runtime, "Friend-Area52", "anyone for Arathi?", 7003) == true)
    assert(ingestCalls == 1, "a clean line is ingested")
    assert(runtime.store.conversations["guild::arthas-area52"] ~= nil, "the line is stored")
  end

  rawset(GroupChatIngest, "HandleEvent", realHandleEvent)
end
