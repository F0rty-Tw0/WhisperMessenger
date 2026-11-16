-- Chat filters stay off wherever sends are held back. The decision comes from
-- the restriction instance's isRestricted(): detection flags, the 12.0 event
-- cache, its API fallback and the chat lock. A filter left on in restricted
-- content taints Blizzard's chat handling.
local RestrictionState = require("tests.helpers.restriction_state")
local ChatFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES
local SAVED_GLOBALS = { "ChatFrameUtil", "C_RestrictedActions", "C_ChatInfo", "_wmSuspended" }

-- apiActive[restrictionType] is what C_RestrictedActions answers.
local apiActive = {}

-- Whisper hiding on, plus one channel chat to hide.
local function configure(active)
  rawset(_G, "ChatFrameUtil", {
    AddMessageEventFilter = function(event, fn)
      active[event] = fn
    end,
    RemoveMessageEventFilter = function(event, fn)
      if active[event] == fn then
        active[event] = nil
      end
    end,
  })
  local accountState = {
    settings = { hideFromDefaultChat = true, hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } },
    filters = { ignored = {}, rules = {} },
  }
  local Bootstrap = {}
  ChatFilters.Configure(Bootstrap, accountState, { accountState = accountState, localPlayerGuid = "Player-1-SELF" })
  return Bootstrap
end

return function()
  local saved = {}
  for _, name in ipairs(SAVED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  rawset(_G, "_wmSuspended", nil)
  rawset(_G, "C_ChatInfo", nil)
  rawset(_G, "C_RestrictedActions", {
    IsAddOnRestrictionActive = function(restrictionType)
      return apiActive[restrictionType] == true
    end,
  })

  local ok, err = pcall(function()
    -- test_filters_registered_when_nothing_is_restricted
    do
      apiActive = {}
      local active = {}
      configure(active).syncChatFilters()
      assert(active.CHAT_MSG_WHISPER ~= nil, "whisper filter on in the open world")
      assert(active.CHAT_MSG_CHANNEL ~= nil, "channel filter on in the open world")
    end

    -- test_chat_filters_not_registered_when_only_api_reports_encounter
    -- Entering the world clears the flags; the game can still report the
    -- restriction, with no event to fill the cache.
    do
      apiActive = { [TYPES.Encounter] = true }
      local active = {}
      local Bootstrap = configure(active)
      RestrictionState.Set(Bootstrap, {})
      Bootstrap.syncChatFilters()
      assert(active.CHAT_MSG_WHISPER == nil, "no whisper filter while the game API reports an encounter")
      assert(active.CHAT_MSG_CHANNEL == nil, "no channel filter while the game API reports an encounter")
    end

    -- test_chat_filters_removed_when_only_cache_reports_pvp_match
    do
      apiActive = {}
      local active = {}
      local Bootstrap = configure(active)
      Bootstrap.syncChatFilters()
      RestrictedActions.For(Bootstrap).updateFromEvent(TYPES.PvPMatch, STATES.Active)
      Bootstrap.syncChatFilters()
      assert(next(active) == nil, "a PvP match only the cache knows about removes every filter")
    end

    -- test_chat_filters_return_when_the_restriction_lifts
    do
      apiActive = { [TYPES.Encounter] = true }
      local active = {}
      local Bootstrap = configure(active)
      Bootstrap.syncChatFilters()
      apiActive = {}
      Bootstrap.syncChatFilters()
      assert(active.CHAT_MSG_WHISPER ~= nil, "whisper filter back once the game stops reporting the encounter")
      assert(active.CHAT_MSG_CHANNEL ~= nil, "channel filter back once the game stops reporting the encounter")
    end

    -- test_suspended_addon_keeps_filters_off_without_any_restriction
    do
      apiActive = {}
      local active = {}
      local Bootstrap = configure(active)
      rawset(_G, "_wmSuspended", true)
      Bootstrap.syncChatFilters()
      rawset(_G, "_wmSuspended", nil)
      assert(next(active) == nil, "the Mythic+ suspend keeps every filter off on its own")
    end
  end)

  for _, name in ipairs(SAVED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end
