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
  trace = ns.trace
elseif type(require) == "function" then
  local ok, loaded = pcall(require, "WhisperMessenger.Core.Trace")
  if ok and loaded then
    trace = loaded
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
  local ChatFilters = loadModule("WhisperMessenger.Core.Bootstrap.ChatFilters", "BootstrapChatFilters")
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

  local uiFactory = factory or _G
  local localProfileId = RuntimeFactory.ResolveLocalProfileId(options)
  local accountState, characterState =
    SavedState.Initialize(options.accountState, options.characterState, localProfileId)
  local defaultCharacterState = Schema.NewCharacterState()
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)
  runtime.messagingNotice = nil
  -- Initialize font mode from saved settings
  accountState.settings = accountState.settings or {}
  if Fonts.Initialize then
    Fonts.Initialize(accountState.settings.fontFamily or "default")
  end
  -- Initialize guild/community presence cache
  local presenceTTL = (accountState.settings and accountState.settings.presenceRefreshInterval) or 30
  PresenceCache.Initialize(options.clubApi or _G.C_Club, {
    ttl = presenceTTL,
    now = options.now or function()
      return type(_G.time) == "function" and _G.time() or 0
    end,
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
  -- Blizzard's chat processing context. During mythic content this breaks
  -- /r, /w, and community whispers. We remove the filters entirely on
  -- mythic enter and re-register them on mythic leave.
  ChatFilters.Configure(Bootstrap, accountState)
  if not Bootstrap._inMythicContent then
    Bootstrap.registerChatFilters()
  end

  SlashCommands.Register({
    toggle = runtime.toggle,
    memoryReport = diagnostics.memoryReport,
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
