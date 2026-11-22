local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The settings pages' part of the WoW: Forever gamepad UI. The right stick
-- scrolls the open page while settings show, the chat otherwise. Widgets
-- the settings builders tagged with _wmPadStep (a slider) or _wmPadButton
-- (a − / + or ▲ / ▼ pad button) go to the nav once each as a D-pad stop.
-- Page list and page are plain spatial nav.
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

-- settings (all optional): contentScrollView, chatScrollFrame,
-- optionsPanel, panels (the settings pages; false = not built yet).
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
  scan()
  return function()
    scan()
    nav.refresh()
  end
end

ns.MessengerWindowGamepadSettings = GamepadSettings

return GamepadSettings
