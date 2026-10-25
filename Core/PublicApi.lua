local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local Preview = ns.PublicApiPreview or require("WhisperMessenger.Core.PublicApi.Preview")
local Panels = ns.PublicApiPanels or require("WhisperMessenger.Core.PublicApi.Panels")
local PublicContactInfo = ns.PublicApiContactInfo or require("WhisperMessenger.Core.PublicApi.ContactInfo")
local BlockList = ns.PublicApiBlockList or require("WhisperMessenger.Core.PublicApi.BlockList")
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

local function buildOpenConversation(runtime)
  return Guards.Wrap(function(playerName, draftText)
    if not Guards.IsNonEmptyString(playerName) or not isValidDraft(draftText) then
      return false
    end
    if Guards.IsRefused(runtime) then
      return false
    end

    local wasVisible = runtime.isWindowVisible()
    runtime.ensureWindow()
    runtime.setWindowVisible(true)
    hideOpenPanel(runtime)
    if not runtime.startConversation(playerName) then
      if not wasVisible then
        runtime.setWindowVisible(false)
      end
      return false
    end

    if draftText ~= nil and draftText ~= "" then
      putDraftInComposer(runtime, draftText)
    end
    return true
  end)
end

local function refuse()
  return false
end

-- Allow addon integration, read once at load: changing it reloads.
local function integrationAllowed(runtime)
  local settings = runtime.accountState and runtime.accountState.settings
  return settings == nil or settings.allowAddonIntegration ~= false
end

function PublicApi.Build(runtime)
  local api = {
    version = API_VERSION,
    OpenConversation = buildOpenConversation(runtime),
  }
  Preview.Install(api, runtime)
  Panels.Install(api, runtime)
  PublicContactInfo.Install(api, runtime)
  BlockList.Install(api, runtime)
  if not integrationAllowed(runtime) then
    -- Same keys, so callers never nil-error; every call is refused.
    for key, value in pairs(api) do
      if type(value) == "function" then
        api[key] = refuse
      end
    end
  end
  return api
end

function PublicApi.Publish(runtime)
  local api = PublicApi.Build(runtime)
  _G.WhisperMessengerAPI = api
  return api
end

ns.PublicApi = PublicApi
return PublicApi
