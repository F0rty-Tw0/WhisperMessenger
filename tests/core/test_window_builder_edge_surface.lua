-- WindowBuilder refreshes the edge surface whenever the window shows or hides,
-- so ESC and the game's close-all reach it too.
local FakeUI = require("tests.helpers.fake_ui")
local WindowBuilder = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowBuilder")

local function noop() end

local function build(getEdgeSurface)
  local factory = FakeUI.NewFactory()
  local runtime = { store = { config = {} }, panelRegistry = { bind = noop } }
  local window
  local options = {
    runtime = runtime,
    accountState = { settings = { compactLayout = false } },
    characterState = {},
    uiFactory = factory,
    positionSlots = {
      read = function()
        return {}
      end,
    },
    theme = {},
    fonts = {},
    surfaces = {
      getIcon = noop,
      getMinimap = noop,
      getWidgetIcon = noop,
      applyIconMode = noop,
      refreshTheme = noop,
      ensureDetachedPreview = noop,
      getEdgeSurface = getEdgeSurface,
    },
    coordinator = {
      buildSelectionState = function()
        return {}
      end,
      updateIconSurfaces = noop,
    },
    windowCallbacks = {},
    externalPreview = {},
    messengerWindow = {
      Create = function()
        local frame = factory.CreateFrame("Frame", nil, nil)
        frame:Show()
        window = { frame = frame }
        return window
      end,
    },
    buildContacts = function()
      return {}
    end,
    selectConversation = noop,
    isWindowVisible = function()
      return false
    end,
    acknowledgeLatestWidgetPreview = noop,
    onShareWidgetPositionChanged = noop,
    onSettingsHandler = noop,
    onWindowCreated = noop,
  }
  return WindowBuilder.Build(options)
end

return function()
  local function test_show_and_hide_each_refresh_the_edge_surface()
    local refreshes = 0
    local edge = {
      refresh = function()
        refreshes = refreshes + 1
      end,
    }
    local window = build(function()
      return edge
    end)
    refreshes = 0
    window.frame:Show()
    assert(refreshes == 1, "Show refreshes once, got " .. refreshes)
    window.frame:Hide()
    assert(refreshes == 2, "a direct Hide (the ESC path) refreshes once more, got " .. refreshes)
  end

  local function test_a_nil_surface_raises_nothing()
    local window = build(function()
      return nil
    end)
    window.frame:Show()
    window.frame:Hide()
  end

  test_show_and_hide_each_refresh_the_edge_surface()
  test_a_nil_surface_raises_nothing()
end
