local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local ButtonSelector = {}

local DEFAULT_BUTTON_HEIGHT = 26
local DEFAULT_BUTTON_SPACING = 8

function ButtonSelector.Create(factory, parent, options)
  options = options or {}

  local labelText = options.labelText
  local optionsList = options.optionsList or {}
  local fallbackKey = options.fallbackKey
  local initial = options.initial
  local colors = options.colors or {}
  local onChange = options.onChange
  local rowWidth = options.rowWidth or 280
  local labelSpacing = options.labelSpacing or 6
  local fixedButtonWidth = options.buttonWidth
  local buttonHeight = options.buttonHeight or DEFAULT_BUTTON_HEIGHT
  local buttonSpacing = options.buttonSpacing or DEFAULT_BUTTON_SPACING
  local maxPerRow = options.maxPerRow

  local numRows = 1
  if maxPerRow and maxPerRow > 0 then
    numRows = math.ceil(#optionsList / maxPerRow)
  end
  local rowGap = 4

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(rowWidth, buttonHeight * numRows + rowGap * math.max(numRows - 1, 0) + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(labelText)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local function hasOptionKey(candidate)
    for _, opt in ipairs(optionsList) do
      if opt.key == candidate then
        return true
      end
    end
    return false
  end

  local buttons = {}
  local selected = hasOptionKey(initial) and initial or fallbackKey
  local palette = {
    bg = colors.bg or Theme.COLORS.option_button_bg,
    bgHover = colors.bgHover or Theme.COLORS.option_button_hover,
    bgActive = colors.bgActive or Theme.COLORS.option_button_active or Theme.COLORS.option_button_hover,
    text = colors.text or Theme.COLORS.option_button_text,
    textHover = colors.textHover or Theme.COLORS.option_button_text_hover,
    textActive = colors.textActive or Theme.COLORS.option_button_text_active or Theme.COLORS.text_primary,
  }

  local function paintButton(entry, isHovered)
    if entry._key == selected then
      entry._selected = true
      applyColorTexture(entry.bg, palette.bgActive)
      UIHelpers.setTextColor(entry.label, palette.textActive)
      return
    end

    entry._selected = false
    if isHovered then
      applyColorTexture(entry.bg, palette.bgHover)
      UIHelpers.setTextColor(entry.label, palette.textHover)
      return
    end

    applyColorTexture(entry.bg, palette.bg)
    UIHelpers.setTextColor(entry.label, palette.text)
  end

  local function repaintButtons()
    for _, entry in ipairs(buttons) do
      paintButton(entry, entry._hovered == true)
    end
  end

  local function updateSelection(nextSelected)
    selected = hasOptionKey(nextSelected) and nextSelected or fallbackKey
    repaintButtons()
  end

  local firstButtonOfRow = {}

  for i, opt in ipairs(optionsList) do
    local btn = factory.CreateFrame("Button", nil, row)

    local rowIndex = 1
    local colIndex = i
    if maxPerRow and maxPerRow > 0 then
      rowIndex = math.ceil(i / maxPerRow)
      colIndex = ((i - 1) % maxPerRow) + 1
    end

    if colIndex == 1 then
      if rowIndex == 1 then
        btn:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -labelSpacing)
      else
        local aboveBtn = firstButtonOfRow[rowIndex - 1]
        btn:SetPoint("TOPLEFT", aboveBtn, "BOTTOMLEFT", 0, -rowGap)
      end
      firstButtonOfRow[rowIndex] = btn
    else
      btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", buttonSpacing, 0)
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)

    local btnLabel = btn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    btnLabel:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnLabel:SetText(opt.label)

    local btnWidth = fixedButtonWidth
    if not btnWidth then
      local countInRow = maxPerRow and math.min(maxPerRow, #optionsList - (rowIndex - 1) * maxPerRow) or #optionsList
      local totalSpacing = buttonSpacing * math.max(countInRow - 1, 0)
      btnWidth = math.floor((rowWidth - totalSpacing) / math.max(countInRow, 1))
    end
    btn:SetSize(btnWidth, buttonHeight)

    btn._key = opt.key
    btn._selected = false
    btn._hovered = false
    btn.bg = bg
    btn.label = btnLabel

    btn:SetScript("OnClick", function()
      updateSelection(opt.key)
      if onChange then
        onChange(opt.key)
      end
    end)

    btn:SetScript("OnEnter", function()
      btn._hovered = true
      paintButton(btn, true)
      if opt.tooltip and _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        _G.GameTooltip:SetText(opt.label)
        if _G.GameTooltip.AddLine then
          pcall(_G.GameTooltip.AddLine, _G.GameTooltip, opt.tooltip, 1, 1, 1, true)
        end
        _G.GameTooltip:Show()
      end
    end)

    btn:SetScript("OnLeave", function()
      btn._hovered = false
      paintButton(btn, false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    table.insert(buttons, btn)
  end

  updateSelection(selected)

  local function mergePalette(nextColors)
    if type(nextColors) ~= "table" then
      return
    end
    palette.bg = nextColors.bg or palette.bg
    palette.bgHover = nextColors.bgHover or palette.bgHover
    palette.bgActive = nextColors.bgActive or palette.bgActive
    palette.text = nextColors.text or palette.text
    palette.textHover = nextColors.textHover or palette.textHover
    palette.textActive = nextColors.textActive or palette.textActive
  end

  return {
    row = row,
    label = labelFs,
    buttons = buttons,
    setSelected = updateSelection,
    setColors = function(nextColors)
      mergePalette(nextColors)
      repaintButtons()
    end,
    applyTheme = function(activeTheme, nextColors)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      mergePalette(nextColors)
      repaintButtons()
    end,
  }
end

ns.MessengerWindowButtonSelector = ButtonSelector

return ButtonSelector
