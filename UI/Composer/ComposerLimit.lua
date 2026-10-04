local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")
local MessageSplit = ns.MessageSplit or require("WhisperMessenger.Util.MessageSplit")

-- How much the composer accepts: whispers go out in up to MAX_PARTS parts,
-- group chats in one message.
local ComposerLimit = {}

local function isWhisperChannel(channel)
  return channel == "WOW" or channel == "BN"
end

function ComposerLimit.InputMaxBytes(channel)
  return isWhisperChannel(channel) and TextLimits.LONG_INPUT_MAX_BYTES or TextLimits.INPUT_MAX_BYTES
end

function ComposerLimit.Create(input)
  local whisper = false
  local lastText, lastCursor = "", 0
  -- True while the limit itself changes the text; that change is not the player's.
  local busy = false
  local limit = {}

  function limit.setChannel(channel)
    whisper = isWhisperChannel(channel)
    if input.SetMaxBytes then
      busy = true
      input:SetMaxBytes(ComposerLimit.InputMaxBytes(channel))
      busy = false
    end
  end

  -- Longest text a launcher may grow the input to.
  function limit.messageMaxBytes()
    return whisper and TextLimits.LONG_MESSAGE_MAX_BYTES or TextLimits.MESSAGE_MAX_BYTES
  end

  -- Makes the input's current text the restore point.
  function limit.remember()
    lastText = input:GetText() or ""
    lastCursor = input.GetCursorPosition and input:GetCursorPosition() or #lastText
  end

  -- False when the change is not the player's or needed too many parts and
  -- was undone. trusted skips the part count (a stored draft loading).
  function limit.accept(text, trusted)
    if busy then
      return false
    end
    if whisper and not trusted and MessageSplit.Count(text, TextLimits.MESSAGE_MAX_BYTES) > TextLimits.MAX_PARTS then
      busy = true
      input:SetText(lastText)
      busy = false
      if input.SetCursorPosition then
        input:SetCursorPosition(lastCursor)
      end
      return false
    end
    limit.remember()
    return true
  end

  limit.setChannel(nil)
  return limit
end

ns.ComposerLimit = ComposerLimit
return ComposerLimit
