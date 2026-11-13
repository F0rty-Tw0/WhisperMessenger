local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local WhoLookup = ns.WhoLookup or require("WhisperMessenger.Transport.WhoLookup")

-- Hardware events that send a /who. A contact row click, a preview open, an
-- icon click that opens a chat, the Toggle Window and Reply keys, a plain
-- header click, Start New Whisper and a composer send trigger the quiet lookup
-- (AskFor); a click on another addon's preview card asks for its who name
-- first, before the addon's own onClick runs (AskForName); whoPlayer sends the visible
-- shift-click /who. A right-click
-- Whisper asks from AutoOpenCoordinator instead (askWho / askWhoForName),
-- except while another addon's card onClick runs (blocked by then). A
-- typed "/w Name " never asks: typing is not a hardware event for SendWho.
-- SendWho is protected, so these must run inside the click or key press
-- itself and before the window opens or the selection changes, never from a
-- selection that code triggered.
local WhoTriggers = {}

-- The quiet lookup for the chat a hardware event just opened or sent to.
function WhoTriggers.AskFor(runtime, conversationKey)
  pcall(WhoLookup.TryFor, runtime, conversationKey)
end

-- The quiet lookup for a player a hardware event is about to open by name
-- (another addon's preview click), before the chat may exist.
function WhoTriggers.AskForName(runtime, playerName)
  pcall(function()
    WhoLookup.TryForName(runtime, playerName, Identity.ResolveWhisperConversation(runtime, playerName, "WOW"))
  end)
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
