-- The addon's text popups borrow the game's StaticPopup edit box, whose font
-- lacks letters like ő and ű on some clients: it draws in the chat font while
-- the popup is up and gets its own font back when the popup closes.
local FakeUI = require("tests.helpers.fake_ui")
local FontBox = require("tests.helpers.font_box")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

local function makePopup(factory)
  local popup = factory.CreateFrame("Frame", nil, nil)
  popup:SetWidth(420)
  popup.editBox = FontBox.Give(factory.CreateFrame("EditBox", nil, popup), FontBox.FRIZ, 14, "")
  popup.text = factory.CreateFrame("FontString", nil, popup)
  return popup
end

return function()
  local factory = FakeUI.NewFactory()

  for _, nativeChrome in ipairs({ true, false }) do
    StyledTextInputPopup.nativeChrome = nativeChrome
    local label = nativeChrome and "native" or "modern"

    -- test_popup_box_draws_in_the_chat_font_while_shown
    local popup = makePopup(factory)
    StyledTextInputPopup.Apply(popup, "WM_TEST", "", StyledTextInputPopup.INPUT_STYLE)
    assert(popup.editBox:GetFont() == FontBox.CHAT, label .. ": box on the chat font, got " .. tostring(popup.editBox:GetFont()))

    -- test_popup_box_gets_its_own_font_back_on_close
    StyledTextInputPopup.Apply(popup, "WM_TEST", "", StyledTextInputPopup.INPUT_STYLE)
    StyledTextInputPopup.Restore(popup, "WM_TEST", StyledTextInputPopup.RESTORE_STYLE)
    local path, size = popup.editBox:GetFont()
    assert(path == FontBox.FRIZ and size == 14, label .. ": box back on its own font after a double show, got " .. tostring(path))
  end

  StyledTextInputPopup.nativeChrome = false
end
