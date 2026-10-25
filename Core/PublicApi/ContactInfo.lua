local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")

-- SetContactInfo: a one-line note under a player's name in their chat.
-- Text nil removes the caller's note.
local PublicContactInfo = {}

function PublicContactInfo.Install(api, runtime)
  api.SetContactInfo = Guards.Wrap(function(sourceKey, playerName, text)
    if not ContactInfo.Set(runtime.contactInfo, sourceKey, playerName, text) then
      return false
    end
    if runtime.isWindowVisible() then
      runtime.refreshWindow()
    end
    return true
  end)
end

ns.PublicApiContactInfo = PublicContactInfo
return PublicContactInfo
