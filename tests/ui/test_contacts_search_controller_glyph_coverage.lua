local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ContactsSearchUI = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local ContactsSearchController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")

-- The search box starts on its base font and stays on it for plain text.
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

  -- test_search_box_starts_on_the_base_font_before_typing
  local base = rawget(_G, "WM_ChatNormal")
  assert(input.fontObject == base, "the search box is on the base font before typing")
  assert(input:GetFont() == "Fonts\\FRIZQT__.TTF", "on the base font file, got " .. tostring(input:GetFont()))

  -- test_plain_searching_keeps_the_base_font
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
  assert(input.fontObject == base and input:GetFont() == "Fonts\\FRIZQT__.TTF", "plain search stays on the base font")

  -- test_typing_ő_moves_the_search_box_to_the_chat_font_and_back
  input:SetText("Kőszívű")
  input.scripts.OnTextChanged(input, true)
  assert(input:GetFont() == "Fonts\\ARIALN.TTF", "ő moves the search box to the chat font, got " .. tostring(input:GetFont()))
  input:SetText("jai")
  input.scripts.OnTextChanged(input, true)
  assert(input:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text moves it back, got " .. tostring(input:GetFont()))

  -- test_native_search_box_swaps_from_its_own_face
  local FontBox = require("tests.helpers.font_box")
  local nativeFactory = FontBox.Factory(FakeUI.NewFactory({ fontColors = true }), FontBox.FRIZ)
  local nativePane = nativeFactory.CreateFrame("Frame", nil, nil)
  nativePane:SetSize(260, 500)
  local native = ContactsSearchUI.Build(nativeFactory, nativePane, {
    contactsWidth = 260,
    searchMargin = 10,
    searchHeight = 30,
    searchClearButtonSize = 18,
    nativeChrome = true,
  })
  assert(native.native == true, "the native search box is built")
  local nativeInput = native.input
  assert(nativeInput:GetFont() == FontBox.FRIZ, "the empty native box keeps its own face")
  local nativeController = ContactsSearchController.Create({
    contacts = {},
    contactsController = {
      refresh = function()
        return {}
      end,
    },
    contactsSearchInput = nativeInput,
    initialContacts = {},
  })
  nativeController.bindInputScripts()
  nativeInput:SetText("Kőszívű")
  nativeInput.scripts.OnTextChanged(nativeInput, true)
  assert(nativeInput:GetFont() == FontBox.CHAT, "ő moves the native box to the chat font, got " .. tostring(nativeInput:GetFont()))
  nativeInput:SetText("")
  nativeInput.scripts.OnTextChanged(nativeInput, true)
  assert(nativeInput:GetFont() == FontBox.FRIZ, "clearing it restores the box's own face, got " .. tostring(nativeInput:GetFont()))
end
