local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local Preview = ns.PublicApiPreview or require("WhisperMessenger.Core.PublicApi.Preview")
local Panels = ns.PublicApiPanels or require("WhisperMessenger.Core.PublicApi.Panels")
local PublicContactInfo = ns.PublicApiContactInfo or require("WhisperMessenger.Core.PublicApi.ContactInfo")
local BlockList = ns.PublicApiBlockList or require("WhisperMessenger.Core.PublicApi.BlockList")
local UnreadCount = ns.PublicApiUnreadCount or require("WhisperMessenger.Core.PublicApi.UnreadCount")
local Look = ns.PublicApiLook or require("WhisperMessenger.Core.PublicApi.Look")
local Animation = ns.PublicApiAnimation or require("WhisperMessenger.Core.PublicApi.Animation")
local CompactWindow = ns.PublicApiCompactWindow or require("WhisperMessenger.Core.PublicApi.CompactWindow")
local InsertLink = ns.PublicApiInsertLink or require("WhisperMessenger.Core.PublicApi.InsertLink")
local Connect = ns.PublicApiConnect or require("WhisperMessenger.Core.PublicApi.Connect")
local IntegrationAccess = ns.BootstrapWindowRuntimeIntegrationAccess or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IntegrationAccess")
local AddonIntegrations = ns.AddonIntegrations or require("WhisperMessenger.Model.AddonIntegrations")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

local PublicApi = {}

local API_VERSION = 1

local function isValidDraft(draft)
  return draft == nil or (type(draft) == "string" and #draft <= TextLimits.MESSAGE_MAX_BYTES)
end

local function putDraftInComposer(runtime, draft)
  runtime.setComposerText(draft)
  local window = runtime.window
  local input = window and window.composer and window.composer.input
  if input and input.SetCursorPosition then
    input:SetCursorPosition(#draft)
  end
end

-- An addon panel covers the conversation; close it so the chat shows. Quiet:
-- the caller selects the chat it opens itself.
local function hideOpenPanel(runtime)
  local window = runtime.window
  if window and window.hidePanel then
    window.hidePanel(true)
  end
end

-- options.afterSend: the caller just sent this player a whisper, so the
-- window opens only as far as "Auto-open on outgoing whisper" allows. An
-- open window still moves to the chat.
local function blockedAfterSend(runtime, options)
  if options == nil or options.afterSend ~= true or runtime.isWindowVisible() then
    return false
  end
  local settings = runtime.accountState and runtime.accountState.settings
  return not (settings and settings.autoOpenOutgoing == true)
end

local function buildOpenConversation(runtime)
  return Guards.Wrap(function(playerName, draftText, options)
    if not Guards.IsNonEmptyString(playerName) or not isValidDraft(draftText) then
      return false
    end
    if options ~= nil and type(options) ~= "table" then
      return false
    end
    if Guards.IsRefused(runtime) or blockedAfterSend(runtime, options) then
      return false
    end

    local wasVisible = runtime.isWindowVisible()
    local hiddenByCombat = runtime.hiddenByCombat
    runtime.ensureWindow()
    runtime.setWindowVisible(true)
    hideOpenPanel(runtime)
    if not runtime.startConversation(playerName) then
      if not wasVisible then
        runtime.setWindowVisible(false)
        -- The open cleared the combat-hide mark; a failed open must not
        -- cancel the combat-end reopen.
        runtime.hiddenByCombat = hiddenByCombat
      end
      return false
    end

    if draftText ~= nil and draftText ~= "" then
      putDraftInComposer(runtime, draftText)
    end
    return true
  end)
end

-- Allow addon integration, read once at load: changing it reloads.
local function integrationAllowed(runtime)
  local settings = runtime.accountState and runtime.accountState.settings
  return settings == nil or settings.allowAddonIntegration ~= false
end

function PublicApi.Build(runtime)
  runtime.addonIntegrations = AddonIntegrations.New(runtime.accountState, FlavorCompat.GetAddOnTitle)
  runtime.integrationAllowedAtLoad = integrationAllowed(runtime)
  local api = {
    version = API_VERSION,
    OpenConversation = buildOpenConversation(runtime),
  }
  Preview.Install(api, runtime)
  Panels.Install(api, runtime)
  PublicContactInfo.Install(api, runtime)
  BlockList.Install(api, runtime)
  UnreadCount.Install(api, runtime)
  Look.Install(api, runtime)
  Animation.Install(api, runtime)
  CompactWindow.Install(api, runtime)
  InsertLink.Install(api, runtime)
  Connect.Install(api, runtime)
  if not runtime.integrationAllowedAtLoad then
    -- Same keys, so callers never nil-error; every call is refused. Connect
    -- still answers: its handles refuse, and the shared calls record nothing.
    for key, value in pairs(api) do
      if type(value) == "function" and key ~= "Connect" then
        api[key] = Connect.Refuse
      end
    end
    api.GetUnreadCount = Connect.RefuseCount
  end
  return api
end

function PublicApi.Publish(runtime)
  local api = PublicApi.Build(runtime)
  IntegrationAccess.Attach(runtime)
  _G.WhisperMessengerAPI = api
  return api
end

ns.PublicApi = PublicApi
return PublicApi
