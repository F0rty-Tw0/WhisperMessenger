local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")

local StartConversationDialog = {}

local DIALOG_NAME = "WHISPER_MESSENGER_START_CONVERSATION"

local function trimPlayerName(value)
  if type(value) ~= "string" then
    return nil
  end

  local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
  if trimmed == "" then
    return nil
  end

  return trimmed
end

local function resolveConversationPopupEditBox(popup, dialogName)
  local resolved = StyledTextInputPopup.ResolveEditBox(popup, dialogName)
  if resolved ~= nil then
    return resolved
  end
  if type(popup) ~= "table" then
    return nil
  end
  if type(popup.editBox) == "table" then
    return popup.editBox
  end
  if type(popup.EditBox) == "table" then
    return popup.EditBox
  end
  if type(popup.GetEditBox) == "function" then
    local ok, editBox = pcall(popup.GetEditBox, popup)
    if ok then
      return editBox
    end
  end
  return nil
end

local function styleStartConversationDialog(popup, dialogName, value)
  StyledTextInputPopup.Apply(popup, dialogName, value, {
    styleSecondaryButton = true,
    fullWidthInput = true,
    inputHorizontalPadding = 14,
    minInputWidth = 260,
  })
end

local function restoreStartConversationDialog(popup, dialogName)
  StyledTextInputPopup.Restore(popup, dialogName, {
    styleSecondaryButton = true,
    clearEditBox = true,
  })
end

function StartConversationDialog.Wire(newConversationButton, options)
  options = options or {}
  if not newConversationButton or type(newConversationButton.SetScript) ~= "function" then
    return
  end
  if type(options.onStartConversation) ~= "function" then
    return
  end

  if type(_G.StaticPopupDialogs) ~= "table" then
    _G.StaticPopupDialogs = {}
  end

  local dialog = _G.StaticPopupDialogs[DIALOG_NAME]
  if type(dialog) ~= "table" then
    dialog = {
      text = "Start a new conversation",
      button1 = "Start",
      button2 = "Cancel",
      hasEditBox = true,
      editBoxWidth = 340,
      maxLetters = 255,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    _G.StaticPopupDialogs[DIALOG_NAME] = dialog
  end

  dialog.OnAccept = function(popup)
    local editBox = resolveConversationPopupEditBox(popup, DIALOG_NAME)
    local playerName = trimPlayerName(editBox and editBox.GetText and editBox:GetText() or nil)
    if playerName ~= nil and dialog._wmOnStartConversation then
      dialog._wmOnStartConversation(playerName)
    end
  end
  dialog._wmOnStartConversation = options.onStartConversation
  dialog.OnShow = function(popup, data)
    local value = tostring((popup and popup.data) or data or "")
    styleStartConversationDialog(popup, DIALOG_NAME, value)
  end
  dialog.OnHide = function(popup)
    restoreStartConversationDialog(popup, DIALOG_NAME)
  end

  newConversationButton:SetScript("OnClick", function()
    if type(_G.StaticPopup_Show) ~= "function" then
      return
    end

    local popup = _G.StaticPopup_Show(DIALOG_NAME)
    if type(popup) == "table" then
      popup.data = ""
      styleStartConversationDialog(popup, DIALOG_NAME, "")
    end

    local editBox = resolveConversationPopupEditBox(popup, DIALOG_NAME) or _G.StaticPopup1EditBox
    if editBox and editBox.SetFocus then
      editBox:SetFocus()
    end
  end)
end

ns.MessengerWindowWindowScriptsButtonsStartConversationDialog = StartConversationDialog

return StartConversationDialog
