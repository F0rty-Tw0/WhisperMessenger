local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeControls = ns.UIHelpersNativeControls or require("WhisperMessenger.UI.Helpers.NativeControls")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

-- Native WoW HUD dropdown row. Prefers the game's dropdown
-- (WowStyle1DropdownTemplate set up with SetupMenu); without it, a panel
-- button showing the current value opens MenuUtil's context menu. Each
-- option is a radio either way. Create returns nil when the HUD is off or
-- the client has neither API; the caller then builds the modern dropdown.
-- Same handle contract as DropdownSelector.
local NativeDropdown = {}

NativeDropdown.DROPDOWN_TEMPLATE = "WowStyle1DropdownTemplate"

local DEFAULT_ROW_WIDTH = 280
local DEFAULT_LABEL_SPACING = 6
local DEFAULT_BUTTON_HEIGHT = 26
local DEFAULT_MENU_HEIGHT = 156
local LABEL_BLOCK_HEIGHT = 20

local function createDropdown(factory, row)
  local dropdown = UIHelpers.createTemplatedFrame(factory, "DropdownButton", nil, row, NativeDropdown.DROPDOWN_TEMPLATE)
  if not dropdown then
    return nil
  end
  if type(dropdown.SetupMenu) == "function" and type(dropdown.GenerateMenu) == "function" then
    return dropdown
  end
  dropdown:Hide()
  return nil
end

local function menuUtil()
  local util = _G.MenuUtil
  if type(util) == "table" and type(util.CreateContextMenu) == "function" then
    return util
  end
  return nil
end

-- Panel button with its own value label: the button swaps its own text's
-- font object on hover, which would wipe the preset colour.
local function createMenuButton(factory, row)
  if not menuUtil() then
    return nil
  end
  local button = UIHelpers.createTemplatedFrame(factory, "Button", nil, row, NativeControls.BUTTON_TEMPLATE)
  if not button then
    return nil
  end
  local label = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  label:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.label = label
  return button
end

function NativeDropdown.Create(factory, parent, options)
  if not Hud.IsOn() then
    return nil
  end
  options = options or {}

  local row = factory.CreateFrame("Frame", nil, parent)
  local dropdown = createDropdown(factory, row)
  local control = dropdown or createMenuButton(factory, row)
  if not control then
    row:Hide()
    return nil
  end
  local isDropdown = control == dropdown

  local optionsList = type(options.optionsList) == "table" and options.optionsList or {}
  local getOptions = options.getOptions
  local fallbackKey = options.fallbackKey
  local onChange = options.onChange
  local rowWidth = options.rowWidth or DEFAULT_ROW_WIDTH
  local buttonHeight = options.buttonHeight or DEFAULT_BUTTON_HEIGHT
  local menuHeight = options.menuHeight or DEFAULT_MENU_HEIGHT
  local rowHeight = buttonHeight + LABEL_BLOCK_HEIGHT
  -- WowStyle1DropdownTemplate's value text; the child key is not guaranteed.
  local valueText = control.label
  if isDropdown then
    valueText = type(control.Text) == "table" and control.Text or nil
  end
  local selected = nil

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(options.labelText)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)
  control:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -(options.labelSpacing or DEFAULT_LABEL_SPACING))

  local function size()
    row:SetSize(rowWidth, rowHeight)
    if isDropdown then
      control:SetWidth(rowWidth)
    else
      control:SetSize(rowWidth, buttonHeight)
    end
  end

  local function paintValue(colors)
    if valueText then
      UIHelpers.setTextColor(valueText, colors.text_primary)
    end
  end

  local function resolve(key)
    local fallback = nil
    for _, option in ipairs(optionsList) do
      if option.key == key then
        return option
      end
      if option.key == fallbackKey then
        fallback = option
      end
    end
    return fallback or optionsList[1]
  end

  -- The game's dropdown redraws its value after a radio click on its own;
  -- refresh=true redraws it for programmatic changes.
  local function select(key, refresh)
    local option = resolve(key)
    selected = option and option.key or fallbackKey
    if not isDropdown then
      control.label:SetText(option and option.label or "")
    elseif refresh then
      control:GenerateMenu()
    end
    paintValue(Theme.COLORS)
  end

  local function isSelected(key)
    return key == selected
  end

  local function choose(key)
    select(key, false)
    if onChange then
      onChange(key)
    end
  end

  local function generator(_owner, rootDescription)
    if type(getOptions) == "function" then
      local refreshed = getOptions()
      if type(refreshed) == "table" then
        optionsList = refreshed
      end
    end
    if type(rootDescription.SetScrollMode) == "function" then
      rootDescription:SetScrollMode(menuHeight)
    end
    for _, option in ipairs(optionsList) do
      rootDescription:CreateRadio(option.label, isSelected, choose, option.key)
    end
  end

  size()
  select(options.initial, false)
  if isDropdown then
    control:SetupMenu(generator)
  else
    control:SetScript("OnClick", function()
      local util = menuUtil()
      if util then
        util.CreateContextMenu(control, generator)
      end
    end)
  end

  return {
    row = row,
    label = labelFs,
    button = control,
    setSelected = function(key)
      select(key, true)
    end,
    setOptionsList = function(nextOptions)
      if type(nextOptions) ~= "table" then
        return
      end
      optionsList = nextOptions
      select(selected, true)
    end,
    setWidth = function(nextWidth)
      if type(nextWidth) ~= "number" or nextWidth <= 0 then
        return
      end
      rowWidth = nextWidth
      size()
    end,
    applyTheme = function(activeTheme)
      if type(activeTheme) ~= "table" or type(activeTheme.COLORS) ~= "table" then
        return
      end
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      paintValue(activeTheme.COLORS)
    end,
  }
end

ns.MessengerWindowNativeDropdown = NativeDropdown
return NativeDropdown
