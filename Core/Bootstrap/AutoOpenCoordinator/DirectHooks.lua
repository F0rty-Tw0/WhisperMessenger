local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationOps = ns.BootstrapAutoOpenConversationOps
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local EditBoxInterop = ns.BootstrapAutoOpenEditBoxInterop
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")

local DirectHooks = {}

-- Shared predicate used by both DirectHooks and Poller.
-- Explicit whisper actions (/w, right-click whisper, or a typed whisper draft in
-- the default chat) still flow through this intercept path. AutoOpenHooks then
-- decides whether that action should open the messenger based on settings and
-- current window visibility.
function DirectHooks.shouldInterceptHook(runtime, deps)
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

function DirectHooks.Install(runtime, hooks, deps)
  if type(_G.hooksecurefunc) ~= "function" then
    return
  end

  local function handleWhisperHook(nameArg)
    if not DirectHooks.shouldInterceptHook(runtime, deps) then
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

ns.BootstrapAutoOpenDirectHooks = DirectHooks
return DirectHooks
