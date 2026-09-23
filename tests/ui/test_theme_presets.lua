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
    assert(found.jade_dark == true, "test_list_presets: missing jade_dark")
    assert(found.wow_native == true, "test_list_presets: missing wow_native")
  end

  do
    local colorsRef = Theme.COLORS
    local accentRef = Theme.COLORS.accent

    local ok = Theme.SetPreset("elvui_dark")
    assert(ok == true, "test_set_elvui_dark: expected SetPreset to return true")
    assert(Theme.GetPreset() == "elvui_dark", "test_set_elvui_dark: expected active preset key")
    assert(Theme.COLORS == colorsRef, "test_set_elvui_dark: Theme.COLORS table identity must be preserved")
    assert(Theme.COLORS.accent == accentRef, "test_set_elvui_dark: color table identity must be preserved")

    assert(colorsMatch(Theme.COLORS.bg_primary, { 0.03, 0.03, 0.03, 0.98 }), "test_set_elvui_dark: bg_primary did not update")
    assert(colorsMatch(Theme.COLORS.accent, { 0.34, 0.51, 0.90, 1.0 }), "test_set_elvui_dark: accent did not update")
    assert(colorsMatch(Theme.COLORS.bg_search_input, { 0.09, 0.10, 0.12, 1.0 }), "test_set_elvui_dark: bg_search_input did not update")
    assert(colorsMatch(Theme.COLORS.bg_message_input, { 0.09, 0.10, 0.12, 1.0 }), "test_set_elvui_dark: bg_message_input did not update")
    assert(Theme.COLORS.message_input_border_top == nil, "test_set_elvui_dark: message_input_border_top should be removed")
    assert(colorsMatch(Theme.COLORS.bg_bubble_in, { 0.16, 0.17, 0.20, 0.95 }), "test_set_elvui_dark: bg_bubble_in did not update")
    assert(Theme.COLORS.send_button_border == nil, "test_set_elvui_dark: send_button_border should be removed")
    assert(Theme.COLORS.send_button_border_hover == nil, "test_set_elvui_dark: send_button_border_hover should be removed")
    assert(Theme.COLORS.send_button_border_disabled == nil, "test_set_elvui_dark: send_button_border_disabled should be removed")
    assert(colorsMatch(Theme.COLORS.contacts_divider_hover, { 1.0, 1.0, 1.0, 0.16 }), "test_set_elvui_dark: contacts_divider_hover did not update")
    assert(colorsMatch(Theme.COLORS.option_toggle_on, { 0.34, 0.51, 0.90, 1.0 }), "test_set_elvui_dark: option_toggle_on did not update")
    assert(colorsMatch(Theme.COLORS.option_toggle_off, { 0.22, 0.23, 0.27, 0.96 }), "test_set_elvui_dark: option_toggle_off did not update")
    assert(
      colorsMatch(Theme.COLORS.composer_pane_border, { 1.0, 1.0, 1.0, 0.08 }),
      "test_set_elvui_dark: composer_pane_border should be a neutral white-plus-alpha hairline"
    )
    assert(colorsMatch(Theme.COLORS.contacts_border_right, { 1.0, 1.0, 1.0, 0.10 }), "test_set_elvui_dark: contacts_border_right did not update")
    assert(colorsMatch(Theme.COLORS.text_title, { 0.99, 0.99, 1.0, 1.0 }), "test_set_elvui_dark: text_title did not update")
  end

  do
    local ok = Theme.SetPreset("plumber_warm")
    assert(ok == true, "test_set_plumber_warm: expected SetPreset to return true")
    assert(Theme.GetPreset() == "plumber_warm", "test_set_plumber_warm: expected active preset key")

    assert(colorsMatch(Theme.COLORS.bg_primary, { 0.12, 0.10, 0.08, 0.97 }), "test_set_plumber_warm: bg_primary did not update")
    assert(colorsMatch(Theme.COLORS.accent, { 0.88, 0.56, 0.22, 1.0 }), "test_set_plumber_warm: accent did not update")
    assert(colorsMatch(Theme.COLORS.bg_search_input, { 0.31, 0.22, 0.16, 0.98 }), "test_set_plumber_warm: bg_search_input did not update")
    assert(colorsMatch(Theme.COLORS.bg_message_input, { 0.31, 0.22, 0.16, 0.98 }), "test_set_plumber_warm: bg_message_input did not update")
    assert(Theme.COLORS.message_input_border_top == nil, "test_set_plumber_warm: message_input_border_top should be removed")
    assert(Theme.COLORS.send_button_border == nil, "test_set_plumber_warm: send_button_border should be removed")
    assert(Theme.COLORS.send_button_border_hover == nil, "test_set_plumber_warm: send_button_border_hover should be removed")
    assert(Theme.COLORS.send_button_border_disabled == nil, "test_set_plumber_warm: send_button_border_disabled should be removed")
    assert(colorsMatch(Theme.COLORS.contacts_divider_hover, { 1.0, 1.0, 1.0, 0.16 }), "test_set_plumber_warm: contacts_divider_hover did not update")
    assert(colorsMatch(Theme.COLORS.option_toggle_on, { 0.88, 0.56, 0.22, 1.0 }), "test_set_plumber_warm: option_toggle_on tracks accent")
    assert(
      colorsMatch(Theme.COLORS.option_toggle_off, { 0.30, 0.24, 0.20, 0.95 }),
      "test_set_plumber_warm: option_toggle_off should be a dull desaturated brown"
    )
    assert(colorsMatch(Theme.COLORS.contacts_border_right, { 1.0, 1.0, 1.0, 0.10 }), "test_set_plumber_warm: contacts_border_right did not update")
    assert(colorsMatch(Theme.COLORS.text_title, { 1.0, 0.97, 0.92, 1.0 }), "test_set_plumber_warm: text_title did not update")
  end

  do
    local ok = Theme.SetPreset("jade_dark")
    assert(ok == true, "test_set_jade_dark: expected SetPreset to return true")
    assert(Theme.GetPreset() == "jade_dark", "test_set_jade_dark: expected active preset key")

    assert(colorsMatch(Theme.COLORS.bg_primary, { 0.067, 0.067, 0.067, 0.94 }), "test_set_jade_dark: bg_primary did not update")
    assert(colorsMatch(Theme.COLORS.accent, { 0.047, 0.824, 0.616, 1.0 }), "test_set_jade_dark: accent did not update")
    assert(colorsMatch(Theme.COLORS.option_toggle_on, { 0.047, 0.824, 0.616, 1.0 }), "test_set_jade_dark: option_toggle_on tracks accent")
    assert(
      colorsMatch(Theme.COLORS.contacts_border_right, { 1.0, 1.0, 1.0, 0.10 }),
      "test_set_jade_dark: contacts_border_right should be a neutral white-plus-alpha hairline"
    )
    assert(colorsMatch(Theme.COLORS.send_button_hover, { 0.047, 0.824, 0.616, 1.0 }), "test_set_jade_dark: send_button_hover should be full jade")
    assert(
      colorsMatch(Theme.COLORS.composer_pane_border, { 1.0, 1.0, 1.0, 0.08 }),
      "test_set_jade_dark: composer_pane_border should be a neutral white-plus-alpha hairline (accent is reserved)"
    )
    assert(Theme.COLORS.message_input_border_top == nil, "test_set_jade_dark: message_input_border_top should be removed")
    assert(Theme.COLORS.send_button_border == nil, "test_set_jade_dark: send_button_border should be removed")
  end

  do
    local colorsRef = Theme.COLORS
    local accentRef = Theme.COLORS.accent

    local ok = Theme.SetPreset("wow_native")
    assert(ok == true, "test_set_wow_native: expected SetPreset to return true")
    assert(Theme.GetPreset() == "wow_native", "test_set_wow_native: expected active preset key")
    assert(Theme.COLORS == colorsRef, "test_set_wow_native: Theme.COLORS table identity must be preserved")
    assert(Theme.COLORS.accent == accentRef, "test_set_wow_native: color table identity must be preserved")

    -- Blizzard NORMAL_FONT_COLOR (gold) drives accent + emphasis
    assert(colorsMatch(Theme.COLORS.accent, { 1.00, 0.82, 0.00, 1.0 }), "test_set_wow_native: accent did not update to NORMAL_FONT_COLOR gold")
    assert(
      colorsMatch(Theme.COLORS.text_title, { 1.00, 0.82, 0.00, 1.0 }),
      "test_set_wow_native: text_title did not update to NORMAL_FONT_COLOR gold"
    )
    assert(colorsMatch(Theme.COLORS.option_toggle_on, { 1.00, 0.82, 0.00, 1.0 }), "test_set_wow_native: option_toggle_on tracks gold accent")
    -- Toggle widget keeps its gold identity (ring + fill)
    assert(colorsMatch(Theme.COLORS.toggle_icon_bg, { 1.00, 0.82, 0.00, 1.0 }), "test_set_wow_native: toggle_icon_bg stays gold")
    assert(colorsMatch(Theme.COLORS.toggle_icon_ring, { 1.00, 0.82, 0.00, 0.75 }), "test_set_wow_native: toggle_icon_ring stays gold")

    -- System text keeps SYSTEM yellow; outgoing bubble keeps whisper magenta
    assert(colorsMatch(Theme.COLORS.text_system, { 1.00, 1.00, 0.00, 1.0 }), "test_set_wow_native: text_system stays system yellow")
    assert(
      colorsMatch(Theme.COLORS.bg_bubble_out, { 0.30, 0.13, 0.36, 0.82 }),
      "test_set_wow_native: bg_bubble_out did not update to whisper-magenta"
    )

    -- Blizzard standard status colors
    assert(colorsMatch(Theme.COLORS.online, { 0.10, 1.00, 0.10, 1.0 }), "test_set_wow_native: online did not update to GREEN_FONT_COLOR")
    assert(colorsMatch(Theme.COLORS.away, { 1.00, 0.50, 0.25, 1.0 }), "test_set_wow_native: away did not update to ORANGE_FONT_COLOR")
    assert(colorsMatch(Theme.COLORS.dnd, { 1.00, 0.10, 0.10, 1.0 }), "test_set_wow_native: dnd did not update to RED_FONT_COLOR")

    -- Modern roles: distinct surface tones instead of one uniform near-black
    assert(
      not colorsMatch(Theme.COLORS.bg_primary, Theme.COLORS.bg_secondary),
      "test_set_wow_native: bg_secondary should be a distinct tone from bg_primary"
    )
    -- Selection and pinned rows are accent tints, hover is a faint white wash
    assert(colorsMatch(Theme.COLORS.bg_contact_selected, { 1.00, 0.82, 0.00, 0.16 }), "test_set_wow_native: selection is a 0.16 gold tint")
    assert(
      colorsMatch(Theme.COLORS.option_button_active_hover, { 1.00, 0.82, 0.00, 0.22 }),
      "test_set_wow_native: selected hover is a 0.22 gold tint"
    )
    assert(colorsMatch(Theme.COLORS.bg_contact_hover, { 1.0, 1.0, 1.0, 0.05 }), "test_set_wow_native: hover is white at 0.05")
    -- Hairlines are neutral white-plus-alpha
    assert(colorsMatch(Theme.COLORS.divider, { 1.0, 1.0, 1.0, 0.08 }), "test_set_wow_native: divider is white at 0.08")
    assert(colorsMatch(Theme.COLORS.contacts_border_right, { 1.0, 1.0, 1.0, 0.10 }), "test_set_wow_native: strong divider is white at 0.10")
    assert(colorsMatch(Theme.COLORS.window_border, { 1.0, 1.0, 1.0, 0.10 }), "test_set_wow_native: window_border is white at 0.10")
    assert(colorsMatch(Theme.COLORS.composer_pane_border, { 1.0, 1.0, 1.0, 0.08 }), "test_set_wow_native: composer edge is white at 0.08")
    -- Muted neutral secondary text and timestamps
    assert(colorsMatch(Theme.COLORS.text_secondary, { 1.0, 1.0, 1.0, 0.55 }), "test_set_wow_native: secondary text is white at 0.55")
    assert(colorsMatch(Theme.COLORS.text_timestamp, { 1.0, 1.0, 1.0, 0.40 }), "test_set_wow_native: timestamps are white at 0.40")

    -- Removed legacy keys must remain absent
    assert(Theme.COLORS.message_input_border_top == nil, "test_set_wow_native: message_input_border_top should remain absent")
    assert(Theme.COLORS.send_button_border == nil, "test_set_wow_native: send_button_border should remain absent")
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
    local resolved, applied = Theme.ResolvePreset("missing_preset")
    assert(applied == true, "test_resolve_fallback: expected fallback apply to succeed")
    assert(resolved == "wow_default", "test_resolve_fallback: expected wow_default fallback, got: " .. tostring(resolved))
  end

  local resetOk = Theme.SetPreset("wow_default")
  assert(resetOk == true, "test_reset_default: expected wow_default preset to apply")
  assert(Theme.COLORS.message_input_border_top == nil, "test_reset_default: message_input_border_top should remain removed")
  assert(Theme.COLORS.send_button_border == nil, "test_reset_default: send_button_border should remain removed")
  -- Tokens that only fed the retired Azeroth-only look are gone.
  for _, token in ipairs({
    "send_button",
    "send_button_disabled",
    "send_button_text",
    "send_button_text_disabled",
    "unread_badge_classic",
    "contacts_resize_hover_fill",
    "contacts_resize_outline",
    "option_toggle_border",
    "action_icon_pinned",
    "contact_selected_border_right",
  }) do
    assert(Theme.COLORS[token] == nil, "test_reset_default: retired token " .. token .. " should be removed")
  end
  assert(colorsMatch(Theme.COLORS.accent, { 0.12, 0.72, 0.96, 1.0 }), "test_reset_default: wow_default accent should be the tuned cobalt accent")
  assert(
    colorsMatch(Theme.COLORS.option_toggle_on, { 0.12, 0.72, 0.96, 1.0 }),
    "test_reset_default: wow_default option_toggle_on should track the tuned accent"
  )

  print("  All theme preset tests passed")
end
