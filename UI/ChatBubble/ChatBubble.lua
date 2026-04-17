local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatBubble = {}

ChatBubble.ShouldGroup = (ns.ChatBubbleGrouping or require("WhisperMessenger.UI.ChatBubble.Grouping")).ShouldGroup
ChatBubble.CreateBubble = (ns.ChatBubbleBubbleFrame or require("WhisperMessenger.UI.ChatBubble.BubbleFrame")).CreateBubble
ChatBubble.CreateDateSeparator = (ns.ChatBubbleDateSeparator or require("WhisperMessenger.UI.ChatBubble.DateSeparator")).CreateDateSeparator
ChatBubble.LayoutMessages = (ns.ChatBubbleLayout or require("WhisperMessenger.UI.ChatBubble.Layout")).LayoutMessages

ns.ChatBubble = ChatBubble
return ChatBubble
