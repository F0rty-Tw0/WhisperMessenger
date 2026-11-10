local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local ReactionHandler = ns.BootstrapReactionHandler or require("WhisperMessenger.Core.Bootstrap.ReactionHandler")
local InviteHandler = ns.BootstrapInviteHandler or require("WhisperMessenger.Core.Bootstrap.InviteHandler")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local ConversationDrafts = ns.ConversationDrafts or require("WhisperMessenger.Model.ConversationDrafts")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
-- stylua: ignore
local ContactPrefsUpdate = ns.BootstrapWindowRuntimeContactPrefsUpdate or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ContactPrefsUpdate")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local QueuedSends = ns.BootstrapQueuedSends or require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local IconPosition = ns.BootstrapWindowRuntimeIconPosition or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconPosition")
local PositionSlots = ns.BootstrapWindowRuntimePositionSlots or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")
local WhoTriggers = ns.BootstrapWindowRuntimeWhoTriggers or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")
local AddonAlerts = ns.BootstrapWindowRuntimeAddonAlerts or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.AddonAlerts")
local GameWhisperTab = ns.BootstrapWindowRuntimeGameWhisperTab or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GameWhisperTab")

local WindowCallbacks = {}

WindowCallbacks.ApplyIconPosition = IconPosition.Apply

