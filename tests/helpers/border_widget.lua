-- Builds the toggle widget for the border tests. state is read live, so a
-- test changes a field and calls refreshTheme(). Nil fields mean the defaults:
-- defaultShape (circle when omitted), background on, border on, themed, not
-- desaturated.

local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function borderWidget(state, defaultShape)
  local fallbackShape = defaultShape or "circle"

  return ToggleIcon.Create(FakeUI.NewFactory(), {
    getWidgetShape = function()
      return state.shape or fallbackShape
    end,
    getIconBackground = function()
      return state.background
    end,
    getIconBorder = function()
      return state.border
    end,
    getIconBorderThemed = function()
      return state.themed
    end,
    getIconDesaturated = function()
      return state.desaturated == true
    end,
  })
end

return borderWidget
