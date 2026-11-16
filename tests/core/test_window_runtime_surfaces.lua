-- Surfaces owns the widget icon, the minimap button with its data broker
-- object, the detached preview and the addon compartment entry: which of them
-- exist, which one a caller gets in each icon mode, and their theme repaint.

local FakeUI = require("tests.helpers.fake_ui")
local PanelRegistry = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local PositionSlots = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")
local Surfaces = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.Surfaces")
local TableUtils = require("WhisperMessenger.Util.TableUtils")

local function noop() end

local function fakeToggleIcon(calls)
  return {
    Create = function(_uiFactory, iconOptions)
      calls.iconCreates = calls.iconCreates + 1
      calls.iconOptions = iconOptions
      return {
        frame = { SetPoint = noop, Show = noop, Hide = noop },
        setUnreadCount = noop,
        setIncomingPreview = noop,
        refreshTheme = function()
          calls.iconTheme = calls.iconTheme + 1
        end,
      }
    end,
  }
end

local function fakeMinimapIconRuntime(calls)
  return {
    Create = function(minimapOptions)
      calls.minimapCreates = calls.minimapCreates + 1
      calls.minimapOptions = minimapOptions
      return {
        minimapIcon = {
          setShown = noop,
          refreshTheme = function()
            calls.minimapTheme = calls.minimapTheme + 1
          end,
        },
        getLdbObject = function()
          return calls.ldbObject
        end,
      }
    end,
  }
end

local function fakeUiParent(factory)
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:Show()
  uiParent.GetCenter = function()
    return 500, 400
  end
  uiParent.GetTop = function()
    return 800
  end
  return uiParent
end

-- Surfaces as Create returns them: no handlers bound yet.
local function buildUnbound(settings)
  local calls = { iconCreates = 0, minimapCreates = 0, iconTheme = 0, minimapTheme = 0, detachedTheme = 0, ldbObject = {} }
  local factory = FakeUI.NewFactory()
  local accountState = { settings = settings }
  local characterState = { window = {}, icon = {} }
  local runtime = { accountState = accountState, panelRegistry = PanelRegistry.New(), store = { conversations = {}, config = {} } }
  local surfaces = Surfaces.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    uiFactory = factory,
    uiParent = fakeUiParent(factory),
    tableUtils = TableUtils,
    positionSlots = PositionSlots.Create({ accountState = accountState, characterState = characterState, tableUtils = TableUtils }),
    toggleIcon = fakeToggleIcon(calls),
    minimapIconRuntime = fakeMinimapIconRuntime(calls),
    buildContacts = function()
      return {}
    end,
    buildLatestIncomingPreview = noop,
  })
  return surfaces, calls, runtime
end

local function build(settings)
  local surfaces, calls, runtime = buildUnbound(settings)
  local handlers = {
    onToggle = noop,
    onOpenPreview = noop,
    onMarkAllRead = noop,
    quickReply = {},
    acknowledgeLatestWidgetPreview = noop,
    refreshWindow = noop,
  }
  surfaces.setHandlers(handlers)
  return surfaces, calls, settings, handlers, runtime
end

