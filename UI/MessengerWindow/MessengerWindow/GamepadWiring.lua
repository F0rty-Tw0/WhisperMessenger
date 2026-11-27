local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GamepadDeps = ns.MessengerWindowGamepadDeps or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadDeps")
local GamepadNav = ns.MessengerWindowGamepadNav or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadCloseOrder = ns.MessengerWindowGamepadCloseOrder or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadCloseOrder")
local PopupEscape = ns.PopupEscape or require("WhisperMessenger.UI.Shared.PopupEscape")
local DropdownSelector = ns.MessengerWindowDropdownSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local GamepadSettings = ns.MessengerWindowGamepadSettings or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")
local GamepadTranscript = ns.MessengerWindowGamepadTranscript or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadTranscript")
local GamepadComposer = ns.MessengerWindowGamepadComposer or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadComposer")
local GamepadMenuButton = ns.MessengerWindowGamepadMenuButton or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadMenuButton")

-- The messenger window's part of the WoW: Forever gamepad UI: register on
-- show, B closes the topmost layer, the right stick scrolls the chat (the
-- settings page while settings show), the D-pad skips grips and the
-- composer padding, stops on each message, reaches every settings control,
-- and walks the top bar and the tabs in on-screen order. Our popups
-- take pad focus while open; B closes them and the composer pickers first.
-- X opens the right-click menu of the contact, message or header in focus.
-- On a client without the gamepad UI API the nav does nothing, so neither
-- does this.
local GamepadWiring = {}

local function ignoreDeadStops(nav, shell, refs)
  local chrome, layout = shell.chrome or {}, shell.layout or {}
  nav.ignore(chrome.resizeGrip)
  nav.ignore(layout.contactsResizeHandle)
  local composer = refs.composer
  -- The holder alone: the template's scroll frame under it (not the edit
  -- box) stays the D-pad stop. Without the input-scroll template the holder
  -- is the message box itself.
  if composer and composer.box ~= composer.input then
    nav.ignore(composer.box, true)
  end
  local transcript = refs.conversation and refs.conversation.transcript
  -- Without the API the nav is inert: no walk of the chat on every render.
  if transcript and nav.isActive() then
    -- Messages are stops; their dead parts are skipped as they render.
    GamepadTranscript.Attach(nav, transcript)
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

