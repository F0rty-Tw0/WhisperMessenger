local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local ReactionHandler = ns.BootstrapReactionHandler or require("WhisperMessenger.Core.Bootstrap.ReactionHandler")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")

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
  local livePresenceSender = options.livePresenceSender
  local refreshWindow = options.refreshWindow or function() end
  local selectConversation = options.selectConversation or function() end
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
      return sendHandler.HandleSend(runtime, payload, refreshWindow)
    end,
    onReact = function(selectedContact, message, reactionKey)
      return reactionHandler.HandleReact(runtime, selectedContact, message, reactionKey, refreshWindow, groupSendPolicy)
    end,
    canReact = canReact,
    onTyping = function(selectedContact, text)
      if livePresenceSender == nil then
        return false
      end
      return livePresenceSender.OnComposerText(runtime, selectedContact, text)
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

    onRemove = function(item)
      local key = item.conversationKey
      MessageReactions.ClearConversation(runtime, key)
      Store.Remove(runtime.store, key)
      if runtime.activeConversationKey == key then
        runtime.activeConversationKey = nil
        characterState.activeConversationKey = nil
      end
      refreshWindow()
    end,

    onMarkUnread = function(item)
      local key = item and item.conversationKey
      if key == nil then
        return
      end
      Store.MarkUnread(runtime.store, key)
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
