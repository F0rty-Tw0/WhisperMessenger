local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TOGGLE_WIDTH = 280
local ROW_SPACING = 16
local LABEL_SPACING = 6

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
  notificationSound = "whisper",
}

local SOUND_OPTIONS = {
  { key = "whisper", label = "Whisper" },
  { key = "ping", label = "Ping" },
  { key = "chime", label = "Chime" },
  { key = "bell", label = "Bell" },
  { key = "raid_warning", label = "RW" },
}

local function createSoundSelector(factory, parent, initial, colors, onChange)
  local BUTTON_WIDTH = 50
  local BUTTON_HEIGHT = 26
  local BUTTON_SPACING = 4

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(TOGGLE_WIDTH, BUTTON_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText("Notification sound")
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local buttons = {}
  local selected = initial or DEFAULTS.notificationSound

  local function updateSelection(nextSelected)
    selected = nextSelected
    for _, entry in ipairs(buttons) do
      if entry._key == selected then
        entry._selected = true
        applyColorTexture(entry.bg, colors.bgActive or { 0.30, 0.82, 0.40, 1.0 })
        UIHelpers.setTextColor(entry.label, colors.textActive or Theme.COLORS.text_primary)
      else
        entry._selected = false
        applyColorTexture(entry.bg, colors.bg or Theme.COLORS.option_button_bg)
        UIHelpers.setTextColor(entry.label, colors.text or Theme.COLORS.option_button_text)
      end
    end
  end

  for i, opt in ipairs(SOUND_OPTIONS) do
    local btn = factory.CreateFrame("Button", nil, row)
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)

    if i == 1 then
      btn:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_SPACING)
    else
      btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", BUTTON_SPACING, 0)
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)

    local btnLabel = btn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    btnLabel:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnLabel:SetText(opt.label)

    btn._key = opt.key
    btn._selected = false
    btn.bg = bg
    btn.label = btnLabel

    btn:SetScript("OnClick", function()
      updateSelection(opt.key)
      if onChange then
        onChange(opt.key)
      end
      local SoundPlayer = ns.SoundPlayer
      if SoundPlayer and SoundPlayer.Preview then
        SoundPlayer.Preview(opt.key)
      end
    end)

    btn:SetScript("OnEnter", function()
      if btn._key ~= selected then
        applyColorTexture(bg, colors.bgHover or Theme.COLORS.option_button_hover)
        UIHelpers.setTextColor(btnLabel, colors.textHover or Theme.COLORS.option_button_text_hover)
      end
    end)

    btn:SetScript("OnLeave", function()
      if btn._key ~= selected then
        applyColorTexture(bg, colors.bg or Theme.COLORS.option_button_bg)
        UIHelpers.setTextColor(btnLabel, colors.text or Theme.COLORS.option_button_text)
      end
    end)

    table.insert(buttons, btn)
  end

  updateSelection(selected)

  return {
    row = row,
    buttons = buttons,
    setSelected = updateSelection,
  }
end

function NotificationSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Notifications")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Configure alerts for incoming messages.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local toggleColors = {
    text = Theme.COLORS.text_primary,
    on = Theme.COLORS.online,
    off = Theme.COLORS.offline,
  }
  local toggleLayout = { width = TOGGLE_WIDTH, height = 24 }

  local badgePulseToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Badge pulse animation",
    config.badgePulse ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("badgePulse", value)
    end
  )
  badgePulseToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local playSoundToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Notification sound",
    config.playSoundOnWhisper == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("playSoundOnWhisper", value)
    end
  )
  playSoundToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local selectorColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    bgActive = Theme.COLORS.accent_primary or { 0.30, 0.82, 0.40, 1.0 },
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
    textActive = Theme.COLORS.text_primary,
  }
  local soundSelector = createSoundSelector(
    factory,
    frame,
    config.notificationSound or DEFAULTS.notificationSound,
    selectorColors,
    function(value)
      onChange("notificationSound", value)
    end
  )
  soundSelector.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local showBadgeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Show unread badge",
    config.showUnreadBadge ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("showUnreadBadge", value)
    end
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  -- Reset button
  local normalColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = TOGGLE_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    badgePulseToggle.setValue(DEFAULTS.badgePulse)
    onChange("badgePulse", DEFAULTS.badgePulse)
    playSoundToggle.setValue(DEFAULTS.playSoundOnWhisper)
    onChange("playSoundOnWhisper", DEFAULTS.playSoundOnWhisper)
    soundSelector.setSelected(DEFAULTS.notificationSound)
    onChange("notificationSound", DEFAULTS.notificationSound)
    showBadgeToggle.setValue(DEFAULTS.showUnreadBadge)
    onChange("showUnreadBadge", DEFAULTS.showUnreadBadge)
  end)

  return {
    frame = frame,
    badgePulseToggle = badgePulseToggle,
    playSoundToggle = playSoundToggle,
    soundSelector = soundSelector,
    showBadgeToggle = showBadgeToggle,
    resetButton = resetButton,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
