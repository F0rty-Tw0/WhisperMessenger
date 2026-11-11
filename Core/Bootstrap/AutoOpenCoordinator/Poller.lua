local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local ChatPrefill = ns.ChatPrefill or require("WhisperMessenger.Util.ChatPrefill")
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

local REPLY_SLASH_COMMANDS = {
  r = true,
  reply = true,
}

-- Command, then whitespace, then the (maybe empty) message. "/r" alone may
-- still be the start of "/raid", so the space is required.
local SLASH_REPLY = "^%s*/([^%s]+)%s+(.-)%s*$"

local SLASH_WHISPER_ONE_PART_NAME = "^%s*/([^%s]+)%s+([^%s]+)%s+(.-)%s*$"
local SLASH_WHISPER_TWO_PART_NAME = "^%s*/([^%s]+)%s+([^%s]+%s+[^%s]+)%s+(.-)%s*$"
local SLASH_WHISPER_BATTLETAG_TARGET = "^%s*/[^%s]+%s+[^%s]*#"

local function parseSlashCommandText(text)
  if type(text) ~= "string" or string.match(text, "^%s*/") == nil then
    return false, nil, nil
  end

  -- Require whitespace after the target name; otherwise the pattern matches
  -- mid-typing `/w S` and routes the half-typed name on the first keystroke.
  -- WoW: Forever names are two words ("John Doe"), so the target spans both.
  -- A BattleTag ("Name#1234") is still one word there.
  local pattern = SLASH_WHISPER_ONE_PART_NAME
  if FlavorCompat.isForever and string.match(text, SLASH_WHISPER_BATTLETAG_TARGET) == nil then
    pattern = SLASH_WHISPER_TWO_PART_NAME
  end
  local command, target, body = string.match(text, pattern)
  if command == nil then
    return true, nil, nil
  end

  command = string.lower(command)
  if not WHISPER_SLASH_COMMANDS[command] then
    return true, nil, nil
  end

  -- "John  Doe" must key the same chat as "John Doe".
  target = string.gsub(target, "%s+", " ")
  return true, target, body or ""
end

-- Blizzard's localized /r spellings live in SLASH_REPLY1..N.
local function isReplyCommand(command)
  if REPLY_SLASH_COMMANDS[command] then
    return true
  end
  local index = 1
  local slash = _G["SLASH_REPLY" .. index]
  while type(slash) == "string" do
    if string.lower(slash) == "/" .. command then
      return true
    end
    index = index + 1
    slash = _G["SLASH_REPLY" .. index]
  end
  return false
end

-- Returns the message typed after /r, or nil when the text is not a reply.
local function parseSlashReplyText(text)
  if type(text) ~= "string" then
    return nil
  end
  local command, body = string.match(text, SLASH_REPLY)
  if command == nil or not isReplyCommand(string.lower(command)) then
    return nil
  end
  return body
end

-- inKeyPress: the player's own typing, so the quiet /who may go out.
local function processEditBox(runtime, hooks, deps, interceptDeps, editBox, inKeyPress)
  -- HARD BAIL before any Blizzard state read. During M+/encounters/PvP,
  -- any read of a chat edit box attribute can propagate secret-string
  -- taint into the current callback and cross-pollute Blizzard calls.
  if deps.isSuspended() then
    return
  end
  if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
    return
  end
  -- Our own prefill (Guild invite) is opening this box: not a whisper intent.
  if ChatPrefill.IsOpening() then
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
  local slashReplyBody = nil
  local textReadable = pcall(function()
    local text = editBox.GetText and editBox:GetText() or ""
    slashCommandSeen, slashWhisperTarget, slashWhisperBody = parseSlashCommandText(text)
    slashReplyBody = parseSlashReplyText(text)
  end)
  if not textReadable then
    return
  end
  -- Reply goes to our tracked last whisper, never Blizzard's last-tell
  -- state, which can hold a secret name after restricted content.
  if slashReplyBody ~= nil then
    if type(hooks.onReplyTell) == "function" and hooks.onReplyTell() == true then
      EditBoxInterop.closeEditBox(runtime, editBox, deps.deactivateChat, slashReplyBody)
    end
    return
  end
  if slashWhisperTarget ~= nil and slashWhisperTarget ~= "" then
    if hooks.onSendTell(slashWhisperTarget, inKeyPress == true) then
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

    processEditBox(runtime, hooks, deps, interceptDeps, editBox, true)
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

  -- Right-click Whisper: the chat opens a frame later, outside the click, so
  -- the quiet /who goes out here, inside it. Bail checks come before the name.
  local function handleSendTell(name)
    if DirectHooks.shouldInterceptHook(runtime, deps) and type(hooks.askWhoForTell) == "function" then
      pcall(function()
        if type(name) == "string" and name ~= "" then
          hooks.askWhoForTell(name)
        end
      end)
    end
    handleTellLauncher()
  end

  local chatFrameUtil = _G.ChatFrameUtil
  if type(_G.hooksecurefunc) == "function" and type(chatFrameUtil) == "table" and type(chatFrameUtil.SendTellWithMessage) == "function" then
    pcall(_G.hooksecurefunc, chatFrameUtil, "SendTellWithMessage", handleSendTell)
  end

  if type(_G.hooksecurefunc) == "function" and type(chatFrameUtil) == "table" and type(chatFrameUtil.SendBNetTell) == "function" then
    pcall(_G.hooksecurefunc, chatFrameUtil, "SendBNetTell", handleTellLauncher)
  elseif type(_G.hooksecurefunc) == "function" and type(_G.ChatFrame_SendBNetTell) == "function" then
    pcall(_G.hooksecurefunc, "ChatFrame_SendBNetTell", handleTellLauncher)
  end
end

ns.BootstrapAutoOpenPoller = Poller
return Poller
