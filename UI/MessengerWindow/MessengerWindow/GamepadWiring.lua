local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GamepadNav = ns.MessengerWindowGamepadNav or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadCloseOrder = ns.MessengerWindowGamepadCloseOrder or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadCloseOrder")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local DropdownSelector = ns.MessengerWindowDropdownSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local GamepadSettings = ns.MessengerWindowGamepadSettings or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

-- The messenger window's part of the WoW: Forever gamepad UI: register on
-- show, B closes the topmost layer, the right stick scrolls the chat (the
-- settings page while settings show), the D-pad skips grips, chat bubbles
-- and the composer padding, and reaches every settings control. Our popups
-- take pad focus while open; B closes them and the composer pickers first.
-- Off Forever the nav does nothing, so neither does this.
local GamepadWiring = {}

local function ignoreDeadStops(nav, shell, refs)
  local chrome, layout = shell.chrome or {}, shell.layout or {}
  nav.ignore(chrome.resizeGrip)
  nav.ignore(layout.contactsResizeHandle)
  local transcript = refs.conversation and refs.conversation.transcript
  if transcript then
    -- Every bubble, separator and copy button sits under the content frame.
    nav.ignore(transcript.content)
  end
  local composer = refs.composer
  -- The holder alone: the message box under it stays reachable. Without the
  -- input-scroll template the holder is the message box itself.
  if composer and composer.box ~= composer.input then
    nav.ignore(composer.box, true)
  end
end

-- The composer's emoji and quick-reply pickers that exist.
local function composerPickers(composer)
  local pickers = {}
  if composer then
    pickers[#pickers + 1] = composer.emojiPicker
    pickers[#pickers + 1] = composer.quickReplyPicker
  end
  return pickers
end

local function buildCloseHandler(frame, refs)
  local visibility = refs.windowVisibility
  return GamepadCloseOrder.Build({
    isWindowShown = function()
      return frame:IsShown()
    end,
    hideShownPopup = PickerPopup.HideShownEscapeFrame,
    hideComposerPopover = function()
      for _, picker in ipairs(composerPickers(refs.composer)) do
        if picker.frame:IsShown() then
          picker:close()
          return true
        end
      end
      return false
    end,
    closeOpenDropdown = DropdownSelector.HideShownMenu,
    -- Read at press time: compact mode replaces the hook after the build.
    compactBack = function()
      return refs.compactMode.onBack()
    end,
    isOptionsVisible = function()
      return visibility.getVisiblePanel() == nil and not visibility.isConversationPaneShown()
    end,
    setOptionsVisible = visibility.setOptionsVisible,
    getVisiblePanel = visibility.getVisiblePanel,
    setPanelVisible = visibility.setPanelVisible,
    closeWindow = visibility.closeWindow,
  })
end

-- Pages built before attach (General) are scanned now; later ones when
-- SettingsTabs reports through onNavTargetsChanged. An inactive nav
-- (Retail, Classic) gets no walk: every mark would be a no-op.
local function attachSettings(nav, shell, transcript)
  local settingsPanels = shell.settingsRuntime and shell.settingsRuntime.settingsPanels
  if not settingsPanels or not nav.isActive() then
    return
  end
  local layout = shell.layout or {}
  settingsPanels.onNavTargetsChanged = GamepadSettings.Attach(nav, {
    contentScrollView = layout.optionsScrollView,
    chatScrollFrame = transcript and transcript.scrollFrame,
    optionsPanel = layout.optionsPanel,
    panels = settingsPanels,
  })
end

-- Our ESC-registered popups take pad focus while open; B hides the
-- focused one (as ESC does, so its own OnHide cleanup runs).
local function attachPopups(nav)
  if not nav.isActive() then
    return
  end
  PickerPopup.SetGamepadPopupHooks(function(popup)
    nav.setPopupCloseHandler(popup, function()
      popup:Hide()
      return true
    end)
    nav.popupShown(popup)
  end, nav.popupHidden)
end

-- shell: WindowShell.Build's result. nav: for tests; defaults to the game's.
-- refresh may run before attach: an unregistered nav ignores it.
-- attach must run after LifecycleWiring.Setup: its SetScript on OnShow and
-- OnHide drops any hook added before it.
function GamepadWiring.Create(shell, nav)
  local frame = shell.frame
  nav = nav or GamepadNav.New(frame)

  local wiring = { nav = nav }

  function wiring.refresh()
    nav.refresh()
  end

  -- refs: { composer, conversation, compactMode, windowVisibility }.
  function wiring.attach(refs)
    frame:HookScript("OnShow", function()
      nav.onShow()
    end)
    frame:HookScript("OnHide", function()
      nav.onHide()
    end)
    -- No register here even if the frame is shown: the build hides it right
    -- after Create, and every real show arrives through the OnShow hook.
    nav.setCloseHandler(buildCloseHandler(frame, refs))
    attachPopups(nav)
    -- The pickers live inside the window: a re-scan makes their buttons
    -- D-pad stops. Their own SetScript calls ran at build, before this.
    for _, picker in ipairs(composerPickers(refs.composer)) do
      picker.frame:HookScript("OnShow", wiring.refresh)
      picker.frame:HookScript("OnHide", wiring.refresh)
    end
    local transcript = refs.conversation and refs.conversation.transcript
    if transcript then
      nav.setScrollFrame(transcript.scrollFrame)
    end
    ignoreDeadStops(nav, shell, refs)
    attachSettings(nav, shell, transcript)
  end

  return wiring
end

ns.MessengerWindowGamepadWiring = GamepadWiring

return GamepadWiring
