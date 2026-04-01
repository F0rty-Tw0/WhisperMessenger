local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local WindowCoordinator = ns.BootstrapWindowCoordinator or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local MessengerWindow = ns.MessengerWindow or require("WhisperMessenger.UI.MessengerWindow")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local WindowRuntime = {}

function WindowRuntime.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountState = options.accountState or runtime.accountState or {}
  local characterState = options.characterState or runtime.characterState or {}
  local defaultCharacterState = options.defaultCharacterState or {}
  local uiFactory = options.uiFactory or _G
  local uiParent = options.uiParent or _G.UIParent
  local bootstrap = options.bootstrap or {}
  local trace = options.trace or function() end

  local contactsList = options.contactsList or ContactsList
  local messengerWindow = options.messengerWindow or MessengerWindow
  local toggleIcon = options.toggleIcon or ToggleIcon
  local windowCoordinatorModule = options.windowCoordinator or WindowCoordinator
  local sendHandler = options.sendHandler or SendHandler
  local tableUtils = options.tableUtils or TableUtils
  local presenceCache = options.presenceCache or PresenceCache
  local fonts = options.fonts or Fonts
  local theme = options.theme or Theme

  local markConversationRead = options.markConversationRead
    or function(store, conversationKey)
      return Store.MarkRead(store, conversationKey)
    end
  local requestAvailability = options.requestAvailability
    or function(chatApi, guid)
      return WhisperGateway.RequestAvailability(chatApi, guid)
    end

  local diagnostics = options.diagnostics or {}
  local window
  local icon

  local function buildContacts()
    return contactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId)
  end

  local coordinator = windowCoordinatorModule.Create({
    runtime = runtime,
    buildContacts = buildContacts,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return icon
    end,
    trace = trace,
    isMythicRestricted = function()
      return bootstrap._inMythicContent == true
    end,
    presenceCache = presenceCache,
  })

  local controller = {}

  local function setWindowVisible(nextVisible)
    return coordinator.setWindowVisible(nextVisible)
  end

  local function refreshWindow()
    return coordinator.refreshWindow()
  end

  local function selectConversation(conversationKey)
    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey

    local conversation = conversationKey ~= nil and runtime.store.conversations[conversationKey] or nil
    if conversation ~= nil then
      markConversationRead(runtime.store, conversationKey)

      if conversation.guid then
        presenceCache.RefreshPresence(conversation.guid)
      end
      if conversation.channel == "WOW" and conversation.guid then
        requestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    if diagnostics.debugContact then
      diagnostics.debugContact(conversationKey)
    end

    return refreshWindow()
  end

  local function ensureWindow()
    if window then
      return
    end

    local contacts = buildContacts()
    local selectedState = coordinator.buildSelectionState(contacts)

    window = messengerWindow.Create(uiFactory, {
      contacts = contacts,
      selectedContact = selectedState.selectedContact,
      conversation = selectedState.conversation,
      status = selectedState.status,
      state = characterState.window,
      onSelectConversation = function(conversationKey)
        return selectConversation(conversationKey)
      end,
      onSend = function(payload)
        return sendHandler.HandleSend(runtime, payload, refreshWindow)
      end,
      onPositionChanged = function(nextState)
        characterState.window = tableUtils.copyState(nextState)
      end,
      onClose = function()
        setWindowVisible(false)
      end,
      onResetWindowPosition = function()
        local nextState = tableUtils.copyState(defaultCharacterState.window)
        characterState.window = nextState
        return nextState
      end,
      onClearAllChats = function()
        for key in pairs(runtime.store.conversations) do
          runtime.store.conversations[key] = nil
        end
        runtime.activeConversationKey = nil
        characterState.activeConversationKey = nil
      end,
      onPin = function(item)
        local key = item.conversationKey
        trace("onPin", "key=" .. tostring(key), "wasPinned=" .. tostring(item.pinned))
        if Store.IsPinned(runtime.store, key) then
          Store.Unpin(runtime.store, key)
        else
          Store.Pin(runtime.store, key)
        end
        refreshWindow()
      end,
      onRemove = function(item)
        local key = item.conversationKey
        trace("onRemove", "key=" .. tostring(key), "name=" .. tostring(item.displayName))
        Store.Remove(runtime.store, key)
        if runtime.activeConversationKey == key then
          runtime.activeConversationKey = nil
          characterState.activeConversationKey = nil
        end
        refreshWindow()
      end,
      onReorder = function(orders)
        trace("onReorder", "keys=" .. tostring(#orders or 0))
        for key, order in pairs(orders) do
          Store.SetSortOrder(runtime.store, key, order)
          trace("  sortOrder", "key=" .. tostring(key), "order=" .. tostring(order))
        end
        refreshWindow()
      end,
      onResetIconPosition = function()
        local nextState = tableUtils.copyState(defaultCharacterState.icon)
        characterState.icon = nextState

        if icon and icon.frame and icon.frame.SetPoint then
          local iconParent = icon.frame.parent or uiParent
          icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
        end

        return nextState
      end,
      storeConfig = runtime.store.config,
      settingsConfig = (function()
        accountState.settings = accountState.settings or {}
        return accountState.settings
      end)(),
      onSettingChanged = function(key, value)
        local persistedValue = value
        local themeApplied = false

        if key == "themePreset" then
          local fallbackKey = theme.DEFAULT_PRESET or "wow_default"
          local presetKey = value or fallbackKey
          if theme.ResolvePreset then
            local resolvedKey, applied = theme.ResolvePreset(presetKey, trace)
            persistedValue = resolvedKey or presetKey
            themeApplied = applied == true
          else
            if theme.SetPreset then
              themeApplied = theme.SetPreset(presetKey) == true
            end
            if theme.GetPreset then
              persistedValue = theme.GetPreset() or presetKey
            else
              persistedValue = presetKey
            end
          end
        end

        accountState.settings[key] = persistedValue

        if runtime.store.config[key] ~= nil then
          runtime.store.config[key] = persistedValue
        end
        if key == "messageMaxAge" then
          runtime.store.config.conversationMaxAge = persistedValue
        end

        trace("setting changed", key, tostring(persistedValue))

        if key == "fontFamily" and fonts.SetMode then
          fonts.SetMode(persistedValue or "default")
        end
        if (key == "hideMessagePreview" or key == "fontFamily") and runtime.refreshWindow then
          runtime.refreshWindow()
        end
        if key == "themePreset" and themeApplied then
          if runtime.window and runtime.window.refreshTheme then
            runtime.window.refreshTheme()
          end
          if runtime.refreshWindow then
            runtime.refreshWindow()
          end
        end
        if (key == "showUnreadBadge" or key == "badgePulse") and icon and icon.setUnreadCount then
          local freshContacts = buildContacts()
          icon.setUnreadCount(tableUtils.sumBy(freshContacts, "unreadCount"))
        end
      end,
    })

    if window.frame.Hide then
      window.frame:Hide()
    end

    runtime.window = window
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not controller.isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible then
      local unreadKey = coordinator.findLatestUnreadKey()
      local targetKey = unreadKey or runtime.activeConversationKey
      if targetKey ~= nil then
        selectConversation(targetKey)
        return
      end
    end

    refreshWindow()
  end

  local function setComposerText(text)
    if window and window.composer and window.composer.input and window.composer.input.SetText then
      window.composer.input:SetText(text or "")
    end
  end

  function controller.getWindow()
    return window
  end

  function controller.getIcon()
    return icon
  end

  function controller.isWindowVisible()
    return coordinator.isWindowVisible()
  end

  function controller.setDiagnostics(nextDiagnostics)
    diagnostics = nextDiagnostics or {}
  end

  controller.buildContacts = buildContacts
  controller.ensureWindow = ensureWindow
  controller.refreshWindow = refreshWindow
  controller.selectConversation = selectConversation
  controller.setWindowVisible = setWindowVisible
  controller.setComposerText = setComposerText
  controller.toggle = toggle

  runtime.isConversationOpen = function(conversationKey)
    return controller.isWindowVisible() and runtime.activeConversationKey == conversationKey
  end

  icon = toggleIcon.Create(uiFactory, {
    state = characterState.icon,
    onToggle = toggle,
    onPositionChanged = function(nextState)
      characterState.icon = tableUtils.copyState(nextState)
    end,
    getShowUnreadBadge = function()
      return accountState.settings.showUnreadBadge ~= false
    end,
    getBadgePulse = function()
      return accountState.settings.badgePulse ~= false
    end,
  })

  runtime.icon = icon
  runtime.toggle = toggle
  runtime.refreshWindow = refreshWindow
  runtime.ensureWindow = ensureWindow
  runtime.setWindowVisible = setWindowVisible
  runtime.setComposerText = setComposerText

  local initContacts = buildContacts()
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(tableUtils.sumBy(initContacts, "unreadCount"))
  end

  return controller
end

ns.BootstrapWindowRuntime = WindowRuntime
return WindowRuntime
