local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local DropdownSkin = ns.MessengerWindowDropdownSkin or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSkin")
local NativeDropdown = ns.MessengerWindowNativeDropdown or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")
local DropdownSwap = ns.MessengerWindowDropdownSwap or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")
local DropdownOptionRow = ns.MessengerWindowDropdownOptionRow or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownOptionRow")

local DropdownSelector = {}

local DEFAULT_BUTTON_HEIGHT = 26
local DEFAULT_MENU_HEIGHT = 156

-- Every menu of WM's own built (either look), so the controller's B can
-- close an open one.
local menus = setmetatable({}, { __mode = "k" })
-- Open or close: the controller re-scans, so the D-pad reaches new options.
local onMenuToggled
local function menuToggled()
  if onMenuToggled then
    onMenuToggled()
  end
end

local function buildOwn(factory, parent, options)
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

  local menu, content, menuSkin = DropdownSkin.CreateMenu(factory, row, button, rowWidth, buttonHeight)
  menus[menu] = true
  local function onMenuShownOrHidden()
    DropdownSkin.SyncPanel(menu, menuSkin)
    menuToggled()
  end
  menu:SetScript("OnShow", onMenuShownOrHidden)
  menu:SetScript("OnHide", onMenuShownOrHidden)

  local optionButtons = {}
  local buttonPool = {}
  -- `requested` is the saved key, kept even while the list lacks it (a
  -- SharedMedia sound whose addon has not registered yet); `selected` is
  -- the option it resolves to now.
  local requested = initial
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

  local function paintClosedButton()
    DropdownSkin.Paint(skin, buttonLabel, buttonHovered)
  end

  local function repaintOptions()
    DropdownOptionRow.RepaintAll(optionButtons, palette, selected)
  end

  local function updateSelection(key)
    requested = key
    local option = NativeDropdown.ResolveOption(optionsList, key, fallbackKey)
    selected = option and option.key or fallbackKey
    buttonLabel:SetText(option and option.label or "")
    repaintOptions()
  end

  local function getSelected()
    return selected
  end

  local function pickOption(key)
    updateSelection(key)
    if onChange then
      onChange(key)
    end
    menu:Hide()
  end

  local function createOptionButton()
    local optionButton = DropdownOptionRow.Create(factory, content, palette, getSelected, pickOption, menuSkin.native)
    buttonPool[#buttonPool + 1] = optionButton
    return optionButton
  end

  -- Under the Native look the menu is menuSkin.inset narrower on each side
  -- (the tooltip panel's border around it), so the panel stays as wide as
  -- the button; the visible rows and scroll range match the modern look.
  local function layoutOptions()
    local listWidth = rowWidth - 2 * menuSkin.inset
    local contentHeight = #optionButtons * buttonHeight
    local popupHeight = math.min(menuHeight, math.max(buttonHeight, contentHeight))

    for i, optionButton in ipairs(optionButtons) do
      optionButton:ClearAllPoints()
      if i == 1 then
        optionButton:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
      else
        optionButton:SetPoint("TOPLEFT", optionButtons[i - 1], "BOTTOMLEFT", 0, 0)
      end
      optionButton:SetSize(listWidth, buttonHeight)
    end

    menu:SetSize(listWidth, popupHeight)
    content:SetSize(listWidth, math.max(contentHeight, popupHeight))
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
      optionButton._header = option.header == true
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
    updateSelection(requested)
  end

  -- Opens at the top unless the selected row sits below the first page;
  -- then the selected row leads the view (clamped at the bottom).
  local function scrollToSelected()
    local offset = 0
    for i, optionButton in ipairs(optionButtons) do
      if optionButton._key == selected and not optionButton._header then
        local rowTop = (i - 1) * buttonHeight
        if rowTop + buttonHeight > menu:GetHeight() then
          offset = math.min(rowTop, menu:GetVerticalScrollRange())
        end
        break
      end
    end
    menu:SetVerticalScroll(offset)
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
    scrollToSelected()
    DropdownSkin.RaiseMenu(menu, menuSkin)
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
      -- The menu is already invisible here, so WoW fires no OnHide for it:
      -- sync the native panel by hand.
      DropdownSkin.SyncPanel(menu, menuSkin)
    end)
  end

  setOptionsList(optionsList)
  paintClosedButton()
  DropdownSkin.PaintMenu(menuSkin, palette)

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
      DropdownSkin.PaintMenu(menuSkin, palette)
    end,
  },
    menu
end

function DropdownSelector.Create(factory, parent, options)
  options = options or {}
  if DropdownSwap.Applies() then
    return DropdownSwap.Create(factory, parent, options, buildOwn)
  end
  local native = NativeDropdown.Create(factory, parent, options)
  if native then
    return native
  end
  return (buildOwn(factory, parent, options))
end

-- Hides every open menu of WM's own (the game's dropdown menu closes
-- itself); true when one was open.
function DropdownSelector.HideShownMenu()
  local hidden = false
  for menu in pairs(menus) do
    if menu:IsShown() then
      menu:Hide()
      hidden = true
    end
  end
  return hidden
end

function DropdownSelector.SetMenuToggledHook(fn)
  onMenuToggled = fn
end

ns.MessengerWindowDropdownSelector = DropdownSelector
return DropdownSelector
