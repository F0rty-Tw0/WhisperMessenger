local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContextMenu = {}
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local MENU_FRAME_NAME = "WhisperMessengerBubbleContextMenu"
local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

local resolvePopupEditBox
local resolvePopupButton
local resolvePopupButtonLabel
local function colorToHex(color)
  local function component(value)
    local v = math.floor((tonumber(value) or 1) * 255 + 0.5)
    if v < 0 then
      v = 0
    elseif v > 255 then
      v = 255
    end
    return v
  end

  local r = component(color and color[1] or 1)
  local g = component(color and color[2] or 1)
  local b = component(color and color[3] or 1)
  return string.format("|cff%02x%02x%02x", r, g, b)
end

local function styleMenuText(text)
  return colorToHex(Theme.COLORS.option_button_text) .. text .. "|r"
end

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

  local label = button._wmManualCopyLabel or resolvePopupButtonLabel(button)
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

  local label = button._wmManualCopyLabel or resolvePopupButtonLabel(button)
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

  local label = button._wmManualCopyLabel or resolvePopupButtonLabel(button)
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

local function restoreManualCopyDialog(dialog)
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

  restoreManualCopyEditBox(resolvePopupEditBox(dialog))
  restoreManualCopyButton(resolvePopupButton(dialog, 1))
  dialog._wmManualCopyRestoring = false
end

local function styleManualCopyDialog(dialog)
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

  styleManualCopyEditBox(resolvePopupEditBox(dialog))
  styleManualCopyButton(resolvePopupButton(dialog, 1))
end

local function normalizeText(text)
  if text == nil then
    return nil
  end

  local value = tostring(text)
  if value == "" then
    return nil
  end

  return value
end

local function getMenuFrame()
  if type(_G.CreateFrame) ~= "function" or _G.UIParent == nil then
    return nil
  end

  local frame = _G[MENU_FRAME_NAME]
  if frame ~= nil then
    return frame
  end

  return _G.CreateFrame("Frame", MENU_FRAME_NAME, _G.UIParent, "UIDropDownMenuTemplate")
end

local function resolveNamedFrameChild(frame, suffix, isCandidate)
  if type(frame) ~= "table" or type(isCandidate) ~= "function" then
    return nil
  end
  if type(frame.GetName) ~= "function" then
    return nil
  end

  local frameName = frame:GetName()
  if type(frameName) ~= "string" or frameName == "" then
    return nil
  end

  local namedChild = _G[frameName .. suffix]
  if isCandidate(namedChild) then
    return namedChild
  end
  return nil
end

resolvePopupEditBox = function(dialog)
  local function isEditBoxCandidate(candidate)
    if candidate == nil or type(candidate) ~= "table" or type(candidate.SetText) ~= "function" then
      return false
    end

    if type(candidate.GetObjectType) == "function" then
      return candidate:GetObjectType() == "EditBox"
    end
    if candidate.frameType == "EditBox" then
      return true
    end

    return type(candidate.HighlightText) == "function" and type(candidate.SetFocus) == "function"
  end

  if type(dialog) ~= "table" then
    return nil
  end

  if isEditBoxCandidate(dialog and dialog.editBox) then
    return dialog.editBox
  end

  if isEditBoxCandidate(dialog and dialog.EditBox) then
    return dialog.EditBox
  end

  local namedEditBox = resolveNamedFrameChild(dialog, "EditBox", isEditBoxCandidate)
  if namedEditBox then
    return namedEditBox
  end

  if type(dialog.GetChildren) == "function" then
    local children = { dialog:GetChildren() }
    for _, child in ipairs(children) do
      if isEditBoxCandidate(child) then
        return child
      end
    end
  end

  for i = 1, 4 do
    local popup = _G["StaticPopup" .. i]
    if popup and popup.which == MANUAL_COPY_DIALOG_NAME then
      if isEditBoxCandidate(popup.editBox) then
        return popup.editBox
      end

      local namedPopupEditBox = resolveNamedFrameChild(popup, "EditBox", isEditBoxCandidate)
      if namedPopupEditBox then
        return namedPopupEditBox
      end
    end
  end

  return nil
end

local function isPopupButtonCandidate(candidate)
  if type(candidate) ~= "table" then
    return false
  end
  if type(candidate.GetObjectType) == "function" then
    return candidate:GetObjectType() == "Button"
  end
  return type(candidate.SetScript) == "function" and type(candidate.CreateTexture) == "function"
end

local function isFontStringCandidate(candidate)
  if type(candidate) ~= "table" then
    return false
  end
  if type(candidate.GetObjectType) == "function" then
    return candidate:GetObjectType() == "FontString"
  end
  return type(candidate.SetTextColor) == "function" and type(candidate.SetText) == "function"
