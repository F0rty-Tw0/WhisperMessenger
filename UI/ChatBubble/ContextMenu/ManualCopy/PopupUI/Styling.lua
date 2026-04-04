local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Resolvers = ns.ChatBubbleContextMenuManualCopyPopupUIResolvers
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI.Resolvers")

local Styling = {}
local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

local function setPartsShown(parts, shown)
  if type(parts) ~= "table" then
    return
  end

  local function setShown(part)
    if type(part) ~= "table" then
      return
    end
    if shown then
      if part.Show then
        part:Show()
      end
    elseif part.Hide then
      part:Hide()
    end
  end

  if type(parts.fills) == "table" then
    for _, part in ipairs(parts.fills) do
      setShown(part)
    end
  end
  if type(parts.corners) == "table" then
    for _, part in ipairs(parts.corners) do
      setShown(part)
    end
  end

  for _, part in pairs(parts) do
    setShown(part)
  end
end

local function captureTextColor(fontString)
  if type(fontString) ~= "table" then
    return nil
  end
  if type(fontString.GetTextColor) == "function" then
    local r, g, b, a = fontString:GetTextColor()
    if r ~= nil then
      return { r, g, b, a or 1 }
    end
  end
  if type(fontString.textColor) == "table" then
    return {
      fontString.textColor[1],
      fontString.textColor[2],
      fontString.textColor[3],
      fontString.textColor[4],
    }
  end
  return nil
end

local function applyTextColor(fontString, color)
  if type(fontString) ~= "table" or type(color) ~= "table" then
    return
  end
  if UIHelpers.setTextColor then
    UIHelpers.setTextColor(fontString, color)
    return
  end
  if fontString.SetTextColor then
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function isTextureRegion(region)
  if type(region) ~= "table" then
    return false
  end
  if type(region.GetObjectType) == "function" then
    return region:GetObjectType() == "Texture"
  end
  return region.frameType == "Texture"
end

local function regionShown(region)
  if type(region) ~= "table" then
    return false
  end
  if type(region.IsShown) == "function" then
    return region:IsShown() == true
  end
  return region.shown == true
end

local function collectTextureParts(parts, out)
  if type(parts) ~= "table" then
    return out
  end
  out = out or {}

  if type(parts.fills) == "table" then
    for _, texture in ipairs(parts.fills) do
      out[texture] = true
    end
  end
  if type(parts.corners) == "table" then
    for _, texture in ipairs(parts.corners) do
      out[texture] = true
    end
  end
  for _, texture in pairs(parts) do
    if isTextureRegion(texture) then
      out[texture] = true
    end
  end

  return out
end

