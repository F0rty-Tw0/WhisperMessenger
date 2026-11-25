local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local MenuPopup = ns.MenuPopup or require("WhisperMessenger.UI.Shared.MenuPopup")
local PadButtons = ns.SettingsControlsPadButtons or require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")
local DropdownSwap = ns.MessengerWindowDropdownSwap or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")
local GamepadSettingsRows = ns.MessengerWindowGamepadSettingsRows
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettingsRows")

-- The settings pages' part of the WoW: Forever gamepad UI. The right stick
-- scrolls the open page while settings show, the chat otherwise. Widgets
-- the settings builders tagged with _wmPadButton (a − / + or ▲ / ▼ pad
-- button) go to the nav once each as a D-pad stop; ones tagged with
-- _wmPadStep (a slider) go once each as skipped.
-- The D-pad on the page follows its rows (GamepadSettingsRows), re-read on
-- the frame after anything may have moved; while a drop-down list is open
-- it is the game's, so DOWN enters the list. The Native-look dropdowns
-- (WM's list or the game's) and then the pad buttons re-read the game's pad
-- UI toggle when settings show, on each re-scan, and when the player flips
-- the toggle (INPUT_DEVICE_INTERFACE_TRANSITION).
local GamepadSettings = {}

local function scrollFrameOf(scrollView)
  return scrollView and scrollView.scrollFrame
end

local function followSettingsPane(nav, settings, scheduleRows)
  local optionsPanel = settings.optionsPanel
  if not optionsPanel then
    return
  end
  local function follow()
    DropdownSwap.Refresh()
    PadButtons.Refresh()
    local target
    if optionsPanel:IsShown() then
      target = scrollFrameOf(settings.contentScrollView)
    else
      target = settings.chatScrollFrame
    end
    if target then
      nav.setScrollFrame(target)
    end
    scheduleRows()
  end
  follow()
  if type(optionsPanel.HookScript) == "function" then
    optionsPanel:HookScript("OnShow", follow)
    optionsPanel:HookScript("OnHide", follow)
    optionsPanel:HookScript("OnSizeChanged", scheduleRows)
  end
end

-- True when the widget carried a tag (and so went to the nav). A slider is
-- skipped: A on it clicks the track and jumps the value, so its − / + pad
-- buttons are the stops that step it.
local function handOver(nav, widget)
  if type(widget._wmPadStep) == "function" then
    nav.ignore(widget)
    return true
  end
  if widget._wmPadButton ~= true then
    return false
  end
  nav.markFocusable(widget)

  return true
end

-- A popup shown under the other mode is not registered with the game's
-- pad frame manager, so B would not reach it: close it on the toggle.
-- Then the dropdowns swap, the pad buttons show or hide and the nav
-- re-scans the new geometry.
-- The event also fires on a switch between mouse and pad input with the
-- pad UI unchanged: that one does nothing, so an open menu stays open.
-- A client without the event (or the frame) keeps the other refreshes only.
local function listenForPadToggle(nav, createFrame, scheduleRows)
  if type(createFrame) ~= "function" then
    return
  end
  local ok, frame = pcall(createFrame)
  if not ok or type(frame) ~= "table" then
    return
  end
  if not pcall(frame.RegisterEvent, frame, "INPUT_DEVICE_INTERFACE_TRANSITION") then
    return
  end
  local padUIEnabled = FlavorCompat.IsGamepadUIEnabled()
  frame:SetScript("OnEvent", function()
    local enabled = FlavorCompat.IsGamepadUIEnabled()
    if enabled == padUIEnabled then
      return
    end
    padUIEnabled = enabled
    if MenuPopup.IsShown() then
      MenuPopup.Close()
    end
    DropdownSwap.Refresh()
    PadButtons.Refresh()
    scheduleRows()
    nav.refresh()
  end)
end

-- Returns scheduleRows: re-chains the page's rows on the next frame (the
-- game lays frames out then), once however often asked. Without a timer
-- the rows stay the game's.
local function newRowScheduler(nav, settings)
  local refreshRows = GamepadSettingsRows.New(nav, {
    scrollView = settings.contentScrollView,
    menuScrollView = settings.menuScrollView,
    activeTab = settings.activeTab,
    panels = settings.panels,
    isEnabled = function()
      local menuOpen = settings.isMenuOpen and settings.isMenuOpen()
      return FlavorCompat.IsGamepadUIEnabled() and not menuOpen
    end,
  })
  local scheduled = false
  local function run()
    scheduled = false
    refreshRows()
  end
  return function()
    if scheduled or not settings.after then
      return
    end
    scheduled = true
    settings.after(0, run)
  end
end

-- settings (all optional): contentScrollView, chatScrollFrame,
-- menuScrollView (the page list), activeTab() -> the open page's tab or nil,
-- optionsPanel, panels (the settings pages; false = not built yet),
-- createFrame() -> event frame for the pad UI toggle, after(delay, fn),
-- isMenuOpen() -> a drop-down list of WM's own is open.
-- Returns onTargetsChanged: hands new tagged widgets over, then re-scans;
-- and onMenuToggled: a drop-down list opened or closed.
function GamepadSettings.Attach(nav, settings)
  local seen = setmetatable({}, { __mode = "k" })
  local scheduleRows = newRowScheduler(nav, settings)

  local function walk(frame)
    -- Memo only what went over: a widget tagged later is still picked up.
    if not seen[frame] and handOver(nav, frame) then
      seen[frame] = true
    end
    if type(frame.GetChildren) ~= "function" then
      return
    end
    for _, child in ipairs({ frame:GetChildren() }) do
      walk(child)
    end
  end

  local function scan()
    for _, page in ipairs(settings.panels or {}) do
      if page then
        walk(page)
      end
    end
  end

  local function onTargetsChanged()
    DropdownSwap.Refresh()
    PadButtons.Refresh()
    scan()
    scheduleRows()
    nav.refresh()
  end

  local function onMenuToggled()
    scheduleRows()
    nav.refresh()
  end

  followSettingsPane(nav, settings, scheduleRows)
  listenForPadToggle(nav, settings.createFrame, scheduleRows)
  scan()
  return onTargetsChanged, onMenuToggled
end

ns.MessengerWindowGamepadSettings = GamepadSettings

return GamepadSettings
