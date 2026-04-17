local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

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
  if newConversationButton.SetScript then
    newConversationButton:SetScript("OnEnter", function()
      applyVertexColor(newConversationIcon, theme.COLORS.text_title or theme.COLORS.text_primary)
      do
        local bc = theme.COLORS.bg_contact_hover
        applyColorTexture(newConversationBg, { bc[1], bc[2], bc[3], 0.75 })
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(newConversationButton, "ANCHOR_TOP")
        _G.GameTooltip:SetText("Start New Whisper")
        if _G.GameTooltip.AddLine then
          pcall(_G.GameTooltip.AddLine, _G.GameTooltip, "Open an empty conversation thread.", 1, 1, 1)
        end
        _G.GameTooltip:Show()
      end
    end)
    newConversationButton:SetScript("OnLeave", function()
      applyVertexColor(newConversationIcon, theme.COLORS.text_primary)
      local bc = theme.COLORS.bg_contact_hover
      applyColorTexture(newConversationBg, { bc[1], bc[2], bc[3], 0.35 })
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
  }
end

-- Creates the gear/options button. Anchors to the left of the close button
-- when present; otherwise pins near the top-right of the frame. Returns the
-- button plus the textures applyTheme needs to repaint.
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
  applyColorTexture(optionsBg, { 0, 0, 0, 0 })
  local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
  optionsIcon:SetSize(theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
  optionsIcon:SetPoint("CENTER", optionsButton, "CENTER", 0, 0)
  optionsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  optionsIcon:SetDesaturated(true)
  applyVertexColor(optionsIcon, theme.COLORS.text_secondary)
  if optionsButton.SetScript then
    optionsButton:SetScript("OnEnter", function()
      applyVertexColor(optionsIcon, theme.COLORS.text_primary)
      do
        local bc = theme.COLORS.bg_contact_hover
        applyColorTexture(optionsBg, { bc[1], bc[2], bc[3], 0.5 })
      end
    end)
    optionsButton:SetScript("OnLeave", function()
      applyVertexColor(optionsIcon, theme.COLORS.text_secondary)
      applyColorTexture(optionsBg, { 0, 0, 0, 0 })
    end)
  end
  optionsButton:EnableMouse(true)

  return {
    button = optionsButton,
    bg = optionsBg,
    icon = optionsIcon,
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

  if resizeGrip.SetScript then
    resizeGrip:SetScript("OnEnter", function()
      local c = theme.COLORS.text_primary
      local hoverColor = { c[1], c[2], c[3], 1 }
      for _, line in ipairs(resizeLines) do
        applyColorTexture(line, hoverColor)
      end
    end)
    resizeGrip:SetScript("OnLeave", function()
      local c = theme.COLORS.text_secondary
      local baseColor = { c[1], c[2], c[3], 0.4 }
      for _, line in ipairs(resizeLines) do
        applyColorTexture(line, baseColor)
      end
    end)
  end

  return {
    grip = resizeGrip,
    lines = resizeLines,
  }
end

ns.MessengerWindowChromeBuilderButtons = Buttons

return Buttons
