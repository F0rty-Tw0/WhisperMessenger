local FakeUI = require("tests.helpers.fake_ui")
local DragGhost = require("WhisperMessenger.UI.MessengerWindow.DragGhost")

return function()
  local factory = FakeUI.NewFactory()
  local list = factory.CreateFrame("Frame", nil, nil)
  local ghost = DragGhost.Create(factory, list)
  local sourceRow = factory.CreateFrame("Button", nil, list)
  sourceRow.item = { displayName = "Arthas#1234" }

  -- test_ghost_label_hides_battletag_numbers
  DragGhost.Show(ghost, sourceRow, list)
  assert(ghost.label.text == "Arthas", "drag ghost hides the BattleTag number, got " .. tostring(ghost.label.text))
end
