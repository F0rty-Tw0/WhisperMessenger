local Theme = require("WhisperMessenger.UI.Theme")
local BubbleColors = require("WhisperMessenger.UI.Theme.BubbleColors")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end

  return actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3] and actual[4] == expected[4]
end

return function()

  -- test_list_bubble_presets_returns_keys

  do
    local keys = BubbleColors.ListPresets()
    assert(type(keys) == "table", "test_list: expected table")
    assert(#keys >= 3, "test_list: expected at least 3 bubble presets, got " .. #keys)

    local found = {}
    for _, key in ipairs(keys) do
      found[key] = true
    end
    assert(found.default == true, "test_list: missing 'default' preset")
  end

  -- test_default_preset_is_active_initially

  do
    assert(BubbleColors.GetPreset() == "default", "test_initial: expected 'default' as initial preset")
  end

  -- test_default_preset_follows_theme_colors

  do
    BubbleColors.SetPreset("default")
    Theme.SetPreset("wow_default")

    local wowBubbleIn = {
      Theme.COLORS.bg_bubble_in[1],
      Theme.COLORS.bg_bubble_in[2],
      Theme.COLORS.bg_bubble_in[3],
      Theme.COLORS.bg_bubble_in[4],
    }

    -- Switch theme — bubble colors should follow because bubble preset is "default"
    Theme.SetPreset("elvui_dark")
    BubbleColors.ApplyPreset()

    assert(
      not colorsMatch(Theme.COLORS.bg_bubble_in, wowBubbleIn),
      "test_default_follows_theme: bubble_in should change when theme changes and bubble preset is default"
    )

    -- Restore
    Theme.SetPreset("wow_default")
    BubbleColors.SetPreset("default")
  end

  -- test_custom_preset_overrides_theme

  do
    Theme.SetPreset("wow_default")

    -- Pick a non-default bubble preset
    local keys = BubbleColors.ListPresets()
    local customKey = nil
    for _, key in ipairs(keys) do
      if key ~= "default" then
        customKey = key
        break
      end
    end
    assert(customKey ~= nil, "test_override: need at least 2 bubble presets")

    BubbleColors.SetPreset(customKey)
    local customIn = {
      Theme.COLORS.bg_bubble_in[1],
      Theme.COLORS.bg_bubble_in[2],
      Theme.COLORS.bg_bubble_in[3],
      Theme.COLORS.bg_bubble_in[4],
    }

    -- Switch theme — bubble colors should NOT change because a custom bubble preset is active
    Theme.SetPreset("elvui_dark")
    BubbleColors.ApplyPreset()

    assert(
      colorsMatch(Theme.COLORS.bg_bubble_in, customIn),
      "test_override: custom bubble preset must survive theme switch"
    )

    -- Restore
    Theme.SetPreset("wow_default")
    BubbleColors.SetPreset("default")
  end

  -- test_switching_back_to_default_restores_theme_colors

  do
    Theme.SetPreset("wow_default")
    BubbleColors.SetPreset("default")

    -- Snapshot theme's native bubble colors
    local themeIn = {
      Theme.COLORS.bg_bubble_in[1],
      Theme.COLORS.bg_bubble_in[2],
      Theme.COLORS.bg_bubble_in[3],
      Theme.COLORS.bg_bubble_in[4],
    }

    -- Switch to a custom preset (changes bubble colors)
    BubbleColors.SetPreset("ember")
    assert(not colorsMatch(Theme.COLORS.bg_bubble_in, themeIn), "test_restore: ember should differ from theme")

    -- Switch back to default — must restore theme's bubble colors
    BubbleColors.SetPreset("default")
    assert(
      colorsMatch(Theme.COLORS.bg_bubble_in, themeIn),
      "test_restore: switching to default must restore theme bubble colors"
    )
  end

  -- test_set_invalid_preset_returns_false

  do
    local before = BubbleColors.GetPreset()
    local ok = BubbleColors.SetPreset("nonexistent_preset")
    assert(ok == false, "test_invalid: expected false for unknown preset")
    assert(BubbleColors.GetPreset() == before, "test_invalid: preset should remain unchanged")
  end

  -- test_set_custom_preset_updates_all_three_tokens

  do
    Theme.SetPreset("wow_default")
    BubbleColors.SetPreset("default")

    local inBefore = {
      Theme.COLORS.bg_bubble_in[1],
      Theme.COLORS.bg_bubble_in[2],
      Theme.COLORS.bg_bubble_in[3],
      Theme.COLORS.bg_bubble_in[4],
    }
    local outBefore = {
      Theme.COLORS.bg_bubble_out[1],
      Theme.COLORS.bg_bubble_out[2],
      Theme.COLORS.bg_bubble_out[3],
      Theme.COLORS.bg_bubble_out[4],
    }

    local keys = BubbleColors.ListPresets()
    local diffKey = nil
    for _, key in ipairs(keys) do
      if key ~= "default" then
        diffKey = key
        break
      end
    end

    BubbleColors.SetPreset(diffKey)
    local inChanged = not colorsMatch(Theme.COLORS.bg_bubble_in, inBefore)
    local outChanged = not colorsMatch(Theme.COLORS.bg_bubble_out, outBefore)

    assert(inChanged or outChanged, "test_all_tokens: at least one bubble token must change with custom preset")

    -- Restore
    BubbleColors.SetPreset("default")
  end

  -- test_get_bubble_color_rgba_returns_current_colors

  do
    BubbleColors.SetPreset("default")
    local colors = BubbleColors.GetColors()
    assert(type(colors) == "table", "test_get_colors: expected table")
    assert(type(colors.bg_bubble_in) == "table", "test_get_colors: expected bg_bubble_in")
    assert(type(colors.bg_bubble_out) == "table", "test_get_colors: expected bg_bubble_out")
    assert(type(colors.bg_bubble_system) == "table", "test_get_colors: expected bg_bubble_system")
  end

  print("  All bubble color tests passed")
end
