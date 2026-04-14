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
  local isVisible = deps.isWindowVisible and deps.isWindowVisible() or false

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
    -- custom-chat-addon edge cases.
    --
    -- ChatFrame_ReplyTell/ReplyTell2 do not carry an explicit target. For those
    -- hooks we must prefer the tracked `lastIncomingWhisperKey`; falling back to
    -- editBox.tellTarget can reintroduce ambiguous name-based routing.
    local isReplyHook = type(nameArg) ~= "string" or nameArg == ""
    local target = (not isReplyHook) and nameArg or nil

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
      if not isReplyHook and not target then
        target = EditBoxInterop.readEditBoxState(editBox, "tellTarget")
      end
    end

    local opened = false
    if isReplyHook then
      if type(hooks.onReplyTell) == "function" then
        opened = hooks.onReplyTell() == true
      else
        return
      end
    elseif not target or target == "" then
      return
    elseif chatType == "BN_WHISPER" then
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
      -- Default path: ChatFrame_SendTell and resolved whisper targets route by name.
      opened = hooks.onSendTell(target) == true
    end

    if opened and editBox then
      -- Defer editbox cleanup to next frame to avoid tainting secure chat
      -- frame state. Writing to editbox attributes during a hooksecurefunc
      -- callback can taint them, causing WoW to fail on subsequent calls.
      local timer = _G.C_Timer
      if type(timer) == "table" and type(timer.After) == "function" then
        timer.After(0, function()
          -- Re-check at fire time: ENCOUNTER_START may have activated between
          -- schedule and dispatch. Any edit-box cleanup now runs inside
          -- lockdown and taints Blizzard's secure reply path.
          if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
            return
          end
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

  -- Only hook explicit whisper actions (/w target, right-click-Whisper).
  -- We intentionally do NOT hook ChatFrame_ReplyTell / ChatFrame_ReplyTell2:
  -- when Blizzard's `chatEditLastTell` holds a secret-string sender captured
  -- during M+, Blizzard's body errors before our hook suffix fires, and
  -- WoW's taint system attributes the crash to us for simply having the
  -- hook attached. Users should use `/wr` (or a macro-bound key) to reply
  -- after whispers received in restricted content.
  safeHook("ChatFrame_SendTell")

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
    -- HARD BAIL before any Blizzard state read. During M+/encounters/PvP,
    -- any read of a chat edit box attribute can propagate secret-string
    -- taint into our OnUpdate context and cross-pollute the next Blizzard
    -- call in the same frame.
    if deps.isSuspended() then
      return
    end
    if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
      return
    end

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

    local editBox = EditBoxInterop.findFocusedEditBox(deps)
    if editBox then
      if EditBoxInterop.shouldPreserveCombatDraft(editBox) then
        return
      end

      -- GetText and string comparisons may also return tainted values
      -- during lockdown; wrap the slash-command guard in pcall so a taint
      -- error skips the guard rather than crashing the poller.
      local isNonWhisperSlash = false
      pcall(function()
        local text = editBox.GetText and editBox:GetText() or ""
        if string.sub(text, 1, 1) == "/" then
          local command = string.lower(string.match(text, "^(/[^%s]*)") or "")
          if command ~= "/w" and command ~= "/whisper" then
            isNonWhisperSlash = true
          end
        end
      end)
      if isNonWhisperSlash then
        return
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
