local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Composer = require("WhisperMessenger.UI.Composer")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local ModernChrome = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ModernChrome")
local PickerStyles = require("WhisperMessenger.UI.Shared.PickerStyles")
local Base = require("WhisperMessenger.UI.Helpers.Base")

local function shownSides(border)
  local sides = {}
  for side, edge in pairs(border) do
    if edge.shown == true then
      sides[#sides + 1] = side
    end
  end
  table.sort(sides)
  return table.concat(sides, ",")
end

local function build(factory)
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)
  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)
  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})

  local composerParent = factory.CreateFrame("Frame", nil, uiParent)
  composerParent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local composer = Composer.Create(factory, composerParent, { conversationKey = "wow::test" }, function() end)

  local headerFrame = factory.CreateFrame("Frame", nil, uiParent)
  local headerDivider = HeaderElements.createDivider(headerFrame)

  local chromeFrame = factory.CreateFrame("Frame", nil, uiParent)
  local chrome = ModernChrome.Build(factory, chromeFrame, {}, Theme)
  -- ChromeBuilder.Build always applies the paint right after building.
  chrome.applyChromePaint(Theme)

  return {
    layout = layout,
    composer = composer,
    headerBorder = headerDivider._headerBorder,
    headerDivider = headerDivider,
    chrome = chrome,
  }
end

local function assertModern(ui, label)
  -- No boxes: the contacts pane, composer container, title bar and search
  -- field carry no outline parts at all.
  assert(ui.layout.contactsPaneBorder == nil, label .. ": contacts pane must not be outlined")
  assert(ui.layout.composerPaneBorder == nil, label .. ": composer container must not be boxed")
  assert(ui.chrome.titleBarBorder == nil, label .. ": title bar has no inner box")
  assert(ui.layout.contactsSearchBorder == nil, label .. ": search field has no outline")
  assert(ui.layout.contactsDivider.shown ~= false, label .. ": one sidebar hairline stays")
  assert(shownSides(ui.composer.border) == "top", label .. ": composer keeps only its top hairline, got " .. shownSides(ui.composer.border))
  assert(ui.composer.inputBg == nil, label .. ": no square input fill")
  assert(FindUI.ofType(ui.composer.input, "Texture")[1] ~= nil, label .. ": input uses a soft rounded fill")
  assert(shownSides(ui.headerBorder) == "bottom", label .. ": header keeps only a bottom hairline, got " .. shownSides(ui.headerBorder))
  -- One subtle gloss sheen per bar (title bar, conversation header, composer).
  -- Title bar regions in creation order: background, sheen, title.
  local _, titleSheen = ui.chrome.titleBar:GetRegions()
  assert(titleSheen.shown == true, label .. ": title bar sheen")
  assert(ui.headerDivider._headerSheen.shown == true, label .. ": header sheen")
  assert(ui.composer.sheen.shown == true, label .. ": composer sheen")
  -- White-plus-alpha hairlines must keep their own alpha (never forced opaque).
  assert(ui.headerBorder.bottom.color[4] == Theme.COLORS.divider[4], label .. ": header hairline keeps divider alpha")
  assert(PickerStyles.BorderColor()[4] == Theme.COLORS.contacts_border_right[4], label .. ": picker border keeps token alpha")
  local hover = Theme.COLORS.bg_contact_hover
  assert(Base.hoverButtonFill(hover, false)[4] == hover[4], label .. ": small-button fill uses the token alpha")
  assert(Base.hoverButtonFill(hover, true)[4] == hover[4] * 2, label .. ": small-button hover doubles it")
  local pickerHover = Theme.COLORS.option_button_hover
  assert(PickerStyles.HighlightColor(0.35)[4] == pickerHover[4] * 2, label .. ": picker highlight never forced to a fixed (white-box) alpha")
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    assertModern(build(factory), key)
  end

  -- Runtime switch Azeroth -> another preset keeps the same surfaces.
  Theme.SetPreset("wow_native")
  local ui = build(factory)
  Theme.SetPreset("plumber_warm")
  ui.layout.applyTheme(Theme)
  ui.composer.refreshTheme()
  HeaderElements.applyDividerTheme(ui.headerDivider)
  ui.chrome.applyChromePaint(Theme)
  assertModern(ui, "runtime plumber_warm")

  Theme.SetPreset(previousPreset)
  print("PASS: test_modern_surfaces")
end
