local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ManualCopy = {}
local Clipboard = ns.ChatBubbleContextMenuManualCopyClipboard
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.Clipboard")

ManualCopy.NormalizeText = Clipboard.NormalizeText
ManualCopy.CopyText = Clipboard.CopyText

ns.ChatBubbleContextMenuManualCopy = ManualCopy
return ManualCopy
