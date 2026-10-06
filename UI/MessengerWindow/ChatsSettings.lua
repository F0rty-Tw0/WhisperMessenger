local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChannelPicker = ns.MessengerWindowChannelPicker or require("WhisperMessenger.UI.MessengerWindow.ChatsSettings.ChannelPicker")

-- Options page for group chats and public channels: show group chats,
-- collapse repeats, hide channels from Blizzard chat, and the channel picker.
local ChatsSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TITLE = "Chats"
local HINT = "Choose which group chats and channels appear."
local TIP = "To hide a channel from the game's chat, right-click the chat tab, open Settings and untick it."

ChatsSettings.DEFAULTS = {
  showGroupChats = true,
  collapseDuplicates = true,
  hideChannelsFromDefaultChat = false,
}

local function text(key)
  return Localization.Text(key)
end

-- Core/Bootstrap loads after the UI in the TOC, so read the flag at create
-- time rather than at file load.
local function selectiveHiding()
  local chatFilters = ns.BootstrapChatFilters or require("WhisperMessenger.Core.Bootstrap.ChatFilters")
  return chatFilters.SELECTIVE_HIDING == true
end

local function buildToggleSpecs(config, onChange, withHiding)
  local function spec(key, labelKey, initial, tooltipLines)
    return {
      key = key,
      labelKey = labelKey,
      label = text(labelKey),
      initial = initial,
      onChange = function(value)
        onChange(key, value)
      end,
      tooltipLines = tooltipLines,
    }
  end
  local specs = {
    spec("showGroupChats", "Show group chats", config.showGroupChats ~= false, {
      text("Show group chats"),
      text("Shows a Groups tab in the contacts list with party, instance, and Battle.net group conversations."),
      text("When off, only whispers appear."),
    }),
  }
  if withHiding then
    specs[#specs + 1] = spec("hideChannelsFromDefaultChat", "Hide channels from default chat", config.hideChannelsFromDefaultChat == true, {
      text("Hide channels from default chat"),
    })
  end
  specs[#specs + 1] = spec("collapseDuplicates", "Collapse repeated messages", config.collapseDuplicates ~= false, {
    text("Collapse repeated messages"),
    text("When a player repeats a message in a channel, it shows once with a count."),
  })
  specs[1].anchorOffsetY = -24
  return specs
end

function ChatsSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, { title = text(TITLE), hint = text(HINT) })

  local withHiding = selectiveHiding()
  local toggleSpecs = buildToggleSpecs(config, onChange, withHiding)
  local toggles = SettingsControls.BuildToggleList(factory, frame, header.hint, toggleSpecs)

  local panel = SettingsControls.NewPanelRegistry()
  SettingsControls.BindToggleSpecs(panel, toggles, toggleSpecs, ChatsSettings.DEFAULTS)

  -- Not bound to Reset to Defaults: it would untick the channels the player picked.
  local picker = ChannelPicker.Create(factory, frame, toggles[#toggles].row, { config = config, panel = panel, onChange = onChange })

  local lastAbove = picker.bottom
  local tip
  if not withHiding then
    tip = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    tip:SetText(text(TIP))
    tip:SetJustifyH("LEFT")
    tip:SetWordWrap(true)
    tip:SetWidth(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH)
    tip:SetPoint("TOPLEFT", picker.bottom, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)
    lastAbove = tip
  end

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, ghost = true }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", lastAbove, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  -- Marker the options scrollview reads to size the scroll content.
  frame._wmBottomMarker = bottomSpacer

  -- Channels joined since the page was built show up the next time it opens.
  frame:SetScript("OnShow", picker.refresh)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
    picker.refreshTheme(activeTheme)
    if tip then
      UIHelpers.setTextColor(tip, activeTheme.COLORS.text_secondary)
    end
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text(TITLE))
    header.hint:SetText(text(HINT))
    SettingsControls.RelabelToggles(toggles, toggleSpecs, text)
    picker.setLanguage()
    if tip then
      tip:SetText(text(TIP))
    end
    resetButton.label:SetText(text("Reset to Defaults"))
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local effective = math.min(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
    picker.refreshLayout(effective)
    if tip then
      tip:SetWidth(effective)
    end
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
  }
end

ns.ChatsSettings = ChatsSettings
return ChatsSettings
