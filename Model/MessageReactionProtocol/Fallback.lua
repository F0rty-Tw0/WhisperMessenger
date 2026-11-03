local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")
local Wire = ns.MessageReactionProtocolWire or require("WhisperMessenger.Model.MessageReactionProtocol.Wire")

-- The plain chat line ("reacted :heart: to: “…”") that carries a reaction
-- to players without the addon, and its parser.
local Fallback = {}

local MAX_PAYLOAD_BYTES = Wire.MAX_PAYLOAD_BYTES
local ELLIPSIS = "…"
local OPEN_QUOTE = "“"
local CLOSE_QUOTE = "”"
local ADDON_HINT_SUFFIX = " (via WhisperMessenger)"

function Fallback.BuildGroupFallback(key, operation, sourceText, hintSuffix)
  if not Wire.IsReactionKey(key) then
    return nil
  end
  if operation ~= "set" and operation ~= "remove" then
    return nil
  end
  if type(sourceText) ~= "string" then
    sourceText = ""
  end
  if type(hintSuffix) ~= "string" then
    hintSuffix = ""
  end

  local action
  if operation == "set" then
    action = "reacted :" .. key .. ": to: "
  else
    action = "removed :" .. key .. ": from: "
  end
  local prefix = action .. OPEN_QUOTE
  local closeQuote = CLOSE_QUOTE
  local available = MAX_PAYLOAD_BYTES - #prefix - #closeQuote - #hintSuffix
  if available < 0 then
    return nil
  end

  local excerpt = sourceText
  if #excerpt > available then
    local textBudget = available - #ELLIPSIS
    if textBudget < 0 then
      return nil
    end
    excerpt = TextLimits.CapBytes(excerpt, textBudget) .. ELLIPSIS
  end
  return prefix .. excerpt .. closeQuote .. hintSuffix
end

function Fallback.ParseGroupFallback(text)
  if type(text) ~= "string" or #text > MAX_PAYLOAD_BYTES then
    return nil
  end

  if #text > #ADDON_HINT_SUFFIX and string.sub(text, -#ADDON_HINT_SUFFIX) == ADDON_HINT_SUFFIX then
    text = string.sub(text, 1, -#ADDON_HINT_SUFFIX - 1)
  end

  local key, sourceExcerpt = string.match(text, "^reacted :([a-z]+): to: “(.*)” *$")
  local operation = "set"
  if key == nil then
    key, sourceExcerpt = string.match(text, "^removed :([a-z]+): from: “(.*)” *$")
    operation = "remove"
  end
  if key == nil or not Wire.IsReactionKey(key) then
    return nil
  end
  return {
    operation = operation,
    key = key,
    sourceExcerpt = sourceExcerpt,
    truncated = string.sub(sourceExcerpt, -#ELLIPSIS) == ELLIPSIS,
  }
end

Fallback.ADDON_HINT_SUFFIX = ADDON_HINT_SUFFIX

ns.MessageReactionProtocolFallback = Fallback
return Fallback
