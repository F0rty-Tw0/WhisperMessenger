local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PointerFocus = ns.MessengerWindowWindowScriptsFramePointerFocus
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.PointerFocus")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

-- Raises the window above other open panels while the user works in it and
-- sends it back when they click elsewhere, without stealing composer focus.
local WindowStrata = {}

-- Frames in one strata draw by level, whatever their parent. Blizzard pins a
-- panel's border at level 510 (AddOn List in HIGH) and Edit Mode boxes at
-- 1000 (MEDIUM), so a window below that gets half covered: their background
-- under it, their border on top. Raise() left it below 500 in game. The
-- window keeps one level above both in HIGH and MEDIUM.
local WINDOW_FRAME_LEVEL = 2000

-- options.composerInput is read on every call, not captured.
-- options.onStrataChanged(strata), when given, runs after each change.
-- options.isWindowPart(frame), when given, claims frames outside the window
-- that count as clicks on it.
function WindowStrata.New(frame, options, escapeOrder)
  local function composerHasFocus()
    local input = options.composerInput
    if input == nil or type(input.HasFocus) ~= "function" then
      return false
    end
    local ok, focused = pcall(function()
      return input:HasFocus() == true
    end)
    return ok and focused == true
  end

  local function isMouseOverFrame()
    if frame == nil or type(frame.IsMouseOver) ~= "function" then
      return false
    end
    local ok, over = pcall(function()
      return frame:IsMouseOver() == true
    end)
    return ok and over == true
  end

  -- Ask which frame is under the cursor, not whether the cursor is inside
  -- the window's rectangle: another window (Auction House) can cover ours,
  -- and children (contacts tabs) or our UIParent popups sit outside it. The
  -- rectangle is the fallback when the game reports no focus.
  local function isPointerOnWindow()
    if PointerFocus.Current() ~= nil then
      return PointerFocus.FindFocusAncestor(function(candidate)
        if candidate == frame or PickerPopup.IsEscapeFrame(candidate) then
          return true
        end
        return options.isWindowPart ~= nil and options.isWindowPart(candidate)
      end) ~= nil
    end
    return isMouseOverFrame()
  end

  -- Strata/level transitions must never pull keyboard focus away from
  -- the composer. WoW's click-on-non-EditBox flow and strata changes can
  -- clear an EditBox's focus as a side effect — when the composer had
  -- focus before the change, restore it afterwards so mouse-over / click
  -- promotions don't interrupt the user's typing.
  local function preserveComposerFocusAround(fn)
    local hadFocus = composerHasFocus()
    fn()
    if hadFocus and not composerHasFocus() then
      local input = options.composerInput
      if input and type(input.SetFocus) == "function" then
        input:SetFocus()
      end
    end
  end

  local function promote()
    if escapeOrder then
      escapeOrder.claim()
    end
    preserveComposerFocusAround(function()
      if frame and type(frame.SetFrameStrata) == "function" then
        frame:SetFrameStrata("HIGH")
      end
      if frame and type(frame.SetFrameLevel) == "function" then
        frame:SetFrameLevel(WINDOW_FRAME_LEVEL)
      end
    end)
    if options.onStrataChanged then
      options.onStrataChanged("HIGH")
    end
  end

  local function demoteIfIdle()
    if composerHasFocus() or isPointerOnWindow() then
      return
    end
    preserveComposerFocusAround(function()
      if frame and type(frame.SetFrameStrata) == "function" then
        frame:SetFrameStrata("MEDIUM")
      end
      if frame and type(frame.SetFrameLevel) == "function" then
        frame:SetFrameLevel(WINDOW_FRAME_LEVEL)
      end
    end)
    if options.onStrataChanged then
      options.onStrataChanged("MEDIUM")
    end
  end

  return {
    promote = promote,
    demoteIfIdle = demoteIfIdle,
    isPointerOnWindow = isPointerOnWindow,
  }
end

ns.MessengerWindowWindowScriptsFrameWindowStrata = WindowStrata

return WindowStrata
