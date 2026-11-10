local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- InsertLink(text) -> boolean: drops a chat link into the Whisper Messenger
-- message box the player is typing in, after what is already there.
-- text is a non-blank string of at most 255 bytes (one chat message), such as
-- "|Hitem:...|h[Name]|h". It does not open the window or pick a conversation:
-- it returns true only when the message box is shown, has keyboard focus and
-- really took the text. It returns false, and inserts nothing, when text is
-- not valid, would pass the box's length limit, the box is not focused, a
-- second insert lands in the same frame, content restrictions apply, or the
-- player refused the caller. It never throws.
-- Detect support with `type(api.InsertLink) == "function"`: older Whisper
-- Messenger versions lack it, and `version` does not change.
local InsertLink = {}

local function isValidText(text)
  return Guards.IsNonEmptyString(text) and #text <= TextLimits.MESSAGE_MAX_BYTES
end

function InsertLink.Install(api, runtime)
  api.InsertLink = Guards.Wrap(function(text)
    if not isValidText(text) or Guards.IsRefused(runtime) then
      return false
    end
    return LinkHooks.InsertText(text)
  end)
end

ns.PublicApiInsertLink = InsertLink
return InsertLink