function WindowCallbacks.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountState = options.accountState or {}

  local characterState = options.characterState or {}
  local defaultCharacterState = options.defaultCharacterState or {}
  local uiParent = options.uiParent
  local getIcon = options.getIcon or function()
    return nil
  end
  local tableUtils = options.tableUtils or TableUtils
  local positionSlots = options.positionSlots
    or PositionSlots.Create({ accountState = accountState, characterState = characterState, tableUtils = tableUtils })
  local groupSendPolicy = options.groupSendPolicy
  local sendHandler = options.sendHandler
  local reactionHandler = options.reactionHandler or ReactionHandler
  local inviteHandler = options.inviteHandler or InviteHandler
  local livePresenceSender = options.livePresenceSender
  local refreshWindow = options.refreshWindow or function() end
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local selectConversation = options.selectConversation or function(_conversationKey) end
  local startConversation = options.startConversation or function() end
  local setWindowVisible = options.setWindowVisible or function() end
  local dismissWidgetPreview = options.dismissWidgetPreview or function() end
  local whoTriggers = WhoTriggers.Create(runtime)

  local function canReact(selectedContact, message)
    if type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() then
      return false
    end
    if type(selectedContact) ~= "table" or not MessageReactions.IsEligible(message, selectedContact.channel) then
      return false
    end
    if selectedContact.channel == "WOW" or selectedContact.channel == "BN" then
      return true
    end
    if type(groupSendPolicy) ~= "table" or type(groupSendPolicy.getNotice) ~= "function" then
      return false
    end
    return groupSendPolicy.getNotice(selectedContact.conversation or selectedContact) == nil
  end

  -- The block list changed: hide or show the player in the game's chat too.
  local function filtersChanged()
    if runtime.syncChatFilters then
      runtime.syncChatFilters()
    end
    refreshWindow()
  end

  local function removeConversation(item)
    local key = item and item.conversationKey
    if key == nil then
      return
    end
    local conversation = Store.Find(runtime.store, key)
    MessageReactions.ClearConversation(runtime, key)
    Store.Remove(runtime.store, key)
    if type(accountState.settings) == "table" and accountState.settings.closeGameWhisperTab == true then
      GameWhisperTab.CloseFor(key, conversation)
    end
    if runtime.activeConversationKey == key then
      runtime.activeConversationKey = nil
      characterState.activeConversationKey = nil
    end
    refreshWindow()
  end

  -- The request below `key` on the Requests tab, or the one above when it
  -- is the last; nil when it is the only one.
  local function neighbourRequestKey(key)
    local requests = ContactsTabFilter.FilterRequests(buildContacts())
    for index, item in ipairs(requests) do
      if item.conversationKey == key then
        local neighbour = requests[index + 1] or requests[index - 1]
        return neighbour and neighbour.conversationKey or nil
      end
    end
    return nil
  end

  return {
    onTabModeChanged = function(mode)
      characterState.contactsTabMode = mode
    end,

    onContactClicked = whoTriggers.onContactClicked,
    whoPlayer = whoTriggers.whoPlayer,

    onSelectConversation = function(conversationKey)
      return selectConversation(conversationKey)
    end,

    onStartConversation = function(playerName)
      return startConversation(playerName)
    end,

    onSend = whoTriggers.wrapSend(function(payload)
      if groupSendPolicy and groupSendPolicy.shouldRoutePayload(payload) then
        return groupSendPolicy.sendPayload(payload)
      end
      local sent = sendHandler.HandleSend(runtime, payload, refreshWindow)
      -- Queued or failed: the text is safe in history, so the composer clears.
      return sent or payload.deliveryRecorded == true
    end),
    -- Delivery menu: "send_now" / "discard" / "retry" (sends again).
    onMessageAction = function(selectedContact, message, action)
      local key = type(selectedContact) == "table" and selectedContact.conversationKey or nil
      if key == nil then
        return false
      end
      return QueuedSends.HandleAction(runtime, key, message, action, sendHandler, refreshWindow)
    end,
    onReact = function(selectedContact, message, reactionKey)
      return reactionHandler.HandleReact(runtime, selectedContact, message, reactionKey, refreshWindow, groupSendPolicy)
    end,
    canReact = canReact,
    onInviteContact = function(selectedContact)
      return inviteHandler.HandleInvite(runtime, selectedContact, refreshWindow)
    end,
    canInviteContact = function()
      return InviteHandler.IsEnabled(runtime)
    end,
    onTyping = function(selectedContact, text)
      if livePresenceSender == nil then
        return false
      end
      return livePresenceSender.OnComposerText(runtime, selectedContact, text)
    end,

    getDraft = function(conversationKey)
      return ConversationDrafts.Get(runtime.store, conversationKey)
    end,

    onDraftChanged = function(conversationKey, text)
      ConversationDrafts.Set(runtime.store, conversationKey, text)
    end,

    -- The compact window keeps its own size and position, so the classic
    -- window is as it was if the player switches back.
    onPositionChanged = function(nextState)
      positionSlots.write(runtime.compactLayoutActive and "compactWindow" or "window", nextState)
    end,

    onClose = function()
      setWindowVisible(false)
    end,

    onResetWindowPosition = function()
      if runtime.compactLayoutActive then
        return positionSlots.reset("compactWindow")
      end
      return positionSlots.reset("window", defaultCharacterState.window)
    end,

    onClearAllChats = function()
      MessageReactions.ClearAll(runtime)
      for key in pairs(runtime.store.conversations) do
        Store.Remove(runtime.store, key)
      end
      runtime.activeConversationKey = nil
      characterState.activeConversationKey = nil
    end,

    onPin = function(item)
      local key = item.conversationKey
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

    onRemove = removeConversation,

    -- Request banner: Accept moves it to Whispers and keeps it open there.
    onAcceptRequest = function(item)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      MessageRequests.Accept(runtime.store, key)
      if runtime.window and runtime.window.setTabMode then
        runtime.window.setTabMode("whispers")
      end
      selectConversation(key)
    end,
    -- Request banner: Delete opens the next request, so the empty page
    -- shows only once none are left.
    onDeleteRequest = function(item)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      local nextKey = neighbourRequestKey(key)
      removeConversation(item)
      if nextKey then
        selectConversation(nextKey)
      end
    end,

    onMarkUnread = function(item)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      Store.MarkUnread(runtime.store, key)
      refreshWindow()
    end,

    -- Also acknowledges the icon popup and other addons' alerts, so nothing still signals unread.
    onMarkAllRead = function()
      Store.MarkAllRead(runtime.store)
      dismissWidgetPreview()
      AddonAlerts.Clear(runtime)
      refreshWindow()
    end,

    -- Mute / nickname / note / notify-when-online / zone watch from the contact row menu.
    onUpdatePrefs = function(item, changes)
      if ContactPrefsUpdate.Apply(runtime, item, changes) then
        refreshWindow()
      end
    end,

    -- "Block…" from a contact row or a message.
    onIgnorePlayer = function(name, reason)
      if IgnoreList.Add(IgnoreList.Ensure(accountState), name, { reason = reason }) ~= nil then
        filtersChanged()
      end
    end,

    -- "Unblock" from a blocked player's contact row.
    onUnblockPlayer = function(name)
      IgnoreList.Remove(IgnoreList.Ensure(accountState), name)
      filtersChanged()
    end,

    isPlayerBlocked = function(name)
      local now = type(runtime.now) == "function" and runtime.now() or nil
      return IgnoreList.Lookup(IgnoreList.Ensure(accountState), name, now) ~= nil
    end,

    onReorder = function(orders)
      for key, order in pairs(orders) do
        Store.SetSortOrder(runtime.store, key, order)
      end
      refreshWindow()
    end,

    onResetIconPosition = function()
      local nextState = positionSlots.reset("icon", defaultCharacterState.icon)

      return WindowCallbacks.ApplyIconPosition(getIcon(), nextState, uiParent)
    end,
  }
end

ns.BootstrapWindowRuntimeWindowCallbacks = WindowCallbacks

return WindowCallbacks
