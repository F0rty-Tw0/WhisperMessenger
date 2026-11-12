local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

-- A sender called "Kőszívű" shows the name in the chat font, not as squares.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  local function render(message)
    return SenderLabel.CreateSenderLabel(factory, contentFrame, message, 400, 0)
  end

  -- test_incoming_sender_name_uses_the_wide_font
  do
    local result = render({ direction = "in", playerName = "Kőszívű" })
    assert(result.frame._wmSenderNameFS:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the name needs the chat font")
  end

  -- test_plain_sender_name_keeps_the_usual_font
  do
    local result = render({ direction = "in", playerName = "Jaina" })
    assert(result.frame._wmSenderNameFS:GetFontObject() == rawget(_G, "WM_DisableSmall"), "a plain name keeps the theme font")
  end

  -- test_outgoing_alt_name_uses_the_wide_font
  do
    local savedUnitName = rawget(_G, "UnitName")
    rawset(_G, "UnitName", function()
      return "Arthas"
    end)
    local result = render({ direction = "out", senderName = "Łucja" })
    rawset(_G, "UnitName", savedUnitName)
    assert(result.frame._wmSenderCharnameFS:GetFontObject() == rawget(_G, "WM_DisableSmall_Wide"), "the alt's name needs the chat font")
  end
end
