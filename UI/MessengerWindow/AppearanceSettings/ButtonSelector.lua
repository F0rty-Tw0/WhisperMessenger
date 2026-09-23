local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SelectorSkin = ns.MessengerWindowSelectorSkin or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.SelectorSkin")

local ButtonSelector = {}

local DEFAULT_BUTTON_HEIGHT = 26
local DEFAULT_BUTTON_SPACING = 8
local ROW_GAP = 4
local LABEL_BLOCK_HEIGHT = 20

local function showTooltip(btn)
  if not (btn._tooltipText and _G.GameTooltip and _G.GameTooltip.SetOwner) then
    return
  end
  _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
  _G.GameTooltip:SetText(btn._tooltipTitle)
  if _G.GameTooltip.AddLine then
    pcall(_G.GameTooltip.AddLine, _G.GameTooltip, btn._tooltipText, 1, 1, 1, true)
  end
  _G.GameTooltip:Show()
end

local function hideTooltip()
  if _G.GameTooltip and _G.GameTooltip.Hide then
    _G.GameTooltip:Hide()
  end
end

function ButtonSelector.Create(factory, parent, options)
  options = options or {}

  local optionsList = options.optionsList or {}
  local fallbackKey = options.fallbackKey
  local onChange = options.onChange
  local rowWidth = options.rowWidth or 280
  local labelSpacing = options.labelSpacing or 6
  local fixedButtonWidth = options.buttonWidth
  local buttonHeight = options.buttonHeight or DEFAULT_BUTTON_HEIGHT
  local buttonSpacing = options.buttonSpacing or DEFAULT_BUTTON_SPACING
  local maxPerRow = options.maxPerRow

  local row = factory.CreateFrame("Frame", nil, parent)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(options.labelText)
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
  local selected = hasOptionKey(options.initial) and options.initial or fallbackKey

  -- Colours come from Theme.COLORS at paint time (see SelectorSkin), so
  -- the `colors` option and applyTheme's colour table are no longer needed.
  local function paintButton(entry, isHovered)
    entry._selected = entry._key == selected
    SelectorSkin.Paint(entry, entry._selected, isHovered)
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

  -- Wraps to as many buttons per row as fit at label-plus-padding width
  -- (capped by maxPerRow), then shares each row's width evenly. A fixed
  -- buttonWidth is a floor, never narrower than the label needs.
  local function layout(nextRowWidth)
    rowWidth = nextRowWidth
    local count = #buttons
    local fitWidth = SelectorSkin.FitWidth(buttons)
    local fixedWidth = fixedButtonWidth and math.max(fixedButtonWidth, fitWidth) or nil
    local perRow = (maxPerRow and maxPerRow > 0) and math.min(maxPerRow, count) or count
    local fitsPerRow = math.floor((rowWidth + buttonSpacing) / ((fixedWidth or fitWidth) + buttonSpacing))
    perRow = math.max(1, math.min(perRow, fitsPerRow))
    local numRows = math.max(1, math.ceil(count / perRow))
    row:SetSize(rowWidth, buttonHeight * numRows + ROW_GAP * (numRows - 1) + LABEL_BLOCK_HEIGHT)

    for i, btn in ipairs(buttons) do
      local rowIndex = math.ceil(i / perRow)
      local colIndex = (i - 1) % perRow + 1
      btn:ClearAllPoints()
      if i == 1 then
        btn:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -labelSpacing)
      elseif colIndex == 1 then
        btn:SetPoint("TOPLEFT", buttons[i - perRow], "BOTTOMLEFT", 0, -ROW_GAP)
      else
        btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", buttonSpacing, 0)
      end
      local width = fixedWidth
      if not width then
        local countInRow = math.min(perRow, count - (rowIndex - 1) * perRow)
        width = math.floor((rowWidth - buttonSpacing * (countInRow - 1)) / countInRow)
      end
      btn:SetSize(width, buttonHeight)
    end
  end

  for _, opt in ipairs(optionsList) do
    local btn = factory.CreateFrame("Button", nil, row)
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)
    local btnLabel = btn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    btnLabel:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnLabel:SetText(opt.label)

    btn._key = opt.key
    btn._selected = false
    btn._hovered = false
    btn.bg = bg
    btn.label = btnLabel
    btn._tooltipTitle = opt.label
    btn._tooltipText = opt.tooltip
    SelectorSkin.Attach(btn)

    btn:SetScript("OnClick", function()
      updateSelection(btn._key)
      if onChange then
        onChange(btn._key)
      end
    end)
    btn:SetScript("OnEnter", function()
      btn._hovered = true
      paintButton(btn, true)
      showTooltip(btn)
    end)
    btn:SetScript("OnLeave", function()
      btn._hovered = false
      paintButton(btn, false)
      hideTooltip()
    end)

    buttons[#buttons + 1] = btn
  end

  layout(rowWidth)
  updateSelection(selected)

  return {
    row = row,
    label = labelFs,
    buttons = buttons,
    setSelected = updateSelection,
    setWidth = function(nextWidth)
      if type(nextWidth) ~= "number" or nextWidth <= 0 then
        return
      end
      layout(nextWidth)
    end,
    setOptionsList = function(nextOptions)
      if type(nextOptions) ~= "table" then
        return
      end
      for i, opt in ipairs(nextOptions) do
        local btn = buttons[i]
        if btn then
          btn.label:SetText(opt.label)
          btn._tooltipTitle = opt.label
          btn._tooltipText = opt.tooltip
        end
      end
      -- New (localized) labels may be wider: refit.
      layout(rowWidth)
    end,
    applyTheme = function(activeTheme)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      -- Font size/family changes alter label widths: refit.
      layout(rowWidth)
      repaintButtons()
    end,
  }
end

ns.MessengerWindowButtonSelector = ButtonSelector

return ButtonSelector
