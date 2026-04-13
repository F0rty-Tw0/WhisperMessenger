local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoOpenHooks = ns.BootstrapAutoOpenHooks or require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local ConversationOps = ns.BootstrapAutoOpenConversationOps
    or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local EditBoxInterop = ns.BootstrapAutoOpenEditBoxInterop
    or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")

local AutoOpenCoordinator = {}

local function focusComposer(runtime)
  local window = runtime.window
  if window and window.composer and window.composer.input and window.composer.input.SetFocus then
    window.composer.input:SetFocus()
  end
end

local function shouldInterceptHook(runtime, deps)
  -- Explicit whisper actions (R / /r / /w / right-click whisper, or a typed
  -- draft in the default chat) route into the messenger regardless of the
  -- autoOpenOutgoing setting — that setting only gates POST-send auto-open.
  -- This is the user's whisper UI.
  if deps.isSuspended() then
    return false
  end

  -- If the messenger is in a "soft" lock (competitive content or encounter),
  -- don't intercept new whisper intents so the default Blizzard chat handles
  -- them instead. This ensures the user can always communicate even when
  -- the addon is paused.
  local isCompetitive = runtime.isCompetitiveContent and runtime.isCompetitiveContent()

  if isCompetitive then
    return false
  end

  if deps.isInCombat and deps.isInCombat() then
    -- Combat still blocks a cold-open of the messenger, but if it's already
    -- visible the user is actively using it — keep routing so typing doesn't
    -- land in the default chat instead.
    if isVisible then
      return true
    end
    return false
  end
  return true
end

local function installDirectHooks(runtime, hooks, deps)
  if type(_G.hooksecurefunc) ~= "function" then
    return
  end

  local function handleWhisperHook(nameArg)
    if not shouldInterceptHook(runtime, deps) then
      return
    end

    -- ChatFrame_SendTell(name, chatFrame) passes the target name directly —
    -- prefer it over reading the edit box attribute, which avoids timing and
    -- custom-chat-addon edge cases. ChatFrame_ReplyTell/ReplyTell2 take no
    -- args, so fall back to ChatEdit_GetActiveWindow (currently-open edit box,
    -- focus-independent) or findFocusedEditBox as a last resort.
    local target = (type(nameArg) == "string" and nameArg ~= "") and nameArg or nil

    local editBox
    if type(_G.ChatEdit_GetActiveWindow) == "function" then
      local ok, active = pcall(_G.ChatEdit_GetActiveWindow)
      if ok then
        editBox = active
      end
    end
    if not editBox then
      editBox = EditBoxInterop.findFocusedEditBox(deps)
    end

    local chatType
    if editBox then
      if deps.isInCombat and deps.isInCombat() then
        EditBoxInterop.markCombatDraft(editBox)
      end
      if EditBoxInterop.shouldPreserveCombatDraft(editBox) then
        return
      end
      chatType = EditBoxInterop.readEditBoxState(editBox, "chatType")
      if not target then
        target = EditBoxInterop.readEditBoxState(editBox, "tellTarget")
      end
    end

    if not target or target == "" then
      return
    end

    local opened = false
    if chatType == "BN_WHISPER" then
      pcall(function()
        local accountInfo = EditBoxInterop.findBattleNetAccountInfo(target, deps.bnetApi, deps.getNumFriends)
        if not accountInfo then
          return
        end
        local conversationKey = ConversationOps.ensureBattleNetConversation(runtime, deps.identity, accountInfo)
        if conversationKey and hooks.onOutgoingWhisper(conversationKey) then
          opened = true
        end
      end)
    else
      -- Default path: ChatFrame_SendTell / ReplyTell / ReplyTell2 all mean
      -- "WoW whisper to target". chatType may be nil here for ReplyTell before
      -- attributes propagate; treat as WHISPER.
      opened = hooks.onSendTell(target) == true
    end

    if opened and editBox then
      -- Defer editbox cleanup to next frame to avoid tainting secure chat
      -- frame state. Writing to editbox attributes during a hooksecurefunc
      -- callback can taint them, causing WoW to fail on subsequent calls.
      local timer = _G.C_Timer
      if type(timer) == "table" and type(timer.After) == "function" then
        timer.After(0, function()
          EditBoxInterop.closeEditBox(runtime, editBox, deps.deactivateChat)
        end)
      end
    end
  end

  local function safeHook(name)
    if type(_G[name]) == "function" then
      pcall(_G.hooksecurefunc, name, handleWhisperHook)
    end
  end

  safeHook("ChatFrame_SendTell")
  safeHook("ChatFrame_ReplyTell")
  safeHook("ChatFrame_ReplyTell2")

  if deps.trace then
    deps.trace("AutoOpen: direct whisper hooks installed")
  end
end

local function installPoller(runtime, hooks, deps)
  local createFrame = deps.createFrame
  if type(createFrame) ~= "function" then
    return nil
  end

  installDirectHooks(runtime, hooks, deps)

  local pollFrame = createFrame("Frame")
  pollFrame:SetScript("OnUpdate", function()
    local inCombat = deps.isInCombat and deps.isInCombat()
    if inCombat then
      local focused = EditBoxInterop.findFocusedEditBox(deps)
      if focused then
        EditBoxInterop.markCombatDraft(focused)
      end
    end
    if not shouldInterceptHook(runtime, deps) then
      return
    end

    for index = 1, deps.getNumChatWindows() do
      local editBox = deps.getEditBox(index)
      if editBox and editBox:HasFocus() then
        if EditBoxInterop.shouldPreserveCombatDraft(editBox) then
          return
        end

        local text = editBox.GetText and editBox:GetText() or ""
        if string.sub(text, 1, 1) == "/" then
          local command = string.lower(string.match(text, "^(/[^%s]*)") or "")
          if command ~= "/w" and command ~= "/whisper" then
            return
          end
        end

        EditBoxInterop.interceptEditBox(runtime, hooks, {
          identity = deps.identity,
          bnetApi = deps.bnetApi,
          getNumFriends = deps.getNumFriends,
          deactivateChat = deps.deactivateChat,
          ensureBattleNetConversation = ConversationOps.ensureBattleNetConversation,
        }, editBox)
        return
      end
    end
  end)

  if deps.trace then
    deps.trace("AutoOpen: edit box poll installed")
  end

  return pollFrame
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
    return installPoller(runtime, autoOpenHooks, {
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
