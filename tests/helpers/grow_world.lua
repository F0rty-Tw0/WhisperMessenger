local CompactWindow = require("tests.helpers.compact_window")
local Rig = require("tests.helpers.grow_rig")
local Theme = require("WhisperMessenger.UI.Theme")

-- The window and clock oracles for the spec section 5 tables, on the classic
-- window and on the compact window with no docked button: both play on the
-- panel's own clock. Window rect 100..460 x 100..740; icon A centre (101, 741);
-- icon B centre (921, 321).
local GrowWorld = {}

local SECONDS = Theme.LAYOUT.COMPACT_RIDE_SECONDS
local NEAR_END = SECONDS * 0.9
local TOLERANCE = 5

GrowWorld.DONE = SECONDS + 0.1
GrowWorld.WIDTH = 360
GrowWorld.ICON_A = { 101, 741 }
GrowWorld.ICON_B = { 921, 321 }

function GrowWorld.World(style)
  local w = { on = true, iconA = Rig.icon(80, 720, 122, 762), iconB = Rig.icon(900, 300, 942, 342) }
  w.source = w.iconA
  w.case = CompactWindow.Build({
    compactLayout = style == "compact",
    getDockIcon = function()
      return nil
    end,
    getGrowSource = function()
      return w.source
    end,
    isGrowAnimationOn = function()
      return w.on
    end,
  })
  w.frame = w.case.window.frame
  Rig.rect(w.frame, 100, 100, 460, 740)
  w.ghost = Rig.ghostOf(w.frame)
  return w
end

function GrowWorld.EachStyle(run)
  for _, style in ipairs({ "classic", "compact" }) do
    run(GrowWorld.World(style), style)
  end
end

function GrowWorld.Settled(w, label)
  assert(not w.ghost:IsShown() and not Rig.running(w.ghost), label .. ": no panel, no clock")
  assert(w.frame:GetAlpha() == 1, label .. ": full alpha, got " .. tostring(w.frame:GetAlpha()))
end

function GrowWorld.Open(w)
  w.frame:Show()
  Rig.tick(w.ghost, GrowWorld.DONE)
end

-- Runs the running panel to 90% of its time and checks where its middle is.
function GrowWorld.AimedAt(w, spent, target, label)
  Rig.tick(w.ghost, NEAR_END - spent)
  assert(Rig.running(w.ghost), label .. ": still on its way")
  local x, y = Rig.center(w.ghost)
  assert(
    math.abs(x - target[1]) < TOLERANCE and math.abs(y - target[2]) < TOLERANCE,
    label .. ": aimed at " .. target[1] .. "," .. target[2] .. ", got " .. x .. "," .. y
  )
end

-- Two ways a window animates not at all.
local INSTANT = {
  {
    name = "switch off",
    apply = function(w)
      w.on = false
    end,
  },
  {
    name = "no source",
    apply = function(w)
      w.source = nil
      w.iconA:Hide()
    end,
  },
}

function GrowWorld.EachInstant(run)
  for _, cause in ipairs(INSTANT) do
    GrowWorld.EachStyle(function(w, style)
      run(w, style .. ", " .. cause.name, cause.apply)
    end)
  end
end

return GrowWorld
