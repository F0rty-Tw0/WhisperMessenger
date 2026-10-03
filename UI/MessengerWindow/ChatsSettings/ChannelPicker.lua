local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local JoinedChannels = ns.JoinedChannels or require("WhisperMessenger.Transport.JoinedChannels")

-- "Channels" section of the Chats page: one toggle per built-in channel plus
-- one per custom channel the character has joined. Ticking a channel saves a
-- fresh `enabledChannels` table; the saved one is never mutated in place.
local ChannelPicker = {}

-- Built-in channels by zone channel ID, in display order.
local BUILT_INS = {
  { id = 1, labelKey = "General" },
  { id = 2, labelKey = "Trade" },
  { id = 42, labelKey = "Trade (Services)" },
  { id = 22, labelKey = "Local Defense" },
  { id = 23, labelKey = "World Defense" },
  { id = 26, labelKey = "Looking for Group" },
}
-- Custom channel slugs are "c:<lowercased name>".
local CUSTOM_SLUG_PATTERN = "^c:."

local function text(key)
  return Localization.Text(key)
end

-- Ticked custom channels missing from `listed` (left on this character, or
-- ticked on an alt that never joined), so they can still be unticked. The
-- saved key is lowercase, so the label only gets its first letter raised.
local function leftChannels(enabledChannels, listed)
  local slugs = {}
  for slug, enabled in pairs(type(enabledChannels) == "table" and enabledChannels or {}) do
    if enabled == true and not listed[slug] and string.find(slug, CUSTOM_SLUG_PATTERN) then
      slugs[#slugs + 1] = slug
    end
  end
  table.sort(slugs)
  local channels = {}
  for index, slug in ipairs(slugs) do
    local name = string.sub(slug, 3)
    channels[index] = { slug = slug, label = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2) }
  end
  return channels
end

-- options = { config, panel, onChange }. Returns the section with `bottom`
-- (the frame the next control anchors below) and `refresh` (re-reads the
-- joined channels).
function ChannelPicker.Create(factory, frame, anchor, options)
  local config = options.config
  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }
  local spacing = Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING

  local titleSection = SettingsControls.CreateSectionLabel(frame, text("Channels"))
  titleSection.region:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local bottom = factory.CreateFrame("Frame", nil, frame)
  bottom:SetSize(1, 1)

  local section = { bottom = bottom }
  local builtInRows = {}
  local customRows = {}

  local function setEnabled(slug, value)
    local nextChannels = {}
    for key, enabled in pairs(config.enabledChannels or {}) do
      nextChannels[key] = enabled
    end
    nextChannels[ChannelKey.SettingKey(slug)] = value == true or nil
    config.enabledChannels = nextChannels
    options.onChange("enabledChannels", nextChannels)
  end

  local function isEnabled(slug)
    local enabled = config.enabledChannels
    return type(enabled) == "table" and enabled[ChannelKey.SettingKey(slug)] == true
  end

  local function createRow(label)
    local entry = {}
    entry.toggle = UIHelpers.createToggleRow(factory, frame, label, false, toggleColors, toggleLayout, function(value)
      setEnabled(entry.slug, value)
    end)
    options.panel:bind(entry.toggle, { type = "toggle" })
    return entry
  end

  for index, builtIn in ipairs(BUILT_INS) do
    local entry = createRow(text(builtIn.labelKey))
    entry.slug = ChannelKey.ZONE_CHANNEL_IDS[builtIn.id]
    entry.labelKey = builtIn.labelKey
    builtInRows[index] = entry
  end

  -- Chains the shown rows below the section label and parks `bottom` under
  -- the last one.
  local function layoutRows(visible)
    local previous = titleSection.region
    local gap = -8
    for _, entry in ipairs(visible) do
      local row = entry.toggle.row
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, gap)
      row:Show()
      previous = row
      gap = -spacing
    end
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
  end

  function section.refresh()
    local visible = {}
    for _, entry in ipairs(builtInRows) do
      entry.toggle.setValue(isEnabled(entry.slug))
      visible[#visible + 1] = entry
    end
    local custom = JoinedChannels.Custom()
    local listed = {}
    for _, channel in ipairs(custom) do
      listed[channel.slug] = true
    end
    for _, channel in ipairs(leftChannels(config.enabledChannels, listed)) do
      custom[#custom + 1] = channel
    end
    for index, channel in ipairs(custom) do
      local entry = customRows[index] or createRow(channel.label)
      customRows[index] = entry
      entry.slug = channel.slug
      entry.toggle.label:SetText(channel.label)
      entry.toggle.setValue(isEnabled(channel.slug))
      visible[#visible + 1] = entry
    end
    for index = #custom + 1, #customRows do
      customRows[index].toggle.row:Hide()
    end
    layoutRows(visible)
  end

  function section.refreshTheme(activeTheme)
    titleSection.refreshTheme(activeTheme or Theme)
  end

  function section.refreshLayout(width)
    titleSection.refreshLayout(width)
  end

  function section.setLanguage()
    titleSection.label:SetText(text("Channels"))
    for _, entry in ipairs(builtInRows) do
      entry.toggle.label:SetText(text(entry.labelKey))
    end
  end

  section.refresh()
  return section
end

ns.MessengerWindowChannelPicker = ChannelPicker
return ChannelPicker
