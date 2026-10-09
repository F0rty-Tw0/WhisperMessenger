local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WhoLookup = ns.WhoLookup or require("WhisperMessenger.Transport.WhoLookup")

-- The two hardware events that may send a quiet /who: a contact row click
-- and a composer send. SendWho is protected, so these must run inside the
-- click or key press itself, never from a selection that code triggered.
local WhoTriggers = {}

local function tryFor(runtime, conversationKey)
  pcall(WhoLookup.TryFor, runtime, conversationKey)
end

function WhoTriggers.Create(runtime)
  return {
    onContactClicked = function(item)
      if item and item.conversationKey then
        tryFor(runtime, item.conversationKey)
      end
    end,
    wrapSend = function(onSend)
      return function(payload)
        if payload and payload.channel == "WOW" and payload.conversationKey then
          tryFor(runtime, payload.conversationKey)
        end
        return onSend(payload)
      end
    end,
  }
end

ns.BootstrapWindowRuntimeWhoTriggers = WhoTriggers

return WhoTriggers
