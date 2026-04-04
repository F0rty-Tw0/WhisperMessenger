local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Resolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")
local StylingCommon = ns.ChatBubbleContextMenuManualCopyPopupUIStylingCommon
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.StylingCommon")

local ButtonStyling = {}

local function paintManualCopyButton(button)
  if type(button) ~= "table" then
    return
  end

  local baseBg = Theme.COLORS.option_button_bg or Theme.COLORS.bg_secondary or Theme.COLORS.bg_primary
  local hoverBg = Theme.COLORS.option_button_hover or baseBg
  local borderColor = Theme.COLORS.divider or hoverBg
  local baseText = Theme.COLORS.option_button_text or Theme.COLORS.text_primary
  local hoverText = Theme.COLORS.option_button_text_hover or baseText

  if button._wmManualCopySkin and button._wmManualCopySkin.setColor and baseBg then
    button._wmManualCopySkin.setColor(button._wmManualCopyHovered and hoverBg or baseBg)
    StylingCommon.setPartsShown(button._wmManualCopySkin, true)
  end
  if button._wmManualCopyBorder and borderColor then
    UIHelpers.applyBorderBoxColor(button._wmManualCopyBorder, borderColor)
    StylingCommon.setPartsShown(button._wmManualCopyBorder, true)
  end

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  if label then
    StylingCommon.applyTextColor(label, button._wmManualCopyHovered and hoverText or baseText)
  end
end

function ButtonStyling.restoreManualCopyButton(button)
  if type(button) ~= "table" then
    return
  end
  if button._wmManualCopyRestoring == true then
    return
  end
  button._wmManualCopyRestoring = true

  button._wmManualCopyStyleActive = false
  button._wmManualCopyHovered = false
  StylingCommon.setPartsShown(button._wmManualCopySkin, false)
  StylingCommon.setPartsShown(button._wmManualCopyBorder, false)

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  if label and button._wmManualCopyOriginalTextColor then
    StylingCommon.applyTextColor(label, button._wmManualCopyOriginalTextColor)
  end

  if button.SetNormalTexture then
    button:SetNormalTexture(button._wmManualCopyOriginalNormalTexture)
  end
  if button.SetHighlightTexture then
    button:SetHighlightTexture(button._wmManualCopyOriginalHighlightTexture)
  end
  if button.SetPushedTexture then
    button:SetPushedTexture(button._wmManualCopyOriginalPushedTexture)
  end
  if button.SetDisabledTexture then
    button:SetDisabledTexture(button._wmManualCopyOriginalDisabledTexture)
  end
  StylingCommon.restoreSuppressedFrameTextures(button, "_wmManualCopySuppressedRegions")

  local originalOnEnter = button._wmManualCopyOriginalOnEnter
  local originalOnLeave = button._wmManualCopyOriginalOnLeave

  button._wmManualCopyOriginalOnEnter = nil
  button._wmManualCopyOriginalOnLeave = nil
  button._wmManualCopyOriginalNormalTexture = nil
  button._wmManualCopyOriginalHighlightTexture = nil
  button._wmManualCopyOriginalPushedTexture = nil
  button._wmManualCopyOriginalDisabledTexture = nil
  button._wmManualCopyRanOriginalHover = nil

  if button.SetScript then
    button:SetScript("OnEnter", originalOnEnter)
    button:SetScript("OnLeave", originalOnLeave)
  end

  button._wmManualCopyRestoring = false
end

function ButtonStyling.styleManualCopyButton(button)
  if type(button) ~= "table" then
    return
  end

  if
    button._wmManualCopySkin == nil
    and type(button.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    button._wmManualCopySkin = UIHelpers.createRoundedBackground(button, 6)
    StylingCommon.setPartsShown(button._wmManualCopySkin, false)
  end
  if button._wmManualCopyBorder == nil and type(UIHelpers.createBorderBox) == "function" then
    button._wmManualCopyBorder = UIHelpers.createBorderBox(button, Theme.COLORS.divider, 1, "BORDER")
    StylingCommon.setPartsShown(button._wmManualCopyBorder, false)
  end

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  button._wmManualCopyLabel = label
  if label and button._wmManualCopyStyleActive ~= true then
    button._wmManualCopyOriginalTextColor = StylingCommon.captureTextColor(label)
  end

  if button._wmManualCopyStyleActive ~= true then
    local skipSet = StylingCommon.collectTextureParts(button._wmManualCopySkin, {})
    StylingCommon.collectTextureParts(button._wmManualCopyBorder, skipSet)
    StylingCommon.suppressFrameTextures(button, "_wmManualCopySuppressedRegions", skipSet)

    if button.GetNormalTexture then
      button._wmManualCopyOriginalNormalTexture = button:GetNormalTexture()
    end
    if button.GetHighlightTexture then
      button._wmManualCopyOriginalHighlightTexture = button:GetHighlightTexture()
    end
    if button.GetPushedTexture then
      button._wmManualCopyOriginalPushedTexture = button:GetPushedTexture()
    end
    if button.GetDisabledTexture then
      button._wmManualCopyOriginalDisabledTexture = button:GetDisabledTexture()
    end
    if button.SetNormalTexture then
      button:SetNormalTexture("")
    end
    if button.SetHighlightTexture then
      button:SetHighlightTexture("")
    end
    if button.SetPushedTexture then
      button:SetPushedTexture("")
    end
    if button.SetDisabledTexture then
      button:SetDisabledTexture("")
    end

    if button.SetScript then
      button._wmManualCopyOriginalOnEnter = button.GetScript and button:GetScript("OnEnter") or nil
      button._wmManualCopyOriginalOnLeave = button.GetScript and button:GetScript("OnLeave") or nil

      if button._wmManualCopyOnEnterWrapper == nil then
        button._wmManualCopyOnEnterWrapper = function(self, ...)
          local originalOnEnter = self._wmManualCopyOriginalOnEnter
          if originalOnEnter then
            originalOnEnter(self, ...)
            self._wmManualCopyRanOriginalHover = true
          end
          if self._wmManualCopyStyleActive then
            self._wmManualCopyHovered = true
            paintManualCopyButton(self)
          end
        end
        button._wmManualCopyOnLeaveWrapper = function(self, ...)
          local originalOnLeave = self._wmManualCopyOriginalOnLeave
          if originalOnLeave then
            originalOnLeave(self, ...)
          end
          self._wmManualCopyRanOriginalHover = false
          if self._wmManualCopyStyleActive then
            self._wmManualCopyHovered = false
            paintManualCopyButton(self)
          end
        end
      end

      button:SetScript("OnEnter", button._wmManualCopyOnEnterWrapper)
      button:SetScript("OnLeave", button._wmManualCopyOnLeaveWrapper)
    end
  end

  button._wmManualCopyStyleActive = true
  button._wmManualCopyHovered = button.IsMouseOver and button:IsMouseOver() or false
  button._wmManualCopyRanOriginalHover = false
  paintManualCopyButton(button)
end

ns.ChatBubbleContextMenuManualCopyPopupUIButtonStyling = ButtonStyling

return ButtonStyling
