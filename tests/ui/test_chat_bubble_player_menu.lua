local FakeUI = require("tests.helpers.fake_ui")
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")

return function()
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Frame", nil, nil)

  -- test_open_routes_incoming_wow_whisper_to_friend_dropdown
  do
    local opened
    local stub = {
      Open = function(item, anchorFrame)
        opened = { item = item, anchor = anchorFrame }
        return true
      end,
    }

    local message = {
      direction = "in",
      channel = "WOW",
      playerName = "Arthas-Area52",
      guid = "Player-3678-0A1B2C3D",
    }
    local ok = PlayerMenu.Open(message, anchor, stub)

    assert(ok == true, "expected Open to return true on success")
    assert(opened ~= nil, "expected the contacts ContextMenu.Open to be called")
    assert(opened.item.channel == "WOW", "expected channel WOW, got " .. tostring(opened.item.channel))
    assert(opened.item.displayName == "Arthas-Area52", "expected displayName 'Arthas-Area52', got " .. tostring(opened.item.displayName))
    assert(opened.item.guid == "Player-3678-0A1B2C3D", "expected guid forwarded, got " .. tostring(opened.item.guid))
    assert(opened.anchor == anchor, "expected the anchor frame to be forwarded")
  end

  -- test_open_routes_incoming_bnet_whisper_with_account_id
  do
    local opened
    local stub = {
      Open = function(item, anchorFrame)
        opened = { item = item, anchor = anchorFrame }
        return true
      end,
    }

    local message = {
      direction = "in",
      channel = "BN",
      playerName = "Jaina#1234",
      bnetAccountID = 12345,
      battleTag = "Jaina#1234",
    }
    local ok = PlayerMenu.Open(message, anchor, stub)

    assert(ok == true, "expected BN open to return true")
    assert(opened.item.channel == "BN", "expected channel BN")
    assert(opened.item.bnetAccountID == 12345, "expected bnetAccountID 12345, got " .. tostring(opened.item.bnetAccountID))
    assert(opened.item.battleTag == "Jaina#1234", "expected battleTag forwarded, got " .. tostring(opened.item.battleTag))
  end

  -- test_open_refuses_outgoing_messages
  -- You don't open a player menu on yourself.
  do
    local called = false
    local stub = {
      Open = function()
        called = true
        return true
      end,
    }

    local ok = PlayerMenu.Open({
      direction = "out",
      channel = "WOW",
      playerName = "Me",
    }, anchor, stub)

    assert(ok == false, "expected Open to refuse outgoing messages")
    assert(called == false, "expected ContextMenu.Open NOT to be called for outgoing messages")
  end

  -- test_open_returns_false_without_a_player_name
  do
    local called = false
    local stub = {
      Open = function()
        called = true
        return true
      end,
    }

    local ok = PlayerMenu.Open({ direction = "in", channel = "WOW" }, anchor, stub)
    assert(ok == false, "expected Open to refuse messages without a playerName")
    assert(called == false, "expected ContextMenu.Open NOT to be called when name is missing")
  end

  -- test_open_returns_false_when_context_menu_is_unavailable
  do
    local ok = PlayerMenu.Open({
      direction = "in",
      channel = "WOW",
      playerName = "Thrall-Doomhammer",
    }, anchor, nil)
    -- Without a contacts ContextMenu impl injected and no ns lookup in the
    -- test sandbox, Open should fail gracefully instead of erroring.
    assert(ok == false, "expected Open to return false when the menu impl is unavailable")
  end
end
