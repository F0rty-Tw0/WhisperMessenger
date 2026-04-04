local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PopupUI = {}
local Styling = ns.ChatBubbleContextMenuManualCopyPopupUIStyling
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Styling")
local Resolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")

local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

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
      text = "Press Ctrl+C to copy the message text.",
      button1 = _G["OKAY"] or "OK",
      hasEditBox = true,
      editBoxWidth = 320,
      timeout = 0,
      whileDead = 1,
      hideOnEscape = 1,
      preferredIndex = 3,
      OnShow = function(self, data)
        local value = tostring((self and self.data) or data or "")
        Styling.styleManualCopyDialog(self, MANUAL_COPY_DIALOG_NAME)
        Resolvers.primePopupEditBox(self, value, MANUAL_COPY_DIALOG_NAME)
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
        Styling.restoreManualCopyDialog(self, MANUAL_COPY_DIALOG_NAME)
        local editBox = Resolvers.resolvePopupEditBox(self, MANUAL_COPY_DIALOG_NAME)
        if editBox and editBox.SetText then
          editBox:SetText("")
        end
      end,
    }
  end

  local dialog = _G.StaticPopup_Show(MANUAL_COPY_DIALOG_NAME, nil, nil, text)
  if dialog == nil then
    return false
  end

  dialog.data = text
  Styling.styleManualCopyDialog(dialog, MANUAL_COPY_DIALOG_NAME)
  Resolvers.primePopupEditBox(dialog, text, MANUAL_COPY_DIALOG_NAME)

  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    scheduleManualCopyRefocus(dialog, text, 0)
    scheduleManualCopyRefocus(dialog, text, 0.05)
  end

  return true
end

ns.ChatBubbleContextMenuManualCopyPopupUI = PopupUI
return PopupUI
