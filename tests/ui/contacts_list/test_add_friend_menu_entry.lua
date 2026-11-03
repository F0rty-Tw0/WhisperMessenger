local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- A WoW whisper row's menu offers "Add friend" unless the player is already a
-- friend, is you, is a Battle.net contact, or the client has no friend API.

local GLOBALS =
  { "Menu", "UnitPopup_OpenMenu", "C_FriendList", "AddFriend", "UnitGUID", "UnitName", "GetNormalizedRealmName", "Ambiguate", "issecretvalue" }

local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return root
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function friendApi(added, friends)
  friends = friends or {}
  return {
    AddFriend = function(name)
      added[#added + 1] = name
    end,
    IsFriend = function(guid)
      return friends[guid] == true
    end,
    GetFriendInfo = function(name)
      if friends[name] then
        return { connected = false }
      end
      return nil
    end,
  }
end

return function()
  Localization.Configure({ language = "enUS" })
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local modifiers = {}
  local openedContext
  rawset(_G, "Menu", {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  })
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)
  rawset(_G, "UnitGUID", function()
    return "Player-1-SELF"
  end)
  rawset(_G, "UnitName", function()
    return "Me"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  -- Same-realm names lose their realm, like the game's Ambiguate(name, "none").
  rawset(_G, "Ambiguate", function(name)
    return (string.gsub(name, "%-Area52$", ""))
  end)

  local rowActions = { onPin = function() end }
  local function menuFor(item)
    ContextMenu.Open(item, anchor, nil, nil, rowActions)
    local root = newRoot()
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, openedContext)
    return root
  end

  local ok, err = pcall(function()
    -- test_stranger_row_offers_add_friend_and_adds_character
    do
      local added = {}
      rawset(_G, "C_FriendList", friendApi(added))
      local entry = findButton(menuFor({ channel = "WOW", displayName = "Arthas-Area52", guid = "Player-1-A" }), "Add friend")
      assert(entry ~= nil, "stranger row offers Add friend")
      entry.callback()
      assert(added[1] == "Arthas-Area52", "adds the character, got " .. tostring(added[1]))
    end

    -- test_friend_by_guid_hides_add_friend
    rawset(_G, "C_FriendList", friendApi({}, { ["Player-1-A"] = true }))
    assert(
      findButton(menuFor({ channel = "WOW", displayName = "Arthas-Area52", guid = "Player-1-A" }), "Add friend") == nil,
      "friend (guid) hides Add friend"
    )

    -- test_same_realm_friend_by_name_hides_add_friend
    rawset(_G, "C_FriendList", friendApi({}, { Jaina = true }))
    assert(findButton(menuFor({ channel = "WOW", displayName = "Jaina-Area52" }), "Add friend") == nil, "friend listed by bare name hides Add friend")

    -- test_battle_net_row_has_no_add_friend
    rawset(_G, "C_FriendList", friendApi({}))
    assert(
      findButton(menuFor({ channel = "BN", displayName = "Thrall", battleTag = "Thrall#1", bnetAccountID = 9 }), "Add friend") == nil,
      "no Add friend for Battle.net rows"
    )

    -- test_own_character_has_no_add_friend
    assert(
      findButton(menuFor({ channel = "WOW", displayName = "Alt-Area52", guid = "Player-1-SELF" }), "Add friend") == nil,
      "no Add friend for yourself (guid)"
    )
    assert(findButton(menuFor({ channel = "WOW", displayName = "Me-Area52" }), "Add friend") == nil, "no Add friend for yourself (name)")

    -- test_secret_name_hides_add_friend
    do
      local added = {}
      rawset(_G, "C_FriendList", friendApi(added))
      rawset(_G, "issecretvalue", function(value)
        return value == "Secret-Area52"
      end)
      local entry = findButton(menuFor({ channel = "WOW", displayName = "Secret-Area52" }), "Add friend")
      rawset(_G, "issecretvalue", nil)
      assert(entry == nil, "a secret name hides Add friend")
    end

    -- test_throwing_player_name_api_still_offers_add_friend
    do
      rawset(_G, "C_FriendList", friendApi({}))
      rawset(_G, "UnitName", function()
        error("secret compare")
      end)
      rawset(_G, "GetNormalizedRealmName", function()
        error("secret compare")
      end)
      local entry = findButton(menuFor({ channel = "WOW", displayName = "Arthas-Area52" }), "Add friend")
      rawset(_G, "UnitName", function()
        return "Me"
      end)
      rawset(_G, "GetNormalizedRealmName", function()
        return "Area52"
      end)
      assert(entry ~= nil, "a throwing player-name API still offers Add friend")
    end

    -- test_legacy_add_friend_global_used_without_c_friend_list
    do
      local added = {}
      rawset(_G, "C_FriendList", nil)
      rawset(_G, "AddFriend", function(name)
        added[#added + 1] = name
      end)
      local entry = findButton(menuFor({ channel = "WOW", displayName = "Arthas-Area52" }), "Add friend")
      assert(entry ~= nil, "legacy client offers Add friend")
      entry.callback()
      assert(added[1] == "Arthas-Area52", "legacy AddFriend called")
    end

    -- test_no_friend_api_hides_add_friend
    rawset(_G, "AddFriend", nil)
    assert(findButton(menuFor({ channel = "WOW", displayName = "Arthas-Area52" }), "Add friend") == nil, "no friend API, no entry")
  end)

  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end
