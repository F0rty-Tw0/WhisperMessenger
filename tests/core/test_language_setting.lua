local LanguageSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.LanguageSetting")
local ReloadPrompt = require("WhisperMessenger.UI.Shared.ReloadPrompt")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local withPopups = require("tests.helpers.reload_popups").With

local function stubLocalization(loaded)
  return {
    IsLanguageLoaded = function(language)
      return loaded[language or "auto"] == true
    end,
  }
end

local function makeRuntime()
  local restored = {}
  return {
    store = { config = {} },
    window = {
      refreshLanguage = function(language)
        restored[#restored + 1] = language
      end,
    },
  },
    restored
end

local function accept()
  _G.StaticPopupDialogs[ReloadPrompt.DIALOG].OnAccept()
end

local function cancel()
  _G.StaticPopupDialogs[ReloadPrompt.DIALOG].OnCancel(nil, nil, "clicked")
end

local function testApply()
  -- test_loaded_language_returns_false_without_prompt
  withPopups(function(popups)
    local settings = {}
    local handled = LanguageSetting.Apply(settings, "deDE", makeRuntime(), stubLocalization({ deDE = true }))
    assert(handled == false, "a loaded language stays with the caller")
    assert(#popups.shown == 0, "a loaded language shows no prompt")
    assert(settings.interfaceLanguage == nil, "Apply saves nothing for a loaded language")
  end)

  -- test_unloaded_language_prompts_and_saves_nothing
  withPopups(function(popups)
    local settings = { interfaceLanguage = "deDE" }
    local handled = LanguageSetting.Apply(settings, "ruRU", makeRuntime(), stubLocalization({}))
    assert(handled == true, "an unloaded language is handled here")
    assert(popups.shown[1] == ReloadPrompt.DIALOG, "an unloaded language shows the prompt")
    assert(settings.interfaceLanguage == "deDE", "nothing is saved while the prompt is up")
    cancel()
  end)

  -- test_reset_auto_unloaded_prompts_with_pending_auto
  withPopups(function()
    local settings = { interfaceLanguage = "enUS" }
    assert(LanguageSetting.Apply(settings, "auto", makeRuntime(), stubLocalization({})) == true, "auto with no catalog prompts")
    accept()
    assert(settings.interfaceLanguage == "auto", "accept saves auto")
  end)

  -- test_nil_value_is_pending_auto
  withPopups(function()
    local settings = { interfaceLanguage = "enUS" }
    assert(LanguageSetting.Apply(settings, nil, makeRuntime(), stubLocalization({})) == true, "nil with no catalog prompts")
    accept()
    assert(settings.interfaceLanguage == "auto", "nil is saved as auto")
  end)

  -- test_accept_saves_pending
  withPopups(function(popups)
    local settings = { interfaceLanguage = "deDE" }
    LanguageSetting.Apply(settings, "ruRU", makeRuntime(), stubLocalization({}))
    accept()
    assert(settings.interfaceLanguage == "ruRU", "accept saves the choice")
    assert(popups.reloads == 1, "accept reloads the interface")
  end)

  -- test_cancel_restores_selector
  withPopups(function(popups)
    local settings = { interfaceLanguage = "deDE" }
    local runtime, restored = makeRuntime()
    LanguageSetting.Apply(settings, "ruRU", runtime, stubLocalization({}))
    cancel()
    assert(restored[1] == "deDE", "cancel shows the saved language again")
    assert(settings.interfaceLanguage == "deDE", "cancel saves nothing")
    assert(popups.reloads == 0, "cancel does not reload")
  end)

  -- test_cancel_with_nothing_saved_restores_auto
  withPopups(function()
    local runtime, restored = makeRuntime()
    LanguageSetting.Apply({}, "ruRU", runtime, stubLocalization({}))
    cancel()
    assert(restored[1] == "auto", "with nothing saved, cancel shows auto")
  end)

  -- test_cancel_without_window_is_safe
  withPopups(function()
    local settings = { interfaceLanguage = "deDE" }
    LanguageSetting.Apply(settings, "ruRU", { store = { config = {} } }, stubLocalization({}))
    cancel()
    assert(settings.interfaceLanguage == "deDE", "cancel with no window saves nothing")
  end)

  -- test_second_unloaded_pick_replaces_pending
  withPopups(function()
    local settings = { interfaceLanguage = "deDE" }
    local localization = stubLocalization({})
    LanguageSetting.Apply(settings, "ruRU", makeRuntime(), localization)
    LanguageSetting.Apply(settings, "frFR", makeRuntime(), localization)
    accept()
    assert(settings.interfaceLanguage == "frFR", "accept saves the latest pick")
  end)

  -- test_loaded_pick_while_prompt_up_hides_it
  withPopups(function(popups)
    local settings = { interfaceLanguage = "deDE" }
    local localization = stubLocalization({ enUS = true })
    LanguageSetting.Apply(settings, "ruRU", makeRuntime(), localization)
    assert(LanguageSetting.Apply(settings, "enUS", makeRuntime(), localization) == false, "a loaded pick stays live")
    assert(popups.hidden[1] == ReloadPrompt.DIALOG, "a loaded pick closes the prompt")
    accept()
    assert(settings.interfaceLanguage == "deDE", "accepting the closed prompt saves nothing")
  end)

  -- test_loaded_pick_with_no_prompt_does_not_hide
  withPopups(function(popups)
    LanguageSetting.Apply({}, "deDE", makeRuntime(), stubLocalization({ deDE = true }))
    assert(#popups.hidden == 0, "another setting's prompt may be up, so leave it alone")
  end)

  -- test_stub_without_check_counts_as_loaded
  withPopups(function(popups)
    assert(LanguageSetting.Apply({}, "ruRU", makeRuntime(), {}) == false, "no check means loaded")
    assert(#popups.shown == 0, "no check shows no prompt")
  end)
end

local function makeHandler(localization)
  local configured = {}
  localization.Configure = localization.Configure or function(options)
    configured[#configured + 1] = options.language
  end
  local settings = {}
  local onChange = SettingsHandler.Create({
    runtime = makeRuntime(),
    accountSettings = settings,
    localization = localization,
    fonts = {},
  })
  return onChange, settings, configured
end

local function testHandler()
  -- test_handler_unloaded_skips_save_and_configure
  withPopups(function()
    local onChange, settings, configured = makeHandler(stubLocalization({}))
    onChange("interfaceLanguage", "ruRU")
    assert(settings.interfaceLanguage == nil, "an unloaded language isn't saved")
    assert(#configured == 0, "an unloaded language isn't applied")
    cancel()
  end)

  -- test_handler_same_effective_language_stays_live
  withPopups(function(popups)
    local onChange, settings, configured = makeHandler(stubLocalization({ deDE = true }))
    onChange("interfaceLanguage", "deDE")
    assert(settings.interfaceLanguage == "deDE", "a loaded language is saved")
    assert(configured[1] == "deDE", "a loaded language is applied")
    assert(#popups.shown == 0, "a loaded language shows no prompt")
  end)

  -- test_handler_switch_back_stays_live
  withPopups(function(popups)
    local onChange, settings = makeHandler(stubLocalization({ deDE = true, enUS = true }))
    onChange("interfaceLanguage", "enUS")
    onChange("interfaceLanguage", "deDE")
    assert(settings.interfaceLanguage == "deDE", "switching back saves")
    assert(#popups.shown == 0, "switching back shows no prompt")
  end)

  -- test_handler_real_catalogs_under_auto_client_locale
  withPopups(function(popups)
    local localization = assert(loadfile("Locale/Localization.lua"))("WhisperMessenger", {
      Locale_deDE = { Hello = "Hallo" },
      Locale_ruRU = { Hello = "Privet" },
    })
    localization.Configure({
      language = "auto",
      getLocale = function()
        return "deDE"
      end,
    })
    localization.ReleaseUnusedCatalogs()
    assert(localization.Text("Hello") == "Hallo", "auto keeps the client's language")

    local onChange, settings = makeHandler(localization)
    onChange("interfaceLanguage", "deDE")
    assert(settings.interfaceLanguage == "deDE", "the client's language saves live")
    onChange("interfaceLanguage", "auto")
    assert(settings.interfaceLanguage == "auto", "auto saves live when it means a loaded language")
    assert(#popups.shown == 0, "no prompt so far")
    onChange("interfaceLanguage", "ruRU")
    assert(popups.shown[1] == ReloadPrompt.DIALOG, "a released language prompts")
    assert(settings.interfaceLanguage == "auto", "a released language isn't saved")
    cancel()
  end)
end

return function()
  testApply()
  testHandler()
end
