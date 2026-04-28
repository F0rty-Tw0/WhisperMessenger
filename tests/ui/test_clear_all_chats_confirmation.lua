local FakeUI = require("tests.helpers.fake_ui")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local function noop() end

  -- test_clear_all_chats_shows_confirmation_instead_of_clearing_immediately

  do
    local clearCalled = false
    local popupShown = nil

    rawset(_G, "StaticPopup_Show", function(dialogName)
      popupShown = dialogName
    end)

    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = function()
        clearCalled = true
      end,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)
    clearAllChatsButton.scripts.OnClick(clearAllChatsButton)

    assert(
      popupShown == "WHISPER_MESSENGER_CLEAR_ALL_CHATS",
      "test_clear_all_chats_shows_confirmation: expected StaticPopup_Show to be called with dialog name, got: " .. tostring(popupShown)
    )
    assert(clearCalled == false, "test_clear_all_chats_shows_confirmation: onClearAllChats should NOT be called before confirmation")

    rawset(_G, "StaticPopup_Show", nil)
  end

  -- test_confirmation_accept_calls_clear_and_refreshes

  do
    local clearCalled = false
    local refreshArgs = nil

    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}

    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = function()
        clearCalled = true
      end,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = function(data, force)
        refreshArgs = { data = data, force = force }
      end,
    }

    WindowScripts.WireButtons(refs, options)

    -- Simulate the user pressing "Accept" on the confirmation dialog
    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_CLEAR_ALL_CHATS"]
    assert(dialog ~= nil, "test_confirmation_accept: expected dialog to be registered")
    assert(type(dialog.OnAccept) == "function", "test_confirmation_accept: expected OnAccept handler")

    dialog.OnAccept()

    assert(clearCalled == true, "test_confirmation_accept: expected onClearAllChats to be called after accept")
    assert(refreshArgs ~= nil, "test_confirmation_accept: expected refreshSelection to be called after accept")
    assert(refreshArgs.data.selectedContact == nil, "test_confirmation_accept: expected selectedContact to be nil")
    assert(refreshArgs.force == true, "test_confirmation_accept: expected force refresh")

    _G.StaticPopupDialogs = nil
  end

  -- test_confirmation_dialog_has_correct_text

  do
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}

    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_CLEAR_ALL_CHATS"]
    assert(type(dialog.text) == "string", "test_dialog_text: expected text string")
    assert(
      string.find(dialog.text, "delete", 1, true) or string.find(dialog.text, "Delete", 1, true),
      "test_dialog_text: dialog text should mention deletion"
    )
    assert(dialog.button1 ~= nil, "test_dialog_text: expected accept button text")
    assert(dialog.button2 ~= nil, "test_dialog_text: expected cancel button text")

    _G.StaticPopupDialogs = nil
  end
end
