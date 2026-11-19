local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatReplyState = ns.ChatReplyState or require("WhisperMessenger.Util.ChatReplyState")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IconSurfaces = ns.BootstrapWindowCoordinatorIconSurfaces or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IconSurfaces")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ReloadSettings = ns.BootstrapWindowRuntimeReloadSettings or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ReloadSettings")
local HudStyleSetting = ReloadSettings.HudStyleSetting
local CompactLayoutSetting = ReloadSettings.CompactLayoutSetting
local IntegrationSetting = ReloadSettings.IntegrationSetting
local LanguageSetting = ReloadSettings.LanguageSetting
local SettingReactions = ns.BootstrapWindowRuntimeSettingReactions or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingReactions")
local DisplayNameSetting = SettingReactions.DisplayNameSetting
local TabVisibilitySetting = SettingReactions.TabVisibilitySetting
local RefreshingSettings = SettingReactions.RefreshingSettings
local EscapeSetting = SettingReactions.EscapeSetting
local IconSettingReactions = SettingReactions.IconSettingReactions
local ComposerSetting = SettingReactions.ComposerSetting
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local WhoLookup = ns.WhoLookup or require("WhisperMessenger.Transport.WhoLookup")
local Relationship = ns.Relationship or require("WhisperMessenger.Model.Relationship")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")

local RETENTION_SETTING_KEYS = {
  maxMessagesPerConversation = true,
  maxConversations = true,
  messageMaxAge = true,
}

local SettingsHandler = {}

