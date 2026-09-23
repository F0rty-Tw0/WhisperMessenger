local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local DropdownSkin = ns.MessengerWindowDropdownSkin or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSkin")
local applyColorTexture = UIHelpers.applyColorTexture

local DropdownSelector = {}

local DEFAULT_BUTTON_HEIGHT = 26
local DEFAULT_MENU_HEIGHT = 156

function DropdownSelector.Create(factory, parent, options)
  options = options or {}

  local labelText = options.labelText
  local optionsList = type(options.optionsList) == "table" and options.optionsList or {}
  local getOptions = options.getOptions
  local fallbackKey = options.fallbackKey
  local initial = options.initial
  local colors = options.colors or {}
  local onChange = options.onChange
  local rowWidth = options.rowWidth or 280
  local labelSpacing = options.labelSpacing or 6
  local buttonHeight = options.buttonHeight or DEFAULT_BUTTON_HEIGHT
  local menuHeight = options.menuHeight or DEFAULT_MENU_HEIGHT
  local rowHeight = buttonHeight + 20

  local palette = DropdownSkin.Palette(Theme.COLORS, colors)

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(rowWidth, rowHeight)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(labelText)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local button = factory.CreateFrame("Button", nil, row)
  button:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -labelSpacing)
  button:SetSize(rowWidth, buttonHeight)

  -- DropdownSkin anchors the label clear of the chevron.
  local buttonLabel = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  buttonLabel:SetJustifyH("LEFT")
  button.label = buttonLabel
  local skin = DropdownSkin.Attach(button, buttonLabel)

  local menu = factory.CreateFrame("ScrollFrame", nil, row)
  menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
  menu:SetFrameLevel((row.GetFrameLevel and row:GetFrameLevel() or 1) + 20)
  menu:SetClampedToScreen(true)
  menu:EnableMouseWheel(true)
  if menu.SetClipsChildren then
    menu:SetClipsChildren(true)
  end

  local menuBg = menu:CreateTexture(nil, "BACKGROUND")
  menuBg:SetAllPoints(menu)

  local content = factory.CreateFrame("Frame", nil, menu)
  content:SetSize(rowWidth, buttonHeight)
  menu:SetScrollChild(content)
  content:Show()
  menu:Hide()

  local optionButtons = {}
  local buttonPool = {}
  local selected = initial
  local buttonHovered = false

  local function mergePalette(nextColors)
    if type(nextColors) ~= "table" then
      return
    end
    for key in pairs(palette) do
      palette[key] = nextColors[key] or palette[key]
    end
  end

  local function findOption(key)
    for _, option in ipairs(optionsList) do
      if option.key == key then
        return option
      end
    end
    return nil
  end

  local function paintClosedButton()
    DropdownSkin.Paint(skin, buttonLabel, buttonHovered)
  end

  local function paintOptionButton(optionButton)
    if optionButton._key == selected then
      applyColorTexture(optionButton.bg, palette.bgActive)
      UIHelpers.setTextColor(optionButton.label, palette.textActive)
    elseif optionButton._hovered then
      applyColorTexture(optionButton.bg, palette.bgHover)
      UIHelpers.setTextColor(optionButton.label, palette.textHover)
    else
      applyColorTexture(optionButton.bg, palette.bg)
      UIHelpers.setTextColor(optionButton.label, palette.text)
    end
  end

  local function repaintOptions()
    for _, optionButton in ipairs(optionButtons) do
      paintOptionButton(optionButton)
    end
  end

  local function updateSelection(key)
    local option = findOption(key) or findOption(fallbackKey) or optionsList[1]
    selected = option and option.key or fallbackKey
    buttonLabel:SetText(option and option.label or "")
    repaintOptions()
  end

  local function createOptionButton()
    local optionButton = factory.CreateFrame("Button", nil, content)
    local bg = optionButton:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(optionButton)

    local optionLabel = optionButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    optionLabel:SetPoint("LEFT", optionButton, "LEFT", 8, 0)
    optionLabel:SetPoint("RIGHT", optionButton, "RIGHT", -8, 0)
    optionLabel:SetJustifyH("LEFT")

    optionButton.bg = bg
    optionButton.label = optionLabel
    optionButton._hovered = false

    optionButton:SetScript("OnClick", function()
      local key = optionButton._key
      updateSelection(key)
      if onChange then
        onChange(key)
      end
      menu:Hide()
    end)
    optionButton:SetScript("OnEnter", function()
      optionButton._hovered = true
      paintOptionButton(optionButton)
    end)
    optionButton:SetScript("OnLeave", function()
      optionButton._hovered = false
      paintOptionButton(optionButton)
    end)

    buttonPool[#buttonPool + 1] = optionButton
    return optionButton
  end

  local function layoutOptions()
    local contentHeight = #optionButtons * buttonHeight
    local popupHeight = math.min(menuHeight, math.max(buttonHeight, contentHeight))

    for i, optionButton in ipairs(optionButtons) do
      optionButton:ClearAllPoints()
      if i == 1 then
        optionButton:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
      else
        optionButton:SetPoint("TOPLEFT", optionButtons[i - 1], "BOTTOMLEFT", 0, 0)
      end
      optionButton:SetSize(rowWidth, buttonHeight)
    end

    menu:SetSize(rowWidth, popupHeight)
    content:SetSize(rowWidth, math.max(contentHeight, popupHeight))
    if menu.UpdateScrollChildRect then
      menu:UpdateScrollChildRect()
    end
    menu:SetVerticalScroll(math.min(menu:GetVerticalScroll(), menu:GetVerticalScrollRange()))
  end

  local function setOptionsList(nextOptions)
    if type(nextOptions) ~= "table" then
      return
    end

    optionsList = nextOptions
    local previousCount = #optionButtons
    for i, option in ipairs(optionsList) do
      local optionButton = buttonPool[i] or createOptionButton()
      optionButton._key = option.key
      optionButton._hovered = false
      optionButton.label:SetText(option.label)
      optionButton:Show()
      optionButtons[i] = optionButton
    end
    for i = #optionsList + 1, previousCount do
      optionButtons[i] = nil
    end
    for i = #optionsList + 1, #buttonPool do
      buttonPool[i]:Hide()
    end

    layoutOptions()
    updateSelection(selected)
  end

  menu:SetScript("OnMouseWheel", function(_, delta)
    local nextOffset = menu:GetVerticalScroll() - delta * buttonHeight
    local scrollRange = menu:GetVerticalScrollRange()
    menu:SetVerticalScroll(math.max(0, math.min(scrollRange, nextOffset)))
  end)

  button:SetScript("OnClick", function()
    if menu:IsShown() then
      menu:Hide()
      return
    end

    if type(getOptions) == "function" then
      local refreshed = getOptions()
      if type(refreshed) == "table" then
        setOptionsList(refreshed)
      end
    end
    menu:SetVerticalScroll(0)
    menu:Raise()
    menu:Show()
  end)
  button:SetScript("OnEnter", function()
    buttonHovered = true
    paintClosedButton()
  end)
  button:SetScript("OnLeave", function()
    buttonHovered = false
    paintClosedButton()
  end)

  if parent and parent.GetScript and parent.SetScript then
    local parentOnHide = parent:GetScript("OnHide")
    parent:SetScript("OnHide", function(...)
      if parentOnHide then
        parentOnHide(...)
      end
      menu:Hide()
    end)
  end

  setOptionsList(optionsList)
  paintClosedButton()
  applyColorTexture(menuBg, palette.bg)

  return {
    row = row,
    label = labelFs,
    button = button,
    setSelected = updateSelection,
    setOptionsList = setOptionsList,
    setWidth = function(nextWidth)
      if type(nextWidth) ~= "number" or nextWidth <= 0 then
        return
      end
      rowWidth = nextWidth
      row:SetSize(rowWidth, rowHeight)
      button:SetSize(rowWidth, buttonHeight)
      layoutOptions()
    end,
    applyTheme = function(activeTheme, nextColors)
      if type(activeTheme) == "table" and type(activeTheme.COLORS) == "table" then
        UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
        if type(nextColors) ~= "table" then
          nextColors = DropdownSkin.Palette(activeTheme.COLORS)
        end
      end
      mergePalette(nextColors)
      paintClosedButton()
      repaintOptions()
      applyColorTexture(menuBg, palette.bg)
    end,
  }
end

ns.MessengerWindowDropdownSelector = DropdownSelector
return DropdownSelector
