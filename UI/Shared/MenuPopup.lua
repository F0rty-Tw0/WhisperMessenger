local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

-- WM's own right-click popup. On WoW: Forever the game's menus taint when
-- addon code opens them, so the window draws this instead. Callers fill it
-- through a builder shaped like the game's root menu description
-- (CreateTitle / CreateButton / CreateCheckbox / CreateDivider). Handlers
-- run with no arguments; a click closes the popup.
local MenuPopup = {}

local MENU_NAME = "WhisperMessengerMenuPopup"
local STRATA = "FULLSCREEN_DIALOG"
local PAD = 4
local ROW_HEIGHT = PickerStyles.ROW_HEIGHT
local DIVIDER_HEIGHT = 10
local MIN_WIDTH = 120
local MAX_WIDTH = 260
local LABEL_PAD = 8
local CHECK_LABEL_PAD = PickerPopup.CHECK_LABEL_PAD
local RIGHT_PAD = 12
local CHECK_SIZE = PickerPopup.CHECK_SIZE
local CHECK_TEXTURE = PickerPopup.CHECK_TEXTURE
local DIVIDER_TEXTURE = "Interface\\Common\\UI-TooltipDivider-Transparent"
local NATIVE_TEXT_COLOR = { 1, 1, 1, 1 }

local frame
local rows = {}
local currentAnchor
-- The anchor a click may land on without closing the popup, if any.
local clickSafeAnchor
local hookedAnchors = setmetatable({}, { __mode = "k" })
local pools = { button = {}, checkbox = {}, divider = {}, title = {} }

local element = {}
element.__index = element

function element:SetEnabled(enabled)
  self.enabled = enabled ~= false
end

function element.CreateButton()
  error("MenuPopup: no submenus")
end

local function addRow(kind, text, fields)
  local row = setmetatable(fields or {}, element)
  row.kind, row.text, row.enabled = kind, text, true
  table.insert(rows, row)
  return row
end

local root = {}

function root.CreateButton(_self, text, onClick)
  return addRow("button", text, { onClick = onClick })
end

function root.CreateCheckbox(_self, text, isSelected, onSelect)
  return addRow("checkbox", text, { isSelected = isSelected, onClick = onSelect })
end

function root.CreateDivider()
  return addRow("divider", nil)
end

function root.CreateTitle(_self, text)
  return addRow("title", text)
end

local function textFont()
  return Hud.IsOn() and PickerPopup.MENU_FONT or Theme.FONTS.icon_label
end

local function enabledColor()
  if Hud.IsOn() then
    return NATIVE_TEXT_COLOR
  end
  return Theme.COLORS.option_button_text or Theme.COLORS.text_primary
end

local function onRowClick(button)
  local row = button._row
  if row == nil or not row.enabled then
    return
  end
  if type(row.onClick) == "function" then
    row.onClick()
  end
  MenuPopup.Close()
end

local function frameFactory()
  return { CreateFrame = _G.CreateFrame }
end

local function createButtonRegion(kind)
  local button, label = PickerPopup.CreateTextButton(frameFactory(), frame, "", onRowClick)
  local inset = kind == "checkbox" and CHECK_LABEL_PAD or LABEL_PAD
  label:ClearAllPoints()
  label:SetPoint("LEFT", button, "LEFT", inset, 0)
  button._label = label
  button._inset = inset
  if kind == "checkbox" then
    local check = button:CreateTexture(nil, "ARTWORK")
    check:SetTexture(CHECK_TEXTURE)
    check:SetSize(CHECK_SIZE, CHECK_SIZE)
    check:SetPoint("LEFT", button, "LEFT", PickerPopup.CHECK_INSET, 0)
    button._check = check
  end
  return button
end

local function createRegion(kind)
  if kind == "button" or kind == "checkbox" then
    return createButtonRegion(kind)
  end
  if kind == "divider" then
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(DIVIDER_TEXTURE)
    return divider
  end
  local title = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(title, textFont())
  return title
end

local function textRegion(row)
  if row.kind == "title" then
    return row.region, LABEL_PAD
  end
  return row.region._label, row.region._inset
end

local function assignRegions()
  local used = { button = 0, checkbox = 0, divider = 0, title = 0 }
  for _, row in ipairs(rows) do
    local index = used[row.kind] + 1
    used[row.kind] = index
    local pool = pools[row.kind]
    pool[index] = pool[index] or createRegion(row.kind)
    row.region = pool[index]
  end
  for kind, pool in pairs(pools) do
    for index = used[kind] + 1, #pool do
      pool[index]:Hide()
    end
  end
end

