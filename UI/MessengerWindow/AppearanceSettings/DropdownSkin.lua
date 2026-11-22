local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

-- Closed-dropdown look: the same softly rounded input surface as the
-- contacts search field, a down chevron on the right (the bundled back glyph
-- rotated a quarter turn via tex coords, no new media) and a faint wash on
-- hover. The open list is a flat panel in the modern look; under the Native
-- WoW HUD it draws like the game's menus (a tooltip panel), while the closed
-- button keeps its modern look.
local DropdownSkin = {}

DropdownSkin.CHEVRON_TEXTURE = Theme.TEXTURES.title_back_icon
DropdownSkin.CHEVRON_SIZE = 10
DropdownSkin.CHEVRON_INSET = 8
DropdownSkin.RADIUS = 6
DropdownSkin.LABEL_INSET = 8
DropdownSkin.LABEL_CHEVRON_GAP = 6

-- Palette from theme colours; `overrides` entries win when present.
function DropdownSkin.Palette(colors, overrides)
  overrides = overrides or {}
  return {
    bg = overrides.bg or colors.option_button_bg,
    bgHover = overrides.bgHover or colors.option_button_hover,
    bgActive = overrides.bgActive or colors.option_button_active or colors.option_button_hover,
    text = overrides.text or colors.option_button_text,
    textHover = overrides.textHover or colors.option_button_text_hover,
    textActive = overrides.textActive or colors.option_button_text_active or colors.text_primary,
  }
end

local function setRoundedShown(rounded, shown)
  for _, part in ipairs(rounded.fills) do
    part:SetShown(shown)
  end
  for _, part in ipairs(rounded.corners) do
    part:SetShown(shown)
  end
end

function DropdownSkin.Attach(button, label)
  local surface = UIHelpers.createRoundedBackground(button, DropdownSkin.RADIUS, "BACKGROUND", 1)
  local hover = UIHelpers.createRoundedBackground(button, DropdownSkin.RADIUS, "BACKGROUND", 2)
  local chevron = button:CreateTexture(nil, "ARTWORK")
  chevron:SetSize(DropdownSkin.CHEVRON_SIZE, DropdownSkin.CHEVRON_SIZE)
  chevron:SetPoint("RIGHT", button, "RIGHT", -DropdownSkin.CHEVRON_INSET, 0)
  chevron:SetTexture(DropdownSkin.CHEVRON_TEXTURE)
  -- "<" glyph turned 90 degrees counter-clockwise so it points down.
  chevron:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
  chevron:Show()
  setRoundedShown(surface, true)
  setRoundedShown(hover, false)
  -- Value text stops short of the chevron.
  label:SetPoint("LEFT", button, "LEFT", DropdownSkin.LABEL_INSET, 0)
  label:SetPoint("RIGHT", button, "RIGHT", -(DropdownSkin.CHEVRON_INSET + DropdownSkin.CHEVRON_SIZE + DropdownSkin.LABEL_CHEVRON_GAP), 0)
  return { surface = surface, hover = hover, chevron = chevron }
end

function DropdownSkin.Paint(skin, label, hovered)
  local colors = Theme.COLORS
  setRoundedShown(skin.hover, hovered)
  skin.surface.setColor(colors.bg_input)
  skin.hover.setColor(colors.bg_contact_hover)
  UIHelpers.applyVertexColor(skin.chevron, hovered and colors.text_primary or colors.text_secondary)
  UIHelpers.setTextColor(label, colors.text_primary)
end

-- Same level as the menu, so the scroll child (one above) draws on top.
local function levelPanel(menu, panel)
  if panel and panel.SetFrameLevel and menu.GetFrameLevel then
    panel:SetFrameLevel(menu:GetFrameLevel())
  end
end

-- Hidden, scrollable open list under `button`; `content` is the scroll
-- child. The look is decided here, once, so rows pooled later match:
-- menuSkin = { native, bg, panel }.
function DropdownSkin.CreateMenu(factory, row, button, rowWidth, buttonHeight)
  local menu = factory.CreateFrame("ScrollFrame", nil, row)
  menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
  menu:SetFrameLevel((row.GetFrameLevel and row:GetFrameLevel() or 1) + 20)
  menu:SetClampedToScreen(true)
  menu:EnableMouseWheel(true)
  if menu.SetClipsChildren then
    menu:SetClipsChildren(true)
  end

  local bg = menu:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(menu)
  -- Kept on the menu so a test can tell the flat fill from other textures.
  menu._wmBg = bg

  local content = factory.CreateFrame("Frame", nil, menu)
  content:SetSize(rowWidth, buttonHeight)
  menu:SetScrollChild(content)
  content:Show()

  local menuSkin = { native = Hud.IsOn(), bg = bg }
  if menuSkin.native then
    local panel = PickerPopup.CreateTooltipFrame(factory, menu)
    panel:SetAllPoints(menu)
    levelPanel(menu, panel)
    panel:Show()
    bg:Hide()
    menuSkin.panel = panel
  end
  menu:Hide()
  return menu, content, menuSkin
end

-- Lifts the menu above its siblings on open. Raise can re-base frame
-- levels, so the native panel is levelled with the menu again.
function DropdownSkin.RaiseMenu(menu, menuSkin)
  menu:Raise()
  levelPanel(menu, menuSkin.panel)
end

-- Modern look: flat fill in the palette's background. Native: the tooltip
-- panel draws the background.
function DropdownSkin.PaintMenu(menuSkin, palette)
  if menuSkin.native then
    return
  end
  UIHelpers.applyColorTexture(menuSkin.bg, palette.bg)
end

ns.MessengerWindowDropdownSkin = DropdownSkin
return DropdownSkin
