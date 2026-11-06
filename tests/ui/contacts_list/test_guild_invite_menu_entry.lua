local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local SeenGuild = require("WhisperMessenger.Model.SeenGuild")
local FakeUI = require("tests.helpers.fake_ui")

-- A WoW whisper row's menu offers "Guild invite" when you are in a guild with
-- invite rights and the player is neither you, a guildmate, nor known to be in
-- another guild this session. Clicking it prefills the chat box with
-- "/ginvite <name>"; the player presses Enter (the invite API is protected).

local GLOBALS = {
  "Menu",
  "UnitPopup_OpenMenu",
  "C_GuildInfo",
  "ChatFrameUtil",
  "ChatFrame_OpenChat",
  "IsInGuild",
  "CanGuildInvite",
  "UnitGUID",
  "UnitName",
  "GetNormalizedRealmName",
  "Ambiguate",
  "issecretvalue",
  "GetPlayerInfoByGUID",
}

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

local function yes()
  return true
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

  local opened
  local invited
  local function resetFixture()
    opened = {}
    invited = {}
    SeenGuild._reset()
    rawset(_G, "IsInGuild", yes)
    rawset(_G, "CanGuildInvite", yes)
    rawset(_G, "issecretvalue", nil)
    rawset(_G, "GetPlayerInfoByGUID", nil)
    rawset(_G, "ChatFrame_OpenChat", nil)
    rawset(_G, "ChatFrameUtil", {
      OpenChat = function(text)
        opened[#opened + 1] = text
      end,
    })
    rawset(_G, "C_GuildInfo", {
      Invite = function(name)
        invited[#invited + 1] = name
      end,
      MemberExistsByName = function()
        return false
      end,
    })
  end

  local function row(overrides)
    local item = { channel = "WOW", displayName = "Arthas-Area52", guid = "Player-1-A" }
    for key, value in pairs(overrides or {}) do
      item[key] = value
    end
    return item
  end

  local function hasEntry(overrides)
    return findButton(menuFor(row(overrides)), "Guild invite") ~= nil
  end

  local ok, err = pcall(function()
    -- test_click_opens_chat_with_ginvite_command
    resetFixture()
    local entry = findButton(menuFor(row()), "Guild invite")
    assert(entry ~= nil, "eligible row offers Guild invite")
    entry.callback()
    assert(opened[1] == "/ginvite Arthas-Area52", "prefills the command, got " .. tostring(opened[1]))
    assert(#opened == 1, "opens chat once")

    -- test_click_prefills_guid_resolved_character_name
    resetFixture()
    rawset(_G, "GetPlayerInfoByGUID", function()
      return nil, nil, nil, nil, nil, "Arthas", "Area 52"
    end)
    local realmless = findButton(menuFor(row({ displayName = "Arthas" })), "Guild invite")
    assert(realmless ~= nil, "realm-less row offers Guild invite")
    realmless.callback()
    assert(opened[1] == "/ginvite Arthas-Area52", "prefills the GUID-resolved name, got " .. tostring(opened[1]))

    -- test_click_never_calls_protected_invite
    resetFixture()
    rawset(_G, "GuildInvite", function(name)
      invited[#invited + 1] = name
    end)
    findButton(menuFor(row()), "Guild invite").callback()
    rawset(_G, "GuildInvite", nil)
    assert(#invited == 0, "click must not call the protected invite API")

    -- test_click_falls_back_to_legacy_open_chat
    resetFixture()
    rawset(_G, "ChatFrameUtil", nil)
    rawset(_G, "ChatFrame_OpenChat", function(text)
      opened[#opened + 1] = text
    end)
    local legacy = findButton(menuFor(row()), "Guild invite")
    assert(legacy ~= nil, "legacy open-chat still offers Guild invite")
    legacy.callback()
    assert(opened[1] == "/ginvite Arthas-Area52", "legacy prefill, got " .. tostring(opened[1]))

    -- test_click_falls_back_when_chat_frame_util_lacks_open_chat
    resetFixture()
    rawset(_G, "ChatFrameUtil", {})
    rawset(_G, "ChatFrame_OpenChat", function(text)
      opened[#opened + 1] = text
    end)
    findButton(menuFor(row()), "Guild invite").callback()
    assert(opened[1] == "/ginvite Arthas-Area52", "falls back when OpenChat is missing, got " .. tostring(opened[1]))

    -- test_hidden_without_open_chat_function
    resetFixture()
    rawset(_G, "ChatFrameUtil", nil)
    assert(not hasEntry(), "no open-chat function hides Guild invite")

    -- test_shown_without_guild_info_api
    resetFixture()
    rawset(_G, "C_GuildInfo", nil)
    assert(hasEntry(), "missing C_GuildInfo still offers Guild invite")

    -- test_hidden_for_bnet_row
    resetFixture()
    assert(not hasEntry({ channel = "BN" }), "Battle.net rows have no Guild invite")

    -- test_hidden_without_display_name
    resetFixture()
    local item = row()
    item.displayName = nil
    assert(findButton(menuFor(item), "Guild invite") == nil, "no display name hides Guild invite")

    -- test_hidden_for_secret_name
    resetFixture()
    rawset(_G, "issecretvalue", function(value)
      return value == "Arthas-Area52"
    end)
    assert(not hasEntry(), "a secret name hides Guild invite")

    -- test_hidden_when_not_in_guild
    resetFixture()
    rawset(_G, "IsInGuild", function()
      return false
    end)
    assert(not hasEntry(), "not in a guild hides Guild invite")
    rawset(_G, "IsInGuild", nil)
    assert(not hasEntry(), "missing IsInGuild hides Guild invite")
    rawset(_G, "IsInGuild", function()
      error("boom")
    end)
    assert(not hasEntry(), "throwing IsInGuild hides Guild invite")

    -- test_hidden_when_guild_global_returns_secret
    resetFixture()
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    rawset(_G, "IsInGuild", function()
      return "SECRET"
    end)
    assert(not hasEntry(), "a secret IsInGuild result hides Guild invite")
    resetFixture()
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    rawset(_G, "CanGuildInvite", function()
      return "SECRET"
    end)
    assert(not hasEntry(), "a secret CanGuildInvite result hides Guild invite")

    -- test_hidden_without_invite_rank
    resetFixture()
    rawset(_G, "CanGuildInvite", function()
      return false
    end)
    assert(not hasEntry(), "no invite rank hides Guild invite")
    rawset(_G, "CanGuildInvite", nil)
    assert(not hasEntry(), "missing CanGuildInvite hides Guild invite")
    rawset(_G, "CanGuildInvite", function()
      error("boom")
    end)
    assert(not hasEntry(), "throwing CanGuildInvite hides Guild invite")

    -- test_hidden_for_self
    resetFixture()
    assert(not hasEntry({ displayName = "Me-Area52", guid = nil }), "no Guild invite for yourself")

    -- test_hidden_for_guildmate
    resetFixture()
    _G.C_GuildInfo.MemberExistsByName = yes
    assert(not hasEntry(), "a guildmate hides Guild invite")

    -- test_shown_when_member_check_missing_or_throws
    resetFixture()
    _G.C_GuildInfo.MemberExistsByName = nil
    assert(hasEntry(), "missing member check still offers Guild invite")
    rawset(_G.C_GuildInfo, "MemberExistsByName", function()
      error("boom")
    end)
    assert(hasEntry(), "throwing member check still offers Guild invite")

    -- test_shown_when_member_check_returns_secret
    resetFixture()
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    rawset(_G.C_GuildInfo, "MemberExistsByName", function()
      return "SECRET"
    end)
    assert(hasEntry(), "a secret member check counts as not a member")

    -- test_hidden_when_seen_in_other_guild
    resetFixture()
    SeenGuild.Record("Arthas-Area52", "Horde Inc")
    assert(not hasEntry(), "a player seen in another guild hides Guild invite")

    -- test_shown_when_seen_without_guild
    resetFixture()
    SeenGuild.Record("Arthas-Area52", "")
    assert(hasEntry(), "a player seen without a guild still offers Guild invite")
  end)

  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  SeenGuild._reset()
  assert(ok, err)
end
