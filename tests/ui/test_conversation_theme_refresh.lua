local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")

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

  print("  Conversation pane theme refresh tests passed")
end
