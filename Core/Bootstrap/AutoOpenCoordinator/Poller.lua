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

local function processEditBox(runtime, hooks, deps, interceptDeps, editBox)
  -- HARD BAIL before any Blizzard state read. During M+/encounters/PvP,
  -- any read of a chat edit box attribute can propagate secret-string
  -- taint into the current callback and cross-pollute Blizzard calls.
  if deps.isSuspended() then
    return
  end
  if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
    return
  end

  local inCombat = deps.isInCombat and deps.isInCombat()
  if inCombat then
    EditBoxInterop.markCombatDraft(editBox)
  end
  if not DirectHooks.shouldInterceptHook(runtime, deps) then
    return
  end
  if EditBoxInterop.shouldPreserveCombatDraft(editBox) then
    return
  end

  -- GetText and string comparisons may also return tainted values during
  -- lockdown. If text cannot be read safely, do not trust potentially stale
  -- edit-box attributes for auto-open routing.
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

  EditBoxInterop.interceptEditBox(runtime, hooks, interceptDeps, editBox)
end

function Poller.Install(runtime, hooks, deps)
  DirectHooks.Install(runtime, hooks, deps)

  local interceptDeps = {
    identity = deps.identity,
    bnetApi = deps.bnetApi,
    getNumFriends = deps.getNumFriends,
    deactivateChat = deps.deactivateChat,
    ensureBattleNetConversation = ConversationOps.ensureBattleNetConversation,
  }

  local function handleEditBox(editBox)
    processEditBox(runtime, hooks, deps, interceptDeps, editBox)
  end

  local function handleTextChanged(editBox, userInput)
    if userInput ~= true then
      return
    end

    handleEditBox(editBox)
  end

  for index = 1, deps.getNumChatWindows() do
    local editBox = deps.getEditBox(index)
    if editBox and type(editBox.HookScript) == "function" then
      editBox:HookScript("OnEditFocusGained", handleEditBox)
      editBox:HookScript("OnTextChanged", handleTextChanged)
    end
  end

  local function handleTellLauncher()
    local timer = _G.C_Timer
    if type(timer) ~= "table" or type(timer.After) ~= "function" then
      return
    end

    timer.After(0, function()
      -- This callback may run after restricted content begins. Bail before
      -- finding the focused edit box, which reads Blizzard edit-box state.
      if deps.isSuspended() then
        return
      end
      if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
        return
      end

      local editBox = EditBoxInterop.findFocusedEditBox(deps)
      if editBox then
        handleEditBox(editBox)
      end
    end)
  end

  local chatFrameUtil = _G.ChatFrameUtil
  if type(_G.hooksecurefunc) == "function" and type(chatFrameUtil) == "table" and type(chatFrameUtil.SendTellWithMessage) == "function" then
    pcall(_G.hooksecurefunc, chatFrameUtil, "SendTellWithMessage", handleTellLauncher)
  end

  if type(_G.hooksecurefunc) == "function" and type(chatFrameUtil) == "table" and type(chatFrameUtil.SendBNetTell) == "function" then
    pcall(_G.hooksecurefunc, chatFrameUtil, "SendBNetTell", handleTellLauncher)
  elseif type(_G.hooksecurefunc) == "function" and type(_G.ChatFrame_SendBNetTell) == "function" then
    pcall(_G.hooksecurefunc, "ChatFrame_SendBNetTell", handleTellLauncher)
  end

end

ns.BootstrapAutoOpenPoller = Poller
return Poller
