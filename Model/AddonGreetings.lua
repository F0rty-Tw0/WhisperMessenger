local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- Addon greetings: crafting addons (CraftScan and others following the
-- RobotsDotTxt convention) send a hidden "Q:<AddonName>" addon message right
-- before an automated whisper. The announcement marks its sender for a short
-- window; the next whisper from them claims the mark and is tagged
-- with <AddonName>, and so are the lines that follow it within a short
-- burst. CraftScan's own channel tags a whisper after it arrived instead
-- (NoteWhisper / ClaimStored). Marks are keyed like whisper conversations
-- (Identity contact key), so the realm-suffixed addon sender matches the
-- whisper's name form.
local AddonGreetings = {}

AddonGreetings.WINDOW_SECONDS = 10
AddonGreetings.EARLY_WHISPER_SECONDS = 1
-- CraftScan sends several lines after one announcement. A whisper this soon
-- after a tagged one belongs to the same burst; a typed reply comes later.
AddonGreetings.BURST_SECONDS = 2
-- CraftScan's own channel speaks right after the customer's whisper.
AddonGreetings.LATE_TAG_SECONDS = 3
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

local function openMap(state, field, maxAge, now)
  local map = state[field] or {}
  state[field] = map
  for key, entry in pairs(map) do
    if now - entry.at > maxAge then
      map[key] = nil
    end
  end
  return map
end

-- Inbox entries: { name, at } marks an announcement, { at } (no name) marks
-- the sender's last whisper, plus burst = <AddonName> when it was tagged.
-- All expire after the window.
local function openInbox(state, now)
  return openMap(state, "addonGreetingInbox", AddonGreetings.WINDOW_SECONDS, now)
end

local function isWithin(entry, now, seconds)
  local age = now - entry.at
  return age >= 0 and age <= seconds
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

local function claimedName(entry, now)
  if entry == nil then
    return nil
  end
  if entry.name ~= nil then
    return isWithin(entry, now, AddonGreetings.WINDOW_SECONDS) and entry.name or nil
  end
  if entry.burst ~= nil and isWithin(entry, now, AddonGreetings.BURST_SECONDS) then
    return entry.burst
  end
  return nil
end

-- Returns the announcing addon's name when contactKey announced a greeting
-- within the window or this whisper continues a tagged burst, and consumes
-- the announcement either way. Every claim leaves a whisper mark for
-- followsWhisper; a tagged one also opens the burst window.
function AddonGreetings.Claim(state, contactKey, now)
  if type(state) ~= "table" or contactKey == nil or type(now) ~= "number" then
    return nil
  end
  local inbox = openInbox(state, now)
  local name = claimedName(inbox[contactKey], now)
  inbox[contactKey] = { at = now, burst = name }
  return name
end

-- stored: what a later CraftScan channel message needs to tag the untagged
-- live whisper from contactKey, or nil when that whisper was tagged already.
-- Only the newest whisper per sender is kept.
function AddonGreetings.NoteWhisper(state, contactKey, now, stored)
  if type(state) ~= "table" or contactKey == nil or type(now) ~= "number" then
    return
  end
  local late = openMap(state, "addonGreetingLate", AddonGreetings.LATE_TAG_SECONDS, now)
  late[contactKey] = stored and { at = now, stored = stored } or nil
end

-- The untagged whisper sender sent at most LATE_TAG_SECONDS ago, consumed so
-- one addon message tags one whisper at most.
function AddonGreetings.ClaimStored(state, sender, now)
  if type(state) ~= "table" or type(sender) ~= "string" or sender == "" or type(now) ~= "number" then
    return nil
  end
  local late = openMap(state, "addonGreetingLate", AddonGreetings.LATE_TAG_SECONDS, now)
  local key = senderKey(sender)
  local entry = late[key]
  late[key] = nil
  if entry == nil or not isWithin(entry, now, AddonGreetings.LATE_TAG_SECONDS) then
    return nil
  end
  return entry.stored
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
