local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PopupUI = {}
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local Resolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")
local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil

local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

local function L(key)
  if Localization and Localization.Text then
    return Localization.Text(key)
  end
  return key
end

-- Refresh the dialog's localized strings every time it's about to show so a
-- runtime language switch picks up immediately. The StaticPopupDialogs entry
-- is read each Show, so writing to it before StaticPopup_Show is sufficient.
local function applyDialogText(dialog)
  if type(dialog) ~= "table" then
    return
  end
  dialog.text = L("Press Ctrl+C to copy the message text.")
  dialog.button1 = L("OK")
end

local function isFrameShown(frame)
  if type(frame) ~= "table" then
    return false
  end
  if type(frame.IsShown) == "function" then
    return frame:IsShown() == true
  end
  return true
end

local function scheduleManualCopyRefocus(dialog, text, delaySeconds)
  _G.C_Timer.After(delaySeconds, function()
    if isFrameShown(dialog) then
      Resolvers.primePopupEditBox(dialog, text, MANUAL_COPY_DIALOG_NAME)
    end
  end)
end

function PopupUI.ShowManualCopyDialog(text)
  if type(_G.StaticPopup_Show) ~= "function" then
    return false
  end

  if type(_G.StaticPopupDialogs) ~= "table" then
    _G.StaticPopupDialogs = {}
  end

  if _G.StaticPopupDialogs[MANUAL_COPY_DIALOG_NAME] == nil then
    _G.StaticPopupDialogs[MANUAL_COPY_DIALOG_NAME] = {
      hasEditBox = true,
      editBoxWidth = 340,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnShow = function(self, data)
        local value = tostring((self and self.data) or data or "")
        StyledTextInputPopup.Apply(self, MANUAL_COPY_DIALOG_NAME, value, {
          fullWidthInput = true,
          inputHorizontalPadding = 14,
          minInputWidth = 260,
        })
      end,
      EditBoxOnEscapePressed = function(self)
        if self and self.ClearFocus then
          self:ClearFocus()
        end
        local parent = self and self.GetParent and self:GetParent()
        if parent and parent.Hide then
          parent:Hide()
        end
      end,
      OnHide = function(self)
        StyledTextInputPopup.Restore(self, MANUAL_COPY_DIALOG_NAME, { clearEditBox = true })
      end,
    }
  end
  applyDialogText(_G.StaticPopupDialogs[MANUAL_COPY_DIALOG_NAME])

  local dialog = _G.StaticPopup_Show(MANUAL_COPY_DIALOG_NAME, nil, nil, text)
  if dialog == nil then
    return false
  end

  dialog.data = text
  StyledTextInputPopup.Apply(dialog, MANUAL_COPY_DIALOG_NAME, text, {
    fullWidthInput = true,
    inputHorizontalPadding = 14,
    minInputWidth = 260,
  })

  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    scheduleManualCopyRefocus(dialog, text, 0)
    scheduleManualCopyRefocus(dialog, text, 0.05)
  end

  return true
end

ns.ChatBubbleContextMenuManualCopyPopupUI = PopupUI
return PopupUI
