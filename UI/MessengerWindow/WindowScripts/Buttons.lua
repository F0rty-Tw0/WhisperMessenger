local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local SettingsTabs = ns.MessengerWindowWindowScriptsButtonsSettingsTabs
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")
local StartConversationDialog = ns.MessengerWindowWindowScriptsButtonsStartConversationDialog
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")

local Buttons = {}

-- Wire close, options, reset-window, reset-icon, clear-all-chats, and
-- settings tab buttons.
--
-- refs:
--   closeButton, optionsButton, newConversationButton, resetWindowButton,
--   resetIconButton, clearAllChatsButton, optionsPanel, settingsPanels,
--   settingsTabs
--
-- options:
--   onClose, onStartConversation, onResetWindowPosition,
--   onResetIconPosition, onClearAllChats, setOptionsVisible, isShown,
--   applyState, refreshSelection
function Buttons.WireButtons(refs, options)
  local closeButton = refs.closeButton
  local optionsButton = refs.optionsButton
  local newConversationButton = refs.newConversationButton
  local resetWindowButton = refs.resetWindowButton
  local resetIconButton = refs.resetIconButton
  local clearAllChatsButton = refs.clearAllChatsButton
  local optionsPanel = refs.optionsPanel
  local settingsPanels = refs.settingsPanels or {}
  local settingsTabs = refs.settingsTabs or {}
  local optionsScrollView = refs.optionsScrollView

  if closeButton and closeButton.SetScript then
    closeButton:SetScript("OnClick", function()
      options.onClose()
    end)
  end

  if optionsButton and optionsButton.SetScript then
    optionsButton:SetScript("OnClick", function()
      options.setOptionsVisible(not options.isShown(optionsPanel))
    end)
  end

  if resetWindowButton and resetWindowButton.SetScript then
    resetWindowButton:SetScript("OnClick", function()
      if options.onResetWindowPosition == nil then
        return
      end
      local nextState = options.onResetWindowPosition()
      if nextState ~= nil then
        options.applyState(nextState)
      end
    end)
  end

  if resetIconButton and resetIconButton.SetScript then
    resetIconButton:SetScript("OnClick", function()
      if options.onResetIconPosition then
        options.onResetIconPosition()
      end
    end)
  end

  local startConversationResult = StartConversationDialog.Wire(newConversationButton, {
    onStartConversation = options.onStartConversation,
  }) or {}

  local clearAllPopupSetLanguage = function() end
  if clearAllChatsButton and clearAllChatsButton.SetScript then
    local dialogName = "WHISPER_MESSENGER_CLEAR_ALL_CHATS"
    if not _G.StaticPopupDialogs then
      _G.StaticPopupDialogs = {}
    end
    -- Build (or rebuild) the dialog table from current Localization. Stored
    -- as a function so a runtime language switch can re-register without a
    -- /reload — the StaticPopupDialogs entry is read literally each Show.
    local function registerPopup()
      _G.StaticPopupDialogs[dialogName] = {
        text = Localization.Text("Are you sure you want to clear all chats?\n\nThis will permanently delete all conversation history."),
        button1 = Localization.Text("Clear All"),
        button2 = Localization.Text("Cancel"),
        OnAccept = function()
          if options.onClearAllChats then
            options.onClearAllChats()
            options.refreshSelection({
              contacts = {},
              selectedContact = nil,
              conversation = nil,
              status = nil,
            }, true)
          end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
    end
    registerPopup()
    clearAllPopupSetLanguage = registerPopup

    clearAllChatsButton:SetScript("OnClick", function()
      _G.StaticPopup_Show(dialogName)
    end)
  end

  SettingsTabs.Wire({
    optionsPanel = optionsPanel,
    optionsScrollView = optionsScrollView,
    settingsTabs = settingsTabs,
    settingsPanels = settingsPanels,
  })

  return {
    setLanguage = function()
      clearAllPopupSetLanguage()
      if startConversationResult.setLanguage then
        startConversationResult.setLanguage()
      end
    end,
  }
end

ns.MessengerWindowWindowScriptsButtons = Buttons

return Buttons
