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
local ContactPrefs = ns.ContactPrefs or require("WhisperMessenger.Model.ContactPrefs")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
local QueuedSends = ns.BootstrapQueuedSends or require("WhisperMessenger.Core.Bootstrap.QueuedSends")

local WindowCallbacks = {}

function WindowCallbacks.ApplyIconPosition(icon, nextState, uiParent)
  local frame = icon and icon.frame
  if frame and type(frame.SetPoint) == "function" then
    if type(frame.ClearAllPoints) == "function" then
      frame:ClearAllPoints()
    end
    local iconParent
    if type(frame.GetParent) == "function" then
      iconParent = frame:GetParent()
    end
    iconParent = iconParent or frame.parent or uiParent
    frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
  end
  return nextState
end

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
  local groupSendPolicy = options.groupSendPolicy
  local sendHandler = options.sendHandler
  local reactionHandler = options.reactionHandler or ReactionHandler
  local inviteHandler = options.inviteHandler or InviteHandler
  local livePresenceSender = options.livePresenceSender
  local refreshWindow = options.refreshWindow or function() end
  local selectConversation = options.selectConversation or function(_conversationKey) end
  local startConversation = options.startConversation or function() end
  local setWindowVisible = options.setWindowVisible or function() end

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

  local function removeConversation(item)
    local key = item and item.conversationKey
    if key == nil then
      return
    end
    MessageReactions.ClearConversation(runtime, key)
    Store.Remove(runtime.store, key)
    if runtime.activeConversationKey == key then
      runtime.activeConversationKey = nil
      characterState.activeConversationKey = nil
    end
    refreshWindow()
  end

  return {
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
      if groupSendPolicy and groupSendPolicy.shouldRoutePayload(payload) then
        return groupSendPolicy.sendPayload(payload)
      end
      local sent = sendHandler.HandleSend(runtime, payload, refreshWindow)
      -- Queued or failed: the text is safe in history, so the composer clears.
      return sent or payload.deliveryRecorded == true
    end,
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
    onDeleteRequest = removeConversation,

    onMarkUnread = function(item)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      Store.MarkUnread(runtime.store, key)
      refreshWindow()
    end,

    onMarkAllRead = function()
      Store.MarkAllRead(runtime.store)
      refreshWindow()
    end,

    -- Mute / nickname / note / notify-when-online from the contact row menu.
    onUpdatePrefs = function(item, changes)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      ContactPrefs.Apply(runtime.store, key, changes)
      -- Record the friend's state now so their next login is a change.
      if changes and changes.notifyOnline == true then
        OnlineWatch.Observe(runtime, key, OnlineWatch.ReadOnline(runtime, runtime.store.conversations[key]))
      end
      refreshWindow()
    end,

    onReorder = function(orders)
      for key, order in pairs(orders) do
        Store.SetSortOrder(runtime.store, key, order)
      end
      refreshWindow()
    end,

    onResetIconPosition = function()
      local nextState = tableUtils.copyState(defaultCharacterState.icon)
      if accountState.settings and accountState.settings.shareWidgetPosition == true then
        accountState.sharedWidgetPosition = nextState
      else
        characterState.icon = nextState
      end

      return WindowCallbacks.ApplyIconPosition(getIcon(), nextState, uiParent)
    end,
  }
end

ns.BootstrapWindowRuntimeWindowCallbacks = WindowCallbacks

return WindowCallbacks
