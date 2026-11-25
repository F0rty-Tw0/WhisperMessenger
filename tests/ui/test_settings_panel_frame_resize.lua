local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanelFrame = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelFrame")

local OUTER_WIDTH = 600

-- A page whose refreshLayout calls are counted, laid out once at OUTER_WIDTH.
local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(OUTER_WIDTH, 400)
  local state = { layouts = 0 }
  local panel = SettingsPanelFrame.Create(factory, parent, function()
    return {
      refreshLayout = function()
        state.layouts = state.layouts + 1
      end,
    }
  end, {}, function() end)
  state.panel = panel
  state.layouts = 0
  function state.resize(width, height)
    panel:GetScript("OnSizeChanged")(panel, width, height)
  end
  return state
end

return function()
  -- test_height_only_resize_does_not_lay_the_page_out_again
  do
    local state = build()
    state.resize(OUTER_WIDTH, 900)
    state.resize(OUTER_WIDTH, 901)
    assert(state.layouts == 0, "a page lays out by width alone, got " .. state.layouts .. " layouts")
  end

  -- test_width_resize_lays_the_page_out_again
  do
    local state = build()
    state.resize(OUTER_WIDTH + 100, 400)
    assert(state.layouts == 1, "a new width lays out once, got " .. state.layouts)
  end

  -- test_sub_pixel_width_drift_does_not_lay_the_page_out_again
  do
    local state = build()
    state.resize(OUTER_WIDTH + 0.0001, 400)
    assert(state.layouts == 0, "float noise in the width is no resize, got " .. state.layouts)
  end

  -- test_small_steps_that_add_up_lay_the_page_out_again
  do
    local state = build()
    state.resize(OUTER_WIDTH + 0.4, 400)
    state.resize(OUTER_WIDTH + 0.8, 400)
    assert(state.layouts == 1, "drift is measured from the last layout, got " .. state.layouts)
  end
end
