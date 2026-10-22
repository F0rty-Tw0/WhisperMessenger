local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

return function()
  -- test_settings_content_keeps_equal_padding_on_both_sides
  do
    -- Controls start CONTENT_PADDING in from the left; their row must end
    -- the same distance in from the right so nothing touches the clip.
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    parent:SetWidth(300)
    local widths = {}
    local panels = SettingsPanels.Create(factory, {
      parent = parent,
      generalCreate = function(f, panel)
        return {
          frame = f.CreateFrame("Frame", nil, panel),
          refreshLayout = function(width)
            widths[#widths + 1] = width
          end,
        }
      end,
    })
    panels.getPanel(1)
    local padding = Theme.CONTENT_PADDING or 16
    assert(widths[1] == 300 - 2 * padding, "content width leaves padding on both sides, got " .. tostring(widths[1]))
  end

  local controlWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  local padding = Theme.CONTENT_PADDING or 16

  local function buildAt(outerWidth)
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    parent:SetWidth(outerWidth)
    local widths, view = {}, nil
    local panels = SettingsPanels.Create(factory, {
      parent = parent,
      generalCreate = function(f, panel)
        local frame = f.CreateFrame("Frame", nil, panel)
        frame:SetAllPoints(panel)
        view = { frame = frame }
        view.refreshLayout = function(width)
          widths[#widths + 1] = width
        end
        return view
      end,
    })
    panels.getPanel(1)
    return assert(view, "settings view should be built"), widths
  end

  -- test_wide_settings_pane_centers_the_control_column
  do
    local outer = controlWidth + 2 * padding + 200
    local view, widths = buildAt(outer)
    local gap = 100
    assert(widths[#widths] == controlWidth, "wide: the column keeps the control width, got " .. tostring(widths[#widths]))
    local tl, br = view.frame.points[1], view.frame.points[2]
    assert(tl[1] == "TOPLEFT" and tl[4] == gap and tl[5] == 0, "wide: page shifts right by the side gap, got x=" .. tostring(tl[4]))
    assert(br[1] == "BOTTOMRIGHT" and br[4] == -gap and br[5] == 0, "wide: page ends the same gap in from the right, got x=" .. tostring(br[4]))
  end

  -- test_narrow_settings_pane_keeps_todays_layout
  do
    local outer = controlWidth + 2 * padding - 40
    local view, widths = buildAt(outer)
    assert(widths[#widths] == outer - 2 * padding, "narrow: content width as today, got " .. tostring(widths[#widths]))
    local tl = view.frame.points[1]
    assert(tl[4] == 0, "narrow: no side gap, got x=" .. tostring(tl[4]))
  end
end
