-- The composer's reported bar height reaches the relayout controller.
local FakeUI = require("tests.helpers.fake_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
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

  -- test_two_rows_before_any_resize_grow_the_composer_pane
  do
    Fonts.Initialize("default")
    local factory = FakeUI.NewFactory({ wrap = true })
    local savedUIParent = _G.UIParent
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.UIParent:SetSize(1280, 720)
    local ok, err = pcall(function()
      local window = MessengerWindow.Create(factory, { contacts = {} })
      local input = window.composer.input
      input:SetText(("a"):rep(150))
      input.scripts.OnTextChanged(input, true)

      local barH = window.composer.getHeight()
      assert(barH > Theme.COMPOSER_HEIGHT, "expected two rows, got bar height " .. tostring(barH))
      assert(window.composerPane.height == barH, "expected composer height " .. barH .. ", got " .. tostring(window.composerPane.height))
      local expectedThreadH = (window.frame.height - Theme.TOP_BAR_HEIGHT) - barH - 1
      assert(
        window.threadPane.height == expectedThreadH,
        "expected thread height " .. expectedThreadH .. ", got " .. tostring(window.threadPane.height)
      )
    end)
    _G.UIParent = savedUIParent
    if not ok then
      error(err, 0)
    end
  end

  -- test_draft_at_build_grows_the_composer_pane
  do
    Fonts.Initialize("default")
    local factory = FakeUI.NewFactory({ wrap = true })
    local savedUIParent = _G.UIParent
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.UIParent:SetSize(1280, 720)
    local ok, err = pcall(function()
      local contact = { conversationKey = "me::WOW::bob-realm", displayName = "Bob", channel = "WOW" }
      local window = MessengerWindow.Create(factory, {
        contacts = { contact },
        selectedContact = contact,
        conversation = { messages = {} },
        getDraft = function()
          return ("a"):rep(150)
        end,
      })

      local barH = window.composer.getHeight()
      assert(barH > Theme.COMPOSER_HEIGHT, "expected two rows, got bar height " .. tostring(barH))
      assert(window.composerPane.height == barH, "expected composer height " .. barH .. ", got " .. tostring(window.composerPane.height))
    end)
    _G.UIParent = savedUIParent
    if not ok then
      error(err, 0)
    end
  end
end
