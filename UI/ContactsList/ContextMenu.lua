local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContextMenu = {}

local function resolveMenuName(item)
  local name = item.displayName or item.gameAccountName or item.battleTag
  if name == nil or name == "" then
    return nil
  end

  return name
end

function ContextMenu.Open(item, anchorFrame)
  if type(item) ~= "table" then
    return false
  end

  local name = resolveMenuName(item)
  if name == nil then
    return false
  end

  local lineID = item.lineID
  local chatType = item.chatType

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
    local which = item.channel == "BN" and "BN_FRIEND" or "FRIEND"
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
