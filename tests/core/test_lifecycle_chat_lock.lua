-- A chat lock (restriction type 5 or InChatMessagingLockdown) drives the same
-- lifecycle as restricted content: notice, chat filters, queued-send notice,
-- and a stale cached lock is cleared on entering the world.
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictionState = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RestrictionState")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")
local Localization = require("WhisperMessenger.Locale.Localization")

local CHAT, ACTIVE, ACTIVATING, INACTIVE = 5, 2, 1, 0

local apiLocked = false

local enterWorldDeps = {
  getContentDetector = function()
    return {
      IsMythicRestricted = function()
        return false
      end,
      IsCompetitiveContent = function()
        return false
      end,
    }
  end,
  getPresenceCache = function()
    return nil
  end,
}

local function newBootstrap()
  local spies = { syncChatFilters = 0, refreshWindow = 0, competitive = {} }
  local runtime = {
    restrictedActions = RestrictedActions.New(),
    store = { conversations = {} },
    refreshWindow = function()
      spies.refreshWindow = spies.refreshWindow + 1
    end,
  }
  runtime.isChatLocked = function()
    return runtime.restrictedActions.isChatLocked()
  end
  runtime.isCompetitiveContent = function()
    return runtime.isChatLocked()
  end
  local Bootstrap = {
    runtime = runtime,
    syncChatFilters = function()
      spies.syncChatFilters = spies.syncChatFilters + 1
    end,
    onCompetitiveStateChanged = function(isActive)
      table.insert(spies.competitive, isActive)
    end,
  }
  return Bootstrap, spies
end

local function withQueuedMessage(runtime)
  runtime.store.conversations.k = { messages = { { direction = "out", kind = "user", text = "gg", delivery = "queued" } } }
end

local function configureFilters(Bootstrap)
  ChatFilters.Configure(Bootstrap, { settings = { hideFromDefaultChat = true } }, Bootstrap.runtime)
end

return function()
  Localization.Configure({ language = "enUS" })
  local saved = {
    chatInfo = _G.C_ChatInfo,
    restricted = _G.C_RestrictedActions,
    addFilter = rawget(_G, "ChatFrame_AddMessageEventFilter"),
    removeFilter = rawget(_G, "ChatFrame_RemoveMessageEventFilter"),
    chatFrame = rawget(_G, "DEFAULT_CHAT_FRAME"),
    timer = _G.C_Timer,
  }
  _G.C_RestrictedActions = nil
  _G.C_Timer = nil
  _G.C_ChatInfo = {
    InChatMessagingLockdown = function()
      return apiLocked
    end,
  }
  rawset(_G, "ChatFrame_AddMessageEventFilter", function() end)
  rawset(_G, "ChatFrame_RemoveMessageEventFilter", function() end)
  local lines = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      lines[#lines + 1] = text
    end,
  })

  -- test_notice_set_under_chat_lock
  do
    apiLocked = true
    local Bootstrap, spies = newBootstrap()
    Common.notifyCompetitiveState(Bootstrap)
    assert(Bootstrap.runtime.messagingNotice == Localization.Text(Common.COMPETITIVE_NOTICE), "chat lock sets the paused notice")
    assert(spies.competitive[1] == true, "icon learns the competitive state")
  end

  -- test_chat_filters_off_under_chat_lock
  do
    apiLocked = true
    local Bootstrap = newBootstrap()
    configureFilters(Bootstrap)
    Bootstrap.syncChatFilters()
    assert(Bootstrap._filtersRegistered ~= true, "whisper filters must stay off under chat lock")
  end

  -- test_type5_active_syncs_filters_and_notice
  do
    apiLocked = false
    local Bootstrap, spies = newBootstrap()
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, CHAT, ACTIVE)
    assert(spies.syncChatFilters == 1, "type 5 resyncs chat filters once, got " .. spies.syncChatFilters)
    assert(Bootstrap.runtime.messagingNotice == Localization.Text(Common.COMPETITIVE_NOTICE), "type 5 sets the notice")
    assert(spies.refreshWindow > 0, "type 5 refreshes the window")
  end

  -- test_type5_inactive_prints_queued_lift_notice
  do
    apiLocked = false
    lines = {}
    local Bootstrap = newBootstrap()
    withQueuedMessage(Bootstrap.runtime)
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, CHAT, ACTIVE)
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, CHAT, INACTIVE)
    assert(#lines == 1, "one queued notice when the chat lock lifts, got " .. #lines)
    assert(string.find(lines[1], "1 queued message is waiting", 1, true), lines[1])
  end

  -- test_type5_inactive_during_mythic_prints_no_lift_notice
  do
    apiLocked = false
    lines = {}
    local Bootstrap = newBootstrap()
    Bootstrap.runtime.isMythicLockdown = function()
      return true
    end
    withQueuedMessage(Bootstrap.runtime)
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, CHAT, ACTIVE)
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, CHAT, INACTIVE)
    assert(#lines == 0, "still mythic-locked: no lift notice, got " .. #lines)
  end

  -- test_pew_with_api_unlocked_clears_stale_type5_and_restores_in_same_call
  do
    apiLocked = false
    local Bootstrap = newBootstrap()
    configureFilters(Bootstrap)
    Bootstrap.runtime.restrictedActions.updateFromEvent(CHAT, ACTIVE)
    Bootstrap.runtime.messagingNotice = Localization.Text(Common.COMPETITIVE_NOTICE)
    Presence.handlePlayerEnteringWorld(Bootstrap, enterWorldDeps)
    assert(Bootstrap.runtime.isChatLocked() == false, "stale cached chat lock is cleared")
    assert(Bootstrap._filtersRegistered == true, "filters come back in the same call")
    assert(Bootstrap.runtime.messagingNotice == nil, "notice clears in the same call")
  end

  -- test_pew_during_type5_activating_keeps_chat_lock
  do
    apiLocked = false
    local Bootstrap = newBootstrap()
    Bootstrap.runtime.restrictedActions.updateFromEvent(CHAT, ACTIVATING)
    Presence.handlePlayerEnteringWorld(Bootstrap, enterWorldDeps)
    assert(Bootstrap.runtime.isChatLocked() == true, "an Activating chat lock must survive entering the world")
  end

  _G.C_ChatInfo = saved.chatInfo
  _G.C_RestrictedActions = saved.restricted
  _G.C_Timer = saved.timer
  rawset(_G, "ChatFrame_AddMessageEventFilter", saved.addFilter)
  rawset(_G, "ChatFrame_RemoveMessageEventFilter", saved.removeFilter)
  rawset(_G, "DEFAULT_CHAT_FRAME", saved.chatFrame)
end
