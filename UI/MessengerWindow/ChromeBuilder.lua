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

-- ChromeBuilder builds the messenger window with one of two chrome paths
-- depending on the active skin (resolved from the active theme preset):
--
--   * BLIZZARD skin (Azeroth preset): frame uses BasicFrameTemplateWithInset.
--     Gold border, red close X, dark inset, and centered title come from
--     the Blizzard template — we don't paint them ourselves.
--
--   * MODERN skin (any other preset): frame uses BackdropTemplate. We paint
--     a custom flat-color background, our own title bar with header bg +
--     borders, edge highlights, and a custom close button. This is the
--     pre-Azeroth chrome, restored as an explicit branch so non-native
--     presets keep their modern minimal look.
--
-- Returns: { frame, background, title, newConversationButton, closeButton,
--   optionsButton, resizeGrip, applyTheme } in both cases. Non-chrome
-- layout (rows, composer margins, content positioning) is shared and
-- applied universally by callers regardless of which chrome was built.
function ChromeBuilder.Build(factory, parent, initialState, options)
  options = options or {}

  -- Chrome choice is now controlled by an explicit setting passed in
  -- `options.useNativeChrome` (independent of the color preset). Falls
  -- back to false (modern chrome) if the caller didn't pass it.
  local useBlizzardChrome = options.useNativeChrome == true

  local frame
  if useBlizzardChrome then
    frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BasicFrameTemplateWithInset")
  else
    -- BackdropTemplate mixin makes :SetBackdrop available on Retail 9.0+
    -- (the modern path doesn't use SetBackdrop today, but keeping the mixin
    -- lets us paint a backdrop later without recreating the frame).
    frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent, "BackdropTemplate")
  end

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

  -- Chrome differs by skin. Each branch produces:
  --   background, title, closeButton, applyChromePaint
  local background, title, closeButton
  local applyChromePaint

  -- Modern-chrome captures (declared at outer scope so applyChromePaint can
  -- close over them; nil under blizzard chrome and the closure no-ops).
  local titleBarBg, titleBarBorder, edgeTextures, closeIcon

  local blizzardTopBarExtension
  if useBlizzardChrome then
    local titleText = options.title or Theme.TITLE
    if frame.SetTitle then
      frame:SetTitle(titleText)
    elseif frame.TitleText and frame.TitleText.SetText then
      frame.TitleText:SetText(titleText)
    end
    background = frame.Bg
    title = frame.TitleText
    closeButton = frame.CloseButton

    -- Double the apparent top bar height: fill the space below the
    -- template's title strip with bg_header, and shift the Inset down
    -- by the same amount so content starts below the extended bar.
    local EXTRA_TITLE_HEIGHT = 24
    blizzardTopBarExtension = frame:CreateTexture(nil, "ARTWORK")
    blizzardTopBarExtension:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -Theme.LAYOUT.TOP_BAR_HEIGHT)
    -- -6 right matches the Inset's own BOTTOMRIGHT inset so the top status
    -- bar extension and the content area share the same right edge (2px
    -- more padding than the default 4px, giving the corner some breathing
    -- room away from the resize grip).
    blizzardTopBarExtension:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -Theme.LAYOUT.TOP_BAR_HEIGHT)
    blizzardTopBarExtension:SetHeight(EXTRA_TITLE_HEIGHT)
    applyColorTexture(blizzardTopBarExtension, Theme.COLORS.bg_header)

    if frame.Inset and frame.Inset.ClearAllPoints and frame.Inset.SetPoint then
      frame.Inset:ClearAllPoints()
      frame.Inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(Theme.LAYOUT.TOP_BAR_HEIGHT + EXTRA_TITLE_HEIGHT))
      -- +8px of chrome visible at the bottom (Inset bottom raised).
      frame.Inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 34)
    end

    applyChromePaint = function(activeTheme)
      activeTheme = activeTheme or Theme
      if blizzardTopBarExtension then
        applyColorTexture(blizzardTopBarExtension, activeTheme.COLORS.bg_header)
      end
    end
  else
    -- Modern: custom flat background
    background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(frame)
    applyColorTexture(background, Theme.COLORS.bg_primary)
    frame.background = background

    -- Subtle edge highlights (1px border)
    edgeTextures = UIHelpers.createBorderBox(frame, Theme.COLORS.divider, Theme.LAYOUT.DIVIDER_THICKNESS, "BORDER")

    -- Title bar with header background
    local titleBar = factory.CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(Theme.TOP_BAR_HEIGHT)
    titleBarBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBarBg:SetAllPoints(titleBar)
    applyColorTexture(titleBarBg, Theme.COLORS.bg_header)
    titleBarBorder = UIHelpers.createBorderBox(
      titleBar,
      Theme.COLORS.divider,
      Theme.DIVIDER_THICKNESS,
      "BORDER",
      { top = true, left = true, right = true, bottom = false }
    )

    -- Title lives on titleBar (not frame) so its OVERLAY layer renders above
    -- titleBarBg. Child-frame layers paint on top of parent-frame layers at
    -- the same frame level, so a fontstring on frame would be hidden behind
    -- any titleBarBg with non-trivial alpha (Shadowlands 0.90, Azeroth 1.0).
    title = titleBar:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
    title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 4, -6)
    title:SetText(options.title or Theme.TITLE)
    if title.SetFont then
      local fontPath, _, flags = title:GetFont()
      if fontPath then
        title:SetFont(fontPath, 10, flags)
      end
    end
    setTextColor(title, Theme.COLORS.text_title or Theme.COLORS.text_primary)
    if title.SetShadowColor then
      title:SetShadowColor(0, 0, 0, 0.85)
    end
    if title.SetShadowOffset then
      title:SetShadowOffset(1, -1)
    end
    frame.title = title

    -- Custom close button (no template)
    closeButton = factory.CreateFrame("Button", nil, frame)
    closeButton:SetSize(Theme.LAYOUT.CHROME_BUTTON_SIZE, Theme.LAYOUT.CHROME_BUTTON_SIZE)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    local closeBg = closeButton:CreateTexture(nil, "BACKGROUND")
    closeBg:SetAllPoints(closeButton)
    applyColorTexture(closeBg, { 0, 0, 0, 0 })
    closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
    closeIcon:SetSize(Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
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

    applyChromePaint = function(activeTheme)
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
  end

  local newConversationButton = factory.CreateFrame("Button", nil, frame)
  newConversationButton:SetSize(Theme.LAYOUT.CHROME_BUTTON_SIZE, Theme.LAYOUT.CHROME_BUTTON_SIZE)
  if useBlizzardChrome then
    -- Anchor at the top-left of the template's title bar.
    newConversationButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -3)
  else
    -- Anchor to the right of the custom title text.
    newConversationButton:SetPoint("LEFT", title, "RIGHT", 2, 0)
  end
  local newConversationBg = newConversationButton:CreateTexture(nil, "BACKGROUND")
  newConversationBg:SetAllPoints(newConversationButton)
  local newConversationBase = Theme.COLORS.bg_contact_hover
  applyColorTexture(newConversationBg, { newConversationBase[1], newConversationBase[2], newConversationBase[3], 0.35 })
  local newConversationIcon = newConversationButton:CreateTexture(nil, "ARTWORK")
  newConversationIcon:SetSize(Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
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

  -- Gear icon for options. Anchor relative to the close button so it sits
  -- cleanly to its left in both chromes.
  local optionsButton = factory.CreateFrame("Button", nil, frame)
  optionsButton:SetSize(Theme.LAYOUT.CHROME_BUTTON_SIZE, Theme.LAYOUT.CHROME_BUTTON_SIZE)
  if closeButton then
    optionsButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
  else
    optionsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -4)
  end
  local optionsBg = optionsButton:CreateTexture(nil, "BACKGROUND")
  optionsBg:SetAllPoints(optionsButton)
  applyColorTexture(optionsBg, { 0, 0, 0, 0 })
  local optionsIcon = optionsButton:CreateTexture(nil, "ARTWORK")
  optionsIcon:SetSize(Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE, Theme.LAYOUT.CHROME_BUTTON_ICON_SIZE)
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
      local c = Theme.COLORS.text_primary
      local hoverColor = { c[1], c[2], c[3], 1 }
      for _, line in ipairs(resizeLines) do
        applyColorTexture(line, hoverColor)
      end
    end)
    resizeGrip:SetScript("OnLeave", function()
      local c = Theme.COLORS.text_secondary
      local baseColor = { c[1], c[2], c[3], 0.4 }
      for _, line in ipairs(resizeLines) do
        applyColorTexture(line, baseColor)
      end
    end)
  end

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or Theme

    applyChromePaint(activeTheme)

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
    title = title,
    newConversationButton = newConversationButton,
    closeButton = closeButton,
    optionsButton = optionsButton,
    resizeGrip = resizeGrip,
    applyTheme = applyTheme,
    titleBarBorder = titleBarBorder,
    titleBarTopBorder = titleBarBorder and titleBarBorder.top or nil,
  }
end

ns.MessengerWindowChromeBuilder = ChromeBuilder

return ChromeBuilder
