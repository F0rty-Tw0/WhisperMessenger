local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ConversationExport = ns.ConversationExport or require("WhisperMessenger.Model.ConversationExport")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")

-- "Export conversation": the whole conversation as plain text in the
-- manual-copy popup, selected for Ctrl+C (addons can't write the clipboard).
-- Any row whose item carries its conversation: whispers, Battle.net, groups
-- and channels.
local ExportMenuEntry = {}

local COPY_OPTIONS = { prompt = "Press Ctrl+C to copy the conversation.", multiLine = true }

function ExportMenuEntry.Open(item)
  local text = ConversationExport.Format(item.conversation.messages, {
    contactName = DisplayName.Format(item.displayName),
    playerName = LocalPlayer.Name(),
  })
  return PopupUI.ShowManualCopyDialog(text, COPY_OPTIONS)
end

function ExportMenuEntry.Add(rootDescription, item)
  local conversation = item.conversation
  if type(conversation) ~= "table" or type(conversation.messages) ~= "table" then
    return
  end
  rootDescription:CreateButton(Localization.Text("Export conversation"), function()
    ExportMenuEntry.Open(item)
  end)
end

ns.ContactsListExportMenuEntry = ExportMenuEntry
return ExportMenuEntry
