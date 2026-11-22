local FakeUI = require("tests.helpers.fake_ui")
local EdgeWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.EdgeWiring")

local function stubEdge(side)
  local edge = EdgeWiring.Hooks()
  edge.side = function()
    return side
  end
  edge.source = {}
  return edge
end

return function()
  -- test_side_reads_left_and_right
  assert(EdgeWiring.Side({ screenEdge = "left" }) == "left" and EdgeWiring.Side({ screenEdge = "right" }) == "right")
  -- test_side_is_nil_for_off_and_missing
  assert(EdgeWiring.Side({ screenEdge = "off" }) == nil and EdgeWiring.Side({}) == nil)
  -- test_side_needs_compact_layout
  assert(EdgeWiring.Side({ compactLayout = false, screenEdge = "left" }) == nil)

  -- test_idle_hooks
  do
    local edge = EdgeWiring.Hooks()
    assert(edge.side() == nil and edge.apply() == false and edge.source == nil)
    edge.applyLive(nil)
  end

  -- test_wrap_position_drops_saves_while_at_the_edge
  do
    local saved = 0
    EdgeWiring.WrapPosition(stubEdge("left"), function()
      saved = saved + 1
    end)({})
    assert(saved == 0, "dropped at the edge")
  end

  -- test_wrap_position_passes_them_otherwise
  do
    local got
    EdgeWiring.WrapPosition(stubEdge(nil), function(state)
      got = state
    end)({ x = 1 })
    assert(got and got.x == 1, "passed on")
  end

  -- test_dock_options_while_at_the_edge
  do
    local edge = stubEdge("left")
    local own = {
      getDockIcon = function()
        return "icon"
      end,
      getGrowSource = function()
        return "button"
      end,
      isIconDockOn = function()
        return true
      end,
      isOpenAtSavedSpot = function()
        return false
      end,
    }
    local opts = EdgeWiring.DockOptions(edge, own)
    assert(opts.getGrowSource() == edge.source, "grows from the edge source")
    assert(opts.isIconDockOn() == false and opts.isOpenAtSavedSpot() == true)
    assert(opts.getDockIcon() == "icon", "other fields come from the window options")
  end

  -- test_dock_options_off_the_edge_defer_to_the_window_options
  do
    local own = {
      getGrowSource = function()
        return "button"
      end,
      isIconDockOn = function()
        return "dockOn"
      end,
      isOpenAtSavedSpot = function()
        return "savedSpot"
      end,
    }
    local opts = EdgeWiring.DockOptions(stubEdge(nil), own)
    assert(opts.getGrowSource() == "button" and opts.isIconDockOn() == "dockOn" and opts.isOpenAtSavedSpot() == "savedSpot")
    local bare = EdgeWiring.DockOptions(stubEdge(nil), {})
    assert(bare.getGrowSource() == nil and bare.isIconDockOn() == true and bare.isOpenAtSavedSpot() == true, "DockWiring's defaults")
  end

  -- test_classic_layout_has_no_side
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local frame = factory.CreateFrame("Frame", "Window", parent)
    frame:SetMovable(true)
    local edge = EdgeWiring.Hooks()
    EdgeWiring.Attach(edge, {
      factory = factory,
      frame = frame,
      chrome = {},
      settingsConfig = { screenEdge = "left" },
      compactLayout = false,
      scriptResult = { applyWindowSize = function() end },
    })
    assert(edge.side() == nil, "no side in the classic layout")
    assert(edge.apply() == false and frame:IsMovable() and frame:GetPoint() == nil, "nothing placed")
  end
end
