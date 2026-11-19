local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")
local CharacterMergeMap = ns.CharacterMergeMap or require("WhisperMessenger.Model.CharacterMergeMap")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local LinkHooks = ns.ComposerLinkHooks or require("WhisperMessenger.UI.Composer.LinkHooks")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- The small public calls that read one piece of state or write one value.
local Queries = {}

local floor = math.floor
local max = math.max

local LOOK_KEYS = {
  "bg_primary",
  "bg_secondary",
  "bg_header",
  "bg_input",
  "divider",
  "contacts_divider",
  "bg_contact_selected",
  "bg_contact_hover",
  "scrollbar",
  "scrollbar_hover",
}

-- SetContactInfo(sourceKey, playerName, text, tooltipLines?): a one-line
-- note under a player's name in their chat. Text nil or blank removes the
-- caller's note and its tooltip. tooltipLines, when given, is an array of 1 to
-- 10 non-empty strings (color codes allowed) shown when the player hovers the
-- note; the first line shows as the tooltip's title. WM keeps a copy, so
-- changing the table later changes nothing. A call with text but no
-- tooltipLines clears the caller's old tooltip. Any other tooltipLines value
-- returns false and changes nothing.
local function installSetContactInfo(api, runtime)
  api.SetContactInfo = Guards.Wrap(function(sourceKey, playerName, text, tooltipLines)
    if not ContactInfo.Set(runtime.contactInfo, sourceKey, playerName, text, runtime, tooltipLines) then
      return false
    end
    Guards.Claim(runtime, "note", sourceKey)
    -- Only the open chat's strip can change.
    if runtime.isWindowVisible() and ContactInfo.ResolvesTo(runtime, playerName, runtime.activeConversationKey) then
      runtime.refreshWindow()
    end
    return true
  end)
end

local function readUnreadCount(runtime, name)
  if SecretValue.Is(name) or not Guards.IsNonEmptyString(name) then
    return 0
  end
  local key = CharacterMergeMap.ResolveWhisperName(runtime, name)
  local conversation = key and runtime.store.conversations[key]
  if not conversation then
    return 0
  end
  return max(0, floor(tonumber(conversation.unreadCount) or 0))
end

-- GetUnreadCount(name): the number of unread whispers in the WoW chat with
-- that player (or the Battle.net chat the character was merged into), the
-- same number the contact row shows. name is "Name-Realm",
-- or a bare "Name" when only one stored chat has that name. Muted chats and
-- message requests report their real count. A bad name (not a string, blank,
-- or secret), a name with no chat or more than one, or an internal error
-- returns 0; it never throws. Each call scans every stored chat, so call it
-- from onUnreadChanged or a repaint, never per frame.
local function installGetUnreadCount(api, runtime)
  api.GetUnreadCount = function(name)
    local ok, count = pcall(readUnreadCount, runtime, name)
    return ok and type(count) == "number" and count or 0
  end
end

local function readLook()
  local colors = {}
  for _, key in ipairs(LOOK_KEYS) do
    local color = Theme.COLORS[key]
    if color then
      colors[key] = { color[1], color[2], color[3], color[4] }
    end
  end
  return { hud = Hud.Style(), colors = colors }
end

-- GetLook(): WM's current look, so an addon panel can draw to match it.
-- Returns a new table each call: { hud = "off" | "classic" | "retail",
-- colors = { <key> = { r, g, b, a }, ... } }. hud is the style this session
-- runs (a change applies after /reload). colors holds copies of the keys in
-- LOOK_KEYS, read at call time so they follow theme switches; a key the
-- theme lacks is left out. Any internal error returns nil; it never throws.
-- With hud other than "off", WM's panes are see-through over the game's frame
-- art, so a matching panel leaves bg_primary and bg_secondary unpainted.
local function installGetLook(api)
  api.GetLook = function()
    local ok, look = pcall(readLook)
    return ok and look or nil
  end
end

-- IsAnimationEnabled(): true unless the player turned "Window animation"
-- off. Read at call time, so it follows the setting; a missing setting counts
-- as on. With addon integration off the call is refused and returns false.
local function installIsAnimationEnabled(api, runtime)
  api.IsAnimationEnabled = function()
    local settings = runtime.accountState and runtime.accountState.settings
    return not settings or settings.windowAnimation ~= false
  end
end

-- IsCompactWindow(): true when the messenger window is in its compact
-- layout. The layout is fixed for the session (changing the setting reloads
-- the UI), so there is no callback: read it when needed. Once the window is
-- built its real layout wins; before that the saved setting answers, and an
-- unset setting counts as compact. No settings at all, or addon integration
-- off (call refused), gives false.
local function installIsCompactWindow(api, runtime)
  api.IsCompactWindow = function()
    if runtime.compactLayoutActive ~= nil then
      return runtime.compactLayoutActive == true
    end
    local settings = runtime.accountState and runtime.accountState.settings
    return settings ~= nil and settings.compactLayout ~= false
  end
end

local function isValidLinkText(text)
  return Guards.IsNonEmptyString(text) and #text <= TextLimits.MESSAGE_MAX_BYTES
end

-- InsertLink(text) -> boolean: drops a chat link into the Whisper Messenger
-- message box the player is typing in, after what is already there.
-- text is a non-blank string of at most 255 bytes (one chat message), such as
-- "|Hitem:...|h[Name]|h". It does not open the window or pick a conversation:
-- it returns true only when the message box is shown, has keyboard focus and
-- really took the text. It returns false, and inserts nothing, when text is
-- not valid, would pass the box's length limit, the box is not focused, a
-- second insert lands in the same frame, content restrictions apply, or the
-- player refused the caller. It never throws.
-- Detect support with `type(api.InsertLink) == "function"`: older Whisper
-- Messenger versions lack it, and `version` does not change.
local function installInsertLink(api, runtime)
  api.InsertLink = Guards.Wrap(function(text)
    if not isValidLinkText(text) or Guards.IsRefused(runtime) then
      return false
    end
    return LinkHooks.InsertText(text)
  end)
end

function Queries.Install(api, runtime)
  installSetContactInfo(api, runtime)
  installGetUnreadCount(api, runtime)
  installGetLook(api)
  installIsAnimationEnabled(api, runtime)
  installIsCompactWindow(api, runtime)
  installInsertLink(api, runtime)
end

ns.PublicApiQueries = Queries
return Queries
