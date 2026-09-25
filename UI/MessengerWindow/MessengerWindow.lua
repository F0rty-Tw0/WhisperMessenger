local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local WindowScripts = ns.MessengerWindowWindowScripts or require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local ContactsRuntime = ns.MessengerWindowContactsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local TabSelectionMemory = ns.MessengerWindowTabSelectionMemory or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")
local SettingsPanelsBootstrap = ns.MessengerWindowSettingsPanelsBootstrap
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelsBootstrap")
local SelectionSync = ns.MessengerWindowSelectionSync or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local SelectionController = ns.MessengerWindowSelectionController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionController")
local WindowVisibility = ns.MessengerWindowWindowVisibility or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")
local WindowAlpha = ns.MessengerWindowWindowAlpha or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local WindowGeometry = ns.MessengerWindowWindowGeometry or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local ScriptWiring = ns.MessengerWindowScriptWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ScriptWiring")
local RelayoutController = ns.MessengerWindowRelayoutController or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
local PatchNotesRuntime = ns.MessengerWindowPatchNotesRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PatchNotesRuntime")
local LanguageRefresh = ns.MessengerWindowLanguageRefresh or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LanguageRefresh")
local PatchNotes = ns.PatchNotes or require("WhisperMessenger.Core.PatchNotes")
local SettingsPanels = ns.MessengerWindowSettingsPanels or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local sizeValue = UIHelpers.sizeValue
local captureFramePosition = UIHelpers.captureFramePosition

local MessengerWindow = {}

