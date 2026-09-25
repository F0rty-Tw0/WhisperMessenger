local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(640, 420)

  local view = ConversationPane.Create(factory, parent, nil, { messages = {} })
  assert(type(view.refreshTheme) == "function", "expected refreshTheme function on conversation view")

  local ok, err = pcall(function()
    view.refreshTheme()
  end)
  assert(ok, "refreshTheme should not raise an error: " .. tostring(err))

  -- test_theme_refresh_preserves_gold_invite_hint_color
  do
    local contact = { displayName = "Arthas", channel = "WOW", peerHasAddon = false }
    local invitePane = ConversationPane.Create(factory, parent, contact, { messages = {} })

    invitePane.refreshTheme()

    local tc = invitePane.headerAddonBadge.textColor
    local gold = Theme.TAG_GOLD
    assert(
      tc ~= nil and tc[1] == gold[1] and tc[2] == gold[2] and tc[3] == gold[3],
      "theme refresh should keep the invite hint gold, got: " .. tostring(tc and tc[1])
    )
  end

  print("  Conversation pane theme refresh tests passed")
end
