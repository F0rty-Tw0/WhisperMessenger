local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

return function()
  local conversationKey = "wow::WOW::arthas-area52"
  local buildContactsCalls = 0
  local iconCreateCalls = 0
  local windowCreateCalls = 0
  local selectionRefreshes = 0
  local themeRefreshes = 0
  local markedRead = {}
  local presenceRefreshes = {}
  local availabilityRequests = {}
  local debugCalls = {}
  local themeSetPresetCalls = {}
  local fontSetModeCalls = {}
  local activeThemePreset = "wow_default"
  local capturedWindowOptions = nil
  local coordinatorWindow = nil
  local coordinatorIcon = nil
  local visible = false

  local runtime = {
    accountState = {
      settings = {},
    },
    localProfileId = "me",
    chatApi = {},
    store = {
      conversations = {
        [conversationKey] = {
          conversationKey = conversationKey,
          displayName = "Arthas-Area52",
          channel = "WOW",
          guid = "Player-1-00000001",
          unreadCount = 3,
          messages = {},
        },
      },
      config = {},
    },
  }

  local accountState = runtime.accountState
  local characterState = {
    window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }
  local defaultCharacterState = {
    window = { x = 10, y = 20, width = 920, height = 580, minimized = false },
    icon = { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 25, y = -40 },
  }

  local contactsList = {
    BuildItemsForProfile = function(nextAccountState, nextLocalProfileId)
      buildContactsCalls = buildContactsCalls + 1
      assert(nextAccountState == accountState, "expected BuildItemsForProfile to receive runtime accountState")
      assert(nextLocalProfileId == "me", "expected BuildItemsForProfile to receive runtime localProfileId")
      return {
        {
          conversationKey = conversationKey,
          displayName = "Arthas-Area52",
          channel = "WOW",
          guid = "Player-1-00000001",
          unreadCount = runtime.store.conversations[conversationKey].unreadCount,
        },
      }
    end,
  }

  local messengerWindow = {
    Create = function(_uiFactory, options)
      windowCreateCalls = windowCreateCalls + 1
      capturedWindowOptions = options

      local inputText = ""
      local createdWindow = {}
      createdWindow.frame = {
        shown = true,
        Show = function(self)
          self.shown = true
        end,
        Hide = function(self)
          self.shown = false
        end,
      }
      createdWindow.composer = {
        input = {
          SetText = function(_, text)
            inputText = text
          end,
          GetText = function()
            return inputText
          end,
        },
      }
      createdWindow.refreshSelection = function(nextState)
        selectionRefreshes = selectionRefreshes + 1
        createdWindow.lastSelectionState = nextState
      end
      createdWindow.refreshTheme = function()
        themeRefreshes = themeRefreshes + 1
      end

      coordinatorWindow = createdWindow
      return createdWindow
    end,
  }

  local toggleIcon = {
    Create = function(_uiFactory, options)
      iconCreateCalls = iconCreateCalls + 1
      local createdIcon = {}
      createdIcon.frame = {
        parent = { tag = "ui-parent" },
        SetPoint = function(self, anchorPoint, parent, relativePoint, x, y)
          self.point = { anchorPoint, parent, relativePoint, x, y }
        end,
      }
      createdIcon.setUnreadCount = function(count)
        createdIcon.lastUnreadCount = count
      end

      coordinatorIcon = createdIcon
      createdIcon.onToggle = options.onToggle
      createdIcon.onPositionChanged = options.onPositionChanged
      return createdIcon
    end,
  }

  local windowCoordinator = {
    Create = function(options)
      return {
        buildSelectionState = function(contacts)
          return {
            selectedContact = contacts[1],
            conversation = { conversationKey = conversationKey },
            status = { text = "Online" },
          }
        end,
        setWindowVisible = function(nextVisible)
          visible = nextVisible
          local window = options.getWindow()
          if window and window.frame then
            if nextVisible then
              window.frame:Show()
            else
              window.frame:Hide()
            end
          end
        end,
        isWindowVisible = function()
          return visible
        end,
        refreshWindow = function()
          local contacts = options.buildContacts()
          local nextState = {
            selectedContact = contacts[1],
            conversation = { conversationKey = conversationKey },
            status = { text = "Online" },
          }
          local icon = options.getIcon()
          if icon and icon.setUnreadCount then
            icon.setUnreadCount(contacts[1].unreadCount)
          end
          local window = options.getWindow()
          if visible and window and window.refreshSelection then
            window.refreshSelection(nextState)
          end

          return nextState
        end,
        findLatestUnreadKey = function()
          return conversationKey
        end,
      }
    end,
  }

  local controller = WindowRuntime.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    defaultCharacterState = defaultCharacterState,
    uiFactory = {},
    bootstrap = { _inMythicContent = false },
    contactsList = contactsList,
    messengerWindow = messengerWindow,
    toggleIcon = toggleIcon,
    windowCoordinator = windowCoordinator,
    sendHandler = {
      HandleSend = function(_runtime, _payload, refreshWindow)
        refreshWindow()
      end,
    },
    tableUtils = {
      copyState = function(value)
        return value
      end,
      sumBy = function(items, key)
        local total = 0
        for _, item in ipairs(items) do
          total = total + (item[key] or 0)
        end
        return total
      end,
    },
    presenceCache = {
      RefreshPresence = function(guid)
        presenceRefreshes[#presenceRefreshes + 1] = guid
      end,
    },
    fonts = {
      SetMode = function(mode)
        fontSetModeCalls[#fontSetModeCalls + 1] = mode
      end,
    },
    theme = {
      DEFAULT_PRESET = "wow_default",
      SetPreset = function(presetKey)
        themeSetPresetCalls[#themeSetPresetCalls + 1] = presetKey
        if presetKey == "unknown_preset" then
          return false
        end
        activeThemePreset = presetKey
        return true
      end,
      GetPreset = function()
        return activeThemePreset
      end,
      ResolvePreset = function(requestedKey)
        local fallbackKey = "wow_default"
        local targetKey = requestedKey or fallbackKey

        local requestedApplied = false
        themeSetPresetCalls[#themeSetPresetCalls + 1] = targetKey
        if targetKey ~= "unknown_preset" then
          activeThemePreset = targetKey
          requestedApplied = true
        end
        if requestedApplied then
          return targetKey, true
        end

        if targetKey ~= fallbackKey then
          themeSetPresetCalls[#themeSetPresetCalls + 1] = fallbackKey
          activeThemePreset = fallbackKey
          return fallbackKey, true
        end

        return activeThemePreset, false
      end,
    },
    markConversationRead = function(store, key)
      markedRead[#markedRead + 1] = key
      store.conversations[key].unreadCount = 0
    end,
    requestAvailability = function(_chatApi, guid)
      availabilityRequests[#availabilityRequests + 1] = guid
    end,
    trace = function() end,
  })

  controller.setDiagnostics({
    debugContact = function(key)
      debugCalls[#debugCalls + 1] = key
    end,
  })

  assert(iconCreateCalls == 1, "expected icon to be created eagerly")
  assert(windowCreateCalls == 0, "expected window creation to stay lazy")
  assert(runtime.icon == coordinatorIcon, "expected runtime.icon to be wired immediately")
  assert(runtime.window == nil, "expected runtime.window to stay nil before first create")
  assert(type(runtime.toggle) == "function", "expected runtime.toggle to be wired")
  assert(type(runtime.refreshWindow) == "function", "expected runtime.refreshWindow to be wired")
  assert(type(runtime.ensureWindow) == "function", "expected runtime.ensureWindow to be wired")
  assert(type(runtime.setWindowVisible) == "function", "expected runtime.setWindowVisible to be wired")
  assert(type(runtime.setComposerText) == "function", "expected runtime.setComposerText to be wired")
  assert(type(runtime.isConversationOpen) == "function", "expected runtime.isConversationOpen to be wired")
  assert(type(coordinatorIcon) == "table", "expected coordinator icon table")
  assert(rawget(coordinatorIcon, "lastUnreadCount") == 3, "expected eager icon setup to initialize unread count")

  runtime.refreshWindow()
  assert(windowCreateCalls == 0, "expected refreshWindow to avoid forcing window creation")

  runtime.ensureWindow()
  assert(windowCreateCalls == 1, "expected ensureWindow to create the window once")
  assert(runtime.window == coordinatorWindow, "expected runtime.window to expose the created window")
  assert(runtime.window.frame.shown == false, "expected ensureWindow to leave the new window hidden")

  runtime.setWindowVisible(true)
  assert(type(capturedWindowOptions) == "table", "expected captured window options")
  local onSelectConversation = rawget(capturedWindowOptions, "onSelectConversation")
  local onPin = rawget(capturedWindowOptions, "onPin")
  local onSettingChanged = rawget(capturedWindowOptions, "onSettingChanged")
  assert(type(onSelectConversation) == "function", "expected onSelectConversation callback")
  assert(type(onPin) == "function", "expected onPin callback")
  assert(type(onSettingChanged) == "function", "expected onSettingChanged callback")

  onSelectConversation(conversationKey)
  assert(
    runtime.activeConversationKey == conversationKey,
    "expected selectConversation to update runtime activeConversationKey"
  )
  assert(
    characterState.activeConversationKey == conversationKey,
    "expected selectConversation to persist character activeConversationKey"
  )
  assert(
    #markedRead == 1 and markedRead[1] == conversationKey,
    "expected selectConversation to mark the conversation read"
  )
  assert(
    #presenceRefreshes == 1 and presenceRefreshes[1] == "Player-1-00000001",
    "expected selectConversation to refresh presence"
  )
  assert(
    #availabilityRequests == 1 and availabilityRequests[1] == "Player-1-00000001",
    "expected selectConversation to request availability for WOW contacts"
  )
  assert(
    #debugCalls == 1 and debugCalls[1] == conversationKey,
    "expected selectConversation to invoke diagnostics.debugContact"
  )
  assert(
    runtime.isConversationOpen(conversationKey) == true,
    "expected conversation to report open when visible and selected"
  )

  local deletedConversationKey = "wow::WOW::stale-area52"
  runtime.store.conversations[deletedConversationKey] = {
    conversationKey = deletedConversationKey,
    displayName = "Stale-Area52",
    channel = "WOW",
    unreadCount = 1,
    pinned = true,
    lastActivityAt = 1,
    messages = { { id = "old", sentAt = 1 } },
  }

  runtime.store.conversations[conversationKey].lastActivityAt = 9990
  runtime.store.conversations[conversationKey].messages = { { id = "recent", sentAt = 9990 } }

  runtime.store.config.messageMaxAge = 3600
  runtime.store.config.conversationMaxAge = 3600

  local savedTime = _G.time
  rawset(_G, "time", function()
    return 10000
  end)

  local previousRefreshes = selectionRefreshes
  runtime.activeConversationKey = deletedConversationKey
  characterState.activeConversationKey = deletedConversationKey
  onPin({
    conversationKey = deletedConversationKey,
    pinned = true,
  })
  assert(
    runtime.store.conversations[deletedConversationKey] == nil,
    "expected test precondition: unpin should remove stale conversation"
  )
  assert(
    runtime.activeConversationKey == nil,
    "expected onPin to clear runtime activeConversationKey when unpin removes the conversation"
  )
  assert(
    characterState.activeConversationKey == nil,
    "expected onPin to clear persisted activeConversationKey when unpin removes the conversation"
  )
  assert(
    selectionRefreshes == previousRefreshes + 1,
    "expected onPin to keep refreshing the window after clearing selection"
  )
  rawset(_G, "time", savedTime)

  local refreshesBeforeFontChange = selectionRefreshes
  onSettingChanged("fontFamily", "system")
  assert(accountState.settings.fontFamily == "system", "expected fontFamily change to persist setting")
  assert(
    fontSetModeCalls[#fontSetModeCalls] == "system",
    "expected fontFamily change to call fonts.SetMode with the selected mode"
  )
  assert(selectionRefreshes == refreshesBeforeFontChange + 1, "expected fontFamily change to refresh the window")

  local refreshesBeforeThemeApply = selectionRefreshes
  local themeRefreshesBeforeApply = themeRefreshes
  onSettingChanged("themePreset", "elvui_dark")
  assert(accountState.settings.themePreset == "elvui_dark", "expected valid themePreset to persist in account settings")
  assert(activeThemePreset == "elvui_dark", "expected valid themePreset to apply to active theme")
  assert(
    themeSetPresetCalls[#themeSetPresetCalls] == "elvui_dark",
    "expected valid themePreset to call Theme.SetPreset"
  )
  assert(
    themeRefreshes == themeRefreshesBeforeApply + 1,
    "expected valid themePreset change to refresh static window chrome"
  )
  assert(selectionRefreshes == refreshesBeforeThemeApply + 1, "expected valid themePreset change to refresh the window")

  local themeCallsBeforeFallback = #themeSetPresetCalls
  local refreshesBeforeThemeFallback = selectionRefreshes
  local themeRefreshesBeforeFallback = themeRefreshes
  onSettingChanged("themePreset", "unknown_preset")
  assert(
    #themeSetPresetCalls == themeCallsBeforeFallback + 2,
    "expected invalid themePreset to attempt requested preset and fallback default"
  )
  assert(
    themeSetPresetCalls[themeCallsBeforeFallback + 1] == "unknown_preset",
    "expected invalid themePreset to try the requested key first"
  )
  assert(
    themeSetPresetCalls[themeCallsBeforeFallback + 2] == "wow_default",
    "expected invalid themePreset to fallback to wow_default"
  )
  assert(
    accountState.settings.themePreset == "wow_default",
    "expected invalid themePreset to persist wow_default fallback"
  )
  assert(activeThemePreset == "wow_default", "expected fallback to apply wow_default preset")
  assert(
    themeRefreshes == themeRefreshesBeforeFallback + 1,
    "expected fallback themePreset apply to refresh static window chrome"
  )
  assert(
    selectionRefreshes == refreshesBeforeThemeFallback + 1,
    "expected fallback themePreset apply to refresh the window"
  )

  local refreshesBeforeHidePreview = selectionRefreshes
  onSettingChanged("hideMessagePreview", true)
  assert(
    selectionRefreshes == refreshesBeforeHidePreview + 1,
    "expected hideMessagePreview change to continue refreshing the window"
  )

  runtime.setComposerText("draft reply")
  assert(
    runtime.window.composer.input:GetText() == "draft reply",
    "expected setComposerText to write into the composer"
  )

  runtime.setWindowVisible(false)
  assert(runtime.isConversationOpen(conversationKey) == false, "expected conversation to report closed when hidden")

  assert(selectionRefreshes >= 1, "expected selection refresh to occur after selecting a conversation")
  assert(buildContactsCalls >= 2, "expected buildContacts to back badge initialization and refreshes")
end
