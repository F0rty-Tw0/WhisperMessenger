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

  -- refreshContacts throttles RequestAvailability within 10s window per-guid
  do
    local window, runtime = makeBase()
    local requestCalls = {}
    local contacts = {
      { channel = "WOW", guid = "g1", conversationKey = "k1" },
      { channel = "WOW", guid = "g2", conversationKey = "k2" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function(_api, guid)
        table.insert(requestCalls, guid)
      end,
    })

    coord.refreshContacts()
    assert(#requestCalls == 2, "first refresh should request for both guids, got: " .. tostring(#requestCalls))

    coord.refreshContacts()
    assert(#requestCalls == 2, "same-timestamp repeat must be throttled, got: " .. tostring(#requestCalls))

    runtime.now = function()
      return 1011
    end
    coord.refreshContacts()
    assert(#requestCalls == 4, "after 10s window elapses, both guids re-requested, got: " .. tostring(#requestCalls))
  end

  -- setWindowVisible(true) starts a status ticker; setWindowVisible(false) cancels it
  do
    local window, runtime = makeBase()
    local tickers = {}
    local cTimer = {
      NewTicker = function(interval, cb)
        local t = { interval = interval, cb = cb, cancelled = false }
        function t:Cancel()
          self.cancelled = true
        end
        table.insert(tickers, t)
        return t
      end,
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
      cTimer = cTimer,
    })

    coord.setWindowVisible(true)
    assert(#tickers == 1, "visible show should start one ticker, got: " .. tostring(#tickers))
    assert(tickers[1].interval == 30, "ticker interval should be 30s, got: " .. tostring(tickers[1].interval))
    assert(tickers[1].cancelled == false, "new ticker not yet cancelled")

    coord.setWindowVisible(false)
    assert(tickers[1].cancelled == true, "hiding window should cancel ticker")

    coord.setWindowVisible(true)
    assert(#tickers == 2, "reopening should spawn a new ticker")
    assert(tickers[2].cancelled == false, "replacement ticker is active")
  end

  -- Ticker callback calls refreshContacts when window visible
  do
    local window, runtime = makeBase()
    local tickerCbs = {}
    local cTimer = {
      NewTicker = function(_interval, cb)
        table.insert(tickerCbs, cb)
        return {
          Cancel = function(self)
            self.cancelled = true
          end,
        }
      end,
    }
    local requestCalls = {}
    local contacts = {
      { channel = "WOW", guid = "g1", conversationKey = "k1" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function(_api, guid)
        table.insert(requestCalls, guid)
      end,
      cTimer = cTimer,
    })

    coord.setWindowVisible(true)
    local initial = #requestCalls

    -- Advance past throttle and invoke the ticker's registered callback
    runtime.now = function()
      return 1011
    end
    tickerCbs[1]()
    assert(
      #requestCalls == initial + 1,
      "ticker tick should invoke a refresh, got delta: " .. tostring(#requestCalls - initial)
    )
  end

  -- scheduleAvailabilityRefresh: fires a deferred refreshWindow while visible
  do
    local window, runtime = makeBase()
    local afterCalls = {}
    local cTimer = {
      NewTicker = function(_, _)
        return { Cancel = function() end }
      end,
      After = function(delay, cb)
        table.insert(afterCalls, { delay = delay, cb = cb })
      end,
    }
    local refreshCount = 0
    local refreshSelectionCalls = 0
    window.refreshSelection = function()
      refreshSelectionCalls = refreshSelectionCalls + 1
    end

    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
      cTimer = cTimer,
    })

    coord.setWindowVisible(true)
    assert(
      type(coord.scheduleAvailabilityRefresh) == "function",
      "coordinator should expose scheduleAvailabilityRefresh"
    )

    refreshSelectionCalls = 0
    coord.scheduleAvailabilityRefresh("g1")
    assert(#afterCalls == 1, "first schedule should enqueue one After call, got: " .. tostring(#afterCalls))
    assert(afterCalls[1].delay > 0, "debounce delay should be positive")
    assert(refreshSelectionCalls == 0, "refresh should be deferred, not immediate")

    -- Multiple calls within the debounce window coalesce into zero additional After calls
    coord.scheduleAvailabilityRefresh("g2")
    coord.scheduleAvailabilityRefresh("g3")
    assert(#afterCalls == 1, "coalesced calls should not enqueue more, got: " .. tostring(#afterCalls))

    -- Fire the scheduled callback → refresh actually happens
    afterCalls[1].cb()
    assert(
      refreshSelectionCalls == 1,
      "deferred callback should trigger refresh, got: " .. tostring(refreshSelectionCalls)
    )

    -- Subsequent schedule after drain enqueues a new After
    coord.scheduleAvailabilityRefresh("g4")
    assert(#afterCalls == 2, "new schedule after drain should enqueue, got: " .. tostring(#afterCalls))
  end

  -- scheduleAvailabilityRefresh no-ops when window hidden
  do
    local window, runtime = makeBase()
    local afterCalls = {}
    local cTimer = {
      NewTicker = function(_, _)
        return { Cancel = function() end }
      end,
      After = function(_delay, cb)
        table.insert(afterCalls, cb)
      end,
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
      cTimer = cTimer,
    })

    -- Window never shown
    coord.scheduleAvailabilityRefresh("g1")
    assert(#afterCalls == 0, "hidden window should skip scheduling, got: " .. tostring(#afterCalls))
  end

  -- Ticker callback is a no-op when window becomes hidden mid-interval
  do
    local window, runtime = makeBase()
    local tickerCbs = {}
    local cTimer = {
      NewTicker = function(_interval, cb)
        table.insert(tickerCbs, cb)
        return {
          Cancel = function(self)
            self.cancelled = true
          end,
        }
      end,
    }
    local requestCalls = {}
    local contacts = {
      { channel = "WOW", guid = "g1", conversationKey = "k1" },
    }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return contacts
      end,
      getWindow = function()
        return window
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function(_api, guid)
        table.insert(requestCalls, guid)
      end,
      cTimer = cTimer,
    })

    coord.setWindowVisible(true)
    local initial = #requestCalls

    -- Simulate an external Hide (bypassing setWindowVisible so we test tick-side guard)
    window.frame:Hide()
    runtime.now = function()
      return 1011
    end
    tickerCbs[1]()
    assert(
      #requestCalls == initial,
      "ticker must not refresh while hidden, got delta: " .. tostring(#requestCalls - initial)
    )
  end

  -- refreshContacts suppresses the widget preview while the window is open,
  -- and restores it once the window is hidden.
  do
    local window, runtime = makeBase()
    local previewCalls = {}
    local icon = {
      setUnreadCount = function() end,
      setIncomingPreview = function(senderName, messageText, classTag)
        table.insert(previewCalls, { sender = senderName, message = messageText, class = classTag })
      end,
    }
    local previewData = { senderName = "Jaina", messageText = "Need help?", classTag = "MAGE" }
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      getIcon = function()
        return icon
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
      buildMessagePreview = function()
        return previewData
      end,
    })

    window.frame:Show()
    coord.refreshContacts()
    local lastCall = previewCalls[#previewCalls]
    assert(lastCall ~= nil, "refreshContacts should call setIncomingPreview even when window is visible")
    assert(
      lastCall.sender == nil and lastCall.message == nil and lastCall.class == nil,
      "while window visible, preview should be cleared (all-nil args)"
    )

    window.frame:Hide()
    coord.refreshContacts()
    lastCall = previewCalls[#previewCalls]
    assert(
      lastCall.sender == "Jaina" and lastCall.message == "Need help?" and lastCall.class == "MAGE",
      "after window hidden, preview should be populated again"
    )
  end
end
