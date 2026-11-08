local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Registry of the addons that use the public API: one saved tick per addon
-- name ({ title, allowed } under accountState.addonIntegrations), plus
-- session-only state (who connected this session, what the tick said at the
-- first connect, who owns which panel / preview / note).
-- "" is the shared API table's row ("Other addons"): callers that name nobody.
local AddonIntegrations = {}

AddonIntegrations.SHARED = ""

local SHARED = AddonIntegrations.SHARED

-- "|cff00ff00Craft|r Alert" sorts as "craft alert".
local function sortKey(row)
  local text = row.title
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  return text:lower()
end

local function sortRows(rows)
  local keys = {}
  for _, row in ipairs(rows) do
    keys[row] = sortKey(row)
  end
  table.sort(rows, function(a, b)
    if a.shared ~= b.shared then
      return b.shared
    end
    if a.seen ~= b.seen then
      return a.seen
    end
    if keys[a] ~= keys[b] then
      return keys[a] < keys[b]
    end
    return a.name < b.name
  end)
end

function AddonIntegrations.New(accountState, lookupTitle)
  local registry = {}
  local privateRows = {}
  local seen = {}
  local mark = {}
  local owners = {}
  local listeners = {}

  -- The saved table, created on first write; a missing account keeps rows in memory.
  local function ensure()
    if type(accountState) ~= "table" then
      return privateRows
    end
    if type(accountState.addonIntegrations) ~= "table" then
      accountState.addonIntegrations = {}
    end
    return accountState.addonIntegrations
  end

  local function saved()
    if type(accountState) == "table" and type(accountState.addonIntegrations) == "table" then
      return accountState.addonIntegrations
    end
    return privateRows
  end

  local function fire(event, name)
    for _, listener in ipairs(listeners) do
      pcall(listener, event, name)
    end
  end

  local function resolveTitle(name, row)
    if name == SHARED then
      return ""
    end
    if type(lookupTitle) == "function" then
      local ok, title = pcall(lookupTitle, name)
      if ok and type(title) == "string" and title ~= "" then
        return title
      end
    end
    if type(row.title) == "string" and row.title ~= "" then
      return row.title
    end
    return name
  end

  function registry.touch(name)
    local rows = ensure()
    local row = rows[name]
    local isNew = row == nil
    if isNew then
      row = { allowed = true }
      rows[name] = row
    end
    if mark[name] == nil then
      mark[name] = row.allowed and "allowed" or "refused"
    end
    local firstSeen = not seen[name]
    seen[name] = true
    local title = resolveTitle(name, row)
    local titleChanged = row.title ~= title
    row.title = title
    if isNew or firstSeen or titleChanged then
      fire("touched", name)
    end
  end

  function registry.isAllowed(name)
    local row = saved()[name]
    return row == nil or row.allowed ~= false
  end

  function registry.setAllowed(name, on)
    local row = saved()[name]
    on = on and true or false
    if row == nil or row.allowed == on then
      return
    end
    row.allowed = on
    fire(on and "allowed" or "refused", name)
  end

  function registry.connectedRefused(name)
    return mark[name] == "refused"
  end

  function registry.forget(name)
    local rows = saved()
    if rows[name] == nil or seen[name] then
      return false
    end
    rows[name] = nil
    mark[name] = nil
    fire("forgotten", name)
    return true
  end

  function registry.rows()
    local list = {}
    for name, row in pairs(saved()) do
      local isShared = name == SHARED
      local isSeen = seen[name] == true
      if not isShared or isSeen or row.allowed == false then
        local title = type(row.title) == "string" and row.title or name
        list[#list + 1] = { name = name, title = title, allowed = row.allowed ~= false, seen = isSeen, shared = isShared }
      end
    end
    sortRows(list)
    return list
  end

  function registry.claim(kind, key, owner)
    if type(owner) ~= "string" then
      return
    end
    owners[kind] = owners[kind] or {}
    owners[kind][key] = owner
  end

  function registry.ownerOf(kind, key)
    return owners[kind] and owners[kind][key] or nil
  end

  function registry.ownedBy(kind, owner)
    local keys = {}
    for key, keyOwner in pairs(owners[kind] or {}) do
      if keyOwner == owner then
        keys[#keys + 1] = key
      end
    end
    return keys
  end

  function registry.onChange(fn)
    listeners[#listeners + 1] = fn
  end

  return registry
end

ns.AddonIntegrations = AddonIntegrations
return AddonIntegrations
