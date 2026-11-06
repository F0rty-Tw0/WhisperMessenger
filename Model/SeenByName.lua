local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")

-- A memory-only store of one value per player, keyed by SeenLevel.NameKey.
-- SeenZone and SeenGuild wrap it; each keeps its own value rules.
local SeenByName = {}

-- A failed check counts as secret: a 12.0 secret value must never be stored.
function SeenByName.IsSecret(value)
  local issecretvalue = _G.issecretvalue
  if type(issecretvalue) ~= "function" then
    return false
  end
  local ok, secret = pcall(issecretvalue, value)

  return not ok or secret == true
end

-- limits.MAX_ENTRIES is read on every Put, so a module can override it.
-- Past the cap the whole store is wiped.
function SeenByName.New(limits)
  local store = {}
  local byName = {}
  local entryCount = 0

  local function clear()
    for key in pairs(byName) do
      byName[key] = nil
    end
    entryCount = 0
  end

  function store.Put(name, value)
    local key = SeenLevel.NameKey(name)
    if key == nil then
      return false
    end
    if byName[key] == nil then
      if entryCount + 1 > limits.MAX_ENTRIES then
        clear()
      end
      entryCount = entryCount + 1
    end
    byName[key] = value

    return true
  end

  function store.Get(name)
    local key = SeenLevel.NameKey(name)

    return key ~= nil and byName[key] or nil
  end

  store.Reset = clear

  return store
end

ns.SeenByName = SeenByName

return SeenByName
