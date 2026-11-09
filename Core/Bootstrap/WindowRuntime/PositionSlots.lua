local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PositionSlots = {}

-- character = this character's key; account = the shared account key.
local SLOTS = {
  icon = { character = "icon", account = "sharedWidgetPosition" },
  detachedPreview = { character = "detachedPreview", account = "sharedDetachedPreview" },
  minimapIcon = { character = "minimapIcon", account = "sharedMinimapIcon" },
}

local function slotFor(name)
  local slot = SLOTS[name]
  if not slot then
    error("unknown position slot: " .. tostring(name), 3)
  end
  return slot
end

function PositionSlots.Create(options)
  local accountState = options.accountState
  local characterState = options.characterState
  local copyState = options.tableUtils.copyState

  local slots = {}

  -- A missing spot is the "default spot" marker: a table with no anchor.
  local function copyOfCharacterSpot(slot)
    local own = characterState[slot.character]
    return own and copyState(own) or {}
  end

  function slots.isShared()
    local settings = accountState.settings or {}
    return settings.shareWidgetPosition == true
  end

  function slots.read(name)
    local slot = slotFor(name)
    if not slots.isShared() then
      return characterState[slot.character]
    end
    if accountState[slot.account] == nil then
      accountState[slot.account] = copyOfCharacterSpot(slot)
    end
    return accountState[slot.account]
  end

  function slots.write(name, nextState)
    local slot = slotFor(name)
    if slots.isShared() then
      accountState[slot.account] = copyState(nextState)
      return
    end
    characterState[slot.character] = copyState(nextState)
  end

  function slots.reset(name, default)
    slots.write(name, default)
    return slots.read(name)
  end

  function slots.seedAll()
    if not slots.isShared() then
      return
    end
    for name in pairs(SLOTS) do
      slots.read(name)
    end
  end

  function slots.onToggle(enabled)
    if not enabled then
      return
    end
    for _, slot in pairs(SLOTS) do
      accountState[slot.account] = copyOfCharacterSpot(slot)
    end
  end

  return slots
end

ns.BootstrapWindowRuntimePositionSlots = PositionSlots

return PositionSlots
