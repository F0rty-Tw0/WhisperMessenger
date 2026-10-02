local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local ToggleSwitch = require("WhisperMessenger.UI.Helpers.ToggleSwitch")
local NativeControls = require("WhisperMessenger.UI.Helpers.NativeControls")

local ROW_HEIGHT = 24
local LINE_HEIGHT = 16
-- Fake GetStringWidth is 7px per character.
local SHORT_LABEL = "Dim"
local LONG_LABEL = "Hide whispers from default chat"

-- The fake FontString never wraps; measure like the game does once a width
-- and word wrap are set.
local function wrapMeasure(fontString)
  fontString.GetStringHeight = function(self)
    local lineHeight = self.lineHeight or LINE_HEIGHT
    if not self.wordWrap or type(self.width) ~= "number" or self.width <= 0 then
      return lineHeight
    end
    return math.max(1, math.ceil(self:GetStringWidth() / self.width)) * lineHeight
  end
end

local function newToggle(factory, label, width)
  local parent = factory.CreateFrame("Frame", nil, nil)
  local colors = { text = Theme.COLORS.text_primary }
  local toggle = Controls.createToggleRow(factory, parent, label, false, colors, { width = 300, height = ROW_HEIGHT })
  wrapMeasure(toggle.label)
  toggle.setWidth(width or 300)
  return toggle
end

local function controlWidth(toggle)
  return toggle.dot.width
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_label_stops_before_the_switch
  do
    local toggle = newToggle(factory, LONG_LABEL, 200)
    assert(type(toggle.label.width) == "number", "label should get a width")
    assert(toggle.label.width + controlWidth(toggle) < 200, "label should end before the switch, got width " .. tostring(toggle.label.width))
  end

  -- test_label_word_wraps
  do
    local toggle = newToggle(factory, LONG_LABEL, 200)
    assert(toggle.label.wordWrap == true, "label should wrap instead of running under the switch")
  end

  -- test_long_label_grows_the_row
  do
    local toggle = newToggle(factory, LONG_LABEL, 200)
    assert(toggle.row.height == 2 * LINE_HEIGHT, "two-line label should make the row two lines tall, got " .. tostring(toggle.row.height))
    assert(toggle.row.width == 200, "row keeps the panel width")
  end

  -- test_short_label_keeps_single_line_row_height
  do
    local toggle = newToggle(factory, SHORT_LABEL, 200)
    assert(toggle.row.height == ROW_HEIGHT, "short label keeps today's row height, got " .. tostring(toggle.row.height))
  end

  -- test_widening_the_panel_unwraps_the_label
  do
    local toggle = newToggle(factory, LONG_LABEL, 200)
    toggle.setWidth(400)
    assert(toggle.row.height == ROW_HEIGHT, "wide panel fits the label on one line, got " .. tostring(toggle.row.height))
    assert(toggle.label.width + controlWidth(toggle) < 400, "label width follows the new panel width")
  end

  -- test_relabel_refits_the_row
  do
    local toggle = newToggle(factory, SHORT_LABEL, 200)
    toggle.label:SetText(LONG_LABEL)
    assert(toggle.label:GetText() == LONG_LABEL, "relabel still sets the text")
    assert(toggle.row.height == 2 * LINE_HEIGHT, "language change to a longer label grows the row, got " .. tostring(toggle.row.height))
  end

  -- test_theme_refresh_refits_the_row_for_font_size
  do
    local toggle = newToggle(factory, SHORT_LABEL, 200)
    toggle.label.lineHeight = 30
    toggle.applyThemeColors({ text = Theme.COLORS.text_primary })
    assert(toggle.row.height == 30, "bigger font grows the row on the next theme refresh, got " .. tostring(toggle.row.height))
  end

  -- test_hud_checkbox_label_stops_before_the_box
  do
    Hud.Configure("classic")
    local toggle = newToggle(factory, LONG_LABEL, 200)
    Hud.Configure("off")
    assert(controlWidth(toggle) == NativeControls.CHECK_SIZE, "HUD toggle uses the checkbox")
    assert(toggle.label.width + NativeControls.CHECK_SIZE < 200, "HUD label ends before the checkbox")
    assert(toggle.row.height == 2 * LINE_HEIGHT, "HUD row grows for a wrapped label")
  end

  -- test_modern_switch_still_sized_like_a_switch
  do
    local toggle = newToggle(factory, SHORT_LABEL, 200)
    assert(controlWidth(toggle) == ToggleSwitch.TRACK_WIDTH, "modern toggle keeps the switch width")
  end

  print("  All toggle row label wrap tests passed")
end
