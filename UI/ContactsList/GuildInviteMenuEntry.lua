local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local SeenGuild = ns.SeenGuild or require("WhisperMessenger.Model.SeenGuild")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- A whisper row's "Guild invite" entry. WoW whisper rows only, and shown only
-- when you are in a guild with invite rights and the player is not you, not a
-- guildmate, and not seen in another guild this session. Clicking it opens the
-- chat box prefilled with "/ginvite <name>" for the player to send: addon code
-- may not call the protected invite API.
local GuildInviteMenuEntry = {}

-- Current Retail has ChatFrameUtil.OpenChat; older clients and the Classic
-- flavors have the ChatFrame_OpenChat global. Neither → nil.
local function resolveOpenChat()
  local util = _G.ChatFrameUtil
  if type(util) == "table" and type(util.OpenChat) == "function" then
    return util.OpenChat
  end
  if type(_G.ChatFrame_OpenChat) == "function" then
    return _G.ChatFrame_OpenChat
  end

  return nil
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
  if resolveOpenChat() == nil then
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
    local openChat = resolveOpenChat()
    if openChat ~= nil then
      openChat("/ginvite " .. name)
    end
  end)
end

ns.ContactsListGuildInviteMenuEntry = GuildInviteMenuEntry
return GuildInviteMenuEntry
