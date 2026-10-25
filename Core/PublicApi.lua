local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = ns.PublicApiGuards or require("WhisperMessenger.Core.PublicApi.Guards")
local Preview = ns.PublicApiPreview or require("WhisperMessenger.Core.PublicApi.Preview")
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

function PublicApi.Build(runtime)
  local api = {
    version = API_VERSION,
    OpenConversation = buildOpenConversation(runtime),
  }
  Preview.Install(api, runtime)
  return api
end

function PublicApi.Publish(runtime)
  local api = PublicApi.Build(runtime)
  _G.WhisperMessengerAPI = api
  return api
end

ns.PublicApi = PublicApi
return PublicApi
