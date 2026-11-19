local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GamepadNav = ns.MessengerWindowGamepadNav or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

-- The chat's part of the WoW: Forever gamepad UI: the D-pad stops on each
-- message, and X opens its right-click menu. Sender labels, avatars and
-- hover copy buttons are skipped: A does nothing on them, and the chat
-- header's X opens the same player menu. The delivery-status button under
-- a sender label stays a stop: it is the only pad path to Retry / Discard.
local GamepadTranscript = {}

-- Varargs, not a table: this runs on every render.
local function tagChildren(nav, ...)
  for i = 1, select("#", ...) do
    local child = select(i, ...)
    if child._wmBubbleResult then
      child.buttonContext = GamepadNav.RIGHT_CLICK_CONTEXT
    elseif child._wmPlayerMenuOpener then
      nav.ignore(child, true)
    elseif child._wmCopyBubble then
      nav.ignore(child)
    end
  end
end

local function tag(nav, content)
  tagChildren(nav, content:GetChildren())
end

-- transcript: { content } (TranscriptView's). Sets
-- transcript.onNavTargetsChanged, which TranscriptView calls after each
-- render: new bubbles are tagged, then the window is re-scanned.
function GamepadTranscript.Attach(nav, transcript)
  local content = transcript.content
  tag(nav, content)
  transcript.onNavTargetsChanged = function()
    tag(nav, content)
    nav.refresh()
  end
end

ns.MessengerWindowGamepadTranscript = GamepadTranscript

return GamepadTranscript
