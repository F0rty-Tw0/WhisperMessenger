local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")

-- SetContactInfo(sourceKey, playerName, text, tooltipLines?): a one-line
-- note under a player's name in their chat. Text nil or blank removes the
-- caller's note and its tooltip. tooltipLines, when given, is an array of 1 to
-- 10 non-empty strings (color codes allowed) shown when the player hovers the
-- note; the first line shows as the tooltip's title. WM keeps a copy, so
-- changing the table later changes nothing. A call with text but no
-- tooltipLines clears the caller's old tooltip. Any other tooltipLines value
-- returns false and changes nothing.
local PublicContactInfo = {}

function PublicContactInfo.Install(api, runtime)
  api.SetContactInfo = Guards.Wrap(function(sourceKey, playerName, text, tooltipLines)
    if not ContactInfo.Set(runtime.contactInfo, sourceKey, playerName, text, runtime, tooltipLines) then
      return false
    end
    -- Only the open chat's strip can change.
    if runtime.isWindowVisible() and ContactInfo.ResolvesTo(runtime, playerName, runtime.activeConversationKey) then
      runtime.refreshWindow()
    end
    return true
  end)
end

ns.PublicApiContactInfo = PublicContactInfo
return PublicContactInfo
