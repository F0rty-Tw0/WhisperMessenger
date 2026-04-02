local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LinkHooks = {}
local registeredLinkHooks = false
local linkedInputs = {}

local function isInputShown(input)
  if type(input.IsVisible) == "function" then
    return input:IsVisible() == true
  end
  if type(input.IsShown) ~= "function" then
    return true
  end
  return input:IsShown() == true
end

local function isInputFocused(input)
  if type(input.HasFocus) ~= "function" then
    return false
  end
  return input:HasFocus() == true
end

local function findInputForInsertion(allowVisibleWithoutFocus)
  local fallbackVisibleInput = nil

  for _, input in ipairs(linkedInputs) do
    if input ~= nil and type(input.Insert) == "function" and isInputShown(input) then
      if isInputFocused(input) then
        return input
      end
      if allowVisibleWithoutFocus and fallbackVisibleInput == nil then
        fallbackVisibleInput = input
      end
    end
  end

  return fallbackVisibleInput
end

local function tryInsertLink(link, options)
  if link == nil then
    return false
  end

  options = options or {}
  local input = findInputForInsertion(options.allowVisibleWithoutFocus == true)
  if input == nil then
    return false
  end

  input:Insert(link)
  return true
end

local function safeHookGlobal(functionName, handler)
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

--- Wrap ChatFrameUtil.GetActiveWindow / ChatEdit_GetActiveWindow:
--- returns our editbox when visible, defers to original when default chat is open.
local function wmGetActiveWindow(original)
  return function()
    local result = original and original()
    if result ~= nil then
      return result
    end
    local input = findInputForInsertion(true)
    if input ~= nil and isInputShown(input) then
      return input
    end
    return nil
  end
end

--- Wrap ChatFrameUtil.InsertLink / ChatEdit_InsertLink:
--- tries original first (default chat), then our editbox as fallback.
--- Returns true when handled so callers (quest log, achievement frame, etc.)
--- do not fall through to their default action (tracking, inspecting).
local function wmInsertLink(original)
  return function(link)
    if original then
      local handled = original(link)
      if handled then
        return true
      end
    end
    if _G._wmSuspended then
      return false
    end
    if type(link) == "string" and link ~= "" then
      local inserted = tryInsertLink(link, { allowVisibleWithoutFocus = true })
      if inserted then
        return true
      end
    end
    return false
  end
end

--- Install overrides at module load time (TOC startup).
--- Modern retail WoW (11.0+) moved chat functions to ChatFrameUtil.
--- Blizzard frames call ChatFrameUtil.InsertLink / ChatFrameUtil.GetActiveWindow
--- directly — the old ChatEdit_* globals are deprecated aliases.
--- We replace BOTH the ChatFrameUtil table entries AND the globals.
local function installEarlyOverrides()
  if type(_G.ChatFrameUtil) == "table" then
    _G.ChatFrameUtil.GetActiveWindow = wmGetActiveWindow(_G.ChatFrameUtil.GetActiveWindow)
    _G.ChatFrameUtil.InsertLink = wmInsertLink(_G.ChatFrameUtil.InsertLink)
  end

  _G.ChatEdit_GetActiveWindow = wmGetActiveWindow(_G.ChatEdit_GetActiveWindow)
  _G.ChatEdit_InsertLink = wmInsertLink(_G.ChatEdit_InsertLink)
end

installEarlyOverrides()

local function registerLinkHooks()
  if registeredLinkHooks or type(_G.hooksecurefunc) ~= "function" then
    return
  end

  -- SetItemRef: handles clicking hyperlinks inside chat bubbles / transcript.
  safeHookGlobal("SetItemRef", function(link, text)
    if _G._wmSuspended then
      return
    end
    if link == nil then
      return
    end

    local linkToInsert = link
    if type(text) == "string" and text ~= "" and string.find(text, "|H", 1, true) then
      linkToInsert = text
    elseif
      type(link) == "string"
      and string.find(link, "quest:", 1, true)
      and type(text) == "string"
      and text ~= ""
    then
      linkToInsert = "|H" .. link .. "|h" .. text .. "|h"
    end

    local normalizedInsertedLink = type(linkToInsert) == "string" and string.lower(linkToInsert) or ""
    local allowVisibleWithoutFocus = string.find(normalizedInsertedLink, "quest:", 1, true) ~= nil
    tryInsertLink(linkToInsert, { allowVisibleWithoutFocus = allowVisibleWithoutFocus })
  end)

  registeredLinkHooks = true
end

function LinkHooks.RegisterInput(input)
  -- Blizzard code (GetActiveChatType, etc.) expects the editbox returned
  -- by GetActiveWindow to behave like a chat frame editbox. Add fields
  -- and method stubs so our plain EditBox doesn't error.
  if input.chatType == nil then
    input.chatType = "SAY"
  end
  if type(input.GetChatType) ~= "function" then
    input.GetChatType = function(self)
      return self.chatType or "SAY"
    end
  end
  table.insert(linkedInputs, 1, input)
  registerLinkHooks()
end

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
