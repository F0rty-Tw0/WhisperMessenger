-- focused start-conversation dialog regression
local FakeUI = require("tests.helpers.fake_ui")
local StartConversationDialog =
  require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")

local function noop() end

local function makePopupButton(factory, parent, name)
  local button = factory.CreateFrame("Button", name, parent)
  button._normalTexture = "orig-normal-" .. tostring(name)
  function button:GetNormalTexture()
    return self._normalTexture
  end
  function button:SetNormalTexture(value)
    self._normalTexture = value
  end
  button.text = factory.CreateFrame("FontString", nil, button)
  return button
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Case 1: dialog is registered with required handlers
  do
    _G.StaticPopupDialogs = {}
    local newConversationButton = factory.CreateFrame("Frame", nil, parent)

    StartConversationDialog.Wire(newConversationButton, {
      onStartConversation = noop,
    })

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    assert(dialog ~= nil, "expected dialog to be registered")
    assert(type(dialog.OnAccept) == "function", "expected OnAccept handler")
    assert(type(dialog.OnShow) == "function", "expected OnShow handler")
    assert(type(dialog.OnHide) == "function", "expected OnHide handler")
    assert(
      type(newConversationButton.scripts) == "table" and type(newConversationButton.scripts.OnClick) == "function",
      "expected OnClick wired on new-conversation button"
    )
    _G.StaticPopupDialogs = nil
  end

  -- Case 2: OnAccept forwards trimmed name
  do
    _G.StaticPopupDialogs = {}
    local startedPlayerName = nil
    local newConversationButton = factory.CreateFrame("Frame", nil, parent)

    StartConversationDialog.Wire(newConversationButton, {
      onStartConversation = function(playerName)
        startedPlayerName = playerName
      end,
    })

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    dialog.OnAccept({
      editBox = {
        GetText = function()
          return "   Jaina Proudmoore   "
        end,
      },
    })
    assert(startedPlayerName == "Jaina Proudmoore", "expected trimmed player name forwarded to callback")
    _G.StaticPopupDialogs = nil
  end

  -- Case 3: whitespace-only input is rejected
  do
    _G.StaticPopupDialogs = {}
    local callbackCount = 0
    local newConversationButton = factory.CreateFrame("Frame", nil, parent)

    StartConversationDialog.Wire(newConversationButton, {
      onStartConversation = function(_)
        callbackCount = callbackCount + 1
      end,
    })

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    dialog.OnAccept({
      editBox = {
        GetText = function()
          return " \n\t "
        end,
      },
    })
    assert(callbackCount == 0, "expected callback to be skipped for whitespace-only input")
    _G.StaticPopupDialogs = nil
  end

  -- Case 4: OnShow / OnHide drive styling lifecycle
  do
    _G.StaticPopupDialogs = {}
    local newConversationButton = factory.CreateFrame("Frame", nil, parent)

    StartConversationDialog.Wire(newConversationButton, {
      onStartConversation = noop,
    })

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]

    local fakePopup = factory.CreateFrame("Frame", nil, parent)
    fakePopup:SetWidth(420)
    fakePopup.editBox = factory.CreateFrame("EditBox", nil, fakePopup)
    fakePopup.editBox:SetText("")
    fakePopup.button1 = makePopupButton(factory, parent, "start")
    fakePopup.button2 = makePopupButton(factory, parent, "cancel")
    fakePopup.text = factory.CreateFrame("FontString", nil, fakePopup)

    local showOk = pcall(dialog.OnShow, fakePopup, "Thrall")
    assert(showOk == true, "expected OnShow to run safely")
    assert(fakePopup._wmManualCopyStyleActive == true, "expected style to activate on show")
    assert(fakePopup.editBox.text == "Thrall", "expected OnShow to prime editbox text")

    local hideOk = pcall(dialog.OnHide, fakePopup)
    assert(hideOk == true, "expected OnHide to run safely")
    assert(fakePopup._wmManualCopyStyleActive == false, "expected style to restore on hide")
    assert(fakePopup.editBox.text == "", "expected OnHide to clear editbox text")
    _G.StaticPopupDialogs = nil
  end
end
