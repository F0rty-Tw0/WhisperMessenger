local FakeUI = require("tests.helpers.fake_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local NativeTabToggle = require("WhisperMessenger.UI.ContactsList.NativeTabToggle")

-- Both skins: the strip moves inside the window's bottom edge (window held at
-- a screen edge) and back to hanging below it.
local SKINS = {
  { native = true, left = 11, overlap = 2, hang = NativeTabToggle.HEIGHT - 2, label = "HUD" },
  { native = false, left = 8, overlap = 0, hang = TabToggle.HEIGHT, label = "modern" },
}

local function create(skin)
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  window:SetClampRectInsets(-5, 5, 7, 3)
  local pane = factory.CreateFrame("Frame", nil, window)
  local toggle = TabToggle.Create(factory, pane, { nativeChrome = skin.native, windowFrame = window })
  return toggle, window
end

local function anchoredAs(frame, window, want, label)
  local points = frame.points
  assert(#points == 2, label .. ": two points, got " .. #points)
  for i, w in ipairs(want) do
    local p = points[i]
    assert(p[1] == w[1] and p[2] == window and p[3] == w[2] and p[4] == w[3] and p[5] == w[4], label .. ": point " .. i .. " " .. tostring(p[1]))
  end
end

return function()
  for _, skin in ipairs(SKINS) do
    -- test_inside_anchors_the_strip_the_given_height_above_the_window_bottom
    do
      local toggle, window = create(skin)
      toggle.setShown(true)
      toggle.setInside(true, 10)
      anchoredAs(toggle.frame, window, {
        { "BOTTOMLEFT", "BOTTOMLEFT", skin.left, 10 },
        { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 10 },
      }, skin.label .. " inside")
      -- test_inside_strip_does_not_reach_the_clamp_below_the_window
      assert(select(4, window:GetClampRectInsets()) == 3, skin.label .. ": no clamp reach while inside")
      toggle.setShown(false)
      toggle.setShown(true)
      assert(select(4, window:GetClampRectInsets()) == 3, skin.label .. ": still none after a show")

      -- test_outside_hangs_the_strip_again_with_its_clamp
      toggle.setInside(false)
      anchoredAs(toggle.frame, window, {
        { "TOPLEFT", "BOTTOMLEFT", skin.left, skin.overlap },
        { "TOPRIGHT", "BOTTOMRIGHT", 0, skin.overlap },
      }, skin.label .. " hanging")
      assert(select(4, window:GetClampRectInsets()) == 3 - skin.hang, skin.label .. ": clamp reaches the hanging strip again")
    end
  end
end
