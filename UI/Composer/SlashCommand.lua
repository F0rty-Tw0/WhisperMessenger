local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Composer text that starts with "/" is a game command, not a whisper. It runs
-- through the default chat box's own Enter handler, exactly as if the player
-- had typed it there: Blizzard parses it, runs the slash command or emote,
-- updates the sticky chat type and clears the box. The edit box is passed to
-- the handler explicitly, so the text is read from and cleared on that box.
local SlashCommand = {}

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

-- Runs the command; false when the game's chat box is unavailable or restricted.
function SlashCommand.Run(command)
  if isRestricted() then
    return false
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
