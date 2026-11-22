local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The chat's part of the WoW: Forever gamepad UI: the D-pad stops on each
-- message. Sender labels, avatars and hover copy buttons are skipped: A
-- does nothing on them. The delivery-status button under a sender label
-- stays a stop: it is the only pad path to Retry / Discard.
-- No frame here gets a buttonContext: the game's buff refresh reads it on
-- the focused frame, and an addon value there taints that refresh.
local GamepadTranscript = {}

-- Varargs, not a table: this runs on every render.
local function tagChildren(nav, ...)
  for i = 1, select("#", ...) do
    local child = select(i, ...)
    if child._wmPlayerMenuOpener then
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
-- render: new labels and copy buttons are skipped, then the window is
-- re-scanned.
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
