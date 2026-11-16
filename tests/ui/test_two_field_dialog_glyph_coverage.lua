local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")

-- The nickname / note dialog's boxes start on their base font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local dialog = TwoFieldDialog.Show(factory, { title = "Nickname", accept = "Save", firstLabel = "Nickname", secondLabel = "Note" })

  -- test_dialog_boxes_start_on_the_base_font
  local base = rawget(_G, "WM_ChatNormal")
  assert(dialog.firstInput.fontObject == base, "the first box is on the base font")
  assert(dialog.secondInput.fontObject == base, "the second box is on the base font")
  assert(dialog.firstInput:GetFont() == "Fonts\\FRIZQT__.TTF", "the first box is on the base font file")
  assert(dialog.secondInput:GetFont() == "Fonts\\FRIZQT__.TTF", "the second box is on the base font file")

  -- test_typing_ő_moves_both_boxes_to_the_chat_font_and_back
  dialog.firstInput:SetText("Kőszívű")
  dialog.firstInput:GetScript("OnTextChanged")(dialog.firstInput)
  assert(dialog.firstInput:GetFont() == "Fonts\\ARIALN.TTF", "ő moves the first box to the chat font")
  dialog.secondInput:SetText("Kőszívű")
  dialog.secondInput:GetScript("OnTextChanged")(dialog.secondInput)
  assert(dialog.secondInput:GetFont() == "Fonts\\ARIALN.TTF", "ő moves the second box to the chat font")
  dialog.firstInput:SetText("Koszivu")
  dialog.firstInput:GetScript("OnTextChanged")(dialog.firstInput)
  assert(dialog.firstInput:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text moves the first box back")
  dialog.secondInput:SetText("Koszivu")
  dialog.secondInput:GetScript("OnTextChanged")(dialog.secondInput)
  assert(dialog.secondInput:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text moves the second box back")

  -- test_prefill_with_ő_starts_the_box_on_the_chat_font
  local prefilled = TwoFieldDialog.Show(factory, {
    title = "Nickname",
    accept = "Save",
    firstLabel = "Nickname",
    secondLabel = "Note",
    firstValue = "tűz",
    secondValue = "tűz",
  })
  assert(prefilled.firstInput:GetFont() == "Fonts\\ARIALN.TTF", "a prefilled first box starts on the chat font")
  assert(prefilled.secondInput:GetFont() == "Fonts\\ARIALN.TTF", "a prefilled second box starts on the chat font")
end
