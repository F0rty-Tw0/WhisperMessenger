local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowShadow = ns.MessengerWindowChromeBuilderWindowShadow or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.WindowShadow")
local IconButtonStyle = ns.MessengerWindowChromeBuilderIconButtonStyle or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.IconButtonStyle")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor
local setTextColor = UIHelpers.setTextColor

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local ModernChrome = {}

-- Full addon name at a readable size; the drop shadow is baked into the
-- window_title font object (see Fonts.lua).
local function applyTitleStyle(title, theme, explicitTitle)
  title:SetText(explicitTitle or theme.MODERN_TITLE)
  UIHelpers.setFontObject(title, theme.FONTS.window_title)
end

-- Builds the custom (non-Blizzard-template) chrome branch. Paints:
--   * a flat bg_primary background spanning the frame,
--   * a 1px window edge (window_border color),
--   * a custom title bar with bg_header and a gloss sheen,
--   * a custom title FontString rendered on the OVERLAY layer of the title
--     bar so it sits above the header bg even when alpha < 1,
--   * a custom close button (line icon) that turns red on hover.
function ModernChrome.Build(factory, frame, options, theme)
  options = options or {}
  theme = theme or Theme

  -- Modern: custom flat background
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  applyColorTexture(background, theme.COLORS.bg_primary)
  frame.background = background
  local shadow = WindowShadow.Create(frame)

  -- Crisp 1px window edge so the frame separates from the game world.
  local edgeTextures = UIHelpers.createBorderBox(frame, theme.COLORS.window_border, theme.LAYOUT.DIVIDER_THICKNESS, "BORDER")

  -- Title bar with header background
  local titleBar = factory.CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  titleBar:SetHeight(theme.TOP_BAR_HEIGHT)
  local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
  titleBarBg:SetAllPoints(titleBar)
  applyColorTexture(titleBarBg, theme.COLORS.bg_header)
  local titleSheen = UIHelpers.createSheen(titleBar, "ARTWORK", 1)

  -- Title lives on titleBar (not frame) so its OVERLAY layer renders above
  -- titleBarBg. Child-frame layers paint on top of parent-frame layers at
  -- the same frame level, so a fontstring on frame would be hidden behind
  -- any titleBarBg with non-trivial alpha.
  -- Title and close button are anchored by TitleBarLayout.
  local title = titleBar:CreateFontString(nil, "OVERLAY", theme.FONTS.header_name)
  applyTitleStyle(title, theme, options.title)
  setTextColor(title, theme.COLORS.text_title or theme.COLORS.text_primary)
  frame.title = title

  -- Custom close button (no template)
  local closeButton = factory.CreateFrame("Button", nil, frame)
  closeButton:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
  closeBg:SetAllPoints(closeButton)
  IconButtonStyle.Attach(closeButton, closeBg)
  local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(closeButton, closeIcon, theme.TEXTURES.title_close_icon)
  closeIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  closeIcon:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
  closeIcon:SetDesaturated(true)
  local function applyCloseVisuals(hovered)
    applyVertexColor(closeIcon, IconButtonStyle.Paint(closeButton, hovered, theme.COLORS, true))
  end
  applyCloseVisuals(false)
  if closeButton.SetScript then
    closeButton:SetScript("OnEnter", function()
      applyCloseVisuals(true)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(closeButton, "ANCHOR_TOP")
        _G.GameTooltip:SetText(Localization.Text("Close"))
        _G.GameTooltip:Show()
      end
    end)
    closeButton:SetScript("OnLeave", function()
      applyCloseVisuals(false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end
  closeButton:EnableMouse(true)

  local function applyChromePaint(activeTheme)
    theme = activeTheme
    applyColorTexture(background, activeTheme.COLORS.bg_primary)
    if titleBarBg then
      applyColorTexture(titleBarBg, activeTheme.COLORS.bg_header)
    end
    applyTitleStyle(title, activeTheme, options.title)
    UIHelpers.applySheen(titleSheen)
    setTextColor(title, activeTheme.COLORS.text_title or activeTheme.COLORS.text_primary)
    if edgeTextures then
      UIHelpers.applyBorderBoxColor(edgeTextures, activeTheme.COLORS.window_border)
    end
    applyCloseVisuals(closeButton:IsMouseOver())
  end

  return {
    background = background,
    title = title,
    closeButton = closeButton,
    applyChromePaint = applyChromePaint,
    titleBar = titleBar,
    shadow = shadow,
  }
end

ns.MessengerWindowChromeBuilderModern = ModernChrome

return ModernChrome
