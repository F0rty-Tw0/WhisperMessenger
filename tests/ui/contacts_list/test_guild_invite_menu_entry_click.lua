local GuildInviteMenu = require("tests.helpers.guild_invite_menu")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")

-- Clicking "Guild invite" prefills the chat box with "/ginvite <name>" for the
-- player to send (the invite API is protected). When prefilling would taint
-- the game's slash commands, the click shows the command in the copy dialog
-- instead. Same-realm names drop the realm.

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

-- Each leaves prefilling unsafe.
local UNSAFE = {
  {
    "no slash command hash",
    function()
      rawset(_G, "hash_SlashCmdList", nil)
    end,
  },
  {
    "command not imported yet",
    function()
      rawset(_G, "hash_SlashCmdList", {})
    end,
  },
  {
    "tainted command entry",
    function()
      rawset(_G, "issecurevariable", function()
        return false, "SomeAddon"
      end)
    end,
  },
  {
    "no issecurevariable",
    function()
      rawset(_G, "issecurevariable", nil)
    end,
  },
  {
    "pending slash commands",
    function()
      rawset(_G, "SlashCmdList", { SOMEADDON = function() end })
    end,
  },
}

return function()
  GuildInviteMenu.With(function(fixture)
    local resetFixture = fixture.reset

    -- test_click_opens_chat_with_ginvite_command
    resetFixture()
    ManualCopyCapture.With(function(capture)
      local entry = fixture.entry({ displayName = "Bob-Area52" })
      assert(entry ~= nil, "eligible row offers Guild invite")
      entry.callback()
      assert(fixture.opened[1] == "/ginvite Bob", "prefills the command, got " .. tostring(fixture.opened[1]))
      assert(#fixture.opened == 1, "opens chat once")
      assert(capture.count == 0, "no copy dialog when prefilling is safe")
    end)

    -- test_click_opens_chat_under_the_prefill_guard
    -- Our chat-box hook skips the box only while ChatPrefill flags it.
    assert(fixture.openedWhilePrefilling == true, "opens chat through ChatPrefill so the hook leaves the box alone")

    -- test_click_keeps_realm_for_other_realm_player
    resetFixture()
    fixture.entry({ displayName = "Bob-Stormrage" }).callback()
    assert(fixture.opened[1] == "/ginvite Bob-Stormrage", "keeps another realm, got " .. tostring(fixture.opened[1]))

    -- test_click_prefills_guid_resolved_character_name
    resetFixture()
    rawset(_G, "GetPlayerInfoByGUID", function()
      return nil, nil, nil, nil, nil, "Arthas", "Stormrage"
    end)
    local realmless = fixture.entry({ displayName = "Arthas" })
    assert(realmless ~= nil, "realm-less row offers Guild invite")
    realmless.callback()
    assert(fixture.opened[1] == "/ginvite Arthas-Stormrage", "prefills the GUID-resolved name, got " .. tostring(fixture.opened[1]))

    -- test_click_never_calls_protected_invite
    resetFixture()
    rawset(_G, "GuildInvite", function(name)
      fixture.invited[#fixture.invited + 1] = name
    end)
    fixture.entry().callback()
    rawset(_G, "GuildInvite", nil)
    assert(#fixture.invited == 0, "click must not call the protected invite API")

    -- test_click_falls_back_to_legacy_open_chat
    resetFixture()
    rawset(_G, "ChatFrameUtil", nil)
    rawset(_G, "ChatFrame_OpenChat", function(text)
      fixture.opened[#fixture.opened + 1] = text
    end)
    local legacy = fixture.entry()
    assert(legacy ~= nil, "legacy open-chat still offers Guild invite")
    legacy.callback()
    assert(fixture.opened[1] == "/ginvite Arthas", "legacy prefill, got " .. tostring(fixture.opened[1]))

    -- test_click_falls_back_when_chat_frame_util_lacks_open_chat
    resetFixture()
    rawset(_G, "ChatFrameUtil", {})
    rawset(_G, "ChatFrame_OpenChat", function(text)
      fixture.opened[#fixture.opened + 1] = text
    end)
    fixture.entry().callback()
    assert(fixture.opened[1] == "/ginvite Arthas", "falls back when OpenChat is missing, got " .. tostring(fixture.opened[1]))

    -- test_click_shows_copy_dialog_when_prefill_unsafe
    for _, case in ipairs(UNSAFE) do
      resetFixture()
      case[2]()
      ManualCopyCapture.With(function(capture)
        fixture.entry({ displayName = "Bob-Area52" }).callback()
        assert(#fixture.opened == 0, case[1] .. ": must not open chat")
        assert(capture.count == 1, case[1] .. ": shows the copy dialog once")
        assert(capture.text == "/ginvite Bob", case[1] .. ": copy dialog holds the command, got " .. tostring(capture.text))
        local dialog = _G.StaticPopupDialogs.WHISPER_MESSENGER_BUBBLE_COPY_TEXT
        assert(dialog.text == COMMAND_PROMPT, case[1] .. ": tells the player to paste it, got " .. tostring(dialog.text))
      end)
    end
  end)
end
