-- On WoW: Forever the game re-scans a whole registered window on every
-- CreateFrame under it. While the gamepad UI is on, frames are created under
-- a holder outside the window and moved in.
local FakeUI = require("tests.helpers.fake_ui")
local GamepadBuild = require("WhisperMessenger.UI.Shared.GamepadBuild")

local function isUnder(frame, ancestor)
  while frame do
    if frame == ancestor then
      return true
    end
    frame = frame.parent
  end
  return false
end

-- fn(world) with the gamepad UI on or off. world: root, window, pane (inside
-- the window), factory (wrapped) and createdInside (CreateFrame calls the
-- game would answer with a re-scan).
local function withWorld(padOn, fn)
  local savedInput, savedUIParent = _G.InputUtil, _G.UIParent
  _G.InputUtil = {
    IsGamepadUIEnabled = function()
      return padOn
    end,
  }
  local plain = FakeUI.NewFactory()
  _G.UIParent = plain.CreateFrame("Frame", "UIParent", nil)
  local window = plain.CreateFrame("Frame", nil, _G.UIParent)
  window:SetFrameStrata("HIGH")
  local pane = plain.CreateFrame("Frame", nil, window)
  pane:SetFrameStrata("HIGH")
  pane:SetFrameLevel(9)
  local world = { root = _G.UIParent, window = window, pane = pane, plain = plain, createdInside = 0, parents = {} }
  world.spy = setmetatable({
    CreateFrame = function(kind, name, parent, template)
      if isUnder(parent, window) then
        world.createdInside = world.createdInside + 1
      end
      world.parents[#world.parents + 1] = parent
      return plain.CreateFrame(kind, name, parent, template)
    end,
  }, { __index = plain })
  world.factory = GamepadBuild.WrapFactory(world.spy)
  local ok, err = pcall(fn, world)
  _G.InputUtil, _G.UIParent = savedInput, savedUIParent
  assert(ok, err)
end

return function()
  -- test_pad_on_creates_a_plain_frame_outside_the_window
  withWorld(true, function(world)
    world.factory.CreateFrame("Frame", nil, world.pane)
    assert(world.createdInside == 0, "got " .. world.createdInside)
  end)

  -- test_pad_on_moves_the_frame_under_its_parent
  withWorld(true, function(world)
    local frame = world.factory.CreateFrame("Button", nil, world.pane)
    assert(frame:GetParent() == world.pane, "the frame ends up under the parent asked for")
  end)

  -- test_pad_on_creates_at_the_parents_strata_and_level
  withWorld(true, function(world)
    world.factory.CreateFrame("Frame", nil, world.pane)
    local holder = world.parents[#world.parents]
    assert(holder:GetFrameStrata() == "HIGH" and holder:GetFrameLevel() == 9, "the holder matches the parent")
  end)

  -- test_pad_on_creates_a_link_frame_outside_the_window
  withWorld(true, function(world)
    world.factory.CreateFrame("Frame", nil, world.pane, "InlineHyperlinkFrameTemplate")
    assert(world.createdInside == 0, "chat bubbles use this template, got " .. world.createdInside)
  end)

  -- test_pad_on_creates_an_unknown_template_in_place
  -- A template's OnLoad may read its parent.
  withWorld(true, function(world)
    world.factory.CreateFrame("Button", nil, world.pane, "SomeGameTemplate")
    assert(world.createdInside == 1, "got " .. world.createdInside)
  end)

  -- test_pad_off_creates_in_place
  withWorld(false, function(world)
    world.factory.CreateFrame("Frame", nil, world.pane)
    assert(world.parents[1] == world.pane, "without the gamepad UI nothing re-scans")
  end)

  -- test_no_parent_is_left_alone
  withWorld(true, function(world)
    local frame = world.factory.CreateFrame("Frame", nil, nil)
    assert(frame:GetParent() == nil, "no parent asked for, none given")
  end)

  -- test_frames_of_a_page_under_construction_stay_in_place
  -- Moving the holder's level for them would shift the page being built.
  withWorld(true, function(world)
    local page = world.plain.CreateFrame("Frame", nil, GamepadBuild.BuildParent(world.spy, world.pane))
    local inner = world.plain.CreateFrame("Frame", nil, page)
    inner:SetFrameLevel(30)
    world.factory.CreateFrame("Frame", nil, inner)
    assert(world.parents[#world.parents] == inner, "already outside the window")
    assert(page:GetParent():GetFrameLevel() == 9, "the holder keeps the pane's level")
  end)

  -- test_the_factorys_other_fields_still_read_through
  withWorld(true, function(world)
    assert(world.factory.CreateFrame ~= world.spy.CreateFrame, "CreateFrame is wrapped")
    world.spy.marker = {}
    assert(world.factory.marker == world.spy.marker, "the rest is the factory's")
  end)
end
