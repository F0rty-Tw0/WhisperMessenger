local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- ESC for our popups and the game menus the window opens: registered
-- frames close on ESC (UISpecialFrames), and each opening is reported to
-- the window's ESC order.
local PopupEscape = {}

local escapeFrameNames = {}
local hookedEscapeFrames = setmetatable({}, { __mode = "k" })
local escapeFrameShownHandler = nil
-- Opening order of the registered frames, for HideShownEscapeFrame.
local shownSerial = setmetatable({}, { __mode = "k" })
local shownCounter = 0
-- Second listener, for the WoW: Forever gamepad UI (GamepadWiring).
local gamepadShown, gamepadHidden = nil, nil

local function reportEscapeFrameShown(popup)
  shownCounter = shownCounter + 1
  shownSerial[popup] = shownCounter
  if escapeFrameShownHandler then
    escapeFrameShownHandler(popup)
  end
  if gamepadShown then
    gamepadShown(popup)
  end
end

local function reportEscapeFrameHidden(popup)
  if gamepadHidden then
    gamepadHidden(popup)
  end
end

-- onShown(popup) / onHidden(popup) run when a popup registered with its
-- frame opens or closes, beside the ESC handler. Game menus never reach
-- them. nil, nil clears both.
function PopupEscape.SetGamepadPopupHooks(onShown, onHidden)
  gamepadShown, gamepadHidden = onShown, onHidden
end

-- `handler(popup)` runs whenever a popup registered with its frame opens,
-- `handler(menu, true)` for a game menu reported with ReportMenuShown.
function PopupEscape.SetEscapeFrameShownHandler(handler)
  escapeFrameShownHandler = handler
end

-- Escape closes the named frame. Pass `frame` to report its opening to the
-- handler set with SetEscapeFrameShownHandler (and its opening and closing
-- to the gamepad hooks).
function PopupEscape.RegisterEscape(frameName, frame)
  if frame and not hookedEscapeFrames[frame] and type(frame.HookScript) == "function" then
    hookedEscapeFrames[frame] = true
    frame:HookScript("OnShow", reportEscapeFrameShown)
    frame:HookScript("OnHide", reportEscapeFrameHidden)
  end
  local known = false
  for _, name in ipairs(escapeFrameNames) do
    known = known or name == frameName
  end
  if not known then
    table.insert(escapeFrameNames, frameName)
  end
  if type(_G.UISpecialFrames) ~= "table" then
    _G.UISpecialFrames = {}
  end
  for _, name in ipairs(_G.UISpecialFrames) do
    if name == frameName then
      return
    end
  end
  table.insert(_G.UISpecialFrames, frameName)
end

-- Hides the most recently opened popup registered with its frame.
-- Returns false when none is shown.
function PopupEscape.HideShownEscapeFrame()
  local top, topSerial = nil, -1
  for frame in pairs(hookedEscapeFrames) do
    local serial = shownSerial[frame] or 0
    if frame:IsShown() and serial > topSerial then
      top, topSerial = frame, serial
    end
  end
  if not top then
    return false
  end
  top:Hide()
  return true
end

-- The game menu open now: the Menu system's (Retail, Classic, WoW:
-- Forever) or the old dropdown list.
local function openGameMenu()
  local menuApi = _G["Menu"]
  if type(menuApi) == "table" and type(menuApi.GetManager) == "function" then
    local manager = menuApi.GetManager()
    local open = manager and type(manager.GetOpenMenu) == "function" and manager:GetOpenMenu() or nil
    if open ~= nil then
      return open
    end
  end
  local dropDownList = _G["DropDownList1"]
  if dropDownList ~= nil and dropDownList:IsShown() then
    return dropDownList
  end
  return nil
end

-- Call right after the window opens a game menu (MenuUtil, UnitPopup, a
-- dropdown): ESC must close it first. Pass the menu frame when known.
-- The handler gets (menu, true).
function PopupEscape.ReportMenuShown(menu)
  menu = menu or openGameMenu()
  if menu ~= nil and escapeFrameShownHandler then
    escapeFrameShownHandler(menu, true)
  end
end

-- True when `frame` is one of the popups registered here.
function PopupEscape.IsEscapeFrame(frame)
  local name = type(frame.GetName) == "function" and frame:GetName() or nil
  for _, known in ipairs(escapeFrameNames) do
    if name ~= nil and known == name then
      return true
    end
  end
  return false
end

ns.PopupEscape = PopupEscape
return PopupEscape
