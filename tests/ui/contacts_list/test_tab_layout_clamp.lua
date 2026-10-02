local FakeUI = require("tests.helpers.fake_ui")
local TabLayout = require("WhisperMessenger.UI.ContactsList.TabLayout")

-- Tabs hanging below the window extend its screen clamp while they show, so
-- dragging the window never pushes them off the bottom of the screen.

return function()
  local factory = FakeUI.NewFactory()

  -- test_shown_tabs_extend_the_bottom_clamp_and_hidden_restore_it
  do
    local window = factory.CreateFrame("Frame", nil, nil)
    window:SetClampRectInsets(-5, 5, 7, 3)
    local applyClamp = TabLayout.BindClamp(window, 30)
    applyClamp(true)
    local l, r, t, b = window:GetClampRectInsets()
    assert(l == -5 and r == 5 and t == 7, "other insets kept")
    assert(b == 3 - 30, "bottom inset reaches over the tabs, got " .. tostring(b))
    applyClamp(false)
    assert(select(4, window:GetClampRectInsets()) == 3, "hidden tabs restore the window's own clamp")
  end

  -- test_window_without_clamp_api_is_a_no_op
  do
    local applyClamp = TabLayout.BindClamp({}, 30)
    applyClamp(true)
  end
end
