local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

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
-- our auto-open poller mistake the empty draft for a fresh whisper intent
-- and re-open the messenger. Restore a non-whisper fallback so Enter goes
-- to Say/Party/etc. as the user expects after the encounter.
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
