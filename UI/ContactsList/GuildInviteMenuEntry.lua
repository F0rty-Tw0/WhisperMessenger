local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local SeenGuild = ns.SeenGuild or require("WhisperMessenger.Model.SeenGuild")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity.Identity")
-- stylua: ignore start
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
-- stylua: ignore end

-- A whisper row's "Guild invite" entry. WoW whisper rows only, and shown only
-- when you are in a guild with invite rights and the player is not you, not a
-- guildmate, and not seen in another guild this session. Clicking it shows
-- "/ginvite <name>" in the copy dialog for the player to paste into chat:
-- addon code may not call the protected invite API, and the game also blocks
-- the invite when the player presses Enter on a chat box the addon filled
-- (seen in game), so the click never touches the game's chat box.
local GuildInviteMenuEntry = {}

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

-- Same-realm names drop the realm, as the game's own name display does. WoW:
-- Forever tags names with a realm, yet /ginvite finds the player only by the
-- bare name there (seen in game), so the realm always goes.
local function inviteName(name)
  if FlavorCompat.isForever then
    return string.match(name, "^(.+)%-[^%-]+$") or name
  end
  return Identity.ShortName(name)
end

local function inviteCommand(name)
  PopupUI.ShowManualCopyDialog("/ginvite " .. inviteName(name), { prompt = COMMAND_PROMPT })
end

-- A missing, throwing or secret check answers "no".
local function callAllows(fn)
  if type(fn) ~= "function" then
    return false
  end
  local ok, result = pcall(fn)

  return ok and not SecretValue.Is(result) and not not result
end

-- A missing, throwing or secret check answers "not a member".
local function isGuildMember(api, name)
  if type(api) ~= "table" or type(api.MemberExistsByName) ~= "function" then
    return false
  end
  local ok, member = pcall(api.MemberExistsByName, name)

  return ok and not SecretValue.Is(member) and member == true
end

function GuildInviteMenuEntry.Add(rootDescription, item)
  if type(_G.StaticPopup_Show) ~= "function" then
    return
  end
  if item.channel ~= "WOW" or item.displayName == nil then
    return
  end
  local name = IgnoreList.CharacterName(item.displayName, item.guid)
  if SecretValue.Is(name) or not callAllows(_G.IsInGuild) or not callAllows(_G.CanGuildInvite) then
    return
  end
  if LocalPlayer.IsSelf(name, item.guid) or isGuildMember(_G.C_GuildInfo, name) then
    return
  end
  local seenGuild = SeenGuild.Get(name)
  if seenGuild ~= nil and seenGuild ~= "" then
    return
  end
  rootDescription:CreateButton(Localization.Text("Guild invite"), function()
    inviteCommand(name)
  end)
end

ns.ContactsListGuildInviteMenuEntry = GuildInviteMenuEntry
return GuildInviteMenuEntry
