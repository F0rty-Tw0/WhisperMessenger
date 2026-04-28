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
local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local MessengerWindow = ns.MessengerWindow or require("WhisperMessenger.UI.MessengerWindow")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

local SettingsHandler = ns.BootstrapWindowRuntimeSettingsHandler
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local ConversationSelector = ns.BootstrapWindowRuntimeConversationSelector
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")
local WidgetPreview = ns.BootstrapWindowRuntimeWidgetPreview
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")
local StartConversation = ns.BootstrapWindowRuntimeStartConversation
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")

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
  local trace = options.trace or function(...)
    local _ = ...
  end

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

  local function isMythicRestricted()
    return bootstrap._inMythicContent == true
  end

  local widgetPreview = WidgetPreview.Create({
    accountState = accountState,
    runtimeStore = runtime.store or {},
    badgeFilter = BadgeFilter,
  })

  local function findLatestIncomingPreview(contacts)
    return widgetPreview.findLatestIncomingPreview(contacts)
  end

  local function buildLatestIncomingPreview(contacts)
    return widgetPreview.buildLatestIncomingPreview(contacts)
  end

  local function acknowledgeLatestWidgetPreview(contacts)
    return widgetPreview.acknowledgeLatestWidgetPreview(contacts)
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
    isMythicRestricted = isMythicRestricted,
    presenceCache = presenceCache,
    buildMessagePreview = buildLatestIncomingPreview,
  })

  runtime.onAvailabilityChanged = coordinator.scheduleAvailabilityRefresh

  -- Per-character group key prefixes (excluding guild, which is
  -- account-wide keyed by guild name — see isForeignCharacterGroup).
  -- For these, when the trailing profileId on the key isn't the current
  -- character's, the conversation is an alt's history and sending must
  -- be blocked — otherwise the composer would forward the message to
  -- the CURRENT character's group, which is a different channel than
  -- what the UI is showing.
  local FOREIGN_PROFILE_GROUP_PREFIXES = { "party::", "raid::", "instance::", "officer::" }

  local function resolvePlayerGuildName()
    local getGuildInfo = _G.GetGuildInfo
    if type(getGuildInfo) ~= "function" then
      return nil
    end
    local ok, name = pcall(getGuildInfo, "player")
    if not ok or type(name) ~= "string" or name == "" then
      return nil
    end
    return name
  end

  local function isForeignCharacterGroup(conversation)
    local conversationKey = conversation and conversation.conversationKey
    if type(conversationKey) ~= "string" then
      return false
    end

    -- Guild is account-wide: two alts in the same guild share the
    -- conversation, so "foreign" is decided by whether the current
    -- character is in the conversation's stored guild rather than by
    -- a trailing profileId on the key.
    if string.find(conversationKey, "guild::", 1, true) == 1 then
      local storedGuildName = conversation.guildName
      if type(storedGuildName) == "string" and storedGuildName ~= "" then
        local playerGuildName = resolvePlayerGuildName()
        if playerGuildName and string.lower(playerGuildName) == string.lower(storedGuildName) then
          return false
        end
        return true
      end
      -- Legacy per-character guild key: fall back to profileId compare.
      local owner = string.sub(conversationKey, 8)
      return owner ~= "" and owner ~= runtime.localProfileId
    end

    for _, prefix in ipairs(FOREIGN_PROFILE_GROUP_PREFIXES) do
      if string.find(conversationKey, prefix, 1, true) == 1 then
        local owner = string.sub(conversationKey, #prefix + 1)
        if owner ~= "" and owner ~= runtime.localProfileId then
          return true
        end
        return false
      end
    end
    return false
  end

  -- Group membership notice: shown in the composer when the user is no longer
  -- in the group for the active conversation.
  -- Legacy whisper channels use "WOW"/"BN"; skip them — they are not group channels.
  runtime.getGroupSendNotice = function(conversation)
    if conversation == nil then
      return nil
    end
    local ch = conversation.channel
    if ch == nil then
      return nil
    end
    -- Skip legacy whisper channel strings and explicit ChannelType whisper constants.
    if ch == "WOW" or ch == "BN" or ch == ChannelType.WHISPER or ch == ChannelType.BN_WHISPER then
      return nil
    end
    -- COMMUNITY is receive-only but not a group membership issue.
    if ch == ChannelType.COMMUNITY then
      return nil
    end
    -- Foreign-character group history is read-only from this character.
    if isForeignCharacterGroup(conversation) then
      return "Another character's history — read-only."
    end
    if not ChatGateway.CanSend(runtime.chatApi, conversation) then
      return "Not in group — can't send."
    end
    return nil
  end

  local controller = {}

  local function setWindowVisible(nextVisible)
    if nextVisible then
      acknowledgeLatestWidgetPreview(buildContacts())
    end
    return coordinator.setWindowVisible(nextVisible)
  end

  local function refreshWindow()
    return coordinator.refreshWindow()
  end

  local function dismissWidgetPreview()
    acknowledgeLatestWidgetPreview(buildContacts())
    return coordinator.refreshWindow()
  end

  local conversationSelector = ConversationSelector.Create({
    runtime = runtime,
    characterState = characterState,
    markConversationRead = markConversationRead,
    presenceCache = presenceCache,
    requestAvailability = requestAvailability,
    getDiagnostics = function()
      return diagnostics
    end,
    refreshWindow = refreshWindow,
  })
  local function selectConversation(conversationKey)
    return conversationSelector.selectConversation(conversationKey)
  end

  local startConversationFlow = StartConversation.Create({
    runtime = runtime,
    identity = Identity,
    getWindow = function()
      return window
    end,
    selectConversation = function(conversationKey)
      return selectConversation(conversationKey)
    end,
  })
  local startConversation = startConversationFlow.startConversation

  local function ensureWindow()
    if window then
      return
    end

    local contacts = buildContacts()
    local selectedState = coordinator.buildSelectionState(contacts)
    local settingsState = (function()
      accountState.settings = accountState.settings or {}
      return accountState.settings
    end)()
    local onSettingChanged = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = settingsState,
      theme = theme,
      fonts = fonts,
      timeFormat = TimeFormat,
      trace = trace,
      getIcon = function()
        return icon
      end,
      buildContacts = buildContacts,
      tableUtils = tableUtils,
    })

    window = messengerWindow.Create(uiFactory, {
      contacts = contacts,
      selectedContact = selectedState.selectedContact,
      conversation = selectedState.conversation,
      status = selectedState.status,
      state = characterState.window,
      initialTabMode = characterState.contactsTabMode or "whispers",
      onTabModeChanged = function(mode)
        characterState.contactsTabMode = mode
      end,
      onSelectConversation = function(conversationKey)
        return selectConversation(conversationKey)
      end,
      onStartConversation = function(playerName)
        return startConversation(playerName)
      end,
      onSend = function(payload)
        local channel = payload and payload.channel
        -- Legacy whisper channels use "WOW" and "BN"; new group channels use
        -- ChannelType constants (PARTY, INSTANCE_CHAT, BN_CONVERSATION, etc.).
        -- Only route through ChatGateway for explicit group channel constants.
        local isLegacyWhisper = channel == "WOW"
          or channel == "BN"
          or channel == ChannelType.WHISPER
          or channel == ChannelType.BN_WHISPER
        if channel ~= nil and not isLegacyWhisper then
          -- Group channel: route through ChatGateway.Send with pcall guard.
          -- The echo (CHAT_MSG_PARTY / INSTANCE_CHAT / BN_CONVERSATION) will
          -- arrive via GroupChatIngest and append the message automatically.
          if not ChatGateway.CanSend(runtime.chatApi, payload) then
            return false
          end
          local ok, err = pcall(ChatGateway.Send, runtime.chatApi, payload, payload.text)
          if not ok then
            trace("group send error", tostring(err))
          end
          return ok
        end
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
          if runtime.store.conversations[key] == nil and runtime.activeConversationKey == key then
            runtime.activeConversationKey = nil
            characterState.activeConversationKey = nil
          end
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
      settingsConfig = settingsState,
      onSettingChanged = onSettingChanged,
    })

    if window.frame.Hide then
      window.frame:Hide()
    end

    runtime.window = window
  end

  local function conversationMatchesTab(conversationKey, tabMode)
    if tabMode == nil then
      return true
    end
    local conversation = runtime.store and runtime.store.conversations and runtime.store.conversations[conversationKey]
      or nil
    if conversation == nil then
      return true
    end
    local isGroup = BadgeFilter.IsGroupChannel(conversation.channel)
    if tabMode == "groups" then
      return isGroup
    end
    return not isGroup
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not controller.isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible then
      local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or nil
      local unreadKey = coordinator.findLatestUnreadKey()
      -- Gate the "jump to unread" shortcut by the current tab: on the Groups
      -- tab we don't want a freshly-received whisper to steal the selection,
      -- and on the Whispers tab an unread party message shouldn't.
      if unreadKey and not conversationMatchesTab(unreadKey, tabMode) then
        unreadKey = nil
      end
      local targetKey = unreadKey or runtime.activeConversationKey
      if targetKey ~= nil and conversationMatchesTab(targetKey, tabMode) then
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
    iconSize = accountState.settings.iconSize,
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
    getIconDesaturated = function()
      return accountState.settings.iconDesaturated ~= false
    end,
    getPreviewAutoDismissSeconds = function()
      local value = accountState.settings.widgetPreviewAutoDismissSeconds
      if value == nil then
        return 30
      end
      return tonumber(value) or 0
    end,
    getPreviewPosition = function()
      local value = accountState.settings.widgetPreviewPosition
      if type(value) ~= "string" or value == "" then
        return "right"
      end
      return value
    end,
    onDismissPreview = dismissWidgetPreview,
  })

  runtime.icon = icon
  runtime.toggle = toggle
  runtime.refreshWindow = refreshWindow
  runtime.ensureWindow = ensureWindow
  runtime.setWindowVisible = setWindowVisible
  runtime.setComposerText = setComposerText

  local initContacts = buildContacts()
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(BadgeFilter.SumWhisperUnread(initContacts))
  end
  if icon and icon.setIncomingPreview then
    local preview = buildLatestIncomingPreview(initContacts)
    icon.setIncomingPreview(
      preview and preview.senderName or nil,
      preview and preview.messageText or nil,
      preview and preview.classTag or nil
    )
  end

  return controller
end

ns.BootstrapWindowRuntime = WindowRuntime
return WindowRuntime
