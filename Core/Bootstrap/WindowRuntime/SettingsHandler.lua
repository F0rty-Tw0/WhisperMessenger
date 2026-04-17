local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsHandler = {}

function SettingsHandler.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountSettings = options.accountSettings or {}
  local theme = options.theme or {}
  local fonts = options.fonts or {}
  local timeFormat = options.timeFormat or {}
  local trace = options.trace or function(...)
    local _ = ...
  end
  local getIcon = options.getIcon or function()
    return nil
  end
  local buildContacts = options.buildContacts or function()
    return {}
  end
  local tableUtils = options.tableUtils or {}

  return function(key, value)
    local persistedValue = value
    local themeApplied = false

    if key == "themePreset" then
      local fallbackKey = theme.DEFAULT_PRESET or "wow_default"
      local presetKey = value or fallbackKey
      if theme.ResolvePreset then
        local resolvedKey, applied = theme.ResolvePreset(presetKey, trace)
        persistedValue = resolvedKey or presetKey
        themeApplied = applied == true
      else
        if theme.SetPreset then
          themeApplied = theme.SetPreset(presetKey) == true
        end
        if theme.GetPreset then
          persistedValue = theme.GetPreset() or presetKey
        else
          persistedValue = presetKey
        end
      end
    end

    accountSettings[key] = persistedValue

    if runtime.store.config[key] ~= nil then
      runtime.store.config[key] = persistedValue
    end
    if key == "messageMaxAge" then
      runtime.store.config.conversationMaxAge = persistedValue
    end

    trace("setting changed", key, tostring(persistedValue))

    if key == "fontFamily" and fonts.SetMode then
      fonts.SetMode(persistedValue or "default")
    end
    if key == "fontSize" and fonts.SetFontSize then
      fonts.SetFontSize(persistedValue or 12)
    end
    if key == "fontOutline" and fonts.SetOutline then
      fonts.SetOutline(persistedValue or "NONE")
    end
    if key == "fontColor" and fonts.SetFontColor then
      fonts.SetFontColor(persistedValue or "default")
    end
    if key == "bubbleColorPreset" and theme.SetBubblePreset then
      theme.SetBubblePreset(persistedValue or "default")
    end
    if (key == "timeFormat" or key == "timeSource") and timeFormat.Configure then
      timeFormat.Configure({ [key] = persistedValue })
    end
    if key == "hideFromDefaultChat" then
      if runtime.syncChatFilters then
        runtime.syncChatFilters()
      end
      if runtime.syncReplyKey then
        runtime.syncReplyKey()
      end
    end
    if
      (
        key == "hideMessagePreview"
        or key == "fontFamily"
        or key == "fontSize"
        or key == "fontOutline"
        or key == "fontColor"
        or key == "bubbleColorPreset"
        or key == "timeFormat"
        or key == "timeSource"
      ) and runtime.refreshWindow
    then
      runtime.refreshWindow()
    end

    if key == "themePreset" and themeApplied then
      if runtime.window and runtime.window.refreshTheme then
        runtime.window.refreshTheme()
      end
      local themeIcon = getIcon()
      if themeIcon and themeIcon.refreshTheme then
        themeIcon.refreshTheme()
      end
      if runtime.refreshWindow then
        runtime.refreshWindow()
      end
    end

    -- nativeChrome flips the messenger frame between BasicFrameTemplateWithInset
    -- and our custom chrome. Templates can't be added/removed at runtime in
    -- WoW, so we tell the user a /reload is required to apply.
    if key == "nativeChrome" and _G.print then
      _G.print("|cffffd100WhisperMessenger:|r Native WoW HUD change requires |cffffff00/reload|r to apply.")
    end

    local icon = getIcon()
    if (key == "showUnreadBadge" or key == "badgePulse") and icon and icon.setUnreadCount then
      local freshContacts = buildContacts()
      icon.setUnreadCount(tableUtils.sumBy(freshContacts, "unreadCount"))
    end

    if key == "iconSize" and icon and icon.applyIconSize then
      icon.applyIconSize(persistedValue)
    end

    if key == "iconDesaturated" and icon and icon.refreshDesaturation then
      icon.refreshDesaturation()
    end
  end
end

ns.BootstrapWindowRuntimeSettingsHandler = SettingsHandler

return SettingsHandler
