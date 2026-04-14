local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then
      return loaded
    end
  end

  error(key .. " module not available")
end

if ns.Loader then
  loadModule = ns.Loader.LoadModule
elseif type(require) == "function" then
  local ok, Loader = pcall(require, "WhisperMessenger.Core.Loader")
  if ok and Loader then
    loadModule = Loader.LoadModule
  end
end

local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

if ns.trace then
  local loadedTrace = ns.trace
  trace = function(...)
    loadedTrace(...)
  end
elseif type(require) == "function" then
  local ok, loaded = pcall(require, "WhisperMessenger.Core.Trace")
  if ok and loaded then
    local loadedTrace = loaded
    trace = function(...)
      loadedTrace(...)
    end
  end
end

local Bootstrap = {}
ns.Bootstrap = Bootstrap

local MYTHIC_PAUSE_NOTICE =
  "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave."
function Bootstrap.Initialize(factory, options)
  options = options or {}
  trace("initialize start")

  local RuntimeFactory = loadModule("WhisperMessenger.Core.Bootstrap.RuntimeFactory", "BootstrapRuntimeFactory")
  loadModule("WhisperMessenger.Core.Bootstrap.EventBridge", "BootstrapEventBridge") -- registers on ns
  local RestrictedActions =
    loadModule("WhisperMessenger.Core.Bootstrap.RestrictedActions", "BootstrapRestrictedActions")
  local ChatFilters = loadModule("WhisperMessenger.Core.Bootstrap.ChatFilters", "BootstrapChatFilters")
  local ReplyKeyBinder = loadModule("WhisperMessenger.Core.Bootstrap.ReplyKeyBinder", "BootstrapReplyKeyBinder")
  local MythicSuspendController =
    loadModule("WhisperMessenger.Core.Bootstrap.MythicSuspendController", "BootstrapMythicSuspendController")
  local WindowRuntime = loadModule("WhisperMessenger.Core.Bootstrap.WindowRuntime", "BootstrapWindowRuntime")
  local AutoOpenCoordinator =
    loadModule("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator", "BootstrapAutoOpenCoordinator")
  local SavedState = loadModule("WhisperMessenger.Persistence.SavedState", "SavedState")
  local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
  local SlashCommands = loadModule("WhisperMessenger.Core.SlashCommands", "SlashCommands")
  local PresenceCache = loadModule("WhisperMessenger.Model.PresenceCache", "PresenceCache")
  local Diagnostics = loadModule("WhisperMessenger.Core.Bootstrap.Diagnostics", "BootstrapDiagnostics")

  local Fonts = loadModule("WhisperMessenger.UI.Theme.Fonts", "ThemeFonts")
  local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

  local uiFactory = factory or _G
  local localProfileId = RuntimeFactory.ResolveLocalProfileId(options)
  local accountState, characterState =
    SavedState.Initialize(options.accountState, options.characterState, localProfileId)
  local defaultCharacterState = Schema.NewCharacterState()
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)
  ns._channelMessageState = runtime.channelMessageStore
  runtime.messagingNotice = nil
  -- Initialize theme/font mode from saved settings
  accountState.settings = accountState.settings or {}
  if Fonts.Initialize then
    Fonts.Initialize(accountState.settings.fontFamily or "default")
  end
  if Fonts.SetFontSize then
    Fonts.SetFontSize(accountState.settings.fontSize or 12)
  end
  if Fonts.SetOutline then
    Fonts.SetOutline(accountState.settings.fontOutline or "NONE")
  end
  if Fonts.SetFontColor then
    Fonts.SetFontColor(accountState.settings.fontColor or "default")
  end
  local themePresetKey = accountState.settings.themePreset or (Theme.DEFAULT_PRESET or "wow_default")
  if Theme.ResolvePreset then
    local resolvedKey = Theme.ResolvePreset(themePresetKey, trace)
    themePresetKey = resolvedKey or themePresetKey
  elseif Theme.SetPreset then
    Theme.SetPreset(themePresetKey)
    if Theme.GetPreset then
      themePresetKey = Theme.GetPreset() or themePresetKey
    end
  end
  accountState.settings.themePreset = themePresetKey
  if Theme.SetBubblePreset then
    Theme.SetBubblePreset(accountState.settings.bubbleColorPreset or "default")
  end
  -- Initialize time format/source from saved settings
  local TimeFormat = loadModule("WhisperMessenger.Util.TimeFormat", "TimeFormat")
  if TimeFormat.Configure then
    TimeFormat.Configure({
      timeFormat = accountState.settings.timeFormat or "12h",
      timeSource = accountState.settings.timeSource or "local",
    })
  end
  -- Initialize guild/community presence cache
  local presenceTTL = (accountState.settings and accountState.settings.presenceRefreshInterval) or 30
  PresenceCache.Initialize(options.clubApi or _G["C_Club"], {
    ttl = presenceTTL,
    now = options.now,
  })

  local windowRuntime = WindowRuntime.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    defaultCharacterState = defaultCharacterState,
    uiFactory = uiFactory,
    uiParent = _G.UIParent,
    bootstrap = Bootstrap,
    trace = trace,
  })

  -- 12.0+ authoritative restriction cache, populated from
  -- ADDON_RESTRICTION_STATE_CHANGED payload. On pre-12.0 clients the
  -- instance exists but never receives events — isCompetitive falls back
  -- to the legacy flag model below.
  runtime.restrictedActions = RestrictedActions.New()

  runtime.isCompetitiveContent = function()
    if runtime.restrictedActions and runtime.restrictedActions.isCompetitive() then
      return true
    end
    return Bootstrap._inCompetitiveContent == true or Bootstrap._inEncounter == true
  end

  runtime.isMythicLockdown = function()
    if runtime.restrictedActions and runtime.restrictedActions.isMythic() then
      return true
    end
    return Bootstrap._inMythicContent == true
  end

  Bootstrap.onCompetitiveStateChanged = function(isActive)
    local ic = windowRuntime.getIcon()
    if ic and ic.setCompetitiveContent then
      ic.setCompetitiveContent(isActive)
    end
  end

  local diagnostics = Diagnostics.Create({
    addonName = addonName,
    runtime = runtime,
    trace = trace,
    presenceCache = PresenceCache,
    getWindow = windowRuntime.getWindow,
    isWindowVisible = windowRuntime.isWindowVisible,
  })
  windowRuntime.setDiagnostics(diagnostics)

  AutoOpenCoordinator.Attach({
    trace = trace,
    runtime = runtime,
    accountState = accountState,
    windowRuntime = windowRuntime,
  })

  -- Suppress whisper messages from the default chat frame (and their sound).
  -- Our addon provides its own messenger UI for whispers.
  -- We must preserve /r reply targets since the default handler won't run.
  -- Setting hideFromDefaultChat = false lets whispers appear in both places.
  --
  -- IMPORTANT: Any addon code running inside a ChatFrame filter taints
  -- Blizzard's chat processing context. Filters are only registered when
  -- they should suppress (hideFromDefaultChat=true, not in competitive
  -- content or mythic). syncChatFilters manages this dynamically.
  ChatFilters.Configure(Bootstrap, accountState)
  Bootstrap.syncChatFilters()

  runtime.syncChatFilters = Bootstrap.syncChatFilters

  -- Option B: when hideFromDefaultChat is on, override R to fire /wr
  -- through a SecureActionButton so Blizzard's tainted ReplyTell never runs.
  local replyKeyBinder = ReplyKeyBinder.New({
    getSettings = function()
      return accountState.settings
    end,
    isMythic = function()
      return runtime.isMythicLockdown and runtime.isMythicLockdown() or false
    end,
  })
  runtime.syncReplyKey = replyKeyBinder.sync
  replyKeyBinder.sync()

  SlashCommands.Register({
    toggle = runtime.toggle,
    memoryReport = diagnostics.memoryReport,
    replyToLast = function()
      -- Taint-safe /r replacement. Routes through our own messenger instead
      -- of Blizzard's chatEditLastTell.
      --
      -- Priority:
      --   1. Live lastIncomingWhisperKey via onReplyTell (composer focus).
      --   2. Most-recent conversation from our store (post-M+ resume,
      --      fresh session, whispers received before addon loaded).
      --   3. Fallback: toggle the messenger open so something happens.
      --
      -- In competitive content we skip onReplyTell (it bails for focus-
      -- steal avoidance) and open+select directly so the user at least
      -- sees the conversation context; composer stays disabled via the
      -- mythic-pause notice.
      local hooks = runtime.autoOpenHooks
      if hooks and hooks.onReplyTell and hooks.onReplyTell() == true then
        return
      end

      local key = runtime.lastIncomingWhisperKey
      if not key and runtime.store and runtime.store.conversations then
        local latest = -1
        for k, conv in pairs(runtime.store.conversations) do
          local activity = conv and conv.lastActivityAt or 0
          if activity > latest then
            latest = activity
            key = k
          end
        end
      end

      if key and runtime.ensureWindow and runtime.setWindowVisible then
        runtime.ensureWindow()
        runtime.setWindowVisible(true)
        if windowRuntime.selectConversation then
          windowRuntime.selectConversation(key)
        end
        return
      end

      if runtime.toggle then
        runtime.toggle()
      end
      if type(_G.print) == "function" and not key then
        _G.print("|cff888888[WhisperMessenger]|r No conversations yet — opened the messenger.")
      end
    end,
  })

  trace("initialize complete")

  MythicSuspendController.Attach(runtime, {
    Bootstrap = Bootstrap,
    mythicPauseNotice = MYTHIC_PAUSE_NOTICE,
    isWindowVisible = windowRuntime.isWindowVisible,
    setWindowVisible = runtime.setWindowVisible,
    refreshWindow = runtime.refreshWindow,
  })

  return runtime
end

local function initializeRuntime()
  if Bootstrap.runtime ~= nil then
    trace("runtime already initialized")
    return Bootstrap.runtime
  end

  trace("runtime initialize")
  Bootstrap.runtime = Bootstrap.Initialize(_G, {
    accountState = _G.WhisperMessengerDB,
    characterState = _G.WhisperMessengerCharacterDB,
  })
  _G.WhisperMessengerDB = Bootstrap.runtime.accountState
  _G.WhisperMessengerCharacterDB = Bootstrap.runtime.characterState

  return Bootstrap.runtime
end

if type(_G.CreateFrame) == "function" then
  local AddonEventFrame = loadModule("WhisperMessenger.Core.Bootstrap.AddonEventFrame", "BootstrapAddonEventFrame")
  AddonEventFrame.Install({
    addonName = addonName,
    Bootstrap = Bootstrap,
    initializeRuntime = initializeRuntime,
    loadModule = loadModule,
    trace = trace,
  })
end

return Bootstrap
