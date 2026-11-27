local FakeUI = require("tests.helpers.fake_ui")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

-- Records every GameTooltip call while fn runs.
local function withTooltip(fn)
  local saved = _G.GameTooltip
  local calls = {}
  local function record(name)
    return function(_, ...)
      calls[#calls + 1] = { name, ... }
    end
  end
  _G.GameTooltip = {
    SetOwner = record("SetOwner"),
    SetText = record("SetText"),
    AddLine = record("AddLine"),
    Show = record("Show"),
    Hide = record("Hide"),
  }
  local ok, err = pcall(fn, calls)
  _G.GameTooltip = saved
  assert(ok, err)
end

local function newRow()
  return FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
end

return function()
  -- test_attach_tooltip_shows_title_and_body_lines_on_enter
  withTooltip(function(calls)
    local row = newRow()
    UIHelpers.attachTooltip(row, { "Title", "Body" })
    row:GetScript("OnEnter")(row)
    assert(calls[1][1] == "SetOwner" and calls[1][2] == row and calls[1][3] == "ANCHOR_TOP", "anchored above the row")
    assert(calls[2][1] == "SetText" and calls[2][2] == "Title", "first line is the title")
    local line = calls[3]
    assert(line[1] == "AddLine" and line[2] == "Body" and line[3] == 1 and line[4] == 1 and line[5] == 1, "later lines in white")
    assert(calls[4][1] == "Show" and #calls == 4, "then shown")
  end)

  -- test_attach_tooltip_hides_on_leave
  withTooltip(function(calls)
    local row = newRow()
    UIHelpers.attachTooltip(row, { "Title", "Body" })
    row:GetScript("OnLeave")(row)
    assert(#calls == 1 and calls[1][1] == "Hide", "leaving hides the tooltip")
  end)

  -- test_attach_tooltip_takes_a_single_string
  withTooltip(function(calls)
    local row = newRow()
    UIHelpers.attachTooltip(row, "Only")
    row:GetScript("OnEnter")(row)
    assert(calls[2][1] == "SetText" and calls[2][2] == "Only" and calls[3][1] == "Show", "a lone string is the title")
  end)

  -- test_attach_tooltip_without_tooltip_sets_no_scripts
  do
    local row = newRow()
    UIHelpers.attachTooltip(row, nil)
    assert(row:GetScript("OnEnter") == nil and row:GetScript("OnLeave") == nil, "no tooltip, no hover scripts")
  end
end
