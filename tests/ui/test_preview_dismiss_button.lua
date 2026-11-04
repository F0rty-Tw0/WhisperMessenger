local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local CloseGlyphButton = require("WhisperMessenger.UI.Shared.CloseGlyphButton")
local PreviewDismissButton = require("WhisperMessenger.UI.ToggleIcon.PreviewDismissButton")

local function sameColor(actual, expected)
  if actual == nil or expected == nil then
    return false
  end
  for i = 1, 3 do
    if actual[i] ~= expected[i] then
      return false
    end
  end
  return (actual[4] or 1) == (expected[4] or 1)
end

local function build(theme)
  local factory = FakeUI.NewFactory()
  local previewFrame = factory.CreateFrame("Frame", nil, nil)
  return PreviewDismissButton.Create(factory, previewFrame, theme or Theme)
end

local function fire(frame, script)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "dismiss button has a " .. script .. " handler")
  handler(frame)
end

local function bgOf(dismiss)
  for _, child in ipairs(dismiss.button.children) do
    if child.frameType == "Texture" then
      return child
    end
  end
  return nil
end

return function()
  local function test_label_is_a_cross_in_the_quiet_color()
    local dismiss = build()
    assert(dismiss.label:GetText() == "×", "label is the cross glyph, got " .. tostring(dismiss.label:GetText()))
    assert(sameColor(dismiss.label.textColor, Theme.COLORS.text_secondary), "label idles at text_secondary")
  end

  local function test_hover_turns_the_cross_red()
    local dismiss = build()
    fire(dismiss.button, "OnEnter")
    assert(sameColor(dismiss.label.textColor, CloseGlyphButton.DANGER_HOVER), "hover paints the label DANGER_HOVER")
    assert(sameColor(bgOf(dismiss).vertexColor, { 0.85, 0.15, 0.15, 0.35 }), "hover tints the bg red")
  end

  local function test_leave_restores_the_quiet_look()
    local dismiss = build()
    fire(dismiss.button, "OnEnter")
    fire(dismiss.button, "OnLeave")
    assert(sameColor(dismiss.label.textColor, Theme.COLORS.text_secondary), "leave restores text_secondary")
    assert(sameColor(bgOf(dismiss).vertexColor, { 0, 0, 0, 0 }), "leave clears the bg")
  end

  local function test_apply_theme_changes_the_leave_color()
    local dismiss = build()
    local t2 = { COLORS = { text_secondary = { 0.1, 0.2, 0.3, 1 } }, FONTS = Theme.FONTS }
    dismiss.applyTheme(t2)
    assert(sameColor(dismiss.label.textColor, t2.COLORS.text_secondary), "applyTheme repaints the label")
    fire(dismiss.button, "OnEnter")
    fire(dismiss.button, "OnLeave")
    assert(sameColor(dismiss.label.textColor, t2.COLORS.text_secondary), "leave uses the new theme")
  end

  test_label_is_a_cross_in_the_quiet_color()
  test_hover_turns_the_cross_red()
  test_leave_restores_the_quiet_look()
  test_apply_theme_changes_the_leave_color()
end
