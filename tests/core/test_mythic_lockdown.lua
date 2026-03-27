local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")

return function()
  -- -----------------------------------------------------------------------
  -- test_event_bridge_drops_events_during_mythic_lockdown
  -- -----------------------------------------------------------------------
  do
    local refreshCalls = 0
    local runtime = {
      isMythicLockdown = function()
        return true
      end,
      isChatMessagingLocked = function()
        return false
      end,
      accountState = { settings = {} },
    }

    local result = EventBridge.RouteLiveEvent(runtime, function()
      refreshCalls = refreshCalls + 1
    end, "CHAT_MSG_WHISPER", "hello", "Arthas-Area52", "", "", "", 0, 0, "", 0, 999, 1001, "Player-1-0ABC")

    assert(result == nil, "expected nil result when mythic locked, got: " .. tostring(result))
    assert(refreshCalls == 0, "should not refresh window when event is dropped")
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
  -- test_chat_filter_returns_false_during_mythic_lockdown
  -- -----------------------------------------------------------------------
  do
    local Bootstrap = require("WhisperMessenger.Bootstrap")
    local FakeUI = require("tests.helpers.fake_ui")
    local factory = FakeUI.NewFactory()

    local savedUIParent = _G.UIParent
    local savedSlashCmdList = _G.SlashCmdList
    local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
    local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
    local savedFilter = _G.ChatFrame_AddMessageEventFilter

    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.SlashCmdList = {}
    _G.SLASH_WHISPERMESSENGER1 = nil
    _G.SLASH_WHISPERMESSENGER2 = nil

    local filters = {}
    _G.ChatFrame_AddMessageEventFilter = function(event, fn)
      filters[event] = fn
    end

    local savedRuntime = Bootstrap.runtime
    Bootstrap.runtime = nil

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
      isMythicLockdown = function()
        return true
      end,
    })
    Bootstrap.runtime = runtime

    -- With mythic lockdown active, filter should return false even though
    -- hideFromDefaultChat is true
    local suppress = filters["CHAT_MSG_WHISPER"](nil, "CHAT_MSG_WHISPER", "hello", "Arthas")
    assert(
      suppress == false,
      "test_chat_filter_mythic: should return false during mythic lockdown, got: " .. tostring(suppress)
    )

    Bootstrap.runtime = savedRuntime
    _G.ChatFrame_AddMessageEventFilter = savedFilter
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
