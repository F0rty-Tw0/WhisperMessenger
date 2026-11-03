local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PlainText = ns.PlainText or require("WhisperMessenger.Util.PlainText")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

local ipairs = ipairs
local format = string.format
local find = string.find

-- A conversation as plain text for copying out of the game: a header line,
-- then one "[YYYY-MM-DD HH:MM] Name: text" line per message in stored
-- (oldest first) order.
local ConversationExport = {}

local function usableName(name)
  return type(name) == "string" and not SecretValue.Is(name) and name ~= "" and not find(name, "|K", 1, true)
end

-- An outgoing record's playerName is the whisper target, so own lines take
-- names.playerName. A protected Battle.net sender (|K token) copies as
-- garbage, so it shows as the contact.
local function senderName(message, names)
  if message.direction == "out" then
    return names.playerName or Localization.Text("You")
  end
  if usableName(message.playerName) then
    return message.playerName
  end
  return names.contactName
end

-- Secret or missing text can't be read; a queued or failed message was
-- never said.
local function isExportable(message)
  local text = message.text
  return type(text) == "string" and not SecretValue.Is(text) and text ~= "" and message.delivery == nil
end

local function formatLine(message, names)
  local stamp = TimeFormat.ExportStamp(message.sentAt)
  local prefix = stamp ~= "" and ("[" .. stamp .. "] ") or ""
  local text = PlainText.Strip(message.text)
  if message.kind ~= "user" then
    return prefix .. text
  end
  return prefix .. tostring(senderName(message, names)) .. ": " .. text
end

-- names: { contactName, playerName }.
function ConversationExport.Format(messages, names)
  local lines = { format(Localization.Text("Conversation with %s"), tostring(names.contactName or "")) }
  for _, message in ipairs(messages or {}) do
    if type(message) == "table" and isExportable(message) then
      lines[#lines + 1] = formatLine(message, names)
    end
  end
  return table.concat(lines, "\n")
end

ns.ConversationExport = ConversationExport
return ConversationExport
