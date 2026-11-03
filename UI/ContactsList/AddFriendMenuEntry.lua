local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")

-- A whisper row's "Add friend" entry. WoW whisper rows only, and hidden when
-- the player is already a friend, is you, or the client can't add friends.
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

local function isSelf(item, name)
  if item.guid ~= nil and type(_G.UnitGUID) == "function" then
    local ok, guid = pcall(_G.UnitGUID, "player")
    if ok and guid == item.guid then
      return true
    end
  end
  local own = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
  if type(own) ~= "string" then
    return false
  end
  local realm = type(_G.GetNormalizedRealmName) == "function" and _G.GetNormalizedRealmName() or nil
  return name == own or (type(realm) == "string" and name == own .. "-" .. realm)
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
    if ok and friend == true then
      return true
    end
  end
  return OnlineWatch.ReadCharacterFriend(api, name) ~= nil
end

function AddFriendMenuEntry.Add(rootDescription, item)
  local addFriend = addFriendFunction()
  if addFriend == nil or item.channel ~= "WOW" or item.displayName == nil then
    return
  end
  local name = IgnoreList.CharacterName(item.displayName, item.guid)
  if isSelf(item, name) or isFriend(item, name) then
    return
  end
  rootDescription:CreateButton(Localization.Text("Add friend"), function()
    addFriend(name)
  end)
end

ns.ContactsListAddFriendMenuEntry = AddFriendMenuEntry
return AddFriendMenuEntry
