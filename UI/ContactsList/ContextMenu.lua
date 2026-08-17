local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

local ContextMenu = {}

local function hasUnansweredIncoming(item)
  if type(item.conversation) == "table" then
    return Store.CountUnansweredIncoming(item.conversation) > 0
  end
  return (tonumber(item.unansweredCount) or 0) > 0
end

local registeredModernMenu = nil

local function addMarkUnreadEntry(_owner, rootDescription, contextData)
  if rootDescription == nil or type(rootDescription.CreateButton) ~= "function" then
    return
  end
  if type(contextData) ~= "table" or type(contextData.whisperMessengerOnMarkUnread) ~= "function" then
    return
  end
  local item = contextData.whisperMessengerItem
  if type(item) ~= "table" then
    return
  end

  local button = rootDescription:CreateButton(Localization.Text("Mark last messages as unread"), function()
    contextData.whisperMessengerOnMarkUnread(item)
  end)
  if button and type(button.SetEnabled) == "function" then
    button:SetEnabled(hasUnansweredIncoming(item))
  end
end

local function ensureModernMenu()
  local menu = _G.Menu
  if type(menu) ~= "table" or type(menu.ModifyMenu) ~= "function" then
    return false
  end
  if registeredModernMenu == menu then
    return true
  end

  local okFriend = pcall(menu.ModifyMenu, "MENU_UNIT_FRIEND", addMarkUnreadEntry)
  local okBnet = pcall(menu.ModifyMenu, "MENU_UNIT_BN_FRIEND", addMarkUnreadEntry)
  if not okFriend or not okBnet then
    return false
  end

  registeredModernMenu = menu
  return true
end

local function resolveMenuName(item)
  local name = item.displayName or item.gameAccountName or item.battleTag
  if name == nil or name == "" then
    return nil
  end

  return name
end

function ContextMenu.Open(item, anchorFrame, onMarkUnread)
  if type(item) ~= "table" then
    return false
  end

  local name = resolveMenuName(item)
  if name == nil then
    return false
  end

  local lineID = item.lineID
  local chatType = item.chatType
  local which = item.channel == "BN" and "BN_FRIEND" or "FRIEND"

  if ensureModernMenu() and type(_G.UnitPopup_OpenMenu) == "function" then
    _G.UnitPopup_OpenMenu(which, {
      name = name,
      lineID = lineID,
      chatType = chatType,
      chatTarget = name,
      chatFrame = anchorFrame,
      bnetAccountID = item.bnetAccountID,
      bnetIDAccount = item.bnetAccountID,
      guid = item.guid,
      battleTag = item.battleTag,
      communityClubID = item.communityClubID,
      communityStreamID = item.communityStreamID,
      communityEpoch = item.communityEpoch,
      communityPosition = item.communityPosition,
      whisperMessengerItem = item,
      whisperMessengerOnMarkUnread = onMarkUnread,
    })
    return true
  end

  if item.channel == "BN" then
    if type(_G.FriendsFrame_ShowBNDropdown) == "function" then
      _G.FriendsFrame_ShowBNDropdown(
        name,
        1,
        lineID,
        chatType,
        anchorFrame,
        nil,
        item.bnetAccountID,
        item.communityClubID,
        item.communityStreamID,
        item.communityEpoch,
        item.communityPosition,
        item.battleTag
      )
      return true
    end
  elseif type(_G.FriendsFrame_ShowDropdown) == "function" then
    _G.FriendsFrame_ShowDropdown(
      name,
      1,
      lineID,
      chatType,
      anchorFrame,
      nil,
      item.communityClubID,
      item.communityStreamID,
      item.communityEpoch,
      item.communityPosition,
      item.guid
    )
    return true
  end

  if type(_G.UnitPopup_OpenMenu) == "function" then
    _G.UnitPopup_OpenMenu(which, {
      name = name,
      lineID = lineID,
      chatType = chatType,
      chatTarget = name,
      chatFrame = anchorFrame,
      bnetIDAccount = item.bnetAccountID,
      guid = item.guid,
      battleTag = item.battleTag,
      communityClubID = item.communityClubID,
      communityStreamID = item.communityStreamID,
      communityEpoch = item.communityEpoch,
      communityPosition = item.communityPosition,
    })
    return true
  end

  return false
end

ns.ContactsListContextMenu = ContextMenu
return ContextMenu
