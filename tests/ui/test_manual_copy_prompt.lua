local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The copy popup's line above the text box: "copy the message text" by
-- default, a caller's own line (profile links) when given.

local DIALOG = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

return function()
  Localization.Configure({ language = "enUS" })
  local savedDialogs = _G.StaticPopupDialogs
  local savedShow = _G.StaticPopup_Show
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function()
    return nil
  end)

  -- test_copy_popup_uses_the_given_prompt
  do
    PopupUI.ShowManualCopyDialog("https://raider.io/characters/eu/kazzak/Thrall", { prompt = "Press Ctrl+C to copy the link." })
    local text = _G.StaticPopupDialogs[DIALOG].text
    assert(text == "Press Ctrl+C to copy the link.", "link prompt shown, got " .. tostring(text))
  end

  -- test_copy_popup_defaults_to_message_prompt
  do
    PopupUI.ShowManualCopyDialog("hello")
    local text = _G.StaticPopupDialogs[DIALOG].text
    assert(text == "Press Ctrl+C to copy the message text.", "message prompt by default, got " .. tostring(text))
  end

  -- test_copy_popup_prompt_is_translated
  do
    Localization.Configure({ language = "deDE" })
    PopupUI.ShowManualCopyDialog("x", { prompt = "Press Ctrl+C to copy the link." })
    local text = _G.StaticPopupDialogs[DIALOG].text
    assert(text ~= "Press Ctrl+C to copy the link.", "German prompt, got " .. tostring(text))
    Localization.Configure({ language = "enUS" })
  end

  _G.StaticPopupDialogs = savedDialogs
  rawset(_G, "StaticPopup_Show", savedShow)
end
