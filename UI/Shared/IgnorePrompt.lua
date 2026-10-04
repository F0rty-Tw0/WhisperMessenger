local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Asks for the optional reason before a player goes on the silent block
-- list. Shared by the Filters page and the right-click "Block…" menus.
local IgnorePrompt = {}

local REASON_DIALOG = "WHISPER_MESSENGER_IGNORE_REASON"
local REASON_MAX_LETTERS = 64

local function trim(value)
  return string.match(value or "", "^%s*(.-)%s*$")
end

-- onReason(reason): the trimmed reason, or nil when left empty. Not called
-- when the player cancels.
function IgnorePrompt.AskReason(onReason)
  return TextInputDialog.Show(REASON_DIALOG, {
    prompt = Localization.Text("Reason (optional)"),
    accept = Localization.Text("OK"),
    maxLetters = REASON_MAX_LETTERS,
    onAccept = function(typed)
      local reason = trim(typed)
      onReason(reason ~= "" and reason or nil)
    end,
  })
end

ns.IgnorePrompt = IgnorePrompt
return IgnorePrompt
