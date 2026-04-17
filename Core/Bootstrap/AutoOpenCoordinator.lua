local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoOpenHooks = ns.BootstrapAutoOpenHooks or require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local ConversationOps = ns.BootstrapAutoOpenConversationOps
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local Poller = ns.BootstrapAutoOpenPoller or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.Poller")

local AutoOpenCoordinator = {}

local function focusComposer(runtime)
  local window = runtime.window
  if window and window.composer and window.composer.input and window.composer.input.SetFocus then
    window.composer.input:SetFocus()
  end
end

function AutoOpenCoordinator.Attach(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountState = options.accountState or runtime.accountState or {}
  local windowRuntime = options.windowRuntime or {}
  local autoOpenHooksModule = options.AutoOpenHooks or AutoOpenHooks
  local identity = options.Identity or Identity
  local controller = {}

  local autoOpenHooks = autoOpenHooksModule.Create({
    trace = options.trace,
    getSettings = function()
      return accountState.settings
    end,
    isInCombat = options.isInCombat or function()
      return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
    end,
    isCompetitive = function()
      return runtime.isCompetitiveContent and runtime.isCompetitiveContent()
    end,
    ensureWindow = runtime.ensureWindow,
    setWindowVisible = runtime.setWindowVisible,
    selectConversation = windowRuntime.selectConversation,
    focusComposer = function()
      focusComposer(runtime)
    end,
    findConversationKeyByName = function(name)
      return ConversationOps.findConversationKeyByName(runtime, name)
    end,
    buildConversationKeyFromName = function(name)
      return ConversationOps.buildConversationKeyFromName(runtime, identity, name)
    end,
    ensureConversation = function(conversationKey, displayName)
      return ConversationOps.ensureConversation(runtime, conversationKey, displayName)
    end,
    getLastReplyKey = function()
      return runtime.lastIncomingWhisperKey
    end,
    isWindowVisible = function()
      return windowRuntime.isWindowVisible and windowRuntime.isWindowVisible() or false
    end,
    getActiveConversationKey = function()
      return runtime.activeConversationKey
    end,
  })

  runtime.onAutoOpen = autoOpenHooks.onIncomingWhisper
  runtime.onAutoOpenOutgoing = autoOpenHooks.onOutgoingWhisper
  runtime.autoOpenHooks = autoOpenHooks

  function controller.installPoller()
    return Poller.Install(runtime, autoOpenHooks, {
      trace = options.trace,
      identity = identity,
      createFrame = options.CreateFrame or _G.CreateFrame,
      isSuspended = options.isSuspended or function()
        return _G._wmSuspended == true
      end,
      isInCombat = options.isInCombat or function()
        return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
      end,
      isWindowVisible = options.isWindowVisible or function()
        return windowRuntime.isWindowVisible and windowRuntime.isWindowVisible() or false
      end,
      getNumChatWindows = options.getNumChatWindows or function()
        return _G.NUM_CHAT_WINDOWS or 10
      end,
      getEditBox = options.getEditBox or function(index)
        return _G["ChatFrame" .. index .. "EditBox"]
      end,
      bnetApi = options.bnetApi or _G.C_BattleNet,
      getNumFriends = options.BNGetNumFriends
        or (
          type(_G.BNGetNumFriends) == "function" and _G.BNGetNumFriends
          or function()
            return 0, 0
          end
        ),
      deactivateChat = options.ChatEdit_DeactivateChat or _G.ChatEdit_DeactivateChat,
    })
  end

  function controller.installDeferredPoller()
    local timer = options.C_Timer or _G.C_Timer
    if not runtime.autoOpenHooks or type(timer) ~= "table" or type(timer.After) ~= "function" then
      return
    end

    timer.After(0, function()
      controller.installPoller()
    end)
  end

  runtime.autoOpenCoordinator = controller

  return controller
end

ns.BootstrapAutoOpenCoordinator = AutoOpenCoordinator
return AutoOpenCoordinator
