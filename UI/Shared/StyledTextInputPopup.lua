local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PopupStyling = ns.ChatBubbleContextMenuManualCopyPopupUIStyling
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Styling")
local PopupResolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")
local PopupButtonStyling = ns.ChatBubbleContextMenuManualCopyPopupUIButtonStyling
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.ButtonStyling")

local StyledTextInputPopup = {}

local function resolveEditBox(dialog, dialogName)
  return PopupResolvers.resolvePopupEditBox(dialog, dialogName)
end

local function applyInputWidth(dialog, editBox, options)
  if type(editBox) ~= "table" or type(editBox.SetWidth) ~= "function" then
    return
  end

  options = options or {}
  local padding = options.inputHorizontalPadding or 14
  local width = options.inputWidth

  if width == nil and type(dialog) == "table" and type(dialog.GetWidth) == "function" then
    local dialogWidth = dialog:GetWidth()
    if type(dialogWidth) == "number" and dialogWidth > 0 then
      width = dialogWidth - (padding * 2)
    end
  end

  if type(width) ~= "number" or width <= 0 then
    return
  end

  local minWidth = options.minInputWidth or 220
  if width < minWidth then
    width = minWidth
  end

  editBox:SetWidth(width)
end

function StyledTextInputPopup.ResolveEditBox(dialog, dialogName)
  return resolveEditBox(dialog, dialogName)
end

function StyledTextInputPopup.Apply(dialog, dialogName, data, options)
  options = options or {}
  if type(dialog) ~= "table" then
    return nil
  end

  PopupStyling.styleManualCopyDialog(dialog, dialogName)
  if options.styleSecondaryButton == true then
    PopupButtonStyling.styleManualCopyButton(PopupResolvers.resolvePopupButton(dialog, 2))
  end

  local value = data
  if value == nil then
    value = dialog.data or ""
  end
  value = tostring(value)

  if options.primeEditBox ~= false then
    PopupResolvers.primePopupEditBox(dialog, value, dialogName)
  end

  local editBox = resolveEditBox(dialog, dialogName)
  if editBox and (options.fullWidthInput == true or type(options.inputWidth) == "number") then
    applyInputWidth(dialog, editBox, options)
  end

  return editBox
end

function StyledTextInputPopup.Restore(dialog, dialogName, options)
  options = options or {}
  if type(dialog) ~= "table" then
    return nil
  end

  PopupStyling.restoreManualCopyDialog(dialog, dialogName)
  if options.styleSecondaryButton == true then
    PopupButtonStyling.restoreManualCopyButton(PopupResolvers.resolvePopupButton(dialog, 2))
  end

  local editBox = resolveEditBox(dialog, dialogName)
  if options.clearEditBox ~= false and editBox and editBox.SetText then
    editBox:SetText("")
  end

  return editBox
end

ns.StyledTextInputPopup = StyledTextInputPopup

return StyledTextInputPopup
