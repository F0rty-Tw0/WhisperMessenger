local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local EventUtils = ns.EventUtils or require("WhisperMessenger.Core.EventUtils")
local Trace = ns.trace or require("WhisperMessenger.Core.Trace")

local Registration = {}

local function traceSkippedEvent(eventName)
  if Trace then
    Trace("EventBridge: skipping unsupported event " .. tostring(eventName))
  end
end

local function registerEventIfSupported(frame, eventName)
  return EventUtils.RegisterEventIfSupported(frame, eventName, traceSkippedEvent)
end

local function unregisterEventIfSupported(frame, eventName)
  local ok, err = pcall(frame.UnregisterEvent, frame, eventName)
  if ok then
    return true
  end
  if EventUtils.IsUnknownEventError(err) then
    traceSkippedEvent(eventName)
    return false
  end
  error(err)
end

function Registration.RegisterLiveEvents(frame)
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function Registration.UnregisterLiveEvents(frame)
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

function Registration.RegisterChannelEvents(frame)
  for _, eventName in ipairs(Constants.CHANNEL_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function Registration.UnregisterChannelEvents(frame)
  for _, eventName in ipairs(Constants.CHANNEL_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

function Registration.RegisterGroupEvents(frame)
  for _, eventName in ipairs(Constants.GROUP_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function Registration.UnregisterGroupEvents(frame)
  for _, eventName in ipairs(Constants.GROUP_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

function Registration.RegisterSuspendableLifecycleEvents(frame)
  local essential = Constants.MYTHIC_ESSENTIAL_EVENTS or {}
  for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
    if not essential[eventName] then
      registerEventIfSupported(frame, eventName)
    end
  end
end

function Registration.UnregisterSuspendableLifecycleEvents(frame)
  local essential = Constants.MYTHIC_ESSENTIAL_EVENTS or {}
  for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
    if not essential[eventName] and frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

ns.BootstrapEventBridgeRegistration = Registration

return Registration
