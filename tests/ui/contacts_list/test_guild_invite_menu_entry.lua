local SeenGuild = require("WhisperMessenger.Model.SeenGuild")
local GuildInviteMenu = require("tests.helpers.guild_invite_menu")

-- A WoW whisper row's menu offers "Guild invite" when you are in a guild with
-- invite rights and the player is neither you, a guildmate, nor known to be in
-- another guild this session. What a click does is covered in
-- test_guild_invite_menu_entry_click.lua.

return function()
  GuildInviteMenu.With(function(fixture)
    local hasEntry = fixture.hasEntry
    local resetFixture = fixture.reset

    -- test_hidden_without_copy_dialog
    resetFixture()
    rawset(_G, "StaticPopup_Show", nil)
    assert(not hasEntry(), "no copy dialog hides Guild invite")

    -- test_shown_without_open_chat_function
    resetFixture()
    rawset(_G, "ChatFrameUtil", nil)
    assert(hasEntry(), "Guild invite needs only the copy dialog, not the chat box")

    -- test_shown_without_guild_info_api
    resetFixture()
    rawset(_G, "C_GuildInfo", nil)
    assert(hasEntry(), "missing C_GuildInfo still offers Guild invite")

    -- test_hidden_for_bnet_row
    resetFixture()
    assert(not hasEntry({ channel = "BN" }), "Battle.net rows have no Guild invite")

    -- test_hidden_without_display_name
    resetFixture()
    local item = fixture.row()
    item.displayName = nil
    assert(GuildInviteMenu.FindButton(fixture.menuFor(item), "Guild invite") == nil, "no display name hides Guild invite")

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
    _G.C_GuildInfo.MemberExistsByName = function(name)
      return name == "Arthas-Area52"
    end
    assert(not hasEntry(), "a guildmate hides Guild invite")
    assert(hasEntry({ displayName = "Jaina-Area52", guid = "Player-1-J" }), "another player's membership is asked by their own name")

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
end
