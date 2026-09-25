local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The one place that decides whether an incoming whisper may alert the
-- player: sound, widget popup, taskbar flash and auto-open all ask here.
-- Group mentions bypass it and alert directly (they break through mute).
local AlertPolicy = {}

local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")

-- settings: account settings; a message request (only while the Requests
-- inbox is on) never alerts.
function AlertPolicy.ShouldAlert(conversation, settings)
  if type(conversation) ~= "table" then
    return true
  end
  if MessageRequests.IsRequest(conversation, settings) then
    return false
  end
  return conversation.muted ~= true
end

ns.AlertPolicy = AlertPolicy
return AlertPolicy
