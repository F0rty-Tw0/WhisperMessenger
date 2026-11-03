local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ConversationExport = ns.ConversationExport or require("WhisperMessenger.Model.ConversationExport")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")

-- "Export conversation": the conversation as plain text in the export
-- panel. Any row whose item carries its conversation: whispers, Battle.net,
-- groups and channels.
local ExportMenuEntry = {}

function ExportMenuEntry.Open(item)
  -- The panel loads after the contacts menu (it needs the settings
  -- controls), so it is looked up on click.
  local ExportPanel = ns.ContactsListExportPanel or require("WhisperMessenger.UI.ContactsList.ExportPanel")
  local contactName = DisplayName.Format(item.displayName)
  local names = { contactName = contactName, playerName = LocalPlayer.Name() }
  return ExportPanel.Show({
    title = contactName,
    header = ConversationExport.Header(names),
    lines = ConversationExport.Lines(item.conversation.messages, names),
  })
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
