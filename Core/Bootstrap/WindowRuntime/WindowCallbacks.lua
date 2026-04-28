local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")

local WindowCallbacks = {}

function WindowCallbacks.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local characterState = options.characterState or {}
  local defaultCharacterState = options.defaultCharacterState or {}
  local uiParent = options.uiParent
  local getIcon = options.getIcon or function()
    return nil
  end
  local tableUtils = options.tableUtils or TableUtils
  local groupSendPolicy = options.groupSendPolicy
  local sendHandler = options.sendHandler
  local refreshWindow = options.refreshWindow or function() end
  local selectConversation = options.selectConversation or function() end
  local startConversation = options.startConversation or function() end
  local setWindowVisible = options.setWindowVisible or function() end
  local trace = options.trace or function() end

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
        return groupSendPolicy.sendPayload(payload, trace)
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

      local icon = getIcon()
      if icon and icon.frame and icon.frame.SetPoint then
        local iconParent = icon.frame.parent or uiParent
        icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
      end

      return nextState
    end,
  }
end

ns.BootstrapWindowRuntimeWindowCallbacks = WindowCallbacks

return WindowCallbacks
