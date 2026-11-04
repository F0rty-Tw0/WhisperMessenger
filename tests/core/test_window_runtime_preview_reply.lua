-- Composition test: WindowRuntime builds one quickReply table for the reply
-- row under the whisper preview and hands it to both icons. Submit sends
-- through the window's own send path without building the window.

local FakeUI = require("tests.helpers.fake_ui")
local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

local CONVERSATION_KEY = "wow::WOW::arthas-area52"

local function fakeCoordinatorModule()
  return {
    Create = function(coordOptions)
      local visible = false
      local coord = {}
      function coord.buildSelectionState(contacts)
        return { selectedContact = contacts[1], conversation = nil, status = nil }
      end
      function coord.refreshWindow()
        return nil
      end
      function coord.setWindowVisible(nextVisible)
        visible = nextVisible
      end
      function coord.isWindowVisible()
        return visible
      end
      function coord.findLatestUnreadKey()
        local contacts = coordOptions.buildContacts()
        return contacts[1] and contacts[1].conversationKey or nil
      end
      function coord.scheduleAvailabilityRefresh() end
      function coord.scheduleIncomingRefresh() end
      function coord.updateIconSurfaces() end
      return coord
    end,
  }
end

local function fakeToggleIcon(trackers)
  local noop = function() end
  return {
    Create = function(_uiFactory, options)
      trackers.capturedIconOptions = options
      return {
        frame = { SetPoint = noop, Show = noop, Hide = noop },
        setUnreadCount = noop,
        setIncomingPreview = noop,
        refreshTheme = noop,
      }
    end,
  }
end

local function fakeMinimapIconRuntime(trackers, factory)
  local noop = function() end
  return {
    Create = function(minimapOptions)
      trackers.capturedMinimapOptions = minimapOptions
      return {
        minimapIcon = {
          frame = factory.CreateFrame("Button", nil, nil),
          setShown = noop,
          setIncomingPreview = noop,
          setUnreadCount = noop,
          refreshTheme = noop,
        },
        getLdbObject = function()
          return {}
        end,
      }
    end,
  }
end

local function build()
  local runtime = {
    accountState = { settings = { iconMode = "both" } },
    localProfileId = "me",
    chatApi = {},
    store = {
      conversations = {
        [CONVERSATION_KEY] = {
          conversationKey = CONVERSATION_KEY,
          displayName = "Arthas-Area52",
          channel = "WOW",
          guid = "Player-1-00000001",
          unreadCount = 1,
          messages = {},
        },
      },
      config = {},
    },
  }
  local trackers = { windowCreates = 0, payloads = {} }
  local factory = FakeUI.NewFactory()

  local options = {
    runtime = runtime,
    accountState = runtime.accountState,
    characterState = { window = {}, icon = {} },
    defaultCharacterState = { window = {}, icon = {} },
    uiFactory = factory,
    bootstrap = { _inMythicContent = false },
    contactsList = {
      BuildItemsForProfile = function()
        local convo = runtime.store.conversations[CONVERSATION_KEY]
        return {
          { conversationKey = CONVERSATION_KEY, displayName = convo.displayName, channel = convo.channel, guid = convo.guid },
        }
      end,
    },
    messengerWindow = {
      Create = function()
        trackers.windowCreates = trackers.windowCreates + 1
        return {}
      end,
    },
    toggleIcon = fakeToggleIcon(trackers),
    minimapIconRuntime = fakeMinimapIconRuntime(trackers, factory),
    windowCoordinator = fakeCoordinatorModule(),
    -- The real HandleSend refreshes synchronously.
    sendHandler = {
      HandleSend = function(_rt, payload, refresh)
        trackers.payloads[#trackers.payloads + 1] = payload
        if refresh then
          refresh()
        end
        return true
      end,
    },
    tableUtils = {
      copyState = function(value)
        local copy = {}
        for key, nextValue in pairs(value or {}) do
          copy[key] = nextValue
        end
        return copy
      end,
    },
    presenceCache = { RefreshPresence = function() end },
    fonts = {},
    theme = {
      DEFAULT_PRESET = "wow_default",
      ResolvePreset = function(key)
        return key, true
      end,
    },
    markConversationRead = function(store, key)
      store.conversations[key].unreadCount = 0
    end,
    requestAvailability = function() end,
  }
  return options, runtime, trackers
end

return function()
  local function test_both_icons_get_the_same_quick_reply_table()
    local options, _, trackers = build()
    WindowRuntime.Create(options)
    local quickReply = trackers.capturedIconOptions.quickReply
    assert(quickReply ~= nil, "the widget icon gets a quickReply table")
    assert(trackers.capturedMinimapOptions.quickReply == quickReply, "the minimap icon gets the same quickReply table")
  end

  local function test_submit_sends_through_window_callbacks()
    local options, _, trackers = build()
    WindowRuntime.Create(options)
    local quickReply = trackers.capturedIconOptions.quickReply
    local sent = quickReply.onSubmit({ conversationKey = CONVERSATION_KEY, sentAt = 1, channel = "WOW" }, "hi")
    assert(sent == true, "submit reports the send")
    local payload = trackers.payloads[1]
    assert(payload and payload.conversationKey == CONVERSATION_KEY, "the payload targets the previewed conversation")
    assert(payload.text == "hi", "the payload carries the typed text")
    assert(trackers.windowCreates == 0, "submit never builds the window, got " .. trackers.windowCreates)
  end

  local function test_is_enabled_follows_account_setting()
    local options, runtime, trackers = build()
    WindowRuntime.Create(options)
    local quickReply = trackers.capturedIconOptions.quickReply
    assert(quickReply.isEnabled() == false, "the reply row is off by default")
    runtime.accountState.settings.widgetPreviewReply = true
    assert(quickReply.isEnabled() == true, "the reply row follows the saved setting")
  end

  test_both_icons_get_the_same_quick_reply_table()
  test_submit_sends_through_window_callbacks()
  test_is_enabled_follows_account_setting()
end
