-- Every shipped catalog translates the same keys (English keys are the
-- source strings, so there is no enUS catalog) and keeps each key's format
-- slots (%s, %d, ...) in the same count and order.
local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local INVITE_TOOLTIP_KEY = "Shows an (Invite to WM) link in the chat header. Clicking it whispers that player a short message about this addon."
local TOOLTIP_KEY = "The floating button opens a narrow chat list attached to it. Click a chat to slide into it."
local REPLY_PLACEHOLDER_KEY = "Reply…"
local REPLY_REASON_KEY = 'Turn on "Show widget message preview" to use this.'
local PREVIEW_REPLY_KEYS = {
  "Reply from widget preview",
  "Adds a small reply box under the widget message preview. Press Enter to send.",
  REPLY_PLACEHOLDER_KEY,
  REPLY_REASON_KEY,
}
local DESELECT_ON_SEND_KEYS = {
  "Deselect chat input after sending",
  "After you send a message, the cursor leaves the text box so your keys control the game again. While the messenger is open, Enter puts the cursor back.",
}
local WIDGET_SHAPE_KEYS = {
  "Widget shape",
  "Circle",
  "Square",
}
local COMMUNITY_NOTICE_KEYS = {
  "Read-only here. Reply in the game's Communities window.",
}
local CHANNEL_CONTEXT_KEYS = {
  "Show their last channel message",
  "When someone whispers you, their latest line from a channel such as Trade shows above the whisper. Turn this off to hide it.",
}
local RELATIONSHIP_KEYS = {
  "Guild: %s",
  "Guild",
  "Battle.net friend",
  "Friend",
  "Community: %s",
  "Community",
  "Show relationship marks",
  "Show a small icon next to names for guildmates, friends and community members.",
}
local BORDER_REASON_KEY = "Only with Show border on."
local BORDER_KEYS = {
  "Show border",
  "Draws a ring around the widget, or a frame around the square widget.",
  "Color border with theme",
  "Tints the border to the theme's accent color. Turn it off for the gold border.",
  BORDER_REASON_KEY,
  "Button background",
  "Shows the circle or square behind the widget icon. Turn it off to show only the two chat bubbles.",
}
local REMOVED_KEYS = {
  "Square button background",
  "Shows a square behind the widget icon when the widget shape is square. Turn it off to show only the two chat bubbles.",
  "Only with the square widget shape.",
  "The window grows out of its icon when it opens and shrinks back into it when it closes. Turn it off to open and close it at once.",
  "Button glide",
  "The floating button glides onto the window's corner when it opens and back when it closes. Turn it off to make it jump.",
  "The window opens where you last moved it. Turn it off to open the window at the floating button, and move the button along when you move the window.",
  "Show more",
  "Show all",
  "%d of %d lines · Ctrl+C copies",
  "Phone-style window",
  "The floating button opens a phone-sized chat list attached to it. Click a chat to slide into it.",
  "Share widget position across characters",
  "Uses one widget position for all characters on this WoW account.",
}
local SAME_POSITION_KEYS = {
  "Same position on every character",
  "Keeps the widget, minimap button, message preview and window in the same place on all characters of this WoW account.",
}
local WIDGET_LAYER_KEYS = {
  "Widget layer",
  "Sets which game windows the widget sits above. Pick a lower layer to keep bags and other windows on top of it.",
  "Background",
  "Low",
  "Medium",
  "High",
}
local COMPACT_WINDOW_KEYS = { "Compact window", TOOLTIP_KEY }
local WINDOW_ANIMATION_KEYS = {
  "Window animation",
  "The window grows out of its icon when it opens and shrinks back into it when it closes, and pages slide in. Turn it off to make everything appear at once.",
}
local DOCK_KEYS = {
  "Dock button on the window",
  "While the window is open, the floating button sits in the window's top-left corner. Turn it off to leave the button where it is.",
}
local ESCAPE_SETTING_KEYS = {
  "Esc closes the window",
  "Turn off to keep the messenger open when you press Esc. Close it with its button or your Toggle Window key.",
}
local REQUEST_SOUND_KEYS = {
  "Play sound on message request",
  "Plays a sound when a whisper from a stranger lands in Requests. Pick the sound below.",
  "Request sound",
}
local EVENT_SOUND_KEYS = {
  "Mention sound",
  "Play sound when you send a whisper",
  "Plays a sound each time a whisper you write here is sent. Pick the sound below.",
  "Sent whisper sound",
}
local SAVED_SPOT_KEYS = {
  "Open at saved spot",
  "The window opens where you last moved it. Turn it off to open the window at the floating button, and move the button along when you move the window. Only while Dock button on the window is on.",
}
local LANGUAGE_RELOAD_KEY = "Reload the interface now to apply the language change?"

