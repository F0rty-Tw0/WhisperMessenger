local GuildInviteMenu = require("tests.helpers.guild_invite_menu")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local Flavor = require("tests.helpers.flavor")

-- Clicking "Guild invite" shows "/ginvite <name>" in the copy dialog for the
-- player to paste into chat. The invite API is protected, and Enter on a chat
-- box the addon filled is blocked too (seen in game), so the click never opens
-- the game's chat box. Same-realm names drop the realm.

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

local function clickCopies(fixture, overrides)
  local copied
  ManualCopyCapture.With(function(capture)
    fixture.entry(overrides).callback()
    local dialog = _G.StaticPopupDialogs.WHISPER_MESSENGER_BUBBLE_COPY_TEXT
    copied = { count = capture.count, text = capture.text, prompt = dialog and dialog.text }
  end)
  return copied
end

return function()
  GuildInviteMenu.With(function(fixture)
    local resetFixture = fixture.reset

    -- test_click_shows_ginvite_in_copy_dialog
    resetFixture()
    local copied = clickCopies(fixture, { displayName = "Bob-Area52" })
    assert(copied.count == 1, "shows the copy dialog once, got " .. tostring(copied.count))
    assert(copied.text == "/ginvite Bob", "copy dialog holds the command, got " .. tostring(copied.text))
    assert(copied.prompt == COMMAND_PROMPT, "tells the player to paste it, got " .. tostring(copied.prompt))

    -- test_click_never_opens_the_chat_box
    assert(#fixture.opened == 0, "must not fill the game's chat box, got " .. tostring(fixture.opened[1]))

    -- test_click_never_opens_the_legacy_chat_box
    resetFixture()
    rawset(_G, "ChatFrameUtil", nil)
    rawset(_G, "ChatFrame_OpenChat", function(text)
      fixture.opened[#fixture.opened + 1] = text
    end)
    clickCopies(fixture)
    assert(#fixture.opened == 0, "must not fill the legacy chat box, got " .. tostring(fixture.opened[1]))

    -- test_click_keeps_realm_for_other_realm_player
    resetFixture()
    Flavor.With(true, false, function()
      copied = clickCopies(fixture, { displayName = "Bob-Stormrage" })
    end)
    assert(copied.text == "/ginvite Bob-Stormrage", "keeps another realm, got " .. tostring(copied.text))

    -- test_click_drops_realm_on_forever
    -- WoW: Forever tags names with a realm, but /ginvite finds the player only
    -- by the bare name there (seen in game). Names can hold spaces.
    resetFixture()
    Flavor.With(true, true, function()
      copied = clickCopies(fixture, { displayName = "Jurst Lule-CAMWOWEU5Realm2PvP" })
    end)
    assert(copied.text == "/ginvite Jurst Lule", "drops the realm on Forever, got " .. tostring(copied.text))

    -- test_click_copies_guid_resolved_character_name
    resetFixture()
    rawset(_G, "GetPlayerInfoByGUID", function()
      return nil, nil, nil, nil, nil, "Arthas", "Stormrage"
    end)
    copied = clickCopies(fixture, { displayName = "Arthas" })
    assert(copied.text == "/ginvite Arthas-Stormrage", "copies the GUID-resolved name, got " .. tostring(copied.text))

    -- test_click_never_calls_protected_invite
    resetFixture()
    rawset(_G, "GuildInvite", function(name)
      fixture.invited[#fixture.invited + 1] = name
    end)
    clickCopies(fixture)
    rawset(_G, "GuildInvite", nil)
    assert(#fixture.invited == 0, "click must not call the protected invite API")
  end)
end
