local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonGreetings = ns.AddonGreetings or require("WhisperMessenger.Model.AddonGreetings")

-- Router glue for addon greetings. The router only calls in with payloads
-- free of secret values; whispers replayed after a chat lockdown are never
-- tagged, since their announcement could not be heard during the lock.
local AddonGreetingIngest = {}

local function settingsOf(state)
  return state.accountState and state.accountState.settings or nil
end

function AddonGreetingIngest.RecordAnnouncement(state, payload)
  if payload.channel ~= "WHISPER" then
    return
  end
  AddonGreetings.Record(state, payload.playerName, payload.text, state.now and state.now() or 0)
end

-- Returns the addon name for a live character whisper that follows an
-- announcement, and whether the "Hide" setting keeps it out of the window.
function AddonGreetingIngest.ClaimForWhisper(state, contact, payload, now)
  if payload.replayedAt ~= nil or contact == nil then
    return nil, false
  end
  local tag = AddonGreetings.Claim(state, contact.contactKey, now)
  if tag == nil then
    return nil, false
  end
  return tag, AddonGreetings.Mode(settingsOf(state)) == AddonGreetings.MODE_HIDE
end

-- "Send to Requests": the conversation this greeting opened waits in Requests.
function AddonGreetingIngest.ClassifyNew(state, conversation)
  if type(conversation) == "table" and AddonGreetings.Mode(settingsOf(state)) == AddonGreetings.MODE_REQUESTS then
    conversation.request = true
  end
end

ns.EventRouterAddonGreetingIngest = AddonGreetingIngest
return AddonGreetingIngest
