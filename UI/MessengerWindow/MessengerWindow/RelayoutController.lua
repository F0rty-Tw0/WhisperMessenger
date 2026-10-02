local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local RelayoutController = {}

function RelayoutController.Create(options)
  options = options or {}

  local layoutBuilder = options.layoutBuilder
  local layout = options.layout
  local setContactsWidth = options.setContactsWidth
  local composer = options.composer
  local contactsController = options.contactsController
  local conversation = options.conversation
  local conversationPane = options.conversationPane
  local refreshContacts = options.refreshContacts
  local getSelectedConversationKey = options.getSelectedConversationKey

  local controller = {}

  function controller.relayoutWindow(w, h, requestedContactsWidth, refreshContactsLayout)
    local metrics = layoutBuilder.Relayout(layout, w, h, requestedContactsWidth)
    -- Remember the expanded width: the rail's width is not the one to return to.
    setContactsWidth(metrics.expandedContactsWidth or metrics.contactsWidth)

    if composer and composer.relayout then
      composer.relayout(metrics.contentWidth)
    end
    if contactsController and contactsController.fillViewport then
      contactsController.fillViewport(metrics.contactsListHeight or metrics.contactsHeight)
    end
    if conversation then
      conversationPane.Relayout(conversation, metrics.contentWidth, metrics.threadHeight)
    end
    if refreshContactsLayout then
      refreshContacts(nil, getSelectedConversationKey(), false)
    end
  end

  return controller
end

ns.MessengerWindowRelayoutController = RelayoutController

return RelayoutController
