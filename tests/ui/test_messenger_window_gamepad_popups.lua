local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local Localization = require("WhisperMessenger.Locale.Localization")
local StyledTextInputPopup = require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadWiring")
local ReactionPicker = require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local DeliveryMenu = require("WhisperMessenger.UI.ChatBubble.DeliveryMenu")
local ExportPanel = require("WhisperMessenger.UI.ContactsList.ExportPanel")
local TwoFieldDialog = require("WhisperMessenger.UI.Shared.TwoFieldDialog")

local noop = function() end

local function refs()
  return {
    compactMode = {
      onBack = function()
        return false
      end,
    },
    windowVisibility = {
      getVisiblePanel = noop,
      isConversationPaneShown = function()
        return true
      end,
      setOptionsVisible = noop,
      setPanelVisible = noop,
      closeWindow = noop,
    },
  }
end

local OPENERS = {
  reaction = function(factory, anchor)
    ReactionPicker.Open(factory, anchor, { direction = "in", text = "hi" }, noop, noop, nil, noop)
    return ReactionPicker.GetFrame()
  end,
  delivery = function(factory, anchor)
    DeliveryMenu.Open(factory, anchor, { direction = "out", text = "hi", delivery = "failed" }, { "retry", "discard" }, noop)
    return DeliveryMenu.GetFrame()
  end,
  export = function(factory)
    return ExportPanel.Show({ title = "Arthas", header = "Conversation with Arthas", lines = { "a", "b" } }, factory)
  end,
  twoField = function(factory)
    return TwoFieldDialog.Show(factory, {
      title = "Add rule…",
      accept = "Add",
      firstLabel = "Name (optional)",
      secondLabel = "Words",
      hint = "wts/wtb: either word is enough.",
      firstMaxLetters = 48,
      secondMaxLetters = 255,
      onAccept = noop,
    })
  end,
}

-- Runs fn(env, factory, frame, nav) with a wired, shown window; restores globals and clears the hooks.
local function withWindow(overrides, fn)
  Localization.Configure({ language = "enUS" })
  local savedUIParent, savedSpecial, savedNative = _G.UIParent, _G.UISpecialFrames, StyledTextInputPopup.nativeChrome
  StyledTextInputPopup.nativeChrome = false
  local env = FakeGamepad.New()
  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UISpecialFrames = {}
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", _G.UIParent)
  local nav = GamepadNav.New(frame, env.deps(overrides))
  GamepadWiring.Create({ frame = frame }, nav).attach(refs())
  frame:Show()
  local ok, err = pcall(fn, env, factory, frame, nav)
  PickerPopup.SetGamepadPopupHooks(nil, nil)
  _G.UIParent, _G.UISpecialFrames, StyledTextInputPopup.nativeChrome = savedUIParent, savedSpecial, savedNative
  assert(ok, err)
end

local function callsFor(env, name, frame)
  local n = 0
  for _, c in ipairs(env.calls) do
    n = n + ((c.name == name and c.args[1] == frame) and 1 or 0)
  end
  return n
end

return function()
  -- test_without_the_api_popups_touch_nothing
  -- First: the reaction picker and delivery menu are module singletons, and
  -- later blocks give them a close handler.
  withWindow({ hasGamepadUI = false }, function(env, factory, frame)
    local popup = OPENERS.reaction(factory, factory.CreateFrame("Button", nil, frame))
    popup:Hide()
    assert(#env.calls == 0 and popup.SmartNavigationCloseHandler == nil, "clients without the gamepad UI unchanged")
  end)

  -- test_inactive_nav_sets_no_popup_hooks
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
    local nav = GamepadNav.New(frame, { hasGamepadUI = false })
    local reached = 0
    nav.popupShown = function()
      reached = reached + 1
    end
    nav.setPopupCloseHandler = nav.popupShown
    GamepadWiring.Create({ frame = frame }, nav).attach(refs())
    local savedSpecial = _G.UISpecialFrames
    local popup = factory.CreateFrame("Frame", "WhisperMessengerTestInactivePopup", nil)
    PickerPopup.RegisterEscape("WhisperMessengerTestInactivePopup", popup)
    popup:Show()
    PickerPopup.SetGamepadPopupHooks(nil, nil)
    _G.UISpecialFrames = savedSpecial
    assert(reached == 0, "no gamepad UI: opening a popup runs no gamepad code")
  end

  -- test_each_popup_opens_focused_and_b_closes_it
  for _, key in ipairs({ "reaction", "delivery", "export", "twoField" }) do
    withWindow(nil, function(env, factory, frame, nav)
      local popup = OPENERS[key](factory, factory.CreateFrame("Button", nil, frame))
      assert(popup:IsShown() and callsFor(env, "HandlePopupShown", popup) == 1, key .. ": FCM focuses it on open")
      assert(popup.SmartNavigationCloseHandler(popup) == true, key .. ": B is handled by the popup")
      assert(not popup:IsShown() and callsFor(env, "FrameHidden", popup) == 1, key .. ": B hides it and FCM lets it go")
      local shownAt, hiddenAt
      for i, c in ipairs(env.calls) do
        if c.args[1] == popup then
          shownAt = shownAt or (c.name == "HandlePopupShown" and i or nil)
          hiddenAt = c.name == "FrameHidden" and i or hiddenAt
        end
      end
      assert(shownAt < hiddenAt, key .. ": HandlePopupShown before FrameHidden: focus goes back to the window")
      assert(frame:IsShown() and nav.isRegistered() and callsFor(env, "FrameHidden", frame) == 0, key .. ": the window stays open")
    end)
  end

  -- test_popup_closed_with_the_mouse_lets_fcm_go
  withWindow(nil, function(env, factory, frame)
    local popup = OPENERS.delivery(factory, factory.CreateFrame("Button", nil, frame))
    DeliveryMenu.Close()
    assert(callsFor(env, "FrameHidden", popup) == 1 and not env.isListed(popup), "any hide unlists it")
  end)
end
