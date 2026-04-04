local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")

local Controls = {}

function Controls.createOptionButton(factory, parent, label, colors, layout)
  local btnHeight = layout.height or 30
  local btnWidth = layout.width or 200

  local button = factory.CreateFrame("Button", nil, parent)
  button:SetSize(btnWidth, btnHeight)

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)

  local labelFs = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("CENTER", button, "CENTER", 0, 0)
  labelFs:SetText(label)

  button._wmHovered = false
  button._wmColors = {
    bg = colors.bg,
    bgHover = colors.bgHover or colors.bg,
    text = colors.text,
    textHover = colors.textHover or colors.text,
  }

  local function applyBaseState()
    local palette = button._wmColors
    Base.applyColorTexture(bg, palette.bg)
    Base.setTextColor(labelFs, palette.text)
  end

  local function applyHoverState()
    local palette = button._wmColors
    Base.applyColorTexture(bg, palette.bgHover or palette.bg)
    Base.setTextColor(labelFs, palette.textHover or palette.text)
  end

  button.applyThemeColors = function(nextColors)
    if type(nextColors) == "table" then
      if nextColors.bg ~= nil then
        button._wmColors.bg = nextColors.bg
      end
      if nextColors.bgHover ~= nil then
        button._wmColors.bgHover = nextColors.bgHover
      end
      if nextColors.text ~= nil then
        button._wmColors.text = nextColors.text
      end
      if nextColors.textHover ~= nil then
        button._wmColors.textHover = nextColors.textHover
      end
    end

    if button._wmHovered then
      applyHoverState()
    else
      applyBaseState()
    end
  end

  button:SetScript("OnEnter", function()
    button._wmHovered = true
    applyHoverState()
  end)

  button:SetScript("OnLeave", function()
    button._wmHovered = false
    applyBaseState()
  end)

  applyBaseState()
  button.bg = bg
  button.label = labelFs

  return button
end

function Controls.createToggleRow(factory, parent, label, initial, colors, layout, onChange, tooltip)
  local toggleWidth = layout.width or 280
  local toggleHeight = layout.height or 24
  local dotSize = 14

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(toggleWidth, toggleHeight)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
  labelFs:SetText(label)

  local dot = factory.CreateFrame("Button", nil, row)
  dot:SetSize(dotSize, dotSize)
  dot:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  local dotBorder = dot:CreateTexture(nil, "BORDER")
  dotBorder:SetAllPoints(dot)

  local dotBg = dot:CreateTexture(nil, "BACKGROUND")
  dotBg:SetPoint("TOPLEFT", dot, "TOPLEFT", 1, -1)
  dotBg:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", -1, 1)

  row._wmColors = {
    text = colors.text,
    on = colors.on or Theme.COLORS.option_toggle_on or Theme.COLORS.online or { 0.30, 0.82, 0.40, 1.0 },
    off = colors.off or Theme.COLORS.option_toggle_off or Theme.COLORS.offline or { 0.45, 0.45, 0.50, 1.0 },
    border = colors.border or Theme.COLORS.option_toggle_border or Theme.COLORS.divider or { 0.55, 0.57, 0.64, 0.90 },
  }

  local enabled = initial == true
  local function updateVisual()
    Base.setTextColor(labelFs, row._wmColors.text)
    if enabled then
      -- Use the active color on the border too so checked toggles read clearly at a glance.
      Base.applyColorTexture(dotBorder, row._wmColors.on)
      Base.applyColorTexture(dotBg, row._wmColors.on)
    else
      Base.applyColorTexture(dotBorder, row._wmColors.border)
      Base.applyColorTexture(dotBg, row._wmColors.off)
    end
  end
  updateVisual()

  dot:SetScript("OnClick", function()
    enabled = not enabled
    updateVisual()
    if onChange then
      onChange(enabled)
    end
  end)

  if tooltip and row.SetScript then
    local lines = type(tooltip) == "table" and tooltip or { tooltip }
    row:SetScript("OnEnter", function()
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(row, "ANCHOR_TOP")
        _G.GameTooltip:SetText(lines[1])
        for i = 2, #lines do
          if _G.GameTooltip.AddLine then
            pcall(_G.GameTooltip.AddLine, _G.GameTooltip, lines[i], 1, 1, 1)
          end
        end
        _G.GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function()
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end

  return {
    row = row,
    label = labelFs,
    dot = dot,
    dotBg = dotBg,
    dotBorder = dotBorder,
    getValue = function()
      return enabled
    end,
    setValue = function(val)
      enabled = val == true
      updateVisual()
    end,
    applyThemeColors = function(nextColors)
      if type(nextColors) == "table" then
        if nextColors.text ~= nil then
          row._wmColors.text = nextColors.text
        end
        if nextColors.on ~= nil then
          row._wmColors.on = nextColors.on
        end
        if nextColors.off ~= nil then
          row._wmColors.off = nextColors.off
        end
        if nextColors.border ~= nil then
          row._wmColors.border = nextColors.border
        end
      end
      updateVisual()
    end,
  }
end

ns.UIHelpersControls = Controls

return Controls
