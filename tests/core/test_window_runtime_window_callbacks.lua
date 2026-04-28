local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

return function()
  local refreshes = 0
  local visibleState = nil
  local selected = nil
  local started = nil
  local sentLegacy = nil
  local sentGroup = nil
  local copiedStates = {}
  local traceCalls = {}

  local runtime = {
    activeConversationKey = "wow::WOW::jaina",
    store = Store.New({ maxMessagesPerConversation = 10 }),
  }
  runtime.store.conversations["wow::WOW::jaina"] = {
    conversationKey = "wow::WOW::jaina",
    displayName = "Jaina",
    channel = "WOW",
    pinned = true,
    messages = {},
  }
  runtime.store.conversations["wow::WOW::thrall"] = {
    conversationKey = "wow::WOW::thrall",
    displayName = "Thrall",
    channel = "WOW",
    messages = {},
  }

  local characterState = {
    activeConversationKey = "wow::WOW::jaina",
    contactsTabMode = "whispers",
    window = { x = 1 },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }
  local defaultCharacterState = {
    window = { x = 10, y = 20 },
    icon = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 25, y = -40 },
  }
  local icon = {
    frame = {
      parent = { tag = "ui-parent" },
      SetPoint = function(self, anchorPoint, parent, relativePoint, x, y)
        self.point = { anchorPoint, parent, relativePoint, x, y }
      end,
    },
  }

  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = characterState,
    defaultCharacterState = defaultCharacterState,
    uiParent = { tag = "fallback-parent" },
    getIcon = function()
      return icon
    end,
    tableUtils = {
      copyState = function(value)
        copiedStates[#copiedStates + 1] = value
        local copy = {}
        for key, nextValue in pairs(value) do
          copy[key] = nextValue
        end
        return copy
      end,
    },
    groupSendPolicy = {
      shouldRoutePayload = function(payload)
        return payload and payload.channel == "PARTY"
      end,
      sendPayload = function(payload)
        sentGroup = payload
        return true
      end,
    },
    sendHandler = {
      HandleSend = function(nextRuntime, payload, refreshWindow)
        assert(nextRuntime == runtime, "legacy send should receive runtime")
        sentLegacy = payload
        refreshWindow()
        return "legacy-result"
      end,
    },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
    selectConversation = function(conversationKey)
      selected = conversationKey
      return "selected-result"
    end,
    startConversation = function(playerName)
      started = playerName
      return "started-result"
    end,
    setWindowVisible = function(nextVisible)
      visibleState = nextVisible
    end,
    trace = function(...)
      traceCalls[#traceCalls + 1] = { ... }
    end,
  })

  callbacks.onTabModeChanged("groups")
  assert(characterState.contactsTabMode == "groups", "tab callback should persist mode")

  assert(callbacks.onSelectConversation("wow::WOW::thrall") == "selected-result", "select callback should return selector result")
  assert(selected == "wow::WOW::thrall", "select callback should pass conversation key")

  assert(callbacks.onStartConversation("Jaina") == "started-result", "start callback should return start result")
  assert(started == "Jaina", "start callback should pass player name")

  assert(callbacks.onSend({ channel = "WOW", text = "hello" }) == "legacy-result", "legacy send should use send handler")
  assert(sentLegacy.text == "hello", "legacy payload should reach send handler")
  assert(refreshes == 1, "legacy send should allow send handler refresh")

  assert(callbacks.onSend({ channel = "PARTY", text = "group hello" }) == true, "group send should use group policy")
  assert(sentGroup.text == "group hello", "group payload should reach group policy")

  callbacks.onPositionChanged({ x = 40 })
  assert(characterState.window.x == 40, "position callback should copy window state")

  callbacks.onClose()
  assert(visibleState == false, "close callback should hide window")

  local resetWindow = callbacks.onResetWindowPosition()
  assert(resetWindow.x == 10 and characterState.window.x == 10, "reset window should copy default window state")

  callbacks.onReorder({ ["wow::WOW::jaina"] = 2, ["wow::WOW::thrall"] = 1 })
  assert(runtime.store.conversations["wow::WOW::jaina"].sortOrder == 2, "reorder should set Jaina sort order")
  assert(runtime.store.conversations["wow::WOW::thrall"].sortOrder == 1, "reorder should set Thrall sort order")

  callbacks.onPin({ conversationKey = "wow::WOW::thrall", pinned = false })
  assert(runtime.store.conversations["wow::WOW::thrall"].pinned == true, "pin callback should pin unpinned conversation")

  callbacks.onRemove({ conversationKey = "wow::WOW::jaina", displayName = "Jaina" })
  assert(runtime.store.conversations["wow::WOW::jaina"] == nil, "remove callback should delete conversation")
  assert(runtime.activeConversationKey == nil, "remove callback should clear runtime active key")
  assert(characterState.activeConversationKey == nil, "remove callback should clear persisted active key")

  local resetIcon = callbacks.onResetIconPosition()
  assert(resetIcon.anchorPoint == "TOPLEFT", "reset icon should return default icon state")
  assert(characterState.icon.anchorPoint == "TOPLEFT", "reset icon should persist default icon state")
  assert(icon.frame.point[1] == "TOPLEFT", "reset icon should move frame")
  assert(icon.frame.point[2].tag == "ui-parent", "reset icon should use frame parent")

  callbacks.onClearAllChats()
  local count = 0
  for _ in pairs(runtime.store.conversations) do
    count = count + 1
  end
  assert(count == 0, "clear all should remove all conversations")

  assert(#copiedStates >= 3, "callbacks should copy mutable state before persisting")
  assert(#traceCalls >= 3, "callbacks should trace pin/remove/reorder operations")
end
