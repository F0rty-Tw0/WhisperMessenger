local WindowRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime")

return function()
  local conversationKey = "wow::WOW::arthas-area52"
  local buildContactsCalls = 0
  local iconCreateCalls = 0
  local windowCreateCalls = 0
  local selectionRefreshes = 0
  local themeRefreshes = 0
  local composerFocuses = 0
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
          SetFocus = function()
            composerFocuses = composerFocuses + 1
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
    bootstrap = { lockdown = { active = false, since = 0, source = "init" } },
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
      SetFontSize = function(size)
        fontSetModeCalls[#fontSetModeCalls + 1] = { "fontSize", size }
      end,
      SetOutline = function(outline)
        fontSetModeCalls[#fontSetModeCalls + 1] = { "outline", outline }
      end,
      SetFontColor = function(color)
        fontSetModeCalls[#fontSetModeCalls + 1] = { "fontColor", color }
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
  local onStartConversation = rawget(capturedWindowOptions, "onStartConversation")
  local onPin = rawget(capturedWindowOptions, "onPin")
  local onSettingChanged = rawget(capturedWindowOptions, "onSettingChanged")
  assert(type(onSelectConversation) == "function", "expected onSelectConversation callback")
  assert(type(onStartConversation) == "function", "expected onStartConversation callback")
  assert(type(onPin) == "function", "expected onPin callback")
  assert(type(onSettingChanged) == "function", "expected onSettingChanged callback")

  local function countConversations()
    local count = 0
    for _ in pairs(runtime.store.conversations) do
      count = count + 1
    end
    return count
  end

  local invalidConversationCount = countConversations()
  local invalidSelectionRefreshes = selectionRefreshes
  local invalidActiveKey = runtime.activeConversationKey
  local invalidPersistedKey = characterState.activeConversationKey
  assert(onStartConversation("   \n  ") == false, "expected onStartConversation to reject whitespace-only names")
  assert(
    countConversations() == invalidConversationCount,
    "expected invalid onStartConversation to keep conversations unchanged"
  )
  assert(
    runtime.activeConversationKey == invalidActiveKey,
    "expected invalid onStartConversation to keep runtime active key"
  )
  assert(
    characterState.activeConversationKey == invalidPersistedKey,
    "expected invalid onStartConversation to keep persisted active key"
  )
  assert(
    selectionRefreshes == invalidSelectionRefreshes,
    "expected invalid onStartConversation to skip selection refresh"
  )

  local reuseConversationCount = countConversations()
  local reuseMarkedReadCount = #markedRead
  local reuseDebugCount = #debugCalls
  local reuseAvailabilityCount = #availabilityRequests
  local reuseFocusCount = composerFocuses
  assert(onStartConversation("  Arthas  ") == true, "expected onStartConversation to open an existing WOW conversation")
  assert(
    countConversations() == reuseConversationCount,
    "expected onStartConversation to reuse existing conversation key"
  )
  assert(runtime.activeConversationKey == conversationKey, "expected existing conversation to become active")
  assert(characterState.activeConversationKey == conversationKey, "expected existing conversation to persist as active")
  assert(
    #markedRead == reuseMarkedReadCount + 1 and markedRead[#markedRead] == conversationKey,
    "expected existing conversation path to mark read via selectConversation"
  )
  assert(
    #debugCalls == reuseDebugCount + 1 and debugCalls[#debugCalls] == conversationKey,
    "expected existing conversation path to go through diagnostics selector path"
  )
  assert(
    #availabilityRequests == reuseAvailabilityCount + 1
      and availabilityRequests[#availabilityRequests] == "Player-1-00000001",
    "expected existing WOW conversation path to request availability"
  )
  assert(composerFocuses == reuseFocusCount + 1, "expected existing conversation path to focus composer input")
  assert(
    runtime.isConversationOpen(conversationKey) == true,
    "expected existing conversation to report open when visible and selected"
  )

  local exactMatchConversationCount = countConversations()
  assert(
    onStartConversation("  arTHas-ARea52  ") == true,
    "expected onStartConversation to reuse exact full-name match with mixed casing"
  )
  assert(
    countConversations() == exactMatchConversationCount,
    "expected exact full-name lookup to avoid creating a new conversation"
  )
  assert(
    runtime.activeConversationKey == conversationKey,
    "expected exact full-name lookup to keep Arthas-Area52 selected"
  )
  assert(
    characterState.activeConversationKey == conversationKey,
    "expected exact full-name lookup to persist selected conversation"
  )

  local secondArthasConversationKey = "wow::WOW::arthas-stormrage"
  runtime.store.conversations[secondArthasConversationKey] = {
    conversationKey = secondArthasConversationKey,
    displayName = "Arthas-Stormrage",
    channel = "WOW",
    unreadCount = 0,
    messages = {},
  }

  local ambiguousConversationCount = countConversations()
  local ambiguousMarkedReadCount = #markedRead
  local ambiguousDebugCount = #debugCalls
  local ambiguousAvailabilityCount = #availabilityRequests
  local ambiguousFocusCount = composerFocuses
  local ambiguousConversationKey = "wow::WOW::arthas"
  assert(
    onStartConversation("  Arthas  ") == true,
    "expected ambiguous base-name input to open a deterministic non-reused conversation"
  )
  assert(
    countConversations() == ambiguousConversationCount + 1,
    "expected ambiguous base-name lookup to create a new conversation"
  )
  assert(
    runtime.store.conversations[ambiguousConversationKey] ~= nil,
    "expected ambiguous base-name lookup to create key derived from typed whisper target"
  )
  assert(
    runtime.activeConversationKey == ambiguousConversationKey,
    "expected ambiguous base-name lookup to avoid selecting an arbitrary existing conversation"
  )
  assert(
    characterState.activeConversationKey == ambiguousConversationKey,
    "expected ambiguous base-name lookup to persist deterministic conversation key"
  )
  assert(
    #markedRead == ambiguousMarkedReadCount + 1 and markedRead[#markedRead] == ambiguousConversationKey,
    "expected ambiguous base-name path to select the newly-created conversation"
  )
  assert(
    #debugCalls == ambiguousDebugCount + 1 and debugCalls[#debugCalls] == ambiguousConversationKey,
    "expected ambiguous base-name path to go through diagnostics selector with new key"
  )
  assert(
    #availabilityRequests == ambiguousAvailabilityCount,
    "expected ambiguous base-name created conversation without guid to skip availability requests"
  )
  assert(composerFocuses == ambiguousFocusCount + 1, "expected ambiguous base-name path to focus composer input")
  assert(runtime.store.conversations[conversationKey] ~= nil, "expected Arthas-Area52 conversation to remain available")
  assert(
    runtime.store.conversations[secondArthasConversationKey] ~= nil,
    "expected Arthas-Stormrage conversation to remain available"
  )

  local battleNetConversationKey = "wow::BN::uther#1234"
  runtime.store.conversations[battleNetConversationKey] = {
    conversationKey = battleNetConversationKey,
    displayName = "Uther",
    channel = "BN",
    battleTag = "Uther#1234",
    unreadCount = 0,
    messages = {},
  }

  local bnCollisionConversationCount = countConversations()
  local bnCollisionMarkedReadCount = #markedRead
  local bnCollisionDebugCount = #debugCalls
  local bnCollisionAvailabilityCount = #availabilityRequests
  local bnCollisionFocusCount = composerFocuses
  local bnCollisionConversationKey = "wow::WOW::uther"
  assert(onStartConversation("  Uther  ") == true, "expected whisper start flow to avoid reusing BN conversations")
  assert(
    countConversations() == bnCollisionConversationCount + 1,
    "expected BN name collision to create a WOW whisper conversation"
  )
  assert(
    runtime.store.conversations[bnCollisionConversationKey] ~= nil,
    "expected BN name collision to create WOW conversation derived from typed name"
  )
  assert(
    runtime.activeConversationKey == bnCollisionConversationKey,
    "expected BN name collision to select WOW conversation key"
  )
  assert(
    characterState.activeConversationKey == bnCollisionConversationKey,
    "expected BN name collision to persist WOW conversation key"
  )
  assert(
    #markedRead == bnCollisionMarkedReadCount + 1 and markedRead[#markedRead] == bnCollisionConversationKey,
    "expected BN name collision path to select created WOW conversation"
  )
  assert(
    #debugCalls == bnCollisionDebugCount + 1 and debugCalls[#debugCalls] == bnCollisionConversationKey,
    "expected BN name collision path to route diagnostics through WOW key"
  )
  assert(
    #availabilityRequests == bnCollisionAvailabilityCount,
    "expected BN name collision created conversation without guid to skip availability requests"
  )
  assert(composerFocuses == bnCollisionFocusCount + 1, "expected BN name collision path to focus composer input")

  local createdConversationName = "Jaina-Proudmoore"
  local createdConversationKey = "wow::WOW::jaina-proudmoore"
  local createMarkedReadCount = #markedRead
  local createDebugCount = #debugCalls
  local createAvailabilityCount = #availabilityRequests
  local createPresenceCount = #presenceRefreshes
  local createFocusCount = composerFocuses
  assert(
    onStartConversation("  " .. createdConversationName .. "  ") == true,
    "expected onStartConversation to create a missing WOW conversation"
  )
  assert(
    runtime.store.conversations[createdConversationKey] ~= nil,
    "expected missing conversation key to be created from player name"
  )
  assert(
    runtime.store.conversations[createdConversationKey].displayName == createdConversationName,
    "expected created conversation to preserve trimmed displayName"
  )
  assert(
    runtime.store.conversations[createdConversationKey].channel == "WOW",
    "expected created conversation channel to default to WOW"
  )
  assert(runtime.activeConversationKey == createdConversationKey, "expected created conversation to become active")
  assert(
    characterState.activeConversationKey == createdConversationKey,
    "expected created conversation to persist as active"
  )
  assert(
    #markedRead == createMarkedReadCount + 1 and markedRead[#markedRead] == createdConversationKey,
    "expected created conversation path to route through selectConversation"
  )
  assert(
    #debugCalls == createDebugCount + 1 and debugCalls[#debugCalls] == createdConversationKey,
    "expected created conversation path to invoke diagnostics selector path"
  )
  assert(
    #availabilityRequests == createAvailabilityCount,
    "expected created conversation without guid to skip availability requests"
  )
  assert(
    #presenceRefreshes == createPresenceCount,
    "expected created conversation without guid to skip presence refresh"
  )
  assert(composerFocuses == createFocusCount + 1, "expected created conversation path to focus composer input")
  assert(
    runtime.isConversationOpen(createdConversationKey) == true,
    "expected created conversation to report open when visible and selected"
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

  -- fontSize setting
  local refreshesBeforeFontSize = selectionRefreshes
  onSettingChanged("fontSize", 16)
  assert(accountState.settings.fontSize == 16, "expected fontSize change to persist setting")
  local lastFontSizeCall = fontSetModeCalls[#fontSetModeCalls]
  assert(
    type(lastFontSizeCall) == "table" and lastFontSizeCall[1] == "fontSize" and lastFontSizeCall[2] == 16,
    "expected fontSize change to call fonts.SetFontSize(16)"
  )
  assert(selectionRefreshes == refreshesBeforeFontSize + 1, "expected fontSize change to refresh the window")

  -- fontOutline setting
  local refreshesBeforeFontOutline = selectionRefreshes
  onSettingChanged("fontOutline", "OUTLINE")
  assert(accountState.settings.fontOutline == "OUTLINE", "expected fontOutline change to persist setting")
  local lastOutlineCall = fontSetModeCalls[#fontSetModeCalls]
  assert(
    type(lastOutlineCall) == "table" and lastOutlineCall[1] == "outline" and lastOutlineCall[2] == "OUTLINE",
    "expected fontOutline change to call fonts.SetOutline(OUTLINE)"
  )
  assert(selectionRefreshes == refreshesBeforeFontOutline + 1, "expected fontOutline change to refresh the window")

  -- fontColor setting
  local refreshesBeforeFontColor = selectionRefreshes
  onSettingChanged("fontColor", "gold")
  assert(accountState.settings.fontColor == "gold", "expected fontColor change to persist setting")
  local lastColorCall = fontSetModeCalls[#fontSetModeCalls]
  assert(
    type(lastColorCall) == "table" and lastColorCall[1] == "fontColor" and lastColorCall[2] == "gold",
    "expected fontColor change to call fonts.SetFontColor(gold)"
  )
  assert(selectionRefreshes == refreshesBeforeFontColor + 1, "expected fontColor change to refresh the window")

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
