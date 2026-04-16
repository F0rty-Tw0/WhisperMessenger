local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor
local setTextColor = UIHelpers.setTextColor
local ChromeBuilder = {}

-- Creates the outer frame, background, edge textures, title bar, title label,
-- close button, options button, new conversation button, and resize grip.
--
-- factory   : frame factory (provides CreateFrame)
-- parent    : parent frame (e.g. UIParent)
-- initialState : { anchorPoint, relativePoint, x, y, width, height }
-- options   : { title, onClose }
--
-- Returns: { frame, background, titleBar, title, newConversationButton, closeButton, optionsButton, resizeGrip }
function ChromeBuilder.Build(factory, parent, initialState, options)
  options = options or {}

  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent)
  frame:SetSize(initialState.width or Theme.WINDOW_WIDTH, initialState.height or Theme.WINDOW_HEIGHT)
  frame:SetPoint(
    initialState.anchorPoint or "CENTER",
    parent,
    initialState.relativePoint or initialState.anchorPoint or "CENTER",
    initialState.x or 0,
    initialState.y or 0
  )
  if frame.SetFrameStrata then
    frame:SetFrameStrata("MEDIUM")
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetResizable(true)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, Theme)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
  else
    frame:SetMinResize(minWidth, minHeight)
    if frame.SetMaxResize and maxWidth and maxHeight then
      frame:SetMaxResize(maxWidth, maxHeight)
    end
  end
  frame:SetClampedToScreen(true)

  local frameName = frame.GetName and frame:GetName() or frame.name
  if type(_G.UISpecialFrames) == "table" and frameName ~= nil then
    local alreadyRegistered = false
    for _, specialFrameName in ipairs(_G.UISpecialFrames) do
      if specialFrameName == frameName then
        alreadyRegistered = true
        break
      end
    end
    if not alreadyRegistered then
      table.insert(_G.UISpecialFrames, frameName)
    end
  end

  if frame.SetAlpha then
    frame:SetAlpha(Theme.WINDOW_IDLE_ALPHA)
  else
    frame.alpha = Theme.WINDOW_IDLE_ALPHA
  end

  -- Window background
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  applyColorTexture(background, Theme.COLORS.bg_primary)
  frame.background = background

  -- Subtle edge highlights (1px border)
  local edgeTextures = UIHelpers.createBorderBox(frame, Theme.COLORS.divider, 1, "BORDER")

  -- Title bar with header background
  local titleBar = factory.CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  titleBar:SetHeight(Theme.TOP_BAR_HEIGHT)
  local titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
  titleBarBg:SetAllPoints(titleBar)
  applyColorTexture(titleBarBg, Theme.COLORS.bg_header)
  local titleBarBorder = UIHelpers.createBorderBox(
    titleBar,
    Theme.COLORS.divider,
    Theme.DIVIDER_THICKNESS,
    "BORDER",
    { top = true, left = true, right = true, bottom = false }
  )
  local titleBarTopBorder = titleBarBorder and titleBarBorder.top or nil

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -9)
  title:SetText(options.title or Theme.TITLE)
  setTextColor(title, Theme.COLORS.text_title or Theme.COLORS.text_primary)
  if title.SetShadowColor then
    title:SetShadowColor(0, 0, 0, 0.85)
  end
  if title.SetShadowOffset then
    title:SetShadowOffset(1, -1)
  end
  frame.title = title

  local newConversationButton = factory.CreateFrame("Button", nil, frame)
  newConversationButton:SetSize(24, 24)
  newConversationButton:SetPoint("LEFT", title, "RIGHT", 6, 0)
  local newConversationBg = newConversationButton:CreateTexture(nil, "BACKGROUND")
  newConversationBg:SetAllPoints(newConversationButton)
  local newConversationBase = Theme.COLORS.bg_contact_hover
  applyColorTexture(newConversationBg, { newConversationBase[1], newConversationBase[2], newConversationBase[3], 0.35 })
  local newConversationIcon = newConversationButton:CreateTexture(nil, "ARTWORK")
  newConversationIcon:SetSize(16, 16)
  newConversationIcon:SetPoint("CENTER", newConversationButton, "CENTER", 0, 0)
  newConversationIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  newConversationIcon:SetDesaturated(true)
  applyVertexColor(newConversationIcon, Theme.COLORS.text_primary)
  if newConversationButton.SetScript then
    newConversationButton:SetScript("OnEnter", function()
      applyVertexColor(newConversationIcon, Theme.COLORS.text_title or Theme.COLORS.text_primary)
      do
        local bc = Theme.COLORS.bg_contact_hover
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
      applyVertexColor(newConversationIcon, Theme.COLORS.text_primary)
      local bc = Theme.COLORS.bg_contact_hover
      applyColorTexture(newConversationBg, { bc[1], bc[2], bc[3], 0.35 })
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end
  newConversationButton:EnableMouse(true)

  -- Custom close button (no template)
  local closeButton = factory.CreateFrame("Button", nil, frame)
  closeButton:SetSize(28, 28)
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
  local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
  closeBg:SetAllPoints(closeButton)
  applyColorTexture(closeBg, { 0, 0, 0, 0 })
  local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
  closeIcon:SetSize(18, 18)
  closeIcon:SetPoint("CENTER", closeButton, "CENTER", 0, 0)
  closeIcon:SetTexture("Interface\\Buttons\\UI-StopButton")
  closeIcon:SetDesaturated(true)
  applyVertexColor(closeIcon, Theme.COLORS.text_secondary)
  if closeButton.SetScript then
    closeButton:SetScript("OnEnter", function()
      applyVertexColor(closeIcon, { 0.9, 0.3, 0.3, 1 })
      applyColorTexture(closeBg, { 0.9, 0.3, 0.3, 0.15 })
    end)
    closeButton:SetScript("OnLeave", function()
      applyVertexColor(closeIcon, Theme.COLORS.text_secondary)
      applyColorTexture(closeBg, { 0, 0, 0, 0 })
    end)
  end
  closeButton:EnableMouse(true)

  -- Gear icon for options
  local optionsButton = factory.CreateFrame("Button", nil, frame)
  optionsButton:SetSize(28, 28)
  optionsButton:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
  local optionsBg = optionsButton:CreateTexture(nil, "BACKGROUND")
  optionsBg:SetAllPoints(optionsButton)
  applyColorTexture(optionsBg, { 0, 0, 0, 0 })
  local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
  optionsIcon:SetSize(18, 18)
  optionsIcon:SetPoint("CENTER", optionsButton, "CENTER", 0, 0)
  optionsIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  optionsIcon:SetDesaturated(true)
  applyVertexColor(optionsIcon, Theme.COLORS.text_secondary)
  if optionsButton.SetScript then
    optionsButton:SetScript("OnEnter", function()
      applyVertexColor(optionsIcon, Theme.COLORS.text_primary)
      do
        local bc = Theme.COLORS.bg_contact_hover
        applyColorTexture(optionsBg, { bc[1], bc[2], bc[3], 0.5 })
      end
    end)
    optionsButton:SetScript("OnLeave", function()
      applyVertexColor(optionsIcon, Theme.COLORS.text_secondary)
      applyColorTexture(optionsBg, { 0, 0, 0, 0 })
    end)
  end
  optionsButton:EnableMouse(true)

  -- Resize grip in bottom-right (triangle corner)
  local resizeGrip = factory.CreateFrame("Frame", nil, frame)
  resizeGrip:SetSize(16, 16)
  resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  resizeGrip:EnableMouse(true)
  if resizeGrip.SetFrameLevel and frame.GetFrameLevel then
    resizeGrip:SetFrameLevel(frame:GetFrameLevel() + 20)
  end
  local resizeLines = {}
  do
    local c = Theme.COLORS.text_secondary
    local gripColor = { c[1], c[2], c[3], 0.4 }
    -- Three diagonal lines forming a triangle in the corner
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

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme
    applyColorTexture(background, activeTheme.COLORS.bg_primary)
    applyColorTexture(titleBarBg, activeTheme.COLORS.bg_header)
    setTextColor(title, activeTheme.COLORS.text_title or activeTheme.COLORS.text_primary)

    local divider = activeTheme.COLORS.divider
    UIHelpers.applyBorderBoxColor(edgeTextures, { divider[1], divider[2], divider[3], divider[4] or 1 })
    UIHelpers.applyBorderBoxColor(titleBarBorder, divider)

    applyVertexColor(closeIcon, activeTheme.COLORS.text_secondary)
    applyVertexColor(optionsIcon, activeTheme.COLORS.text_secondary)
    applyVertexColor(newConversationIcon, activeTheme.COLORS.text_primary)
    local refreshedConversationBase = activeTheme.COLORS.bg_contact_hover
    applyColorTexture(
      newConversationBg,
      { refreshedConversationBase[1], refreshedConversationBase[2], refreshedConversationBase[3], 0.35 }
    )

    local secondary = activeTheme.COLORS.text_secondary
    local gripColor = { secondary[1], secondary[2], secondary[3], 0.4 }
    for _, line in ipairs(resizeLines) do
      applyColorTexture(line, gripColor)
    end
  end

  applyTheme(Theme)

  return {
    frame = frame,
    background = background,
    titleBar = titleBar,
    titleBarBorder = titleBarBorder,
    titleBarTopBorder = titleBarTopBorder,
    title = title,
    newConversationButton = newConversationButton,
    closeButton = closeButton,
    optionsButton = optionsButton,
    resizeGrip = resizeGrip,
    applyTheme = applyTheme,
  }
end

ns.MessengerWindowChromeBuilder = ChromeBuilder

return ChromeBuilder
