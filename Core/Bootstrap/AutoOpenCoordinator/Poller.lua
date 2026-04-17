local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local DirectHooks = ns.BootstrapAutoOpenDirectHooks
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.DirectHooks")
local ConversationOps = ns.BootstrapAutoOpenConversationOps
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local EditBoxInterop = ns.BootstrapAutoOpenEditBoxInterop
  or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")

local Poller = {}

function Poller.Install(runtime, hooks, deps)
  local createFrame = deps.createFrame
  if type(createFrame) ~= "function" then
    return nil
  end

  DirectHooks.Install(runtime, hooks, deps)

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
    if not DirectHooks.shouldInterceptHook(runtime, deps) then
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

ns.BootstrapAutoOpenPoller = Poller
return Poller
