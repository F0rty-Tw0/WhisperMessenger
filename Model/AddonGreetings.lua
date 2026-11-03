local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- Addon greetings: crafting addons (CraftScan and others following the
-- RobotsDotTxt convention) send a hidden "Q:<AddonName>" addon message right
-- before an automated whisper. The announcement marks its sender for a short
-- window; the next whisper from them claims the mark and is tagged
-- "Sent by <AddonName>". Marks are keyed like whisper conversations
-- (Identity contact key), so the realm-suffixed addon sender matches the
-- whisper's name form.
local AddonGreetings = {}

AddonGreetings.WINDOW_SECONDS = 10
AddonGreetings.EARLY_WHISPER_SECONDS = 1
AddonGreetings.MAX_NAME_BYTES = 32
AddonGreetings.SETTING_KEY = "addonGreetings"
AddonGreetings.MODE_SHOW = "show"
AddonGreetings.MODE_REQUESTS = "requests"
AddonGreetings.MODE_HIDE = "hide"
AddonGreetings.DEFAULT_MODE = AddonGreetings.MODE_SHOW

local KNOWN_MODES = {
  [AddonGreetings.MODE_SHOW] = true,
  [AddonGreetings.MODE_REQUESTS] = true,
  [AddonGreetings.MODE_HIDE] = true,
}

-- The name comes from another player's addon: printable ASCII only, so no
-- "|" escape codes (colours, links, textures) and no control characters.
local function isPlainName(name)
  return name ~= "" and #name <= AddonGreetings.MAX_NAME_BYTES and string.find(name, "[^\32-\123\125\126]") == nil
end

function AddonGreetings.Decode(text)
  if type(text) ~= "string" then
    return nil
  end
  local raw = string.match(text, "^Q:(.*)$")
  if raw == nil then
    return nil
  end
  local name = string.match(raw, "^%s*(.-)%s*$")
  if not isPlainName(name) then
    return nil
  end
  return name
end

local function senderKey(sender)
  return Identity.FromWhisper(sender).contactKey
end

-- Inbox entries: { name, at } marks an announcement, { at } (no name) marks
-- the sender's last whisper. Both expire after the window.
local function openInbox(state, now)
  local inbox = state.addonGreetingInbox or {}
  state.addonGreetingInbox = inbox
  for key, entry in pairs(inbox) do
    if now - entry.at > AddonGreetings.WINDOW_SECONDS then
      inbox[key] = nil
    end
  end
  return inbox
end

-- The whisper can beat its own announcement. An announcement that lands
-- right after a whisper from the same sender belongs to that whisper, so it
-- must not tag the next one. The clock counts whole seconds, so "right
-- after" is the same or the next second.
local function followsWhisper(entry, now)
  return entry ~= nil and entry.name == nil and now - entry.at <= AddonGreetings.EARLY_WHISPER_SECONDS
end

function AddonGreetings.Record(state, sender, text, now)
  if type(state) ~= "table" or type(sender) ~= "string" or sender == "" or type(now) ~= "number" then
    return false
  end
  local name = AddonGreetings.Decode(text)
  if name == nil then
    return false
  end
  local inbox = openInbox(state, now)
  local key = senderKey(sender)
  if followsWhisper(inbox[key], now) then
    return false
  end
  inbox[key] = { name = name, at = now }
  return true
end

-- Returns the announcing addon's name when contactKey announced a greeting
-- within the window, and consumes the mark either way. Every claim leaves a
-- whisper mark for followsWhisper.
function AddonGreetings.Claim(state, contactKey, now)
  if type(state) ~= "table" or contactKey == nil or type(now) ~= "number" then
    return nil
  end
  local inbox = openInbox(state, now)
  local entry = inbox[contactKey]
  inbox[contactKey] = { at = now }
  if entry == nil or entry.name == nil then
    return nil
  end
  local age = now - entry.at
  if age < 0 or age > AddonGreetings.WINDOW_SECONDS then
    return nil
  end
  return entry.name
end

-- The mode in effect. "Send to Requests" only counts while the Requests
-- inbox is on; the stored value is kept, the greeting just shows meanwhile.
function AddonGreetings.Mode(settings)
  local mode = type(settings) == "table" and settings[AddonGreetings.SETTING_KEY] or nil
  if not KNOWN_MODES[mode] then
    return AddonGreetings.DEFAULT_MODE
  end
  if mode == AddonGreetings.MODE_REQUESTS and settings.requestsInbox ~= true then
    return AddonGreetings.MODE_SHOW
  end
  return mode
end

ns.AddonGreetings = AddonGreetings
return AddonGreetings
