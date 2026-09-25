local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local CloseGlyphButton = ns.CloseGlyphButton or require("WhisperMessenger.UI.Shared.CloseGlyphButton")

local ContactsSearchUI = {}

-- Softly filled rounded field with a small magnifier glyph and
-- no outline. SearchBoxTemplate's own icon texture, shipped with every flavor.
local SEARCH_ICON_TEXTURE = "Interface\\Common\\UI-Searchbox-Icon"
local SEARCH_ICON_SIZE = 12
local FIELD_RADIUS = 8
-- Field inset 4 + icon inset 4 = 8px from the pane: the row icons' left edge.
local SEARCH_ICON_INSET = 4
local INPUT_LEFT_INSET_WITH_ICON = SEARCH_ICON_INSET + SEARCH_ICON_SIZE + 6

local function setRoundedShown(rounded, shown)
  for _, part in ipairs(rounded.fills) do
    part:SetShown(shown)
  end
  for _, part in ipairs(rounded.corners) do
    part:SetShown(shown)
  end
end

-- SearchBoxTemplate's left/right art overhangs the EditBox; inset it so the
-- art lines up with the pane like the Communities search box.
local NATIVE_SEARCH_LEFT_INSET = 6
local NATIVE_SEARCH_HEIGHT = 20

-- Native WoW HUD variant: Blizzard SearchBoxTemplate (own magnifier, clear
-- button and Instructions text). Child keys are optional on some clients, so
-- missing ones fall back to an own placeholder / no clear button. Returns nil
-- when the template is unavailable so the caller builds the modern field.
local function buildNative(factory, contactsSearchFrame, theme, uiHelpers)
  local input = UIHelpers.createTemplatedFrame(factory, "EditBox", nil, contactsSearchFrame, "SearchBoxTemplate")
  if input == nil then
    return nil
  end
  input:SetPoint("LEFT", contactsSearchFrame, "LEFT", NATIVE_SEARCH_LEFT_INSET, 0)
  input:SetPoint("RIGHT", contactsSearchFrame, "RIGHT", 0, 0)
  input:SetHeight(NATIVE_SEARCH_HEIGHT)
  if input.SetAutoFocus then
    input:SetAutoFocus(false)
  end

  local placeholder = input.Instructions
  if placeholder == nil then
    placeholder = input:CreateFontString(nil, "ARTWORK", theme.FONTS.contact_preview)
    placeholder:SetPoint("LEFT", input, "LEFT", 16, 0)
    uiHelpers.setTextColor(placeholder, theme.COLORS.text_secondary)
  end
  placeholder:SetText(Localization.Text("Search chats"))

  return {
    frame = contactsSearchFrame,
    input = input,
    placeholder = placeholder,
    clearButton = input.clearButton,
    native = true,
    -- Blizzard art: theme presets never repaint it.
    applySkin = function(_activeTheme) end,
    setLanguage = function()
      placeholder:SetText(Localization.Text("Search chats"))
    end,
  }
end

function ContactsSearchUI.Build(factory, contactsPane, options)
  options = options or {}

  local contactsWidth = options.contactsWidth
  local searchMargin = options.searchMargin
  local searchHeight = options.searchHeight
  local searchClearButtonSize = options.searchClearButtonSize
  local theme = options.theme or Theme
  local uiHelpers = options.uiHelpers or UIHelpers

  local contactsSearchFrame = factory.CreateFrame("Frame", nil, contactsPane)
  local insetX = theme.LAYOUT.CONTACT_SEARCH_INSET_X or searchMargin
  contactsSearchFrame:SetSize(math.max(0, contactsWidth - (insetX * 2)), searchHeight)
  contactsSearchFrame:SetPoint("TOPLEFT", contactsPane, "TOPLEFT", insetX, -searchMargin)

  if options.nativeChrome then
    local native = buildNative(factory, contactsSearchFrame, theme, uiHelpers)
    if native then
      return native
    end
  end

  local contactsSearchInput = factory.CreateFrame("EditBox", nil, contactsSearchFrame)
  contactsSearchInput:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", INPUT_LEFT_INSET_WITH_ICON, -4)
  contactsSearchInput:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", -(searchClearButtonSize + 8), 4)
  contactsSearchInput:SetText("")
  uiHelpers.setFontObject(contactsSearchInput, theme.FONTS.composer_input)
  if contactsSearchInput.SetTextInsets then
    contactsSearchInput:SetTextInsets(0, 0, 0, 0)
  end
  if contactsSearchInput.SetAutoFocus then
    contactsSearchInput:SetAutoFocus(false)
  end
  if contactsSearchInput.SetTextColor then
    contactsSearchInput:SetTextColor(
      theme.COLORS.text_primary[1],
      theme.COLORS.text_primary[2],
      theme.COLORS.text_primary[3],
      theme.COLORS.text_primary[4] or 1
    )
  end

  local contactsSearchPlaceholder = contactsSearchFrame:CreateFontString(nil, "OVERLAY", theme.FONTS.contact_preview)
  contactsSearchPlaceholder:SetPoint("LEFT", contactsSearchInput, "LEFT", 0, 0)
  contactsSearchPlaceholder:SetText(Localization.Text("Search chats"))
  uiHelpers.setTextColor(contactsSearchPlaceholder, theme.COLORS.text_secondary)

  local roundedBg = UIHelpers.createRoundedBackground(contactsSearchFrame, FIELD_RADIUS)
  local searchIcon = contactsSearchFrame:CreateTexture(nil, "ARTWORK")
  searchIcon:SetSize(SEARCH_ICON_SIZE, SEARCH_ICON_SIZE)
  searchIcon:SetPoint("LEFT", contactsSearchFrame, "LEFT", SEARCH_ICON_INSET, 0)
  searchIcon:SetTexture(SEARCH_ICON_TEXTURE)

  setRoundedShown(roundedBg, true)
  searchIcon:Show()

  -- Repaint for the active theme (called on build and every theme refresh).
  local function applySkin(activeTheme)
    roundedBg.setColor(activeTheme.COLORS.bg_search_input or activeTheme.COLORS.bg_input)
    UIHelpers.applyVertexColor(searchIcon, activeTheme.COLORS.text_secondary)
  end

  local contactsSearchClearButton = CloseGlyphButton.Create(factory, contactsSearchFrame, searchClearButtonSize, theme)
  contactsSearchClearButton:SetPoint("RIGHT", contactsSearchFrame, "RIGHT", -2, 0)
  local contactsSearchClearLabel = contactsSearchClearButton.label

  contactsSearchPlaceholder:Show()
  contactsSearchClearButton:Hide()

  local function setLanguage()
    contactsSearchPlaceholder:SetText(Localization.Text("Search chats"))
  end

  return {
    frame = contactsSearchFrame,
    input = contactsSearchInput,
    placeholder = contactsSearchPlaceholder,
    clearButton = contactsSearchClearButton,
    clearLabel = contactsSearchClearLabel,
    roundedBg = roundedBg,
    icon = searchIcon,
    applySkin = applySkin,
    setLanguage = setLanguage,
  }
end

ns.MessengerWindowLayoutContactsSearchUI = ContactsSearchUI

return ContactsSearchUI
