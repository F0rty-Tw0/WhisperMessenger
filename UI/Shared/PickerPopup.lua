local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")

-- Behaviour shared by the small popups (reaction picker, delivery menu,
-- composer popovers): panel, text buttons, Escape to close, close on an
-- outside click.
local PickerPopup = {}

-- Escape closes the named frame.
function PickerPopup.RegisterEscape(frameName)
  _G.UISpecialFrames = _G.UISpecialFrames or {}
  for _, name in ipairs(_G.UISpecialFrames) do
    if name == frameName then
      return
    end
  end
  table.insert(_G.UISpecialFrames, frameName)
end

local function isMouseOver(frame)
  if type(frame.IsMouseOver) ~= "function" then
    return false
  end
  local ok, over = pcall(frame.IsMouseOver, frame)
  return ok and over == true
end

local function registerGlobalMouse(frame)
  if frame._globalMouseRegistered or type(frame.RegisterEvent) ~= "function" then
    return
  end
  local ok = pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
  frame._globalMouseRegistered = ok
end

local function unregisterGlobalMouse(frame)
  if not frame._globalMouseRegistered or type(frame.UnregisterEvent) ~= "function" then
    return
  end
  pcall(frame.UnregisterEvent, frame, "GLOBAL_MOUSE_DOWN")
  frame._globalMouseRegistered = nil
end

-- Call right before showing: the next click outside `frame` closes it. The
-- click that opened it lands in the same tick and is ignored.
function PickerPopup.ArmDismiss(frame)
  frame._dismissArmed = false
  registerGlobalMouse(frame)
  frame:SetScript("OnUpdate", function(self)
    self._dismissArmed = true
    self:SetScript("OnUpdate", nil)
  end)
end

-- Call from OnHide.
function PickerPopup.Disarm(frame)
  unregisterGlobalMouse(frame)
  frame:SetScript("OnUpdate", nil)
  frame._dismissArmed = nil
end

-- Call from OnEvent; runs close() on an armed outside click. A click on the
-- optional anchor (the popup's launcher) is not "outside".
function PickerPopup.HandleEvent(frame, event, close, anchor)
  if event == "GLOBAL_MOUSE_DOWN" and frame._dismissArmed and not isMouseOver(frame) and not (anchor and isMouseOver(anchor)) then
    close()
  end
end

-- Hidden, screen-clamped, mouse-enabled panel with the picker background
-- (frame._background) and border (frame._border). Paint with
-- PickerStyles.ApplyPanelTheme.
function PickerPopup.CreatePanel(factory, parent, name, strata)
  local frame = factory.CreateFrame("Frame", name, parent)
  frame:Hide()
  if frame.SetFrameStrata then
    frame:SetFrameStrata(strata)
  end
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(true)
  end
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  frame._background = background
  if type(UIHelpers.createBorderBox) == "function" then
    frame._border = UIHelpers.createBorderBox(frame, PickerStyles.BorderColor(), 1, "BORDER")
  end
  return frame
end

-- Full-width text button with a hover highlight. Returns button, label.
function PickerPopup.CreateTextButton(factory, parent, key, onClick)
  local button = factory.CreateFrame("Button", nil, parent)
  local highlight = button:CreateTexture(nil, "BACKGROUND")
  highlight:SetAllPoints(button)
  PickerStyles.ApplyColor(highlight, PickerStyles.HighlightColor(0.35))
  highlight:Hide()
  button._highlight = highlight

  local label = button:CreateFontString(nil, "OVERLAY")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  UIHelpers.setFontObject(label, Theme.FONTS.icon_label)
  label:SetText(Localization.Text(key))
  UIHelpers.setTextColor(label, Theme.COLORS.option_button_text or Theme.COLORS.text_primary)
  button:SetScript("OnEnter", function(self)
    PickerStyles.ApplyColor(self._highlight, PickerStyles.HighlightColor(0.35))
    self._highlight:Show()
  end)
  button:SetScript("OnLeave", function(self)
    self._highlight:Hide()
  end)
  button:SetScript("OnClick", onClick)
  return button, label
end

ns.PickerPopup = PickerPopup
return PickerPopup
