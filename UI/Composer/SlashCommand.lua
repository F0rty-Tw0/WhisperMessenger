local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Composer text that starts with "/" is a game command, not a whisper. It runs
-- through the default chat box's own Enter handler, exactly as if the player
-- had typed it there: Blizzard parses it, runs the slash command or emote,
-- updates the sticky chat type and clears the box. The edit box is passed to
-- the handler explicitly, so the text is read from and cleared on that box.
-- A protected command (/use, /target, /cast, ...) is the exception: run from
-- addon code the game blocks it (ADDON_ACTION_FORBIDDEN). Prefilling the chat
-- box from addon code does not help either: the player's Enter on that box is
-- still blocked (seen in game). So it goes to the copy dialog for the player
-- to paste into chat.
local ChatPrefill = ns.ChatPrefill or require("WhisperMessenger.Util.ChatPrefill")
-- stylua: ignore start
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
-- stylua: ignore end

local SlashCommand = {}

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

-- The command with leading spaces dropped, or nil when text is not a command.
function SlashCommand.Parse(text)
  if type(text) ~= "string" then
    return nil
  end
  return string.match(text, "^%s*(/.*)$")
end

local function resolveEnterHandler()
  local chatFrame = _G.DEFAULT_CHAT_FRAME
  local editBox = type(chatFrame) == "table" and chatFrame.editBox or nil
  if editBox == nil or type(editBox.SetText) ~= "function" or type(editBox.GetScript) ~= "function" then
    return nil, nil
  end
  local handler = editBox:GetScript("OnEnterPressed")
  if type(handler) ~= "function" then
    return nil, nil
  end
  return editBox, handler
end

-- Chat lockdown or competitive content: writing Blizzard's edit box from addon
-- code then taints its reply state until /reload, so the command must not run.
-- Looked up at call time: RestrictedActions loads later in the TOC.
local function isRestricted()
  local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
  local restrictions = RestrictedActions.New()
  return restrictions.isChatLocked() or restrictions.isCompetitive()
end

-- Runs the command, or shows a protected one in the copy dialog; false when
-- the game's chat box or the copy dialog is unavailable, or chat is restricted.
function SlashCommand.Run(command)
  if isRestricted() then
    return false
  end
  if ChatPrefill.IsProtectedCommand(command) then
    return PopupUI.ShowManualCopyDialog(command, { prompt = COMMAND_PROMPT }) == true
  end
  local editBox, handler = resolveEnterHandler()
  if editBox == nil or handler == nil then
    return false
  end
  editBox:SetText(command)
  handler(editBox)
  return true
end

ns.ComposerSlashCommand = SlashCommand
return SlashCommand
