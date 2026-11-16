local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local NOW = 100000
local STALE = "me::WOW::stale"
local RECENT = "me::WOW::recent"

-- A real runtime (the removal hook lives there) with one chat a shorter
-- retention would expire and one it would keep.
local function build(activeKey)
  local accountState = {
    settings = { messageMaxAge = 86400 },
    conversations = {
      [STALE] = { conversationKey = STALE, messages = {}, lastActivityAt = NOW - 7200 },
      [RECENT] = { conversationKey = RECENT, messages = {}, lastActivityAt = NOW - 60 },
    },
  }
  local characterState = { activeConversationKey = activeKey }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {
    now = function()
      return NOW
    end,
  })
  local refreshes = { count = 0 }
  runtime.refreshWindow = function()
    refreshes.count = refreshes.count + 1
  end
  local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountState.settings })
  return onChange, runtime, characterState, refreshes
end

return function()
  -- test_retention_setting_change_clears_selection_when_it_expires
  do
    local onChange, runtime, characterState, refreshes = build(STALE)

    onChange("messageMaxAge", 3600)

    assert(runtime.store.conversations[STALE] == nil, "the shorter limit expires the selected chat")
    assert(runtime.store.conversations[RECENT] ~= nil, "a recent chat stays")
    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
    assert(refreshes.count == 1, "the window refreshes once")
  end

  -- test_retention_setting_change_keeps_selection_when_it_stays
  do
    local onChange, runtime, characterState = build(RECENT)

    onChange("messageMaxAge", 3600)

    assert(runtime.store.conversations[STALE] == nil, "the shorter limit expires the stale chat")
    assert(runtime.activeConversationKey == RECENT and characterState.activeConversationKey == RECENT, "selection stays")
  end

  -- test_conversation_cap_change_never_evicts_the_selected_conversation
  do
    local onChange, runtime, characterState = build(STALE)

    onChange("maxConversations", 1)

    assert(runtime.store.conversations[STALE] ~= nil, "the selected chat is protected from the cap")
    assert(runtime.store.conversations[RECENT] == nil, "the other chat is evicted")
    assert(runtime.activeConversationKey == STALE and characterState.activeConversationKey == STALE, "selection stays")
  end
end
