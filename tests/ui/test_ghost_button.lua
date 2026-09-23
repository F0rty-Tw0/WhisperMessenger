local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")
local GhostButton = require("WhisperMessenger.UI.Helpers.GhostButton")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function newButton(factory)
  local button = factory.CreateFrame("Button", nil, nil)
  button:SetSize(44, 30)
  local label = button:CreateFontString(nil, "OVERLAY")
  return button, label
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  -- test_every_preset_defines_ghost_roles
  for _, key in ipairs(Presets.ListKeys()) do
    local palette = assert(Presets.Get(key), key .. ": expected preset palette")
    for _, token in ipairs({ "ghost_button_fill_hover", "ghost_button_border", "ghost_button_text" }) do
      assert(type(palette[token]) == "table", key .. ": expected " .. token .. " token")
    end
  end

  Theme.SetPreset("wow_default")

  -- test_ghost_idle_is_neutral_outline
  do
    local button, label = newButton(factory)
    local ghost = GhostButton.Attach(button)
    GhostButton.Paint(ghost, label, false)
    assert(colorsMatch(ghost.border.top.color, Theme.COLORS.ghost_button_border), "idle: 1px neutral border")
    assert(ghost.border.top.shown == true, "idle: border shown")
    assert(ghost.border.top.height == Shapes.pixelSize(button), "idle: border should be one physical pixel")
    assert(ghost.fill == nil, "idle: no fill texture at all")
    assert(colorsMatch(label.textColor, Theme.COLORS.ghost_button_text), "idle: neutral text")
    assert(not colorsMatch(label.textColor, Theme.COLORS.accent), "idle: text must not be the accent")
    assert(ghost.hover.shown ~= true, "idle: hover fill hidden")
  end

  -- test_ghost_hover_shows_faint_accent_fill
  do
    local button, label = newButton(factory)
    local ghost = GhostButton.Attach(button)
    GhostButton.Paint(ghost, label, true)
    assert(ghost.hover.shown == true, "hover: hover fill shown")
    -- Colour at full alpha; the effective (region) alpha is the token's.
    local want = Theme.COLORS.ghost_button_fill_hover
    local c = ghost.hover.color
    assert(c[1] == want[1] and c[2] == want[2] and c[3] == want[3], "hover: neutral hover fill colour")
    assert(ghost.hover.alpha == want[4], "hover: faint effective alpha")
    GhostButton.Paint(ghost, label, false)
    assert(ghost.hover.shown == false, "leave: hover fill hidden again")
  end

  -- test_ghost_set_shown_false_hides_all_parts
  do
    local button = newButton(factory)
    local ghost = GhostButton.Attach(button)
    GhostButton.SetShown(ghost, false)
    assert(ghost.hover.shown == false, "hidden: hover hidden")
    assert(ghost.border.top.shown == false and ghost.border.left.shown == false, "hidden: border hidden")
  end

  -- test_option_button_ghost_opt_in_modern
  do
    local colors = { bg = Theme.COLORS.option_button_bg, text = Theme.COLORS.option_button_text }
    local button = Controls.createOptionButton(factory, nil, "Reset", colors, { ghost = true })
    assert(button.ghost ~= nil, "ghost option button should attach ghost parts")
    assert(button.ghost.border.top.shown == true, "modern: ghost border visible")
    assert(colorsMatch(button.label.textColor, Theme.COLORS.ghost_button_text), "modern: ghost option button uses neutral text")
    assert(button.bg.color[4] == 0, "modern: legacy solid bg cleared")
    button.scripts.OnEnter(button)
    assert(button.ghost.hover.shown == true, "modern: ghost option button hover fill")
  end

  -- test_option_button_ghost_azeroth_matches_every_preset
  do
    Theme.SetPreset("wow_native")
    local colors = { bg = Theme.COLORS.option_button_bg, text = Theme.COLORS.option_button_text }
    local button = Controls.createOptionButton(factory, nil, "Reset", colors, { ghost = true })
    assert(button.ghost.border.top.shown == true, "azeroth: ghost border visible")
    assert(button.bg.color[4] == 0, "azeroth: no solid bg")
    assert(colorsMatch(button.label.textColor, Theme.COLORS.ghost_button_text), "azeroth: neutral ghost text")
  end

  -- test_option_button_without_ghost_unchanged
  do
    Theme.SetPreset("wow_default")
    local colors = { bg = Theme.COLORS.option_button_bg, text = Theme.COLORS.option_button_text }
    local button = Controls.createOptionButton(factory, nil, "Tab", colors, {})
    assert(button.ghost == nil, "non-ghost option buttons stay plain")
    assert(colorsMatch(button.bg.color, Theme.COLORS.option_button_bg), "non-ghost keeps solid bg")
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_ghost_button")
end
