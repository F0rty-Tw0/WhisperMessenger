local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MenuPopup = ns.MenuPopup or require("WhisperMessenger.UI.Shared.MenuPopup")
local PadButtons = ns.SettingsControlsPadButtons or require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")

-- The settings pages' part of the WoW: Forever gamepad UI. The right stick
-- scrolls the open page while settings show, the chat otherwise. Widgets
-- the settings builders tagged with _wmPadStep (a slider) or _wmPadButton
-- (a − / + or ▲ / ▼ pad button) go to the nav once each as a D-pad stop.
-- Page list and page are plain spatial nav. The pad buttons re-read the
-- game's pad UI toggle when settings show, on each re-scan, and when the
-- player flips the toggle (INPUT_DEVICE_INTERFACE_TRANSITION).
local GamepadSettings = {}

local function scrollFrameOf(scrollView)
  return scrollView and scrollView.scrollFrame
end

local function followSettingsPane(nav, settings)
  local optionsPanel = settings.optionsPanel
  if not optionsPanel then
    return
  end
  local function follow()
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
  end
  follow()
  if type(optionsPanel.HookScript) == "function" then
    optionsPanel:HookScript("OnShow", follow)
    optionsPanel:HookScript("OnHide", follow)
  end
end

-- True when the widget carried a tag (and so went to the nav).
local function handOver(nav, widget)
  if type(widget._wmPadStep) ~= "function" and widget._wmPadButton ~= true then
    return false
  end
  nav.markFocusable(widget)
  return true
end

-- A popup shown under the other mode is not registered with the game's
-- pad frame manager, so B would not reach it: close it on the toggle.
-- Then the pad buttons show or hide and the nav re-scans the new geometry.
-- A client without the event (or the frame) keeps the other refreshes only.
local function listenForPadToggle(nav, createFrame)
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
  frame:SetScript("OnEvent", function()
    if MenuPopup.IsShown() then
      MenuPopup.Close()
    end
    PadButtons.Refresh()
    nav.refresh()
  end)
end

-- settings (all optional): contentScrollView, chatScrollFrame,
-- optionsPanel, panels (the settings pages; false = not built yet),
-- createFrame() -> event frame for the pad UI toggle.
-- Returns onTargetsChanged: hands new tagged widgets over, then re-scans.
function GamepadSettings.Attach(nav, settings)
  local seen = setmetatable({}, { __mode = "k" })

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

  followSettingsPane(nav, settings)
  listenForPadToggle(nav, settings.createFrame)
  scan()
  return function()
    PadButtons.Refresh()
    scan()
    nav.refresh()
  end
end

ns.MessengerWindowGamepadSettings = GamepadSettings

return GamepadSettings
