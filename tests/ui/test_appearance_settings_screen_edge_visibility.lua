-- Screen edge, Edge glow and Glow color only show while Compact window is on;
-- hidden, the rows below close the gap.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")

local EDGE_ROWS = { "Screen edge", "Edge glow", "Glow color" }

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local case = { changes = {}, relayouts = 0 }
  case.result = AppearanceSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      case.changes[#case.changes + 1] = { key = key, value = value }
    end,
    onLayoutChanged = function()
      case.relayouts = case.relayouts + 1
    end,
  })
  return case
end

local function anchorOf(case, label)
  return select(2, FindUI.byLabel(case.result.frame, label):GetPoint())
end

local function assertEdgeRows(case, shown, why)
  local frame = case.result.frame
  for _, label in ipairs(EDGE_ROWS) do
    assert(FindUI.byLabel(frame, label):IsShown() == shown, label .. (shown and " shown" or " hidden") .. ": " .. why)
  end
  local above = shown and "Glow color" or "Compact window"
  assert(anchorOf(case, "Window animation") == FindUI.byLabel(frame, above), "Window animation sits under " .. above .. ": " .. why)
end

return function()
  -- test_compact_off_hides_the_edge_rows_and_closes_the_gap
  assertEdgeRows(create({ compactLayout = false }), false, "compact off")

  -- test_compact_on_shows_the_edge_rows
  assertEdgeRows(create({ compactLayout = true }), true, "compact on")
  assertEdgeRows(create(), true, "nothing saved reads as on, like the toggle")

  -- test_flipping_compact_shows_and_hides_them_and_relayouts_the_page
  do
    local case = create({ compactLayout = false })
    local toggle = FindUI.toggle(case.result.frame, "Compact window")
    FindUI.click(toggle)
    assertEdgeRows(case, true, "turned on")
    assert(case.relayouts == 1, "page remeasured once, got " .. case.relayouts)
    FindUI.click(toggle)
    assertEdgeRows(case, false, "turned off")
    assert(case.relayouts == 2, "page remeasured again, got " .. case.relayouts)
  end

  -- test_a_cancelled_reload_puts_the_rows_back_with_the_toggle
  do
    local case = create({ compactLayout = true })
    FindUI.click(FindUI.toggle(case.result.frame, "Compact window"))
    case.result.setCompactLayout(true)
    assertEdgeRows(case, true, "reload cancelled")
  end

  -- test_reset_to_defaults_hides_them_with_compact_off
  do
    local case = create({ compactLayout = true })
    FindUI.click(FindUI.byLabel(case.result.frame, "Reset to Defaults"))
    assertEdgeRows(case, false, "reset")
  end
end
