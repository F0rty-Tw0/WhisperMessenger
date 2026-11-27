-- New Whisper on WoW: Forever with the gamepad UI on: showing Blizzard's
-- StaticPopup from addon code taints the game's gamepad bindings, so the
-- name is asked for in the addon's own popup instead. Everywhere else the
-- StaticPopup stays.
local FakeUI = require("tests.helpers.fake_ui")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")
local StartConversationDialog = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")

local DIALOG_NAME = "WHISPER_MESSENGER_START_CONVERSATION"

local function typeInto(box, text)
  box:SetText(text)
  local onTextChanged = box:GetScript("OnTextChanged")
  if onTextChanged then
    onTextChanged(box, true)
  end
end

return function()
  local savedUsesOwnMenus = FlavorCompat.UsesOwnMenus
  local savedCreateFrame = _G.CreateFrame
  local savedStaticPopupShow = _G.StaticPopup_Show
  local savedDialogs = _G.StaticPopupDialogs

  local factory = FakeUI.NewFactory()
  local ownPopup = nil
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    if name == TwoFieldDialog.FRAME_NAME then
      ownPopup = frame
    end
    return frame
  end)
  local staticShown = {}
  rawset(_G, "StaticPopup_Show", function(which)
    table.insert(staticShown, which)
    return nil
  end)
  _G.StaticPopupDialogs = {}

  local usesOwnMenus = true
  rawset(FlavorCompat, "UsesOwnMenus", function()
    return usesOwnMenus
  end)

  local started = {}
  local button = factory.CreateFrame("Button", nil, nil)
  StartConversationDialog.Wire(button, {
    onStartConversation = function(playerName)
      table.insert(started, playerName)
    end,
  })

  local ok, err = pcall(function()
    -- test_own_menus_open_the_addon_popup_not_the_static_popup
    do
      button:GetScript("OnClick")(button, "LeftButton")
      assert(#staticShown == 0, "Blizzard's StaticPopup must not open while WM uses its own menus")
      assert(ownPopup ~= nil and ownPopup:IsShown(), "the addon's own name popup opens")
      assert(ownPopup.title:GetText() == "Start a new conversation", "same title as the StaticPopup")
      assert(ownPopup.acceptButton.label:GetText() == "Start", "Start button")
      assert(ownPopup.cancelButton.label:GetText() == "Cancel", "Cancel button")
      assert(not ownPopup.firstInput:IsShown(), "only one field")
      assert(ownPopup.secondInput:HasFocus(), "the name field takes focus")
      assert(ownPopup.secondInput.maxLetters == 255, "255 letters at most")
    end

    -- test_own_popup_starts_the_trimmed_name
    do
      typeInto(ownPopup.secondInput, "  Name-Realm  ")
      ownPopup.secondInput:GetScript("OnEnterPressed")(ownPopup.secondInput)
      assert(#started == 1 and started[1] == "Name-Realm", "trimmed name started")
      assert(not ownPopup:IsShown(), "closed after Start")
    end

    -- test_own_popup_with_an_empty_name_starts_nothing
    do
      StartConversationDialog.Open()
      assert(ownPopup.secondInput:GetText() == "", "reopened empty")
      typeInto(ownPopup.secondInput, "   ")
      ownPopup.acceptButton:GetScript("OnClick")(ownPopup.acceptButton)
      ownPopup.secondInput:GetScript("OnEnterPressed")(ownPopup.secondInput)
      assert(#started == 1, "an empty name starts nothing")
      ownPopup:Hide()
    end

    -- test_without_own_menus_the_static_popup_still_opens
    do
      usesOwnMenus = false
      StartConversationDialog.Open()
      assert(#staticShown == 1 and staticShown[1] == DIALOG_NAME, "StaticPopup path unchanged")
      assert(not ownPopup:IsShown(), "the addon popup stays closed")
    end
  end)

  rawset(FlavorCompat, "UsesOwnMenus", savedUsesOwnMenus)
  rawset(_G, "CreateFrame", savedCreateFrame)
  rawset(_G, "StaticPopup_Show", savedStaticPopupShow)
  _G.StaticPopupDialogs = savedDialogs
  assert(ok, err)
end
