local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- On WoW: Forever the game hooks CreateFrame (SmartNavigation) and re-scans
-- our whole window, twice, for every frame created under it while the gamepad
-- UI holds it: 2 to 8 ms each, up to 0.8 s for a settings page. Frames are
-- created under a holder outside the window instead and then moved in:
-- SetParent has no re-scan.
local GamepadBuild = {}

-- Templates that add scripts or art only, so a frame can be made under the
-- holder. Any other template may read or anchor to its parent as it loads.
local MOVABLE_TEMPLATES = {
  BackdropTemplate = true,
  InlineHyperlinkFrameTemplate = true,
  TooltipBackdropTemplate = true,
}

local holder

local function isUnderHolder(frame)
  while frame do
    if frame == holder then
      return true
    end
    frame = frame.GetParent and frame:GetParent()
  end
  return false
end

-- The frame to create under when the result will be moved to `parent`, or
-- `parent` itself when there is nothing to avoid. The holder matches parent's
-- strata, level and scale, so text measures and frame levels set before the
-- move hold after it.
function GamepadBuild.BuildParent(factory, parent)
  local root = _G.UIParent
  if not root or parent == nil or parent == root or not FlavorCompat.IsGamepadUIEnabled() then
    return parent
  end
  if not holder or holder:GetParent() ~= root then
    holder = factory.CreateFrame("Frame", nil, root)
  end
  if isUnderHolder(parent) then
    return parent
  end
  holder:SetScale(parent:GetEffectiveScale() / root:GetEffectiveScale())
  holder:SetFrameStrata(parent:GetFrameStrata())
  holder:SetFrameLevel(parent:GetFrameLevel())
  return holder
end

local function isMovable(template)
  if template == nil then
    return true
  end
  for name in string.gmatch(template, "[^,%s]+") do
    if not MOVABLE_TEMPLATES[name] then
      return false
    end
  end
  return true
end

-- CreateFrame through `factory`, without the re-scan where that is safe.
function GamepadBuild.CreateFrame(factory, frameType, name, parent, template, ...)
  local buildParent = isMovable(template) and GamepadBuild.BuildParent(factory, parent) or parent
  local frame = factory.CreateFrame(frameType, name, buildParent, template, ...)
  if buildParent ~= parent then
    frame:SetParent(parent)
  end
  return frame
end

-- `factory` with its CreateFrame replaced by the one above.
function GamepadBuild.WrapFactory(factory)
  return setmetatable({
    CreateFrame = function(...)
      return GamepadBuild.CreateFrame(factory, ...)
    end,
  }, { __index = factory })
end

ns.GamepadBuild = GamepadBuild

return GamepadBuild
