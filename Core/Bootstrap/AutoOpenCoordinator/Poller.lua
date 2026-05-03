local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local DirectHooks = ns.BootstrapAutoOpenDirectHooks or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.DirectHooks")
local ConversationOps = ns.BootstrapAutoOpenConversationOps or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local EditBoxInterop = ns.BootstrapAutoOpenEditBoxInterop or require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.EditBoxInterop")
-- stylua: ignore end

local Poller = {}

local WHISPER_SLASH_COMMANDS = {
  w = true,
  whisper = true,
  t = true,
  tell = true,
}

local function parseSlashCommandText(text)
  if type(text) ~= "string" or string.match(text, "^%s*/") == nil then
    return false, nil, nil
  end

  -- Require whitespace after the target name; otherwise the pattern matches
  -- mid-typing `/w S` and routes the half-typed name on the first keystroke.
  local command, target, body = string.match(text, "^%s*/([^%s]+)%s+([^%s]+)%s+(.-)%s*$")
  if command == nil then
    return true, nil, nil
  end

  command = string.lower(command)
  if not WHISPER_SLASH_COMMANDS[command] then
    return true, nil, nil
  end

  return true, target, body or ""
end

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
      -- during lockdown. If text cannot be read safely, do not trust
      -- potentially stale edit-box attributes for auto-open routing.
      local slashCommandSeen = false
      local slashWhisperTarget = nil
      local slashWhisperBody = nil
      local textReadable = pcall(function()
        local text = editBox.GetText and editBox:GetText() or ""
        slashCommandSeen, slashWhisperTarget, slashWhisperBody = parseSlashCommandText(text)
      end)
      if not textReadable then
        return
      end
      if slashWhisperTarget ~= nil and slashWhisperTarget ~= "" then
        if hooks.onSendTell(slashWhisperTarget) then
          EditBoxInterop.closeEditBox(runtime, editBox, deps.deactivateChat, slashWhisperBody or "")
        end
        return
      end
      if slashCommandSeen then
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
