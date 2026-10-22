local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PointerFocus = ns.MessengerWindowWindowScriptsFramePointerFocus
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.PointerFocus")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

local EscapeOrder = {}

-- ESC closes everything in UISpecialFrames together with the open UI panels
-- (Auction House, Character...). Retail has an ESC handler registry that runs
-- before that sweep, so there the window closes on its own while in front and
-- lets ESC pass while the player works in another window. The window stays in
-- UISpecialFrames while in front so the game's other close-all sweeps (death,
-- loss of control, a center panel opening) still close it; it leaves the list
-- while another window has ESC and comes back once that window closes.

local PANEL_SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }

local function indexOf(list, value)
  for index, item in ipairs(list) do
    if item == value then
      return index
    end
  end
  return nil
end

local function setSpecialFrame(name, listed)
  local list = _G.UISpecialFrames
  if name == nil or type(list) ~= "table" then
    return
  end
  local index = indexOf(list, name)
  if listed and index == nil then
    table.insert(list, name)
  elseif not listed and index ~= nil then
    table.remove(list, index)
  end
end

local function isOpenPanel(candidate)
  local getUIPanel = _G.GetUIPanel
  if type(getUIPanel) ~= "function" then
    return false
  end
  for _, slot in ipairs(PANEL_SLOTS) do
    if getUIPanel(slot) == candidate then
      return true
    end
  end
  return false
end

-- A window ESC would close: an open UI panel or a UISpecialFrames entry.
local function closesOnEscape(candidate)
  if isOpenPanel(candidate) then
    return true
  end
  local name = type(candidate.GetName) == "function" and candidate:GetName() or nil
  return name ~= nil and type(_G.UISpecialFrames) == "table" and indexOf(_G.UISpecialFrames, name) ~= nil
end

local function escHandlerRegistry()
  local register, priority = _G.RegisterGameMenuEscHandler, _G.GameMenuEscPriority
  if type(register) == "function" and type(priority) == "table" and priority.AddOn ~= nil then
    return register, priority.AddOn
  end
  return nil
end

function EscapeOrder.New(frame)
  local yieldedTo = nil
  local hooked = setmetatable({}, { __mode = "k" })
  local register, addOnPriority = escHandlerRegistry()

  local function windowName()
    return type(frame.GetName) == "function" and frame:GetName() or nil
  end

  if register then
    register(addOnPriority, function()
      if not frame:IsShown() or yieldedTo ~= nil then
        return false
      end
      if not PickerPopup.HideEscapeFrames() then
        frame:Hide()
      end
      return true
    end)
  end

  local order = {}

  function order.claim()
    yieldedTo = nil
    setSpecialFrame(windowName(), true)
  end

  local function onBlockerHidden(blocker)
    if blocker == yieldedTo then
      order.claim()
    end
  end

  function order.yieldToClickedWindow()
    local blocker = PointerFocus.FindFocusAncestor(closesOnEscape)
    if blocker == nil or blocker == frame then
      return
    end
    yieldedTo = blocker
    setSpecialFrame(windowName(), false)
    if not hooked[blocker] and type(blocker.HookScript) == "function" then
      hooked[blocker] = true
      blocker:HookScript("OnHide", onBlockerHidden)
    end
  end

  return order
end

ns.MessengerWindowWindowScriptsFrameEscapeOrder = EscapeOrder

return EscapeOrder