function SettingsHandler.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountSettings = options.accountSettings or {}
  local theme = options.theme or {}
  local fonts = options.fonts or {}
  local timeFormat = options.timeFormat or {}
  local localization = options.localization or Localization
  local displayName = options.displayName or DisplayName
  local windowScale = options.windowScale or WindowScale
  local getIcon = options.getIcon or function()
    return nil
  end
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local getNumChatWindows = options.getNumChatWindows or function()
    return _G.NUM_CHAT_WINDOWS or 10
  end
  local getEditBox = options.getEditBox or function(index)
    return _G["ChatFrame" .. index .. "EditBox"]
  end
  local onShareWidgetPositionChanged = options.onShareWidgetPositionChanged

  -- A change to the floating button reaches the window it may ride (either layout).
  local function dockCompactIcon()
    local window = runtime.window
    if window and window.dockCompactIcon then
      window.dockCompactIcon()
    end
  end

  return function(key, value)
    -- Not a setting: the Filters page changed the ignore list or rules.
    if key == "filters" then
      if runtime.syncChatFilters then
        runtime.syncChatFilters()
      end
      -- The open whisper's header shows whether that player is blocked.
      if runtime.refreshWindow then
        runtime.refreshWindow()
      end
      return
    end
    -- Saved by HudStyleSetting only when the player reloads.
    if key == "hudStyle" then
      HudStyleSetting.Apply(accountSettings, value, function(savedStyle)
        local appearance = runtime.window and runtime.window.appearanceSettings
        if appearance and appearance.setHudStyle then
          appearance.setHudStyle(savedStyle)
        end
      end)
      return
    end
    -- Saved by CompactLayoutSetting only when the player reloads.
    if key == "compactLayout" then
      CompactLayoutSetting.Apply(accountSettings, value == true, runtime.compactLayoutActive ~= false, function(saved)
        local appearance = runtime.window and runtime.window.appearanceSettings
        if appearance and appearance.setCompactLayout then
          appearance.setCompactLayout(saved)
        end
      end)
      return
    end
    if key == "allowAddonIntegration" then
      IntegrationSetting.Apply(accountSettings, value, runtime)
      return
    end
    if key == "interfaceLanguage" and LanguageSetting.Apply(accountSettings, value, runtime, localization) then
      return
    end
    local persistedValue = value
    if key == "windowScale" and windowScale.Normalize then
      persistedValue = windowScale.Normalize(value)
    end
    local themeApplied = false
    local previousPreset = accountSettings.themePreset

    if key == "themePreset" then
      local fallbackKey = theme.DEFAULT_PRESET or "wow_default"
      local presetKey = value or fallbackKey
      persistedValue = presetKey
      if theme.ResolvePreset then
        local resolvedKey, applied = theme.ResolvePreset(presetKey)
        persistedValue = resolvedKey or presetKey
        themeApplied = applied == true
      end
    end

    local previousValue = accountSettings[key]
    accountSettings[key] = persistedValue

    if key ~= "windowScale" and runtime.store.config[key] ~= nil then
      runtime.store.config[key] = persistedValue
    end
    if key == "messageMaxAge" then
      runtime.store.config.conversationMaxAge = persistedValue
    end

    if RETENTION_SETTING_KEYS[key] then
      local now = runtime.now and runtime.now() or nil
      -- A selected chat that expires here loses the selection through the
      -- store's removal hook.
      Store.ApplyRetention(runtime.store, now, runtime.activeConversationKey)
      if runtime.refreshWindow then
        runtime.refreshWindow()
      end
    end

    if key == "windowScale" then
      local window = runtime.window
      if window and window.setScale then
        window.setScale(persistedValue)
      end
    end

    -- Reset to Defaults sends the default even when it is already set; moving
    -- the window then would drop it on an old saved spot.
    if key == "shareWidgetPosition" and onShareWidgetPositionChanged and (persistedValue == true) ~= (previousValue == true) then
      onShareWidgetPositionChanged(persistedValue)
    end

    if key == "fontFamily" and fonts.SetMode then
      fonts.SetMode(persistedValue or "default")
    end
    if key == "fontSize" and fonts.SetFontSize then
      fonts.SetFontSize(persistedValue or 12)
    end
    if key == "fontOutline" and fonts.SetOutline then
      fonts.SetOutline(persistedValue or "NONE")
    end
    if key == "fontFamily" or key == "fontSize" or key == "fontOutline" then
      local composer = runtime.window and runtime.window.composer
      if composer and composer.remeasure then
        composer.remeasure()
      end
    end
    ComposerSetting.Apply(runtime, key, persistedValue)
    if key == "fontColor" and fonts.SetFontColor then
      fonts.SetFontColor(persistedValue or "default")
    end
    if key == "bubbleColorPreset" and theme.SetBubblePreset then
      theme.SetBubblePreset(persistedValue or "default")
    end
    if (key == "timeFormat" or key == "timeSource") and timeFormat.Configure then
      timeFormat.Configure({ [key] = persistedValue })
    end
    DisplayNameSetting.Apply(displayName, key, persistedValue, runtime.seenLevelEvents)
    if key == "whoLookups" then
      WhoLookup.SetEnabled(persistedValue ~= false)
    end
    if key == "showRelationshipMarks" then
      Relationship.Invalidate(runtime)
    end
    if key == "interfaceLanguage" then
      if localization.Configure then
        localization.Configure({ language = persistedValue })
      end
      -- Korean and Chinese locales need a CJK-capable font path; the
      -- default FRIZQT / ARIALN / MORPHEUS files contain no CJK glyphs
      -- and render as squares. Update the font swap before refreshing
      -- so the next paint uses the correct face.
      if fonts.SetLanguage then
        fonts.SetLanguage(persistedValue)
      end
      -- Configure() must run first so child widgets re-resolve from the new
      -- catalog. refreshLanguage carries the explicit language so the
      -- General panel's languageOverride-based text() helper sees the user's
      -- choice instead of the "auto" default.
      if runtime.window and runtime.window.refreshLanguage then
        runtime.window.refreshLanguage(persistedValue)
      end
    end
    if (key == "hideFromDefaultChat" or key == "hideChannelsFromDefaultChat" or key == "enabledChannels") and runtime.syncChatFilters then
      runtime.syncChatFilters()
    end
    if key == "hideFromDefaultChat" and runtime.syncReplyKey then
      runtime.syncReplyKey()
    end
    if key == "autoOpenOutgoing" and persistedValue == true then
      ChatReplyState.ClearStaleWhisperReplyState(getNumChatWindows, getEditBox)
    end
    TabVisibilitySetting.Apply(runtime, accountSettings, key, persistedValue)
    EscapeSetting.Apply(runtime, key)
    if RefreshingSettings.Has(key) and runtime.refreshWindow then
      runtime.refreshWindow()
    end

    if key == "themePreset" and themeApplied then
      if runtime.window and runtime.window.refreshTheme then
        runtime.window.refreshTheme()
      end
      -- The widget icon, minimap button and detached preview: Surfaces owns the list.
      if options.refreshSurfacesTheme then
        options.refreshSurfacesTheme()
      end
      if runtime.refreshWindow then
        runtime.refreshWindow()
      end
      HudStyleSetting.OfferOffFor(accountSettings, previousPreset, persistedValue, function(style)
        local appearance = runtime.window and runtime.window.appearanceSettings
        if appearance and appearance.setHudStyle then
          appearance.setHudStyle(style)
        end
      end)
    end

    local icon = getIcon()
    local minimap = options.getMinimapIcon and options.getMinimapIcon()
    -- The icon refresh's count; each icon resyncs alone (no starved minimap).
    if (key == "showUnreadBadge" or key == "badgePulse") and (icon or minimap) then
      local total, unread = IconSurfaces.Counts(buildContacts(), runtime.panelRegistry)
      IconSurfaces.ShowCounts(total, unread, icon, minimap)
    end

    if key == "iconMode" and options.applyIconMode then
      options.applyIconMode()
      dockCompactIcon()
    end

    if key == "iconSize" and icon and icon.applyIconSize then
      icon.applyIconSize(persistedValue)
      dockCompactIcon()
    end

    if key == "iconDock" then
      dockCompactIcon()
    end

    IconSettingReactions.Apply(key, persistedValue, icon, minimap)

    if options.onDetachedSetting then
      options.onDetachedSetting(key, persistedValue)
    end
  end
end

ns.BootstrapWindowRuntimeSettingsHandler = SettingsHandler

return SettingsHandler
