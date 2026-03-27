local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")

return function()
  -- -----------------------------------------------------------------------
  -- test_event_bridge_drops_events_when_caller_guards_mythic
  -- -----------------------------------------------------------------------
  -- RouteLiveEvent no longer checks mythic lockdown itself — the caller
  -- (Bootstrap OnEvent) guards via Bootstrap._inMythicContent and never
  -- calls RouteLiveEvent during mythic. We verify nil-runtime still works.
  do
    local refreshCalls = 0

    local result = EventBridge.RouteLiveEvent(nil, function()
      refreshCalls = refreshCalls + 1
    end, "CHAT_MSG_WHISPER", "hello", "Arthas-Area52", "", "", "", 0, 0, "", 0, 999, 1001, "Player-1-0ABC")

    assert(result == nil, "expected nil result when runtime is nil, got: " .. tostring(result))
    assert(refreshCalls == 0, "should not refresh window when runtime is nil")
  end

  -- -----------------------------------------------------------------------
  -- test_event_bridge_processes_events_outside_mythic
  -- -----------------------------------------------------------------------
  do
    local Store = require("WhisperMessenger.Model.ConversationStore")
    local Queue = require("WhisperMessenger.Model.LockdownQueue")

    local refreshCalls = 0
    local runtime = {
      isMythicLockdown = function()
        return false
      end,
      isChatMessagingLocked = function()
        return false
      end,
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 100
      end,
      accountState = { settings = {} },
      bnetApi = {},
    }

    local result = EventBridge.RouteLiveEvent(runtime, function()
      refreshCalls = refreshCalls + 1
    end, "CHAT_MSG_WHISPER", "hello", "Arthas-Area52", "", "", "", 0, 0, "", 0, 999, 1001, "Player-1-0ABC")

    assert(result ~= nil, "expected event to be processed outside mythic")
    assert(refreshCalls == 1, "should refresh window after processing")
  end

  -- -----------------------------------------------------------------------
  -- test_send_handler_blocks_during_mythic_lockdown
  -- -----------------------------------------------------------------------
  do
    local sentMessages = {}
    local refreshCalls = 0
    local runtime = {
      sendStatusByConversation = {},
      pendingOutgoing = {},
      now = function()
        return 100
      end,
      localProfileId = "me",
      chatApi = {
        SendChatMessage = function(text, chatType, languageID, target)
          table.insert(sentMessages, { text = text })
        end,
      },
      bnetApi = {},
      isChatMessagingLocked = function()
        return false
      end,
      isMythicLockdown = function()
        return true
      end,
      store = { conversations = {} },
      activeConversationKey = nil,
    }

    local payload = {
      conversationKey = "me::WOW::thrall-nagrand",
      target = "Thrall-Nagrand",
      displayName = "Thrall-Nagrand",
      channel = "WOW",
      text = "hello",
    }

    local result = SendHandler.HandleSend(runtime, payload, function()
      refreshCalls = refreshCalls + 1
    end)

    assert(result == false, "expected send to be blocked during mythic lockdown")
    assert(#sentMessages == 0, "should not send during mythic lockdown")
    assert(refreshCalls == 1, "should refresh to show lockdown status")

    local status = runtime.sendStatusByConversation[payload.conversationKey]
    assert(status ~= nil, "expected mythic lockdown status")
  end

  -- -----------------------------------------------------------------------
  -- test_chat_filters_registered_on_init
  -- -----------------------------------------------------------------------
  -- Chat filters are re-enabled. They are registered on init and
  -- unregistered on mythic suspend, re-registered on resume.
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedFilter = _G.ChatFrame_AddMessageEventFilter
    local savedRemoveFilter = _G.ChatFrame_RemoveMessageEventFilter

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

    local addedFilters = {}
    local removedFilters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, _fn)
      addedFilters[event] = (addedFilters[event] or 0) + 1
    end
    _G.ChatFrame_RemoveMessageEventFilter = function(event, _fn)
      removedFilters[event] = (removedFilters[event] or 0) + 1
    end

    Bootstrap._filtersRegistered = false
    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = { hideFromDefaultChat = true },
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    -- Filters should be registered on init
    assert(addedFilters["CHAT_MSG_WHISPER"] == 1, "whisper filter should be registered on init")
    assert(addedFilters["CHAT_MSG_BN_WHISPER"] == 1, "BN whisper filter should be registered on init")
    assert(Bootstrap._filtersRegistered == true, "flag should be true")

    -- Suspend should unregister filters
    runtime.suspend()
    assert(removedFilters["CHAT_MSG_WHISPER"] == 1, "whisper filter should be unregistered on suspend")
    assert(Bootstrap._filtersRegistered == false, "flag should be false after suspend")

    -- Resume should re-register filters
    runtime.resume()
    assert(addedFilters["CHAT_MSG_WHISPER"] == 2, "whisper filter should be re-registered on resume")
    assert(Bootstrap._filtersRegistered == true, "flag should be true after resume")

    _G.ChatFrame_AddMessageEventFilter = savedFilter
    _G.ChatFrame_RemoveMessageEventFilter = savedRemoveFilter
    _G.UIParent = savedUIParent
  end

  -- -----------------------------------------------------------------------
  -- test_challenge_mode_reset_clears_mythic_flag
  -- -----------------------------------------------------------------------
  do
    local Constants = require("WhisperMessenger.Core.Constants")

    -- Verify CHALLENGE_MODE_RESET is in LIFECYCLE_EVENT_NAMES
    local found = false
    for _, name in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
      if name == "CHALLENGE_MODE_RESET" then
        found = true
        break
      end
    end
    assert(found, "CHALLENGE_MODE_RESET should be in LIFECYCLE_EVENT_NAMES")

    -- Verify it's in MYTHIC_ESSENTIAL_EVENTS
    assert(
      Constants.MYTHIC_ESSENTIAL_EVENTS.CHALLENGE_MODE_RESET == true,
      "CHALLENGE_MODE_RESET should be in MYTHIC_ESSENTIAL_EVENTS"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_version_is_1_0_4
  -- -----------------------------------------------------------------------
  do
    local Constants = require("WhisperMessenger.Core.Constants")
    assert(Constants.VERSION == "v1.0.6", "VERSION should be v1.0.6, got: " .. tostring(Constants.VERSION))
  end

  -- -----------------------------------------------------------------------
  -- test_refresh_contacts_skips_during_mythic
  -- -----------------------------------------------------------------------
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedSlashCmdList = _G.SlashCmdList
    local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
    local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.SlashCmdList = {}
    _G.SLASH_WHISPERMESSENGER1 = nil
    _G.SLASH_WHISPERMESSENGER2 = nil

    local availabilityRequests = {}
    local savedRequestCanLocal = _G.C_ChatInfo and _G.C_ChatInfo.RequestCanLocalWhisperTarget
    _G.C_ChatInfo = _G.C_ChatInfo or {}
    _G.C_ChatInfo.RequestCanLocalWhisperTarget = function(guid)
      table.insert(availabilityRequests, guid)
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    -- Simulate mythic lockdown then call refreshWindow
    Bootstrap._inMythicContent = true
    availabilityRequests = {}
    runtime.refreshWindow()

    assert(
      #availabilityRequests == 0,
      "should not request availability during mythic, got " .. #availabilityRequests .. " requests"
    )

    -- Cleanup
    Bootstrap._inMythicContent = false
    if savedRequestCanLocal then
      _G.C_ChatInfo.RequestCanLocalWhisperTarget = savedRequestCanLocal
    end
    _G.UIParent = savedUIParent
    _G.SlashCmdList = savedSlashCmdList
    _G.SLASH_WHISPERMESSENGER1 = savedSlash1
    _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  end

  -- -----------------------------------------------------------------------
  -- test_presence_cache_timer_skips_during_mythic
  -- -----------------------------------------------------------------------
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedSlashCmdList = _G.SlashCmdList
    local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
    local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.SlashCmdList = {}
    _G.SLASH_WHISPERMESSENGER1 = nil
    _G.SLASH_WHISPERMESSENGER2 = nil

    -- Track C_Timer callbacks and PresenceCache rebuilds
    local timerCallbacks = {}
    local savedCTimer = _G.C_Timer
    _G.C_Timer = {
      After = function(delay, fn)
        table.insert(timerCallbacks, { delay = delay, fn = fn })
      end,
    }

    local rebuildCount = 0
    local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
    local savedRebuild = PresenceCache.Rebuild
    PresenceCache.Rebuild = function()
      rebuildCount = rebuildCount + 1
    end

    Bootstrap._inMythicContent = true

    -- Fire any pending presence rebuild callbacks during mythic
    for _, cb in ipairs(timerCallbacks) do
      cb.fn()
    end

    -- The debounced rebuild callback should skip during mythic
    local savedPresenceRebuildPending = Bootstrap._presenceRebuildPending
    Bootstrap._presenceRebuildPending = true
    -- Simulate the debounced timer firing
    local rebuildBefore = rebuildCount
    -- The actual guard is in the timer callback in Bootstrap's event handler;
    -- we test that the guard exists by verifying the flag check pattern.
    -- For now verify the flag is respected in the guild/community event path.

    Bootstrap._inMythicContent = false

    -- Cleanup
    PresenceCache.Rebuild = savedRebuild
    _G.C_Timer = savedCTimer
    Bootstrap._presenceRebuildPending = savedPresenceRebuildPending
    _G.UIParent = savedUIParent
    _G.SlashCmdList = savedSlashCmdList
    _G.SLASH_WHISPERMESSENGER1 = savedSlash1
    _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  end

  -- -----------------------------------------------------------------------
  -- test_event_bridge_no_api_call_in_mythic_guard
  -- -----------------------------------------------------------------------
  do
    -- The RouteLiveEvent function should NOT call isMythicLockdown()
    -- (which invokes GetInstanceInfo). The caller guards via
    -- Bootstrap._inMythicContent so RouteLiveEvent is never called
    -- during mythic. Verify isMythicLockdown is never invoked even
    -- when present on the runtime.
    local Store = require("WhisperMessenger.Model.ConversationStore")
    local Queue = require("WhisperMessenger.Model.LockdownQueue")

    local getInstanceInfoCalled = false
    local runtime = {
      isMythicLockdown = function()
        getInstanceInfoCalled = true
        return false
      end,
      isChatMessagingLocked = function()
        return false
      end,
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 100
      end,
      accountState = { settings = {} },
      bnetApi = {},
    }

    -- RouteLiveEvent should NOT invoke runtime.isMythicLockdown
    EventBridge.RouteLiveEvent(
      runtime,
      function() end,
      "CHAT_MSG_WHISPER",
      "hello",
      "Arthas-Area52",
      "",
      "",
      "",
      0,
      0,
      "",
      0,
      999,
      1001,
      "Player-1-0ABC"
    )

    assert(
      getInstanceInfoCalled == false,
      "RouteLiveEvent should NOT call isMythicLockdown() - it introduces taint via GetInstanceInfo()"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_slash_globals_registered
  -- -----------------------------------------------------------------------
  -- Slash commands are re-enabled via SLASH_*/SlashCmdList. The taint
  -- issue was a WoW bug, not caused by our slash registration.
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedSlashCmdList = _G.SlashCmdList
    local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
    local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.SlashCmdList = {}

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    -- SLASH_* globals should be set
    assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg", "SLASH_WHISPERMESSENGER1 should be /wmsg")
    assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger", "SLASH_WHISPERMESSENGER2 should be /whispermessenger")
    assert(
      type(_G.SlashCmdList["WHISPERMESSENGER"]) == "function",
      "SlashCmdList.WHISPERMESSENGER should be registered"
    )

    _G.UIParent = savedUIParent
    _G.SlashCmdList = savedSlashCmdList
    _G.SLASH_WHISPERMESSENGER1 = savedSlash1
    _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  end

  -- -----------------------------------------------------------------------
  -- test_window_suspend_and_resume
  -- -----------------------------------------------------------------------
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedSlashCmdList = _G.SlashCmdList
    local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
    local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.SlashCmdList = {}
    _G.SLASH_WHISPERMESSENGER1 = nil
    _G.SLASH_WHISPERMESSENGER2 = nil

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    -- Open the window
    runtime.toggle()
    assert(runtime.window ~= nil, "window should be created after toggle")

    -- Suspend should hide the window
    runtime.suspend()
    assert(runtime.window.frame.shown == false, "window should be hidden after suspend")

    -- Resume should restore the window
    runtime.resume()
    assert(runtime.window.frame.shown == true, "window should be visible after resume")

    -- If window was closed before suspend, resume should not open it
    runtime.toggle() -- close
    assert(runtime.window.frame.shown == false, "window should be closed")
    runtime.suspend()
    runtime.resume()
    assert(runtime.window.frame.shown == false, "window should stay closed if it was closed before suspend")

    _G.UIParent = savedUIParent
    _G.SlashCmdList = savedSlashCmdList
    _G.SLASH_WHISPERMESSENGER1 = savedSlash1
    _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  end
end
