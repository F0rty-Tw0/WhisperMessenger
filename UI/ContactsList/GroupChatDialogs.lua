local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TextInputDialog = ns.TextInputDialog or require("WhisperMessenger.UI.Shared.TextInputDialog")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")
local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")

-- Popups and contact-menu entries for party-free group chats: start one,
-- add people, rename, leave. The actions (Core/GroupChat/GroupChatActions)
-- are set once at load; without them nothing here shows.
local GroupChatDialogs = {}

local CREATE_DIALOG = "WHISPER_MESSENGER_NEW_GROUP_CHAT"
local ADD_DIALOG = "WHISPER_MESSENGER_GROUP_CHAT_ADD"
local RENAME_DIALOG = "WHISPER_MESSENGER_GROUP_CHAT_RENAME"
local LEAVE_DIALOG = "WHISPER_MESSENGER_GROUP_CHAT_LEAVE"

local actions = nil

function GroupChatDialogs.SetActions(nextActions)
  actions = nextActions
end

function GroupChatDialogs.HasActions()
  return type(actions) == "table"
end

local function L(key)
  return Localization.Text(key)
end

local function titleOf(item)
  return item.title or item.displayName or ""
end

function GroupChatDialogs.ShowCreate()
  if actions == nil then
    return false
  end
  return TextInputDialog.Show(CREATE_DIALOG, {
    prompt = L("Start a group chat. Enter player names, separated by commas. Everyone needs Whisper Messenger."),
    accept = L("Create"),
    maxBytes = TextLimits.INPUT_MAX_BYTES,
    value = "",
    onAccept = function(text)
      actions.CreateAndOpen(text)
    end,
  })
end

function GroupChatDialogs.ShowAddPeople(item)
  if actions == nil then
    return false
  end
  return TextInputDialog.Show(ADD_DIALOG, {
    prompt = L("Add people to %s. Enter player names, separated by commas."),
    accept = L("Add"),
    maxBytes = TextLimits.INPUT_MAX_BYTES,
    textArg = titleOf(item),
    value = "",
    onAccept = function(text)
      actions.AddMembers(item, text)
    end,
  })
end

function GroupChatDialogs.ShowRename(item)
  if actions == nil then
    return false
  end
  return TextInputDialog.Show(RENAME_DIALOG, {
    prompt = L("Rename %s."),
    accept = L("Save"),
    maxLetters = GroupChats.MAX_NAME_CHARS,
    textArg = titleOf(item),
    value = titleOf(item),
    onAccept = function(text)
      actions.Rename(item, text)
    end,
  })
end

function GroupChatDialogs.ConfirmLeave(item)
  if actions == nil or type(_G.StaticPopup_Show) ~= "function" then
    return false
  end
  if type(_G.StaticPopupDialogs) ~= "table" then
    _G.StaticPopupDialogs = {}
  end
  -- Rebuilt per show so a language switch needs no reload.
  _G.StaticPopupDialogs[LEAVE_DIALOG] = {
    text = L("Leave %s? You will stop getting its messages."),
    button1 = L("Leave"),
    button2 = L("Cancel"),
    OnAccept = function(_popup, data)
      if actions and data then
        actions.Leave(data)
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  _G.StaticPopup_Show(LEAVE_DIALOG, titleOf(item), nil, item)
  return true
end

-- The group chat's own entries in its row menu.
function GroupChatDialogs.AddMenuEntries(rootDescription, item)
  if actions == nil or type(item) ~= "table" or item.channel ~= ChannelType.WM_GROUP then
    return
  end
  if not actions.CanManage(item) then
    return
  end
  rootDescription:CreateButton(L("Add people…"), function()
    GroupChatDialogs.ShowAddPeople(item)
  end)
  rootDescription:CreateButton(L("Rename…"), function()
    GroupChatDialogs.ShowRename(item)
  end)
  rootDescription:CreateButton(L("Leave group chat"), function()
    GroupChatDialogs.ConfirmLeave(item)
  end)
end

ns.ContactsListGroupChatDialogs = GroupChatDialogs
return GroupChatDialogs
