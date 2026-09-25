local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local SettingsPanels = ns.MessengerWindowSettingsPanels or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local LanguageRefresh = {}

local GENERAL_SETTINGS_INDEX = 1
-- What's New is the last settings page.
local LAST_SETTINGS_INDEX = SettingsPanels.PATCH_NOTES_INDEX

-- Returns refreshLanguage(lang): re-resolves every window label from the
-- active Localization catalog.
-- options: layout, composer, settingsRuntime, settingsConfig,
-- contactsRuntime, relayoutCurrentSize, conversation, scriptResult,
-- refreshContacts, getCurrentContacts, selectionController
function LanguageRefresh.Create(options)
  local layout = options.layout
  local composer = options.composer
  local settingsRuntime = options.settingsRuntime
  local settingsConfig = options.settingsConfig
  local contactsRuntime = options.contactsRuntime
  local conversation = options.conversation
  local scriptResult = options.scriptResult
  local refreshContacts = options.refreshContacts
  local selectionController = options.selectionController

  return function(lang)
    -- GeneralSettings.applyLanguage uses `nextLanguage or DEFAULTS.interfaceLanguage`,
    -- so calling it with nil silently resets the panel to "auto" and unselects
    -- the user's choice in the language selector. Resolve the live setting
    -- when the caller doesn't pass an explicit language.
    local effectiveLang = lang or settingsConfig.interfaceLanguage
    -- Each child widget owns the labels it created and re-resolves them from
    -- the active Localization catalog. Call them in dependency order so a
    -- StatusLine.Build() that runs during the contacts refresh sees fresh
    -- catalog state.
    if layout.setLanguage then
      layout.setLanguage()
    end
    if composer.setLanguage then
      composer.setLanguage()
    end
    for index = 1, LAST_SETTINGS_INDEX do
      local settings = settingsRuntime.getSettings(index)
      if settings and settings.setLanguage then
        if index == GENERAL_SETTINGS_INDEX then
          settings.setLanguage(effectiveLang)
        else
          settings.setLanguage()
        end
      end
    end
    if contactsRuntime and contactsRuntime.tabToggle and contactsRuntime.tabToggle.setLanguage then
      contactsRuntime.tabToggle.setLanguage()
      options.relayoutCurrentSize()
    end
    if conversation then
      ConversationPane.SetLanguage(conversation)
    end
    if scriptResult and scriptResult.setLanguage then
      scriptResult.setLanguage()
    end
    -- Force a contacts refresh so dynamic labels (group channel labels,
    -- the "no group chats yet" empty state, contact preview timestamps)
    -- pick up the new locale.
    if refreshContacts then
      refreshContacts(options.getCurrentContacts(), selectionController and selectionController.getSelectedConversationKey() or nil, false)
    end
  end
end

ns.MessengerWindowLanguageRefresh = LanguageRefresh

return LanguageRefresh
