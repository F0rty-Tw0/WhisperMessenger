-- The composer's reported bar height reaches the relayout controller.
local FakeUI = require("tests.helpers.fake_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local ComposerRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ComposerRuntime")

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local composerPane = factory.CreateFrame("Frame", nil, frame)
  composerPane:SetSize(400, 80)
  return ComposerRuntime.Create(factory, {
    frame = frame,
    layout = { composerPane = composerPane },
    settingsConfig = {},
    windowOptions = {},
    conversation = { tag = "conversation" },
    messageActions = { bind = function() end },
    settingsRuntime = { setThemeTargets = function() end },
    closeWindow = function() end,
    refreshContacts = function() end,
  })
end

local function buildWindowAndRuntime()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local originalCreate = ComposerRuntime.Create
  local captured
  ComposerRuntime.Create = function(...)
    captured = originalCreate(...)
    return captured
  end
  local ok, result = pcall(function()
    local window = MessengerWindow.Create(factory, { contacts = {} })
    window.frame:SetSize(1100, 700)
    window.frame.scripts.OnSizeChanged(window.frame, 1100, 700)
    return window
  end)
  ComposerRuntime.Create = originalCreate
  _G.UIParent = savedUIParent
  if not ok then
    error(result, 0)
  end
  return result, captured
end

return function()
  -- test_height_reported_before_binding_is_dropped_quietly
  do
    local runtime = build()
    runtime.reportHeight(56)
  end

  -- test_bound_listener_gets_each_reported_height
  do
    local runtime = build()
    local seen = {}
    runtime.bindHeightChanged(function(height)
      seen[#seen + 1] = height
    end)
    runtime.reportHeight(56)
    runtime.reportHeight(68)
    assert(seen[1] == 56 and seen[2] == 68, "expected both heights forwarded in order")
  end

  -- test_window_binds_the_relayout_controller
  do
    local window, runtime = buildWindowAndRuntime()
    runtime.reportHeight(68)
    local expectedThreadH = (700 - Theme.TOP_BAR_HEIGHT) - 68 - 1
    assert(
      window.threadPane.height == expectedThreadH,
      "expected thread height " .. expectedThreadH .. ", got " .. tostring(window.threadPane.height)
    )
    assert(window.composerPane.height == 68, "expected composer height 68, got " .. tostring(window.composerPane.height))
  end
end
