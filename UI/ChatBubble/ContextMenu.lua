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
  end

  if dialog._wmRoundedBackground and dialog._wmRoundedBackground.setColor then
    dialog._wmRoundedBackground.setColor(Theme.COLORS.bg_primary)
  end

  local textRegion = dialog.text
  if textRegion then
    if UIHelpers.setFontObject then
      UIHelpers.setFontObject(textRegion, Theme.FONTS.icon_label)
    end
    if UIHelpers.setTextColor then
      UIHelpers.setTextColor(textRegion, Theme.COLORS.text_primary)
    end
  end

  local editBox = resolvePopupEditBox(dialog)
  if editBox then
    if UIHelpers.setFontObject then
      UIHelpers.setFontObject(editBox, Theme.FONTS.composer_input)
    end
    if editBox.SetTextColor and Theme.COLORS.text_primary then
      local color = Theme.COLORS.text_primary
      editBox:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    if editBox.SetBackdropColor and Theme.COLORS.bg_input then
      local bg = Theme.COLORS.bg_input
      editBox:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    end
  end
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

resolvePopupEditBox = function(dialog)
  local function isEditBoxCandidate(candidate)
    if candidate == nil or type(candidate) ~= "table" or type(candidate.SetText) ~= "function" then
      return false
    end

    if type(candidate.GetObjectType) == "function" then
      return candidate:GetObjectType() == "EditBox"
    end

    return type(candidate.HighlightText) == "function" and type(candidate.SetFocus) == "function"
  end

  if not isEditBoxCandidate(dialog) and type(dialog) ~= "table" then
    return nil
  end

  if isEditBoxCandidate(dialog and dialog.editBox) then
    return dialog.editBox
  end

  if isEditBoxCandidate(dialog and dialog.EditBox) then
    return dialog.EditBox
  end

  if type(dialog.GetName) == "function" then
    local dialogName = dialog:GetName()
    if type(dialogName) == "string" and dialogName ~= "" then
      local namedEditBox = _G[dialogName .. "EditBox"]
      if isEditBoxCandidate(namedEditBox) then
        return namedEditBox
      end
    end
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

      if type(popup.GetName) == "function" then
        local popupName = popup:GetName()
        if type(popupName) == "string" and popupName ~= "" then
          local namedPopupEditBox = _G[popupName .. "EditBox"]
          if isEditBoxCandidate(namedPopupEditBox) then
            return namedPopupEditBox
          end
        end
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
      button1 = _G.OKAY or "OK",
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
    _G.C_Timer.After(0, function()
      if dialog and (type(dialog.IsShown) ~= "function" or dialog:IsShown()) then
        primePopupEditBox(dialog, text)
      end
    end)
    _G.C_Timer.After(0.05, function()
      if dialog and (type(dialog.IsShown) ~= "function" or dialog:IsShown()) then
        primePopupEditBox(dialog, text)
      end
    end)
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

  _G.UIDropDownMenu_Initialize(menuFrame, function(_, level)
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
  end, "MENU")

  _G.ToggleDropDownMenu(1, nil, menuFrame, menuAnchor, 0, 0)
  return true
end

ns.ChatBubbleContextMenu = ContextMenu
return ContextMenu
