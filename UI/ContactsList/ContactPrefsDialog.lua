local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ContactPrefs = ns.ContactPrefs or require("WhisperMessenger.Model.ContactPrefs")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- Text-entry popups for a contact's nickname and note. The typed text goes
-- to onSave untouched (ContactPrefs trims, caps and clears).
local ContactPrefsDialog = {}

local NICKNAME_DIALOG = "WHISPER_MESSENGER_SET_NICKNAME"
local NOTE_DIALOG = "WHISPER_MESSENGER_EDIT_NOTE"

local function show(dialogName, limits, promptKey, item, currentValue, onSave)
  return TextInputDialog.Show(dialogName, {
    prompt = Localization.Text(promptKey),
    accept = Localization.Text("Save"),
    maxLetters = limits.maxLetters,
    maxBytes = limits.maxBytes,
    textArg = item.displayName or item.battleTag or "",
    value = currentValue or "",
    onAccept = onSave,
  })
end

function ContactPrefsDialog.ShowNickname(item, onSave)
  local limits = { maxLetters = ContactPrefs.MAX_NICKNAME_CHARS }
  return show(NICKNAME_DIALOG, limits, "Set a nickname for %s. Leave empty to remove it.", item, item.nickname, onSave)
end

function ContactPrefsDialog.ShowNote(item, onSave)
  local limits = { maxBytes = TextLimits.INPUT_MAX_BYTES }
  return show(NOTE_DIALOG, limits, "Note for %s. Leave empty to remove it.", item, item.note, onSave)
end

ns.ContactsListContactPrefsDialog = ContactPrefsDialog
return ContactPrefsDialog