-- Retail's addon compartment for the length of fn; returns the entries it got.
local function withCompartment(fn)
  local frame = { entries = {} }
  function frame:RegisterAddon(data)
    self.entries[#self.entries + 1] = data
  end
  local saved = rawget(_G, "AddonCompartmentFrame")
  rawset(_G, "AddonCompartmentFrame", frame)
  local ok, err = pcall(fn)
  rawset(_G, "AddonCompartmentFrame", saved)
  assert(ok, err)
  return frame.entries
end

local function switchMode(surfaces, settings, mode)
  settings.iconMode = mode
  surfaces.applyIconMode()
end

local function countDetachedRepaints(surfaces, calls)
  local detached = surfaces.ensureDetachedPreview()
  local repaint = detached.refreshTheme
  detached.refreshTheme = function()
    calls.detachedTheme = calls.detachedTheme + 1
    return repaint()
  end
end

return function()
  local function test_widget_icon_is_nil_in_minimap_mode()
    local surfaces, _, settings = build({ iconMode = "widget" })
    surfaces.applyIconMode()
    assert(surfaces.getWidgetIcon() ~= nil, "widget mode hands out the widget icon")

    switchMode(surfaces, settings, "minimap")
    assert(surfaces.getIcon() ~= nil, "the hidden widget icon still exists")
    assert(surfaces.getWidgetIcon() == nil, "minimap mode hands out no widget icon")
    switchMode(surfaces, settings, "none")
    assert(surfaces.getWidgetIcon() == nil, "none mode hands out no widget icon")
  end

  local function test_minimap_icon_is_nil_in_widget_mode()
    local surfaces, _, settings = build({ iconMode = "widget" })
    surfaces.applyIconMode()
    assert(surfaces.getMinimap() ~= nil, "widget mode still builds the hidden minimap button")
    assert(surfaces.getMinimapIcon() == nil, "widget mode hands out no minimap icon")

    switchMode(surfaces, settings, "minimap")
    assert(surfaces.getMinimapIcon() == surfaces.getMinimap(), "minimap mode hands out the minimap button")
    switchMode(surfaces, settings, "none")
    assert(surfaces.getMinimapIcon() == nil, "none mode hands out no minimap icon")
  end

  local function test_ldb_object_is_nil_when_icons_are_off()
    local surfaces, calls, settings = build({ iconMode = "none" })
    surfaces.applyIconMode()
    assert(surfaces.getLdbObject() == nil, "nothing is registered while icons were never on")

    switchMode(surfaces, settings, "widget")
    assert(surfaces.getLdbObject() == calls.ldbObject, "an icon mode hands out the data broker object")
    switchMode(surfaces, settings, "none")
    assert(surfaces.getLdbObject() == nil, "icons off hides the data broker object")
  end

  local function test_refresh_theme_reaches_icon_minimap_and_detached_preview()
    local surfaces, calls = build({ iconMode = "both", widgetPreviewPosition = "detached" })
    surfaces.applyIconMode()
    countDetachedRepaints(surfaces, calls)

    surfaces.refreshTheme()

    assert(calls.iconTheme == 1, "the widget icon repaints once, got " .. calls.iconTheme)
    assert(calls.minimapTheme == 1, "the minimap button repaints once, got " .. calls.minimapTheme)
    assert(calls.detachedTheme == 1, "the detached preview repaints once, got " .. calls.detachedTheme)
  end

  -- A hidden surface comes back with the theme chosen while it was away.
  local function test_refresh_theme_reaches_hidden_surfaces()
    local surfaces, calls, settings = build({ iconMode = "both" })
    surfaces.applyIconMode()
    switchMode(surfaces, settings, "none")

    surfaces.refreshTheme()

    assert(calls.iconTheme == 1, "the hidden widget icon repaints, got " .. calls.iconTheme)
    assert(calls.minimapTheme == 1, "the hidden minimap button repaints, got " .. calls.minimapTheme)
  end

  local function test_refresh_theme_skips_surfaces_never_created()
    local surfaces, calls = build({ iconMode = "none" })
    surfaces.applyIconMode()

    surfaces.refreshTheme()

    assert(calls.iconTheme + calls.minimapTheme == 0, "nothing exists to repaint")
    assert(surfaces.getDetachedPreview() == nil, "a repaint creates no detached preview")
  end

  local function test_switching_icon_mode_creates_the_missing_surface_once()
    local surfaces, calls, settings = build({ iconMode = "none" })
    surfaces.applyIconMode()
    assert(calls.iconCreates == 0 and calls.minimapCreates == 0, "none mode creates no icon surface")

    switchMode(surfaces, settings, "minimap")
    assert(calls.iconCreates == 0, "minimap mode leaves the widget icon unbuilt")
    assert(calls.minimapCreates == 1, "minimap mode builds the minimap button")

    for _, mode in ipairs({ "widget", "both", "none", "widget", "minimap" }) do
      switchMode(surfaces, settings, mode)
    end
    assert(calls.iconCreates == 1, "the widget icon is built once, got " .. calls.iconCreates)
    assert(calls.minimapCreates == 1, "the minimap button is built once, got " .. calls.minimapCreates)
  end

  local function test_detached_preview_is_created_once()
    local surfaces = build({ iconMode = "widget", widgetPreviewPosition = "detached" })
    assert(surfaces.isPreviewDetached() == true, "the setting says detached")
    assert(surfaces.getDetachedPreview() == nil, "nothing is built before it is asked for")

    local first = surfaces.ensureDetachedPreview()
    assert(first ~= nil and surfaces.ensureDetachedPreview() == first, "a second ask returns the same surface")
    assert(surfaces.getDetachedPreview() == first, "the getter returns it")
  end

  local function test_compartment_entry_is_created_once()
    local surfaces = build({ iconMode = "widget" })
    local first, second

    local entries = withCompartment(function()
      first = surfaces.createCompartment()
      second = surfaces.createCompartment()
    end)

    assert(#entries == 1, "the compartment gets one entry, got " .. #entries)
    assert(first ~= nil and second == first, "a second ask returns the same entry")
    assert(surfaces.getCompartment() == first, "the getter returns it")
  end

  -- A surface built with no handlers would toggle and reply into nothing.
  local function test_building_a_surface_before_set_handlers_raises()
    local builders = { "applyIconMode", "ensureDetachedPreview", "createCompartment" }
    withCompartment(function()
      for _, name in ipairs(builders) do
        local surfaces, calls = buildUnbound({ iconMode = "both", widgetPreviewPosition = "detached" })
        assert(pcall(surfaces[name]) == false, name .. " raises before setHandlers")
        assert(calls.iconCreates + calls.minimapCreates == 0, name .. " builds no icon surface")
        assert(surfaces.getDetachedPreview() == nil and surfaces.getCompartment() == nil, name .. " keeps no surface")
      end
    end)
  end

  local function test_handlers_reach_both_icon_surfaces()
    local surfaces, calls, _, handlers = build({ iconMode = "both" })
    surfaces.applyIconMode()

    assert(calls.iconOptions.onToggle == handlers.onToggle, "the widget icon toggles through the handler")
    assert(calls.iconOptions.quickReply == handlers.quickReply, "the widget icon gets the quick reply")
    assert(calls.minimapOptions.onToggle == handlers.onToggle, "the minimap button toggles through the handler")
    assert(calls.minimapOptions.onMarkAllRead == handlers.onMarkAllRead, "the minimap button marks all read through the handler")
    assert(calls.minimapOptions.refreshWindow == handlers.refreshWindow, "the minimap button refreshes through the handler")
  end

  local function test_the_created_icon_is_published_on_the_runtime()
    local surfaces, _, _, _, runtime = build({ iconMode = "widget" })
    assert(runtime.icon == nil, "no icon before the mode is applied")

    surfaces.applyIconMode()

    assert(runtime.icon ~= nil and runtime.icon == surfaces.getIcon(), "runtime.icon is the widget icon")
  end

  test_widget_icon_is_nil_in_minimap_mode()
  test_minimap_icon_is_nil_in_widget_mode()
  test_ldb_object_is_nil_when_icons_are_off()
  test_refresh_theme_reaches_icon_minimap_and_detached_preview()
  test_refresh_theme_reaches_hidden_surfaces()
  test_refresh_theme_skips_surfaces_never_created()
  test_switching_icon_mode_creates_the_missing_surface_once()
  test_detached_preview_is_created_once()
  test_compartment_entry_is_created_once()
  test_building_a_surface_before_set_handlers_raises()
  test_handlers_reach_both_icon_surfaces()
  test_the_created_icon_is_published_on_the_runtime()
end
