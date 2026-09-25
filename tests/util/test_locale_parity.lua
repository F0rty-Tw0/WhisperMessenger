-- Every shipped catalog translates the same keys (English keys are the
-- source strings, so there is no enUS catalog) and keeps each key's format
-- slots (%s, %d, ...) in the same count and order.
local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

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

    -- test_edit_hint_names_the_translated_pages
    local hint = catalog["Edit this list in Options > Behavior."]
    assert(string.find(hint, catalog["Options"], 1, true), code .. " edit hint should name the translated Options page")
    assert(string.find(hint, catalog["Behavior"], 1, true), code .. " edit hint should name the translated Behavior page")
  end
end
