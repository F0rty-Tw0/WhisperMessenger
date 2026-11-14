local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")

-- The nickname / note dialog's boxes sit on the chat-font twin, so a
-- nickname like "Kőszívű" shows while typing.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local dialog = TwoFieldDialog.Show(factory, { title = "Nickname", accept = "Save", firstLabel = "Nickname", secondLabel = "Note" })

  -- test_dialog_boxes_start_on_the_wide_font
  assert(dialog.firstInput:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the first box is on the wide font")
  assert(dialog.secondInput:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the second box is on the wide font")
end