local function suppressFrameTextures(frame, stateKey, skipSet)
  if type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
    return
  end
  local snapshots = {}
  for _, region in ipairs({ frame:GetRegions() }) do
    if isTextureRegion(region) and not (skipSet and skipSet[region]) then
      local snapshot = {
        region = region,
        shown = regionShown(region),
      }
      if type(region.GetAlpha) == "function" then
        snapshot.alpha = region:GetAlpha()
      else
        snapshot.alpha = region.alpha
      end
      snapshots[#snapshots + 1] = snapshot

      if type(region.SetAlpha) == "function" then
        region:SetAlpha(0)
      end
      if type(region.Hide) == "function" then
        region:Hide()
      end
    end
  end
  frame[stateKey] = snapshots
end

local function restoreSuppressedFrameTextures(frame, stateKey)
  if type(frame) ~= "table" then
    return
  end
  local snapshots = frame[stateKey]
  if type(snapshots) ~= "table" then
    return
  end
  for _, snapshot in ipairs(snapshots) do
    local region = snapshot.region
    if type(region) == "table" then
      if snapshot.alpha ~= nil and type(region.SetAlpha) == "function" then
        region:SetAlpha(snapshot.alpha)
      end
      if snapshot.shown and type(region.Show) == "function" then
        region:Show()
      elseif not snapshot.shown and type(region.Hide) == "function" then
        region:Hide()
      end
    end
  end
  frame[stateKey] = nil
end

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
    setPartsShown(button._wmManualCopySkin, true)
  end
  if button._wmManualCopyBorder and borderColor then
    UIHelpers.applyBorderBoxColor(button._wmManualCopyBorder, borderColor)
    setPartsShown(button._wmManualCopyBorder, true)
  end

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  if label then
    applyTextColor(label, button._wmManualCopyHovered and hoverText or baseText)
  end
end

local function restoreManualCopyButton(button)
  if type(button) ~= "table" then
    return
  end
  if button._wmManualCopyRestoring == true then
    return
  end
  button._wmManualCopyRestoring = true

  button._wmManualCopyStyleActive = false
  button._wmManualCopyHovered = false
  setPartsShown(button._wmManualCopySkin, false)
  setPartsShown(button._wmManualCopyBorder, false)

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  if label and button._wmManualCopyOriginalTextColor then
    applyTextColor(label, button._wmManualCopyOriginalTextColor)
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
  restoreSuppressedFrameTextures(button, "_wmManualCopySuppressedRegions")

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

local function styleManualCopyButton(button)
  if type(button) ~= "table" then
    return
  end

  if
    button._wmManualCopySkin == nil
    and type(button.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    button._wmManualCopySkin = UIHelpers.createRoundedBackground(button, 6)
    setPartsShown(button._wmManualCopySkin, false)
  end
  if button._wmManualCopyBorder == nil and type(UIHelpers.createBorderBox) == "function" then
    button._wmManualCopyBorder = UIHelpers.createBorderBox(button, Theme.COLORS.divider, 1, "BORDER")
    setPartsShown(button._wmManualCopyBorder, false)
  end

  local label = button._wmManualCopyLabel or Resolvers.resolvePopupButtonLabel(button)
  button._wmManualCopyLabel = label
  if label and button._wmManualCopyStyleActive ~= true then
    button._wmManualCopyOriginalTextColor = captureTextColor(label)
  end

  if button._wmManualCopyStyleActive ~= true then
    local skipSet = collectTextureParts(button._wmManualCopySkin, {})
    collectTextureParts(button._wmManualCopyBorder, skipSet)
    suppressFrameTextures(button, "_wmManualCopySuppressedRegions", skipSet)

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

local function restoreManualCopyEditBox(editBox)
  if type(editBox) ~= "table" then
    return
  end

  setPartsShown(editBox._wmManualCopyBackground, false)
  setPartsShown(editBox._wmManualCopyBorder, false)
  restoreSuppressedFrameTextures(editBox, "_wmManualCopySuppressedRegions")
  editBox._wmManualCopyStyleActive = false

  local insets = editBox._wmManualCopyOriginalTextInsets
  if editBox._wmManualCopyOriginalTextColor ~= nil then
    applyTextColor(editBox, editBox._wmManualCopyOriginalTextColor)
  end
  if insets and editBox.SetTextInsets then
    editBox:SetTextInsets(insets[1] or 0, insets[2] or 0, insets[3] or 0, insets[4] or 0)
  end
end

local function styleManualCopyEditBox(editBox)
  if type(editBox) ~= "table" then
    return
  end

  if
    editBox._wmManualCopyBackground == nil
    and type(editBox.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    editBox._wmManualCopyBackground = UIHelpers.createRoundedBackground(editBox, 6)
    setPartsShown(editBox._wmManualCopyBackground, false)
  end
  if editBox._wmManualCopyBorder == nil and type(UIHelpers.createBorderBox) == "function" then
    editBox._wmManualCopyBorder = UIHelpers.createBorderBox(editBox, Theme.COLORS.divider, 1, "BORDER")
    setPartsShown(editBox._wmManualCopyBorder, false)
  end

  if editBox._wmManualCopyStyleActive ~= true then
    local skipSet = collectTextureParts(editBox._wmManualCopyBackground, {})
    collectTextureParts(editBox._wmManualCopyBorder, skipSet)
    suppressFrameTextures(editBox, "_wmManualCopySuppressedRegions", skipSet)

    editBox._wmManualCopyOriginalTextColor = captureTextColor(editBox)
    if type(editBox.GetTextInsets) == "function" then
      local left, right, top, bottom = editBox:GetTextInsets()
      editBox._wmManualCopyOriginalTextInsets = { left, right, top, bottom }
    elseif type(editBox.textInsets) == "table" then
      editBox._wmManualCopyOriginalTextInsets = {
        editBox.textInsets[1],
        editBox.textInsets[2],
        editBox.textInsets[3],
        editBox.textInsets[4],
      }
    else
      editBox._wmManualCopyOriginalTextInsets = nil
    end
  end
  editBox._wmManualCopyStyleActive = true

  if editBox.SetTextColor and Theme.COLORS.text_primary then
    local color = Theme.COLORS.text_primary
    editBox:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
  if editBox._wmManualCopyBackground and editBox._wmManualCopyBackground.setColor and Theme.COLORS.bg_input then
    editBox._wmManualCopyBackground.setColor(Theme.COLORS.bg_input)
    setPartsShown(editBox._wmManualCopyBackground, true)
  end
  if editBox._wmManualCopyBorder and Theme.COLORS.divider then
    UIHelpers.applyBorderBoxColor(editBox._wmManualCopyBorder, Theme.COLORS.divider)
    setPartsShown(editBox._wmManualCopyBorder, true)
  end
  if editBox.SetTextInsets then
    editBox:SetTextInsets(10, 10, 6, 6)
  end
end

function Styling.restoreManualCopyDialog(dialog, dialogName)
  if type(dialog) ~= "table" then
    return
  end
  if dialog._wmManualCopyRestoring == true then
    return
  end
  dialog._wmManualCopyRestoring = true

  setPartsShown(dialog._wmRoundedBackground, false)
  setPartsShown(dialog._wmManualCopyBorder, false)
  dialog._wmManualCopyStyleActive = false

  -- Do not restore popup font objects here: touching StaticPopup font objects
  -- caused live-client SetFontObject stack overflows in OnHide cleanup paths.
  local textRegion = dialog.text
  if textRegion then
    if dialog._wmManualCopyOriginalTextColor ~= nil then
      applyTextColor(textRegion, dialog._wmManualCopyOriginalTextColor)
    end
  end

  local resolvedDialogName = dialogName or MANUAL_COPY_DIALOG_NAME
  restoreManualCopyEditBox(Resolvers.resolvePopupEditBox(dialog, resolvedDialogName))
  restoreManualCopyButton(Resolvers.resolvePopupButton(dialog, 1))
  dialog._wmManualCopyRestoring = false
end

function Styling.styleManualCopyDialog(dialog, dialogName)
  if type(dialog) ~= "table" then
    return
  end

  if
    dialog._wmRoundedBackground == nil
    and type(dialog.CreateTexture) == "function"
    and type(UIHelpers.createRoundedBackground) == "function"
  then
    dialog._wmRoundedBackground = UIHelpers.createRoundedBackground(dialog, 10)
    setPartsShown(dialog._wmRoundedBackground, false)
  end
  if dialog._wmManualCopyBorder == nil and type(UIHelpers.createBorderBox) == "function" then
    dialog._wmManualCopyBorder = UIHelpers.createBorderBox(dialog, Theme.COLORS.divider, 1, "BORDER")
    setPartsShown(dialog._wmManualCopyBorder, false)
  end

  if dialog._wmRoundedBackground and dialog._wmRoundedBackground.setColor then
    dialog._wmRoundedBackground.setColor(Theme.COLORS.bg_primary)
    setPartsShown(dialog._wmRoundedBackground, true)
  end
  if dialog._wmManualCopyBorder and Theme.COLORS.divider then
    UIHelpers.applyBorderBoxColor(dialog._wmManualCopyBorder, Theme.COLORS.divider)
    setPartsShown(dialog._wmManualCopyBorder, true)
  end

  -- Keep popup font objects unchanged; theme the dialog through colors only.
  -- This avoids SetFontObject recursion/crash behavior seen in production.
  local textRegion = dialog.text
  if textRegion and dialog._wmManualCopyStyleActive ~= true then
    dialog._wmManualCopyOriginalTextColor = captureTextColor(textRegion)
  end
  dialog._wmManualCopyStyleActive = true
  if textRegion then
    applyTextColor(textRegion, Theme.COLORS.text_primary)
  end

  local resolvedDialogName = dialogName or MANUAL_COPY_DIALOG_NAME
  styleManualCopyEditBox(Resolvers.resolvePopupEditBox(dialog, resolvedDialogName))
  styleManualCopyButton(Resolvers.resolvePopupButton(dialog, 1))
end

ns.ChatBubbleContextMenuManualCopyPopupUIStyling = Styling

return Styling
