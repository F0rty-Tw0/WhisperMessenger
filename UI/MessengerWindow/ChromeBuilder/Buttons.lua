local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IconButtonStyle = ns.MessengerWindowChromeBuilderIconButtonStyle or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.IconButtonStyle")
local applyVertexColor = UIHelpers.applyVertexColor

local function showTooltip(button, textKey)
  if _G.GameTooltip and _G.GameTooltip.SetOwner then
    _G.GameTooltip:SetOwner(button, "ANCHOR_TOP")
    _G.GameTooltip:SetText(Localization.Text(textKey))
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
  theme = theme or Theme

  local newConversationButton = factory.CreateFrame("Button", nil, frame)
  local newConversationBg = newConversationButton:CreateTexture(nil, "BACKGROUND")
  newConversationBg:SetAllPoints(newConversationButton)
  IconButtonStyle.Attach(newConversationButton, newConversationBg)
  local newConversationIcon = newConversationButton:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(newConversationButton, newConversationIcon, theme.TEXTURES.title_new_whisper_icon)
  newConversationIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  newConversationIcon:SetPoint("CENTER", newConversationButton, "CENTER", 0, 0)
  newConversationIcon:SetDesaturated(true)
  local function applyVisuals(hovered)
    applyVertexColor(newConversationIcon, IconButtonStyle.Paint(newConversationButton, hovered, theme.COLORS))
  end

  local function isHovered()
    return newConversationButton.IsMouseOver and newConversationButton:IsMouseOver()
  end

  if newConversationButton.SetScript then
    newConversationButton:SetScript("OnEnter", function()
      applyVisuals(true)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(newConversationButton, "ANCHOR_TOP")
        _G.GameTooltip:SetText(Localization.Text("Start New Whisper"))
        if _G.GameTooltip.AddLine then
          pcall(_G.GameTooltip.AddLine, _G.GameTooltip, Localization.Text("Open an empty conversation thread."), 1, 1, 1)
        end
        _G.GameTooltip:Show()
      end
    end)
    newConversationButton:SetScript("OnLeave", function()
      applyVisuals(false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end
  newConversationButton:EnableMouse(true)
  applyVisuals(false)

  return {
    button = newConversationButton,
    bg = newConversationBg,
    icon = newConversationIcon,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

-- Creates the gear/options button. Its active state is kept locally so hover
-- never overwrites the selection paint while the options pane is visible.
function Buttons.CreateOptions(factory, frame, theme)
  theme = theme or Theme

  local optionsButton = factory.CreateFrame("Button", nil, frame)
  local optionsBg = optionsButton:CreateTexture(nil, "BACKGROUND")
  optionsBg:SetAllPoints(optionsButton)
  IconButtonStyle.Attach(optionsButton, optionsBg)
  local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(optionsButton, optionsIcon, theme.TEXTURES.title_settings_icon)
  optionsIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  optionsIcon:SetPoint("CENTER", optionsButton, "CENTER", 0, 0)
  optionsIcon:SetDesaturated(true)

  local active = false
  local function applyVisuals(hovered)
    applyVertexColor(optionsIcon, IconButtonStyle.Paint(optionsButton, hovered or active, theme.COLORS))
  end

  local function isHovered()
    return optionsButton.IsMouseOver and optionsButton:IsMouseOver()
  end

  local function setActive(nextActive)
    active = nextActive == true
    applyVisuals(isHovered())
  end

  if optionsButton.SetScript then
    optionsButton:SetScript("OnEnter", function()
      applyVisuals(true)
      showTooltip(optionsButton, "Options")
    end)
    optionsButton:SetScript("OnLeave", function()
      applyVisuals(false)
      hideTooltip()
    end)
  end
  optionsButton:EnableMouse(true)
  applyVisuals(false)

  return {
    button = optionsButton,
    bg = optionsBg,
    icon = optionsIcon,
    setActive = setActive,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

function Buttons.CreateBack(factory, frame, theme)
  theme = theme or Theme

  local backButton = factory.CreateFrame("Button", nil, frame)
  local backBg = backButton:CreateTexture(nil, "BACKGROUND")
  backBg:SetAllPoints(backButton)
  IconButtonStyle.Attach(backButton, backBg)
  local backIcon = backButton:CreateTexture(nil, "ARTWORK")
  IconButtonStyle.SetGlyph(backButton, backIcon, theme.TEXTURES.title_back_icon)
  backIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  backIcon:SetPoint("CENTER", backButton, "CENTER", 0, 0)
  backIcon:SetDesaturated(true)

  local function applyVisuals(hovered)
    applyVertexColor(backIcon, IconButtonStyle.Paint(backButton, hovered, theme.COLORS))
  end

  local function isHovered()
    return backButton.IsMouseOver and backButton:IsMouseOver()
  end

  if backButton.SetScript then
    backButton:SetScript("OnEnter", function()
      applyVisuals(true)
      showTooltip(backButton, "Back")
    end)
    backButton:SetScript("OnLeave", function()
      applyVisuals(false)
      hideTooltip()
    end)
  end
  backButton:EnableMouse(true)
  backButton:Hide()
  applyVisuals(false)

  return {
    button = backButton,
    bg = backBg,
    icon = backIcon,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

ns.MessengerWindowChromeBuilderButtons = Buttons

return Buttons
