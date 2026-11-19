-- Drives the real modules through every combination of restricted-content
-- inputs and reports what each reader of that state answers. Not every
-- reader uses the same formula yet, so a row can hold answers that disagree;
-- the table pins each one as it is.
local RestrictionState = require("tests.helpers.restriction_state")
local RestrictionWorld = require("tests.helpers.restriction_world")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES

local TruthTable = {}

-- One answer per reader, in this order, in every row.
TruthTable.READERS = {
  "isCompetitiveContent", -- runtime.isCompetitiveContent()
  "isMythicLockdown", -- runtime.isMythicLockdown()
  "isChatLocked", -- runtime.isChatLocked()
  "isChannelIngestSuspended", -- runtime.isChannelIngestSuspended()
  "queuedSendsLocked", -- runtime.queuedSendsLocked after the notification
  "competitiveNotified", -- what Common.notifyCompetitiveState reports
  "messagingNotice", -- shown, cleared, or kept (left to the Mythic+ suspend)
  "whisperFilters", -- Bootstrap.syncChatFilters registered the whisper filters
  "conditionalFilters", -- ... and the channel filter
  "windowMythicRestricted", -- isMythicRestricted() in WindowRuntime
  "eventFrameRoutesWhisper", -- AddonEventFrame lets a live whisper through
  "catcherHoldsWhisper", -- LockdownCatcher holds a readable whisper
}

-- How the game reports one restriction type: "none" and "api" leave the
-- event cache empty (the API fallback says no / yes); the others cache a
-- state. "inactive" has the API say yes, which the cache must overrule.
local LOCK_STATES = { "none", "api", "inactive", "active" }
local CACHED_STATE = { inactive = STATES.Inactive, activating = STATES.Activating, active = STATES.Active }
local API_SAYS_YES = { api = true, inactive = true }
-- "info": C_ChatInfo.InChatMessagingLockdown. The others report restriction
-- type Chat the way LOCK_STATES does; "cached" is an Active event. "info"
-- follows "off" because the two share a runtime.
local CHAT_LOCKS = { "off", "info", "cached", "api", "inactive", "activating" }
local CHAT_LOCK_STATE = { off = "none", cached = "active", api = "api", inactive = "inactive", activating = "activating" }
-- The string stands in for nil, which a list cannot hold.
local SUSPENDED_VALUES = { "nil", false, true }
-- 1: a truthy value that is not true still sets a flag.
local FLAG_VALUES = { "nil", false, true, 1 }
local NOTICE_KEPT = "kept by the truth table"
local LINE_ID = 9

local function unbox(value)
  if value == "nil" then
    return nil
  end
  return value
end

