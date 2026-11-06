local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
-- stylua: ignore end

-- In a player menu our addon opened, Blizzard's entries run as addon code, so
-- the game blocks the restricted calls some of them make
-- (ADDON_ACTION_FORBIDDEN). Copy Character Name (CopyToClipboard) is pointed
-- at our own copy dialog. Report was checked in game and works as is.
local ProtectedMenuEntries = {}

local NAME_PROMPT = "Press Ctrl+C to copy the name."

-- Only the FRIEND menu has Copy Character Name (BN_FRIEND has none on Retail
-- or Forever), so the name is always the whisper row's display name.
local function characterName(item)
  local name = item.displayName
  if type(name) ~= "string" or SecretValue.Is(name) or name == "" then
    return nil
  end
  -- WoW: Forever's own Copy Character Name leaves the realm out.
  if FlavorCompat.isForever then
    name = string.match(name, "^[^%-]+") or name
  end
  return name
end

local function disable(element)
  if type(element.SetEnabled) == "function" then
    element:SetEnabled(false)
  end
end

local function fixCopy(element, item)
  local name = characterName(item)
  if name == nil or type(element.SetResponder) ~= "function" then
    disable(element)
    return
  end
  element:SetResponder(function()
    PopupUI.ShowManualCopyDialog(name, { prompt = NAME_PROMPT })
  end)
end

-- Labels are the same globals Blizzard builds the entries from, so they match
-- in every language. Entries are matched by label because a menu description
-- does not keep the button it was made from.
local function handlers()
  local byLabel = {}
  local function add(label, handler)
    if label ~= nil then
      byLabel[label] = handler
    end
  end
  add(_G.COPY_CHARACTER_NAME, fixCopy)
  return byLabel
end

local function walk(description, item, byLabel, getText)
  if type(description.EnumerateElementDescriptions) ~= "function" then
    return
  end
  for _, element in description:EnumerateElementDescriptions() do
    local handler = byLabel[getText(element)]
    if handler then
      handler(element, item)
    end
    walk(element, item, byLabel, getText)
  end
end

function ProtectedMenuEntries.Fix(rootDescription, item)
  local menuUtil = _G.MenuUtil
  if type(menuUtil) ~= "table" or type(menuUtil.GetElementText) ~= "function" then
    return
  end
  walk(rootDescription, item, handlers(), menuUtil.GetElementText)
end

ns.ContactsListProtectedMenuEntries = ProtectedMenuEntries
return ProtectedMenuEntries
