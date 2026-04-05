local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FacadeBuilder = {}

function FacadeBuilder.Build(context)
  local contacts = context.contacts
  local handleContactSelected = context.handleContactSelected
  local refreshSelection = context.refreshSelection

  return {
    frame = context.frame,
    title = context.title,
    newConversationButton = context.newConversationButton,
    contactsPane = context.contactsPane,
    contactsPaneBorder = context.contactsPaneBorder,
    contactsDivider = context.contactsDivider,
    contactsRightBorder = context.contactsRightBorder,
    contactsHeaderDivider = context.contactsHeaderDivider,
    contentPane = context.contentPane,
    headerDivider = context.headerDivider,
    titleBarBorder = context.titleBarBorder,
    titleBarTopBorder = context.titleBarTopBorder,
    threadPane = context.threadPane,
    composerPane = context.composerPane,
    composerPaneBorder = context.composerPaneBorder,
    composerDivider = context.composerDivider,
    closeButton = context.closeButton,
    optionsButton = context.optionsButton,
    optionsPanel = context.optionsPanel,
    optionsMenu = context.optionsMenu,
    optionsContentPane = context.optionsContentPane,
    generalTab = context.generalTab,
    appearanceTab = context.appearanceTab,
    behaviorTab = context.behaviorTab,
    notificationsTab = context.notificationsTab,
    generalSettings = context.generalSettings,
    appearanceSettings = context.appearanceSettings,
    behaviorSettings = context.behaviorSettings,
    notificationSettings = context.notificationSettings,
    optionsHeader = context.optionsHeader,
    optionsHint = context.optionsHint,
    resetWindowButton = context.resetWindowButton,
    resetIconButton = context.resetIconButton,
    clearAllChatsButton = context.clearAllChatsButton,
    contactsSearchInput = context.contactsSearchInput,
    contactsSearchClearButton = context.contactsSearchClearButton,
    contactsSearchPlaceholder = context.contactsSearchPlaceholder,
    resizeGrip = context.resizeGrip,
    contactsResizeHandle = context.contactsResizeHandle,
    contacts = contacts,
    conversation = context.conversation,
    composer = context.composer,
    refreshContacts = context.refreshContacts,
    refreshSelection = refreshSelection,
    refreshTheme = context.refreshTheme,
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
end

ns.MessengerWindowFacadeBuilder = FacadeBuilder

return FacadeBuilder