function MessengerWindow.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local settingsConfig = options.settingsConfig or {}
  local initialScale = WindowScale.Normalize(settingsConfig.windowScale)
  settingsConfig.windowScale = initialScale
  local state = options.state or {}
  local initialState = WindowBounds.ClampState(parent, {
    anchorPoint = state.anchorPoint or "CENTER",
    relativePoint = state.relativePoint or state.anchorPoint or "CENTER",
    x = state.x or 0,
    y = state.y or 0,
    width = state.width or Theme.WINDOW_WIDTH,
    height = state.height or Theme.WINDOW_HEIGHT,
    minimized = state.minimized or false,
  }, Theme, initialScale)
  local windowGeometry = WindowGeometry.Create({
    parent = parent,
    theme = Theme,
    clampState = WindowBounds.ClampState,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = captureFramePosition,
    sizeValue = sizeValue,
    initialState = initialState,
    initialContactsWidth = state.contactsWidth,
    initialScale = initialScale,
  })
  local currentContactsWidth = windowGeometry.getContactsWidth()

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end
    return target ~= nil and target.shown == true
  end

  -- Build chrome (outer frame, buttons, etc.). useNativeChrome flips
  -- the frame to BasicFrameTemplateWithInset (gold border, red X) — read
  -- from saved settings so it persists across reloads.
  StyledTextInputPopup.nativeChrome = settingsConfig.nativeChrome == true
  local chrome = ChromeBuilder.Build(factory, parent, initialState, {
    title = options.title,
    useNativeChrome = settingsConfig.nativeChrome == true,
    windowScale = initialScale,
  })
  local frame = chrome.frame

  -- Settings config is normalized before geometry and chrome creation.

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, { contactsWidth = currentContactsWidth })
  currentContactsWidth = layout.contactsWidth or currentContactsWidth
  windowGeometry.setContactsWidth(currentContactsWidth)
  local contactsPane = layout.contactsPane
  local contentPane = layout.contentPane
  local threadPane = layout.threadPane
  local composerPane = layout.composerPane
  local optionsPanel = layout.optionsPanel
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content or layout.optionsContentPane
  local contactsView = layout.contactsView
  local contactsSearchInput = layout.contactsSearchInput
  local contactsSearchClearButton = layout.contactsSearchClearButton
  local contactsSearchPlaceholder = layout.contactsSearchPlaceholder
  -- Construct each settings panel when its tab is selected.
  local settingsResult = {}
  local settingKeys = {
    "generalSettings",
    "appearanceSettings",
    "behaviorSettings",
    "notificationSettings",
    "iconSettings",
    "patchNotesSettings",
  }
  local settingsRuntime = SettingsPanelsBootstrap.Create(factory, {
    parent = optionsScrollContent,
    settingsConfig = settingsConfig,
    storeConfig = options.storeConfig or {},
    onSettingChanged = options.onSettingChanged,
    theme = Theme,
    chrome = chrome,
    layout = layout,
    onPanelCreated = function(index, _panel, settings)
      settingsResult[settingKeys[index]] = settings
    end,
  })
  local settingsPanels = settingsRuntime.settingsPanels
  local refreshThemeVisuals = settingsRuntime.refreshThemeVisuals

  -- Contacts controller (manages rows, paging, scroll hooks)
  local handleContactSelected -- forward declaration
  local selectionController = nil
  -- Per-tab remembered selection/restore policy. Keep it in a focused helper
  -- so Create only wires runtime dependencies instead of owning the policy.
  local refreshSelection -- forward declaration (used by swap callback below)
  local conversation -- forward declaration (tab changes retitle its empty state)
  -- IMPORTANT: declare before the `= Create(...)` call so the callbacks
  -- inside the table constructor capture THIS local (not a global/nil).
  -- Lua local scope begins AFTER the declaration statement completes.
  local contactsRuntime
  local tabSelectionMemory = TabSelectionMemory.Create({
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
    getCurrentContacts = function()
      if contactsRuntime and contactsRuntime.getCurrentContacts then
        return contactsRuntime.getCurrentContacts() or {}
      end
      return {}
    end,
    handleContactSelected = function(item)
      if handleContactSelected then
        handleContactSelected(item)
      end
    end,
    refreshSelection = function(nextState)
      if refreshSelection then
        refreshSelection(nextState)
      end
    end,
  })
  contactsRuntime = ContactsRuntime.Create(factory, {
    contactsPane = contactsPane,
    nativeChrome = layout.nativeChrome == true,
    contactsView = contactsView,
    initialContacts = options.contacts or {},
    settingsConfig = settingsConfig,
    initialTabMode = options.initialTabMode,
    onTabModeChanged = function(mode)
      if conversation and conversation.headerEmpty then
        conversation.headerEmpty.setMode(mode)
      end
      if options.onTabModeChanged then
        options.onTabModeChanged(mode)
      end
    end,
    onTabModeSwapSelection = tabSelectionMemory.onTabModeSwapSelection,
    onSelect = tabSelectionMemory.onSelect,
    onPin = options.onPin,
    onRemove = options.onRemove,
    onMarkUnread = options.onMarkUnread,
    onReorder = options.onReorder,
    contactsSearchInput = contactsSearchInput,
    contactsSearchClearButton = contactsSearchClearButton,
    contactsSearchPlaceholder = contactsSearchPlaceholder,
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
  })
  local contactsController = contactsRuntime.contactsController
  local contacts = contactsRuntime.contacts
  local refreshContacts = contactsRuntime.refreshContacts
  local getCurrentContacts = contactsRuntime.getCurrentContacts
  contactsRuntime.bindInputScripts()

  -- The tab toggle is created after LayoutBuilder.Build, so the list was
  -- sized without it. Reserve its height now and re-run the layout once.
  layout.contactsBottomInset = contactsRuntime.getContactsBottomInset()
  if layout.contactsBottomInset > 0 then
    LayoutBuilder.Relayout(layout, initialState.width, initialState.height, currentContactsWidth)
  end

  -- Conversation pane
  conversation = ConversationPane.Create(factory, threadPane, options.selectedContact, options.conversation, {
    onReact = options.onReact,
    canReact = options.canReact,
    onInviteContact = options.onInviteContact,
    hideEmptyHeader = settingsConfig.nativeChrome == true,
  })
  conversation.headerEmpty.setMode(contactsRuntime.getTabMode())

  -- Composer (created before wiring alpha so we have composer.input)
  local composerSelectedContact = {}

  local windowVisibility = WindowVisibility.Create({
    optionsPanel = optionsPanel,
    contactsPane = contactsPane,
    contentPane = contentPane,
    frame = frame,
    onClose = options.onClose,
    onOptionsVisibilityChanged = chrome.setOptionsActive,
  })
  local setOptionsVisible = windowVisibility.setOptionsVisible
  local closeWindow = windowVisibility.closeWindow

  local composer = Composer.Create(factory, composerPane, composerSelectedContact, options.onSend or function(...)
    local _ = ...
  end, closeWindow, function()
    return settingsConfig.doubleEscapeToClose == true
  end, options.onTyping, { nativeChrome = layout.nativeChrome == true })
  settingsRuntime.setThemeTargets(conversation, composer)

  -- Alpha helpers (capture composer.input now that composer exists)
  local composerInput = composer.input
  local windowAlpha = WindowAlpha.Create({
    alphaController = AlphaController,
    frame = frame,
    composerInput = composerInput,
    settingsConfig = settingsConfig,
  })
  local refreshWindowAlpha = windowAlpha.refreshWindowAlpha

  -- Selection management
  selectionController = SelectionController.Create({
    refreshContacts = refreshContacts,
    refreshConversationPane = function(selectedContact, selectedConversation, selectedStatus, noticeText)
      ConversationPane.Refresh(conversation, selectedContact, selectedConversation, selectedStatus, noticeText)
    end,
    syncComposerSelectedContact = function(selectedContact)
      SelectionSync.SyncComposerSelectedContact(composerSelectedContact, selectedContact)
    end,
    setComposerEnabled = function(selectedContact, noticeText)
      SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText)
    end,
    onSelectConversation = options.onSelectConversation,
    getSelectedContact = options.getSelectedContact,
    getConversation = options.getConversation,
    getStatus = options.getStatus,
  })

  refreshSelection = function(nextState, resetPaging)
    selectionController.refresh(nextState, resetPaging)
  end

  handleContactSelected = selectionController.handleContactSelected

  local relayoutWindow, scriptResult = LifecycleWiring.Setup({
    relayoutFactory = RelayoutController,
    layoutBuilder = LayoutBuilder,
    layout = layout,
    setContactsWidth = function(nextContactsWidth)
      currentContactsWidth = nextContactsWidth or currentContactsWidth
      windowGeometry.setContactsWidth(currentContactsWidth)
    end,
    composer = composer,
    contactsController = contactsController,
    conversation = conversation,
    conversationPane = ConversationPane,
    refreshContacts = refreshContacts,
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
    getCurrentContacts = getCurrentContacts,
    selectedContact = options.selectedContact,
    initialConversation = options.conversation,
    initialStatus = options.status,
    refreshSelection = refreshSelection,
    setOptionsVisible = setOptionsVisible,
    scriptWiring = ScriptWiring,
    windowScripts = WindowScripts,
    chrome = chrome,
    settingsPanels = settingsPanels,
    closeWindow = closeWindow,
    onResetWindowPosition = options.onResetWindowPosition,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    onStartConversation = options.onStartConversation,
    isShown = isShown,
    windowGeometry = windowGeometry,
    frame = frame,
    refreshWindowAlpha = refreshWindowAlpha,
    onPositionChanged = options.onPositionChanged,
    theme = Theme,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return settingsConfig.autoFocusComposer == true
    end,
  })

  -- Patch-notes "?" button: glows until the shipped release notes are read.
  -- Clicking opens Options on the What's New page; the sidebar tab clears the
  -- glow too, so either route counts as seeing the notes.
  if PatchNotes ~= nil and chrome.patchNotesButton ~= nil then
    PatchNotesRuntime.Wire({
      button = chrome.patchNotesButton,
      tab = layout.whatsNewTab,
      setGlowing = chrome.setPatchNotesGlow,
      settingsConfig = settingsConfig,
      patchNotes = PatchNotes,
      openPage = function()
        setOptionsVisible(true)
        if scriptResult.selectSettingsTab then
          scriptResult.selectSettingsTab(SettingsPanels.PATCH_NOTES_INDEX)
        end
      end,
    })
  elseif chrome.patchNotesButton ~= nil and chrome.patchNotesButton.Hide then
    chrome.patchNotesButton:Hide()
  end

  local function setScale(nextScale)
    local currentState = windowGeometry.buildState(frame)
    local previousWidth = sizeValue(frame, "GetWidth", "width", currentState.width)
    local previousHeight = sizeValue(frame, "GetHeight", "height", currentState.height)
    currentState.width = previousWidth
    currentState.height = previousHeight
    local normalizedScale = windowGeometry.setScale(nextScale)
    settingsConfig.windowScale = normalizedScale

    local appliedState = scriptResult.withSizeChangedRelayoutSuppressed(function()
      chrome.refreshScale(normalizedScale)
      return windowGeometry.applyState(frame, currentState)
    end)
    if appliedState.width ~= previousWidth or appliedState.height ~= previousHeight then
      relayoutWindow(appliedState.width, appliedState.height, windowGeometry.getContactsWidth(), nil)
    end
    return normalizedScale
  end

  -- Re-applies the layout at the current size (theme, language and footer
  -- tab changes can all move the bottom of the contacts list).
  local function relayoutCurrentSize()
    relayoutWindow(
      sizeValue(frame, "GetWidth", "width", initialState.width),
      sizeValue(frame, "GetHeight", "height", initialState.height),
      windowGeometry.getContactsWidth(),
      false
    )
  end

  local refreshLanguage = LanguageRefresh.Create({
    layout = layout,
    composer = composer,
    settingsRuntime = settingsRuntime,
    settingsConfig = settingsConfig,
    contactsRuntime = contactsRuntime,
    relayoutCurrentSize = relayoutCurrentSize,
    conversation = conversation,
    scriptResult = scriptResult,
    refreshContacts = refreshContacts,
    getCurrentContacts = getCurrentContacts,
    selectionController = selectionController,
  })

  local window = {
    frame = chrome.frame,
    title = chrome.title,
    newConversationButton = chrome.newConversationButton,
    patchNotesButton = chrome.patchNotesButton,
    contactsPane = layout.contactsPane,
    contactsDivider = layout.contactsDivider,
    contentPane = layout.contentPane,
    headerDivider = layout.headerDivider,
    threadPane = layout.threadPane,
    composerPane = layout.composerPane,
    closeButton = chrome.closeButton,
    optionsButton = chrome.optionsButton,
    backButton = chrome.backButton,
    optionsPanel = layout.optionsPanel,
    optionsMenu = layout.optionsMenu,
    optionsContentPane = layout.optionsContentPane,
    generalTab = layout.generalTab,
    appearanceTab = layout.appearanceTab,
    behaviorTab = layout.behaviorTab,
    notificationsTab = layout.notificationsTab,
    iconsTab = layout.iconsTab,
    whatsNewTab = layout.whatsNewTab,
    settingsPanels = settingsPanels,
    generalSettings = settingsRuntime.getSettings(1),
    appearanceSettings = settingsRuntime.getSettings(2),
    behaviorSettings = settingsRuntime.getSettings(3),
    notificationSettings = settingsRuntime.getSettings(4),
    iconSettings = settingsRuntime.getSettings(5),
    patchNotesSettings = settingsRuntime.getSettings(SettingsPanels.PATCH_NOTES_INDEX),
    optionsHeader = layout.optionsHeader,
    optionsHint = layout.optionsHint,
    resetWindowButton = layout.resetWindowButton,
    resetIconButton = layout.resetIconButton,
    clearAllChatsButton = layout.clearAllChatsButton,
    contactsSearchInput = layout.contactsSearchInput,
    contactsSearchClearButton = layout.contactsSearchClearButton,
    contactsSearchPlaceholder = layout.contactsSearchPlaceholder,
    resizeGrip = chrome.resizeGrip,
    contactsResizeHandle = layout.contactsResizeHandle,
    tabToggle = contactsRuntime.tabToggle,
    contacts = contacts,
    conversation = conversation,
    composer = composer,
    refreshContacts = refreshContacts,
    refreshSelection = refreshSelection,
    refreshTheme = function()
      refreshThemeVisuals()
      -- Tab bar reads colours at paint time; re-set the current mode to
      -- repaint it without firing the mode-change callback.
      local tabToggle = contactsRuntime.tabToggle
      if tabToggle then
        tabToggle.setMode(tabToggle.getMode())
      end
      -- Re-apply pane anchors and composer geometry for the new theme.
      relayoutCurrentSize()
    end,
    setScale = setScale,
    refreshLanguage = refreshLanguage,
    refreshTabToggleVisibility = function()
      contactsRuntime.refreshTabToggleVisibility()
      layout.contactsBottomInset = contactsRuntime.getContactsBottomInset()
      relayoutWindow(
        sizeValue(frame, "GetWidth", "width", initialState.width),
        sizeValue(frame, "GetHeight", "height", initialState.height),
        windowGeometry.getContactsWidth(),
        false
      )
    end,
    setTabMode = contactsRuntime.setTabMode,
    getTabMode = contactsRuntime.getTabMode,
    selectConversation = function(conversationKey)
      for _, row in ipairs(contacts.rows) do
        if row.item ~= nil and row.item.conversationKey == conversationKey then
          handleContactSelected(row.item)
          return true
        end
      end
      refreshSelection()
      return false
    end,
  }
  return setmetatable(window, { __index = settingsResult })
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
