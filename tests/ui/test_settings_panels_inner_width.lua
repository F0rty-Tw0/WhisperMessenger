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
end
