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
-- another window or one of its own popups or game menus has ESC, and comes
-- back once that closes. While in front it also holds the ESC key (EscapeKey), since
-- other windows' ESC handlers run before that sweep. Retail's
-- RegisterGameMenuEscHandler is not used: calling it
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

-- Game menus come from a frame pool that resets their scripts on reuse, so
-- a hook on one can silently vanish: the window checks this often whether
-- its menu is still open instead.
local MENU_CHECK_SECONDS = 0.1

-- `escapeKey` (EscapeKey.New) hands the ESC key to the window while it is in
-- front; optional.
function EscapeOrder.New(frame, escapeKey)
  local yieldedTo = nil
  -- True when yieldedTo is one of the window's own popups or menus.
  local yieldedToOwn = false
  local hooked = setmetatable({}, { __mode = "k" })

  local function windowName()
    return type(frame.GetName) == "function" and frame:GetName() or nil
  end

  local function setKeyFocused(focused)
    if escapeKey then
      escapeKey.setFocused(focused)
    end
  end

  local order = {}

  -- A click inside an open popup or menu counts as a click on the window;
  -- ESC must still close that first.
  function order.claim()
    if yieldedToOwn and yieldedTo ~= nil and yieldedTo:IsShown() then
      return
    end
    yieldedTo = nil
    yieldedToOwn = false
    setSpecialFrame(windowName(), true)
    setKeyFocused(true)
  end

  -- The window closed: ESC belongs to the game again.
  function order.release()
    setKeyFocused(false)
  end

  -- The game's close-all sweep hides the UI panels before it reads
  -- UISpecialFrames, so listing the window inside the panel's OnHide would
  -- close it with the same ESC press: it comes back on the next frame.
  local function onBlockerHidden(blocker)
    if blocker ~= yieldedTo then
      return
    end
    yieldedTo = nil
    yieldedToOwn = false
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

  local function hookHidden(blocker)
    if not hooked[blocker] and type(blocker.HookScript) == "function" then
      hooked[blocker] = true
      blocker:HookScript("OnHide", onBlockerHidden)
    end
  end

  local function watchMenu(menu)
    if menu ~= yieldedTo then
      return
    end
    if not menu:IsShown() then
      onBlockerHidden(menu)
      return
    end
    local timer = _G.C_Timer
    if timer ~= nil and type(timer.After) == "function" then
      timer.After(MENU_CHECK_SECONDS, function()
        watchMenu(menu)
      end)
    end
  end

  -- Returns true when the window gave ESC up to `blocker`.
  local function yieldTo(blocker, own)
    if blocker == nil or blocker == frame then
      return false
    end
    yieldedTo = blocker
    yieldedToOwn = own
    setSpecialFrame(windowName(), false)
    setKeyFocused(false)
    return true
  end

  function order.yieldToClickedWindow()
    local clicked = PointerFocus.FindFocusAncestor(closesOnEscape)
    if yieldTo(clicked, false) then
      hookHidden(clicked)
    end
  end

  PickerPopup.SetEscapeFrameShownHandler(function(shown, isGameMenu)
    if not yieldTo(shown, true) then
      return
    end
    if isGameMenu then
      watchMenu(shown)
    else
      hookHidden(shown)
    end
  end)

  return order
end

ns.MessengerWindowWindowScriptsFrameEscapeOrder = EscapeOrder

return EscapeOrder
