local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local RelayoutController = {}

-- The composer grows to at most this share (1/N) of the content height.
local COMPOSER_MAX_SHARE = 3

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
  local onContactsWidth = options.onContactsWidth

  local controller = {}
  local lastWidth, lastHeight, lastContactsWidth
  local composerRunning = false

  local function composerMaxHeight(metrics)
    if not metrics.contentHeight then
      return nil
    end

    return math.floor(metrics.contentHeight / COMPOSER_MAX_SHARE)
  end

  function controller.relayoutWindow(w, h, requestedContactsWidth, refreshContactsLayout)
    lastWidth, lastHeight, lastContactsWidth = w, h, requestedContactsWidth
    local metrics = layoutBuilder.Relayout(layout, w, h, requestedContactsWidth)
    -- Remember the expanded width: the rail's width is not the one to return to.
    setContactsWidth(metrics.expandedContactsWidth or metrics.contactsWidth)
    -- The live width (the rail when collapsed), for panels that line up with the list.
    if onContactsWidth then
      onContactsWidth(metrics.contactsWidth)
    end

    if composer and composer.relayout then
      local heightBefore = layout.composerHeight
      composerRunning = true
      local ok, err = pcall(composer.relayout, metrics.contentWidth, composerMaxHeight(metrics))
      composerRunning = false
      if not ok then
        error(err, 0)
      end
      -- Rows never change the width, so one more pass settles the new bar height.
      if layout.composerHeight ~= heightBefore then
        metrics = layoutBuilder.Relayout(layout, w, h, requestedContactsWidth)
      end
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

  function controller.setComposerHeight(height)
    if layout.composerHeight == height then
      return
    end
    layout.composerHeight = height
    if composerRunning or not lastWidth then
      return
    end

    -- Replays the last size, so every window relayout must go through this controller.
    controller.relayoutWindow(lastWidth, lastHeight, lastContactsWidth, false)
  end

  return controller
end

ns.MessengerWindowRelayoutController = RelayoutController

return RelayoutController
