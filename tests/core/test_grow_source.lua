local GrowSource = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GrowSource")

local function frame(visible)
  return {
    visible = visible,
    IsVisible = function(self)
      return self.visible
    end,
  }
end

local function icon(visible)
  return { frame = frame(visible) }
end

local function minimap(shown, visible)
  return {
    frame = frame(visible),
    isShown = function()
      return shown
    end,
  }
end

-- widget: what getWidgetIcon returns (nil in minimap/none mode, like WindowRuntime).
local function build(mode, widget, minimapIcon, settings)
  return GrowSource.Create({
    resolveIconMode = function()
      return mode
    end,
    getWidgetIcon = function()
      return widget
    end,
    getMinimapIcon = function()
      return minimapIcon
    end,
    settings = settings,
  })
end

return function()
  -- test_visible_floating_button_wins
  do
    local widget, map = icon(true), minimap(true, true)
    assert(build("both", widget, map, {}).getGrowSource() == widget.frame, "button first, even with the minimap icon up")
    assert(build("widget", widget, nil, {}).getGrowSource() == widget.frame, "widget mode")
  end

  -- test_hidden_button_falls_back_to_the_minimap_icon_in_both_mode
  do
    local map = minimap(true, true)
    assert(build("both", icon(false), map, {}).getGrowSource() == map.frame, "minimap icon")
  end

  -- test_minimap_mode_uses_the_minimap_icon
  do
    local map = minimap(true, true)
    assert(build("minimap", nil, map, {}).getGrowSource() == map.frame, "no widget in minimap mode")
  end

  -- test_minimap_icon_is_ignored_outside_minimap_and_both_modes
  do
    assert(build("widget", icon(false), minimap(true, true), {}).getGrowSource() == nil, "widget mode, hidden button")
    assert(build("none", nil, minimap(true, true), {}).getGrowSource() == nil, "none mode")
  end

  -- test_hidden_minimap_icon_is_no_source
  do
    assert(build("minimap", nil, minimap(false, true), {}).getGrowSource() == nil, "setShown(false)")
    assert(build("minimap", nil, minimap(true, false), {}).getGrowSource() == nil, "frame not visible")
    assert(build("minimap", nil, nil, {}).getGrowSource() == nil, "no minimap icon built")
  end

  -- test_animation_switch_defaults_on_and_follows_the_live_setting
  do
    local settings = {}
    local source = build("widget", nil, nil, settings)
    assert(source.isGrowAnimationOn() == true, "missing counts as on")
    settings.windowAnimation = false
    assert(source.isGrowAnimationOn() == false, "off, read live")
    settings.windowAnimation = true
    assert(source.isGrowAnimationOn() == true, "on again")
    assert(build("widget", nil, nil, nil).isGrowAnimationOn() == true, "no settings table counts as on")
  end

  -- test_the_glide_is_window_animation_and_has_no_reader_of_its_own
  do
    local source = build("widget", nil, nil, { iconGlide = false })
    assert(source.isIconGlideOn == nil, "the glide is Window animation, nothing else")
  end

  -- test_open_at_saved_spot_is_off_unless_switched_on
  do
    local settings = {}
    local source = build("widget", nil, nil, settings)
    assert(source.isOpenAtSavedSpot() == false, "missing counts as off")
    settings.openAtSavedSpot = true
    assert(source.isOpenAtSavedSpot() == true, "on, read live")
    settings.openAtSavedSpot = false
    assert(source.isOpenAtSavedSpot() == false, "off again")
    assert(build("widget", nil, nil, nil).isOpenAtSavedSpot() == false, "no settings table counts as off")
  end
end
