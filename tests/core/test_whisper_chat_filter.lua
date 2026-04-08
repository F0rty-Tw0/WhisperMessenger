local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedFilter = _G.ChatFrame_AddMessageEventFilter
  local savedRemoveFilter = _G.ChatFrame_RemoveMessageEventFilter

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_chat_filters_registered_on_init_when_enabled
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    rawset(_G, "ChatFrame_AddMessageEventFilter", function(event, fn)
      filters[event] = fn
    end)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", function() end)

    Bootstrap.Initialize(factory, {
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

    -- Filters should be auto-registered on init when hideFromDefaultChat = true
    assert(filters["CHAT_MSG_WHISPER"] ~= nil, "whisper filter should be registered on init")
    assert(filters["CHAT_MSG_BN_WHISPER"] ~= nil, "BN whisper filter should be registered on init")
    assert(filters["CHAT_MSG_WHISPER_INFORM"] ~= nil, "whisper INFORM filter should be registered on init")
    assert(filters["CHAT_MSG_BN_WHISPER_INFORM"] ~= nil, "BN whisper INFORM filter should be registered on init")
    assert(Bootstrap._filtersRegistered == true, "flag should be true")

    -- The filter functions should exist on Bootstrap
    assert(type(Bootstrap._whisperFilter) == "function", "whisper filter function should exist")
    assert(type(Bootstrap._bnWhisperFilter) == "function", "BN whisper filter function should exist")
    assert(type(Bootstrap.registerChatFilters) == "function", "registerChatFilters should exist")
    assert(type(Bootstrap.unregisterChatFilters) == "function", "unregisterChatFilters should exist")
    assert(type(Bootstrap.syncChatFilters) == "function", "syncChatFilters should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_always_returns_true (trivial — no addon state access)
  -- -----------------------------------------------------------------------
  do
    local result = Bootstrap._whisperFilter(nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(result == true, "filter should always return true (registration controls when it runs)")

    local bnResult = Bootstrap._bnWhisperFilter(nil, "CHAT_MSG_BN_WHISPER", "hello", "Friend#1234")
    assert(bnResult == true, "BN filter should always return true")
  end

  -- -----------------------------------------------------------------------
  -- test_filters_not_registered_when_hideFromDefaultChat_is_false
  -- -----------------------------------------------------------------------
  do
    local registered = {}
    rawset(_G, "ChatFrame_AddMessageEventFilter", function(event, fn)
      registered[event] = fn
    end)
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", function() end)
    Bootstrap._filtersRegistered = false

    Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = { hideFromDefaultChat = false },
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    assert(
      registered["CHAT_MSG_WHISPER"] == nil,
      "whisper filter should NOT be registered when hideFromDefaultChat is false"
    )
    assert(Bootstrap._filtersRegistered == false, "flag should be false")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_does_not_call_SetLastTellTarget
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    local savedSetLast = _G.ChatEdit_SetLastTellTarget
    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalled = true
    end)

    -- Call the filter — it should NOT invoke SetLastTellTarget
    Bootstrap._whisperFilter(nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(setLastTellCalled == false, "filter must NOT call ChatEdit_SetLastTellTarget (causes taint)")

    rawset(_G, "ChatEdit_SetLastTellTarget", savedSetLast)
  end

  -- -----------------------------------------------------------------------
  -- test_sync_unregisters_when_suspended
  -- -----------------------------------------------------------------------
  do
    -- Re-initialize with hideFromDefaultChat = true so filters are registered
    rawset(_G, "ChatFrame_AddMessageEventFilter", function() end)
    local removedEvents = {}
    rawset(_G, "ChatFrame_RemoveMessageEventFilter", function(event)
      removedEvents[event] = true
    end)
    Bootstrap._filtersRegistered = false

    Bootstrap.Initialize(factory, {
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

    assert(Bootstrap._filtersRegistered == true, "filters should be registered before suspend test")

    _G._wmSuspended = true
    Bootstrap.syncChatFilters()
    assert(Bootstrap._filtersRegistered == false, "syncChatFilters should unregister when suspended")
    assert(removedEvents["CHAT_MSG_WHISPER"] == true, "whisper filter should be removed when suspended")
    assert(removedEvents["CHAT_MSG_WHISPER_INFORM"] == true, "whisper inform filter should be removed when suspended")
    assert(removedEvents["CHAT_MSG_BN_WHISPER"] == true, "BN whisper filter should be removed when suspended")
    assert(
      removedEvents["CHAT_MSG_BN_WHISPER_INFORM"] == true,
      "BN whisper inform filter should be removed when suspended"
    )
    _G._wmSuspended = nil
  end

  -- -----------------------------------------------------------------------
  -- test_sync_unregisters_during_competitive_content
  -- -----------------------------------------------------------------------
  do
    -- Re-register so we can test unregistration
    Bootstrap._filtersRegistered = false
    rawset(_G, "ChatFrame_AddMessageEventFilter", function() end)
    Bootstrap.registerChatFilters()
    assert(Bootstrap._filtersRegistered == true, "filters should be registered before competitive test")

    Bootstrap.lockdown = { active = true, since = 1, source = "ENCOUNTER_START" }
    Bootstrap.syncChatFilters()
    assert(Bootstrap._filtersRegistered == false, "syncChatFilters should unregister when lockdown is active")
    Bootstrap.lockdown = { active = false, since = 0, source = "init" }
  end

  -- -----------------------------------------------------------------------
  -- test_sync_re_registers_when_leaving_competitive_content
  -- -----------------------------------------------------------------------
  do
    assert(Bootstrap._filtersRegistered == false, "filters should be unregistered before re-register test")
    Bootstrap.syncChatFilters()
    assert(
      Bootstrap._filtersRegistered == true,
      "syncChatFilters should re-register when competitive content ends and setting is on"
    )
  end

  rawset(_G, "ChatFrame_AddMessageEventFilter", savedFilter)
  rawset(_G, "ChatFrame_RemoveMessageEventFilter", savedRemoveFilter)
  _G.UIParent = savedUIParent
end
