local FakeUI = require("tests.helpers.fake_ui")

-- The fake frame's Show must match WoW: OnShow fires only when a hidden frame
-- becomes shown.

local function buildCounted()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local counts = { script = 0, hook = 0 }
  frame:SetScript("OnShow", function()
    counts.script = counts.script + 1
  end)
  frame:HookScript("OnShow", function()
    counts.hook = counts.hook + 1
  end)
  return frame, counts
end

-- test_show_on_shown_frame_fires_no_on_show
do
  local frame, counts = buildCounted()
  frame:Hide()
  frame:Show()
  frame:Show()
  assert(counts.script == 1, "OnShow script fires once for two Show calls, got " .. counts.script)
  assert(counts.hook == 1, "OnShow hook fires once for two Show calls, got " .. counts.hook)
end

-- test_show_after_hide_fires_on_show_again
do
  local frame, counts = buildCounted()
  frame:Hide()
  frame:Show()
  frame:Hide()
  frame:Show()
  assert(counts.script == 2, "OnShow script fires again after Hide, got " .. counts.script)
  assert(counts.hook == 2, "OnShow hook fires again after Hide, got " .. counts.hook)
end
