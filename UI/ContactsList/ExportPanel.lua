local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local DialogChrome = ns.DialogChrome or require("WhisperMessenger.UI.Shared.DialogChrome")

local format = string.format
local concat = table.concat

-- A whole conversation as copyable text in a fixed-size panel, newest lines
-- in view. The store caps a conversation's lines, so all of them load at
-- once. The text is selected for Ctrl+C (addons can't write the clipboard).
-- Escape or the close button hides it.
local ExportPanel = {}

ExportPanel.FRAME_NAME = "WhisperMessengerExportPanel"

local WIDTH = 560
local HEIGHT = 400
local PADDING = 18
local TITLE_HEIGHT = 20
local CLOSE_SIZE = 20
local ROW_GAP = 10
local BUTTON_GAP = 8
local STATUS_HEIGHT = 14
local WELL_RADIUS = 6
local TEXT_INSET = 8
local SCROLL_STEP = 40
-- WoW: Forever draws no letters in an edit box inside the addon's own scroll
-- view; Blizzard's input scroll box draws them, with its own scroll bar.
local INPUT_SCROLL_TEMPLATE = "InputScrollFrameTemplate"
local TEMPLATE_BAR_WIDTH = 18
-- Font for the fallback box, on clients without that template.
local EXPORT_FONT = "ChatFontNormal"

-- One panel per frame factory, reused on every Show.
local panels = setmetatable({}, { __mode = "k" })

-- The header, then every line, oldest first.
local function loadedText(panel)
  if #panel.lines == 0 then
    return panel.header
  end
  return panel.header .. "\n" .. concat(panel.lines, "\n")
end

-- The newest lines stay in view.
local function load(panel)
  panel.text = loadedText(panel)
  local box = panel.editBox
  box:SetText(panel.text)
  box:SetFocus()
  box:HighlightText()
  panel.status:SetText(format(Localization.Text("%d lines · Ctrl+C copies"), #panel.lines))
  panel.snapToEnd = true
  if panel.view then
    ScrollView.RefreshMetrics(panel.view, box:GetHeight(), panel.snapToEnd)
  end
end

local function createText(parent, font, justify)
  local label = parent:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH(justify)
  return label
end

local function hideTextures(frame)
  for _, region in ipairs({ frame:GetRegions() }) do
    if region:GetObjectType() == "Texture" then
      region:Hide()
    end
  end
end

-- Modern look: the themed well replaces Blizzard's border, and the scroll
-- bar (Back/Forward arrows, a Track holding the Thumb knob, as on WoW:
-- Forever) keeps only a slim knob. Returns the knob's fill for painting;
-- a bar of any other shape keeps Blizzard's art.
local function slimTemplateArt(scroll)
  hideTextures(scroll)
  local bar = scroll.ScrollBar
  local thumb = bar and bar.Track and bar.Track.Thumb
  if thumb == nil then
    return nil
  end
  for _, arrow in ipairs({ bar.Back, bar.Forward }) do
    arrow:Hide()
  end
  hideTextures(bar)
  hideTextures(bar.Track)
  hideTextures(thumb)
  local fill = thumb:CreateTexture(nil, "OVERLAY")
  fill:SetPoint("TOP", thumb, "TOP", 0, 0)
  fill:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
  fill:SetWidth(Theme.LAYOUT.SCROLLBAR_WIDTH)
  fill:Show()
  return fill
end

-- Blizzard's input scroll box, nil on a client without the template.
local function createTemplateBox(factory, panel, well, width, height)
  local scroll = UIHelpers.createTemplatedFrame(factory, "ScrollFrame", nil, well, INPUT_SCROLL_TEMPLATE)
  if scroll == nil or scroll.EditBox == nil then
    return nil
  end
  scroll:SetPoint("TOPLEFT", well, "TOPLEFT", TEXT_INSET, -TEXT_INSET)
  scroll:SetSize(width, height)
  scroll:Show()
  if scroll.CharCount then
    scroll.CharCount:Hide()
  end
  if not DialogChrome.IsNative() then
    panel.templateThumb = slimTemplateArt(scroll)
  end
  local box = scroll.EditBox
  box:SetWidth(width - TEMPLATE_BAR_WIDTH)
  return box
end

-- The addon's scroll view with an edit box as its content.
local function createViewBox(factory, panel, well, width, height)
  local view = ScrollView.Create(factory, well, {
    width = width,
    height = height,
    point = { "TOPLEFT", well, "TOPLEFT", TEXT_INSET, -TEXT_INSET },
    step = SCROLL_STEP,
  })
  panel.view = view

  local box = factory.CreateFrame("EditBox", nil, view.content)
  box:SetPoint("TOPLEFT", view.content, "TOPLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", view.content, "TOPRIGHT", 0, 0)
  UIHelpers.setFontObject(box, _G[EXPORT_FONT] and EXPORT_FONT or Theme.FONTS.composer_input)
  return box
end

-- The text well: a themed input background (modern look only) holding the
-- scrolling edit box.
local function createWell(factory, panel, body, top)
  local well = factory.CreateFrame("Frame", nil, body)
  local wellHeight = HEIGHT - top - PADDING - STATUS_HEIGHT - ROW_GAP
  well:SetSize(WIDTH - PADDING * 2, wellHeight)
  well:SetPoint("TOPLEFT", body, "TOPLEFT", PADDING, -top)
  if not DialogChrome.IsNative() then
    panel.wellBackground = UIHelpers.createRoundedBackground(well, WELL_RADIUS)
  end

  local width = WIDTH - PADDING * 2 - TEXT_INSET * 2
  local height = wellHeight - TEXT_INSET * 2
  local box = createTemplateBox(factory, panel, well, width, height) or createViewBox(factory, panel, well, width, height)
  box:SetMultiLine(true)
  box:SetMaxLetters(0)
  box:SetMaxBytes(0)
  box:SetAutoFocus(false)
  panel.editBox = box
  return well
end

local function wireScripts(panel)
  local box = panel.editBox
  local function close()
    panel:Hide()
  end
  box:SetScript("OnEscapePressed", close)
  -- Read-only: whatever the player types is put back. Hooked, so Blizzard's
  -- box keeps its own handler.
  local function undoTyping(self, userInput)
    if userInput and panel.text ~= nil and self:GetText() ~= panel.text then
      self:SetText(panel.text)
      self:HighlightText()
    end
  end
  if box:GetScript("OnTextChanged") then
    box:HookScript("OnTextChanged", undoTyping)
  else
    box:SetScript("OnTextChanged", undoTyping)
  end
  if panel.view then
    -- A multi-line edit box grows to fit its text once laid out.
    box:SetScript("OnSizeChanged", function(_, _, height)
      ScrollView.RefreshMetrics(panel.view, height, panel.snapToEnd)
    end)
    panel.view.scrollFrame:SetScript("OnMouseDown", function()
      box:SetFocus()
    end)
  end
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

  createWell(factory, panel, body, PADDING + TITLE_HEIGHT + ROW_GAP)
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
  if panel.templateThumb then
    UIHelpers.applyColorTexture(panel.templateThumb, Theme.COLORS.scrollbar)
  end
  if panel.view and panel.view.refreshSkin then
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
  paint(panel)
  panel:Show()
  if panel.Raise then
    panel:Raise()
  end
  load(panel)
  return panel
end

ns.ContactsListExportPanel = ExportPanel
return ExportPanel
