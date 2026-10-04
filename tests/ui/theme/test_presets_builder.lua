local Builder = require("WhisperMessenger.UI.Theme.Presets.Builder")

local function assertColor(actual, expected, label)
  assert(#actual == #expected, label .. ": expected " .. #expected .. " channels, got " .. #actual)
  for i = 1, #expected do
    assert(actual[i] == expected[i], label .. ": channel " .. i .. " expected " .. tostring(expected[i]) .. ", got " .. tostring(actual[i]))
  end
end

return function()
  -- test_rgb_returns_three_channel_color
  assertColor(Builder.Rgb(0.1, 0.2, 0.3), { 0.1, 0.2, 0.3 }, "Rgb")

  -- test_with_alpha_appends_alpha_to_rgb
  assertColor(Builder.WithAlpha({ 0.1, 0.2, 0.3 }, 0.5), { 0.1, 0.2, 0.3, 0.5 }, "WithAlpha")

  -- test_make_divider_roles_builds_base_strong_and_hover_dividers
  local roles = Builder.MakeDividerRoles({ 1, 1, 1 }, 0.08, 0.10, { 0.5, 0.5, 0.5 }, 0.16)
  assertColor(roles.divider, { 1, 1, 1, 0.08 }, "divider")
  assertColor(roles.divider_strong, { 1, 1, 1, 0.10 }, "divider_strong")
  assertColor(roles.divider_hover, { 0.5, 0.5, 0.5, 0.16 }, "divider_hover")
end
