local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ManualCopy = {}
-- stylua: ignore start
local Clipboard = ns.ChatBubbleContextMenuManualCopyClipboard or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.Clipboard")
-- stylua: ignore end

ManualCopy.NormalizeText = Clipboard.NormalizeText
ManualCopy.CopyText = Clipboard.CopyText

ns.ChatBubbleContextMenuManualCopy = ManualCopy
return ManualCopy
