local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")

local FirstRunTip = {}

local TIP_TEXT_KEY = "your whispers now open in the messenger window. Click the chat icon or type /wmsg."

-- An account with any saved conversation or a recorded patchNotesSeenVersion
-- is an upgrade, not a fresh install -- gets the flag set silently.
function FirstRunTip.Announce(accountState, options)
  options = options or {}
  if accountState == nil or accountState.settings == nil then
    return
  end
  if accountState.settings.firstRunTipShown ~= nil then
    return
  end

  local isExistingUser = next(accountState.conversations or {}) ~= nil or accountState.settings.patchNotesSeenVersion ~= nil

  if not isExistingUser then
    local localization = ns.Localization
    local text = (localization and localization.Text and localization.Text(TIP_TEXT_KEY)) or TIP_TEXT_KEY
    ChatPrint.Print(text, options.frame)
  end

  accountState.settings.firstRunTipShown = true
end

ns.BootstrapFirstRunTip = FirstRunTip

return FirstRunTip
