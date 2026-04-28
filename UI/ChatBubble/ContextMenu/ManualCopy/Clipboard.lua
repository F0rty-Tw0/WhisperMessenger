local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Clipboard = {}
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")

function Clipboard.NormalizeText(text)
  if text == nil then
    return nil
  end

  local value = tostring(text)
  if value == "" then
    return nil
  end

  return value
end

function Clipboard.CopyText(text)
  local normalized = Clipboard.NormalizeText(text)
  if normalized == nil then
    return false
  end

  if type(_G.C_Clipboard) == "table" then
    local candidates = { "SetClipboard", "SetClipboardText", "SetText", "CopyText", "CopyToClipboard" }
    for _, methodName in ipairs(candidates) do
      local method = _G.C_Clipboard[methodName]
      if type(method) == "function" then
        local ok = pcall(method, normalized)
        if ok then
          return true
        end

        ok = pcall(method, _G.C_Clipboard, normalized)
        if ok then
          return true
        end
      end
    end
  end

  return PopupUI.ShowManualCopyDialog(normalized)
end

ns.ChatBubbleContextMenuManualCopyClipboard = Clipboard
return Clipboard
