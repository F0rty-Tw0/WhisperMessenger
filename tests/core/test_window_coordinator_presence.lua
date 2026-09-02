local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

return function()
  local function makeBase()
    local shown = false
    local window = {
      frame = {
        shown = false,
      },
      refreshSelection = function() end,
    }
    function window.frame:IsShown()
      return shown
    end
    function window.frame:Show()
      shown = true
      self.shown = true
    end
    function window.frame:Hide()
      shown = false
      self.shown = false
    end

    local runtime = {
      availabilityByGUID = {},
      availabilityRequestedAt = {},
      now = function()
        return 1000
      end,
      chatApi = {},
      activeConversationKey = nil,
      store = { conversations = {} },
    }
    return window, runtime
  end

  local function makeContacts()
    return {
      { channel = "WOW", guid = "guid-1", conversationKey = "k1" },
      { channel = "WOW", guid = "guid-2", conversationKey = "k2" },
      { channel = "BN", conversationKey = "k3" },
    }
  end

  -- refreshContacts refreshes presence per contact GUID instead of scanning
  -- every guild and community member.
  do
    local window, runtime = makeBase()
    local ensured = {}
    local rebuilds = 0
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = makeContacts,
      getWindow = function()
        return window
      end,
      presenceCache = {
        EnsureFresh = function(guid)
          ensured[#ensured + 1] = guid
        end,
        IsStale = function()
          return true
        end,
        Rebuild = function()
          rebuilds = rebuilds + 1
        end,
      },
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    coord.refreshContacts()

    assert(#ensured == 2, "expected one presence refresh per contact GUID, got " .. #ensured)
    assert(ensured[1] == "guid-1", "expected first contact GUID refreshed, got " .. tostring(ensured[1]))
    assert(ensured[2] == "guid-2", "expected second contact GUID refreshed, got " .. tostring(ensured[2]))
    assert(rebuilds == 0, "per-contact refresh must not trigger a full rebuild, got " .. rebuilds)
  end

  -- Presence lookups are suppressed in mythic-restricted content along with
  -- the availability requests they sit beside.
  do
    local window, runtime = makeBase()
    local ensured = 0
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = makeContacts,
      getWindow = function()
        return window
      end,
      presenceCache = {
        EnsureFresh = function()
          ensured = ensured + 1
        end,
      },
      isMythicRestricted = function()
        return true
      end,
      requestAvailability = function() end,
    })

    coord.refreshContacts()

    assert(ensured == 0, "mythic-restricted content must not refresh presence, got " .. ensured)
  end

  -- Opening the window never triggers a full guild/community enumeration.
  do
    local window, runtime = makeBase()
    local rebuilds = 0
    local ensured = 0
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = makeContacts,
      getWindow = function()
        return window
      end,
      presenceCache = {
        EnsureFresh = function()
          ensured = ensured + 1
        end,
        IsStale = function()
          return true
        end,
        Rebuild = function()
          rebuilds = rebuilds + 1
        end,
      },
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    coord.setWindowVisible(true)

    assert(rebuilds == 0, "opening the window must not rebuild the whole presence cache, got " .. rebuilds)
    assert(ensured > 0, "opening the window should still freshen the visible contacts")
  end

  -- A presence cache without the targeted refresh entry point is tolerated.
  do
    local window, runtime = makeBase()
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = makeContacts,
      getWindow = function()
        return window
      end,
      presenceCache = {
        RefreshPresence = function() end,
      },
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    local ok = pcall(coord.refreshContacts)
    assert(ok, "refreshContacts must tolerate a presence cache without EnsureFresh")
  end
end
