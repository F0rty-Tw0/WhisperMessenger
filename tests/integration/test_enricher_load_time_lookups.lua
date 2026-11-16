-- The live client's `require` throws, so `ns.X or require(...)` must find
-- ns.X. The load-order test proves that only for lookups made while a file
-- loads. These files load after everything they read, so they resolve every
-- dependency at load and read the namespace no more once the addon is up.
local FakeUI = require("tests.helpers.fake_ui")

local WATCHED = {
  ["Model/ContactEnricher/Disambiguation.lua"] = true,
  ["Model/ContactEnricher/WoWStatus.lua"] = true,
  ["Model/ContactEnricher/BNetStatus.lua"] = true,
  ["Model/ContactEnricher/AvailabilityEnricher.lua"] = true,
  ["Model/ContactEnricher/ContactEnricher.lua"] = true,
  ["Model/OnlineWatch.lua"] = true,
  ["Model/ProfileCharacter.lua"] = true,
}

-- Relationship keeps three call-time lookups; only its resolver is checked.
local RELATIONSHIP = "Model/Relationship.lua"

-- Stands in for the namespace of one file and reports each read of it.
local function watchedNamespace(ns, path, onRead)
  return setmetatable({}, {
    __index = function(_, key)
      onRead(path, key)
      return ns[key]
    end,
    __newindex = function(_, key, value)
      ns[key] = value
    end,
  })
end

-- Files are matched by exact TOC path, so a renamed or mistyped path would
-- drop out of the check without failing it.
local function assertAllWatchedLoaded(proxied)
  local expected = 1
  local missing = {}
  if not proxied[RELATIONSHIP] then
    missing[#missing + 1] = RELATIONSHIP
  end
  for path in pairs(WATCHED) do
    expected = expected + 1
    if not proxied[path] then
      missing[#missing + 1] = path
    end
  end
  table.sort(missing)
  assert(
    #missing == 0,
    string.format("loaded %d of %d watched files; the TOC never loads: %s", expected - #missing, expected, table.concat(missing, ", "))
  )
end

local function loadAddon(onRead)
  local ns = {}
  local proxied = {}
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local watched = WATCHED[line] or line == RELATIONSHIP
      local chunk = assert(loadfile(line))
      chunk("WhisperMessenger", watched and watchedNamespace(ns, line, onRead) or ns)
      proxied[line] = watched or nil
    end
  end
  assertAllWatchedLoaded(proxied)
  return ns
end

local function newRuntime()
  return {
    availabilityByGUID = { cached = { status = "CanWhisperGuild" } },
    sendStatusByConversation = {},
    store = { conversations = {} },
    localFaction = "Alliance",
    bnetApi = {},
  }
end

-- One entry per function that used to look a module up when called.
local function calls(ns)
  local WoWStatus = ns.ContactEnricherWoWStatus
  local BNetStatus = ns.ContactEnricherBNetStatus
  local ContactEnricher = ns.ContactEnricher
  local function bnetItem()
    return { channel = "BN", bnetAccountID = 1, displayName = "Friend#1" }
  end

  return {
    function()
      ns.ContactEnricherDisambiguation.ResolveWrongFaction({ guid = "cached" }, newRuntime(), true)
    end,
    function()
      WoWStatus.ResolveGuild({ status = "CanWhisperGuild" }, "Alliance", "Alliance")
    end,
    function()
      WoWStatus.ApplyCached({ guid = "cached", channel = "WOW" }, newRuntime())
    end,
    function()
      WoWStatus.ApplyPresenceFallback({ guid = "uncached", channel = "WOW" }, newRuntime())
    end,
    function()
      WoWStatus.ApplySeenZone({ displayName = "Stranger" })
    end,
    function()
      BNetStatus.ApplyGameInfoMetadata({}, { characterName = "Friend" }, newRuntime())
    end,
    function()
      BNetStatus.Apply(bnetItem(), newRuntime())
    end,
    function()
      ns.OnlineWatch.ReadOnline(newRuntime(), bnetItem())
    end,
    function()
      ns.AvailabilityEnricher.EnrichContactsAvailability({ { channel = "WOW", displayName = "Stranger" } }, newRuntime())
    end,
    function()
      ContactEnricher.BuildConversationStatus(newRuntime(), "wow::cached", { guid = "cached" })
    end,
    function()
      ContactEnricher.EnrichContactsPresence({}, newRuntime())
    end,
    function()
      ContactEnricher.EnrichContactsRelationship({}, newRuntime())
    end,
    function()
      ContactEnricher.BuildWindowSelectionState(newRuntime(), {})
    end,
    function()
      ns.Relationship.Resolve(bnetItem(), newRuntime())
    end,
    function()
      ns.ProfileCharacter.FromItem(bnetItem(), {}, { projectId = 1, regionId = 1 })
    end,
  }
end

return function()
  local savedRequire = require
  local savedCreateFrame = _G.CreateFrame
  local lateReads = {}
  local loaded = false

  rawset(_G, "CreateFrame", FakeUI.NewFactory().CreateFrame)
  rawset(_G, "require", function(moduleName)
    error("Invalid import: No module with that name exists (" .. tostring(moduleName) .. ")")
  end)

  local ok, err = pcall(function()
    local ns = loadAddon(function(path, key)
      if loaded then
        lateReads[#lateReads + 1] = path .. " reads ns." .. tostring(key)
      end
    end)
    loaded = true
    for _, call in ipairs(calls(ns)) do
      call()
    end
  end)

  rawset(_G, "require", savedRequire)
  rawset(_G, "CreateFrame", savedCreateFrame)

  assert(ok, tostring(err))
  assert(#lateReads == 0, "looked up after load:\n" .. table.concat(lateReads, "\n"))
end
