local FakeUI = require("tests.helpers.fake_ui")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

return function()
  -- The toggle icon and its incoming-message preview must float above
  -- action bars, bags, and other MEDIUM-strata frames. Without an explicit
  -- HIGH strata, both inherit MEDIUM and can render behind those frames.
  local factory = FakeUI.NewFactory()
  local icon = ToggleIcon.Create(factory, {})

  assert(
    icon.frame.frameStrata == "HIGH",
    "expected toggle icon frame to use HIGH strata so it stays above action bars/bags; got " .. tostring(icon.frame.frameStrata)
  )
  assert(
    icon.previewFrame.frameStrata == "HIGH",
    "expected incoming preview frame to use HIGH strata so it stays above action bars/bags; got " .. tostring(icon.previewFrame.frameStrata)
  )

  print("  All toggle icon strata tests passed")
end
