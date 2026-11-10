local FakeUI = require("tests.helpers.fake_ui")
local DetachedPreviewRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

-- The detached preview keeps no share rule of its own: it reads and writes
-- its spot through PositionSlots ("detachedPreview").

local function fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "frame has a " .. script .. " handler")
  handler(frame, ...)
end

local function makeSpy(spot)
  local spy = { reads = {}, writes = {} }
  function spy.read(name)
    spy.reads[#spy.reads + 1] = name
    return spot
  end
  function spy.write(name, nextState)
    spy.writes[#spy.writes + 1] = { name = name, state = nextState }
  end
  return spy
end

local function build(positionSlots)
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:Show()
  uiParent.GetCenter = function()
    return 500, 400
  end
  uiParent.GetTop = function()
    return 800
  end
  local env = {}
  env.uiParent = uiParent
  env.surface = DetachedPreviewRuntime.Create({
    uiFactory = factory,
    uiParent = uiParent,
    accountState = { settings = {} },
    characterState = {},
    positionSlots = positionSlots,
    buildContacts = function()
      return {}
    end,
    acknowledgeLatestWidgetPreview = function() end,
    refreshWindow = function() end,
    getWidgetIcon = function() end,
    now = function()
      return 10
    end,
  })
  return env
end

local function moveHolder(env, centerX, top)
  env.surface.holder.GetCenter = function()
    return centerX, 0
  end
  env.surface.holder.GetTop = function()
    return top
  end
end

local function test_preview_drag_while_sharing_goes_through_position_slots()
  local spy = makeSpy(nil)
  local env = build(spy)
  moveHolder(env, 500, 650)
  fire(env.surface.previewFrame, "OnDragStart")
  moveHolder(env, 620, 700)

  fire(env.surface.previewFrame, "OnDragStop")

  local write = spy.writes[1]
  assert(write ~= nil, "the drag writes through the slots")
  assert(write.name == "detachedPreview", "the write names the detachedPreview slot")
  assert(write.state.x == 120 and write.state.y == -100, "the write carries the TOP-relative offset")
end

local function test_preview_spot_comes_from_position_slots()
  local spy = makeSpy({ x = 40, y = -60 })

  local env = build(spy)

  local point, _, _, x, y = env.surface.holder:GetPoint()
  assert(spy.reads[1] == "detachedPreview", "the spot is read from the detachedPreview slot")
  assert(point == "TOP" and x == 40 and y == -60, "the holder is anchored at the slot's spot")
end

return function()
  test_preview_drag_while_sharing_goes_through_position_slots()
  test_preview_spot_comes_from_position_slots()
end
