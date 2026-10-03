local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Asks for an optional reason, then adds a player to the silent ignore list.
-- Shared by the Filters page and the right-click "Ignore…" menus.
local IgnorePrompt = {}

local REASON_DIALOG = "WHISPER_MESSENGER_IGNORE_REASON"
local REASON_MAX_LETTERS = 64

local function trim(value)
  return string.match(value or "", "^%s*(.-)%s*$")
end

-- opts = { duration (seconds; nil = forever), onIgnored(entry) }.
function IgnorePrompt.Ask(filters, name, opts)
  opts = opts or {}
  return TextInputDialog.Show(REASON_DIALOG, {
    prompt = Localization.Text("Reason (optional)"),
    accept = Localization.Text("OK"),
    maxLetters = REASON_MAX_LETTERS,
    onAccept = function(typed)
      local reason = trim(typed)
      local entry = IgnoreList.Add(filters, name, {
        reason = reason ~= "" and reason or nil,
        duration = opts.duration,
      })
      if entry ~= nil and opts.onIgnored then
        opts.onIgnored(entry)
      end
    end,
  })
end

ns.IgnorePrompt = IgnorePrompt
return IgnorePrompt
