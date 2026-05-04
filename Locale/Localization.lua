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
  deDE = true,
  frFR = true,
  esES = true,
  esMX = true,
  itIT = true,
  ptBR = true,
  koKR = true,
  zhCN = true,
  zhTW = true,
}

local configuredLanguage = AUTO_LANGUAGE
local getLocaleFn = function()
  local getLocale = _G and _G["GetLocale"] or nil
  if type(getLocale) == "function" then
    return getLocale()
  end
  return DEFAULT_LANGUAGE
end

-- Each non-English locale ships its own catalog file. They populate
-- `ns.Locale_<code>` when loaded by the WoW client (TOC order). For tests that
-- run under the lupa harness, `require` falls back to a direct module load.
local function loadCatalog(code, modulePath)
  local cached = ns["Locale_" .. code]
  if cached ~= nil then
    return cached
  end
  if type(require) == "function" then
    local ok, catalog = pcall(require, modulePath)
    if ok then
      return catalog
    end
  end
  return nil
end

local catalogs = {
  ruRU = loadCatalog("ruRU", "WhisperMessenger.Locale.ruRU"),
  deDE = loadCatalog("deDE", "WhisperMessenger.Locale.deDE"),
  frFR = loadCatalog("frFR", "WhisperMessenger.Locale.frFR"),
  esES = loadCatalog("esES", "WhisperMessenger.Locale.esES"),
  esMX = loadCatalog("esMX", "WhisperMessenger.Locale.esMX"),
  itIT = loadCatalog("itIT", "WhisperMessenger.Locale.itIT"),
  ptBR = loadCatalog("ptBR", "WhisperMessenger.Locale.ptBR"),
  koKR = loadCatalog("koKR", "WhisperMessenger.Locale.koKR"),
  zhCN = loadCatalog("zhCN", "WhisperMessenger.Locale.zhCN"),
  zhTW = loadCatalog("zhTW", "WhisperMessenger.Locale.zhTW"),
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

-- Each language is displayed using its own native name (autonym) so the
-- picker is readable to anyone who can use that locale. The tooltip is the
-- only string here that gets translated into the user's current language.
local LANGUAGE_PICKER_ORDER = {
  { key = "enUS", label = "English", tooltipKey = "Use English for the addon's interface." },
  { key = "deDE", label = "Deutsch", tooltipKey = "Use German for the addon's interface." },
  { key = "esES", label = "Español (ES)", tooltipKey = "Use Spanish (Spain) for the addon's interface." },
  { key = "esMX", label = "Español (LA)", tooltipKey = "Use Spanish (Latin America) for the addon's interface." },
  { key = "frFR", label = "Français", tooltipKey = "Use French for the addon's interface." },
  { key = "itIT", label = "Italiano", tooltipKey = "Use Italian for the addon's interface." },
  { key = "ptBR", label = "Português", tooltipKey = "Use Portuguese (Brazil) for the addon's interface." },
  { key = "ruRU", label = "Русский", tooltipKey = "Use Russian for the addon's interface." },
  { key = "koKR", label = "한국어", tooltipKey = "Use Korean for the addon's interface." },
  { key = "zhCN", label = "简体中文", tooltipKey = "Use Chinese (Simplified) for the addon's interface." },
  { key = "zhTW", label = "繁體中文", tooltipKey = "Use Chinese (Traditional) for the addon's interface." },
}

function Localization.LanguageOptions(languageOverride)
  local options = {
    {
      key = AUTO_LANGUAGE,
      label = Localization.Text("Auto", languageOverride),
      tooltip = Localization.Text("Use World of Warcraft's current locale.", languageOverride),
    },
  }
  for _, entry in ipairs(LANGUAGE_PICKER_ORDER) do
    options[#options + 1] = {
      key = entry.key,
      label = entry.label,
      tooltip = Localization.Text(entry.tooltipKey, languageOverride),
    }
  end
  return options
end

ns.Localization = Localization

return Localization
