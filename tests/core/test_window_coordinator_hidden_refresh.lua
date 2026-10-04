-- A refresh while the window is hidden keeps only the always-visible icon
-- surfaces current. Availability requests, presence freshness and the
-- selection rebuild wait for the next open, which refreshes in full.

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local function makeCoordinator()
  local h = {
    builds = {},
    availabilityRequests = {},
    ensured = {},
    selectionStates = {},
    contacts = {
      { conversationKey = "plain", channel = "WOW", guid = "g-plain", unreadCount = 2 },
      { conversationKey = "muted", channel = "WOW", guid = "g-muted", unreadCount = 5, muted = true },
    },
  }
  local shown = false
  h.window = {
    frame = {},
    refreshSelection = function(state)
      h.selectionStates[#h.selectionStates + 1] = state
    end,
  }
  function h.window.frame:IsShown()
    return shown
  end
  function h.window.frame:Show()
    shown = true
  end
  function h.window.frame:Hide()
    shown = false
  end
  h.icon = {
    setUnreadCount = function(count)
      h.badge = count
    end,
  }
  h.runtime = {
    availabilityByGUID = { gone = { status = "CanWhisper" } },
    availabilityRequestedAt = {},
    sendStatusByConversation = {},
    now = function()
      return 1000
    end,
    activeConversationKey = "plain",
    store = { conversations = { plain = { channel = "WOW", guid = "g-plain" } } },
  }
  h.coordinator = WindowCoordinator.Create({
    runtime = h.runtime,
    buildContacts = function(dirtyKeys)
      h.builds[#h.builds + 1] = dirtyKeys or false
      return h.contacts
    end,
    getWindow = function()
      return h.window
    end,
    getIcon = function()
      return h.icon
    end,
    presenceCache = {
      EnsureFresh = function(guid)
        h.ensured[#h.ensured + 1] = guid
      end,
    },
    requestAvailability = function(_api, guid)
      h.availabilityRequests[#h.availabilityRequests + 1] = guid
    end,
    cTimer = {
      NewTicker = function()
        return { Cancel = function() end }
      end,
    },
  })
  return h
end

return function()
  -- test_hidden_refresh_skips_availability_requests
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow("plain")
    assert(#h.availabilityRequests == 0, "hidden refresh must not request availability, got " .. #h.availabilityRequests)
  end

  -- test_hidden_refresh_skips_presence_freshness
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow("plain")
    assert(#h.ensured == 0, "hidden refresh must not freshen presence, got " .. #h.ensured)
  end

  -- test_hidden_refresh_skips_selection_rebuild
  do
    local h = makeCoordinator()
    local state = h.coordinator.refreshWindow("plain")
    assert(state.selectedContact == nil, "hidden refresh must not build the selection state")
    assert(state.contacts == h.contacts, "hidden refresh still returns the built contacts")
  end

  -- test_hidden_refresh_keeps_availability_caches
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow("plain")
    assert(h.runtime.availabilityByGUID.gone ~= nil, "hidden refresh must leave cache pruning to the next open")
  end

  -- test_hidden_refresh_passes_dirty_keys_to_contact_build
  do
    local h = makeCoordinator()
    local dirtyKeys = { plain = true }
    h.coordinator.refreshWindow("plain", dirtyKeys)
    assert(h.builds[#h.builds] == dirtyKeys, "hidden refresh rebuilds only the dirty contacts")
  end

  -- test_hidden_refresh_updates_badge_without_muted_unread
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow("plain")
    assert(h.badge == 2, "badge counts the unmuted unread only, got " .. tostring(h.badge))
  end

  -- test_show_after_hidden_refresh_runs_full_refresh
  do
    local h = makeCoordinator()
    h.coordinator.refreshWindow("plain", { plain = true })
    h.coordinator.setWindowVisible(true)
    assert(h.builds[#h.builds] == false, "opening rebuilds every contact")
    assert(#h.availabilityRequests == 2, "opening requests availability, got " .. #h.availabilityRequests)
    assert(#h.ensured == 2, "opening freshens presence, got " .. #h.ensured)
    assert(h.runtime.availabilityByGUID.gone == nil, "opening prunes stale availability")
    local shownState = h.selectionStates[#h.selectionStates]
    assert(shownState and shownState.selectedContact, "opening paints the selected conversation")
    assert(shownState.selectedContact.conversationKey == "plain", "opening keeps the active conversation")
  end
end
