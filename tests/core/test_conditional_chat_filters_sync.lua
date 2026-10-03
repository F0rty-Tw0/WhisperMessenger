local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")

-- The channel, say, yell and emote filters register only while something can
-- be hidden, and never in restricted content. Whisper events only ever get
-- the always-true filters.
local WHISPER_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_WHISPER_INFORM = true,
  CHAT_MSG_BN_WHISPER = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function setup(settings, filterState)
  local active, log = {}, {}
  local savedUtil = rawget(_G, "ChatFrameUtil")
  rawset(_G, "ChatFrameUtil", {
    AddMessageEventFilter = function(event, fn)
      active[event] = fn
      log[#log + 1] = { event = event, fn = fn }
    end,
    RemoveMessageEventFilter = function(event, fn)
      if active[event] == fn then
        active[event] = nil
      end
    end,
  })
  local accountState = { settings = settings, filters = filterState or { ignored = {}, rules = {} } }
  local runtime = { accountState = accountState, localPlayerGuid = "Player-1-SELF" }
  local Bootstrap = {}
  ChatFilters.Configure(Bootstrap, accountState, runtime)
  local function restore()
    rawset(_G, "ChatFrameUtil", savedUtil)
  end
  return Bootstrap, active, log, restore, accountState
end

local function run(fn)
  local ok, err = pcall(fn)
  assert(ok, err)
end

return function()
  -- test_channel_filter_registers_when_hiding_a_channel_chat
  run(function()
    local Bootstrap, active, _, restore = setup({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    Bootstrap.syncChatFilters()
    restore()
    assert(active.CHAT_MSG_CHANNEL ~= nil, "channel filter registered")
    assert(active.CHAT_MSG_SAY == nil, "nothing to hide in say without ignored players")
  end)

  -- test_ignored_player_registers_channel_and_speech_filters
  run(function()
    local Bootstrap, active, _, restore = setup({}, { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} })
    Bootstrap.syncChatFilters()
    restore()
    for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE" }) do
      assert(active[event] ~= nil, event .. " filter registered")
    end
  end)

  -- test_enabled_rule_registers_only_the_channel_filter
  run(function()
    local Bootstrap, active, _, restore = setup({}, { ignored = {}, rules = { { words = { "wts" }, enabled = true } } })
    Bootstrap.syncChatFilters()
    restore()
    assert(active.CHAT_MSG_CHANNEL ~= nil, "channel filter registered for rules")
    assert(active.CHAT_MSG_SAY == nil, "rules never hide say")
  end)

  -- test_nothing_hideable_registers_nothing
  run(function()
    local Bootstrap, active, _, restore = setup(
      { hideChannelsFromDefaultChat = true, enabledChannels = { trade = false } },
      { ignored = {}, rules = { { words = { "wts" }, enabled = false } } }
    )
    Bootstrap.syncChatFilters()
    restore()
    assert(next(active) == nil, "no filter without anything to hide")
  end)

  -- test_restricted_content_unregisters_the_filters
  for _, flag in ipairs({ "_inMythicContent", "_inEncounter", "_inCompetitiveContent" }) do
    run(function()
      local Bootstrap, active, _, restore = setup({}, { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} })
      Bootstrap.syncChatFilters()
      Bootstrap[flag] = true
      Bootstrap.syncChatFilters()
      restore()
      assert(next(active) == nil, flag .. " removes every conditional filter")
    end)
  end

  -- test_suspended_addon_registers_nothing
  run(function()
    local Bootstrap, active, _, restore = setup({}, { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} })
    rawset(_G, "_wmSuspended", true)
    Bootstrap.syncChatFilters()
    rawset(_G, "_wmSuspended", nil)
    restore()
    assert(next(active) == nil, "a suspended addon hides nothing")
  end)

  -- test_emptied_ignore_list_unregisters_on_resync
  run(function()
    local Bootstrap, active, _, restore, accountState = setup({}, { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} })
    Bootstrap.syncChatFilters()
    accountState.filters.ignored["spammer-realm"] = nil
    Bootstrap.syncChatFilters()
    restore()
    assert(next(active) == nil, "removing the last entry removes the filters")
  end)

  -- test_whisper_events_only_get_always_true_filters
  run(function()
    local Bootstrap, _, log, restore = setup(
      { hideFromDefaultChat = true, hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } },
      { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = { { words = { "wts" }, enabled = true } } }
    )
    Bootstrap.syncChatFilters()
    restore()
    local whisperAdds = 0
    for _, entry in ipairs(log) do
      if WHISPER_EVENTS[entry.event] then
        whisperAdds = whisperAdds + 1
        assert(entry.fn == Bootstrap._whisperFilter or entry.fn == Bootstrap._bnWhisperFilter, entry.event .. " gets only the whisper filter")
        assert(entry.fn() == true, "whisper filters always return true")
      end
    end
    assert(whisperAdds == 4, "the four whisper filters registered, got " .. whisperAdds)
  end)

  -- test_selective_hiding_switch_off_registers_nothing
  run(function()
    local Bootstrap, active, _, restore = setup({}, { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} })
    rawset(ChatFilters, "SELECTIVE_HIDING", false)
    local ok, err = pcall(Bootstrap.syncChatFilters)
    rawset(ChatFilters, "SELECTIVE_HIDING", true)
    restore()
    assert(ok, err)
    assert(next(active) == nil, "the switch keeps every conditional filter off")
  end)

  -- test_mythic_suspend_unregister_drops_conditional_filters
  -- Entering Mythic+ suspends through unregisterChatFilters without a resync,
  -- so it must drop the channel and speech filters too.
  run(function()
    local Bootstrap, active, _, restore = setup(
      { hideFromDefaultChat = true },
      { ignored = { ["spammer-realm"] = { name = "Spammer-Realm" } }, rules = {} }
    )
    Bootstrap.syncChatFilters()
    Bootstrap.unregisterChatFilters()
    restore()
    assert(next(active) == nil, "no filter stays registered after unregister")
  end)
end
