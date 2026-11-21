local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ConversationExport = ns.ConversationExport or require("WhisperMessenger.Model.ConversationExport")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
local ZoneWatch = ns.ZoneWatch or require("WhisperMessenger.Model.ZoneWatch")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local IgnorePrompt = ns.IgnorePrompt or require("WhisperMessenger.UI.Shared.IgnorePrompt")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local ProfileCharacter = ns.ProfileCharacter or require("WhisperMessenger.Model.ProfileCharacter")
local ProfileLinks = ns.ProfileLinks or require("WhisperMessenger.Model.ProfileLinks")
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")

-- The contact menu's own entries, in the order the menu shows them. Each is
-- a table with Add(rootDescription, ...), which adds nothing when the entry
-- does not apply to the row.

-- "Export conversation": the conversation as plain text in the export
-- panel. Any row whose item carries its conversation: whispers, Battle.net,
-- groups and channels.
local ExportMenuEntry = {}

function ExportMenuEntry.Open(item)
  -- The panel loads after the contacts menu (it needs the settings
  -- controls), so it is looked up on click.
  local ExportPanel = ns.ContactsListExportPanel or require("WhisperMessenger.UI.ContactsList.ExportPanel")
  local contactName = DisplayName.Format(item.displayName)
  local names = { contactName = contactName, playerName = LocalPlayer.Name() }
  return ExportPanel.Show({
    title = contactName,
    header = ConversationExport.Header(names),
    lines = ConversationExport.Lines(item.conversation.messages, names),
  })
end

function ExportMenuEntry.Add(rootDescription, item)
  local conversation = item.conversation
  if type(conversation) ~= "table" or type(conversation.messages) ~= "table" then
    return
  end
  rootDescription:CreateButton(Localization.Text("Export conversation"), function()
    ExportMenuEntry.Open(item)
  end)
end

-- "Notify when online" and "Notify when they change zone" in the whisper-row
-- menu: checkboxes (plain buttons on clients without one), each shown only
-- where WoW reports what it watches.
local NotifyMenuEntries = {}

local function addCheckbox(rootDescription, label, initial, onToggle)
  -- item is a snapshot that the save doesn't update, and the menu stays open
  -- after a checkbox click, so track the ticked state here.
  local enabled = initial
  local function toggle()
    enabled = not enabled
    onToggle(enabled)
  end
  if type(rootDescription.CreateCheckbox) == "function" then
    rootDescription:CreateCheckbox(label, function()
      return enabled
    end, toggle)
  else
    rootDescription:CreateButton(label, toggle)
  end
end

function NotifyMenuEntries.Add(rootDescription, item, onUpdatePrefs)
  if OnlineWatch.CanWatch(item, _G.C_FriendList) then
    addCheckbox(rootDescription, Localization.Text("Notify when online"), item.notifyOnline == true, function(enabled)
      onUpdatePrefs(item, { notifyOnline = enabled })
    end)
  end
  if ZoneWatch.CanWatch(item) then
    addCheckbox(rootDescription, Localization.Text("Notify when they change zone"), item.notifyZone == true, function(enabled)
      onUpdatePrefs(item, { notifyZone = enabled })
    end)
  end
end

-- A whisper row's "Add friend" entry. WoW whisper rows only, and hidden when
-- the player is already a friend, is you, the client can't add friends, or a
-- chat lock made the name secret (comparing it would throw).
local AddFriendMenuEntry = {}

-- C_FriendList.AddFriend on every current flavor; the old global otherwise.
local function addFriendFunction()
  local api = _G.C_FriendList
  if type(api) == "table" and type(api.AddFriend) == "function" then
    return api.AddFriend
  end
  if type(_G.AddFriend) == "function" then
    return _G.AddFriend
  end
  return nil
end

-- Without C_FriendList the friends list can't be read; the game itself
-- answers "already your friend" then.
local function isFriend(item, name)
  local api = _G.C_FriendList
  if type(api) ~= "table" then
    return false
  end
  if item.guid ~= nil and type(api.IsFriend) == "function" then
    local ok, friend = pcall(api.IsFriend, item.guid)
    if ok and not SecretValue.Is(friend) and friend == true then
      return true
    end
  end
  return OnlineWatch.IsCharacterFriend(api, name)
end

