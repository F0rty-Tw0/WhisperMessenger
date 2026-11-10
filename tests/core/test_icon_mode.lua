local IconMode = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconMode")

-- Oracle: the icon-mode branches of the old WindowRuntime.applyIconMode.
-- widget/both show the widget; minimap/both show the minimap button; none
-- creates neither; an unknown or missing mode is "widget".

local function makeIcon(calls)
  return {
    frame = {
      Show = function()
        calls.shown[#calls.shown + 1] = "widget"
      end,
      Hide = function()
        calls.hidden = calls.hidden + 1
      end,
    },
    setIncomingPreview = function(...)
      calls.preview[#calls.preview + 1] = { ... }
    end,
  }
end

local function makeMinimap(calls)
  return {
    setShown = function(shown)
      calls.shown[#calls.shown + 1] = shown and "minimap-on" or "minimap-off"
    end,
  }
end

-- Both surfaces already exist, as after an earlier mode was applied.
local function build()
  local calls = { ensureIcon = 0, ensureMinimap = 0, shown = {}, hidden = 0, preview = {} }
  local icon = makeIcon(calls)
  local minimap = makeMinimap(calls)
  local deps = {
    ensureIcon = function()
      calls.ensureIcon = calls.ensureIcon + 1
    end,
    ensureMinimap = function()
      calls.ensureMinimap = calls.ensureMinimap + 1
    end,
    getIcon = function()
      return icon
    end,
    getMinimap = function()
      return minimap
    end,
  }
  return deps, calls
end

local function test_resolve_defaults_when_icon_mode_is_missing()
  assert(IconMode.Resolve({}) == "widget", "no setting is the widget")
  assert(IconMode.Resolve(nil) == "widget", "no settings table is the widget")
  assert(IconMode.Resolve({ iconMode = "banana" }) == "widget", "an unknown mode is the widget")
end

local function test_resolve_keeps_the_known_modes()
  for _, mode in ipairs({ "widget", "minimap", "both", "none" }) do
    assert(IconMode.Resolve({ iconMode = mode }) == mode, mode .. " is kept")
  end
end

local function test_apply_shows_only_the_minimap_in_minimap_mode()
  local deps, calls = build()

  IconMode.Apply("minimap", deps)

  assert(calls.ensureIcon == 0, "minimap mode must not create the widget")
  assert(calls.ensureMinimap == 1, "minimap mode creates the minimap button")
  assert(calls.hidden == 1, "an existing widget is hidden")
  local preview = calls.preview[1]
  assert(#calls.preview == 1 and preview[1] == nil and preview[2] == nil and preview[3] == nil, "the hidden widget drops its incoming preview")
  assert(calls.shown[1] == "minimap-on", "the minimap button is shown")
end

local function test_apply_shows_both_surfaces_in_both_mode()
  local deps, calls = build()

  IconMode.Apply("both", deps)

  assert(calls.ensureIcon == 1 and calls.ensureMinimap == 1, "both modes create both surfaces")
  assert(calls.hidden == 0, "the widget stays")
  assert(calls.shown[1] == "widget" and calls.shown[2] == "minimap-on", "both are shown")
end

local function test_apply_creates_nothing_in_none_mode()
  local deps, calls = build()

  IconMode.Apply("none", deps)

  assert(calls.ensureIcon == 0 and calls.ensureMinimap == 0, "none creates no surface")
end

local function test_apply_hides_the_minimap_button_in_widget_mode()
  local deps, calls = build()

  IconMode.Apply("widget", deps)

  assert(calls.ensureIcon == 1 and calls.ensureMinimap == 1, "widget mode still creates the minimap runtime")
  assert(calls.shown[1] == "widget" and calls.shown[2] == "minimap-off", "the widget shows and the minimap hides")
end

return function()
  test_resolve_defaults_when_icon_mode_is_missing()
  test_resolve_keeps_the_known_modes()
  test_apply_shows_only_the_minimap_in_minimap_mode()
  test_apply_shows_both_surfaces_in_both_mode()
  test_apply_creates_nothing_in_none_mode()
  test_apply_hides_the_minimap_button_in_widget_mode()
end
