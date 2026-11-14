local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ContactsSearchUI = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local ContactsSearchController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")

-- The search box sits on the chat-font twin from the start, so searching
-- for "Kőszívű" shows the typed letters.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(260, 500)
  local search = ContactsSearchUI.Build(factory, pane, {
    contactsWidth = 260,
    searchMargin = 10,
    searchHeight = 30,
    searchClearButtonSize = 18,
  })
  local input = search.input

  -- test_search_box_starts_on_the_wide_font_before_typing
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the search box is on the wide font before typing")

  -- test_searching_keeps_the_wide_font
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
  input:SetText("jai")
  input.scripts.OnTextChanged(input, true)
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "plain search stays on the wide font")
end