-- clearComposerFocus: GamepadComposer.Attach's result, nil = no such step.
local function buildCloseHandler(frame, refs, clearComposerFocus)
  local visibility = refs.windowVisibility
  return GamepadCloseOrder.Build({
    isWindowShown = function()
      return frame:IsShown()
    end,
    hideShownPopup = PopupEscape.HideShownEscapeFrame,
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
    clearComposerFocus = clearComposerFocus,
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
-- (no gamepad UI API) gets no walk: every mark would be a no-op.
local function attachSettings(nav, shell, transcript)
  local settingsPanels = shell.settingsRuntime and shell.settingsRuntime.settingsPanels
  if not settingsPanels or not nav.isActive() then
    return
  end
  local layout = shell.layout or {}
  local onTargetsChanged, onMenuToggled = GamepadSettings.Attach(nav, {
    contentScrollView = layout.optionsScrollView,
    chatScrollFrame = transcript and transcript.scrollFrame,
    optionsPanel = layout.optionsPanel,
    panels = settingsPanels,
    createFrame = GamepadDeps.defaultCreateFrame,
    menuScrollView = layout.optionsMenuScrollView,
    activeTab = function()
      for _, tab in ipairs(layout.settingsTabs or {}) do
        if tab._wmIsActiveTab then
          return tab
        end
      end
      return nil
    end,
    after = GamepadDeps.defaultAfter,
    isMenuOpen = DropdownSelector.IsMenuShown,
  })
  settingsPanels.onNavTargetsChanged = onTargetsChanged
  DropdownSelector.SetMenuToggledHook(onMenuToggled)
end

-- Our ESC-registered popups take pad focus while open; B hides the
-- focused one (as ESC does, so its own OnHide cleanup runs).
local function attachPopups(nav)
  if not nav.isActive() then
    return
  end
  PopupEscape.SetGamepadPopupHooks(function(popup)
    nav.setPopupCloseHandler(popup, function()
      popup:Hide()
      return true
    end)
    nav.popupShown(popup)
  end, nav.popupHidden)
end

-- Left to right on screen in both views: in the compact chat view Back
-- takes the first left slot while the left group hides.
local TOP_BAR = { "newConversationButton", "patchNotesButton", "markAllReadButton", "backButton", "optionsButton", "closeButton" }

-- The D-pad walks the top bar and the contact tabs left / right and the
-- settings tabs (a vertical list) up / down, in on-screen order. Each frame
-- seen gets an OnShow / OnHide hook once (memo `hooked`), so a button that
-- hides, such as Mark all read, re-chains at once; contact tabs shown later
-- re-chain through the toggle's tabs-changed handler (see attach).
local function orderStops(nav, shell, refs, hooked, reorder)
  local chrome, layout = shell.chrome or {}, shell.layout or {}
  local bar = {}
  for _, name in ipairs(TOP_BAR) do
    bar[#bar + 1] = chrome[name]
  end
  local tabToggle = refs.tabToggle
  local contactTabs = tabToggle and tabToggle.getTabButtons and tabToggle.getTabButtons() or {}
  local orders = {
    { "topBar", bar, "LEFT", "RIGHT" },
    { "settingsTabs", layout.settingsTabs or {}, "UP", "DOWN" },
    { "contactTabs", contactTabs, "LEFT", "RIGHT" },
  }
  for _, order in ipairs(orders) do
    for _, stop in ipairs(order[2]) do
      if not hooked[stop] and stop.HookScript then
        hooked[stop] = true
        stop:HookScript("OnShow", reorder)
        stop:HookScript("OnHide", reorder)
      end
    end
    nav.setOrder(order[1], order[2], order[3], order[4])
  end
end

-- shell: WindowShell.Build's result. nav: for tests; defaults to the game's.
-- refresh may run before attach: an unregistered nav ignores it.
-- attach must run after LifecycleWiring.Setup: its SetScript on OnShow and
-- OnHide drops any hook added before it.
function GamepadWiring.Create(shell, nav)
  local frame = shell.frame
  nav = nav or GamepadNav.New(frame)

  local wiring = { nav = nav }
  local attachedRefs = nil
  local hooked = setmetatable({}, { __mode = "k" })

  -- Before attach (no refs yet) or without the gamepad UI API: nothing.
  local function reorder()
    if attachedRefs and nav.isActive() then
      orderStops(nav, shell, attachedRefs, hooked, reorder)
    end
  end

  function wiring.refresh()
    reorder()
    nav.refresh()
  end

  -- refs: { composer, conversation, compactMode, windowVisibility, tabToggle }.
  function wiring.attach(refs)
    frame:HookScript("OnShow", function()
      nav.onShow()
    end)
    frame:HookScript("OnHide", function()
      nav.onHide()
    end)
    -- No register here even if the frame is shown: the build hides it right
    -- after Create, and every real show arrives through the OnShow hook.
    local clearComposerFocus = GamepadComposer.Attach(nav, refs.composer)
    nav.setCloseHandler(buildCloseHandler(frame, refs, clearComposerFocus))
    attachPopups(nav)
    GamepadMenuButton.Attach(nav, frame)
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
    -- A tab shown later (a mode turned on, an addon panel's tab) has no
    -- OnShow hook yet: the toggle reports the change instead.
    local tabToggle = refs.tabToggle
    if tabToggle and tabToggle.setTabsChangedHandler then
      tabToggle.setTabsChangedHandler(reorder)
    end
    attachedRefs = refs
    reorder()
  end

  return wiring
end

ns.MessengerWindowGamepadWiring = GamepadWiring

return GamepadWiring
