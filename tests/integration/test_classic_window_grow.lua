local PhoneWindow = require("tests.helpers.phone_window")
local Rig = require("tests.helpers.grow_rig")
local Theme = require("WhisperMessenger.UI.Theme")

local DONE = Theme.LAYOUT.PHONE_RIDE_SECONDS + 0.1

local function classic(extra)
  local options = { phoneLayout = false }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  local case = PhoneWindow.Build(options)
  Rig.rect(case.window.frame, 100, 100, 460, 740)
  return case
end

return function()
  -- test_classic_window_grows_from_the_source_through_its_real_scripts
  do
    local icon = Rig.icon(80, 720, 122, 762)
    local case = classic({
      getGrowSource = function()
        return icon
      end,
    })
    local frame = case.window.frame
    frame:Show()
    assert(frame:GetAlpha() == 0, "the panel does the growing")
    local ghost = Rig.ghostOf(frame)
    assert(ghost:IsShown() and Rig.running(ghost), "panel growing on its own clock")
    Rig.tick(ghost, DONE)
    assert(frame:GetAlpha() == 1, "back at the player's opacity, got " .. tostring(frame:GetAlpha()))
  end

  -- test_the_windows_own_show_script_stays_in_place
  do
    local case = classic()
    local frame = case.window.frame
    assert(type(frame.scripts.OnShow) == "function", "the window's own OnShow is still set")
    assert(#frame._hookScripts.OnShow >= 1, "the grow hooks on top of it")
  end

  -- test_missing_grow_options_open_the_classic_window_at_once
  do
    local case = classic({ getGrowSource = false }) -- the harness otherwise defaults the source to its stub button
    local frame = case.window.frame
    frame:Show()
    assert(frame:GetAlpha() == 1, "no source: never held unseen")
    assert(not Rig.running(Rig.ghostOf(frame)), "no OnUpdate")
  end

  -- test_switch_off_opens_the_classic_window_at_once
  do
    local icon = Rig.icon(80, 720, 122, 762)
    local case = classic({
      getGrowSource = function()
        return icon
      end,
      isGrowAnimationOn = function()
        return false
      end,
    })
    case.window.frame:Show()
    assert(case.window.frame:GetAlpha() == 1 and not Rig.running(Rig.ghostOf(case.window.frame)), "instant")
  end
end
