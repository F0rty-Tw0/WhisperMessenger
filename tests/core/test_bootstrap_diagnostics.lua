local Diagnostics = require("WhisperMessenger.Core.Bootstrap.Diagnostics")

return function()
  local unpackValues = table.unpack or unpack
  local traces = {}
  local refreshedPresence = {}
  local enrichCalls = {}
  local memoryUsageQueries = {}
  local gcCalls = {}

  local function trace(message)
    traces[#traces + 1] = message
  end

  local function makeFrame(regionCount, childCount)
    local frame = {}

    function frame:GetRegions()
      local regions = {}
      for index = 1, regionCount do
        regions[index] = { region = index }
      end
      return unpackValues(regions)
    end

    function frame:GetChildren()
      local children = {}
      for index = 1, childCount do
        children[index] = { child = index }
      end
      return unpackValues(children)
    end

    return frame
  end

  local conversationKey = "me::WOW::arthas-area52"
  local runtime = {
    store = {
      conversations = {
        [conversationKey] = {
          displayName = "Arthas-Area52",
          contactDisplayName = "Arthas",
          battleTag = nil,
          channel = "WOW",
          guid = "Player-3676-0ABCDEF0",
          bnetAccountID = nil,
          gameAccountName = nil,
          className = "Paladin",
          classTag = "PALADIN",
          raceName = "Human",
          raceTag = "Human",
          factionName = "Alliance",
          unreadCount = 2,
          lastActivityAt = 12345,
          lastPreview = "For the Alliance",
          activeStatus = {
            eventName = "Dungeon",
            text = "At key level 10",
          },
          messages = {
            { text = "hello" },
            { text = "again" },
          },
        },
      },
    },
    availabilityByGUID = {
      ["Player-3676-0ABCDEF0"] = {
        status = "Online",
        canWhisper = true,
        rawStatus = 7,
      },
    },
    pendingOutgoing = {
      [conversationKey] = true,
    },
    localFaction = "Alliance",
  }

  local diagnostics = Diagnostics.Create({
    addonName = "WhisperMessenger",
    runtime = runtime,
    trace = trace,
    presenceCache = {
      GetPresence = function(guid)
        assert(guid == "Player-3676-0ABCDEF0")
        return "guild-presence"
      end,
      IsStale = function()
        return false
      end,
      RefreshPresence = function(guid)
        refreshedPresence[#refreshedPresence + 1] = guid
        return "fresh-presence"
      end,
    },
    contactEnricher = {
      EnrichContactsAvailability = function(contacts, runtimeArg)
        enrichCalls[#enrichCalls + 1] = {
          contacts = contacts,
          runtime = runtimeArg,
        }
        contacts[1].availability = {
          status = "Online",
          canWhisper = true,
        }
      end,
    },
    getWindow = function()
      return {
        conversation = {
          transcript = {
            content = {
              _activeFrames = {
                makeFrame(2, 1),
                makeFrame(1, 0),
              },
              _freeFrames = {
                makeFrame(3, 1),
              },
            },
          },
        },
      }
    end,
    isWindowVisible = function()
      return true
    end,
    updateAddOnMemoryUsage = function() end,
    getAddOnMemoryUsage = function(name)
      memoryUsageQueries[#memoryUsageQueries + 1] = name
      return (#memoryUsageQueries == 1) and 12.5 or 8.5
    end,
    collectgarbage = function(action)
      gcCalls[#gcCalls + 1] = action
      if action == "count" then
        return 64
      end
    end,
  })

  assert(type(diagnostics) == "table", "Create should return a table")
  assert(type(diagnostics.debugContact) == "function", "Create should return debugContact")
  assert(type(diagnostics.memoryReport) == "function", "Create should return memoryReport")

  diagnostics.debugContact(conversationKey)
  diagnostics.memoryReport()

  assert(#refreshedPresence == 1, "debugContact should refresh presence for the selected contact")
  assert(refreshedPresence[1] == "Player-3676-0ABCDEF0")
  assert(#enrichCalls == 1, "debugContact should invoke the contact enricher")
  assert(enrichCalls[1].runtime == runtime, "contact enricher should receive the injected runtime")
  assert(enrichCalls[1].contacts[1].guid == "Player-3676-0ABCDEF0")

  assert(#memoryUsageQueries == 2, "memoryReport should query addon memory before and after GC")
  assert(memoryUsageQueries[1] == "WhisperMessenger")
  assert(memoryUsageQueries[2] == "WhisperMessenger")
  assert(gcCalls[1] == "collect", "memoryReport should trigger a GC collection before measuring")
  assert(gcCalls[2] == "count", "memoryReport should report Lua memory usage")

  local joined = table.concat(traces, "\n")
  assert(
    string.find(joined, "--- Contact Debug ---", 1, true) ~= nil,
    "debugContact should preserve the contact debug header"
  )
  assert(
    string.find(joined, "[enriched] final availability (what the UI displays):", 1, true) ~= nil,
    "debugContact should report enriched availability"
  )
  assert(
    string.find(joined, "=== WhisperMessenger Memory Report ===", 1, true) ~= nil,
    "memoryReport should print the memory report header"
  )
  assert(
    string.find(joined, "Frames: 2 active / 1 free / 3 total  |  regions: 8", 1, true) ~= nil,
    "memoryReport should include frame pool region counts"
  )
  assert(
    string.find(joined, "=== End Memory Report ===", 1, true) ~= nil,
    "memoryReport should print the memory report footer"
  )
end