function AddFriendMenuEntry.Add(rootDescription, item)
  local addFriend = addFriendFunction()
  if addFriend == nil or item.channel ~= "WOW" or item.displayName == nil then
    return
  end
  local name = IgnoreList.CharacterName(item.displayName, item.guid)
  if SecretValue.Is(name) or LocalPlayer.IsSelf(name, item.guid) or isFriend(item, name) then
    return
  end
  rootDescription:CreateButton(Localization.Text("Add friend"), function()
    addFriend(name)
  end)
end

-- A whisper row's "Block…" entry, or "Unblock" when the player is already
-- blocked. WoW whisper rows only: Battle.net friends and groups aren't one
-- character. rowActions: onIgnorePlayer(name, reason), and optionally
-- isPlayerBlocked(name) and onUnblockPlayer(name).
local BlockMenuEntry = {}

local function isBlocked(rowActions, name)
  return type(rowActions.isPlayerBlocked) == "function"
    and type(rowActions.onUnblockPlayer) == "function"
    and rowActions.isPlayerBlocked(name) == true
end

function BlockMenuEntry.Add(rootDescription, item, rowActions)
  local onIgnorePlayer = type(rowActions) == "table" and rowActions.onIgnorePlayer
  if type(onIgnorePlayer) ~= "function" or item.channel ~= "WOW" or item.displayName == nil then
    return
  end
  local name = IgnoreList.CharacterName(item.displayName, item.guid)
  if isBlocked(rowActions, name) then
    rootDescription:CreateButton(Localization.Text("Unblock"), function()
      rowActions.onUnblockPlayer(name)
    end)
    return
  end
  rootDescription:CreateButton(Localization.Text("Block…"), function()
    IgnorePrompt.AskReason(function(reason)
      onIgnorePlayer(name, reason)
    end)
  end)
end

-- "Copy profile link" submenu: one entry per profile site of this game for
-- the contact's character. Picking one opens the copy popup with the URL.
local ProfileLinksMenuEntry = {}

local LINK_PROMPT = "Press Ctrl+C to copy the link."

local function buildLinks(item)
  if FlavorCompat.isForever then
    return {}
  end
  local game = {
    regionId = FlavorCompat.CurrentRegion(),
    projectId = FlavorCompat.projectId,
    seasonId = FlavorCompat.ActiveSeason(),
  }
  local character = ProfileCharacter.FromItem(item, ProfileCharacter.OwnRealm(), game)
  if character == nil then
    return {}
  end
  return ProfileLinks.Build(character, game)
end

-- Empty when no site applies (WoW: Forever, China, no known character).
-- Runs before the rest of our menu section, so it must never raise: a
-- missed secret value would otherwise take every entry with it.
function ProfileLinksMenuEntry.Links(item)
  local ok, links = pcall(buildLinks, item)
  return ok and links or {}
end

function ProfileLinksMenuEntry.Add(rootDescription, links)
  if #links == 0 then
    return
  end
  local submenu = rootDescription:CreateButton(Localization.Text("Copy profile link"))
  if submenu == nil or type(submenu.CreateButton) ~= "function" then
    return
  end
  for _, link in ipairs(links) do
    local url = link.url
    submenu:CreateButton(Localization.Text(link.label), function()
      PopupUI.ShowManualCopyDialog(url, { prompt = LINK_PROMPT })
    end)
  end
end

-- "Separate <Character>": one top-level entry per character folded into a
-- Battle.net row, each moving that character's lines back into a chat of
-- their own. Battle.net rows only; groups are never merged.
local SeparateMenuEntry = {}

local function canSeparate(item, rowActions)
  return item.channel == "BN"
    and type(item.conversationKey) == "string"
    and type(rowActions) == "table"
    and type(rowActions.listMergedCharacters) == "function"
    and type(rowActions.onSeparateCharacter) == "function"
end

function SeparateMenuEntry.Add(rootDescription, item, rowActions)
  if not canSeparate(item, rowActions) then
    return
  end
  local bnetKey = item.conversationKey
  for _, character in ipairs(rowActions.listMergedCharacters(bnetKey)) do
    local characterKey = character.characterKey
    rootDescription:CreateButton(string.format(Localization.Text("Separate %s"), character.name), function()
      rowActions.onSeparateCharacter(bnetKey, characterKey)
    end)
  end
end

local MenuEntries = {
  Export = ExportMenuEntry,
  Notify = NotifyMenuEntries,
  AddFriend = AddFriendMenuEntry,
  Block = BlockMenuEntry,
  ProfileLinks = ProfileLinksMenuEntry,
  Separate = SeparateMenuEntry,
}

ns.ContactsListMenuEntries = MenuEntries
return MenuEntries
