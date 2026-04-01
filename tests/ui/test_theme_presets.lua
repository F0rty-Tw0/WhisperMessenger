local Theme = require("WhisperMessenger.UI.Theme")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end

  return actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3] and actual[4] == expected[4]
end

return function()
  do
    local keys = Theme.ListPresets()
    local found = {}
    for _, key in ipairs(keys) do
      found[key] = true
    end

    assert(found.wow_default == true, "test_list_presets: missing wow_default")
    assert(found.elvui_dark == true, "test_list_presets: missing elvui_dark")
    assert(found.plumber_warm == true, "test_list_presets: missing plumber_warm")
  end

  do
    local colorsRef = Theme.COLORS
    local accentRef = Theme.COLORS.accent

    local ok = Theme.SetPreset("elvui_dark")
    assert(ok == true, "test_set_elvui_dark: expected SetPreset to return true")
    assert(Theme.GetPreset() == "elvui_dark", "test_set_elvui_dark: expected active preset key")
    assert(Theme.COLORS == colorsRef, "test_set_elvui_dark: Theme.COLORS table identity must be preserved")
    assert(Theme.COLORS.accent == accentRef, "test_set_elvui_dark: color table identity must be preserved")

    assert(
      colorsMatch(Theme.COLORS.bg_primary, { 0.03, 0.03, 0.03, 0.98 }),
      "test_set_elvui_dark: bg_primary did not update"
    )
    assert(colorsMatch(Theme.COLORS.accent, { 0.34, 0.51, 0.90, 1.0 }), "test_set_elvui_dark: accent did not update")
    assert(
      colorsMatch(Theme.COLORS.bg_search_input, { 0.09, 0.10, 0.12, 1.0 }),
      "test_set_elvui_dark: bg_search_input did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.bg_message_input, { 0.09, 0.10, 0.12, 1.0 }),
      "test_set_elvui_dark: bg_message_input did not update"
    )
    assert(
      Theme.COLORS.message_input_border_top == nil,
      "test_set_elvui_dark: message_input_border_top should be removed"
    )
    assert(
      colorsMatch(Theme.COLORS.bg_bubble_in, { 0.16, 0.17, 0.20, 0.95 }),
      "test_set_elvui_dark: bg_bubble_in did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.send_button, { 0.20, 0.56, 0.84, 1.0 }),
      "test_set_elvui_dark: send_button did not update"
    )
    assert(Theme.COLORS.send_button_border == nil, "test_set_elvui_dark: send_button_border should be removed")
    assert(
      Theme.COLORS.send_button_border_hover == nil,
      "test_set_elvui_dark: send_button_border_hover should be removed"
    )
    assert(
      Theme.COLORS.send_button_border_disabled == nil,
      "test_set_elvui_dark: send_button_border_disabled should be removed"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_divider_hover, { 0.17, 0.18, 0.23, 0.72 }),
      "test_set_elvui_dark: contacts_divider_hover did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_resize_hover_fill, { 0.17, 0.18, 0.23, 0.07 }),
      "test_set_elvui_dark: contacts_resize_hover_fill did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_on, { 0.34, 0.51, 0.90, 1.0 }),
      "test_set_elvui_dark: option_toggle_on did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_off, { 0.22, 0.23, 0.27, 0.96 }),
      "test_set_elvui_dark: option_toggle_off did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_border, { 0.50, 0.52, 0.58, 0.90 }),
      "test_set_elvui_dark: option_toggle_border did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_border_right, { 0.15, 0.16, 0.20, 0.90 }),
      "test_set_elvui_dark: contacts_border_right did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contact_selected_border_right, { 0.34, 0.51, 0.90, 1.0 }),
      "test_set_elvui_dark: contact_selected_border_right did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.text_title, { 0.99, 0.99, 1.0, 1.0 }),
      "test_set_elvui_dark: text_title did not update"
    )
  end

  do
    local ok = Theme.SetPreset("plumber_warm")
    assert(ok == true, "test_set_plumber_warm: expected SetPreset to return true")
    assert(Theme.GetPreset() == "plumber_warm", "test_set_plumber_warm: expected active preset key")

    assert(
      colorsMatch(Theme.COLORS.bg_primary, { 0.12, 0.10, 0.08, 0.97 }),
      "test_set_plumber_warm: bg_primary did not update"
    )
    assert(colorsMatch(Theme.COLORS.accent, { 0.88, 0.56, 0.22, 1.0 }), "test_set_plumber_warm: accent did not update")
    assert(
      colorsMatch(Theme.COLORS.bg_search_input, { 0.31, 0.22, 0.16, 0.98 }),
      "test_set_plumber_warm: bg_search_input did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.bg_message_input, { 0.31, 0.22, 0.16, 0.98 }),
      "test_set_plumber_warm: bg_message_input did not update"
    )
    assert(
      Theme.COLORS.message_input_border_top == nil,
      "test_set_plumber_warm: message_input_border_top should be removed"
    )
    assert(
      colorsMatch(Theme.COLORS.send_button, { 0.74, 0.40, 0.20, 1.0 }),
      "test_set_plumber_warm: send_button did not update"
    )
    assert(Theme.COLORS.send_button_border == nil, "test_set_plumber_warm: send_button_border should be removed")
    assert(
      Theme.COLORS.send_button_border_hover == nil,
      "test_set_plumber_warm: send_button_border_hover should be removed"
    )
    assert(
      Theme.COLORS.send_button_border_disabled == nil,
      "test_set_plumber_warm: send_button_border_disabled should be removed"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_divider_hover, { 0.48, 0.34, 0.24, 0.80 }),
      "test_set_plumber_warm: contacts_divider_hover did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_resize_hover_fill, { 0.48, 0.34, 0.24, 0.08 }),
      "test_set_plumber_warm: contacts_resize_hover_fill did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_on, { 0.88, 0.56, 0.22, 1.0 }),
      "test_set_plumber_warm: option_toggle_on did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_off, { 0.34, 0.25, 0.19, 0.95 }),
      "test_set_plumber_warm: option_toggle_off did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.option_toggle_border, { 0.78, 0.61, 0.46, 0.92 }),
      "test_set_plumber_warm: option_toggle_border did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contacts_border_right, { 0.42, 0.29, 0.20, 0.90 }),
      "test_set_plumber_warm: contacts_border_right did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.contact_selected_border_right, { 0.88, 0.56, 0.22, 1.0 }),
      "test_set_plumber_warm: contact_selected_border_right did not update"
    )
    assert(
      colorsMatch(Theme.COLORS.text_title, { 1.0, 0.97, 0.92, 1.0 }),
      "test_set_plumber_warm: text_title did not update"
    )
  end

  do
    local beforePreset = Theme.GetPreset()
    local beforeAccent = {
      Theme.COLORS.accent[1],
      Theme.COLORS.accent[2],
      Theme.COLORS.accent[3],
      Theme.COLORS.accent[4],
    }

    local ok = Theme.SetPreset("unknown")
    assert(ok == false, "test_invalid_key: expected SetPreset to return false")
    assert(Theme.GetPreset() == beforePreset, "test_invalid_key: active preset should remain unchanged")
    assert(colorsMatch(Theme.COLORS.accent, beforeAccent), "test_invalid_key: color state should remain unchanged")
  end

  do
    local traceCalls = {}
    local function trace(...)
      traceCalls[#traceCalls + 1] = table.concat({ ... }, " ")
    end

    local resolved, applied = Theme.ResolvePreset("missing_preset", trace)
    assert(applied == true, "test_resolve_fallback: expected fallback apply to succeed")
    assert(
      resolved == "wow_default",
      "test_resolve_fallback: expected wow_default fallback, got: " .. tostring(resolved)
    )
    assert(#traceCalls > 0, "test_resolve_fallback: expected fallback trace to be emitted")
  end

  local resetOk = Theme.SetPreset("wow_default")
  assert(resetOk == true, "test_reset_default: expected wow_default preset to apply")
  assert(
    Theme.COLORS.message_input_border_top == nil,
    "test_reset_default: message_input_border_top should remain removed"
  )
  assert(Theme.COLORS.send_button_border == nil, "test_reset_default: send_button_border should remain removed")
  assert(
    colorsMatch(Theme.COLORS.accent, { 0.12, 0.72, 0.96, 1.0 }),
    "test_reset_default: wow_default accent should be the tuned cobalt accent"
  )
  assert(
    colorsMatch(Theme.COLORS.option_toggle_on, { 0.12, 0.72, 0.96, 1.0 }),
    "test_reset_default: wow_default option_toggle_on should track the tuned accent"
  )
  assert(
    colorsMatch(Theme.COLORS.contact_selected_border_right, { 0.12, 0.72, 0.96, 1.0 }),
    "test_reset_default: wow_default contact_selected_border_right should track the tuned accent"
  )

  print("  All theme preset tests passed")
end
