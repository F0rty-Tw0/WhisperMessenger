local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IconButtonStyle = ns.MessengerWindowChromeBuilderIconButtonStyle or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.IconButtonStyle")
local applyVertexColor = UIHelpers.applyVertexColor

-- hintKey, when given, adds a second line in white under the title.
local function showTooltip(button, textKey, hintKey)
  if _G.GameTooltip and _G.GameTooltip.SetOwner then
    _G.GameTooltip:SetOwner(button, "ANCHOR_TOP")
    _G.GameTooltip:SetText(Localization.Text(textKey))
    if hintKey and _G.GameTooltip.AddLine then
      pcall(_G.GameTooltip.AddLine, _G.GameTooltip, Localization.Text(hintKey), 1, 1, 1)
    end
    _G.GameTooltip:Show()
  end
end

local function hideTooltip()
  if _G.GameTooltip and _G.GameTooltip.Hide then
    _G.GameTooltip:Hide()
  end
end

local Buttons = {}

-- Creates the "New Whisper" button. Size and anchor come from
-- TitleBarLayout. Returns the button plus the textures applyTheme repaints.
function Buttons.CreateNewConversation(factory, frame, theme)
  return Buttons.CreatePlainIcon(factory, frame, theme, "title_new_whisper_icon", "Start New Whisper", {
    desaturate = true,
    hintKey = "Open an empty conversation thread.",
  })
end

-- Creates the gear/options button. ChromeBuilder calls setActive while the
-- options pane is visible, so hover never overwrites the selection paint.
function Buttons.CreateOptions(factory, frame, theme)
  return Buttons.CreatePlainIcon(factory, frame, theme, "title_settings_icon", "Options", { desaturate = true })
end

-- Title-bar icon button with the shared hover paint and tooltip.
-- textureKey names a theme.TEXTURES entry; the caller sets OnClick.
-- opts (optional): hintKey adds a second tooltip line; desaturate greys the
-- icon. Returns { button, bg, icon, setActive, applyTheme }: while active,
-- the button keeps its hover paint (the gear while Options is open).
function Buttons.CreatePlainIcon(factory, frame, theme, textureKey, tooltipKey, opts)
  theme = theme or Theme
  opts = opts or {}

  local button = factory.CreateFrame("Button", nil, frame)
  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  IconButtonStyle.Attach(button, bg)
  local icon = button:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(button, icon, theme.TEXTURES[textureKey])
  icon:SetSize(theme.LAYOUT.TITLE_ICON_SIZE, theme.LAYOUT.TITLE_ICON_SIZE)
  icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  if opts.desaturate then
    icon:SetDesaturated(true)
  end

  local active = false
  local function applyVisuals(hovered)
    applyVertexColor(icon, IconButtonStyle.Paint(button, hovered or active, theme.COLORS))
  end

  local function isHovered()
    return button.IsMouseOver and button:IsMouseOver()
  end

  if button.SetScript then
    button:SetScript("OnEnter", function()
      applyVisuals(true)
      showTooltip(button, tooltipKey, opts.hintKey)
    end)
    button:SetScript("OnLeave", function()
      applyVisuals(false)
      hideTooltip()
    end)
  end
  button:EnableMouse(true)
  applyVisuals(false)

  return {
    button = button,
    bg = bg,
    icon = icon,
    setActive = function(nextActive)
      active = nextActive == true
      applyVisuals(isHovered())
    end,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

-- Starts hidden; ChromeBuilder shows it while the options pane is open.
function Buttons.CreateBack(factory, frame, theme)
  local back = Buttons.CreatePlainIcon(factory, frame, theme, "title_back_icon", "Back")
  back.icon:SetDesaturated(true)
  back.button:Hide()
  return back
end

ns.MessengerWindowChromeBuilderButtons = Buttons

return Buttons
