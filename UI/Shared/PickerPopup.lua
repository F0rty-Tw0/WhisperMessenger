local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Behaviour shared by the small popups (reaction picker, delivery menu,
-- composer popovers): panel, text buttons, Escape to close, close on an
-- outside click.
local PickerPopup = {}

-- Native WoW HUD art: action-button hover and action-button checked glow.
-- Dropdown-menu entries hover with NativeArt.LIST_HOVER.
PickerPopup.ICON_HIGHLIGHT = "Interface\\Buttons\\ButtonHilight-Square"
PickerPopup.ICON_CHECKED = "Interface\\Buttons\\CheckButtonHilight"

-- Same size as the modern label font (WM_Highlight is built from it).
PickerPopup.MENU_FONT = "GameFontHighlight"
local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"
-- Fallback when the client lacks TooltipBackdropTemplate: GameTooltip's
-- backdrop and default colours.
local TOOLTIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local TOOLTIP_BACKGROUND_COLOR = { 0.09, 0.09, 0.19, 0.9 }
local TOOLTIP_BORDER_COLOR = { 1, 1, 1, 1 }

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

local function applyColor(setter, frame, color)
  if type(frame[setter]) == "function" then
    frame[setter](frame, color[1], color[2], color[3], color[4])
  end
end

-- A frame that draws like GameTooltip (popups, Native HUD chat bubbles).
function PickerPopup.CreateTooltipFrame(factory, parent, name)
  local frame = UIHelpers.createTemplatedFrame(factory, "Frame", name, parent, TOOLTIP_TEMPLATE)
  if frame then
    return frame
  end
  frame = factory.CreateFrame("Frame", name, parent, "BackdropTemplate")
  if type(frame.SetBackdrop) == "function" then
    frame:SetBackdrop(TOOLTIP_BACKDROP)
    applyColor("SetBackdropColor", frame, TOOLTIP_BACKGROUND_COLOR)
    applyColor("SetBackdropBorderColor", frame, TOOLTIP_BORDER_COLOR)
  end
  return frame
end

-- Hidden, screen-clamped, mouse-enabled panel with the picker background
-- (frame._background) and border (frame._border). Paint with
-- PickerStyles.ApplyPanelTheme. Under the Native WoW HUD it is a tooltip
-- frame instead and has neither.
function PickerPopup.CreatePanel(factory, parent, name, strata)
  local native = Hud.IsOn()
  local frame = native and PickerPopup.CreateTooltipFrame(factory, parent, name) or factory.CreateFrame("Frame", name, parent)
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
  if native then
    -- Contents shift by this so they clear the tooltip border.
    frame._nativeInset = Theme.LAYOUT.NATIVE_BORDER_INSET
    return frame
  end
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  frame._background = background
  if type(UIHelpers.createBorderBox) == "function" then
    frame._border = UIHelpers.createBorderBox(frame, PickerStyles.BorderColor(), 1, "BORDER")
  end
  return frame
end

-- Content offset that clears a HUD panel's tooltip border (0 otherwise).
function PickerPopup.BorderInset(frame)
  return frame._nativeInset or 0
end

-- Modern hover: a hidden themed fill behind `button`; the caller shows it
-- on hover. (Under the Native WoW HUD, entries use NativeArt.AddHighlight.)
function PickerPopup.CreateHoverFill(button)
  local fill = button:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(button)
  PickerStyles.ApplyColor(fill, PickerStyles.HighlightColor(PickerStyles.HOVER_ALPHA))
  fill:Hide()
  return fill
end

-- Dropdown-menu style entry: game font, Blizzard hover art.
local function createNativeTextButton(factory, parent, key, onClick)
  local button = factory.CreateFrame("Button", nil, parent)
  button._highlight = NativeArt.AddHighlight(button, NativeArt.LIST_HOVER)
  local label = button:CreateFontString(nil, "OVERLAY")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  UIHelpers.setFontObject(label, PickerPopup.MENU_FONT)
  label:SetText(Localization.Text(key))
  button:SetScript("OnClick", onClick)
  return button, label
end

-- Full-width text button with a hover highlight. Returns button, label.
function PickerPopup.CreateTextButton(factory, parent, key, onClick)
  if Hud.IsOn() then
    return createNativeTextButton(factory, parent, key, onClick)
  end
  local button = factory.CreateFrame("Button", nil, parent)
  button._highlight = PickerPopup.CreateHoverFill(button)

  local label = button:CreateFontString(nil, "OVERLAY")
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  UIHelpers.setFontObject(label, Theme.FONTS.icon_label)
  label:SetText(Localization.Text(key))
  UIHelpers.setTextColor(label, Theme.COLORS.option_button_text or Theme.COLORS.text_primary)
  button:SetScript("OnEnter", function(self)
    PickerStyles.ApplyColor(self._highlight, PickerStyles.HighlightColor(PickerStyles.HOVER_ALPHA))
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
