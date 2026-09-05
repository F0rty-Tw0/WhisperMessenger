local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)

  local selectedContact = { conversationKey = "me::WOW::arthas-area52", displayName = "Arthas-Area52", channel = "WOW" }
  local calls = {}
  local composer = Composer.Create(factory, parent, selectedContact, function() end, nil, nil, function(contact, text)
    table.insert(calls, { contact = contact, text = text })
  end)

  -- test_text_change_reports_contact_and_text
  composer.input:SetText("hey")
  composer.input.scripts.OnTextChanged(composer.input)
  assert(#calls == 1, "typing callback fired once")
  assert(calls[1].contact == selectedContact and calls[1].text == "hey", "callback receives contact and text")

  -- test_clearing_reports_empty_text
  composer.input:SetText("")
  composer.input.scripts.OnTextChanged(composer.input)
  assert(calls[2].text == "", "clear reported")
end
