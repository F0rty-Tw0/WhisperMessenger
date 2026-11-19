local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")
local AddonGreetingText = ns.ChatBubbleAddonGreetingText or require("WhisperMessenger.UI.ChatBubble.AddonGreetingText")
local RowElements = ns.ContactsListRowElements or require("WhisperMessenger.UI.ContactsList.RowElements")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local sizeValue = UIHelpers.sizeValue
local pairs = pairs
local type = type

-- What a contact row was last bound from: every item field plus everything
-- outside the item the bind reads (list width, options, theme, fonts,
-- language, name display, the shown time label). A row whose signature still matches is
-- painted correctly already, so the refresh can skip its bind.
--
-- Item fields are compared generically, so a field a future enricher adds is
-- covered without a line here. Table fields (availability, relationship) are
-- compared by value, lists inside them (relationship.ties) entry by entry:
-- enrichers build them fresh on every refresh.
local RowSignature = {}

-- The store record: the bind reads it only for the shown preview, which
-- the context below carries instead.
local SKIPPED_FIELDS = { conversation = true }

local CONTEXT_SIZE = 16
local SELECTED_SLOT = 14
local TIME_SLOT = 15
local PREVIEW_SLOT = 16

local context = {}

-- Group titles take the player's class color.
local function playerClassTag()
  local fn = _G.UnitClass
  if type(fn) ~= "function" then
    return nil
  end
  local ok, _, classTag = pcall(fn, "player")
  return ok and classTag or nil
end

-- Same-faction contacts hide their faction icon.

local function playerFaction()
  local fn = _G.UnitFactionGroup
  if type(fn) ~= "function" then
    return nil
  end
  local ok, faction = pcall(fn, "player")
  return ok and faction or nil
end

-- The values every row of one refresh shares. Returns a table reused by
-- every refresh. A row's position is fixed by its pool slot, so it is not
-- part of the signature.
function RowSignature.Context(parent, options)
  options = options or {}
  local timeFormat, timeSource = TimeFormat.GetConfig()
  context[1] = sizeValue(parent, "GetWidth", "width", 260)
  context[2] = Theme.ContactRowHeight()
  context[3] = options.compact == true
  context[4] = options.hideMessagePreview and true or false
  context[5] = options
  context[6] = Theme.Revision()
  context[7] = Localization.GetEffectiveLanguage()
  context[8] = Hud.IsOn()
  context[9] = timeFormat
  context[10] = timeSource
  context[11] = playerClassTag()
  context[12] = playerFaction()
  -- Shown names follow the "Hide BattleTag numbers" option and name clashes.
  context[13] = DisplayName.Revision()
  context.selectedConversationKey = options.selectedConversationKey
  return context
end

-- The values only this item's row reads: the open conversation's draft is
-- hidden, the time label ticks without data changes, and the preview may
-- come from the newest stored line.
local function fillItemSlots(ctx, item)
  ctx[SELECTED_SLOT] = item.conversationKey == ctx.selectedConversationKey
  ctx[TIME_SLOT] = RowElements.TimeText(item, ns)
  ctx[PREVIEW_SLOT] = AddonGreetingText.ForPreview(item.conversation, item.lastPreview)
end

-- A list inside a table field (relationship.ties) against its snapshot.
-- Entries are compared by identity: a nested table changed in place would
-- not be seen, so a new nested field needs a deeper snapshot.
local function sameEntries(snapshot, value)
  for key, entry in pairs(value) do
    if snapshot[key] ~= entry then
      return false
    end
  end
  for key in pairs(snapshot) do
    if value[key] == nil then
      return false
    end
  end
  return true
end

local function sameTable(copy, count, value)
  if copy == nil then
    return false
  end
  local seen = 0
  for key, nested in pairs(value) do
    seen = seen + 1
    local stored = copy[key]
    if type(nested) == "table" then
      if type(stored) ~= "table" or not sameEntries(stored, nested) then
        return false
      end
    elseif stored ~= nested then
      return false
    end
  end
  return seen == count
end

local function sameItem(signature, item)
  local fields, nestedCopies, nestedCounts = signature.fields, signature.nested, signature.nestedCounts
  local count = 0
  for key, value in pairs(item) do
    count = count + 1
    if type(value) == "table" and not SKIPPED_FIELDS[key] then
      if not sameTable(nestedCopies[key], nestedCounts[key], value) then
        return false
      end
    elseif fields[key] ~= value then
      return false
    end
  end
  return count == signature.count
end

local function sameContext(stored, ctx)
  for slot = 1, CONTEXT_SIZE do
    if stored[slot] ~= ctx[slot] then
      return false
    end
  end
  return true
end

function RowSignature.Matches(row, item, ctx)
  local signature = row and row._wmSignature
  if signature == nil or signature.valid ~= true or item == nil then
    return false
  end
  fillItemSlots(ctx, item)
  return sameContext(signature.context, ctx) and sameItem(signature, item)
end

local function clearTable(t)
  for key in pairs(t) do
    t[key] = nil
  end
end

local function snapshotOf(value)
  local snapshot = {}
  for key, entry in pairs(value) do
    snapshot[key] = entry
  end
  return snapshot
end

local function copyNested(signature, key, value)
  local copy = signature.nested[key] or {}
  clearTable(copy)
  local count = 0
  for nestedKey, nested in pairs(value) do
    copy[nestedKey] = type(nested) == "table" and snapshotOf(nested) or nested
    count = count + 1
  end
  signature.nested[key] = copy
  signature.nestedCounts[key] = count
end

-- Records what the row was just bound from.
function RowSignature.Store(row, item, ctx)
  local signature = row._wmSignature
  if signature == nil then
    signature = { fields = {}, nested = {}, nestedCounts = {}, context = {} }
    row._wmSignature = signature
  end
  clearTable(signature.fields)
  clearTable(signature.nestedCounts)
  local count = 0
  for key, value in pairs(item) do
    count = count + 1
    signature.fields[key] = value
    if type(value) == "table" and not SKIPPED_FIELDS[key] then
      copyNested(signature, key, value)
    end
  end
  signature.count = count
  fillItemSlots(ctx, item)
  for slot = 1, CONTEXT_SIZE do
    signature.context[slot] = ctx[slot]
  end
  signature.valid = true
end

-- The row was blanked or handed to nothing: its next bind must run.
function RowSignature.Clear(row)
  local signature = row and row._wmSignature
  if signature then
    signature.valid = false
  end
end

ns.ContactsListRowSignature = RowSignature
return RowSignature
