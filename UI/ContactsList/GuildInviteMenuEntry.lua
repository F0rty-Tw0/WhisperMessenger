local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatPrefill = ns.ChatPrefill or require("WhisperMessenger.Util.ChatPrefill")
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
-- guildmate, and not seen in another guild this session. Clicking it opens the
-- chat box prefilled with "/ginvite <name>" for the player to send: addon code
-- may not call the protected invite API. When prefilling would taint the
-- game's slash commands (see ChatPrefill.IsSafe), the click shows the command
-- in the copy dialog for the player to paste into chat instead.
local GuildInviteMenuEntry = {}

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

-- Same-realm names drop the realm, as the game's own name display does.
local function inviteCommand(name)
  local command = "/ginvite " .. Identity.ShortName(name)
  if ChatPrefill.IsSafe(command) then
    ChatPrefill.Open(command)
    return
  end
  PopupUI.ShowManualCopyDialog(command, { prompt = COMMAND_PROMPT })
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
  if ChatPrefill.Resolve() == nil then
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
