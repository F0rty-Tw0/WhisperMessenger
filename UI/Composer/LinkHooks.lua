local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")

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

  -- Classic vanilla shift-click of a quest produces plain `[Name (id)]` text
  -- with no |H...|h envelope. Rewrite to a real hyperlink so the link is
  -- clickable in the composer and survives transmission to the recipient.
  local insertable = link
  if type(insertable) == "string" then
    insertable = QuestLinkClassic.Rewrite(insertable)
  end

  input:Insert(insertable)
  return true
end

local function safeHookGlobal(functionName, handler)
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

-- Snapshot originals at module load so we can restore them when no composer
-- input has focus. We intentionally do NOT install the overrides here —
-- leaving our function baked into Blizzard's call graph taints every
-- internal `ChatEdit_GetActiveWindow` query, including the one on the
-- `OPENCHAT` binding (Enter) path. That crashed `UpdateHeader` arithmetic
-- with WhisperMessenger attribution on every Enter press and on `/r` after
-- a post-M+ BN_WHISPER sticky.
--
-- Instead, the overrides install on composer focus-gained and restore on
-- focus-lost. While the composer is focused (user actively composing), any
-- Blizzard query routes through us and links insert correctly. While it is
-- unfocused — which is exactly when OPENCHAT and /r fire — Blizzard sees
-- its own function and runs untainted.
local originals = {
  chatEditGetActiveWindow = nil,
  chatEditInsertLink = nil,
  chatFrameUtilGetActiveWindow = nil,
  chatFrameUtilInsertLink = nil,
  captured = false,
}

local function captureOriginals()
  if originals.captured then
    return
  end
  originals.chatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  originals.chatEditInsertLink = _G.ChatEdit_InsertLink
  local cfu = _G.ChatFrameUtil
  if type(cfu) == "table" then
    originals.chatFrameUtilGetActiveWindow = cfu.GetActiveWindow
    originals.chatFrameUtilInsertLink = cfu.InsertLink
  end
  originals.captured = true
end

local overrideInstalled = false

local function wmGetActiveWindow()
  local original = originals.chatEditGetActiveWindow or originals.chatFrameUtilGetActiveWindow
  if original then
    local result = original()
    if result ~= nil then
      return result
    end
  end
  local input = findInputForInsertion(false)
  if input ~= nil and isInputShown(input) and isInputFocused(input) then
    return input
  end
  return nil
end

local function wmInsertLink(link)
  -- Rewrite Classic plain-text quest links BEFORE delegating to the original.
  -- Otherwise Blizzard's `ChatEdit_InsertLink` sees our composer via our
  -- `wmGetActiveWindow` override, calls `editbox:Insert(plainText)` directly,
  -- and returns true — short-circuiting the rewrite path below.
  local insertable = link
  if type(insertable) == "string" then
    insertable = QuestLinkClassic.Rewrite(insertable)
  end

  local original = originals.chatEditInsertLink or originals.chatFrameUtilInsertLink
  if original then
    local handled = original(insertable)
    if handled then
      return true
    end
  end
  if _G._wmSuspended then
    return false
  end
  if type(insertable) == "string" and insertable ~= "" then
    if tryInsertLink(insertable, { allowVisibleWithoutFocus = false }) then
      return true
    end
  end
  return false
end

local function installOverrides()
  if overrideInstalled then
    return
  end
  captureOriginals()
  _G.ChatEdit_GetActiveWindow = wmGetActiveWindow
  _G.ChatEdit_InsertLink = wmInsertLink
  local cfu = _G.ChatFrameUtil
  if type(cfu) == "table" then
    cfu.GetActiveWindow = wmGetActiveWindow
    cfu.InsertLink = wmInsertLink
  end
  overrideInstalled = true
end

local function anyLinkedInputFocused()
  for _, input in ipairs(linkedInputs) do
    if input ~= nil and type(input.HasFocus) == "function" and input:HasFocus() then
      return true
    end
  end
  return false
end

local function uninstallOverrides()
  if not overrideInstalled then
    return
  end
  _G.ChatEdit_GetActiveWindow = originals.chatEditGetActiveWindow
  _G.ChatEdit_InsertLink = originals.chatEditInsertLink
  local cfu = _G.ChatFrameUtil
  if type(cfu) == "table" then
    cfu.GetActiveWindow = originals.chatFrameUtilGetActiveWindow
    cfu.InsertLink = originals.chatFrameUtilInsertLink
  end
  overrideInstalled = false
end

local function attachFocusGuards(input)
  if type(input.HookScript) ~= "function" then
    return
  end
  input:HookScript("OnEditFocusGained", function()
    installOverrides()
  end)
  input:HookScript("OnEditFocusLost", function()
    if not anyLinkedInputFocused() then
      uninstallOverrides()
    end
  end)
end

-- Exposed for tests so we can drive focus transitions without a real
-- EditBox.
LinkHooks._installOverrides = installOverrides
LinkHooks._uninstallOverrides = uninstallOverrides
LinkHooks._isOverrideInstalled = function()
  return overrideInstalled
end

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
    elseif type(link) == "string" and string.find(link, "quest:", 1, true) and type(text) == "string" and text ~= "" then
      linkToInsert = "|H" .. link .. "|h" .. text .. "|h"
    end

    -- Only insert into the messenger composer when it currently has focus.
    -- Otherwise clicking a chat-bubble link (or anything routed through
    -- SetItemRef) would silently dump the link into our editbox even when
    -- the user expected the default behavior (open quest log, show tooltip).
    tryInsertLink(linkToInsert, { allowVisibleWithoutFocus = false })
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
  attachFocusGuards(input)
  registerLinkHooks()
end

ns.ComposerLinkHooks = LinkHooks
return LinkHooks
