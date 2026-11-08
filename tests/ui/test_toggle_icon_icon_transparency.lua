local FakeUI = require("tests.helpers.fake_ui")
local IconTransparency = require("WhisperMessenger.UI.ToggleIcon.IconTransparency")

local EPSILON = 1e-9

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(getWidgetTransparency)
    local frame = factory.CreateFrame("Button", nil, parent)
    local hover = { active = false }
    local transparency = IconTransparency.Create(frame, {
      hover = hover,
      getWidgetTransparency = getWidgetTransparency,
    })
    return frame, hover, transparency
  end

  -- test_refresh_fades_icon_by_chosen_transparency

  do
    local frame, _, transparency = build(function()
      return 0.4
    end)
    transparency.refresh()
    assert(math.abs(frame:GetAlpha() - 0.6) < EPSILON, "40% transparency should give 60% alpha")
  end

  -- test_unread_makes_icon_opaque

  do
    local frame, _, transparency = build(function()
      return 0.4
    end)
    transparency.setHasUnread(true)
    assert(frame:GetAlpha() == 1, "unread whispers should make the icon opaque")
  end

  -- test_hover_makes_icon_opaque

  do
    local frame, hover, transparency = build(function()
      return 0.4
    end)
    transparency.setHasUnread(false)
    hover.active = true
    transparency.refresh()
    assert(frame:GetAlpha() == 1, "hovering should make the icon opaque")
  end

  -- test_non_numeric_transparency_counts_as_zero

  do
    local frame, _, transparency = build(function()
      return "x"
    end)
    transparency.refresh()
    assert(frame:GetAlpha() == 1, "a non-numeric transparency should leave the icon opaque")
  end

  -- test_transparency_above_one_is_clamped

  do
    local frame, _, transparency = build(function()
      return 2
    end)
    transparency.refresh()
    assert(frame:GetAlpha() == 0, "transparency above 1 should clamp to fully transparent")
  end

  -- test_missing_getter_leaves_icon_opaque

  do
    local frame, _, transparency = build(nil)
    transparency.refresh()
    assert(frame:GetAlpha() == 1, "no getter should leave the icon opaque")
  end

  -- test_frame_without_set_alpha_is_skipped

  do
    local transparency = IconTransparency.Create({}, { hover = { active = false } })
    transparency.setHasUnread(true)
    transparency.refresh()
  end
end
