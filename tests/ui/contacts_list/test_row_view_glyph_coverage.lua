local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local FakeUI = require("tests.helpers.fake_ui")

-- A community called "Főnökök" shows its name in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  local options = { onSelect = function() end }

  -- test_group_row_title_with_double_acute_letters_uses_the_wide_font
  local row = RowView.bindRow(factory, parent, nil, 1, {
    conversationKey = "me::COMMUNITY::1",
    channel = ChannelType.COMMUNITY,
    title = "Főnökök",
    displayName = "Raiders",
    lastActivityAt = 100,
  }, options)
  assert(row.title.text == "Főnökök", "the row shows the community title, got " .. tostring(row.title.text))
  assert(row.title:GetFontObject() == rawget(_G, "WM_Normal_Wide"), "the title needs the chat font")
end
