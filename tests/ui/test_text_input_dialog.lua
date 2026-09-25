local TextInputDialog = require("WhisperMessenger.UI.Shared.TextInputDialog")
local Localization = require("WhisperMessenger.Locale.Localization")

-- One styled text-entry popup builder: Show fills the prompt, buttons and
-- limits, primes the edit box, and Accept / Enter hand back the typed text.
return function()
  Localization.Configure({ language = "enUS" })
  local shown = {}
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name, textArg, _, data)
    shown = { name = name, textArg = textArg, data = data }
  end)

  local accepted = {}
  local ok = TextInputDialog.Show("WM_TEST_DIALOG", {
    prompt = "Note for %s.",
    accept = "Save",
    maxBytes = 256,
    textArg = "Thrall",
    value = "old note",
    onAccept = function(text)
      accepted[#accepted + 1] = text
    end,
  })

  -- test_show_fills_the_dialog
  local dialog = _G.StaticPopupDialogs.WM_TEST_DIALOG
  assert(ok == true and shown.name == "WM_TEST_DIALOG", "popup shown")
  assert(dialog.text == "Note for %s." and dialog.button1 == "Save" and dialog.button2 == "Cancel", "texts set")
  assert(dialog.maxBytes == 256 and dialog.hasEditBox == true, "edit box with its limit")
  assert(shown.textArg == "Thrall" and shown.data == "old note", "prompt name and current value passed on")

  -- test_enter_accepts_the_typed_text_and_closes
  local hidden = false
  local popup
  popup = {
    editBox = {
      frameType = "EditBox",
      GetText = function()
        return "new note"
      end,
      SetText = function() end,
      GetParent = function()
        return popup
      end,
    },
    Hide = function()
      hidden = true
    end,
  }
  dialog.EditBoxOnEnterPressed(popup.editBox)
  assert(accepted[1] == "new note" and hidden, "Enter saves and closes")

  -- test_missing_static_popup_is_safe
  rawset(_G, "StaticPopup_Show", nil)
  assert(TextInputDialog.Show("WM_TEST_DIALOG", { onAccept = function() end }) == false, "no popup API: nothing shown")
  _G.StaticPopupDialogs = nil
end
