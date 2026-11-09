local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconPosition = ns.BootstrapWindowRuntimeIconPosition or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconPosition")

local PositionSlots = {}

-- The window fields one account spot carries. Everything else a window state
-- holds (collapsed rail, minimized, compact layout) stays per character.
PositionSlots.SHARED_WINDOW_FIELDS = { "anchorPoint", "relativePoint", "x", "y", "width", "height", "contactsWidth" }

local SHARED_WINDOW_SET = {}
for _, field in ipairs(PositionSlots.SHARED_WINDOW_FIELDS) do
  SHARED_WINDOW_SET[field] = true
end

-- character = this character's key; account = the shared account key.
-- fields = true: only the shared window fields go to the account.
-- markerWhenMissing = true: no character spot reads as the default marker {}.
local SLOTS = {
  icon = { character = "icon", account = "sharedWidgetPosition" },
  detachedPreview = { character = "detachedPreview", account = "sharedDetachedPreview" },
  minimapIcon = { character = "minimapIcon", account = "sharedMinimapIcon" },
  window = { character = "window", account = "sharedWindow", fields = true },
  compactWindow = { character = "compactWindow", account = "sharedCompactWindow", fields = true, markerWhenMissing = true },
}

local function slotFor(name)
  local slot = SLOTS[name]
  if not slot then
    error("unknown position slot: " .. tostring(name), 3)
  end
  return slot
end

-- Splits a window state into its shared fields and the rest.
local function splitWindowState(state)
  local shared, rest = {}, {}
  for key, value in pairs(state or {}) do
    local target = SHARED_WINDOW_SET[key] and shared or rest
    target[key] = value
  end
  return shared, rest
end

function PositionSlots.Create(options)
  local accountState = options.accountState
  local characterState = options.characterState
  local copyState = options.tableUtils.copyState

  local slots = {}

  -- A missing spot is the "default spot" marker: a table with no anchor.
  local function accountSpotFromCharacter(slot)
    local own = characterState[slot.character]
    if slot.fields then
      return (splitWindowState(own))
    end
    return own and copyState(own) or {}
  end

  local function seedAccountSpot(slot)
    if accountState[slot.account] == nil then
      accountState[slot.account] = accountSpotFromCharacter(slot)
    end
  end

  local function readCharacterSpot(slot)
    local own = characterState[slot.character]
    if own == nil and slot.markerWhenMissing then
      return {}
    end
    return own
  end

  -- Shared window: this character's non-geometry fields + the account geometry.
  local function readSharedWindow(slot)
    local _, rest = splitWindowState(characterState[slot.character])
    for key, value in pairs(accountState[slot.account]) do
      rest[key] = value
    end
    return rest
  end

  local function writeSharedWindow(slot, nextState)
    local shared, rest = splitWindowState(nextState)
    accountState[slot.account] = shared
    local own = characterState[slot.character] or {}
    for key, value in pairs(rest) do
      own[key] = value
    end
    characterState[slot.character] = own
  end

  function slots.isShared()
    local settings = accountState.settings or {}
    return settings.shareWidgetPosition == true
  end

  function slots.read(name)
    local slot = slotFor(name)
    if not slots.isShared() then
      return readCharacterSpot(slot)
    end
    seedAccountSpot(slot)
    if slot.fields then
      return readSharedWindow(slot)
    end
    return accountState[slot.account]
  end

  function slots.write(name, nextState)
    local slot = slotFor(name)
    if not slots.isShared() then
      characterState[slot.character] = copyState(nextState)
    elseif slot.fields then
      writeSharedWindow(slot, nextState)
    else
      accountState[slot.account] = copyState(nextState)
    end
  end

  function slots.reset(name, default)
    local slot = slotFor(name)
    if name == "compactWindow" then
      if slots.isShared() then
        -- {} (not nil) keeps the next login from re-seeding the account spot.
        accountState[slot.account] = {}
      else
        characterState[slot.character] = nil
      end
      return nil
    end
    slots.write(name, default)
    return slots.read(name)
  end

  function slots.seedAll()
    if not slots.isShared() then
      return
    end
    for _, slot in pairs(SLOTS) do
      seedAccountSpot(slot)
    end
  end

  function slots.onToggle(enabled)
    if not enabled then
      return
    end
    for _, slot in pairs(SLOTS) do
      accountState[slot.account] = accountSpotFromCharacter(slot)
    end
  end

  return slots
end

-- Moves every created surface to its slot's spot. Each surface may be nil
-- (the widget, minimap button and preview are created lazily).
function PositionSlots.Reapply(slots, surfaces)
  if surfaces.icon then
    IconPosition.Apply(surfaces.icon, slots.read("icon"), surfaces.uiParent)
  end
  if surfaces.window then
    local windowSlot = surfaces.compactLayoutActive and "compactWindow" or "window"
    surfaces.window.applySavedState(slots.read(windowSlot))
  end
  if surfaces.minimap then
    surfaces.minimap.applyRadialPosition(slots.read("minimapIcon"))
  end
  if surfaces.detached then
    surfaces.detached.applySavedSpot()
  end
end

ns.BootstrapWindowRuntimePositionSlots = PositionSlots

return PositionSlots
