-- The runtime table has one declared shape: RuntimeFactory.CreateRuntimeState
-- gives a field its default, or RuntimeFactory.OPTIONAL_FIELDS names it as
-- nil until set. A field written from anywhere else fails here. The check is
-- on the live table, never on source text: the release build renames locals.
local RestrictionState = require("tests.helpers.restriction_state")
local RestrictionWorld = require("tests.helpers.restriction_world")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local SavedState = require("WhisperMessenger.Persistence.SavedState")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES

local WHISPER_KEY = "wow::WOW::arthas-area52"
local PARTY_KEY = "party::me"

local DEPS = {
  getContentDetector = function()
    return ContentDetector
  end,
  getPresenceCache = function()
    return nil
  end,
}

local function declaredFields()
  local accountState, characterState = SavedState.Initialize(nil, nil, "me")
  local declared = {}
  for key in pairs(RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {})) do
    declared[key] = true
  end
  for _, key in ipairs(RuntimeFactory.OPTIONAL_FIELDS) do
    declared[key] = true
  end
  return declared
end

local function boot(world)
  RestrictionState.Set(Bootstrap, {})
  local runtime = Bootstrap.Initialize(world.factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = {} },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
  Bootstrap.runtime = runtime
  return runtime
end

local function describe(what, undeclared)
  if #undeclared == 0 then
    return nil
  end
  table.sort(undeclared)
  return what .. " added " .. #undeclared .. " undeclared runtime field(s): " .. table.concat(undeclared, ", ")
end

-- Fails the moment a write creates a key that is not declared.
local function watchWrites(runtime, declared, undeclared)
  setmetatable(runtime, {
    __newindex = function(target, key, value)
      if not declared[key] then
        undeclared[#undeclared + 1] = tostring(key)
        declared[key] = true
      end
      rawset(target, key, value)
    end,
  })
end

local function routeLiveEvents(runtime)
  EventBridge.RouteLiveEvent(
    runtime,
    runtime.refreshWindow,
    "CHAT_MSG_WHISPER",
    "hello",
    "Arthas-Area52",
    "",
    "",
    "",
    "",
    0,
    0,
    "",
    0,
    101,
    "Player-3676-0ABCDEF1"
  )
  assert(runtime.store.conversations[WHISPER_KEY] ~= nil, "the whisper must reach the store")

  -- A typing packet from the same sender.
  EventBridge.RouteLiveEvent(runtime, runtime.refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas-Area52")

  local routed = EventBridge.RouteGroupEvent(
    runtime,
    "CHAT_MSG_PARTY",
    "hello party",
    "Thrall-Aggamaggan",
    "",
    "",
    "",
    "",
    0,
    0,
    "",
    0,
    501,
    "Player-1084-00000099"
  )
  assert(routed == true, "the party message must be routed")
  assert(runtime.store.conversations[PARTY_KEY] ~= nil, "the party message must reach the store")

  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Active)
  assert(runtime.messagingNotice ~= nil, "a challenge mode restriction must pause messaging")
  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Inactive)
  assert(runtime.messagingNotice == nil, "lifting the restriction must resume messaging")
end

return function()
  local savedMythicPlus = FlavorCompat.hasMythicPlus
  local savedTimer = rawget(_G, "C_Timer")
  FlavorCompat.hasMythicPlus = true
  -- The default fake runs a timer at once; the typing expiry would re-arm forever.
  rawset(_G, "C_Timer", { After = function() end })
  local failures = {}
  local world = RestrictionWorld.Install()
  local ok, err = pcall(function()
    RestrictionWorld.Start(world)

    -- test_initialize_adds_no_undeclared_field
    do
      local declared = declaredFields()
      local undeclared = {}
      for key in pairs(boot(world)) do
        if not declared[key] then
          undeclared[#undeclared + 1] = tostring(key)
        end
      end
      failures[#failures + 1] = describe("Bootstrap.Initialize", undeclared)
    end

    -- test_live_events_add_no_undeclared_field
    do
      local undeclared = {}
      local runtime = boot(world)
      watchWrites(runtime, declaredFields(), undeclared)
      routeLiveEvents(runtime)
      failures[#failures + 1] = describe("Live events", undeclared)
    end
  end)

  RestrictionWorld.Restore(world)
  RestrictionState.Set(Bootstrap, {})
  rawset(_G, "C_Timer", savedTimer)
  FlavorCompat.hasMythicPlus = savedMythicPlus
  assert(ok, err)
  assert(#failures == 0, table.concat(failures, "\n"))
end
