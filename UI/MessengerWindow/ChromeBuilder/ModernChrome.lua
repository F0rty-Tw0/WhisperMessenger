local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor
local setTextColor = UIHelpers.setTextColor

local ModernChrome = {}

-- Builds the modern (non-Blizzard-template) chrome branch. Paints:
--   * a flat bg_primary background spanning the frame,
--   * 1px edge highlights (divider color),
--   * a custom title bar with bg_header + divider borders (no bottom),
--   * a custom title FontString rendered on the OVERLAY layer of the title
--     bar so it sits above the header bg even when alpha < 1,
--   * a custom close button with a StopButton icon that recolors red on
--     hover.
function ModernChrome.Build(factory, frame, options, theme)
  options = options or {}
  theme = theme or Theme

  -- Modern: custom flat background
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  applyColorTexture(background, theme.COLORS.bg_primary)
  frame.background = background

  -- Subtle edge highlights (1px border)
  local edgeTextures = UIHelpers.createBorderBox(frame, theme.COLORS.divider, theme.LAYOUT.DIVIDER_THICKNESS, "BORDER")

  -- Title bar with header background
  local titleBar = factory.CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  titleBar:SetHeight(theme.TOP_BAR_HEIGHT)
  local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
  titleBarBg:SetAllPoints(titleBar)
  applyColorTexture(titleBarBg, theme.COLORS.bg_header)
  local titleBarBorder = UIHelpers.createBorderBox(
    titleBar,
    theme.COLORS.divider,
    theme.DIVIDER_THICKNESS,
    "BORDER",
    { top = true, left = true, right = true, bottom = false }
  )

  -- Title lives on titleBar (not frame) so its OVERLAY layer renders above
  -- titleBarBg. Child-frame layers paint on top of parent-frame layers at
  -- the same frame level, so a fontstring on frame would be hidden behind
  -- any titleBarBg with non-trivial alpha (Shadowlands 0.90, Azeroth 1.0).
  local title = titleBar:CreateFontString(nil, "OVERLAY", theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 4, -6)
  title:SetText(options.title or theme.TITLE)
  if title.SetFont then
    local fontPath, _, flags = title:GetFont()
    if fontPath then
      title:SetFont(fontPath, 10, flags)
    end
  end
  setTextColor(title, theme.COLORS.text_title or theme.COLORS.text_primary)
  if title.SetShadowColor then
    title:SetShadowColor(0, 0, 0, 0.85)
  end
  if title.SetShadowOffset then
    title:SetShadowOffset(1, -1)
  end
  frame.title = title

  -- Custom close button (no template)
  local closeButton = factory.CreateFrame("Button", nil, frame)
  closeButton:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
  local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
  closeBg:SetAllPoints(closeButton)
  applyColorTexture(closeBg, { 0, 0, 0, 0 })
  local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
  closeIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  closeIcon:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
  closeIcon:SetTexture("Interface\\Buttons\\UI-StopButton")
  closeIcon:SetDesaturated(true)
  applyVertexColor(closeIcon, theme.COLORS.text_secondary)
  if closeButton.SetScript then
    closeButton:SetScript("OnEnter", function()
      applyVertexColor(closeIcon, { 0.9, 0.3, 0.3, 1 })
      applyColorTexture(closeBg, { 0.9, 0.3, 0.3, 0.15 })
    end)
    closeButton:SetScript("OnLeave", function()
      applyVertexColor(closeIcon, theme.COLORS.text_secondary)
      applyColorTexture(closeBg, { 0, 0, 0, 0 })
    end)
  end
  closeButton:EnableMouse(true)

  local function applyChromePaint(activeTheme)
    applyColorTexture(background, activeTheme.COLORS.bg_primary)
    if titleBarBg then
      applyColorTexture(titleBarBg, activeTheme.COLORS.bg_header)
    end
    setTextColor(title, activeTheme.COLORS.text_title or activeTheme.COLORS.text_primary)
    local divider = activeTheme.COLORS.divider
    if edgeTextures then
      UIHelpers.applyBorderBoxColor(edgeTextures, { divider[1], divider[2], divider[3], divider[4] or 1 })
    end
    if titleBarBorder then
      UIHelpers.applyBorderBoxColor(titleBarBorder, divider)
    end
    if closeIcon then
      applyVertexColor(closeIcon, activeTheme.COLORS.text_secondary)
    end
  end

  return {
    background = background,
    title = title,
    closeButton = closeButton,
    applyChromePaint = applyChromePaint,
    titleBarBg = titleBarBg,
    titleBarBorder = titleBarBorder,
    edgeTextures = edgeTextures,
    closeIcon = closeIcon,
  }
end

ns.MessengerWindowChromeBuilderModern = ModernChrome

return ModernChrome
