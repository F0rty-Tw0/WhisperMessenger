local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FacadePayload = {}

function FacadePayload.Build(options)
  options = options or {}

  local chrome = options.chrome
  local layout = options.layout
  local settings = options.settings or {}

  return {
    frame = chrome.frame,
    title = chrome.title,
    newConversationButton = chrome.newConversationButton,
    contactsPane = layout.contactsPane,
    contactsPaneBorder = layout.contactsPaneBorder,
    contactsDivider = layout.contactsDivider,
    contactsRightBorder = layout.contactsRightBorder,
    contactsHeaderDivider = layout.contactsHeaderDivider,
    contentPane = layout.contentPane,
    headerDivider = layout.headerDivider,
    titleBarBorder = chrome.titleBarBorder,
    titleBarTopBorder = chrome.titleBarTopBorder,
    threadPane = layout.threadPane,
    composerPane = layout.composerPane,
    composerPaneBorder = layout.composerPaneBorder,
    composerDivider = layout.composerDivider,
    closeButton = chrome.closeButton,
    optionsButton = chrome.optionsButton,
    optionsPanel = layout.optionsPanel,
    optionsMenu = layout.optionsMenu,
    optionsContentPane = layout.optionsContentPane,
    generalTab = layout.generalTab,
    appearanceTab = layout.appearanceTab,
    behaviorTab = layout.behaviorTab,
    notificationsTab = layout.notificationsTab,
    generalSettings = settings.general,
    appearanceSettings = settings.appearance,
    behaviorSettings = settings.behavior,
    notificationSettings = settings.notifications,
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
    contacts = options.contacts,
    conversation = options.conversation,
    composer = options.composer,
    refreshContacts = options.refreshContacts,
    refreshSelection = options.refreshSelection,
    refreshTheme = options.refreshTheme,
    handleContactSelected = options.handleContactSelected,
  }
end

ns.MessengerWindowFacadePayload = FacadePayload

return FacadePayload
