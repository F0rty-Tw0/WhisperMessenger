local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Styled one-line text-entry popup (same look as "Start a new
-- conversation"), shared by the nickname, note and quick-reply dialogs.
local TextInputDialog = {}

local function ensureDialog(dialogName)
  if type(_G.StaticPopupDialogs) ~= "table" then
    _G.StaticPopupDialogs = {}
  end
  local dialog = _G.StaticPopupDialogs[dialogName]
  if type(dialog) == "table" then
    return dialog
  end

  dialog = StyledTextInputPopup.NewDialog()
  dialog.OnAccept = function(popup)
    local editBox = StyledTextInputPopup.ResolveEditBox(popup, dialogName)
    local text = editBox and editBox.GetText and editBox:GetText() or ""
    if dialog._wmOnAccept then
      dialog._wmOnAccept(text)
    end
  end
  -- Enter confirms, like the accept button.
  dialog.EditBoxOnEnterPressed = function(editBox)
    local popup = editBox.GetParent and editBox:GetParent() or nil
    if popup == nil then
      return
    end
    dialog.OnAccept(popup)
    popup:Hide()
  end
  dialog.OnShow = function(popup)
    StyledTextInputPopup.Apply(popup, dialogName, nil, StyledTextInputPopup.INPUT_STYLE)
  end
  dialog.OnHide = function(popup)
    StyledTextInputPopup.Restore(popup, dialogName, StyledTextInputPopup.RESTORE_STYLE)
  end
  _G.StaticPopupDialogs[dialogName] = dialog
  return dialog
end

-- spec: prompt and accept (localized labels), maxLetters / maxBytes, textArg
-- (fills %s in the prompt), value (primes the edit box), onAccept(text).
function TextInputDialog.Show(dialogName, spec)
  if type(_G.StaticPopup_Show) ~= "function" then
    return false
  end
  local dialog = ensureDialog(dialogName)
  dialog.text = spec.prompt
  dialog.button1 = spec.accept
  dialog.button2 = Localization.Text("Cancel")
  dialog.maxLetters = spec.maxLetters
  dialog.maxBytes = spec.maxBytes
  dialog._wmOnAccept = spec.onAccept
  _G.StaticPopup_Show(dialogName, spec.textArg, nil, spec.value)
  return true
end

ns.TextInputDialog = TextInputDialog
return TextInputDialog
