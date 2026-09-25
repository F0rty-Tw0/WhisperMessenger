local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

-- Grey tooltip lines naming the keys that open WhisperMessenger (widget and
-- minimap icon tooltips).
local KeybindHints = {}

local HINT_GREY = PickerStyles.HINT_GREY

-- Display names for every key bound to the action returned by GetBindingKey.
local function keyNames(...)
  local names = {}
  for i = 1, select("#", ...) do
    local key = select(i, ...)
    if type(key) == "string" and key ~= "" then
      names[#names + 1] = type(_G.GetBindingText) == "function" and _G.GetBindingText(key) or key
    end
  end
  return names
end

local function addHint(tooltip, labelKey, action)
  local names = keyNames(_G.GetBindingKey(action))
  if #names == 0 then
    return
  end
  local text = string.format(Localization.Text(labelKey), table.concat(names, ", "))
  tooltip:AddLine(text, HINT_GREY, HINT_GREY, HINT_GREY)
end

-- includeReply: the reply key opens the messenger only while whispers are
-- hidden from the default chat (the reply key binder routes it to /wr).
function KeybindHints.AddToTooltip(tooltip, includeReply)
  if tooltip == nil or type(tooltip.AddLine) ~= "function" or type(_G.GetBindingKey) ~= "function" then
    return
  end
  addHint(tooltip, "Open/close: %s", "WHISPERMESSENGER_TOGGLE")
  if includeReply then
    addHint(tooltip, "Reply: %s", "REPLY")
  end
end

ns.KeybindHints = KeybindHints
return KeybindHints
