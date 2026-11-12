local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

-- Contact names and previews with "ő" or "ű" draw in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.classIconFrame = factory.CreateFrame("Frame", nil, row)
  local item = { displayName = "Kőszívű", lastPreview = "szia", conversationKey = "me::WOW::k" }

  -- test_contact_name_with_double_acute_letters_uses_the_wide_font
  RowElements.createNameLabel(row, item, 260)
  assert(row.title:GetFontObject() == rawget(_G, "WM_Normal_Wide"), "the name needs the chat font")

  -- test_plain_contact_name_goes_back_to_the_usual_font
  RowElements.updateNameLabel(row, { displayName = "Jaina" }, 260)
  assert(row.title:GetFontObject() == rawget(_G, "WM_Normal"), "a plain name keeps the theme font")

  -- test_faction_refresh_keeps_the_name_on_the_wide_font
  row.item = item
  RowElements.createFactionIcon(factory, row, item, nil)
  assert(row.title:GetFontObject() == rawget(_G, "WM_Normal_Wide"), "the faction pass sets the name too")

  -- test_preview_with_double_acute_letters_uses_the_wide_font
  RowElements.createPreview(row, { lastPreview = "jössz, főnök?" }, 260)
  assert(row.preview:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the preview needs the chat font")

  -- test_preview_keeps_its_grey_colour_on_the_wide_font
  local r, g, b = row.preview:GetTextColor()
  local grey = Theme.COLORS.text_secondary
  assert(r == grey[1] and g == grey[2] and b == grey[3], "the preview stays grey")

  -- test_plain_preview_goes_back_to_the_usual_font
  RowElements.updatePreview(row, { lastPreview = "hi" }, 260, false, nil)
  assert(row.preview:GetFontObject() == rawget(_G, "WM_DisableSmall"), "a plain preview keeps the theme font")

  -- test_draft_preview_with_double_acute_letters_uses_the_wide_font
  RowElements.updatePreview(row, { lastPreview = "hi", draft = "főnök", conversationKey = "a" }, 260, false, "b")
  assert(row.preview:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the draft needs the chat font")

  -- test_typing_preview_goes_back_to_the_usual_font
  RowElements.updatePreview(row, { isTyping = true }, 260, false, nil)
  assert(row.preview:GetFontObject() == rawget(_G, "WM_DisableSmall"), "typing… keeps the theme font")
end
