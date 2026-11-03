local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local PreviewOpen = ns.BootstrapWindowRuntimePreviewOpen or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewOpen")
local ToastStack = ns.WhisperToastsToastStack or require("WhisperMessenger.UI.WhisperToasts.ToastStack")

-- Pop-up cards for whispers that alert (the caller already applied mute and
-- the Requests inbox). Only while the messenger is closed and nothing blocks
-- opening it: combat, a chat lock or restricted content. Opening the window
-- clears them.
local WhisperToasts = {}

function WhisperToasts.Create(options)
  local runtime = options.runtime
  local accountState = options.accountState
  local selectConversation = options.selectConversation
  local stack = nil

  local function getStack()
    stack = stack
      or ToastStack.Create(options.uiFactory, options.uiParent, {
        onOpen = function(conversationKey)
          PreviewOpen.OpenConversation(runtime, selectConversation, conversationKey)
        end,
      })
    return stack
  end

  local function allowed()
    local settings = accountState.settings
    if type(settings) ~= "table" or settings.showWhisperToasts ~= true then
      return false
    end
    return not runtime.isWindowVisible() and not Guards.IsRefused(runtime)
  end

  local toasts = {}

  function toasts.show(conversationKey)
    if not allowed() then
      return
    end
    local conversation = runtime.store and runtime.store.conversations and runtime.store.conversations[conversationKey]
    local messageText = conversation and conversation.lastIncomingPreview
    if type(messageText) ~= "string" or messageText == "" then
      return
    end
    getStack().show({
      conversationKey = conversationKey,
      senderName = DisplayName.Format(conversation.lastIncomingSender or conversation.displayName),
      messageText = messageText,
      classTag = conversation.classTag,
    }, accountState.settings.whisperToastCorner)
  end

  function toasts.clear()
    if stack then
      stack.clear()
    end
  end

  return toasts
end

ns.BootstrapWindowRuntimeWhisperToasts = WhisperToasts
return WhisperToasts
