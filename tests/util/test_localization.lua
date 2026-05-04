local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  Localization.Configure({
    language = "auto",
    getLocale = function()
      return "enUS"
    end,
  })
  assert(Localization.GetConfiguredLanguage() == "auto", "default configured language should be auto")
  assert(Localization.GetEffectiveLanguage() == "enUS", "enUS locale should resolve English")
  assert(Localization.Text("General Settings") == "General Settings", "English should return the source key")

  Localization.Configure({
    language = "auto",
    getLocale = function()
      return "ruRU"
    end,
  })
  assert(Localization.GetEffectiveLanguage() == "ruRU", "ruRU locale should auto-detect Russian")
  assert(Localization.Text("General Settings") == "Общие настройки", "Russian catalog should translate General Settings")

  Localization.Configure({ language = "enUS" })
  assert(Localization.GetEffectiveLanguage() == "enUS", "explicit enUS should override ruRU auto-detection")
  assert(Localization.Text("General Settings") == "General Settings", "explicit English should return source key")

  Localization.Configure({
    language = "bogus",
    getLocale = function()
      return "ruRU"
    end,
  })
  assert(Localization.GetConfiguredLanguage() == "auto", "invalid language should normalize to auto")
  assert(Localization.GetEffectiveLanguage() == "ruRU", "invalid explicit language should fall back to supported auto-detected locale")
end
