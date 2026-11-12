local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WhoLookup = ns.WhoLookup or require("WhisperMessenger.Transport.WhoLookup")

-- Hardware events that send a /who. A contact row click, a preview open, an
-- icon click that opens a chat, the Toggle Window and Reply keys, a plain
-- header click, Start New Whisper and a composer send trigger the quiet lookup
-- (AskFor); whoPlayer sends the visible shift-click /who. A right-click
-- Whisper asks from AutoOpenCoordinator instead (askWho / askWhoForName). A
-- typed "/w Name " never asks: typing is not a hardware event for SendWho.
-- SendWho is protected, so these must run inside the click or key press
-- itself and before the window opens or the selection changes, never from a
-- selection that code triggered.
local WhoTriggers = {}

-- The quiet lookup for the chat a hardware event just opened or sent to.
function WhoTriggers.AskFor(runtime, conversationKey)
  pcall(WhoLookup.TryFor, runtime, conversationKey)
end

function WhoTriggers.Create(runtime)
  return {
    onContactClicked = function(item)
      if item and item.conversationKey then
        WhoTriggers.AskFor(runtime, item.conversationKey)
      end
    end,
    onHeaderClicked = function(conversationKey)
      if conversationKey then
        WhoTriggers.AskFor(runtime, conversationKey)
      end
    end,
    whoPlayer = function(name)
      pcall(WhoLookup.SendVisible, name)
    end,
    wrapSend = function(onSend)
      return function(payload)
        if payload and payload.channel == "WOW" and payload.conversationKey then
          WhoTriggers.AskFor(runtime, payload.conversationKey)
        end
        return onSend(payload)
      end
    end,
  }
end

ns.BootstrapWindowRuntimeWhoTriggers = WhoTriggers

return WhoTriggers
