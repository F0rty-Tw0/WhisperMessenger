local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeControls = ns.UIHelpersNativeControls or require("WhisperMessenger.UI.Helpers.NativeControls")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local CloseGlyphButton = ns.CloseGlyphButton or require("WhisperMessenger.UI.Shared.CloseGlyphButton")

-- Frame, buttons and text colours shared by the addon's own dialogs (two
-- field dialog, conversation export). The modern look is a rounded themed
-- panel; under the Native WoW HUD it is Blizzard's dialog border, panel
-- buttons and close button.
local DialogChrome = {}

local FRAME_RADIUS = 10
-- Blizzard's own text colours for the Native WoW HUD look.
local NATIVE_TITLE_COLOR = { 1, 0.82, 0, 1 }
local NATIVE_TEXT_COLOR = { 1, 1, 1, 1 }
local NATIVE_HINT_COLOR = { 0.8, 0.8, 0.8, 1 }
local NATIVE_BORDER_TEMPLATE = "DialogBorderTemplate"
local NATIVE_CLOSE_TEMPLATE = "UIPanelCloseButton"
-- Blizzard's dialog background is see-through; a dark fill under it keeps
-- the world from showing through. Inset to sit inside the border art.
local NATIVE_FILL_COLOR = { 0, 0, 0, 0.9 }
local NATIVE_FILL_INSET = 7

function DialogChrome.IsNative()
  return StyledTextInputPopup.nativeChrome == true
end

-- A missing template is skipped where the client can tell; elsewhere the
-- pcall in createTemplatedFrame is the guard.
local function hasTemplate(name)
  local xmlUtil = _G.C_XMLUtil
  if type(xmlUtil) ~= "table" or type(xmlUtil.GetTemplateInfo) ~= "function" then
    return true
  end
  local ok, info = pcall(xmlUtil.GetTemplateInfo, name)
  return ok and info ~= nil
end

-- A Blizzard-templated frame under the Native WoW HUD, nil otherwise.
function DialogChrome.NativeFrame(factory, frameType, parent, template)
  if not DialogChrome.IsNative() or not hasTemplate(template) then
    return nil
  end
  return UIHelpers.createTemplatedFrame(factory, frameType, nil, parent, template)
end

-- Native art sits on its own child so content on a higher frame draws
-- above it. Returns the theme repaint, nil under the Native WoW HUD.
function DialogChrome.CreateBackground(factory, frame)
  local border = DialogChrome.NativeFrame(factory, "Frame", frame, NATIVE_BORDER_TEMPLATE)
  if border then
    border:SetAllPoints(frame)
    local fill = frame:CreateTexture(nil, "BACKGROUND")
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", NATIVE_FILL_INSET, -NATIVE_FILL_INSET)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -NATIVE_FILL_INSET, NATIVE_FILL_INSET)
    local c = NATIVE_FILL_COLOR
    fill:SetColorTexture(c[1], c[2], c[3], c[4])
    frame.nativeFill = fill
    return nil
  end
  local background = UIHelpers.createRoundedBackground(frame, FRAME_RADIUS)
  local outline = UIHelpers.createBorderBox(frame, Theme.COLORS.divider, 1, "BORDER")
  return function()
    if background and background.setColor then
      background.setColor(Theme.COLORS.bg_primary)
    end
    UIHelpers.applyBorderBoxColor(outline, Theme.COLORS.divider)
  end
end

-- Option button (Blizzard panel button under the Native WoW HUD). Relabel
-- through `.label:SetText`.
function DialogChrome.CreateButton(factory, parent, width)
  local height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT
  if DialogChrome.IsNative() then
    local native = NativeControls.CreateButton(factory, parent, "", width, height)
    if native then
      return native
    end
  end
  return UIHelpers.createOptionButton(factory, parent, "", SettingsControls.OptionButtonColors(Theme), { height = height, width = width })
end

-- Modern "X" glyph, red on hover; Blizzard's close button under the Native
-- WoW HUD. The caller anchors it and sets OnClick.
function DialogChrome.CreateCloseButton(factory, parent, size)
  local native = DialogChrome.IsNative() and UIHelpers.createTemplatedFrame(factory, "Button", nil, parent, NATIVE_CLOSE_TEMPLATE)
  if native then
    native:SetSize(size, size)
    return native
  end
  return CloseGlyphButton.Create(factory, parent, size, nil, { danger = true })
end

-- Title, body and hint colours, read at paint time so a theme change since
-- the last Show is picked up.
function DialogChrome.TextColors()
  if DialogChrome.IsNative() then
    return NATIVE_TITLE_COLOR, NATIVE_TEXT_COLOR, NATIVE_HINT_COLOR
  end
  return Theme.COLORS.text_primary, Theme.COLORS.text_primary, Theme.COLORS.text_secondary
end

ns.DialogChrome = DialogChrome
return DialogChrome
