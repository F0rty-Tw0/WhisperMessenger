local LinkHooksEnv = require("tests.helpers.link_hooks_env")

-- Links reach the composer through post-hooks on Blizzard's insert functions
-- and on SetItemRef, and only while the composer has focus.
return function()
  local env = LinkHooksEnv.New()
  local input = env.NewInput()
  env.LinkHooks.RegisterInput(input)
  local itemLink = "|Hitem:12345|h[Test Item]|h"

  local function reset(focused)
    env.Reset()
    input.focused = focused
    input.shown = true
    env.blizzardActiveWindow = nil
    rawset(_G, "_wmSuspended", nil)
  end

  -- test_insert_link_skips_composer_when_blizzard_chat_box_is_open
  -- (Blizzard already put the link in its own open chat box)
  do
    reset(true)
    env.blizzardActiveWindow = {}
    _G.ChatFrameUtil.InsertLink(itemLink)
    _G.ChatEdit_InsertLink(itemLink)
    assert(#env.inserts == 0, "an open Blizzard chat box must keep the link to itself, got " .. #env.inserts)
  end

  -- test_quest_log_shift_click_lands_in_focused_composer
  do
    reset(true)
    local button = {
      GetID = function()
        return 1
      end,
      GetText = function()
        return "[Apprentice's Duties (471)]"
      end,
    }
    _G.QuestLogTitleButton_OnClick(button, "LeftButton")
    local expected = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
    assert(env.inserts[1] == expected, "expected the quest log link in the composer, got: " .. tostring(env.inserts[1]))
  end

  -- test_insert_link_lands_in_focused_composer_once
  do
    reset(true)
    _G.ChatFrameUtil.InsertLink(itemLink)
    assert(#env.inserts == 1, "expected one insert, got " .. #env.inserts)
    assert(env.inserts[1] == itemLink, "expected the item link, got: " .. tostring(env.inserts[1]))
  end

  -- test_insert_link_skips_unfocused_composer
  do
    reset(false)
    _G.ChatFrameUtil.InsertLink(itemLink)
    assert(#env.inserts == 0, "an unfocused composer must not receive the link, got " .. #env.inserts)
  end

  -- test_insert_link_skips_hidden_composer
  do
    reset(true)
    input.shown = false
    _G.ChatFrameUtil.InsertLink(itemLink)
    assert(#env.inserts == 0, "a hidden composer must not receive the link, got " .. #env.inserts)
  end

  -- test_insert_link_does_nothing_while_suspended
  do
    reset(true)
    rawset(_G, "_wmSuspended", true)
    _G.ChatFrameUtil.InsertLink(itemLink)
    assert(#env.inserts == 0, "a suspended addon must not insert, got " .. #env.inserts)
  end

  -- test_global_insert_link_lands_in_focused_composer
  do
    reset(true)
    _G.ChatEdit_InsertLink(itemLink)
    assert(#env.inserts == 1 and env.inserts[1] == itemLink, "ChatEdit_InsertLink should insert into the focused composer")
  end

  -- test_insert_link_rewrites_classic_plain_quest_text
  do
    reset(true)
    _G.ChatEdit_InsertLink("[Apprentice's Duties (471)]")
    local expected = "|cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
    assert(env.inserts[1] == expected, "expected the quest hyperlink, got: " .. tostring(env.inserts[1]))
  end

  -- test_set_item_ref_hook_does_nothing_when_unfocused
  do
    reset(false)
    _G.SetItemRef("quest:12345", "[Some Quest]")
    assert(#env.inserts == 0, "SetItemRef hook should not insert quest link when unfocused")
  end

  -- test_set_item_ref_hook_inserts_when_focused
  do
    reset(true)
    _G.SetItemRef(itemLink, itemLink)
    assert(#env.inserts == 1, "SetItemRef hook should insert when focused")
  end

  -- test_set_item_ref_hook_does_nothing_while_suspended
  do
    reset(true)
    rawset(_G, "_wmSuspended", true)
    _G.SetItemRef(itemLink, itemLink)
    assert(#env.inserts == 0, "a suspended addon must not insert from SetItemRef, got " .. #env.inserts)
  end

  -- test_shift_clicked_player_name_inserts_plain_name
  do
    reset(true)
    _G.SetItemRef("player:Gæmmer-Kazzak:1:WHISPER", "|cff3fc7eb|Hplayer:Gæmmer-Kazzak:1:WHISPER|hGæmmer|h|r")
    assert(env.inserts[1] == "Gæmmer-Kazzak", "expected the plain player name, got: " .. tostring(env.inserts[1]))
  end

  -- test_shift_clicked_player_name_skips_composer_when_blizzard_chat_box_is_open
  do
    reset(true)
    env.blizzardActiveWindow = {}
    _G.SetItemRef("player:Gæmmer-Kazzak:1:WHISPER", "|cff3fc7eb|Hplayer:Gæmmer-Kazzak:1:WHISPER|hGæmmer|h|r")
    assert(#env.inserts == 0, "an open Blizzard chat box must keep the name to itself, got: " .. tostring(env.inserts[1]))
  end

  -- test_shift_clicked_battlenet_name_inserts_nothing
  -- (Blizzard ignores this click so the encoded account name never reaches chat)
  do
    reset(true)
    _G.SetItemRef("BNplayer:|Kq12|k:12:3:BN_WHISPER:", "|HBNplayer:|Kq12|k:12:3:BN_WHISPER:|h[|Kq12|k]|h")
    assert(#env.inserts == 0, "a Battle.net name must not be inserted, got: " .. tostring(env.inserts[1]))
  end

  -- Right-click (menu) or plain left-click on a player name: no chat-link
  -- modifier. The server rejects |Hplayer links in sent messages ("Invalid
  -- escape code in chat message"), so none of these may reach the composer.
  local rawPlayerLink = "|Hplayer:Ambush Rasit:3901:CHANNEL:2|h|cfffff468Ambush Rasit|r|h"
  local plainClick = function()
    return false
  end
  local chatLinkClick = rawget(_G, "IsModifiedClick")

  -- test_unmodified_player_click_inserts_nothing
  do
    reset(true)
    rawset(_G, "IsModifiedClick", plainClick)
    _G.SetItemRef("player:Ambush Rasit:3901:CHANNEL:2", rawPlayerLink)
    rawset(_G, "IsModifiedClick", chatLinkClick)
    assert(#env.inserts == 0, "a plain player click must not insert, got: " .. tostring(env.inserts[1]))
  end

  -- test_insert_clicked_player_name_ignores_a_plain_click
  do
    reset(true)
    rawset(_G, "IsModifiedClick", plainClick)
    local took = env.LinkHooks.InsertClickedPlayerName("player:Ambush Rasit:3901:CHANNEL:2")
    rawset(_G, "IsModifiedClick", chatLinkClick)
    assert(took == false and #env.inserts == 0, "a plain click must not insert the name, got: " .. tostring(env.inserts[1]))
  end

  -- test_insert_clicked_player_name_does_nothing_while_suspended
  do
    reset(true)
    rawset(_G, "_wmSuspended", true)
    local took = env.LinkHooks.InsertClickedPlayerName("player:Ambush Rasit:3901:CHANNEL:2")
    rawset(_G, "_wmSuspended", nil)
    assert(took == false and #env.inserts == 0, "a suspended addon must not insert the name, got: " .. tostring(env.inserts[1]))
  end

  -- test_unmodified_community_player_click_inserts_nothing
  do
    reset(true)
    rawset(_G, "IsModifiedClick", plainClick)
    _G.SetItemRef("playerCommunity:Ambush Rasit:1:2", "|HplayerCommunity:Ambush Rasit:1:2|h[Ambush Rasit]|h")
    rawset(_G, "IsModifiedClick", chatLinkClick)
    assert(#env.inserts == 0, "a plain community player click must not insert, got: " .. tostring(env.inserts[1]))
  end

  -- test_unmodified_battlenet_player_click_inserts_nothing
  do
    reset(true)
    rawset(_G, "IsModifiedClick", plainClick)
    _G.SetItemRef("BNplayer:|Kq12|k:12:3:BN_WHISPER:", "|HBNplayer:|Kq12|k:12:3:BN_WHISPER:|h[|Kq12|k]|h")
    rawset(_G, "IsModifiedClick", chatLinkClick)
    assert(#env.inserts == 0, "a plain Battle.net click must not insert, got: " .. tostring(env.inserts[1]))
  end

  -- test_nameless_player_link_inserts_nothing
  -- (no name to parse must not fall through to the generic raw-link insert)
  do
    local nameless = "|Hplayer::1:WHISPER|h[x]|h"
    reset(true)
    _G.SetItemRef("player::1:WHISPER", nameless)
    assert(#env.inserts == 0, "a shift-clicked nameless player link must not insert, got: " .. tostring(env.inserts[1]))
    reset(true)
    rawset(_G, "IsModifiedClick", plainClick)
    _G.SetItemRef("player::1:WHISPER", nameless)
    rawset(_G, "IsModifiedClick", chatLinkClick)
    assert(#env.inserts == 0, "a plain nameless player click must not insert, got: " .. tostring(env.inserts[1]))
  end

  -- test_set_item_ref_hook_skips_our_url_links_when_focused
  -- (a URL click copies the address; it must not also drop the link into the
  --  composer now that URL clicks pass through SetItemRef)
  do
    reset(true)
    local urlText = "|cff71d5ff|Haddon:WhisperMessenger:url:https://example.com|hhttps://example.com|h|r"
    _G.SetItemRef("addon:WhisperMessenger:url:https://example.com", urlText)
    assert(#env.inserts == 0, "SetItemRef hook should not insert our URL links, got: " .. tostring(env.inserts[1]))
  end

  env.Restore()
end
