local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local applyColorTexture = UIHelpers.applyColorTexture
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

-- Creates the "New Whisper" button. Anchors differently per chrome: pinned
-- to the frame's top-left under the Blizzard template, or to the right of
-- the custom title in the modern chrome. Returns the button plus the
-- textures applyTheme needs to repaint.
function Buttons.CreateNewConversation(factory, frame, title, useBlizzardChrome, theme)
  theme = theme or Theme

  local newConversationButton = factory.CreateFrame("Button", nil, frame)
  newConversationButton:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  if useBlizzardChrome then
    -- Anchor at the top-left of the template's title bar.
    newConversationButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -3)
  else
    -- Anchor to the right of the custom title text.
    newConversationButton:SetPoint("LEFT", title, "RIGHT", 2, 0)
  end
  local newConversationBg = newConversationButton:CreateTexture(nil, "BACKGROUND")
  newConversationBg:SetAllPoints(newConversationButton)
  local newConversationBase = theme.COLORS.bg_contact_hover
  applyColorTexture(newConversationBg, { newConversationBase[1], newConversationBase[2], newConversationBase[3], 0.35 })
  local newConversationIcon = newConversationButton:CreateTexture(nil, "ARTWORK")
  newConversationIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  newConversationIcon:SetPoint("CENTER", newConversationButton, "CENTER", 0, 0)
  newConversationIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  newConversationIcon:SetDesaturated(true)
  applyVertexColor(newConversationIcon, theme.COLORS.text_primary)
  local function applyVisuals(hovered)
    if hovered then
      applyVertexColor(newConversationIcon, theme.COLORS.text_title or theme.COLORS.text_primary)
      local bc = theme.COLORS.bg_contact_hover
      applyColorTexture(newConversationBg, { bc[1], bc[2], bc[3], 0.75 })
      return
    end

    applyVertexColor(newConversationIcon, theme.COLORS.text_primary)
    local bc = theme.COLORS.bg_contact_hover
    applyColorTexture(newConversationBg, { bc[1], bc[2], bc[3], 0.35 })
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
function Buttons.CreateOptions(factory, frame, closeButton, theme)
  theme = theme or Theme

  local optionsButton = factory.CreateFrame("Button", nil, frame)
  optionsButton:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  if closeButton then
    optionsButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
  else
    optionsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -4)
  end
  local optionsBg = optionsButton:CreateTexture(nil, "BACKGROUND")
  optionsBg:SetAllPoints(optionsButton)
  local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
  optionsIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  optionsIcon:SetPoint("CENTER", optionsButton, "CENTER", 0, 0)
  optionsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  optionsIcon:SetDesaturated(true)

  local active = false
  local function applyVisuals(hovered)
    local colors = theme.COLORS
    if active then
      applyColorTexture(
        optionsBg,
        hovered and (colors.option_button_active_hover or colors.option_button_active or colors.bg_contact_selected)
          or (colors.option_button_active or colors.bg_contact_selected)
      )
      applyVertexColor(optionsIcon, colors.option_button_text_active or colors.text_primary)
      return
    end

    if hovered then
      applyColorTexture(optionsBg, colors.option_button_hover or colors.bg_contact_hover)
      applyVertexColor(optionsIcon, colors.option_button_text_hover or colors.text_primary)
      return
    end

    applyColorTexture(optionsBg, colors.option_button_bg or { 0, 0, 0, 0 })
    applyVertexColor(optionsIcon, colors.option_button_text or colors.text_secondary)
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

function Buttons.CreateBack(factory, frame, optionsButton, theme)
  theme = theme or Theme

  local backButton = factory.CreateFrame("Button", nil, frame)
  backButton:SetSize(theme.LAYOUT.CHROME_BUTTON_SIZE, theme.LAYOUT.CHROME_BUTTON_SIZE)
  backButton:SetPoint("RIGHT", optionsButton, "LEFT", -2, 0)
  local backBg = backButton:CreateTexture(nil, "BACKGROUND")
  backBg:SetAllPoints(backButton)
  local backIcon = backButton:CreateTexture(nil, "ARTWORK")
  backIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  backIcon:SetPoint("CENTER", backButton, "CENTER", 0, 0)
  backIcon:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
  backIcon:SetDesaturated(true)

  local function applyVisuals(hovered)
    local colors = theme.COLORS
    if hovered then
      applyColorTexture(backBg, colors.option_button_hover or colors.bg_contact_hover)
      applyVertexColor(backIcon, colors.option_button_text_hover or colors.text_primary)
      return
    end

    applyColorTexture(backBg, colors.option_button_bg or { 0, 0, 0, 0 })
    applyVertexColor(backIcon, colors.option_button_text or colors.text_secondary)
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

-- Creates the bottom-right resize grip. Renders a triangular dot-pattern
-- using six small OVERLAY textures. Returns the grip frame plus the list
-- of line textures so applyTheme can repaint the base color.
function Buttons.CreateResizeGrip(factory, frame, theme)
  theme = theme or Theme

  local resizeGrip = factory.CreateFrame("Frame", nil, frame)
  resizeGrip:SetSize(16, 16)
  resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  resizeGrip:EnableMouse(true)
  if resizeGrip.SetFrameLevel and frame.GetFrameLevel then
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 20)
  end
  local resizeLines = {}
  do
    local c = theme.COLORS.text_secondary
    local gripColor = { c[1], c[2], c[3], 0.4 }
    local line1 = resizeGrip:CreateTexture(nil, "OVERLAY")
    line1:SetSize(2, 2)
    line1:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -1, 1)
    applyColorTexture(line1, gripColor)
    resizeLines[#resizeLines + 1] = line1

    local line2 = resizeGrip:CreateTexture(nil, "OVERLAY")
    line2:SetSize(6, 2)
    line2:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -1, 5)
    applyColorTexture(line2, gripColor)
    resizeLines[#resizeLines + 1] = line2
    local line2h = resizeGrip:CreateTexture(nil, "OVERLAY")
    line2h:SetSize(2, 6)
    line2h:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -5, 1)
    applyColorTexture(line2h, gripColor)
    resizeLines[#resizeLines + 1] = line2h

    local line3 = resizeGrip:CreateTexture(nil, "OVERLAY")
    line3:SetSize(10, 2)
    line3:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -1, 9)
    applyColorTexture(line3, gripColor)
    resizeLines[#resizeLines + 1] = line3
    local line3h = resizeGrip:CreateTexture(nil, "OVERLAY")
    line3h:SetSize(2, 10)
    line3h:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -9, 1)
    applyColorTexture(line3h, gripColor)
    resizeLines[#resizeLines + 1] = line3h
  end

  local function applyVisuals(hovered)
    local c = theme.COLORS[hovered and "text_primary" or "text_secondary"]
    local color = { c[1], c[2], c[3], hovered and 1 or 0.4 }
    for _, line in ipairs(resizeLines) do
      applyColorTexture(line, color)
    end
  end

  local function isHovered()
    return resizeGrip.IsMouseOver and resizeGrip:IsMouseOver()
  end

  if resizeGrip.SetScript then
    resizeGrip:SetScript("OnEnter", function()
      applyVisuals(true)
    end)
    resizeGrip:SetScript("OnLeave", function()
      applyVisuals(false)
    end)
  end

  return {
    grip = resizeGrip,
    lines = resizeLines,
    applyTheme = function(nextTheme)
      theme = nextTheme or Theme
      applyVisuals(isHovered())
    end,
  }
end

ns.MessengerWindowChromeBuilderButtons = Buttons

return Buttons
