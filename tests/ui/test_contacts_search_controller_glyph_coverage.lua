local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ContactsSearchController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")

-- Searching for "Kőszívű" shows the typed letters in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local input = factory.CreateFrame("EditBox", nil, nil)
  input:SetFontObject(rawget(_G, "WM_ChatNormal"))
  local controller = ContactsSearchController.Create({
    contacts = {},
    contactsController = {
      refresh = function()
        return {}
      end,
    },
    contactsSearchInput = input,
    initialContacts = {},
  })
  controller.bindInputScripts()

  local function typeText(text)
    input:SetText(text)
    input.scripts.OnTextChanged(input, true)
  end

  -- test_searching_double_acute_letters_uses_the_wide_font
  typeText("kősz")
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the search box shows ő")

  -- test_plain_search_goes_back_to_the_usual_font
  typeText("jai")
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal"), "back to the usual font")
end
