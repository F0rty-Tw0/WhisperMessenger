local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ToggleSpecs = ns.MessengerWindowBehaviorToggleSpecs or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.ToggleSpecs")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING

local function text(key)
  return Localization.Text(key)
end

local DEFAULTS = ToggleSpecs.DEFAULTS

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = text("Behavior"),
    hint = text("Control how the messenger window behaves."),
  })
  local hint = header.hint

  local toggleSpecs = ToggleSpecs.Build(config, onChange)

  local toggles = SettingsControls.BuildToggleList(factory, frame, hint, toggleSpecs)
  local dimToggle = toggles[1]
  local autoFocusToggle = toggles[2]
  local hideFromDefaultChatToggle = toggles[3]
  local profanityFilterToggle = toggles[4]
  local autoOpenIncomingToggle = toggles[5]
  local autoOpenOutgoingToggle = toggles[6]
  local hideOnCombatToggle = toggles[7]
  local doubleEscapeToggle = toggles[8]
  local showGroupChatsToggle = toggles[9]
  local requestsInboxToggle = toggles[10]
  local shareTypingToggle = toggles[11]
  local shareReadReceiptsToggle = toggles[12]

  local panel = SettingsControls.NewPanelRegistry()
  panel:bind(dimToggle, { type = "toggle", key = "dimWhenMoving", default = DEFAULTS.dimWhenMoving })
  panel:bind(autoFocusToggle, { type = "toggle", key = "autoFocusComposer", default = DEFAULTS.autoFocusComposer })
  panel:bind(hideFromDefaultChatToggle, { type = "toggle", key = "hideFromDefaultChat", default = DEFAULTS.hideFromDefaultChat })
  -- Profanity filter writes a CVar instead of routing through onChange.
  panel:bind(profanityFilterToggle, {
    type = "toggle",
    reset = function(control)
      -- Blizzard's game-wide mature-language CVar has no addon default;
      -- "Reset to Defaults" must not silently flip it. Just re-sync the
      -- toggle display to the live value.
      local live = _G.GetCVar and _G.GetCVar("profanityFilter") == "1"
      control.setValue(live == true)
    end,
  })
  panel:bind(autoOpenIncomingToggle, { type = "toggle", key = "autoOpenIncoming", default = DEFAULTS.autoOpenIncoming })
  panel:bind(autoOpenOutgoingToggle, { type = "toggle", key = "autoOpenOutgoing", default = DEFAULTS.autoOpenOutgoing })
  panel:bind(hideOnCombatToggle, { type = "toggle", key = "hideOnCombat", default = DEFAULTS.hideOnCombat })
  panel:bind(doubleEscapeToggle, { type = "toggle", key = "doubleEscapeToClose", default = DEFAULTS.doubleEscapeToClose })
  panel:bind(showGroupChatsToggle, { type = "toggle", key = "showGroupChats", default = DEFAULTS.showGroupChats })
  panel:bind(requestsInboxToggle, { type = "toggle", key = "requestsInbox", default = DEFAULTS.requestsInbox })
  panel:bind(shareTypingToggle, { type = "toggle", key = "shareTypingStatus", default = DEFAULTS.shareTypingStatus })
  panel:bind(shareReadReceiptsToggle, { type = "toggle", key = "shareReadReceipts", default = DEFAULTS.shareReadReceipts })

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
  resetButton:SetPoint("TOPLEFT", shareReadReceiptsToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  -- Marker the options scrollview reads to size the scroll content to this
  -- tab's actual extent. Anchored to the very last control plus a padding
  -- spacer, so its bottom = panel content bottom.
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text("Behavior"))
    header.hint:SetText(text("Control how the messenger window behaves."))
    dimToggle.label:SetText(text("Dim when moving"))
    autoFocusToggle.label:SetText(text("Auto-focus chat input"))
    hideFromDefaultChatToggle.label:SetText(text("Hide whispers from default chat"))
    profanityFilterToggle.label:SetText(text("Enable profanity filter"))
    autoOpenIncomingToggle.label:SetText(text("Auto-open on incoming whisper"))
    autoOpenOutgoingToggle.label:SetText(text("Auto-open on outgoing whisper"))
    doubleEscapeToggle.label:SetText(text("Double ESC to close"))
    hideOnCombatToggle.label:SetText(text("Hide on entering combat"))
    showGroupChatsToggle.label:SetText(text("Show group chats"))
    requestsInboxToggle.label:SetText(text("Put whispers from strangers in Requests"))
    shareTypingToggle.label:SetText(text("Share typing status"))
    shareReadReceiptsToggle.label:SetText(text("Send read receipts"))
    resetButton.label:SetText(text("Reset to Defaults"))
    -- Tooltip lines were captured into closure-frozen arrays at construction
    -- and stay in the previous language until the toggle is re-hovered after
    -- a /reload. Live-refreshing them would require restructuring the toggle
    -- helper to read keys at hover time; deferred until the codebase needs it.
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = setLanguage,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
