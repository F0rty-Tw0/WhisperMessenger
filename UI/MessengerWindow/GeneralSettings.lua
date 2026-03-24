local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local createOptionButton = UIHelpers.createOptionButton

local GeneralSettings = {}

local PADDING = Theme.CONTENT_PADDING
local SLIDER_WIDTH = 280
local SLIDER_HEIGHT = 16
local ROW_SPACING = 32
local LABEL_SPACING = 6

local DEFAULTS = {
  maxMessagesPerConversation = 200,
  maxConversations = 100,
  messageMaxAge = 86400,
  clearOnLogout = false,
  hideMessagePreview = false,
}

local function createSettingRow(factory, parent, label, min, max, step, initial, onChange)
  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local valueFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  valueFs:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  UIHelpers.setTextColor(valueFs, Theme.COLORS.text_secondary)

  local slider = factory.CreateFrame("Slider", nil, row)
  slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_SPACING)
  if slider.SetOrientation then
    slider:SetOrientation("HORIZONTAL")
  end
  slider:SetMinMaxValues(min, max)
  slider:SetValueStep(step)

  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end

  local bg = slider:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(slider)
  applyColorTexture(bg, Theme.COLORS.option_button_bg)

  if slider.SetThumbTexture then
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  end

  local minLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
  minLabel:SetText(tostring(min))
  UIHelpers.setTextColor(minLabel, Theme.COLORS.text_secondary)

  local maxLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
  maxLabel:SetText(tostring(max))
  UIHelpers.setTextColor(maxLabel, Theme.COLORS.text_secondary)

  slider:SetValue(initial)
  valueFs:SetText(tostring(initial))

  slider:SetScript("OnValueChanged", function(_self, value)
    local stepped = math.floor(value / step + 0.5) * step
    valueFs:SetText(tostring(stepped))
    if onChange then
      onChange(stepped)
    end
  end)

  return {
    row = row,
    label = labelFs,
    value = valueFs,
    slider = slider,
    minLabel = minLabel,
    maxLabel = maxLabel,
  }
end

-- Create the General Settings view.
--
-- factory : frame factory
-- parent  : the optionsContentPane frame
-- config  : { maxMessagesPerConversation, maxConversations, messageMaxAge }
-- options : { onChange(key, value) }
--
-- Returns: { frame, maxMessagesSlider, maxConversationsSlider, retentionSlider }
function GeneralSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("General Settings")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Configure message storage and retention limits.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  -- Max messages per conversation
  local messagesRow = createSettingRow(
    factory,
    frame,
    "Max Messages Per Contact",
    50,
    500,
    10,
    config.maxMessagesPerConversation or 200,
    function(value)
      onChange("maxMessagesPerConversation", value)
    end
  )
  messagesRow.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ROW_SPACING)

  -- Max conversations
  local conversationsRow = createSettingRow(
    factory,
    frame,
    "Max Contacts",
    10,
    100,
    10,
    config.maxConversations or 100,
    function(value)
      onChange("maxConversations", value)
    end
  )
  conversationsRow.row:SetPoint("TOPLEFT", messagesRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  -- Message retention (in hours, converted to/from seconds)
  local retentionHours = math.floor((config.messageMaxAge or 86400) / 3600 + 0.5)
  local retentionRow = createSettingRow(
    factory,
    frame,
    "Message Retention (hours)",
    1,
    168,
    1,
    retentionHours,
    function(value)
      onChange("messageMaxAge", value * 3600)
    end
  )
  retentionRow.row:SetPoint("TOPLEFT", conversationsRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  -- Privacy toggles
  local toggleColors = {
    text = Theme.COLORS.text_primary,
    on = Theme.COLORS.online,
    off = Theme.COLORS.offline,
  }
  local toggleLayout = { width = SLIDER_WIDTH, height = 24 }

  local privacyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  privacyLabel:SetPoint("TOPLEFT", retentionRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)
  privacyLabel:SetText("Privacy")
  UIHelpers.setTextColor(privacyLabel, Theme.COLORS.text_secondary)

  local clearOnLogoutToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Clear on logout",
    config.clearOnLogout == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("clearOnLogout", value)
    end
  )
  clearOnLogoutToggle.row:SetPoint("TOPLEFT", privacyLabel, "BOTTOMLEFT", 0, -12)

  local hidePreviewToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Hide message preview",
    config.hideMessagePreview == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("hideMessagePreview", value)
    end
  )
  hidePreviewToggle.row:SetPoint("TOPLEFT", clearOnLogoutToggle.row, "BOTTOMLEFT", 0, -12)

  -- Reset to Defaults button
  local normalColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local resetButton = createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = SLIDER_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", hidePreviewToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  resetButton:SetScript("OnClick", function()
    messagesRow.slider:SetValue(DEFAULTS.maxMessagesPerConversation)
    conversationsRow.slider:SetValue(DEFAULTS.maxConversations)
    retentionRow.slider:SetValue(math.floor(DEFAULTS.messageMaxAge / 3600 + 0.5))
    clearOnLogoutToggle.setValue(DEFAULTS.clearOnLogout)
    onChange("clearOnLogout", DEFAULTS.clearOnLogout)
    hidePreviewToggle.setValue(DEFAULTS.hideMessagePreview)
    onChange("hideMessagePreview", DEFAULTS.hideMessagePreview)
  end)

  return {
    frame = frame,
    maxMessagesSlider = messagesRow.slider,
    maxConversationsSlider = conversationsRow.slider,
    retentionSlider = retentionRow.slider,
    maxMessagesMinLabel = messagesRow.minLabel,
    maxMessagesMaxLabel = messagesRow.maxLabel,
    maxConversationsMinLabel = conversationsRow.minLabel,
    maxConversationsMaxLabel = conversationsRow.maxLabel,
    retentionMinLabel = retentionRow.minLabel,
    retentionMaxLabel = retentionRow.maxLabel,
    clearOnLogoutToggle = clearOnLogoutToggle,
    hidePreviewToggle = hidePreviewToggle,
    resetButton = resetButton,
  }
end

ns.GeneralSettings = GeneralSettings
return GeneralSettings
