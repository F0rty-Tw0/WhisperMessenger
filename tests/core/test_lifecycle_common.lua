-- The "messages are paused" notice and the icon follow the restriction
-- instance's isRestricted(): detection flags, 12.0 event cache, API fallback
-- and chat lock together. Sends are held by the same answer, so the notice
-- can no longer be missing while they are.
local RestrictionState = require("tests.helpers.restriction_state")
local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local Localization = require("WhisperMessenger.Locale.Localization")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES
local KEPT = "left alone"

-- apiActive[restrictionType] is what C_RestrictedActions answers.
local apiActive = {}

local function newBootstrap()
  local told = {}
  local Bootstrap = {
    runtime = { messagingNotice = KEPT, store = { conversations = {} } },
    onCompetitiveStateChanged = function(isActive)
      told[#told + 1] = isActive
    end,
  }
  Bootstrap.runtime.restrictedActions = RestrictedActions.For(Bootstrap)
  return Bootstrap, told
end

return function()
  Localization.Configure({ language = "enUS" })
  local saved = { restricted = rawget(_G, "C_RestrictedActions"), chatInfo = rawget(_G, "C_ChatInfo") }
  rawset(_G, "C_ChatInfo", nil)
  rawset(_G, "C_RestrictedActions", {
    IsAddOnRestrictionActive = function(restrictionType)
      return apiActive[restrictionType] == true
    end,
  })
  local notice = Localization.Text(Common.COMPETITIVE_NOTICE)

  local ok, err = pcall(function()
    -- test_notice_cleared_when_nothing_is_restricted
    do
      apiActive = {}
      local Bootstrap, told = newBootstrap()
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == nil, "nothing restricted clears the notice")
      assert(told[1] == false, "the icon is told nothing is restricted")
    end

    -- test_competitive_notice_shown_when_only_cache_reports_pvp_match
    do
      apiActive = {}
      local Bootstrap, told = newBootstrap()
      Bootstrap.restrictions.updateFromEvent(TYPES.PvPMatch, STATES.Active)
      assert(RestrictionState.Flag(Bootstrap, "competitive") == false, "the flags know nothing of the match")
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == notice, "a PvP match only the cache knows about shows the notice")
      assert(told[1] == true, "the icon is told about a cached PvP match")
    end

    -- test_competitive_notice_shown_when_only_the_api_reports_an_encounter
    -- Entering the world clears the flags; the game can still report the
    -- restriction, with no event to fill the cache.
    do
      apiActive = { [TYPES.Encounter] = true }
      local Bootstrap, told = newBootstrap()
      RestrictionState.Set(Bootstrap, {})
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == notice, "an encounter only the game API reports shows the notice")
      assert(told[1] == true, "the icon is told about an API-reported encounter")
    end

    -- test_cached_inactive_overrules_the_api
    do
      apiActive = { [TYPES.Encounter] = true }
      local Bootstrap, told = newBootstrap()
      Bootstrap.restrictions.updateFromEvent(TYPES.Encounter, STATES.Inactive)
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == nil, "an Inactive event wins over the API, so the notice clears")
      assert(told[1] == false, "the icon is told nothing is restricted")
    end

    -- test_mythic_suspend_keeps_ownership_of_the_notice
    do
      apiActive = {}
      local Bootstrap, told = newBootstrap()
      RestrictionState.Set(Bootstrap, { mythic = true })
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == KEPT, "the Mythic+ suspend owns the notice while the mythic flag is set")
      assert(told[1] == true, "the icon is still told")
    end

    -- test_notice_shown_for_a_key_the_addon_has_not_suspended_for
    -- Only the game reports the key: no suspend ran, so nothing else would
    -- show a notice while sends are held.
    do
      apiActive = { [TYPES.ChallengeMode] = true }
      local Bootstrap, told = newBootstrap()
      Common.notifyCompetitiveState(Bootstrap)
      assert(Bootstrap.runtime.messagingNotice == notice, "a key without a suspend still shows the paused notice")
      assert(told[1] == true, "the icon is told about the key")
    end
  end)

  rawset(_G, "C_RestrictedActions", saved.restricted)
  rawset(_G, "C_ChatInfo", saved.chatInfo)
  assert(ok, err)
end
