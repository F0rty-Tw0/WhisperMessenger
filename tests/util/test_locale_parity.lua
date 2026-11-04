-- Every shipped catalog translates the same keys (English keys are the
-- source strings, so there is no enUS catalog) and keeps each key's format
-- slots (%s, %d, ...) in the same count and order.
local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local INVITE_TOOLTIP_KEY = "Shows an (Invite to WM) link in the chat header. Clicking it whispers that player a short message about this addon."
local REPLY_PLACEHOLDER_KEY = "Reply…"
local REPLY_REASON_KEY = 'Turn on "Show widget message preview" to use this.'
local PREVIEW_REPLY_KEYS = {
  "Reply from widget preview",
  "Adds a small reply box under the widget message preview. Press Enter to send.",
  REPLY_PLACEHOLDER_KEY,
  REPLY_REASON_KEY,
}

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

    -- test_preview_reply_reason_names_the_translated_preview_toggle
    local replyReason = catalog[REPLY_REASON_KEY]
    assert(
      string.find(replyReason, catalog["Show widget message preview"], 1, true),
      code .. " reply reason should name the translated preview toggle"
    )
  end
end
