local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local SettingsTabs = ns.MessengerWindowWindowScriptsButtonsSettingsTabs
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

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

  local function trimPlayerName(value)
    if type(value) ~= "string" then
      return nil
    end

    local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
    if trimmed == "" then
      return nil
    end

    return trimmed
  end

  local function resolveConversationPopupEditBox(popup, dialogName)
    local resolved = StyledTextInputPopup.ResolveEditBox(popup, dialogName)
    if resolved ~= nil then
      return resolved
    end
    if type(popup) ~= "table" then
      return nil
    end
    if type(popup.editBox) == "table" then
      return popup.editBox
    end
    if type(popup.EditBox) == "table" then
      return popup.EditBox
    end
    if type(popup.GetEditBox) == "function" then
      local ok, editBox = pcall(popup.GetEditBox, popup)
      if ok then
        return editBox
      end
    end
    return nil
  end

  local function styleStartConversationDialog(popup, dialogName, value)
    StyledTextInputPopup.Apply(popup, dialogName, value, {
      styleSecondaryButton = true,
      fullWidthInput = true,
      inputHorizontalPadding = 14,
      minInputWidth = 260,
    })
  end

  local function restoreStartConversationDialog(popup, dialogName)
    StyledTextInputPopup.Restore(popup, dialogName, {
      styleSecondaryButton = true,
      clearEditBox = true,
    })
  end

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

  if newConversationButton and newConversationButton.SetScript and options.onStartConversation then
    local dialogName = "WHISPER_MESSENGER_START_CONVERSATION"
    if type(_G.StaticPopupDialogs) ~= "table" then
      _G.StaticPopupDialogs = {}
    end

    local dialog = _G.StaticPopupDialogs[dialogName]
    if type(dialog) ~= "table" then
      dialog = {
        text = "Start a new conversation",
        button1 = "Start",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 340,
        maxLetters = 255,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      _G.StaticPopupDialogs[dialogName] = dialog
    end

    dialog.OnAccept = function(popup)
      local editBox = resolveConversationPopupEditBox(popup, dialogName)
      local playerName = trimPlayerName(editBox and editBox.GetText and editBox:GetText() or nil)
      if playerName ~= nil and dialog._wmOnStartConversation then
        dialog._wmOnStartConversation(playerName)
      end
    end
    dialog._wmOnStartConversation = options.onStartConversation
    dialog.OnShow = function(popup, data)
      local value = tostring((popup and popup.data) or data or "")
      styleStartConversationDialog(popup, dialogName, value)
    end
    dialog.OnHide = function(popup)
      restoreStartConversationDialog(popup, dialogName)
    end

    newConversationButton:SetScript("OnClick", function()
      if type(_G.StaticPopup_Show) ~= "function" then
        return
      end

      local popup = _G.StaticPopup_Show(dialogName)
      if type(popup) == "table" then
        popup.data = ""
        styleStartConversationDialog(popup, dialogName, "")
      end

      local editBox = resolveConversationPopupEditBox(popup, dialogName) or _G.StaticPopup1EditBox
      if editBox and editBox.SetFocus then
        editBox:SetFocus()
      end
    end)
  end

  if clearAllChatsButton and clearAllChatsButton.SetScript then
    local dialogName = "WHISPER_MESSENGER_CLEAR_ALL_CHATS"
    if not _G.StaticPopupDialogs then
      _G.StaticPopupDialogs = {}
    end
    _G.StaticPopupDialogs[dialogName] = {
      text = "Are you sure you want to clear all chats?\n\nThis will permanently delete all conversation history.",
      button1 = "Clear All",
      button2 = "Cancel",
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
end

ns.MessengerWindowWindowScriptsButtons = Buttons

return Buttons
