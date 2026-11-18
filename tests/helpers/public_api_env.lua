-- Boots a real runtime on the fake UI and publishes the public API on it.
-- UIParent stays swapped until Reset(): the messenger window reads it lazily.
local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local PublicApi = require("WhisperMessenger.Core.PublicApi")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")
local RestrictionState = require("tests.helpers.restriction_state")

local PublicApiEnv = {}

local saved = nil

function PublicApiEnv.Initialize(settings)
  local factory = FakeUI.NewFactory()
  if saved == nil then
    saved = { uiParent = _G.UIParent, suspended = RestrictionState.Suspended() }
  end
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(1920, 1080)
  uiParent:Show()
  _G.UIParent = uiParent
  RestrictionState.SetSuspended(false)
  SeenLevelEvents._reset()

  local ok, runtime = pcall(Bootstrap.Initialize, factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      settings = settings,
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560 },
      icon = {},
    },
  })
  assert(ok, runtime)
  return runtime, PublicApi.Publish(runtime), uiParent
end

function PublicApiEnv.Reset()
  _G.WhisperMessengerAPI = nil
  if saved ~= nil then
    _G.UIParent = saved.uiParent
    RestrictionState.SetSuspended(saved.suspended)
    saved = nil
  end
end

return PublicApiEnv
