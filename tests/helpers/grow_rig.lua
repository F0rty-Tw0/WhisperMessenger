local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

-- Pieces for tests that drive the window's grow/shrink panel by hand.
local GrowRig = {}

GrowRig.STEP = 1 / 30 -- GlideClock's per-frame cap
local PANEL_LEVEL = WindowGrowAnimation.PANEL_LEVEL

function GrowRig.rect(frame, left, bottom, right, top)
  rawset(frame, "GetLeft", function()
    return left
  end)
  rawset(frame, "GetBottom", function()
    return bottom
  end)
  rawset(frame, "GetRight", function()
    return right
  end)
  rawset(frame, "GetTop", function()
    return top
  end)
end

-- A shown stand-in for the floating button or the minimap icon.
function GrowRig.icon(left, bottom, right, top)
  local frame = FakeUI.NewFactory().CreateFrame("Button", "Icon", nil)
  GrowRig.rect(frame, left, bottom, right, top)
  frame:Show()
  return frame
end

-- The grow panel: a Frame at the panel level under the window's parent.
function GrowRig.ghostOf(window)
  local ghost = FindUI.find(window:GetParent(), function(node)
    return node.frameType == "Frame" and node:GetFrameLevel() == PANEL_LEVEL
  end)
  assert(ghost, "the grow panel exists")
  return ghost
end

function GrowRig.running(ghost)
  return ghost.scripts ~= nil and ghost.scripts.OnUpdate ~= nil
end

-- Runs the panel's clock frame by frame, as the client does, until it stops or the time is up.
function GrowRig.tick(ghost, seconds)
  local remaining = seconds
  while remaining > 0 and GrowRig.running(ghost) do
    ghost.scripts.OnUpdate(ghost, math.min(GrowRig.STEP, remaining))
    remaining = remaining - GrowRig.STEP
  end
end

-- Screen position of the panel's middle (the panel anchors TOPLEFT).
function GrowRig.center(ghost)
  local _, _, _, x, y = ghost:GetPoint()
  return x + ghost.width / 2, y - ghost.height / 2
end

-- Alt+Z: the client hides the parent, so the window gets OnHide while IsShown() is still true.
function GrowRig.parentHides(window)
  window.shown = true
  for _, hook in ipairs(window._hookScripts.OnHide) do
    hook(window)
  end
end

-- Alt+Z again: the client shows the parent, so the window gets OnShow while it never stopped being shown.
function GrowRig.parentShows(window)
  window.shown = true
  if window.scripts.OnShow then
    window.scripts.OnShow(window)
  end
  for _, hook in ipairs(window._hookScripts.OnShow or {}) do
    hook(window)
  end
end

return GrowRig
