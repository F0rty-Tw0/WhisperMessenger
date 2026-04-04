local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Resolvers = {}

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

function Resolvers.resolvePopupEditBox(dialog, dialogName)
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

  if type(dialogName) == "string" and dialogName ~= "" then
    for i = 1, 4 do
      local popup = _G["StaticPopup" .. i]
      if popup and popup.which == dialogName then
        if isEditBoxCandidate(popup.editBox) then
          return popup.editBox
        end

        local namedPopupEditBox = resolveNamedFrameChild(popup, "EditBox", isEditBoxCandidate)
        if namedPopupEditBox then
          return namedPopupEditBox
        end
      end
    end
  end

  return nil
end

function Resolvers.resolvePopupButton(dialog, buttonIndex)
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

function Resolvers.resolvePopupButtonLabel(button)
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

function Resolvers.primePopupEditBox(dialog, value, dialogName)
  local editBox = Resolvers.resolvePopupEditBox(dialog, dialogName)
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

ns.ChatBubbleContextMenuManualCopyPopupUIResolvers = Resolvers

return Resolvers
