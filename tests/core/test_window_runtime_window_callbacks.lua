local Store = require("WhisperMessenger.Model.ConversationStore")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

return function()
  local refreshes = 0
  local visibleState = nil
  local selected = nil
  local started = nil
  local sentLegacy = nil
  local sentGroup = nil
  local reacted = nil
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
    messages = {
      { kind = "user", direction = "in", text = "hello" },
    },
    unreadCount = 0,
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
  local accountState = {
    settings = { shareWidgetPosition = false },
  }
  local icon = {
    frame = {
      parent = { tag = "ui-parent" },
      SetPoint = function(self, anchorPoint, parent, relativePoint, x, y)
        self.point = { anchorPoint, parent, relativePoint, x, y }
      end,
    },
  }

  local checkedConversation = nil
  local callbacksGroupSendPolicy = {
    shouldRoutePayload = function(payload)
      return payload and payload.channel == "PARTY"
    end,
    sendPayload = function(payload)
      sentGroup = payload
      return true
    end,
    getNotice = function(conversation)
      checkedConversation = conversation
      return conversation and conversation.notice or nil
    end,
  }

  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    accountState = accountState,
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
    groupSendPolicy = callbacksGroupSendPolicy,
    sendHandler = {
      HandleSend = function(nextRuntime, payload, refreshWindow)
        assert(nextRuntime == runtime, "legacy send should receive runtime")
        sentLegacy = payload
        refreshWindow()
        return "legacy-result"
      end,
    },
    reactionHandler = {
      HandleReact = function(nextRuntime, selectedContact, message, reactionKey, refreshWindow, receivedGroupSendPolicy)
        assert(nextRuntime == runtime, "reaction callback should receive runtime")
        assert(receivedGroupSendPolicy == callbacksGroupSendPolicy, "reaction callback should receive group policy")
        reacted = {
          selectedContact = selectedContact,
          message = message,
          reactionKey = reactionKey,
        }
        refreshWindow()
        return "reaction-result"
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

  local competitive = false
  runtime.isCompetitiveContent = function()
    return competitive
  end
  local directMessage = {
    kind = "user",
    direction = "in",
    channel = "WOW",
    text = "hello",
  }
  local groupMessage = {
    kind = "user",
    direction = "in",
    channel = "PARTY",
    text = "hello group",
  }
  local groupConversation = {
    conversationKey = "party::PARTY::current",
    channel = "PARTY",
  }
  local groupSnapshot = {
    conversationKey = "party::PARTY::snapshot",
    channel = "PARTY",
    conversation = groupConversation,
  }

  assert(callbacks.canReact({ channel = "WOW" }, directMessage) == true, "WOW reactions should be available outside competitive content")
  assert(callbacks.canReact({ channel = "BN" }, {
    kind = "user",
    direction = "in",
    channel = "BN",
    text = "bnet",
  }) == true, "BN reactions should be available outside competitive content")
  assert(callbacks.canReact(groupSnapshot, groupMessage) == true, "live PARTY reactions should be available")
  assert(checkedConversation == groupConversation, "group snapshot availability should check its underlying conversation")

  for _, channel in ipairs({ "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }) do
    assert(callbacks.canReact({ channel = channel }, {
      kind = "user",
      direction = "in",
      channel = channel,
      text = channel,
    }) == true, channel .. " reactions should be available")
  end
  assert(callbacks.canReact({ channel = "COMMUNITY" }, {
    kind = "user",
    direction = "in",
    channel = "COMMUNITY",
    text = "community",
  }) == false, "unsupported channels must not expose reactions")

  groupConversation.notice = "Historical group chat — read-only."
  assert(callbacks.canReact(groupSnapshot, groupMessage) == false, "left groups should hide reactions")
  groupConversation.notice = "Another character's history — read-only."
  assert(callbacks.canReact(groupSnapshot, groupMessage) == false, "foreign groups should hide reactions")
  groupConversation.notice = "Not in group — can't send."
  assert(callbacks.canReact(groupSnapshot, groupMessage) == false, "unsendable groups should hide reactions")
  groupConversation.notice = nil

  competitive = true
  assert(callbacks.canReact({ channel = "WOW" }, directMessage) == false, "competitive content should dynamically disable direct reactions")
  assert(callbacks.canReact(groupSnapshot, groupMessage) == false, "competitive content should dynamically disable group reactions")
  competitive = false

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

  local selectedContact = { conversationKey = "wow::WOW::thrall" }
  local targetMessage = runtime.store.conversations["wow::WOW::thrall"].messages[1]
  assert(callbacks.onReact(selectedContact, targetMessage, "heart") == "reaction-result", "reaction callback should delegate")
  assert(reacted.selectedContact == selectedContact, "reaction callback should preserve selected contact")
  assert(reacted.message == targetMessage and reacted.reactionKey == "heart", "reaction callback should preserve message and key")
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
  callbacks.onMarkUnread({ conversationKey = "wow::WOW::thrall", displayName = "Thrall" })
  assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 1, "mark unread should restore retained incoming count")
  assert(refreshes == 5, "mark unread should refresh the window")

  callbacks.onRemove({ conversationKey = "wow::WOW::jaina", displayName = "Jaina" })
  assert(runtime.store.conversations["wow::WOW::jaina"] == nil, "remove callback should delete conversation")
  assert(runtime.activeConversationKey == nil, "remove callback should clear runtime active key")
  assert(characterState.activeConversationKey == nil, "remove callback should clear persisted active key")

  local resetIcon = callbacks.onResetIconPosition()
  assert(resetIcon.anchorPoint == "TOPLEFT", "reset icon should return default icon state")
  assert(characterState.icon.anchorPoint == "TOPLEFT", "reset icon should persist default icon state")
  assert(icon.frame.point[1] == "TOPLEFT", "reset icon should move frame")
  assert(icon.frame.point[2].tag == "ui-parent", "reset icon should use frame parent")

  -- test_reset_icon_position_updates_only_shared_state_while_sharing
  accountState.settings.shareWidgetPosition = true
  accountState.sharedWidgetPosition = { anchorPoint = "RIGHT", relativePoint = "RIGHT", x = -8, y = 9 }
  local localIconPosition = { anchorPoint = "BOTTOM", relativePoint = "BOTTOM", x = 11, y = 12 }
  characterState.icon = localIconPosition

  local resetSharedIcon = callbacks.onResetIconPosition()
  local sharedIconPosition = accountState.sharedWidgetPosition
  assert(
    sharedIconPosition.anchorPoint == "TOPLEFT"
      and sharedIconPosition.relativePoint == "TOPLEFT"
      and sharedIconPosition.x == 25
      and sharedIconPosition.y == -40,
    "shared reset should persist the exact default icon position"
  )
  assert(sharedIconPosition ~= defaultCharacterState.icon, "shared reset should copy rather than alias the default position")
  assert(resetSharedIcon == sharedIconPosition, "shared reset should return the persisted shared position")
  assert(characterState.icon == localIconPosition, "shared reset should preserve the character position")
  assert(
    icon.frame.point[1] == "TOPLEFT"
      and icon.frame.point[2].tag == "ui-parent"
      and icon.frame.point[3] == "TOPLEFT"
      and icon.frame.point[4] == 25
      and icon.frame.point[5] == -40,
    "shared reset should apply the exact default position to the widget frame"
  )
  callbacks.onClearAllChats()
  local count = 0
  for _ in pairs(runtime.store.conversations) do
    count = count + 1
  end
  assert(count == 0, "clear all should remove all conversations")

  -- test_clear_all_uses_store_removal_lifecycle_without_discarding_active_sends
  do
    local now = 1000
    local key = "wow::WOW::cached-realm"
    local guid = "Player-cached"
    local clearCharacterState = { activeConversationKey = key }
    local clearRuntime = RuntimeFactory.CreateRuntimeState({
      conversations = {
        [key] = {
          conversationKey = key,
          guid = guid,
          messages = {},
          lastActivityAt = now,
        },
      },
    }, clearCharacterState, "wow", {
      now = function()
        return now
      end,
    })
    clearRuntime.pendingOutgoing[key] = { { createdAt = now } }
    clearRuntime.pendingGroupOutgoing = { [key] = { { createdAt = now } } }
    clearRuntime.sendStatusByConversation[key] = { status = "sent" }
    clearRuntime.availabilityByGUID[guid] = { status = "CanWhisper" }
    clearRuntime.availabilityRequestedAt = { [guid] = now }

    local clearCallbacks = WindowCallbacks.Create({
      runtime = clearRuntime,
      characterState = clearCharacterState,
    })
    clearCallbacks.onClearAllChats()

    assert(next(clearRuntime.store.conversations) == nil, "clear all must remove every conversation")
    assert(clearRuntime.sendStatusByConversation[key] == nil, "clear all must release per-conversation send status")
    assert(clearRuntime.availabilityByGUID[guid] == nil, "clear all must release orphaned availability")
    assert(clearRuntime.availabilityRequestedAt[guid] == nil, "clear all must release orphaned resolver requests")
    assert(clearRuntime.pendingOutgoing[key] ~= nil, "clear all must preserve active whisper sends")
    assert(clearRuntime.pendingGroupOutgoing[key] ~= nil, "clear all must preserve active group sends")
    assert(clearRuntime.activeConversationKey == nil, "clear all must clear runtime active conversation")
    assert(clearCharacterState.activeConversationKey == nil, "clear all must clear persisted active conversation")
  end

  assert(#copiedStates >= 3, "callbacks should copy mutable state before persisting")
  assert(#traceCalls >= 3, "callbacks should trace pin/remove/reorder operations")
end
