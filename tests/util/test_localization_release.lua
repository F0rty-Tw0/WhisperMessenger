local function fresh(language, clientLocale)
  local ns = {
    Locale_deDE = { Hello = "Hallo" },
    Locale_ruRU = { Hello = "Privet" },
  }
  local Localization = assert(loadfile("Locale/Localization.lua"))("WhisperMessenger", ns)
  Localization.Configure({
    language = language,
    getLocale = function()
      return clientLocale or "enUS"
    end,
  })
  return Localization, ns
end

return function()
  -- test_release_keeps_active_catalog
  do
    local Localization, ns = fresh("deDE")
    Localization.ReleaseUnusedCatalogs()
    assert(ns.Locale_deDE ~= nil, "the active catalog stays in ns")
    assert(ns.Locale_ruRU == nil, "other catalogs leave ns")
    assert(Localization.Text("Hello") == "Hallo", "the active language still translates")
    assert(Localization.IsLanguageLoaded("deDE") == true, "the active language counts as loaded")
    assert(Localization.IsLanguageLoaded("ruRU") == false, "a released language does not count as loaded")
  end

  -- test_release_for_english_keeps_none
  do
    local Localization, ns = fresh("enUS")
    Localization.ReleaseUnusedCatalogs()
    assert(ns.Locale_deDE == nil and ns.Locale_ruRU == nil, "English needs no catalog")
    assert(Localization.IsLanguageLoaded("deDE") == false, "German was released")
    assert(Localization.IsLanguageLoaded("enUS") == true, "English is always available")
  end

  -- test_all_loaded_before_release
  do
    local Localization = fresh("enUS")
    assert(Localization.IsLanguageLoaded("deDE") == true, "German is loaded before release")
    assert(Localization.IsLanguageLoaded("ruRU") == true, "Russian is loaded before release")
  end

  -- test_auto_values_mean_client_locale
  do
    local Localization = fresh("enUS", "deDE")
    Localization.ReleaseUnusedCatalogs()
    for _, value in ipairs({ "", "auto", "bogus" }) do
      assert(Localization.IsLanguageLoaded(value) == false, "'" .. value .. "' means the client's released German")
    end
    assert(Localization.IsLanguageLoaded(nil) == false, "nil means the client's released German, not the configured English")

    local english = fresh("enUS", "enUS")
    english.ReleaseUnusedCatalogs()
    for _, value in ipairs({ "", "auto", "bogus" }) do
      assert(english.IsLanguageLoaded(value) == true, "'" .. value .. "' means the client's English")
    end
    assert(english.IsLanguageLoaded(nil) == true, "nil means the client's English")
  end

  -- test_release_under_auto_keeps_client_locale
  do
    local Localization, ns = fresh("auto", "deDE")
    Localization.ReleaseUnusedCatalogs()
    assert(ns.Locale_deDE ~= nil, "auto keeps the client's catalog")
    assert(ns.Locale_ruRU == nil, "auto drops the others")
    assert(Localization.Text("Hello") == "Hallo", "auto still translates")
  end

  -- test_released_language_falls_back_to_english
  do
    local Localization = fresh("deDE")
    Localization.ReleaseUnusedCatalogs()
    assert(Localization.Text("Hello", "ruRU") == "Hello", "a released language returns the English key")
  end

  -- test_release_twice_is_safe
  do
    local Localization, ns = fresh("deDE")
    Localization.ReleaseUnusedCatalogs()
    Localization.ReleaseUnusedCatalogs()
    assert(ns.Locale_deDE ~= nil, "a second release keeps the active catalog")
    assert(Localization.Text("Hello") == "Hallo", "a second release keeps translating")
  end
end
