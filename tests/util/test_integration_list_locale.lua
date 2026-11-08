local LOCALES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local KEYS = {
  "Addons using Whisper Messenger",
  "No addons have connected yet.",
  "Other addons",
  "Addons that use Whisper Messenger without naming themselves.",
  "Not loaded",
  "Forget",
}

return function()
  for _, code in ipairs(LOCALES) do
    local catalog = require("WhisperMessenger.Locale." .. code)
    for _, key in ipairs(KEYS) do
      -- test_every_catalog_translates_the_integration_list_strings
      local value = catalog[key]
      assert(type(value) == "string" and value ~= "", code .. " is missing a translation for '" .. key .. "'")
      assert(value ~= key, code .. " left '" .. key .. "' in English")
    end
  end
end
