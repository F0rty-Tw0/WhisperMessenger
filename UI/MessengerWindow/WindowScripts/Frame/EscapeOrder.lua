local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PointerFocus = ns.MessengerWindowWindowScriptsFramePointerFocus
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.PointerFocus")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

local EscapeOrder = {}

-- ESC closes everything in UISpecialFrames together with the open UI panels
-- (Auction House, Character...). The window stays in UISpecialFrames while
-- in front, so ESC and the game's other close-all sweeps (death, loss of
-- control, a center panel opening) close it. It leaves the list while
-- another window or one of its own popups has ESC, and comes back once that
-- window closes. Retail's RegisterGameMenuEscHandler is not used: calling it
-- from addon code taints the game's ESC handler list, and ESC then fails to
-- stop casting.

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

local function isOpenOwnPopup(candidate)
  return candidate ~= nil and PickerPopup.IsEscapeFrame(candidate) and candidate:IsShown()
end

function EscapeOrder.New(frame)
  local yieldedTo = nil
  local hooked = setmetatable({}, { __mode = "k" })

  local function windowName()
    return type(frame.GetName) == "function" and frame:GetName() or nil
  end

  local order = {}

  -- A click inside an open popup counts as a click on the window; ESC must
  -- still close that popup first.
  function order.claim()
    if isOpenOwnPopup(yieldedTo) then
      return
    end
    yieldedTo = nil
    setSpecialFrame(windowName(), true)
  end

  -- The game's close-all sweep hides the UI panels before it reads
  -- UISpecialFrames, so listing the window inside the panel's OnHide would
  -- close it with the same ESC press: it comes back on the next frame.
  local function onBlockerHidden(blocker)
    if blocker ~= yieldedTo then
      return
    end
    yieldedTo = nil
    local timer = _G.C_Timer
    -- Every client has C_Timer; only test stubs without it get here.
    if timer == nil or type(timer.After) ~= "function" then
      order.claim()
      return
    end
    timer.After(0, function()
      if yieldedTo == nil then
        order.claim()
      end
    end)
  end

  local function yieldTo(blocker)
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

  function order.yieldToClickedWindow()
    yieldTo(PointerFocus.FindFocusAncestor(closesOnEscape))
  end

  PickerPopup.SetEscapeFrameShownHandler(yieldTo)

  return order
end

ns.MessengerWindowWindowScriptsFrameEscapeOrder = EscapeOrder

return EscapeOrder