end

resolvePopupButton = function(dialog, buttonIndex)
  if type(dialog) ~= "table" then
    return nil
  end

  local key = "button" .. tostring(buttonIndex)
  if isPopupButtonCandidate(dialog[key]) then
    return dialog[key]
  end

  local capitalizedKey = "Button" .. tostring(buttonIndex)
  if isPopupButtonCandidate(dialog[capitalizedKey]) then
    return dialog[capitalizedKey]
  end

  local namedButton = resolveNamedFrameChild(dialog, "Button" .. tostring(buttonIndex), isPopupButtonCandidate)
  if namedButton then
    return namedButton
  end

  if type(dialog.GetChildren) == "function" then
    for _, child in ipairs({ dialog:GetChildren() }) do
      if isPopupButtonCandidate(child) then
        return child
      end
    end
  end

  return nil
end

resolvePopupButtonLabel = function(button)
  if type(button) ~= "table" then
    return nil
  end

  if isFontStringCandidate(button.text) then
    return button.text
  end
  if isFontStringCandidate(button.Text) then
    return button.Text
  end
  if type(button.GetFontString) == "function" then
    local fontString = button:GetFontString()
    if isFontStringCandidate(fontString) then
      return fontString
    end
  end
  if type(button.GetRegions) == "function" then
    for _, region in ipairs({ button:GetRegions() }) do
      if isFontStringCandidate(region) then
        return region
      end
    end
  end

  return nil
end

local function primePopupEditBox(dialog, value)
  local editBox = resolvePopupEditBox(dialog)
  if editBox == nil then
    return false
  end

  if editBox.SetText then
    editBox:SetText(value)
  end
  if editBox.HighlightText then
    editBox:HighlightText()
  end
  if editBox.SetFocus then
    editBox:SetFocus()
  end

  return true
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
      primePopupEditBox(dialog, text)
    end
  end)
end

local function showManualCopyDialog(text)
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
        styleManualCopyDialog(self)
        primePopupEditBox(self, value)
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
        restoreManualCopyDialog(self)
        local editBox = resolvePopupEditBox(self)
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
  styleManualCopyDialog(dialog)
  primePopupEditBox(dialog, text)

  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    scheduleManualCopyRefocus(dialog, text, 0)
    scheduleManualCopyRefocus(dialog, text, 0.05)
  end

  return true
end

function ContextMenu.CopyText(text)
  local normalized = normalizeText(text)
  if normalized == nil then
    return false
  end

  if type(_G.C_Clipboard) == "table" then
    local candidates = { "SetClipboard", "SetClipboardText", "SetText", "CopyText", "CopyToClipboard" }
    for _, methodName in ipairs(candidates) do
      local method = _G.C_Clipboard[methodName]
      if type(method) == "function" then
        local ok = pcall(method, normalized)
        if ok then
          return true
        end

        ok = pcall(method, _G.C_Clipboard, normalized)
        if ok then
          return true
        end
      end
    end
  end

  return showManualCopyDialog(normalized)
end

function ContextMenu.Open(text, anchorFrame)
  local normalized = normalizeText(text)
  if normalized == nil then
    return false
  end

  local menuFrame = getMenuFrame()
  if menuFrame == nil then
    return ContextMenu.CopyText(normalized)
  end

  local menuAnchor = anchorFrame or "cursor"
  local menu = {
    {
      text = styleMenuText("Copy Text"),
      notCheckable = true,
      padding = 0,
      minWidth = 1,
      fontObject = Theme.FONTS.icon_label,
      func = function()
        ContextMenu.CopyText(normalized)
      end,
    },
  }

  if type(_G.EasyMenu) == "function" then
    _G.EasyMenu(menu, menuFrame, menuAnchor, 0, 0, "MENU")
    return true
  end

  if
    type(_G.UIDropDownMenu_Initialize) ~= "function"
    or type(_G.UIDropDownMenu_CreateInfo) ~= "function"
    or type(_G.UIDropDownMenu_AddButton) ~= "function"
    or type(_G.ToggleDropDownMenu) ~= "function"
  then
    return false
  end

  local function initializeMenu(_, level)
    if level ~= 1 then
      return
    end

    for _, item in ipairs(menu) do
      local info = _G.UIDropDownMenu_CreateInfo()
      for key, value in pairs(item) do
        info[key] = value
      end
      _G.UIDropDownMenu_AddButton(info, level)
    end
  end

  pcall(_G.UIDropDownMenu_Initialize, menuFrame, initializeMenu, "MENU")

  _G.ToggleDropDownMenu(1, nil, menuFrame, menuAnchor, 0, 0)
  return true
end

ns.ChatBubbleContextMenu = ContextMenu
return ContextMenu
