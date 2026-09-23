local FakeUI = require("tests.helpers.fake_ui")
local DateSeparator = require("WhisperMessenger.UI.ChatBubble.DateSeparator")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local innerFactory = FakeUI.NewFactory()
  local parent = innerFactory.CreateFrame("Frame", "Pane", nil)
  parent:SetSize(400, 600)
  local ts = os.time({ year = 2026, month = 3, day = 19, hour = 12, min = 0, sec = 0 })

  -- test_divider_lines_take_current_theme_color_on_reuse
  do
    -- Model the frame pool: the factory hands back the same frame on the
    -- second render, which is exactly when the cached-region branch runs.
    local pooled
    local poolingFactory = {
      CreateFrame = function(...)
        if pooled == nil then
          pooled = innerFactory.CreateFrame(...)
        end
        return pooled
      end,
    }

    local frame = DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400).frame
    assert(frame._lineLeft ~= nil and frame._lineRight ~= nil, "separator creates divider lines")

    local savedDivider = Theme.COLORS.divider
    Theme.COLORS.divider = { 0.9, 0.1, 0.1, 1 }

    local again = DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400).frame
    assert(again == frame, "pool returns the same frame on reuse")

    local left = again._lineLeft
    assert(left.color ~= nil, "divider line has a color applied")
    assert(left.color[1] == 0.9 and left.color[2] == 0.1, "reused divider picks up the current theme color, got: " .. tostring(left.color[1]))
    local right = again._lineRight
    assert(right.color and right.color[1] == 0.9, "right divider recolors too")

    Theme.COLORS.divider = savedDivider
  end

  -- Pooled separator whose lines record SetGradient / SetVertexColor calls,
  -- rendered once under `preset`.
  local function renderWithGradientSpy(preset)
    local pooled
    local poolingFactory = {
      CreateFrame = function(...)
        if pooled == nil then
          pooled = innerFactory.CreateFrame(...)
        end
        return pooled
      end,
    }
    local frame = DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400).frame
    for _, line in ipairs({ frame._lineLeft, frame._lineRight }) do
      rawset(line, "SetGradient", function(self, orientation, minColor, maxColor)
        self.gradient = { orientation = orientation, from = minColor, to = maxColor }
      end)
    end
    Theme.SetPreset(preset)
    DateSeparator.CreateDateSeparator(poolingFactory, parent, ts, 400)
    return frame
  end

  local previousPreset = Theme.GetPreset()
  local previousCreateColor = _G.CreateColor
  rawset(_G, "CreateColor", function(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
  end)

  -- test_modern_divider_lines_fade_toward_outer_edges
  do
    local frame = renderWithGradientSpy("wow_default")
    local left = frame._lineLeft.gradient
    assert(left and left.orientation == "HORIZONTAL", "left line gets a horizontal gradient")
    assert(left.from.a == 0 and left.to.a == 1, "left line: transparent far left -> full near label")
    local right = frame._lineRight.gradient
    assert(right and right.orientation == "HORIZONTAL", "right line gets a horizontal gradient")
    assert(right.from.a == 1 and right.to.a == 0, "right line: full near label -> transparent far right")
  end

  -- test_azeroth_divider_lines_fade_too
  do
    local frame = renderWithGradientSpy("wow_native")
    assert(frame._lineLeft.gradient ~= nil and frame._lineRight.gradient ~= nil, "Azeroth lines fade like every preset")
  end

  Theme.SetPreset(previousPreset)
  rawset(_G, "CreateColor", previousCreateColor)
end
