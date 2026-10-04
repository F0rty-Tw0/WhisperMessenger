local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")

-- At load, the addon registers the say filter for a saved ignore entry, and
-- that filter reads the live ignore list: an ignored player's say line is
-- hidden from the game's chat.
return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedUtil = rawget(_G, "ChatFrameUtil")
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local added = {}
  rawset(_G, "ChatFrameUtil", {
    AddMessageEventFilter = function(event, fn)
      added[event] = fn
    end,
    RemoveMessageEventFilter = function(event, fn)
      if added[event] == fn then
        added[event] = nil
      end
    end,
  })

  local ok, err = pcall(function()
    Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
        filters = { ignored = { ["spammer-realm"] = { name = "Spammer-Realm", addedAt = 0, blocked = 0 } }, rules = {} },
      },
      characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    })

    -- test_saved_ignore_entry_registers_the_say_filter
    local say = added.CHAT_MSG_SAY
    assert(type(say) == "function", "say filter registered at load")

    -- test_say_filter_hides_the_ignored_player
    local hidden = say({}, "CHAT_MSG_SAY", "hello", "Spammer-Realm", "", "", "", "", 0, 0, "", 0, 9001, "Player-1-0000OTHER")
    assert(hidden == true, "ignored player's say line is hidden")
  end)

  rawset(_G, "ChatFrameUtil", savedUtil)
  _G.UIParent = savedUIParent
  assert(ok, err)
end
