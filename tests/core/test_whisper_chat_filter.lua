local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedFilter = _G.ChatFrame_AddMessageEventFilter
  local savedRemoveFilter = _G.ChatFrame_RemoveMessageEventFilter

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_chat_filters_registered_on_init
  -- -----------------------------------------------------------------------
  do
    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end
    _G.ChatFrame_RemoveMessageEventFilter = function() end

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

    -- Filters should be auto-registered on init
    assert(filters["CHAT_MSG_WHISPER"] ~= nil, "whisper filter should be registered on init")
    assert(filters["CHAT_MSG_BN_WHISPER"] ~= nil, "BN whisper filter should be registered on init")
    assert(Bootstrap._filtersRegistered == true, "flag should be true")

    -- The filter functions should exist on Bootstrap
    assert(type(Bootstrap._whisperFilter) == "function", "whisper filter function should exist")
    assert(type(Bootstrap._bnWhisperFilter) == "function", "BN whisper filter function should exist")
    assert(type(Bootstrap.registerChatFilters) == "function", "registerChatFilters should exist")
    assert(type(Bootstrap.unregisterChatFilters) == "function", "unregisterChatFilters should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_suppresses_when_hideFromDefaultChat_is_true
  -- -----------------------------------------------------------------------
  do
    -- _whisperFilter was set up with hideFromDefaultChat = true above
    local result = Bootstrap._whisperFilter(nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(result == true, "filter should suppress (return true) when hideFromDefaultChat is true")

    local bnResult = Bootstrap._bnWhisperFilter(nil, "CHAT_MSG_BN_WHISPER", "hello", "Friend#1234")
    assert(bnResult == true, "BN filter should suppress when hideFromDefaultChat is true")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_passes_through_when_hideFromDefaultChat_is_false
  -- -----------------------------------------------------------------------
  do
    -- Re-initialize with hideFromDefaultChat = false
    _G.ChatFrame_AddMessageEventFilter = function() end
    Bootstrap._filtersRegistered = false

    local runtime2 = Bootstrap.Initialize(factory, {
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

    local result = Bootstrap._whisperFilter(nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(result == false, "filter should pass through (return false) when hideFromDefaultChat is false")

    local bnResult = Bootstrap._bnWhisperFilter(nil, "CHAT_MSG_BN_WHISPER", "hello", "Friend#1234")
    assert(bnResult == false, "BN filter should pass through when hideFromDefaultChat is false")
  end

  -- -----------------------------------------------------------------------
  -- test_filter_does_not_call_SetLastTellTarget
  -- -----------------------------------------------------------------------
  do
    local setLastTellCalled = false
    local savedSetLast = _G.ChatEdit_SetLastTellTarget
    _G.ChatEdit_SetLastTellTarget = function()
      setLastTellCalled = true
    end

    -- Re-initialize with hideFromDefaultChat = true
    Bootstrap._filtersRegistered = false
    _G.ChatFrame_AddMessageEventFilter = function() end

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

    -- Call the filter — it should NOT invoke SetLastTellTarget
    Bootstrap._whisperFilter(nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(setLastTellCalled == false, "filter must NOT call ChatEdit_SetLastTellTarget (causes taint)")

    _G.ChatEdit_SetLastTellTarget = savedSetLast
  end

  _G.ChatFrame_AddMessageEventFilter = savedFilter
  _G.ChatFrame_RemoveMessageEventFilter = savedRemoveFilter
  _G.UIParent = savedUIParent
end
