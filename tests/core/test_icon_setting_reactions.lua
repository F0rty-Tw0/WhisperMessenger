local IconSettingReactions = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconSettingReactions")

local function newSpyIcon()
  local calls = {}
  local function record(name)
    return function(...)
      calls[#calls + 1] = name .. ":" .. table.concat({ ... }, ",")
    end
  end
  return {
    calls = calls,
    applyStrata = record("applyStrata"),
    refreshTheme = record("refreshTheme"),
    refreshDesaturation = record("refreshDesaturation"),
    refreshTransparency = record("refreshTransparency"),
    refreshLockGlyph = record("refreshLockGlyph"),
    applyPreviewPosition = record("applyPreviewPosition"),
  }
end

return function()
  -- test_widget_strata_change_reaches_the_widget
  do
    local icon = newSpyIcon()
    IconSettingReactions.Apply("widgetStrata", "LOW", icon, nil)
    assert(table.concat(icon.calls, ";") == "applyStrata:LOW", "got " .. table.concat(icon.calls, ";"))
  end

  -- test_widget_strata_change_without_a_widget_is_safe
  do
    IconSettingReactions.Apply("widgetStrata", "LOW", nil, nil)
    IconSettingReactions.Apply("widgetStrata", "LOW", {}, nil)
  end

  -- test_look_settings_repaint_the_widget
  for _, key in ipairs({ "iconBorder", "iconBorderThemed", "iconBackground", "widgetShape" }) do
    local icon = newSpyIcon()
    IconSettingReactions.Apply(key, true, icon, nil)
    assert(table.concat(icon.calls, ";") == "refreshTheme:", key .. " got " .. table.concat(icon.calls, ";"))
  end

  -- test_transparency_and_lock_glyph_reach_the_widget
  do
    local icon = newSpyIcon()
    IconSettingReactions.Apply("widgetTransparency", 0.5, icon, nil)
    IconSettingReactions.Apply("lockToggleIcon", true, icon, nil)
    assert(table.concat(icon.calls, ";") == "refreshTransparency:;refreshLockGlyph:", "got " .. table.concat(icon.calls, ";"))
  end

  -- test_desaturation_reaches_both_icons
  do
    local icon, minimap = newSpyIcon(), newSpyIcon()
    IconSettingReactions.Apply("iconDesaturated", true, icon, minimap)
    assert(table.concat(icon.calls, ";") == "refreshDesaturation:", "icon got " .. table.concat(icon.calls, ";"))
    assert(table.concat(minimap.calls, ";") == "refreshDesaturation:", "minimap got " .. table.concat(minimap.calls, ";"))
  end

  -- test_preview_position_reaches_both_icons
  do
    local icon, minimap = newSpyIcon(), newSpyIcon()
    IconSettingReactions.Apply("widgetPreviewPosition", "left", icon, minimap)
    assert(table.concat(icon.calls, ";") == "applyPreviewPosition:left", "icon got " .. table.concat(icon.calls, ";"))
    assert(table.concat(minimap.calls, ";") == "applyPreviewPosition:left", "minimap got " .. table.concat(minimap.calls, ";"))
  end

  -- test_other_keys_touch_nothing
  do
    local icon = newSpyIcon()
    IconSettingReactions.Apply("fontSize", 14, icon, icon)
    assert(#icon.calls == 0, "unrelated key reached the icon")
  end
end
