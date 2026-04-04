local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local ContactsSearchUI = {}

function ContactsSearchUI.Build(factory, contactsPane, options)
  options = options or {}

  local contactsWidth = options.contactsWidth
  local searchMargin = options.searchMargin
  local searchHeight = options.searchHeight
  local searchClearButtonSize = options.searchClearButtonSize
  local dividerColor = options.dividerColor
  local theme = options.theme or Theme
  local uiHelpers = options.uiHelpers or UIHelpers
  local applyTexture = options.applyColorTexture or applyColorTexture

  local contactsSearchFrame = factory.CreateFrame("Frame", nil, contactsPane)
  contactsSearchFrame:SetSize(math.max(0, contactsWidth - (searchMargin * 2)), searchHeight)
  contactsSearchFrame:SetPoint("TOPLEFT", contactsPane, "TOPLEFT", searchMargin, -searchMargin)

  local contactsSearchBg = contactsSearchFrame:CreateTexture(nil, "BACKGROUND")
  contactsSearchBg:SetAllPoints(contactsSearchFrame)
  applyTexture(contactsSearchBg, theme.COLORS.bg_search_input or theme.COLORS.bg_input)

  local searchBorderColor = { dividerColor[1], dividerColor[2], dividerColor[3], 0.95 }
  local searchBorderTop = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderTop:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 0, 0)
  searchBorderTop:SetPoint("TOPRIGHT", contactsSearchFrame, "TOPRIGHT", 0, 0)
  searchBorderTop:SetHeight(1)
  applyTexture(searchBorderTop, searchBorderColor)

  local searchBorderBottom = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderBottom:SetPoint("BOTTOMLEFT", contactsSearchFrame, "BOTTOMLEFT", 0, 0)
  searchBorderBottom:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", 0, 0)
  searchBorderBottom:SetHeight(1)
  applyTexture(searchBorderBottom, searchBorderColor)

  local searchBorderLeft = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderLeft:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 0, 0)
  searchBorderLeft:SetPoint("BOTTOMLEFT", contactsSearchFrame, "BOTTOMLEFT", 0, 0)
  searchBorderLeft:SetWidth(1)
  applyTexture(searchBorderLeft, searchBorderColor)

  local searchBorderRight = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderRight:SetPoint("TOPRIGHT", contactsSearchFrame, "TOPRIGHT", 0, 0)
  searchBorderRight:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", 0, 0)
  searchBorderRight:SetWidth(1)
  applyTexture(searchBorderRight, searchBorderColor)

  local contactsSearchInput = factory.CreateFrame("EditBox", nil, contactsSearchFrame)
  contactsSearchInput:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 8, -4)
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
  contactsSearchPlaceholder:SetText("Search chats")
  uiHelpers.setTextColor(contactsSearchPlaceholder, theme.COLORS.text_secondary)

  local contactsSearchClearButton = factory.CreateFrame("Button", nil, contactsSearchFrame)
  contactsSearchClearButton:SetSize(searchClearButtonSize, searchClearButtonSize)
  contactsSearchClearButton:SetPoint("RIGHT", contactsSearchFrame, "RIGHT", -2, 0)
  contactsSearchClearButton:EnableMouse(true)

  local contactsSearchClearLabel = contactsSearchClearButton:CreateFontString(nil, "OVERLAY", theme.FONTS.contact_name)
  contactsSearchClearLabel:SetPoint("CENTER", contactsSearchClearButton, "CENTER", 0, 0)
  contactsSearchClearLabel:SetText("X")
  uiHelpers.setTextColor(contactsSearchClearLabel, theme.COLORS.text_secondary)

  contactsSearchPlaceholder:Show()
  contactsSearchClearButton:Hide()
  contactsSearchClearButton:SetScript("OnEnter", function()
    uiHelpers.setTextColor(contactsSearchClearLabel, theme.COLORS.text_primary)
  end)
  contactsSearchClearButton:SetScript("OnLeave", function()
    uiHelpers.setTextColor(contactsSearchClearLabel, theme.COLORS.text_secondary)
  end)

  return {
    frame = contactsSearchFrame,
    bg = contactsSearchBg,
    borderTop = searchBorderTop,
    borderBottom = searchBorderBottom,
    borderLeft = searchBorderLeft,
    borderRight = searchBorderRight,
    input = contactsSearchInput,
    placeholder = contactsSearchPlaceholder,
    clearButton = contactsSearchClearButton,
    clearLabel = contactsSearchClearLabel,
  }
end

ns.MessengerWindowLayoutContactsSearchUI = ContactsSearchUI

return ContactsSearchUI
