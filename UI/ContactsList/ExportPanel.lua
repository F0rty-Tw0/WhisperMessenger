local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local DisabledState = ns.UIHelpersDisabledState or require("WhisperMessenger.UI.Helpers.DisabledState")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local DialogChrome = ns.DialogChrome or require("WhisperMessenger.UI.Shared.DialogChrome")

local format = string.format
local concat = table.concat
local min = math.min

-- A conversation as copyable text in a fixed-size panel: the newest
-- PAGE_SIZE lines first, "Show more" adds the page before them, "Show all"
-- the rest. The text is selected after each load for Ctrl+C (addons can't
-- write the clipboard). Escape or the close button hides it.
local ExportPanel = {}

ExportPanel.FRAME_NAME = "WhisperMessengerExportPanel"
ExportPanel.PAGE_SIZE = 200

local WIDTH = 560
local HEIGHT = 400
local PADDING = 18
local TITLE_HEIGHT = 20
local CLOSE_SIZE = 20
local ROW_GAP = 10
local BUTTON_WIDTH = 110
local BUTTON_GAP = 8
local STATUS_HEIGHT = 14
local WELL_RADIUS = 6
local TEXT_INSET = 8
local SCROLL_STEP = 40

-- One panel per frame factory, reused on every Show.
local panels = setmetatable({}, { __mode = "k" })

local function setButtonEnabled(button, enabled)
  button:SetEnabled(enabled)
  button:SetAlpha(enabled and 1 or DisabledState.ALPHA)
end

-- The header, then the newest `loaded` lines, oldest of them first.
local function loadedText(panel)
  if panel.loaded == 0 then
    return panel.header
  end
  local total = #panel.lines
  return panel.header .. "\n" .. concat(panel.lines, "\n", total - panel.loaded + 1, total)
end

-- toTop: show the newly added older lines; otherwise the newest stay in view.
local function load(panel, toTop)
  local total = #panel.lines
  panel.text = loadedText(panel)
  local box = panel.editBox
  box:SetText(panel.text)
  box:SetFocus()
  box:HighlightText()
  panel.status:SetText(format(Localization.Text("%d of %d lines · Ctrl+C copies"), panel.loaded, total))
  local more = panel.loaded < total
  setButtonEnabled(panel.showMoreButton, more)
  setButtonEnabled(panel.showAllButton, more)
  panel.snapToEnd = not toTop
  ScrollView.RefreshMetrics(panel.view, box:GetHeight(), panel.snapToEnd)
  if toTop then
    ScrollView.SetVerticalScroll(panel.view, 0)
  end
end

local function showUpTo(panel, count)
  local total = #panel.lines
  if panel.loaded >= total then
    return
  end
  panel.loaded = min(total, count)
  load(panel, true)
end

local function createText(parent, font, justify)
  local label = parent:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH(justify)
  return label
end

local function createButton(factory, body, key, onClick)
  local button = DialogChrome.CreateButton(factory, body, BUTTON_WIDTH)
  button.label:SetText(Localization.Text(key))
  button:SetScript("OnClick", onClick)
  return button
end

-- The text well: a themed input background (modern look only) holding the
-- scroll view, whose content is the edit box.
local function createWell(factory, panel, body, top)
  local well = factory.CreateFrame("Frame", nil, body)
  local wellHeight = HEIGHT - top - PADDING - STATUS_HEIGHT - ROW_GAP
  well:SetSize(WIDTH - PADDING * 2, wellHeight)
  well:SetPoint("TOPLEFT", body, "TOPLEFT", PADDING, -top)
  if not DialogChrome.IsNative() then
    panel.wellBackground = UIHelpers.createRoundedBackground(well, WELL_RADIUS)
  end

  local view = ScrollView.Create(factory, well, {
    width = WIDTH - PADDING * 2 - TEXT_INSET * 2,
    height = wellHeight - TEXT_INSET * 2,
    point = { "TOPLEFT", well, "TOPLEFT", TEXT_INSET, -TEXT_INSET },
    step = SCROLL_STEP,
  })
  panel.view = view

  local box = factory.CreateFrame("EditBox", nil, view.content)
  box:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", view.content, "TOPRIGHT", 0, 0)
  box:SetMultiLine(true)
  box:SetMaxLetters(0)
  box:SetMaxBytes(0)
  box:SetAutoFocus(false)
  UIHelpers.setFontObject(box, Theme.FONTS.composer_input)
  panel.editBox = box
  return well
end

