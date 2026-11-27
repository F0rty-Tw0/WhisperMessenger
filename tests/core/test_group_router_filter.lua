local Store = require("WhisperMessenger.Model.ConversationStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")
local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")

-- Filtered group lines are dropped before ingest: no store change, no refresh.
-- With "Show group chats" off, lines pass the filters (so blocked counts stay
-- right) and are then dropped too, mention alerts included.

local function guildLine(runtime, sender, text, lineID, guid)
  return EventBridge.RouteGroupEvent(runtime, "CHAT_MSG_GUILD", text, sender, "", "", "", "", 0, 0, "", 0, lineID, guid or "Player-1-OTHER")
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

  -- test_own_line_is_never_filtered
  do
    local runtime = makeRuntime()
    KeywordRules.Add(runtime.accountState.filters, "wts boost")
    IgnoreList.Add(runtime.accountState.filters, "Arthas-Area52", { now = 1 })
    assert(guildLine(runtime, "Arthas-Area52", "WTS boost cheap", 7004, "Player-1-SELF") == true)
    local guild = runtime.store.conversations["guild::arthas-area52"]
    assert(guild ~= nil and #guild.messages == 1, "the player's own line with a blocked word is stored")
    assert(guild.messages[1].direction == "out", "the stored line is the player's own")

    assert(guildLine(runtime, "Seller-Area52", "WTS boost cheap", 7005) == true)
    assert(#guild.messages == 1, "another player's identical line is dropped")
  end

  -- test_group_line_not_stored_when_show_group_chats_off
  do
    local runtime, refreshCount = makeRuntime()
    runtime.accountState.settings.showGroupChats = false
    ingestCalls = 0
    local handled = guildLine(runtime, "Other-Area52", "hello", 7100)
    assert(handled == true, "a line with group chats off is consumed")
    assert(ingestCalls == 0, "ingest is never called with group chats off")
    assert(next(runtime.store.conversations) == nil, "nothing is stored with group chats off")
    assert(refreshCount() == 0, "no refresh is scheduled with group chats off")
  end

  -- test_ignored_group_sender_still_recorded_when_show_group_chats_off
  do
    local runtime = makeRuntime()
    runtime.accountState.settings.showGroupChats = false
    IgnoreList.Add(runtime.accountState.filters, "Spammer-Area52", { now = 1 })
    guildLine(runtime, "Spammer-Area52", "cheap gold", 7101)
    local _, entry = next(runtime.accountState.filters.ignored)
    assert(entry ~= nil, "setup: the sender is on the ignore list")
    assert(entry.blocked == 1, "the Filters page still counts the blocked line, got " .. tostring(entry.blocked))
  end

  -- test_group_mention_stays_quiet_when_show_group_chats_off
  do
    local notifies = 0
    local realNotify = IncomingAlerts.Notify
    local savedUnitName = _G.UnitName
    rawset(IncomingAlerts, "Notify", function()
      notifies = notifies + 1
    end)
    rawset(_G, "UnitName", function()
      return "Arthas"
    end)
    local runtime = makeRuntime()
    runtime.accountState.settings.showGroupChats = false
    guildLine(runtime, "Other-Area52", "Arthas can you tank?", 7102)
    rawset(IncomingAlerts, "Notify", realNotify)
    rawset(_G, "UnitName", savedUnitName)
    assert(notifies == 0, "no mention alert with group chats off, got " .. notifies)
  end

  -- test_group_line_stored_when_show_group_chats_nil
  do
    local runtime = makeRuntime()
    runtime.accountState.settings.showGroupChats = nil
    ingestCalls = 0
    guildLine(runtime, "Other-Area52", "hello", 7103)
    assert(ingestCalls == 1, "group chats default to on")
    assert(runtime.store.conversations["guild::arthas-area52"] ~= nil, "the line is stored by default")
  end

  rawset(GroupChatIngest, "HandleEvent", realHandleEvent)
end
