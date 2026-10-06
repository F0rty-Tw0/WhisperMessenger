local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local Bootstrap = {}
ns.Bootstrap = Bootstrap

function Bootstrap.Initialize(factory, options)
  options = options or {}

  local RuntimeFactory = loadModule("WhisperMessenger.Core.Bootstrap.RuntimeFactory", "BootstrapRuntimeFactory")
  loadModule("WhisperMessenger.Core.Bootstrap.EventBridge", "BootstrapEventBridge") -- registers on ns
  local RestrictedActions = loadModule("WhisperMessenger.Core.Bootstrap.RestrictedActions", "BootstrapRestrictedActions")
  local ChatFilters = loadModule("WhisperMessenger.Core.Bootstrap.ChatFilters", "BootstrapChatFilters")
  local ReplyKeyBinder = loadModule("WhisperMessenger.Core.Bootstrap.ReplyKeyBinder", "BootstrapReplyKeyBinder")
  local MythicSuspendController = loadModule("WhisperMessenger.Core.Bootstrap.MythicSuspendController", "BootstrapMythicSuspendController")
  local WindowRuntime = loadModule("WhisperMessenger.Core.Bootstrap.WindowRuntime", "BootstrapWindowRuntime")
  local AutoOpenCoordinator = loadModule("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator", "BootstrapAutoOpenCoordinator")
  local FirstRunTip = loadModule("WhisperMessenger.Core.Bootstrap.FirstRunTip", "BootstrapFirstRunTip")
  local SavedState = loadModule("WhisperMessenger.Persistence.SavedState", "SavedState")
  local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
  local SlashCommands = loadModule("WhisperMessenger.Core.SlashCommands", "SlashCommands")
  local PresenceCache = loadModule("WhisperMessenger.Model.PresenceCache", "PresenceCache")
  local ReplyToLast = loadModule("WhisperMessenger.Core.SlashCommands.ReplyToLast", "SlashCommandsReplyToLast")
  local PerfCounters = loadModule("WhisperMessenger.Util.PerfCounters", "PerfCounters")
  local ChatPrint = loadModule("WhisperMessenger.Util.ChatPrint", "ChatPrint")

  local Fonts = loadModule("WhisperMessenger.UI.Theme.Fonts", "ThemeFonts")
  local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
  local Hud = loadModule("WhisperMessenger.UI.Theme.Hud", "Hud")
  local WindowScale = loadModule("WhisperMessenger.UI.MessengerWindow.WindowScale", "MessengerWindowWindowScale")

  local uiFactory = factory or _G
  local localProfileId = RuntimeFactory.ResolveLocalProfileId(options)
  local accountState, characterState = SavedState.Initialize(options.accountState, options.characterState, localProfileId)
  local freshInstall = FirstRunTip.IsFreshInstall(accountState)
  accountState.settings = accountState.settings or {}
  accountState.settings.windowScale = WindowScale.Normalize(accountState.settings.windowScale)
  local defaultCharacterState = Schema.NewCharacterState()
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)
  ns._channelMessageState = runtime.channelMessageStore
  runtime.messagingNotice = nil

  -- Record the current character's class tag under their profileId so
  -- group-chat rows originating from any character on this account can
  -- be tinted with the owner's class color (even after switching alts).
  if type(localProfileId) == "string" and localProfileId ~= "" and type(_G.UnitClass) == "function" then
    local ok, _, classTag = pcall(_G.UnitClass, "player")
    if ok and type(classTag) == "string" and classTag ~= "" then
      accountState.playerClasses = accountState.playerClasses or {}
      accountState.playerClasses[localProfileId] = classTag
    end
  end
  -- Initialize theme/font mode from saved settings
  -- Group-chat visibility toggle. First-run default is ON. We seed the
  -- value explicitly so SavedVariables always serializes the current
  -- choice (absence-treated-as-true is fragile if SavedVariables
  -- compaction ever drops nil-equivalent fields).
  if accountState.settings.showGroupChats == nil then
    accountState.settings.showGroupChats = true
  end
  -- Brand-new installs start on the default HUD and theme (Modern with
  -- Azeroth on Retail and Forever) with whispers hidden from default chat.
  -- Upgraders keep what they had.
  if freshInstall then
    accountState.settings.hideFromDefaultChat = true
    accountState.settings.hudStyle = Hud.DefaultStyle()
    accountState.settings.themePreset = Hud.DefaultPreset()
  end
  -- hudStyle replaces the old nativeChrome flag, which stays saved for
  -- older addon versions after a downgrade.
  if accountState.settings.hudStyle == nil then
    accountState.settings.hudStyle = accountState.settings.nativeChrome == true and "classic" or "off"
  end
  Hud.Configure(accountState.settings.hudStyle)
  FirstRunTip.Announce(accountState)
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
    local resolvedKey = Theme.ResolvePreset(themePresetKey)
    themePresetKey = resolvedKey or themePresetKey
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
  local Localization = loadModule("WhisperMessenger.Locale.Localization", "Localization")
  if Localization.Configure then
    Localization.Configure({
      language = accountState.settings.interfaceLanguage or "auto",
    })
  end
  if Fonts.SetLanguage then
    Fonts.SetLanguage(accountState.settings.interfaceLanguage or "auto")
  end
  local DisplayName = loadModule("WhisperMessenger.Util.DisplayName", "DisplayName")
  DisplayName.Configure({
    hideBattleTagNumbers = accountState.settings.hideBattleTagNumbers ~= false,
    classColorSenderNames = accountState.settings.classColorSenderNames == true,
  })
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
  })
  -- Building the contact list fills DisplayName's BattleTag clash set, so
  -- chat alerts before the first window or icon refresh name the right friend.
  if windowRuntime.buildContacts then
    windowRuntime.buildContacts()
  end

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

  -- Channel chats pause wherever chat may carry secret values.
  runtime.isChannelIngestSuspended = function()
    if runtime.isMythicLockdown() or runtime.isCompetitiveContent() then
      return true
    end
    local chatInfo = _G.C_ChatInfo
    if type(chatInfo) ~= "table" or type(chatInfo.InChatMessagingLockdown) ~= "function" then
      return false
    end
    local ok, locked = pcall(chatInfo.InChatMessagingLockdown)
    return ok and locked == true
  end

  Bootstrap.onCompetitiveStateChanged = function(isActive)
    local ic = windowRuntime.getIcon()
    if ic and ic.setCompetitiveContent then
      ic.setCompetitiveContent(isActive)
    end
  end

  AutoOpenCoordinator.Attach({
    runtime = runtime,
    accountState = accountState,
    windowRuntime = windowRuntime,
  })

  -- Register addon-message prefixes before live events begin routing.
  local AddonComm = loadModule("WhisperMessenger.Transport.AddonComm", "AddonComm")
  AddonComm.RegisterPrefix(_G.C_ChatInfo, AddonComm.PREFIX_QUEST_LINK)
  AddonComm.RegisterPrefix(_G.C_ChatInfo, AddonComm.PREFIX_REACTION)
  -- Suppress whisper messages from the default chat frame (and their sound).
  -- Our addon provides its own messenger UI for whispers.
  -- We must preserve /r reply targets since the default handler won't run.
  -- Setting hideFromDefaultChat = false lets whispers appear in both places.
  --
  -- IMPORTANT: Any addon code running inside a ChatFrame filter taints
  -- Blizzard's chat processing context. Filters are only registered when
  -- they should suppress (hideFromDefaultChat=true, not in competitive
  -- content or mythic). syncChatFilters manages this dynamically.
  ChatFilters.Configure(Bootstrap, accountState, runtime)
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
    replyToLast = ReplyToLast.Create({ runtime = runtime, windowRuntime = windowRuntime }),
    perf = function()
      for _, line in ipairs(PerfCounters.Lines(addonName)) do
        ChatPrint.Print(line)
      end
    end,
  })

  MythicSuspendController.Attach(runtime, {
    Bootstrap = Bootstrap,
    isWindowVisible = windowRuntime.isWindowVisible,
    setWindowVisible = runtime.setWindowVisible,
    refreshWindow = runtime.refreshWindow,
  })

  return runtime
end

local function initializeRuntime()
  if Bootstrap.runtime ~= nil then
    return Bootstrap.runtime
  end

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
  })
end

return Bootstrap
