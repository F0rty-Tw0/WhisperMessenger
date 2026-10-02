local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")

local FirstRunTip = {}

local TIP_TEXT_KEY = "your whispers now open in the messenger window. Click the chat icon or type /wmsg."

-- An account with any saved conversation or a recorded patchNotesSeenVersion
-- is an upgrade, not a fresh install -- gets the flag set silently.
local function isExistingUser(accountState)
  return next(accountState.conversations or {}) ~= nil or accountState.settings.patchNotesSeenVersion ~= nil
end

-- True only on the very first boot of a brand-new install. Call it before
-- Announce, which marks the account as booted.
function FirstRunTip.IsFreshInstall(accountState)
  if accountState == nil or accountState.settings == nil or accountState.settings.firstRunTipShown ~= nil then
    return false
  end
  return not isExistingUser(accountState)
end

function FirstRunTip.Announce(accountState, options)
  options = options or {}
  if accountState == nil or accountState.settings == nil then
    return
  end
  if accountState.settings.firstRunTipShown ~= nil then
    return
  end

  if not isExistingUser(accountState) then
    local localization = ns.Localization
    local text = (localization and localization.Text and localization.Text(TIP_TEXT_KEY)) or TIP_TEXT_KEY
    ChatPrint.Print(text, options.frame)
  end

  accountState.settings.firstRunTipShown = true
end

ns.BootstrapFirstRunTip = FirstRunTip

return FirstRunTip
