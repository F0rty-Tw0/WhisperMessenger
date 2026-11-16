-- Bootstrap creates one restriction instance per runtime, before the window
-- runtime exists, and the runtime's predicates answer from it.
local FakeUI = require("tests.helpers.fake_ui")
local RestrictionState = require("tests.helpers.restriction_state")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

local TYPES = RestrictedActions.TYPES
local ACTIVE = RestrictedActions.STATES.Active

local function boot()
  local factory = FakeUI.NewFactory()
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  rawset(_G, "C_RestrictedActions", nil)
  rawset(_G, "C_ChatInfo", {
    InChatMessagingLockdown = function()
      return false
    end,
  })
  RestrictionState.Set(Bootstrap, {})
  return Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = {} },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
end

return function()
  local saved = {}
  for _, name in ipairs({ "UIParent", "C_ChatInfo", "C_RestrictedActions" }) do
    saved[name] = rawget(_G, name)
  end
  local savedRestrictions = Bootstrap.restrictions
  local createWindowRuntime = WindowRuntime.Create

  local ok, err = pcall(function()
    -- test_bootstrap_and_runtime_share_one_restriction_instance
    do
      local runtime = boot()
      assert(type(Bootstrap.restrictions) == "table", "Bootstrap must expose the restriction instance")
      assert(runtime.restrictedActions == Bootstrap.restrictions, "the runtime cache and Bootstrap.restrictions must be one object")
    end

    -- test_restriction_instance_exists_before_the_window_runtime
    do
      local seen
      WindowRuntime.Create = function(options)
        seen = options.bootstrap.restrictions
        return createWindowRuntime(options)
      end
      local runtime = boot()
      WindowRuntime.Create = createWindowRuntime
      assert(seen ~= nil, "the instance must exist when the window runtime is created")
      assert(seen == runtime.restrictedActions, "the window runtime must see the instance the runtime keeps")
    end

    -- test_instance_flags_are_the_bootstrap_fields
    do
      local runtime = boot()
      Bootstrap.restrictions.setFlag("encounter", true)
      assert(Bootstrap._inEncounter == true, "setFlag must write the field today's handlers read")
      assert(runtime.isCompetitiveContent() == true, "a flag set on the instance must reach runtime.isCompetitiveContent")
      RestrictionState.Set(Bootstrap, { mythic = true })
      assert(Bootstrap.restrictions.flag("mythic") == true, "a field today's handlers write must reach the instance")
      assert(Bootstrap.restrictions.flag("encounter") == false, "a cleared field must clear the flag")
      assert(runtime.isMythicLockdown() == true, "the mythic field must reach runtime.isMythicLockdown")
    end

    -- test_runtime_predicates_answer_from_the_instance
    do
      local runtime = boot()
      assert(Bootstrap.restrictions.isRestricted() == false, "nothing reported: not restricted")
      Bootstrap.restrictions.updateFromEvent(TYPES.PvPMatch, ACTIVE)
      assert(runtime.isCompetitiveContent() == true, "a cached PvP match must reach runtime.isCompetitiveContent")
      assert(runtime.isMythicLockdown() == false, "a PvP match is not a mythic lockdown")
      assert(Bootstrap.restrictions.isRestricted() == true, "a cached PvP match is restricted")
      Bootstrap.restrictions.updateFromEvent(TYPES.Chat, ACTIVE)
      assert(runtime.isChatLocked() == true, "a cached chat lock must reach runtime.isChatLocked")
    end
  end)

  WindowRuntime.Create = createWindowRuntime
  RestrictionState.Set(Bootstrap, {})
  Bootstrap.restrictions = savedRestrictions
  for _, name in ipairs({ "UIParent", "C_ChatInfo", "C_RestrictedActions" }) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end
