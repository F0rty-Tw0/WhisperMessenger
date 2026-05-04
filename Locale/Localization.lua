local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = {}

local DEFAULT_LANGUAGE = "enUS"
local AUTO_LANGUAGE = "auto"

local supportedLanguages = {
  enUS = true,
  ruRU = true,
}

local configuredLanguage = AUTO_LANGUAGE
local getLocaleFn = function()
  local getLocale = _G and _G["GetLocale"] or nil
  if type(getLocale) == "function" then
    return getLocale()
  end
  return DEFAULT_LANGUAGE
end

local Russian = ns.Locale_ruRU or require("WhisperMessenger.Locale.ruRU")

local catalogs = {
  ruRU = Russian,
}

local function normalizeLanguage(language)
  if language == nil or language == "" or language == AUTO_LANGUAGE then
    return AUTO_LANGUAGE
  end
  if supportedLanguages[language] then
    return language
  end
  return AUTO_LANGUAGE
end

local function detectLocale()
  local ok, locale = pcall(getLocaleFn)
  if ok and supportedLanguages[locale] then
    return locale
  end
  return DEFAULT_LANGUAGE
end

function Localization.Configure(options)
  options = options or {}
  if type(options.getLocale) == "function" then
    getLocaleFn = options.getLocale
  end
  configuredLanguage = normalizeLanguage(options.language)
end

function Localization.GetConfiguredLanguage()
  return configuredLanguage
end

function Localization.GetEffectiveLanguage(languageOverride)
  local language = configuredLanguage
  if languageOverride ~= nil then
    language = normalizeLanguage(languageOverride)
  end
  if language == AUTO_LANGUAGE then
    return detectLocale()
  end
  return language
end

function Localization.Text(key, languageOverride)
  local effective = Localization.GetEffectiveLanguage(languageOverride)
  local catalog = catalogs[effective]
  if catalog and catalog[key] then
    return catalog[key]
  end
  return key
end

function Localization.LanguageOptions(languageOverride)
  return {
    {
      key = AUTO_LANGUAGE,
      label = Localization.Text("Auto", languageOverride),
      tooltip = Localization.Text("Use World of Warcraft's current locale.", languageOverride),
    },
    {
      key = "enUS",
      label = Localization.Text("English", languageOverride),
      tooltip = Localization.Text("Use English for the addon's interface.", languageOverride),
    },
    {
      key = "ruRU",
      label = Localization.Text("Russian", languageOverride),
      tooltip = Localization.Text("Use Russian for the addon's interface.", languageOverride),
    },
  }
end

ns.Localization = Localization

return Localization
