-- Native WoW HUD: the start-conversation and manual-copy popups are Blizzard
-- StaticPopups. In HUD mode the modern reskin is skipped so the stock dialog
-- border, InputBoxTemplate edit box and UIPanelButtonTemplate buttons show
-- through; the text prime / highlight / focus / width behaviour stays.
local FakeUI = require("tests.helpers.fake_ui")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local StartConversationDialog = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")
local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

local function makeButton(factory, parent, name)
  local button = factory.CreateFrame("Button", name, parent)
  button._normalTexture = "orig-normal-" .. name
  function button:GetNormalTexture()
    return self._normalTexture
  end
  function button:SetNormalTexture(value)
    self._normalTexture = value
  end
  button.text = factory.CreateFrame("FontString", nil, button)
  return button
end

local function makePopup(factory, parent)
  local popup = factory.CreateFrame("Frame", nil, parent)
  popup:SetWidth(420)
  popup.editBox = factory.CreateFrame("EditBox", nil, popup)
  popup.button1 = makeButton(factory, popup, "b1")
  popup.button2 = makeButton(factory, popup, "b2")
  popup.text = factory.CreateFrame("FontString", nil, popup)
  return popup
end

local function assertUnstyled(popup, label)
  assert(popup._wmManualCopyStyleActive == nil, label .. ": dialog must not be reskinned")
  assert(popup._wmRoundedBackground == nil, label .. ": no rounded background")
  assert(popup.button1._normalTexture == "orig-normal-b1", label .. ": button1 keeps Blizzard art")
  assert(popup.button2._normalTexture == "orig-normal-b2", label .. ": button2 keeps Blizzard art")
end

local function buildWindow(factory, nativeChrome)
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  MessengerWindow.Create(factory, {
    contacts = {},
    settingsConfig = { showGroupChats = true, nativeChrome = nativeChrome },
  })
  _G.UIParent = savedUIParent
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local savedDialogs = _G.StaticPopupDialogs
  local savedShow = _G.StaticPopup_Show
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil

  -- test_window_build_sets_native_popup_flag_from_settings
  do
    buildWindow(factory, true)
    assert(StyledTextInputPopup.nativeChrome == true, "HUD window must flag popups native")
    buildWindow(factory, false)
    assert(StyledTextInputPopup.nativeChrome == false, "modern window must clear the native flag")
  end

  -- test_modern_apply_still_reskins_popup (regression)
  do
    StyledTextInputPopup.nativeChrome = false
    local popup = makePopup(factory, parent)
    StyledTextInputPopup.Apply(popup, "WM_TEST", "x", { styleSecondaryButton = true })
    assert(popup._wmManualCopyStyleActive == true, "modern: dialog reskinned")
    assert(popup._wmRoundedBackground ~= nil, "modern: rounded background created")
    assert(popup.button2._normalTexture ~= "orig-normal-b2", "modern: secondary button reskinned")
  end

  -- test_native_start_conversation_dialog_keeps_blizzard_look_and_behaviour
  do
    StyledTextInputPopup.nativeChrome = true
    _G.StaticPopupDialogs = {}
    StartConversationDialog.Wire(factory.CreateFrame("Button", nil, parent), { onStartConversation = function() end })
    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    local popup = makePopup(factory, parent)
    dialog.OnShow(popup, "Thrall")
    assertUnstyled(popup, "native start dialog")
    assert(popup.editBox:GetText() == "Thrall", "native start dialog: edit box primed")
    assert(popup.editBox:HasFocus(), "native start dialog: edit box focused")
    assert(popup.editBox:GetWidth() == 392, "native start dialog: input width kept")
    dialog.OnHide(popup)
    assertUnstyled(popup, "native start dialog after hide")
    assert(popup.editBox:GetText() == "", "native start dialog: edit box cleared on hide")
  end

  -- test_native_manual_copy_dialog_keeps_blizzard_look_and_behaviour
  do
    StyledTextInputPopup.nativeChrome = true
    _G.StaticPopupDialogs = {}
    local popup = makePopup(factory, parent)
    rawset(_G, "StaticPopup_Show", function(which, _t1, _t2, data)
      _G.StaticPopupDialogs[which].OnShow(popup, data)
      return popup
    end)
    assert(PopupUI.ShowManualCopyDialog("copy me") == true, "native copy dialog shown")
    assertUnstyled(popup, "native copy dialog")
    assert(popup.editBox:GetText() == "copy me", "native copy dialog: text primed")
    assert(popup.editBox:HasFocus(), "native copy dialog: edit box focused")
  end

  StyledTextInputPopup.nativeChrome = false
  _G.StaticPopupDialogs = savedDialogs
  rawset(_G, "StaticPopup_Show", savedShow)
  _G.C_Timer = savedTimer
end