-- Sets texts and returns the panel's inner width.
local function fillTexts()
  local width = MIN_WIDTH
  for _, row in ipairs(rows) do
    if row.kind ~= "divider" then
      local text, inset = textRegion(row)
      text:SetWordWrap(false)
      text:SetWidth(0)
      text:SetText(row.text or "")
      width = math.max(width, text:GetStringWidth() + inset + RIGHT_PAD)
    end
  end
  return math.min(width, MAX_WIDTH)
end

local function fillButton(row)
  local button = row.region
  button._row = row
  if button.SetEnabled then
    button:SetEnabled(row.enabled)
  end
  local color = row.enabled and enabledColor() or Theme.COLORS.text_secondary
  UIHelpers.setTextColor(button._label, color)
  if button._check then
    row.checked = type(row.isSelected) == "function" and row.isSelected() == true
    button._check:SetShown(row.checked)
  end
end

local function layoutRows(width)
  local pad = PAD + PickerPopup.BorderInset(frame)
  local y = pad
  for _, row in ipairs(rows) do
    local region = row.region
    local height = row.kind == "divider" and DIVIDER_HEIGHT or ROW_HEIGHT
    -- A title is its own text: it starts at the label inset.
    local x = row.kind == "title" and pad + LABEL_PAD or pad
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    region:SetSize(width, height)
    if row.kind ~= "divider" then
      local text, inset = textRegion(row)
      text:SetWidth(width - inset - RIGHT_PAD)
    end
    if row.kind == "button" or row.kind == "checkbox" then
      fillButton(row)
    end
    region:Show()
    y = y + height
  end
  frame:SetSize(width + pad * 2, y + pad)
end

local function createFrame()
  local panel = PickerPopup.CreatePanel(frameFactory(), _G.UIParent, MENU_NAME, STRATA)
  panel:SetScript("OnEvent", function(self, event)
    PickerPopup.HandleEvent(self, event, MenuPopup.Close, clickSafeAnchor)
  end)
  panel:SetScript("OnHide", function(self)
    PickerPopup.Disarm(self)
    currentAnchor, clickSafeAnchor = nil, nil
  end)
  rawset(_G, MENU_NAME, panel)
  return panel
end

-- The window hides its children with it: the popup closes with its anchor.
local function hookAnchor(anchorFrame)
  if hookedAnchors[anchorFrame] or type(anchorFrame.HookScript) ~= "function" then
    return
  end
  hookedAnchors[anchorFrame] = true
  anchorFrame:HookScript("OnHide", function(self)
    if self == currentAnchor then
      MenuPopup.Close()
    end
  end)
end

local function place(anchorFrame, atCursor)
  frame:ClearAllPoints()
  local placedAtCursor = atCursor and PickerPopup.PlaceAtCursor(frame)
  if not placedAtCursor then
    frame:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 0, 0)
  end
end

-- Calls build(root) and shows the rows beside `anchorFrame`. Returns false,
-- with nothing shown, when there is nothing to show. options (optional):
-- { atCursor = true } opens it at the cursor instead (beside the anchor
-- when the cursor is unknown), for an anchor much larger than the click
-- such as a chat transcript; a click on that anchor then closes it too.
-- Either way the popup hides with its anchor.
function MenuPopup.Open(anchorFrame, build, options)
  MenuPopup.Close()
  local canOpen = anchorFrame ~= nil and type(build) == "function" and type(_G.CreateFrame) == "function" and _G.UIParent ~= nil
  if not canOpen then
    return false
  end
  local atCursor = type(options) == "table" and options.atCursor == true
  rows = {}
  build(root)
  if #rows == 0 then
    return false
  end
  frame = frame or createFrame()
  PickerStyles.ApplyPanelTheme(frame, frame._border)
  assignRegions()
  layoutRows(fillTexts())
  place(anchorFrame, atCursor)
  PickerPopup.RegisterEscape(MENU_NAME, frame)
  hookAnchor(anchorFrame)
  currentAnchor = anchorFrame
  clickSafeAnchor = not atCursor and anchorFrame or nil
  PickerPopup.ArmDismiss(frame)
  frame:Show()
  return true
end

function MenuPopup.Close()
  if frame and frame:IsShown() then
    frame:Hide()
  end
end

function MenuPopup.IsShown()
  return frame ~= nil and frame:IsShown()
end

function MenuPopup.GetFrame()
  return frame
end

-- The current fill in display order: { kind, text, region, enabled, checked }.
-- Rows() and row.checked exist for the tests to read the popup.
function MenuPopup.Rows()
  return rows
end

ns.MenuPopup = MenuPopup
return MenuPopup
