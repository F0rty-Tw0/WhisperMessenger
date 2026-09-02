local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local row = factory.CreateFrame("Button", nil, nil)
  row.bg = row:CreateTexture(nil, "BACKGROUND")

  RowScripts.bindHover(row)

  assert(row:GetScript("OnUpdate") == nil, "bindHover should not install OnUpdate before hover begins")
end
