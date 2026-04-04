local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local OptionsPanelLayout = {}

function OptionsPanelLayout.Build(factory, frame, initialState, options)
  options = options or {}

  local theme = options.theme or Theme
  local contactsWidth = options.contactsWidth
  local scrollView = options.scrollView or ScrollView
  local applyTexture = options.applyColorTexture or applyColorTexture

  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -theme.TOP_BAR_HEIGHT)
  optionsPanel:SetSize(initialState.width, initialState.height - theme.TOP_BAR_HEIGHT)

  local optionsMenu = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsMenu:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsMenu:SetSize(contactsWidth, initialState.height - theme.TOP_BAR_HEIGHT)

  local optionsMenuBg = optionsMenu:CreateTexture(nil, "BACKGROUND")
  optionsMenuBg:SetAllPoints(optionsMenu)
  applyTexture(optionsMenuBg, theme.COLORS.bg_secondary)

  local menuPadding = theme.CONTENT_PADDING

  local optionsHeader = optionsMenu:CreateFontString(nil, "OVERLAY", theme.FONTS.header_name)
  optionsHeader:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", menuPadding, -menuPadding)
  optionsHeader:SetText("Options")

  local optionsMenuDivider = optionsPanel:CreateTexture(nil, "BORDER")
  optionsMenuDivider:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", 0, 0)
  optionsMenuDivider:SetSize(theme.DIVIDER_THICKNESS, initialState.height - theme.TOP_BAR_HEIGHT)
  applyTexture(optionsMenuDivider, theme.COLORS.divider)

  local optionsContentWidth = initialState.width - contactsWidth - theme.DIVIDER_THICKNESS
  local optionsContentH = initialState.height - theme.TOP_BAR_HEIGHT
  local optionsContentPane = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsContentPane:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", theme.DIVIDER_THICKNESS, 0)
  optionsContentPane:SetSize(optionsContentWidth, optionsContentH)

  local optionsContentBg = optionsContentPane:CreateTexture(nil, "BACKGROUND")
  optionsContentBg:SetAllPoints(optionsContentPane)
  applyTexture(optionsContentBg, theme.COLORS.bg_primary)

  local OPTIONS_CONTENT_HEIGHT = 420
  local optionsScrollView = scrollView.Create(factory, optionsContentPane, {
    width = optionsContentWidth,
    height = optionsContentH,
    step = 24,
  })
  optionsScrollView.content:SetSize(optionsContentWidth, OPTIONS_CONTENT_HEIGHT)

  return {
    optionsPanel = optionsPanel,
    optionsMenu = optionsMenu,
    optionsMenuBg = optionsMenuBg,
    menuPadding = menuPadding,
    optionsHeader = optionsHeader,
    optionsMenuDivider = optionsMenuDivider,
    optionsContentPane = optionsContentPane,
    optionsContentBg = optionsContentBg,
    optionsScrollView = optionsScrollView,
    optionsContentHeight = OPTIONS_CONTENT_HEIGHT,
  }
end

ns.MessengerWindowLayoutOptionsPanelLayout = OptionsPanelLayout

return OptionsPanelLayout