-- "%s|%d" for "Last seen %s ... %d"; "%%" is a literal percent, not a slot.
local function formatSlots(text)
  local slots = {}
  for flag in string.gmatch(text, "%%([%%%a])") do
    if flag ~= "%" then
      slots[#slots + 1] = "%" .. flag
    end
  end
  return table.concat(slots, "|")
end

return function()
  local catalogs = {}
  local allKeys = {}
  for _, code in ipairs(LOCALES) do
    local catalog = require("WhisperMessenger.Locale." .. code)
    catalogs[code] = catalog
    for key in pairs(catalog) do
      allKeys[key] = true
    end
  end

  for _, code in ipairs(LOCALES) do
    local catalog = catalogs[code]
    for key in pairs(allKeys) do
      -- test_every_catalog_has_every_key
      local value = catalog[key]
      assert(type(value) == "string" and value ~= "", code .. " is missing a translation for '" .. key .. "'")
      -- test_translations_keep_format_slots
      assert(
        formatSlots(value) == formatSlots(key),
        code .. " translation of '" .. key .. "' must keep the format slots " .. formatSlots(key) .. ", got " .. formatSlots(value)
      )
    end

    -- test_zone_divider_is_translated
    assert(catalog["Zone: %s"] ~= nil, code .. " is missing the channel zone divider")

    -- test_edit_hint_names_the_translated_pages
    local hint = catalog["Edit this list in Options > Behavior."]
    assert(string.find(hint, catalog["Options"], 1, true), code .. " edit hint should name the translated Options page")
    assert(string.find(hint, catalog["Behavior"], 1, true), code .. " edit hint should name the translated Behavior page")

    -- test_invite_tooltip_names_the_translated_link
    local inviteTooltip = catalog[INVITE_TOOLTIP_KEY]
    assert(string.find(inviteTooltip, catalog["Invite to WM"], 1, true), code .. " invite tooltip should name the translated link")

    -- test_preview_reply_strings_are_translated
    for _, key in ipairs(PREVIEW_REPLY_KEYS) do
      assert(catalog[key] ~= nil, code .. " is missing a translation for '" .. key .. "'")
    end
    assert(string.find(catalog[REPLY_PLACEHOLDER_KEY], "…", 1, true), code .. " reply placeholder should keep the ellipsis")

    -- test_deselect_on_send_strings_are_translated
    for _, key in ipairs(DESELECT_ON_SEND_KEYS) do
      assert(catalog[key] ~= nil, code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_widget_shape_strings_are_translated
    for _, key in ipairs(WIDGET_SHAPE_KEYS) do
      assert(catalog[key] ~= nil, code .. " is missing a translation for '" .. key .. "'")
    end
    assert(
      catalog["With the EllesmereUI theme, shows the square behind the widget icon. Turn it off to show only the two chat bubbles."] == nil,
      code .. " still has the old EllesmereUI tooltip"
    )

    -- test_channel_context_strings_are_translated
    for _, key in ipairs(CHANNEL_CONTEXT_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_community_notice_is_translated
    for _, key in ipairs(COMMUNITY_NOTICE_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_relationship_strings_are_translated
    for _, key in ipairs(RELATIONSHIP_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_border_strings_are_translated
    for _, key in ipairs(BORDER_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_removed_icon_strings_are_gone
    for _, key in ipairs(REMOVED_KEYS) do
      assert(catalog[key] == nil, code .. " still has the removed string '" .. key .. "'")
    end

    -- test_window_animation_strings_are_translated
    for _, key in ipairs(WINDOW_ANIMATION_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_same_position_strings_are_translated
    for _, key in ipairs(SAME_POSITION_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_widget_layer_strings_are_translated
    for _, key in ipairs(WIDGET_LAYER_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_compact_window_strings_are_translated
    for _, key in ipairs(COMPACT_WINDOW_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_dock_button_strings_are_translated
    for _, key in ipairs(DOCK_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_escape_setting_strings_are_translated
    for _, key in ipairs(ESCAPE_SETTING_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_request_sound_strings_are_translated
    for _, key in ipairs(REQUEST_SOUND_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_event_sound_strings_are_translated
    for _, key in ipairs(EVENT_SOUND_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_open_at_saved_spot_strings_are_translated
    for _, key in ipairs(SAVED_SPOT_KEYS) do
      assert(type(catalog[key]) == "string" and catalog[key] ~= "", code .. " is missing a translation for '" .. key .. "'")
    end

    -- test_language_reload_prompt_is_translated
    assert(catalog[LANGUAGE_RELOAD_KEY] ~= nil, code .. " is missing a translation for '" .. LANGUAGE_RELOAD_KEY .. "'")

    -- test_preview_reply_reason_names_the_translated_preview_toggle
    local replyReason = catalog[REPLY_REASON_KEY]
    assert(
      string.find(replyReason, catalog["Show widget message preview"], 1, true),
      code .. " reply reason should name the translated preview toggle"
    )

    -- test_border_reason_names_the_translated_show_border_toggle
    assert(
      string.find(catalog[BORDER_REASON_KEY], catalog["Show border"], 1, true),
      code .. " border reason should name the translated Show border toggle"
    )
  end
end
