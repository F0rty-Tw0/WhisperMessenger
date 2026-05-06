local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local function makeRuntime()
  local calls = {
    setTabMode = {},
    refreshTabToggleVisibility = 0,
    refreshWindow = 0,
    refreshTheme = 0,
    syncChatFilters = 0,
    syncReplyKey = 0,
  }
  local runtime = {
    store = { config = {} },
    window = {
      setTabMode = function(mode)
        table.insert(calls.setTabMode, mode)
      end,
      refreshTabToggleVisibility = function()
        calls.refreshTabToggleVisibility = calls.refreshTabToggleVisibility + 1
      end,
      refreshTheme = function()
        calls.refreshTheme = calls.refreshTheme + 1
      end,
    },
    refreshWindow = function()
      calls.refreshWindow = calls.refreshWindow + 1
    end,
    syncChatFilters = function()
      calls.syncChatFilters = calls.syncChatFilters + 1
    end,
    syncReplyKey = function()
      calls.syncReplyKey = calls.syncReplyKey + 1
    end,
  }
  return runtime, calls
end

local function makeFonts()
  local log = {}
  return {
    SetMode = function(mode)
      log[#log + 1] = { "mode", mode }
    end,
    SetFontSize = function(size)
      log[#log + 1] = { "fontSize", size }
    end,
    SetOutline = function(outline)
      log[#log + 1] = { "outline", outline }
    end,
    SetFontColor = function(color)
      log[#log + 1] = { "fontColor", color }
    end,
    SetLanguage = function(language)
      log[#log + 1] = { "language", language }
    end,
  },
    log
end

local function makeIcon()
  local state = {
    unreadCount = nil,
    appliedSize = nil,
    refreshDesaturationCalls = 0,
    appliedPreviewPosition = nil,
  }
  return {
    setUnreadCount = function(count)
      state.unreadCount = count
    end,
    applyIconSize = function(size)
      state.appliedSize = size
    end,
    refreshDesaturation = function()
      state.refreshDesaturationCalls = state.refreshDesaturationCalls + 1
    end,
    applyPreviewPosition = function(position)
      state.appliedPreviewPosition = position
    end,
  },
    state
end

return function()
  -- showGroupChats=false forces the Whispers tab and refreshes visibility.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = { showGroupChats = true }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("showGroupChats", false)

    assert(accountSettings.showGroupChats == false, "showGroupChats persisted as false")
    assert(#calls.setTabMode == 1 and calls.setTabMode[1] == "whispers", "setTabMode forced to whispers")
    assert(calls.refreshTabToggleVisibility == 1, "tab toggle visibility refreshed once")
    assert(calls.refreshWindow == 1, "window refreshed once")
  end

  -- showGroupChats=true preserves the user's last tab mode.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = { showGroupChats = false }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("showGroupChats", true)

    assert(accountSettings.showGroupChats == true, "showGroupChats persisted as true")
    assert(#calls.setTabMode == 0, "tab mode preserved when re-enabling")
    assert(calls.refreshTabToggleVisibility == 1, "visibility still refreshed")
  end

  -- showGroupChats handles a missing window without crashing (icon-before-window bootstrap).
  do
    local calls = { refreshWindow = 0 }
    local runtime = {
      store = { config = {} },
      window = nil,
      refreshWindow = function()
        calls.refreshWindow = calls.refreshWindow + 1
      end,
    }
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    local ok = pcall(onChange, "showGroupChats", false)
    assert(ok, "must not crash when runtime.window is nil")
    assert(accountSettings.showGroupChats == false, "setting still persists")
    assert(calls.refreshWindow == 1, "refreshWindow still fires")
  end

  -- Unrelated keys never touch the tab toggle.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("dimWhenMoving", true)

    assert(#calls.setTabMode == 0, "no tab change for unrelated key")
    assert(calls.refreshTabToggleVisibility == 0, "no toggle refresh for unrelated key")
  end

  -- fontFamily / fontSize / fontOutline / fontColor each route to the right Fonts API
  -- and refresh the window so live transcripts re-render.
  do
    local runtime, calls = makeRuntime()
    local fonts, fontLog = makeFonts()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings, fonts = fonts })

    onChange("fontFamily", "system")
    onChange("fontSize", 16)
    onChange("fontOutline", "OUTLINE")
    onChange("fontColor", "gold")

    assert(accountSettings.fontFamily == "system", "fontFamily persists")
    assert(accountSettings.fontSize == 16, "fontSize persists")
    assert(accountSettings.fontOutline == "OUTLINE", "fontOutline persists")
    assert(accountSettings.fontColor == "gold", "fontColor persists")
    assert(fontLog[1][1] == "mode" and fontLog[1][2] == "system", "fontFamily routes to Fonts.SetMode")
    assert(fontLog[2][1] == "fontSize" and fontLog[2][2] == 16, "fontSize routes to Fonts.SetFontSize")
    assert(fontLog[3][1] == "outline" and fontLog[3][2] == "OUTLINE", "fontOutline routes to Fonts.SetOutline")
    assert(fontLog[4][1] == "fontColor" and fontLog[4][2] == "gold", "fontColor routes to Fonts.SetFontColor")
    assert(calls.refreshWindow == 4, "each font key refreshes the window once")
  end

  -- Valid themePreset persists the resolved key, refreshes static chrome, and refreshes the window.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local theme = {
      DEFAULT_PRESET = "wow_default",
      ResolvePreset = function(key)
        return key, true
      end,
    }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings, theme = theme })

    onChange("themePreset", "elvui_dark")

    assert(accountSettings.themePreset == "elvui_dark", "valid preset persists")
    assert(calls.refreshTheme == 1, "static chrome refreshes once")
    assert(calls.refreshWindow == 1, "window refreshes once")
  end

  -- Invalid themePreset falls back to the default and persists the fallback key.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local theme = {
      DEFAULT_PRESET = "wow_default",
      ResolvePreset = function(key)
        if key == "unknown_preset" then
          return "wow_default", true
        end
        return key, true
      end,
    }
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings, theme = theme })

    onChange("themePreset", "unknown_preset")

    assert(accountSettings.themePreset == "wow_default", "invalid preset falls back and persists default")
    assert(calls.refreshTheme == 1, "fallback still refreshes static chrome")
    assert(calls.refreshWindow == 1, "fallback still refreshes the window")
  end

  -- iconSize forwards to icon.applyIconSize.
  do
    local runtime = makeRuntime()
    local icon, iconState = makeIcon()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = accountSettings,
      getIcon = function()
        return icon
      end,
    })

    onChange("iconSize", 48)

    assert(accountSettings.iconSize == 48, "iconSize persists")
    assert(iconState.appliedSize == 48, "icon.applyIconSize received the new size")
  end

  -- iconDesaturated forwards to icon.refreshDesaturation.
  do
    local runtime = makeRuntime()
    local icon, iconState = makeIcon()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = accountSettings,
      getIcon = function()
        return icon
      end,
    })

    onChange("iconDesaturated", true)

    assert(accountSettings.iconDesaturated == true, "iconDesaturated persists")
    assert(iconState.refreshDesaturationCalls == 1, "icon.refreshDesaturation called once")
  end

  -- widgetPreviewPosition forwards to icon.applyPreviewPosition.
  do
    local runtime = makeRuntime()
    local icon, iconState = makeIcon()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = accountSettings,
      getIcon = function()
        return icon
      end,
    })

    onChange("widgetPreviewPosition", "left")

    assert(accountSettings.widgetPreviewPosition == "left", "widgetPreviewPosition persists")
    assert(iconState.appliedPreviewPosition == "left", "icon.applyPreviewPosition received new value")
  end

  -- showUnreadBadge / badgePulse rebuild contacts and feed the icon a fresh sum.
  do
    local runtime = makeRuntime()
    local icon, iconState = makeIcon()
    local accountSettings = {}
    local builtContacts = { { unreadCount = 2 }, { unreadCount = 5 } }
    local builds = 0
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = accountSettings,
      getIcon = function()
        return icon
      end,
      buildContacts = function()
        builds = builds + 1
        return builtContacts
      end,
      tableUtils = {
        sumBy = function(items, key)
          local total = 0
          for _, item in ipairs(items) do
            total = total + (item[key] or 0)
          end
          return total
        end,
      },
    })

    onChange("showUnreadBadge", true)
    assert(builds == 1, "showUnreadBadge rebuilt contacts once")
    assert(iconState.unreadCount == 7, "icon received summed unread count")

    onChange("badgePulse", false)
    assert(builds == 2, "badgePulse rebuilt contacts again")
  end

  -- hideMessagePreview / showWidgetMessagePreview persist and refresh the window.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("hideMessagePreview", true)
    onChange("showWidgetMessagePreview", false)

    assert(accountSettings.hideMessagePreview == true, "hideMessagePreview persists")
    assert(accountSettings.showWidgetMessagePreview == false, "showWidgetMessagePreview persists")
    assert(calls.refreshWindow == 2, "each preview-related key refreshed the window")
  end

  -- timeFormat / timeSource forward to TimeFormat.Configure.
  do
    local runtime = makeRuntime()
    local configCalls = {}
    local timeFormat = {
      Configure = function(opts)
        configCalls[#configCalls + 1] = opts
      end,
    }
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings, timeFormat = timeFormat })

    onChange("timeFormat", "24h")
    onChange("timeSource", "server")

    assert(accountSettings.timeFormat == "24h", "timeFormat persists")
    assert(accountSettings.timeSource == "server", "timeSource persists")
    assert(configCalls[1].timeFormat == "24h", "TimeFormat.Configure received timeFormat")
    assert(configCalls[2].timeSource == "server", "TimeFormat.Configure received timeSource")
  end

  -- interfaceLanguage configures localization, persists, and refreshes the window.
  do
    local runtime, calls = makeRuntime()
    local configCalls = {}
    local refreshLanguageCalls = {}
    runtime.window.refreshLanguage = function(language)
      refreshLanguageCalls[#refreshLanguageCalls + 1] = language
    end
    local localization = {
      Configure = function(opts)
        configCalls[#configCalls + 1] = opts
      end,
    }
    local fonts, fontLog = makeFonts()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = accountSettings,
      localization = localization,
      fonts = fonts,
    })

    onChange("interfaceLanguage", "ruRU")

    assert(accountSettings.interfaceLanguage == "ruRU", "interfaceLanguage persists")
    assert(configCalls[1].language == "ruRU", "Localization.Configure received interfaceLanguage")
    -- Regression: Korean / Chinese require a CJK-capable font path. The
    -- handler must propagate the language to Fonts so the swap happens
    -- before the upcoming refresh paints text in the new locale.
    assert(
      fontLog[1] and fontLog[1][1] == "language" and fontLog[1][2] == "ruRU",
      "interfaceLanguage routes to Fonts.SetLanguage"
    )
    assert(calls.refreshWindow == 1, "interfaceLanguage refreshes the window once")
    -- Regression: the language must propagate as an argument so the
    -- General settings panel keeps the user's selection. Calling
    -- refreshLanguage with no argument resets GeneralSettings' internal
    -- interfaceLanguage to the "auto" default, which deselects the user's
    -- choice in the selector and rebuilds option labels via auto-detect.
    assert(#refreshLanguageCalls == 1, "refreshLanguage fired exactly once")
    assert(refreshLanguageCalls[1] == "ruRU", "refreshLanguage must receive the new language; got: " .. tostring(refreshLanguageCalls[1]))
  end

  -- hideFromDefaultChat triggers chat filter and reply-key sync.
  do
    local runtime, calls = makeRuntime()
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("hideFromDefaultChat", true)

    assert(accountSettings.hideFromDefaultChat == true, "setting persists")
    assert(calls.syncChatFilters == 1, "syncChatFilters fired")
    assert(calls.syncReplyKey == 1, "syncReplyKey fired")
  end

  -- messageMaxAge mirrors into store.config.conversationMaxAge.
  do
    local runtime = makeRuntime()
    runtime.store.config.messageMaxAge = 0
    runtime.store.config.conversationMaxAge = 0
    local accountSettings = {}
    local onChange = SettingsHandler.Create({ runtime = runtime, accountSettings = accountSettings })

    onChange("messageMaxAge", 3600)

    assert(accountSettings.messageMaxAge == 3600, "setting persists")
    assert(runtime.store.config.messageMaxAge == 3600, "store config receives the new max age")
    assert(runtime.store.config.conversationMaxAge == 3600, "conversationMaxAge mirrors messageMaxAge")
  end
end