local function lockScenarios()
  local list = {}
  for _, encounter in ipairs(LOCK_STATES) do
    for _, challenge in ipairs(LOCK_STATES) do
      for _, pvp in ipairs(LOCK_STATES) do
        list[#list + 1] = { encounterLock = encounter, challengeLock = challenge, pvpLock = pvp, api = true }
      end
    end
  end
  for _, name in ipairs({ "encounterLock", "challengeLock", "pvpLock" }) do
    local scenario = { encounterLock = "none", challengeLock = "none", pvpLock = "none", api = true }
    scenario[name] = "activating"
    list[#list + 1] = scenario
  end
  -- A client without C_RestrictedActions.
  list[#list + 1] = { encounterLock = "none", challengeLock = "none", pvpLock = "none", api = false }
  return list
end

local function reportLock(world, runtime, restrictionType, lockState)
  world.apiSaysYes[restrictionType] = API_SAYS_YES[lockState] == true
  if CACHED_STATE[lockState] ~= nil then
    runtime.restrictedActions.updateFromEvent(restrictionType, CACHED_STATE[lockState])
  end
end

-- A fresh runtime, because a cached restriction state cannot be emptied.
local function boot(world, scenario, chatLockState)
  RestrictionState.Set(Bootstrap, {})
  RestrictionState.SetSuspended(false)
  rawset(_G, "C_RestrictedActions", scenario.api and world.restrictedApi or nil)
  world.filters = {}
  world.apiSaysYes = {}
  world.chatInfoLocked = false
  local runtime = Bootstrap.Initialize(world.factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = { hideFromDefaultChat = true, hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } },
    },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
  Bootstrap.runtime = runtime
  local notify = Bootstrap.onCompetitiveStateChanged
  Bootstrap.onCompetitiveStateChanged = function(isActive)
    world.notified = isActive
    return notify(isActive)
  end
  reportLock(world, runtime, TYPES.Encounter, scenario.encounterLock)
  reportLock(world, runtime, TYPES.ChallengeMode, scenario.challengeLock)
  reportLock(world, runtime, TYPES.PvPMatch, scenario.pvpLock)
  reportLock(world, runtime, TYPES.Chat, chatLockState)
  return runtime
end

local function noticeAnswer(notice)
  if notice == NOTICE_KEPT then
    return "kept"
  end
  return notice == nil and "cleared" or "shown"
end

local function readAnswers(world, runtime, answers)
  answers[1] = runtime.isCompetitiveContent()
  answers[2] = runtime.isMythicLockdown()
  answers[3] = runtime.isChatLocked()
  answers[4] = runtime.isChannelIngestSuspended()

  runtime.messagingNotice = NOTICE_KEPT
  world.notified = "not called"
  Common.notifyCompetitiveState(Bootstrap)
  answers[5] = runtime.queuedSendsLocked
  answers[6] = world.notified
  answers[7] = noticeAnswer(runtime.messagingNotice)

  Bootstrap.syncChatFilters()
  answers[8] = world.filters.CHAT_MSG_WHISPER ~= nil
  answers[9] = world.filters.CHAT_MSG_CHANNEL ~= nil

  answers[10] = world.isMythicRestricted()

  world.routed = false
  world.eventFrame.scripts.OnEvent(world.eventFrame, "CHAT_MSG_WHISPER", "hi", "Arthas-Area52")
  answers[11] = world.routed

  local onCatcherEvent = world.catcherFrame.scripts.OnEvent
  onCatcherEvent(world.catcherFrame, "CHAT_MSG_WHISPER", "hi", "Arthas-Area52", nil, nil, nil, nil, nil, nil, nil, nil, LINE_ID, "Player-1-ABC")
  answers[12] = #world.catcher.drain() == 1
end

local function label(inputs)
  return string.format(
    "encounterLock=%s challengeLock=%s pvpLock=%s api=%s chatLock=%s suspended=%s mythic=%s competitive=%s encounter=%s",
    inputs.encounterLock,
    inputs.challengeLock,
    inputs.pvpLock,
    tostring(inputs.api),
    inputs.chatLock,
    tostring(inputs.suspended),
    tostring(inputs.mythic),
    tostring(inputs.competitive),
    tostring(inputs.encounter)
  )
end

-- Every suspended x flag combination under one booted scenario.
local function visitFlagRows(world, runtime, inputs, visit)
  local answers = {}
  local rows = 0
  for _, suspended in ipairs(SUSPENDED_VALUES) do
    inputs.suspended = unbox(suspended)
    RestrictionState.SetSuspended(inputs.suspended)
    for _, mythic in ipairs(FLAG_VALUES) do
      for _, competitive in ipairs(FLAG_VALUES) do
        for _, encounter in ipairs(FLAG_VALUES) do
          inputs.mythic, inputs.competitive, inputs.encounter = unbox(mythic), unbox(competitive), unbox(encounter)
          RestrictionState.Set(Bootstrap, inputs)
          readAnswers(world, runtime, answers)
          visit(label(inputs), inputs, answers)
          rows = rows + 1
        end
      end
    end
  end
  return rows
end

local function visitScenario(world, scenario, visit)
  local rows = 0
  local runtime
  for _, chatLock in ipairs(CHAT_LOCKS) do
    -- The API fallback needs the API.
    if scenario.api or chatLock ~= "api" then
      -- "off" and "info" differ only in what the chat API answers, so they share a runtime.
      if chatLock ~= "info" then
        runtime = boot(world, scenario, CHAT_LOCK_STATE[chatLock])
      end
      world.chatInfoLocked = chatLock == "info"
      local inputs = {
        encounterLock = scenario.encounterLock,
        challengeLock = scenario.challengeLock,
        pvpLock = scenario.pvpLock,
        api = scenario.api,
        chatLock = chatLock,
      }
      rows = rows + visitFlagRows(world, runtime, inputs, visit)
    end
  end
  return rows
end

-- Calls visit(label, inputs, answers) for every row and returns the row
-- count. inputs and answers are reused between rows: copy what you keep.
function TruthTable.Run(visit)
  local world = RestrictionWorld.Install()
  local ok, result = pcall(function()
    RestrictionWorld.Start(world)
    local rows = 0
    for _, scenario in ipairs(lockScenarios()) do
      rows = rows + visitScenario(world, scenario, visit)
    end
    return rows
  end)
  RestrictionWorld.Restore(world)
  assert(ok, result)
  return result
end

return TruthTable
