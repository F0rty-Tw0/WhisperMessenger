local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or (type(require) == "function" and require("WhisperMessenger.Model.Identity")) or nil
local Store = ns.ConversationStore or (type(require) == "function" and require("WhisperMessenger.Model.ConversationStore")) or nil
local ChatReplyState = {}

local function readEditBoxState(editBox, key)
  if type(editBox) ~= "table" then
    return nil
  end

  if type(editBox.GetAttribute) == "function" then
    local attribute = editBox:GetAttribute(key)
    if attribute ~= nil and attribute ~= "" then
      return attribute
    end
  end

  local direct = editBox[key]
  if direct ~= nil and direct ~= "" then
    return direct
  end

  return nil
end

local function readEditBoxText(editBox)
  if type(editBox) ~= "table" or type(editBox.GetText) ~= "function" then
    return ""
  end

  local ok, text = pcall(editBox.GetText, editBox)
  if not ok then
    return nil
  end

  return text or ""
end

local function defaultGetNumChatWindows()
  return _G.NUM_CHAT_WINDOWS or 10
end

local function defaultGetEditBox(index)
  return _G["ChatFrame" .. index .. "EditBox"]
end

-- Scrub Blizzard's whisper sticky state on default chat edit boxes when no
-- text is pending. After a /r reply (in M+ or otherwise), Blizzard leaves
-- chatType=WHISPER + tellTarget set; a later focus on the edit box would let
-- our auto-open poller mistake the empty draft for a fresh whisper intent.
-- Capture that target for our own reply flow, then restore a non-whisper
-- fallback so Enter goes to Say/Party/etc. as the user expects.
local function currentTime(runtime)
  if runtime and type(runtime.now) == "function" then
    return runtime.now()
  end
  if type(_G.time) == "function" then
    return _G.time()
  end
  return 0
end

local function staleWhisperReplyTarget(editBox)
  local chatType = readEditBoxState(editBox, "chatType")
  local stickyType = readEditBoxState(editBox, "stickyType")
  local tellTarget = readEditBoxState(editBox, "tellTarget")
  local text = readEditBoxText(editBox)
  local isWhisperChat = chatType == "WHISPER" or chatType == "BN_WHISPER"
  local isWhisperSticky = stickyType == "WHISPER" or stickyType == "BN_WHISPER"

  if type(editBox) == "table" and tellTarget ~= nil and tellTarget ~= "" and text == "" and (isWhisperChat or isWhisperSticky) then
    local channel = (chatType == "BN_WHISPER" or stickyType == "BN_WHISPER") and "BN" or "WOW"
    return tellTarget, channel
  end

  return nil
end

local function ensureWhisperConversation(runtime, target, channel)
  if type(runtime) ~= "table" or target == nil or target == "" or Identity == nil then
    return nil, channel ~= "BN"
  end

  local conversationKey = Identity.ResolveWhisperConversation(runtime, target, channel)
  if conversationKey ~= nil then
    runtime.lastIncomingWhisperKey = conversationKey
    return conversationKey, true
  end

  if channel == "BN" then
    return nil, false
  end

  local contact = Identity.FromWhisper(target, nil, {})
  if contact.canonicalName == "" then
    return nil, true
  end

  conversationKey = Identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
  if type(conversationKey) ~= "string" or conversationKey == "" or Store == nil then
    return nil, true
  end

  runtime.store = runtime.store or {}
  Store.EnsureConversation(runtime.store, conversationKey, {
    channel = "WOW",
    displayName = target,
    lastActivityAt = currentTime(runtime),
  })

  runtime.lastIncomingWhisperKey = conversationKey
  return conversationKey, true
end
function ChatReplyState.CaptureStaleWhisperReplyTarget(runtime, getNumChatWindows, getEditBox)
  getNumChatWindows = getNumChatWindows or defaultGetNumChatWindows
  getEditBox = getEditBox or defaultGetEditBox

  if type(getNumChatWindows) ~= "function" or type(getEditBox) ~= "function" then
    return nil
  end

  local capturedKey = nil
  local chatWindowCount = getNumChatWindows() or 0
  for index = 1, chatWindowCount do
    local target, channel = staleWhisperReplyTarget(getEditBox(index))
    if target ~= nil then
      local conversationKey, resolved = ensureWhisperConversation(runtime, target, channel)
      capturedKey = capturedKey or conversationKey
      if resolved == false then
        return capturedKey, false
      end
    end
  end

  return capturedKey, true
end

function ChatReplyState.ClearStaleWhisperReplyState(getNumChatWindows, getEditBox)
  getNumChatWindows = getNumChatWindows or defaultGetNumChatWindows
  getEditBox = getEditBox or defaultGetEditBox

  if type(getNumChatWindows) ~= "function" or type(getEditBox) ~= "function" then
    return
  end

  local chatWindowCount = getNumChatWindows() or 0
  for index = 1, chatWindowCount do
    local editBox = getEditBox(index)
    local chatType = readEditBoxState(editBox, "chatType")
    local stickyType = readEditBoxState(editBox, "stickyType")
    local tellTarget = readEditBoxState(editBox, "tellTarget")
    local text = readEditBoxText(editBox)
    local isWhisperChat = chatType == "WHISPER" or chatType == "BN_WHISPER"
    local isWhisperSticky = stickyType == "WHISPER" or stickyType == "BN_WHISPER"

    if
      type(editBox) == "table"
      and type(editBox.SetAttribute) == "function"
      and tellTarget ~= nil
      and tellTarget ~= ""
      and text == ""
      and (isWhisperChat or isWhisperSticky)
    then
      local fallbackType = stickyType
      if fallbackType == nil or fallbackType == "" or fallbackType == "WHISPER" or fallbackType == "BN_WHISPER" then
        fallbackType = "SAY"
      end

      pcall(editBox.SetAttribute, editBox, "chatType", fallbackType)
      pcall(editBox.SetAttribute, editBox, "stickyType", fallbackType)
      pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
    end
  end
end

ns.ChatReplyState = ChatReplyState

return ChatReplyState