local function wireScripts(panel)
  local box = panel.editBox
  local function close()
    panel:Hide()
  end
  box:SetScript("OnEscapePressed", close)
  -- Read-only: whatever the player types is put back.
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput and panel.text ~= nil and self:GetText() ~= panel.text then
      self:SetText(panel.text)
      self:HighlightText()
    end
  end)
  -- A multi-line edit box grows to fit its text once laid out.
  box:SetScript("OnSizeChanged", function(_, _, height)
    ScrollView.RefreshMetrics(panel.view, height, panel.snapToEnd)
  end)
  panel.view.scrollFrame:SetScript("OnMouseDown", function()
    box:SetFocus()
  end)
  panel.closeButton:SetScript("OnClick", close)
  panel:SetScript("OnHide", function()
    box:ClearFocus()
  end)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
end

local function build(factory)
  local panel = factory.CreateFrame("Frame", ExportPanel.FRAME_NAME, _G.UIParent)
  panel:SetSize(WIDTH, HEIGHT)
  panel:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
  panel:SetFrameStrata("DIALOG")
  if panel.SetToplevel then
    panel:SetToplevel(true)
  end
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel.paintBackground = DialogChrome.CreateBackground(factory, panel)

  local body = factory.CreateFrame("Frame", nil, panel)
  body:SetAllPoints(panel)
  body:SetFrameLevel(panel:GetFrameLevel() + 2)

  panel.title = createText(body, Theme.FONTS.icon_label, "LEFT")
  panel.title:SetPoint("TOPLEFT", body, "TOPLEFT", PADDING, -PADDING)
  panel.title:SetPoint("RIGHT", body, "RIGHT", -(PADDING + CLOSE_SIZE + BUTTON_GAP), 0)
  panel.closeButton = DialogChrome.CreateCloseButton(factory, body, CLOSE_SIZE)
  panel.closeButton:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PADDING + 4, -PADDING + 4)

  local buttonsTop = PADDING + TITLE_HEIGHT + ROW_GAP
  panel.showMoreButton = createButton(factory, body, "Show more", function()
    showUpTo(panel, panel.loaded + ExportPanel.PAGE_SIZE)
  end)
  panel.showMoreButton:SetPoint("TOPLEFT", body, "TOPLEFT", PADDING, -buttonsTop)
  panel.showAllButton = createButton(factory, body, "Show all", function()
    showUpTo(panel, #panel.lines)
  end)
  panel.showAllButton:SetPoint("LEFT", panel.showMoreButton, "RIGHT", BUTTON_GAP, 0)

  createWell(factory, panel, body, buttonsTop + Theme.LAYOUT.OPTION_BUTTON_HEIGHT + ROW_GAP)
  panel.status = createText(body, Theme.FONTS.contact_preview, "LEFT")
  panel.status:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", PADDING, PADDING)

  wireScripts(panel)
  PickerPopup.RegisterEscape(ExportPanel.FRAME_NAME, panel)
  panel:Hide()
  return panel
end

-- Theme colours are read on every Show, so a theme change since the last
-- one is picked up.
local function paint(panel)
  if panel.paintBackground then
    panel.paintBackground()
  end
  if panel.wellBackground and panel.wellBackground.setColor then
    panel.wellBackground.setColor(Theme.COLORS.bg_input)
  end
  local titleColor, textColor, hintColor = DialogChrome.TextColors()
  UIHelpers.setTextColor(panel.title, titleColor)
  UIHelpers.setTextColor(panel.editBox, textColor)
  UIHelpers.setTextColor(panel.status, hintColor)
  if panel.view.refreshSkin then
    panel.view.refreshSkin()
  end
end

-- spec: title (the contact's name), header (first line of the text) and
-- lines (one entry per message, oldest first). factory defaults to the
-- game's CreateFrame. Returns the panel.
function ExportPanel.Show(spec, factory)
  factory = factory or _G
  local panel = panels[factory]
  if panel == nil then
    panel = build(factory)
    panels[factory] = panel
  end
  panel.title:SetText(format(Localization.Text("Export: %s"), tostring(spec.title or "")))
  panel.header = spec.header or ""
  panel.lines = spec.lines or {}
  panel.loaded = min(#panel.lines, ExportPanel.PAGE_SIZE)
  paint(panel)
  panel:Show()
  if panel.Raise then
    panel:Raise()
  end
  load(panel, false)
  return panel
end

ns.ContactsListExportPanel = ExportPanel
return ExportPanel
