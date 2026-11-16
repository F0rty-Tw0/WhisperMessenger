-- The game as the restricted-content readers see it: faked chat and
-- restriction APIs, the chat filter registry, and the real event frame and
-- lockdown catcher installed over the real Bootstrap table.
local FakeUI = require("tests.helpers.fake_ui")
local RestrictionState = require("tests.helpers.restriction_state")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local AddonEventFrame = require("WhisperMessenger.Core.Bootstrap.AddonEventFrame")
local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local RestrictionWorld = {}

local SAVED_GLOBALS = { "UIParent", "C_RestrictedActions", "C_ChatInfo", "ChatFrameUtil", "issecretvalue", "_wmSuspended" }
local SAVED_FIELDS = {
  "runtime",
  "onCompetitiveStateChanged",
  "_loadFrame",
  "_lockdownCatcher",
  "restrictions",
}

local function fakeFrame(frames)
  return function(_frameType, name)
    local frame = { scripts = {} }
    function frame:RegisterEvent() end
    function frame:UnregisterEvent() end
    function frame:SetScript(script, handler)
      self.scripts[script] = handler
    end
    frames[name] = frame
    return frame
  end
end

-- Only the modules the event frame hands a whisper on to are stand-ins.
local function installEventFrames(world)
  local frames = {}
  local bridge = {
    RouteChannelEvent = function()
      return false
    end,
    RouteGroupEvent = function()
      return false
    end,
    RouteLiveEvent = function()
      world.routed = true
    end,
  }
  local lifecycle = {
    Handle = function()
      return false
    end,
  }
  AddonEventFrame.Install({
    Bootstrap = Bootstrap,
    createFrame = fakeFrame(frames),
    loadModule = function(_name, key)
      return key == "BootstrapEventBridge" and bridge or lifecycle
    end,
  })
  world.eventFrame = frames.WhisperMessengerLoadFrame
  world.catcherFrame = frames.WhisperMessengerLockdownCatcher
  world.catcher = Bootstrap._lockdownCatcher
end

local function installGlobals(world)
  rawset(_G, "issecretvalue", function()
    return false
  end)
  rawset(_G, "C_ChatInfo", {
    InChatMessagingLockdown = function()
      return world.chatInfoLocked
    end,
    GetChatLineText = function()
      return ""
    end,
  })
  rawset(_G, "ChatFrameUtil", {
    AddMessageEventFilter = function(event, fn)
      world.filters[event] = fn
    end,
    RemoveMessageEventFilter = function(event, fn)
      if world.filters[event] == fn then
        world.filters[event] = nil
      end
    end,
  })
  local uiParent = world.factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(1920, 1080)
  rawset(_G, "UIParent", uiParent)
end

-- world fields the caller sets: chatInfoLocked (C_ChatInfo's answer) and
-- apiSaysYes[restrictionType] (C_RestrictedActions' answer). Fields it
-- reads: filters[event], routed, isMythicRestricted, eventFrame,
-- catcherFrame, catcher, restrictedApi, factory.
function RestrictionWorld.Install()
  local world = { factory = FakeUI.NewFactory(), filters = {}, apiSaysYes = {}, chatInfoLocked = false, saved = {} }
  for _, name in ipairs(SAVED_GLOBALS) do
    world.saved[name] = rawget(_G, name)
  end
  for _, name in ipairs(SAVED_FIELDS) do
    world.saved[name] = Bootstrap[name]
  end
  world.savedFlags = {}
  for _, name in ipairs(RestrictionState.NAMES) do
    world.savedFlags[name] = RestrictionState.Flag(Bootstrap, name)
  end
  world.createCoordinator = WindowCoordinator.Create
  -- WindowRuntime keeps isMythicRestricted to itself and hands it only to
  -- its coordinator, so take the real closure from there.
  WindowCoordinator.Create = function(options)
    world.isMythicRestricted = options.isMythicRestricted
    return world.createCoordinator(options)
  end
  world.restrictedApi = {
    IsAddOnRestrictionActive = function(restrictionType)
      return world.apiSaysYes[restrictionType] == true
    end,
  }
  return world
end

-- Separate from Install so a failure in here is still followed by Restore.
function RestrictionWorld.Start(world)
  installGlobals(world)
  installEventFrames(world)
end

function RestrictionWorld.Restore(world)
  WindowCoordinator.Create = world.createCoordinator
  RestrictionState.Set(Bootstrap, world.savedFlags)
  for _, name in ipairs(SAVED_FIELDS) do
    Bootstrap[name] = world.saved[name]
  end
  for _, name in ipairs(SAVED_GLOBALS) do
    rawset(_G, name, world.saved[name])
  end
end

return RestrictionWorld
