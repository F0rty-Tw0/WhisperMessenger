local FakeUI = require("tests.helpers.fake_ui")
local TabScroller = require("WhisperMessenger.UI.ContactsList.TabScroller")

-- A bare strip with fixed-width tabs and a TabScroller on it, for tests that
-- check tab placement without a skin. The fake SetWidth does not fire
-- OnSizeChanged, so Rig.resize calls the script the way the game would.
local Rig = {}

local DEFAULT_WIDTHS = { 50, 50, 50, 50, 50 }
local ARROW_HEIGHT = 24
local STRIP_HEIGHT = 24

-- opts: spacing (2), endReserve (0), arrowWidth (16).
-- Returns { factory, strip, tabs, visible, scroller, prev, next, painted };
-- `painted` collects { btn, enabled } for every paintArrow call.
function Rig.build(widths, opts)
  opts = opts or {}
  local arrowWidth = opts.arrowWidth or 16
  local factory = FakeUI.NewFactory()
  local strip = factory.CreateFrame("Frame", nil, nil)
  local rig = { factory = factory, strip = strip, tabs = {}, painted = {} }
  for index, width in ipairs(widths or DEFAULT_WIDTHS) do
    local btn = factory.CreateFrame("Button", nil, strip)
    btn:SetWidth(width)
    rig.tabs[index] = { btn = btn }
  end
  rig.visible = rig.tabs
  rig.scroller = TabScroller.Attach(factory, strip, {
    spacing = opts.spacing or 2,
    endReserve = opts.endReserve or 0,
    arrowWidth = arrowWidth,
    createArrows = function(parent)
      local back = factory.CreateFrame("Button", nil, parent)
      local forward = factory.CreateFrame("Button", nil, parent)
      back:SetSize(arrowWidth, ARROW_HEIGHT)
      forward:SetSize(arrowWidth, ARROW_HEIGHT)
      rig.prev, rig.next = back, forward
      return { prev = back, next = forward }
    end,
    paintArrow = function(btn, enabled)
      rig.painted[#rig.painted + 1] = { btn = btn, enabled = enabled }
    end,
  })
  return rig
end

function Rig.resize(rig, width)
  rig.strip:SetWidth(width)
  rig.strip.scripts.OnSizeChanged(rig.strip, width, STRIP_HEIGHT)
end

-- Indices of the tabs currently shown, ascending.
function Rig.shownIndices(rig)
  local shown = {}
  for index, tab in ipairs(rig.tabs) do
    if tab.btn.shown then
      shown[#shown + 1] = index
    end
  end
  return shown
end

return Rig
