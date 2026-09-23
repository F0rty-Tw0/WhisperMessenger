local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ResizeGrip = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ResizeGrip")

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  frame:SetSize(900, 580)
  local grip = ResizeGrip.Create(factory, frame)
  grip.applyTheme(Theme)
  return grip
end

-- Offsets (x from right, y from bottom) of every part, keyed "x,y:wxh".
local function shapeKeys(grip)
  local keys = {}
  for _, part in ipairs(grip.lines) do
    if part.shown ~= false then
      local pt = part.point
      keys[#keys + 1] = ("%d,%d:%dx%d"):format(-pt[4], pt[5], part.width, part.height)
    end
  end
  table.sort(keys)
  return table.concat(keys, " ")
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_modern_grip_is_three_dotted_diagonals
  do
    Theme.SetPreset("wow_default")
    local grip = build()
    -- Diagonals x + y = 2, 6, 10 (1, 2 and 3 dots), all 2x2.
    assert(shapeKeys(grip) == "1,1:2x2 1,5:2x2 1,9:2x2 5,1:2x2 5,5:2x2 9,1:2x2", "modern: expected 3 dotted diagonals, got " .. shapeKeys(grip))
    local c = grip.lines[1].color
    assert(c[1] == c[2] and c[2] == c[3], "modern: grip dots are neutral")
    assert(c[4] <= 0.3, "modern: grip dots are low alpha, got " .. tostring(c[4]))
  end

  -- test_azeroth_grip_matches_every_preset
  do
    Theme.SetPreset("wow_native")
    local grip = build()
    assert(shapeKeys(grip) == "1,1:2x2 1,5:2x2 1,9:2x2 5,1:2x2 5,5:2x2 9,1:2x2", "azeroth: same dotted grip, got " .. shapeKeys(grip))
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_resize_grip")
end
